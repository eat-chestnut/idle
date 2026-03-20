<?php

namespace App\Http\Resources\Api\Stage;

use BackedEnum;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StageDifficultyResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'stage_difficulty_id' => (string) data_get($this->resource, 'stage_difficulty_id', ''),
            'difficulty_key' => (string) $this->normalizeValue(data_get($this->resource, 'difficulty_key')),
            'difficulty_name' => (string) data_get($this->resource, 'difficulty_name', ''),
            'difficulty_order' => (int) data_get($this->resource, 'difficulty_order', 0),
            'recommended_power' => (int) data_get($this->resource, 'recommended_power', 0),
            'first_clear_reward' => [
                'has_reward' => (int) data_get($this->resource, 'first_clear_reward.has_reward', 0),
                'has_granted' => (int) data_get($this->resource, 'first_clear_reward.has_granted', 0),
                'reward_group_id' => data_get($this->resource, 'first_clear_reward.reward_group_id'),
            ],
        ];
    }

    private function normalizeValue(mixed $value): mixed
    {
        return $value instanceof BackedEnum ? $value->value : $value;
    }
}
