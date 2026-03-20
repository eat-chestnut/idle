<?php

namespace App\Http\Resources\Api\Stage;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class FirstClearRewardStatusResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'source_type' => (string) data_get($this->resource, 'source_type', ''),
            'source_id' => (string) data_get($this->resource, 'source_id', ''),
            'has_reward' => (int) data_get($this->resource, 'has_reward', 0),
            'reward_group_id' => data_get($this->resource, 'reward_group_id'),
            'has_granted' => (int) data_get($this->resource, 'has_granted', 0),
            'grant_status' => data_get($this->resource, 'grant_status'),
        ];
    }
}
