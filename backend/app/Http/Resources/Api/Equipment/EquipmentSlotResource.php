<?php

namespace App\Http\Resources\Api\Equipment;

use BackedEnum;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class EquipmentSlotResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'slot_key' => (string) $this->normalizeValue(data_get($this->resource, 'slot_key')),
            'equipped_instance_id' => data_get($this->resource, 'equipped_instance_id') === null
                ? null
                : (int) data_get($this->resource, 'equipped_instance_id'),
            'equipment' => data_get($this->resource, 'equipment') === null
                ? null
                : (new EquipmentInstanceResource(data_get($this->resource, 'equipment')))->resolve($request),
        ];
    }

    private function normalizeValue(mixed $value): mixed
    {
        return $value instanceof BackedEnum ? $value->value : $value;
    }
}
