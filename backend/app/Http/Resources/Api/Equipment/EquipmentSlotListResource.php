<?php

namespace App\Http\Resources\Api\Equipment;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class EquipmentSlotListResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'character_id' => (int) data_get($this->resource, 'character_id'),
            'slots' => array_map(
                static fn (array $slot): array => (new EquipmentSlotResource($slot))->resolve($request),
                data_get($this->resource, 'slots', [])
            ),
        ];
    }
}
