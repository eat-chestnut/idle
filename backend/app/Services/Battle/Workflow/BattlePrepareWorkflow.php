<?php

namespace App\Services\Battle\Workflow;

use App\Exceptions\BusinessException;
use App\Services\Battle\Domain\BattlePrepareService;
use App\Support\ErrorCode;
use Illuminate\Support\Facades\Log;
use Throwable;

class BattlePrepareWorkflow
{
    public function __construct(
        private readonly BattlePrepareService $battlePrepareService,
    ) {
    }

    public function prepareBattle(int $userId, int $characterId, string $stageDifficultyId): array
    {
        try {
            return $this->battlePrepareService->prepareBattle($userId, $characterId, $stageDifficultyId);
        } catch (BusinessException $exception) {
            Log::warning('battle prepare failed', [
                'user_id' => $userId,
                'character_id' => $characterId,
                'stage_difficulty_id' => $stageDifficultyId,
                'error_code' => $exception->getErrorCode(),
                'message' => $exception->getMessage(),
            ]);

            throw $exception;
        } catch (Throwable $throwable) {
            Log::error('battle prepare crashed', [
                'user_id' => $userId,
                'character_id' => $characterId,
                'stage_difficulty_id' => $stageDifficultyId,
                'message' => $throwable->getMessage(),
            ]);

            throw new BusinessException(ErrorCode::BATTLE_PREPARE_FAILED, previous: $throwable);
        }
    }
}
