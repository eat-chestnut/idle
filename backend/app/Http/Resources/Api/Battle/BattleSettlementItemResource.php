<?php

namespace App\Http\Resources\Api\Battle;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BattleSettlementItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'item_id' => (string) data_get($this->resource, 'item_id', ''),
            'item_name' => (string) data_get($this->resource, 'item_name', ''),
            'item_type' => (string) data_get($this->resource, 'item_type', ''),
            'rarity' => (string) data_get($this->resource, 'rarity', ''),
            'icon' => data_get($this->resource, 'icon'),
            'quantity' => (int) data_get($this->resource, 'quantity', 0),
        ];
    }
}
