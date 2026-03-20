<?php

namespace App\Services\Equipment\Domain;

use App\Enums\Equipment\EquipmentSlotKey;
use App\Exceptions\BusinessException;
use App\Models\Character\CharacterEquipmentSlot;
use App\Services\Character\Query\CharacterQueryService;
use App\Services\Equipment\Query\EquipmentQueryService;
use App\Support\ErrorCode;

class EquipmentUnequipService
{
    public function __construct(
        private readonly CharacterQueryService $characterQueryService,
        private readonly EquipmentQueryService $equipmentQueryService,
    ) {
    }

    public function validateUnequipRequest(int $userId, int $characterId, string $targetSlotKey): void
    {
        $this->characterQueryService->getOwnedCharacterById($userId, $characterId);
        $this->assertSlotKeyValid($targetSlotKey);

        $slotRow = $this->equipmentQueryService->getSlotRowByKey($characterId, $targetSlotKey);

        if ($slotRow === null || $slotRow->equipped_instance_id === null) {
            throw new BusinessException(ErrorCode::EQUIPMENT_SLOT_EMPTY);
        }
    }

    public function clearSlotInstance(CharacterEquipmentSlot $slotRow): void
    {
        $slotRow->equipped_instance_id = null;
        $slotRow->save();
    }

    private function assertSlotKeyValid(string $targetSlotKey): void
    {
        if (! in_array($targetSlotKey, EquipmentSlotKey::orderedValues(), true)) {
            throw new BusinessException(ErrorCode::EQUIPMENT_SLOT_INVALID);
        }
    }
}
