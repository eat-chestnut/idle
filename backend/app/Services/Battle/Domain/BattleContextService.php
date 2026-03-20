<?php

namespace App\Services\Battle\Domain;

use App\Enums\Battle\BattleContextStatus;
use App\Exceptions\BusinessException;
use App\Models\Battle\BattleContext;
use App\Support\ErrorCode;
use Throwable;

class BattleContextService
{
    public function createPreparedContext(
        string $battleContextId,
        int $userId,
        int $characterId,
        string $stageDifficultyId
    ): BattleContext {
        try {
            return BattleContext::query()->create([
                'battle_context_id' => $battleContextId,
                'user_id' => $userId,
                'character_id' => $characterId,
                'stage_difficulty_id' => $stageDifficultyId,
                'status' => BattleContextStatus::PREPARED->value,
                'settled_at' => null,
            ]);
        } catch (Throwable $throwable) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_BUILD_FAILED, previous: $throwable);
        }
    }

    public function assertSettleAllowed(
        int $userId,
        int $characterId,
        string $stageDifficultyId,
        ?BattleContext $battleContext
    ): void {
        if ($battleContext === null) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_INVALID);
        }

        if ((int) $battleContext->user_id !== $userId) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_INVALID);
        }

        if ((int) $battleContext->character_id !== $characterId) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_INVALID);
        }

        if ((string) $battleContext->stage_difficulty_id !== $stageDifficultyId) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_INVALID);
        }

        if (data_get($battleContext, 'status.value', $battleContext->status) !== BattleContextStatus::PREPARED->value) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_INVALID);
        }
    }

    public function markSettled(BattleContext $battleContext): void
    {
        $updated = BattleContext::query()
            ->where('battle_context_id', $battleContext->battle_context_id)
            ->where('status', BattleContextStatus::PREPARED->value)
            ->update([
                'status' => BattleContextStatus::SETTLED->value,
                'settled_at' => now(),
                'updated_at' => now(),
            ]);

        if ($updated !== 1) {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_INVALID);
        }

        $battleContext->status = BattleContextStatus::SETTLED;
        $battleContext->settled_at = now();
    }
}
