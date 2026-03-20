<?php

namespace App\Services\Character\Domain;

use App\Enums\Equipment\EquipmentSlotKey;
use App\Exceptions\BusinessException;
use App\Models\Character\CharacterEquipmentSlot;
use App\Support\ErrorCode;
use Throwable;

class CharacterEquipmentSlotInitService
{
    public function buildDefaultEquipmentSlots(int $characterId): array
    {
        $timestamp = now();
        $rows = [];

        foreach (EquipmentSlotKey::orderedValues() as $sortOrder => $slotKey) {
            $rows[] = [
                'character_id' => $characterId,
                'slot_key' => $slotKey,
                'equipped_instance_id' => null,
                'sort_order' => $sortOrder + 1,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ];
        }

        return $rows;
    }

    public function insertCharacterEquipmentSlots(array $rows): void
    {
        try {
            CharacterEquipmentSlot::query()->insert($rows);
        } catch (Throwable $throwable) {
            throw new BusinessException(ErrorCode::CHARACTER_SLOT_INIT_FAILED, previous: $throwable);
        }
    }
}
