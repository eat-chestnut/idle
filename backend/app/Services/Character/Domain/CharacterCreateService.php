<?php

namespace App\Services\Character\Domain;

use App\Exceptions\BusinessException;
use App\Models\Character\Character;
use App\Services\Character\Config\ClassConfigService;
use App\Support\ErrorCode;
use Throwable;

class CharacterCreateService
{
    public function __construct(
        private readonly ClassConfigService $classConfigService,
    ) {
    }

    public function validateCharacterCreateRequest(int $userId, array $input): void
    {
        $classId = (string) ($input['class_id'] ?? '');
        $characterName = trim((string) ($input['character_name'] ?? ''));

        if ($characterName === '' || mb_strlen($characterName) > 255) {
            throw new BusinessException(ErrorCode::CHARACTER_NAME_INVALID);
        }

        if ($this->classConfigService->getEnabledClassById($classId) === null) {
            throw new BusinessException(ErrorCode::CHARACTER_CLASS_INVALID);
        }
    }

    public function buildCharacterCreatePayload(int $userId, array $input, bool $isActive): array
    {
        return [
            'user_id' => $userId,
            'class_id' => (string) $input['class_id'],
            'character_name' => trim((string) $input['character_name']),
            'level' => 1,
            'exp' => 0,
            'unspent_stat_points' => 0,
            'added_strength' => 0,
            'added_mana' => 0,
            'added_constitution' => 0,
            'added_dexterity' => 0,
            'long_term_growth_stage' => null,
            'extra_context' => null,
            'is_active' => $isActive,
        ];
    }

    public function createCharacterRecord(array $payload): Character
    {
        try {
            return Character::query()->create($payload);
        } catch (Throwable $throwable) {
            throw new BusinessException(ErrorCode::CHARACTER_CREATE_FAILED, previous: $throwable);
        }
    }

    public function buildCharacterCreateResult(Character $character, array $slotRows): array
    {
        $character->loadMissing('gameClass');

        return [
            'character' => $character,
            'equipment_slots' => array_map(
                static fn (array $slotRow): array => [
                    'slot_key' => $slotRow['slot_key'],
                    'equipped_instance_id' => null,
                    'equipment' => null,
                ],
                $slotRows
            ),
        ];
    }
}
