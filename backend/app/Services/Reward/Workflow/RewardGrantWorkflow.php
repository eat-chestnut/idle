<?php

namespace App\Services\Reward\Workflow;

use App\Exceptions\BusinessException;
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
                    array_map(
                        static fn ($rewardItem): array => [
                            'item_id' => (string) $rewardItem->item_id,
                            'quantity' => (int) $rewardItem->quantity,
                        ],
                        $rewardItems
                    ),
                    [
                        'source' => 'reward',
                        'source_type' => (string) data_get($context, 'source_type'),
                        'source_id' => (string) data_get($context, 'source_id'),
                        'reward_grant_id' => $rewardGrantId,
                        'battle_context_id' => (string) data_get($context, 'battle_context_id'),
                    ]
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
}
