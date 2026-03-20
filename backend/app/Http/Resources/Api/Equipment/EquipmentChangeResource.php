<?php

namespace App\Http\Resources\Api\Equipment;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class EquipmentChangeResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $payload = [
            'character_id' => (int) data_get($this->resource, 'character_id'),
            'unequipped_instance_ids' => array_map(
                static fn (mixed $id): int => (int) $id,
                data_get($this->resource, 'unequipped_instance_ids', [])
            ),
            'changed_slots' => array_values(data_get($this->resource, 'changed_slots', [])),
            'slot_snapshot' => array_map(
                static fn (array $slot): array => (new EquipmentSlotResource($slot))->resolve($request),
                data_get($this->resource, 'slot_snapshot', [])
            ),
        ];

        if (array_key_exists('equipped_instance_id', $this->resource)) {
            $payload['equipped_instance_id'] = (int) data_get($this->resource, 'equipped_instance_id');
        }

        return $payload;
    }
}
