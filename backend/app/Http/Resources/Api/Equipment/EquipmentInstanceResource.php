<?php

namespace App\Http\Resources\Api\Equipment;

use BackedEnum;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class EquipmentInstanceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'equipment_instance_id' => (int) data_get($this->resource, 'equipment_instance_id'),
            'item_id' => (string) data_get($this->resource, 'item_id', ''),
            'item_name' => (string) data_get($this->resource, 'item_name', data_get($this->resource, 'equipmentTemplate.item.item_name', '')),
            'equipment_slot' => (string) $this->normalizeValue(
                data_get($this->resource, 'equipment_slot', data_get($this->resource, 'equipmentTemplate.equipment_slot', ''))
            ),
            'rarity' => (string) $this->normalizeValue(
                data_get($this->resource, 'rarity', data_get($this->resource, 'equipmentTemplate.rarity', ''))
            ),
            'icon' => data_get($this->resource, 'icon', data_get($this->resource, 'equipmentTemplate.item.icon')),
            'bind_type' => (string) $this->normalizeValue(data_get($this->resource, 'bind_type', '')),
            'enhance_level' => (int) data_get($this->resource, 'enhance_level', 0),
            'durability' => (int) data_get($this->resource, 'durability', 0),
            'max_durability' => (int) data_get($this->resource, 'max_durability', 0),
        ];
    }

    private function normalizeValue(mixed $value): mixed
    {
        return $value instanceof BackedEnum ? $value->value : $value;
    }
}
