<?php

namespace App\Services\Battle\Domain;

use App\Enums\Reward\RewardSourceType;
use App\Exceptions\BusinessException;
use App\Models\Battle\BattleContext;
use App\Models\Stage\StageDifficulty;
use App\Support\ErrorCode;
use Throwable;

class BattleSettlementService
{
    public function validateBattleSettlementRequest(
        int $userId,
        int $characterId,
        string $stageDifficultyId,
        array $battleResult,
        ?BattleContext $battleContext = null,
        array $allowedMonsterIds = []
    ): void {
        if ($userId <= 0 || $characterId <= 0 || $stageDifficultyId === '') {
            throw new BusinessException(ErrorCode::BATTLE_RESULT_INVALID);
        }

        $this->assertBattleContextValid($userId, $characterId, $stageDifficultyId, $battleResult, $battleContext);
        $this->assertBattleResultValid($battleResult, $allowedMonsterIds);
    }

    public function assertBattleContextValid(
        int $userId,
        int $characterId,
        string $stageDifficultyId,
        array $battleResult,
        ?BattleContext $battlePrepareContext = null
    ): void {
        $battleContextId = data_get($battleResult, 'battle_context_id');

        if (! is_string($battleContextId) || ! preg_match('/^battle_ctx_\d{8}_\d{6}_[a-z0-9]{6}$/', $battleContextId)) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_INVALID);
        }

        if ($battlePrepareContext === null) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_INVALID);
        }

        if ((string) $battlePrepareContext->battle_context_id !== $battleContextId) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_INVALID);
        }

        if ((int) $battlePrepareContext->user_id !== $userId) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_INVALID);
        }

        if ((int) $battlePrepareContext->character_id !== $characterId) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_INVALID);
        }

        if ((string) $battlePrepareContext->stage_difficulty_id !== $stageDifficultyId) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_INVALID);
        }
    }

    public function assertBattleResultValid(array $battleResult, array $allowedMonsterIds = []): void
    {
        if (! array_key_exists('is_cleared', $battleResult)) {
            throw new BusinessException(ErrorCode::BATTLE_RESULT_INVALID);
        }

        $isCleared = (int) data_get($battleResult, 'is_cleared');

        if (! in_array($isCleared, [0, 1], true)) {
            throw new BusinessException(ErrorCode::BATTLE_RESULT_INVALID);
        }

        $killedMonsters = data_get($battleResult, 'killed_monsters');

        if (! is_array($killedMonsters)) {
            throw new BusinessException(ErrorCode::BATTLE_RESULT_INVALID);
        }

        if ($isCleared === 1 && $killedMonsters === []) {
            throw new BusinessException(ErrorCode::BATTLE_RESULT_INVALID);
        }

        foreach ($killedMonsters as $monsterId) {
            if (! is_string($monsterId) || $monsterId === '') {
                throw new BusinessException(ErrorCode::BATTLE_RESULT_INVALID);
            }

            if ($allowedMonsterIds !== [] && ! in_array($monsterId, $allowedMonsterIds, true)) {
                throw new BusinessException(ErrorCode::BATTLE_RESULT_INVALID);
            }
        }
    }

    public function extractKilledMonsterIds(array $battleResult): array
    {
        return array_values(array_map(
            static fn (string $monsterId): string => trim($monsterId),
            array_filter(
                data_get($battleResult, 'killed_monsters', []),
                static fn (mixed $monsterId): bool => is_string($monsterId) && trim($monsterId) !== ''
            )
        ));
    }

    public function buildDropSettlementContext(string $stageDifficultyId, array $killedMonsterIds, array $battleResult = []): array
    {
        return [
            'stage_difficulty_id' => $stageDifficultyId,
            'killed_monster_ids' => $killedMonsterIds,
            'battle_context_id' => (string) data_get($battleResult, 'battle_context_id'),
        ];
    }

    public function buildRewardSettlementContext(
        int $userId,
        string $stageDifficultyId,
        array $battleResult,
        array $rewardStatus
    ): array {
        return [
            'user_id' => $userId,
            'source_type' => RewardSourceType::FIRST_CLEAR->value,
            'source_id' => $stageDifficultyId,
            'is_cleared' => (int) data_get($battleResult, 'is_cleared', 0),
            'battle_context_id' => (string) data_get($battleResult, 'battle_context_id'),
            'reward_status' => $rewardStatus,
        ];
    }

    public function buildBattleSettlementPayload(
        StageDifficulty $stageDifficulty,
        array $battleResult,
        array $dropResults,
        array $rewardResults = [],
        array $inventoryResults = [],
        array $instanceResults = [],
        array $firstClearRewardStatus = []
    ): array {
        try {
            return [
                'stage_difficulty' => [
                    'stage_difficulty_id' => (string) $stageDifficulty->stage_difficulty_id,
                    'difficulty_key' => (string) data_get($stageDifficulty, 'difficulty_key.value', data_get($stageDifficulty, 'difficulty_key', '')),
                    'difficulty_name' => (string) $stageDifficulty->difficulty_name,
                ],
                'is_cleared' => (int) data_get($battleResult, 'is_cleared', 0),
                'drop_results' => $dropResults,
                'reward_results' => $rewardResults,
                'inventory_results' => $inventoryResults,
                'created_equipment_instances' => $instanceResults,
                'first_clear_reward_status' => $firstClearRewardStatus,
                'settlement_summary' => [
                    'drop_count' => count($dropResults),
                    'reward_count' => count($rewardResults),
                    'created_equipment_instance_count' => count($instanceResults),
                ],
            ];
        } catch (Throwable $throwable) {
            throw new BusinessException(ErrorCode::BATTLE_SETTLEMENT_PAYLOAD_BUILD_FAILED, previous: $throwable);
        }
    }
}
