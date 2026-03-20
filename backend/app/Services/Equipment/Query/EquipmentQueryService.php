<?php

namespace App\Services\Equipment\Query;

use App\Enums\Equipment\EquipmentSlotKey;
use App\Models\Character\CharacterEquipmentSlot;
use App\Models\Equipment\InventoryEquipmentInstance;
use Illuminate\Database\Eloquent\Collection;

class EquipmentQueryService
{
    public function getCharacterSlotMap(int $characterId, bool $forUpdate = false): array
    {
        $slotMap = [];

        foreach ($this->getCharacterSlots($characterId, null, $forUpdate) as $slotRow) {
            $slotMap[$this->resolveSlotKeyValue($slotRow->slot_key)] = $slotRow;
        }

        return $slotMap;
    }

    public function getCharacterSlots(int $characterId, ?array $slotKeys = null, bool $forUpdate = false): Collection
    {
        $query = CharacterEquipmentSlot::query()
            ->with(['equippedInstance.equipmentTemplate.item'])
            ->where('character_id', $characterId)
            ->orderBy('sort_order');

        if ($slotKeys !== null) {
            $query->whereIn('slot_key', $slotKeys);
        }

        if ($forUpdate) {
            $query->lockForUpdate();
        }

        return $query->get();
    }

    public function getSlotRowByKey(int $characterId, string $slotKey, bool $forUpdate = false): ?CharacterEquipmentSlot
    {
        $query = CharacterEquipmentSlot::query()
            ->with(['equippedInstance.equipmentTemplate.item'])
            ->where('character_id', $characterId)
            ->where('slot_key', $slotKey);

        if ($forUpdate) {
            $query->lockForUpdate();
        }

        return $query->first();
    }

    public function getEquipmentInstanceById(int $equipmentInstanceId): ?InventoryEquipmentInstance
    {
        return InventoryEquipmentInstance::query()
            ->with(['equipmentTemplate.item', 'equippedSlot'])
            ->find($equipmentInstanceId);
    }

    public function isEquipmentInstanceEquipped(int $equipmentInstanceId): bool
    {
        return CharacterEquipmentSlot::query()
            ->where('equipped_instance_id', $equipmentInstanceId)
            ->exists();
    }

    public function getOrderedSlotSnapshot(int $characterId, ?array $slotKeys = null): array
    {
        $orderedSlotKeys = $slotKeys === null
            ? EquipmentSlotKey::orderedValues()
            : array_values(array_intersect(EquipmentSlotKey::orderedValues(), $slotKeys));

        $slotRows = $this->getCharacterSlots($characterId, $orderedSlotKeys);
        $slotMap = [];

        foreach ($slotRows as $slotRow) {
            $slotMap[$this->resolveSlotKeyValue($slotRow->slot_key)] = $slotRow;
        }

        return array_map(
            fn (string $slotKey): array => $this->normalizeSlotSnapshot(
                $slotMap[$slotKey] ?? null,
                $slotKey
            ),
            $orderedSlotKeys
        );
    }

    private function normalizeSlotSnapshot(?CharacterEquipmentSlot $slotRow, string $slotKey): array
    {
        if ($slotRow === null) {
            return [
                'slot_key' => $slotKey,
                'equipped_instance_id' => null,
                'equipment' => null,
            ];
        }

        return [
            'slot_key' => $slotKey,
            'equipped_instance_id' => $slotRow->equipped_instance_id === null
                ? null
                : (int) $slotRow->equipped_instance_id,
            'equipment' => $slotRow->equippedInstance === null
                ? null
                : $this->normalizeEquipmentInstance($slotRow->equippedInstance),
        ];
    }

    private function normalizeEquipmentInstance(InventoryEquipmentInstance $instance): array
    {
        return [
            'equipment_instance_id' => (int) $instance->equipment_instance_id,
            'item_id' => (string) $instance->item_id,
            'item_name' => (string) data_get($instance, 'equipmentTemplate.item.item_name', ''),
            'equipment_slot' => (string) data_get($instance, 'equipmentTemplate.equipment_slot.value', data_get($instance, 'equipmentTemplate.equipment_slot', '')),
            'rarity' => (string) data_get($instance, 'equipmentTemplate.rarity.value', data_get($instance, 'equipmentTemplate.rarity', '')),
            'icon' => data_get($instance, 'equipmentTemplate.item.icon'),
            'bind_type' => (string) data_get($instance, 'bind_type.value', $instance->bind_type),
            'enhance_level' => (int) $instance->enhance_level,
            'durability' => (int) $instance->durability,
            'max_durability' => (int) $instance->max_durability,
        ];
    }

    private function resolveSlotKeyValue(mixed $slotKey): string
    {
        return $slotKey instanceof EquipmentSlotKey ? $slotKey->value : (string) $slotKey;
    }
}
