<?php

namespace App\Services\Inventory\Query;

use App\Models\Equipment\InventoryEquipmentInstance;
use App\Models\Inventory\InventoryStackItem;

class InventoryQueryService
{
    public function getInventoryList(int $userId, string $tab = 'all'): array
    {
        $tab = in_array($tab, ['stack', 'equipment', 'all'], true) ? $tab : 'all';

        return [
            'stack_items' => $tab === 'equipment' ? [] : $this->getStackItems($userId),
            'equipment_items' => $tab === 'stack' ? [] : $this->getEquipmentItems($userId),
        ];
    }

    private function getStackItems(int $userId): array
    {
        return InventoryStackItem::query()
            ->with('item')
            ->where('user_id', $userId)
            ->get()
            ->sortBy([
                fn (InventoryStackItem $stackItem): int => (int) data_get($stackItem, 'item.sort_order', 0),
                fn (InventoryStackItem $stackItem): string => (string) $stackItem->item_id,
            ])
            ->values()
            ->map(static fn (InventoryStackItem $stackItem): array => [
                'item_id' => (string) $stackItem->item_id,
                'item_name' => (string) data_get($stackItem, 'item.item_name', ''),
                'item_type' => (string) data_get($stackItem, 'item.item_type.value', data_get($stackItem, 'item.item_type', '')),
                'rarity' => (string) data_get($stackItem, 'item.rarity.value', data_get($stackItem, 'item.rarity', '')),
                'icon' => data_get($stackItem, 'item.icon'),
                'quantity' => (int) $stackItem->quantity,
            ])
            ->all();
    }

    private function getEquipmentItems(int $userId): array
    {
        return InventoryEquipmentInstance::query()
            ->with(['equipmentTemplate.item', 'equippedSlot'])
            ->where('user_id', $userId)
            ->get()
            ->sortBy([
                fn (InventoryEquipmentInstance $instance): int => (int) data_get($instance, 'equipmentTemplate.sort_order', 0),
                fn (InventoryEquipmentInstance $instance): int => (int) $instance->equipment_instance_id,
            ])
            ->values()
            ->map(static fn (InventoryEquipmentInstance $instance): array => [
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
            ])
            ->all();
    }
}
