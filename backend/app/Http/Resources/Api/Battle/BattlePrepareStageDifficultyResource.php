<?php

namespace App\Http\Resources\Api\Battle;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BattlePrepareStageDifficultyResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'stage_difficulty_id' => (string) data_get($this->resource, 'stage_difficulty_id', ''),
            'difficulty_key' => (string) data_get($this->resource, 'difficulty_key', ''),
            'difficulty_name' => (string) data_get($this->resource, 'difficulty_name', ''),
            'recommended_power' => (int) data_get($this->resource, 'recommended_power', 0),
        ];
    }
}
