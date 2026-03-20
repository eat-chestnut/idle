<?php

namespace App\Http\Resources\Api\Inventory;

use App\Http\Resources\Api\Equipment\EquipmentInstanceResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InventoryListResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'stack_items' => array_map(
                static fn (array $item): array => (new InventoryStackItemResource($item))->resolve($request),
                $this->resource['stack_items']
            ),
            'equipment_items' => array_map(
                static fn (array $item): array => (new EquipmentInstanceResource($item))->resolve($request),
                $this->resource['equipment_items']
            ),
        ];
    }
}
