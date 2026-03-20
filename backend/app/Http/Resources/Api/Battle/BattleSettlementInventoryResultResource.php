<?php

namespace App\Http\Resources\Api\Battle;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BattleSettlementInventoryResultResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'stack_results' => array_map(
                static fn (array $result): array => [
                    'item_id' => (string) data_get($result, 'item_id', ''),
                    'before_quantity' => (int) data_get($result, 'before_quantity', 0),
                    'add_quantity' => (int) data_get($result, 'add_quantity', 0),
                    'after_quantity' => (int) data_get($result, 'after_quantity', 0),
                    'action' => (string) data_get($result, 'action', ''),
                ],
                data_get($this->resource, 'stack_results', [])
            ),
            'equipment_instance_results' => array_map(
                static fn (array $result): array => [
                    'equipment_instance_id' => (int) data_get($result, 'equipment_instance_id', 0),
                    'item_id' => (string) data_get($result, 'item_id', ''),
                    'bind_type' => (string) data_get($result, 'bind_type', ''),
                    'enhance_level' => (int) data_get($result, 'enhance_level', 0),
                    'durability' => (int) data_get($result, 'durability', 0),
                    'max_durability' => (int) data_get($result, 'max_durability', 0),
                ],
                data_get($this->resource, 'equipment_instance_results', [])
            ),
        ];
    }
}
