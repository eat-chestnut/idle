<?php

namespace App\Services\Equipment\Domain;

use App\Services\Equipment\Query\EquipmentQueryService;

class EquipmentChangeResultService
{
    public function __construct(
        private readonly EquipmentQueryService $equipmentQueryService,
        private readonly EquipmentWearService $equipmentWearService,
    ) {
    }

    public function buildEquipmentChangeResult(int $characterId, array $changedSlots, array $meta = []): array
    {
        $changedSlots = $this->equipmentWearService->sortSlotKeys($changedSlots);

        $payload = [
            'character_id' => $characterId,
            'changed_slots' => $changedSlots,
            'unequipped_instance_ids' => array_values(array_unique($meta['unequipped_instance_ids'] ?? [])),
            'slot_snapshot' => $this->equipmentQueryService->getOrderedSlotSnapshot($characterId, $changedSlots),
        ];

        if (array_key_exists('equipped_instance_id', $meta)) {
            $payload['equipped_instance_id'] = $meta['equipped_instance_id'];
        }

        return $payload;
    }
}
