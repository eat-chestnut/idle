<?php

namespace App\Http\Resources\Api\Character;

use App\Http\Resources\Api\Equipment\EquipmentSlotResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CharacterCreateResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'character' => (new CharacterResource($this->resource['character']))->resolve($request),
            'equipment_slots' => array_map(
                static fn (array $slot): array => (new EquipmentSlotResource($slot))->resolve($request),
                $this->resource['equipment_slots']
            ),
        ];
    }
}
