<?php

namespace App\Http\Resources\Api\Battle;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Collection;

class BattleSettlementRewardResultResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'reward_grant_id' => (int) data_get($this->resource, 'reward_grant_id', 0),
            'reward_group_id' => (string) data_get($this->resource, 'reward_group_id', ''),
            'grant_status' => (string) data_get($this->resource, 'grant_status', ''),
            'reward_items' => BattleSettlementItemResource::collection(
                Collection::make(data_get($this->resource, 'reward_items', []))
            )->resolve($request),
        ];
    }
}
