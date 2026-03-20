<?php

namespace App\Services\Battle\Workflow;

use App\Exceptions\BusinessException;
use App\Services\Battle\Domain\BattleSettlementService;
use App\Services\Character\Query\CharacterQueryService;
use App\Services\Drop\Domain\DropResolverService;
use App\Services\Inventory\Domain\InventoryWriteService;
use App\Services\Reward\Config\FirstClearRewardConfigService;
use App\Services\Reward\Query\FirstClearRewardStatusQueryService;
use App\Services\Reward\Workflow\RewardGrantWorkflow;
use App\Services\Stage\Config\StageConfigService;
use App\Services\Stage\Query\StageMonsterQueryService;
use App\Support\ErrorCode;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class BattleSettlementWorkflow
{
    public function __construct(
        private readonly StageConfigService $stageConfigService,
        private readonly StageMonsterQueryService $stageMonsterQueryService,
        private readonly CharacterQueryService $characterQueryService,
        private readonly FirstClearRewardConfigService $firstClearRewardConfigService,
        private readonly FirstClearRewardStatusQueryService $firstClearRewardStatusQueryService,
        private readonly DropResolverService $dropResolverService,
        private readonly InventoryWriteService $inventoryWriteService,
        private readonly RewardGrantWorkflow $rewardGrantWorkflow,
        private readonly BattleSettlementService $battleSettlementService,
    ) {
    }

    public function settleBattle(int $userId, int $characterId, string $stageDifficultyId, array $battleResult): array
    {
        try {
            $stageDifficulty = $this->stageConfigService->getEnabledStageDifficultyById($stageDifficultyId);

            if ($stageDifficulty === null) {
                throw new BusinessException(ErrorCode::STAGE_DIFFICULTY_NOT_FOUND);
            }

            $character = $this->characterQueryService->getOwnedCharacterById($userId, $characterId);

            if (! $character->is_active) {
                throw new BusinessException(ErrorCode::CHARACTER_NOT_ACTIVE);
            }

            $allowedMonsterIds = $this->stageMonsterQueryService->getStageMonsterBindings($stageDifficultyId)
                ->pluck('monster_id')
                ->map(static fn (mixed $monsterId): string => (string) $monsterId)
                ->all();

            if ($allowedMonsterIds === []) {
                throw new BusinessException(ErrorCode::STAGE_MONSTER_BINDING_EMPTY);
            }

            $this->battleSettlementService->validateBattleSettlementRequest(
                $userId,
                $characterId,
                $stageDifficultyId,
                $battleResult,
                $allowedMonsterIds
            );

            $killedMonsterIds = $this->battleSettlementService->extractKilledMonsterIds($battleResult);
            $rewardBinding = $this->firstClearRewardConfigService->getEnabledBindingBySourceId($stageDifficultyId);
            $rewardStatusBefore = $this->firstClearRewardStatusQueryService->getStatus($userId, $stageDifficultyId, $rewardBinding);

            $dropResults = $this->resolveDropResults($stageDifficultyId, $battleResult, $killedMonsterIds);
            $shouldGrantReward = (int) data_get($battleResult, 'is_cleared', 0) === 1
                && (int) data_get($rewardStatusBefore, 'has_reward', 0) === 1
                && (int) data_get($rewardStatusBefore, 'has_granted', 0) === 0;

            [$dropInventoryResults, $rewardGrantResult] = DB::transaction(function () use (
                $userId,
                $stageDifficultyId,
                $battleResult,
                $rewardStatusBefore,
                $dropResults,
                $shouldGrantReward
            ): array {
                try {
                    $dropInventoryResults = $dropResults === []
                        ? $this->inventoryWriteService->emptyResult()
                        : $this->inventoryWriteService->writeDrops(
                            $userId,
                            array_map(
                                static fn (array $dropResult): array => [
                                    'item_id' => (string) $dropResult['item_id'],
                                    'quantity' => (int) $dropResult['quantity'],
                                ],
                                $dropResults
                            ),
                            [
                                'source' => 'drop',
                                'source_type' => 'stage_difficulty',
                                'source_id' => $stageDifficultyId,
                                'battle_context_id' => (string) data_get($battleResult, 'battle_context_id'),
                            ]
                        );
                } catch (BusinessException $exception) {
                    throw $this->isInventoryError($exception->getErrorCode())
                        ? new BusinessException(ErrorCode::BATTLE_SETTLEMENT_INVENTORY_FAILED, previous: $exception)
                        : $exception;
                }

                $rewardGrantResult = null;

                if ($shouldGrantReward) {
                    try {
                        $rewardGrantResult = $this->rewardGrantWorkflow->grant(
                            $this->battleSettlementService->buildRewardSettlementContext(
                                $userId,
                                $stageDifficultyId,
                                $battleResult,
                                $rewardStatusBefore
                            )
                        );
                    } catch (BusinessException $exception) {
                        throw new BusinessException(ErrorCode::BATTLE_SETTLEMENT_REWARD_FAILED, previous: $exception);
                    }
                }

                return [$dropInventoryResults, $rewardGrantResult];
            });

            $finalRewardStatus = $rewardGrantResult === null
                ? $rewardStatusBefore
                : $this->firstClearRewardStatusQueryService->getStatus($userId, $stageDifficultyId, $rewardBinding);

            $payload = $this->battleSettlementService->buildBattleSettlementPayload(
                $stageDifficulty,
                $battleResult,
                $dropResults,
                $rewardGrantResult === null ? [] : [[
                    'reward_grant_id' => (int) $rewardGrantResult['reward_grant_id'],
                    'reward_group_id' => (string) $rewardGrantResult['reward_group_id'],
                    'grant_status' => (string) $rewardGrantResult['grant_status'],
                    'reward_items' => $rewardGrantResult['reward_items'],
                ]],
                $this->mergeInventoryResults(
                    $dropInventoryResults,
                    $rewardGrantResult['inventory_results'] ?? $this->inventoryWriteService->emptyResult()
                ),
                array_merge(
                    $dropInventoryResults['created_equipment_instances'],
                    $rewardGrantResult['created_equipment_instances'] ?? []
                ),
                [
                    'has_reward' => (int) data_get($finalRewardStatus, 'has_reward', 0),
                    'has_granted' => (int) data_get($finalRewardStatus, 'has_granted', 0),
                    'grant_status' => data_get($finalRewardStatus, 'grant_status'),
                ]
            );

            return $payload;
        } catch (BusinessException $exception) {
            Log::warning('battle settlement failed', [
                'user_id' => $userId,
                'character_id' => $characterId,
                'stage_difficulty_id' => $stageDifficultyId,
                'battle_context_id' => data_get($battleResult, 'battle_context_id'),
                'error_code' => $exception->getErrorCode(),
            ]);

            throw $exception;
        } catch (Throwable $throwable) {
            Log::error('battle settlement crashed', [
                'user_id' => $userId,
                'character_id' => $characterId,
                'stage_difficulty_id' => $stageDifficultyId,
                'battle_context_id' => data_get($battleResult, 'battle_context_id'),
                'message' => $throwable->getMessage(),
            ]);

            throw new BusinessException(ErrorCode::BATTLE_SETTLEMENT_FAILED, previous: $throwable);
        }
    }

    private function resolveDropResults(string $stageDifficultyId, array $battleResult, array $killedMonsterIds): array
    {
        if ($killedMonsterIds === []) {
            return [];
        }

        try {
            return $this->dropResolverService->resolve(
                $this->battleSettlementService->buildDropSettlementContext(
                    $stageDifficultyId,
                    $killedMonsterIds,
                    $battleResult
                )
            );
        } catch (BusinessException $exception) {
            throw match (true) {
                $this->isDropError($exception->getErrorCode()) => new BusinessException(
                    ErrorCode::BATTLE_SETTLEMENT_DROP_FAILED,
                    previous: $exception
                ),
                default => $exception,
            };
        }
    }

    private function mergeInventoryResults(array $dropInventoryResults, array $rewardInventoryResults): array
    {
        return [
            'stack_results' => array_merge(
                $dropInventoryResults['stack_results'] ?? [],
                $rewardInventoryResults['stack_results'] ?? []
            ),
            'equipment_instance_results' => array_merge(
                $dropInventoryResults['equipment_instance_results'] ?? [],
                $rewardInventoryResults['equipment_instance_results'] ?? []
            ),
        ];
    }

    private function isDropError(int $errorCode): bool
    {
        return $errorCode >= ErrorCode::DROP_CONTEXT_INVALID && $errorCode <= ErrorCode::DROP_RESULT_BUILD_FAILED;
    }

    private function isInventoryError(int $errorCode): bool
    {
        return $errorCode >= ErrorCode::INVENTORY_WRITE_CONTEXT_INVALID && $errorCode <= ErrorCode::INVENTORY_RESULT_BUILD_FAILED;
    }
}
