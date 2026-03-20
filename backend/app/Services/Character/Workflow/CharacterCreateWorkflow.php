<?php

namespace App\Services\Character\Workflow;

use App\Exceptions\BusinessException;
use App\Services\Character\Domain\CharacterCreateService;
use App\Services\Character\Domain\CharacterEquipmentSlotInitService;
use App\Services\Character\Query\CharacterQueryService;
use App\Support\ErrorCode;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class CharacterCreateWorkflow
{
    public function __construct(
        private readonly CharacterCreateService $characterCreateService,
        private readonly CharacterEquipmentSlotInitService $characterEquipmentSlotInitService,
        private readonly CharacterQueryService $characterQueryService,
    ) {
    }

    public function createCharacter(int $userId, array $input): array
    {
        $this->characterCreateService->validateCharacterCreateRequest($userId, $input);

        $existingCharacterCount = $this->characterQueryService->countUserCharacters($userId);

        try {
            return DB::transaction(function () use ($userId, $input, $existingCharacterCount): array {
                $payload = $this->characterCreateService->buildCharacterCreatePayload(
                    $userId,
                    $input,
                    $existingCharacterCount === 0
                );

                $character = $this->characterCreateService->createCharacterRecord($payload);
                $slotRows = $this->characterEquipmentSlotInitService->buildDefaultEquipmentSlots((int) $character->character_id);

                $this->characterEquipmentSlotInitService->insertCharacterEquipmentSlots($slotRows);

                return $this->characterCreateService->buildCharacterCreateResult($character, $slotRows);
            });
        } catch (BusinessException $exception) {
            Log::warning('character_create_failed', [
                'user_id' => $userId,
                'class_id' => $input['class_id'] ?? null,
                'character_name' => $input['character_name'] ?? null,
                'error_code' => $exception->getErrorCode(),
            ]);

            throw $exception;
        } catch (Throwable $throwable) {
            Log::error('character_create_failed', [
                'user_id' => $userId,
                'class_id' => $input['class_id'] ?? null,
                'character_name' => $input['character_name'] ?? null,
                'exception' => $throwable,
            ]);

            throw new BusinessException(ErrorCode::CHARACTER_CREATE_FAILED, previous: $throwable);
        }
    }
}
