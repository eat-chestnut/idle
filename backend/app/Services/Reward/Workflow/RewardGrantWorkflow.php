<?php

namespace App\Services\Reward\Workflow;

use App\Exceptions\BusinessException;
use App\Models\Reward\UserRewardGrant;
use App\Services\Inventory\Domain\InventoryWriteService;
use App\Services\Reward\Config\RewardConfigService;
use App\Services\Reward\Domain\RewardGrantService;
use App\Services\Reward\Query\RewardGrantQueryService;
use App\Support\ErrorCode;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class RewardGrantWorkflow
{
    public function __construct(
        private readonly RewardConfigService $rewardConfigService,
        private readonly RewardGrantQueryService $rewardGrantQueryService,
        private readonly RewardGrantService $rewardGrantService,
        private readonly InventoryWriteService $inventoryWriteService,
    ) {
    }

    public function grant(array $context): array
    {
        $rewardGrantId = null;

        try {
            $this->rewardGrantService->validateRewardGrantContext($context);
            $binding = $this->rewardConfigService->getRewardBindingBySource(
                (string) data_get($context, 'source_type'),
                (string) data_get($context, 'source_id')
            );
            $rewardGroup = $binding === null
                ? null
                : $this->rewardConfigService->getRewardGroupById((string) $binding->reward_group_id);
            $rewardItems = $binding === null
                ? []
                : $this->rewardConfigService->getRewardGroupItemsByGroupId((string) $binding->reward_group_id);

            $this->rewardGrantService->assertRewardSourceValid($context, $binding, $rewardGroup, $rewardItems);

            $idempotencyKey = $this->rewardGrantService->buildRewardIdempotencyKey($context);

            if ($this->rewardGrantQueryService->getRewardGrantByIdempotencyKey((int) data_get($context, 'user_id'), $idempotencyKey) !== null) {
                throw new BusinessException(ErrorCode::REWARD_IDEMPOTENCY_CONFLICT);
            }

            $this->rewardGrantService->assertRewardGrantable(
                $context,
                $this->rewardGrantQueryService->getExistingSuccessfulGrant(
                    (int) data_get($context, 'user_id'),
                    (string) data_get($context, 'source_type'),
                    (string) data_get($context, 'source_id')
                )
            );

            return DB::transaction(function () use ($context, $binding, $rewardItems, $idempotencyKey, &$rewardGrantId): array {
                $grantRecord = $this->rewardGrantService->createRewardGrantRecord(
                    $this->rewardGrantService->buildRewardGrantRecordPayload(
                        $context,
                        (string) $binding->reward_group_id,
                        $idempotencyKey,
                        $rewardItems
                    )
                );
                $rewardGrantId = (int) $grantRecord->reward_grant_id;

                $this->rewardGrantService->insertRewardGrantItems(
                    $this->rewardGrantService->buildRewardGrantItemRows($rewardGrantId, $rewardItems)
                );

                $inventoryResults = $this->inventoryWriteService->writeRewards(
                    (int) data_get($context, 'user_id'),
                    $this->buildGrantInventoryObjects($rewardItems),
                    $this->buildRewardInventoryContext($context, $rewardGrantId)
                );

                $this->rewardGrantService->markRewardGrantSuccess($rewardGrantId);
                $grantRecord->refresh();

                return $this->rewardGrantService->buildRewardGrantResult(
                    $grantRecord,
                    $rewardItems,
                    $inventoryResults,
                    $inventoryResults['created_equipment_instances']
                );
            });
        } catch (BusinessException $exception) {
            Log::warning('reward grant failed', [
                'user_id' => data_get($context, 'user_id'),
                'source_type' => data_get($context, 'source_type'),
                'source_id' => data_get($context, 'source_id'),
                'battle_context_id' => data_get($context, 'battle_context_id'),
                'reward_grant_id' => $rewardGrantId,
                'error_code' => $exception->getErrorCode(),
            ]);

            throw $exception;
        } catch (Throwable $throwable) {
            Log::error('reward grant crashed', [
                'user_id' => data_get($context, 'user_id'),
                'source_type' => data_get($context, 'source_type'),
                'source_id' => data_get($context, 'source_id'),
                'battle_context_id' => data_get($context, 'battle_context_id'),
                'reward_grant_id' => $rewardGrantId,
                'message' => $throwable->getMessage(),
            ]);

            throw new BusinessException(ErrorCode::REWARD_GRANT_FAILED, previous: $throwable);
        }
    }

    public function retryGrant(int $rewardGrantId): array
    {
        $grantRecord = $this->rewardGrantQueryService->getRewardGrantById($rewardGrantId);

        if ($grantRecord === null) {
            throw new BusinessException(ErrorCode::RESOURCE_NOT_FOUND, '发奖记录不存在');
        }

        $grantItems = $grantRecord->items->all();

        if ($grantItems === []) {
            throw new BusinessException(ErrorCode::REWARD_GROUP_ITEMS_EMPTY);
        }

        $grantStatus = (string) data_get($grantRecord, 'grant_status.value', $grantRecord->grant_status);

        if ($grantStatus !== 'failed') {
            throw new BusinessException(ErrorCode::ADMIN_OPERATION_FORBIDDEN, '仅允许对 failed 发奖记录执行补发');
        }

        $existingSuccessfulGrant = $this->rewardGrantQueryService->getExistingSuccessfulGrantExcept(
            (int) $grantRecord->user_id,
            (string) data_get($grantRecord, 'source_type.value', $grantRecord->source_type),
            (string) $grantRecord->source_id,
            (int) $grantRecord->reward_grant_id
        );

        if ($existingSuccessfulGrant !== null) {
            throw new BusinessException(ErrorCode::REWARD_ALREADY_GRANTED);
        }

        try {
            return DB::transaction(function () use ($grantRecord, $grantItems): array {
                $lockedGrantRecord = $this->rewardGrantQueryService->getRewardGrantById((int) $grantRecord->reward_grant_id, true);

                if ($lockedGrantRecord === null) {
                    throw new BusinessException(ErrorCode::RESOURCE_NOT_FOUND, '发奖记录不存在');
                }

                $lockedGrantStatus = (string) data_get($lockedGrantRecord, 'grant_status.value', $lockedGrantRecord->grant_status);

                if ($lockedGrantStatus !== 'failed') {
                    throw new BusinessException(ErrorCode::ADMIN_OPERATION_FORBIDDEN, '仅允许对 failed 发奖记录执行补发');
                }

                $inventoryResults = $this->inventoryWriteService->writeRewards(
                    (int) $lockedGrantRecord->user_id,
                    $this->buildGrantInventoryObjects($grantItems),
                    $this->buildRewardInventoryContext([
                        'source_type' => (string) data_get($lockedGrantRecord, 'source_type.value', $lockedGrantRecord->source_type),
                        'source_id' => (string) $lockedGrantRecord->source_id,
                        'battle_context_id' => (string) data_get($lockedGrantRecord->grant_payload_snapshot, 'battle_context_id', ''),
                    ], (int) $lockedGrantRecord->reward_grant_id)
                );

                $this->rewardGrantService->markRewardGrantSuccess((int) $lockedGrantRecord->reward_grant_id);
                $lockedGrantRecord->refresh()->loadMissing(['items.item', 'rewardGroup']);

                return $this->rewardGrantService->buildRewardGrantResult(
                    $lockedGrantRecord,
                    $lockedGrantRecord->items->all(),
                    $inventoryResults,
                    $inventoryResults['created_equipment_instances']
                );
            });
        } catch (BusinessException $exception) {
            $this->markRetryGrantFailed($rewardGrantId, $exception);

            Log::warning('reward retry failed', [
                'reward_grant_id' => $rewardGrantId,
                'user_id' => $grantRecord->user_id,
                'source_type' => data_get($grantRecord, 'source_type.value', $grantRecord->source_type),
                'source_id' => $grantRecord->source_id,
                'error_code' => $exception->getErrorCode(),
            ]);

            throw $exception;
        } catch (Throwable $throwable) {
            $this->markRetryGrantFailed(
                $rewardGrantId,
                new BusinessException(ErrorCode::REWARD_GRANT_FAILED, previous: $throwable)
            );

            Log::error('reward retry crashed', [
                'reward_grant_id' => $rewardGrantId,
                'user_id' => $grantRecord->user_id,
                'source_type' => data_get($grantRecord, 'source_type.value', $grantRecord->source_type),
                'source_id' => $grantRecord->source_id,
                'message' => $throwable->getMessage(),
            ]);

            throw new BusinessException(ErrorCode::REWARD_GRANT_FAILED, previous: $throwable);
        }
    }

    private function buildGrantInventoryObjects(array $grantItems): array
    {
        return array_map(
            static fn ($grantItem): array => [
                'item_id' => (string) data_get($grantItem, 'item_id'),
                'quantity' => (int) data_get($grantItem, 'quantity', 0),
            ],
            $grantItems
        );
    }

    private function buildRewardInventoryContext(array $context, int $rewardGrantId): array
    {
        return [
            'source' => 'reward',
            'source_type' => (string) data_get($context, 'source_type'),
            'source_id' => (string) data_get($context, 'source_id'),
            'reward_grant_id' => $rewardGrantId,
            'battle_context_id' => (string) data_get($context, 'battle_context_id', ''),
        ];
    }

    private function markRetryGrantFailed(int $rewardGrantId, BusinessException $exception): void
    {
        try {
            $this->rewardGrantService->markRewardGrantFailed($rewardGrantId, [
                'error_code' => $exception->getErrorCode(),
                'message' => $exception->getMessage(),
            ]);
        } catch (Throwable) {
            // 后台补发失败时，主错误优先，状态修正失败只写日志。
        }
    }
}
