<?php

namespace App\Http\Resources\Api\Battle;

use App\Http\Resources\Api\Equipment\EquipmentInstanceResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Collection;

class BattleSettlementResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'stage_difficulty' => [
                'stage_difficulty_id' => (string) data_get($this->resource, 'stage_difficulty.stage_difficulty_id', ''),
                'difficulty_key' => (string) data_get($this->resource, 'stage_difficulty.difficulty_key', ''),
                'difficulty_name' => (string) data_get($this->resource, 'stage_difficulty.difficulty_name', ''),
            ],
            'is_cleared' => (int) data_get($this->resource, 'is_cleared', 0),
            'drop_results' => BattleSettlementItemResource::collection(
                Collection::make(data_get($this->resource, 'drop_results', []))
            )->resolve($request),
            'reward_results' => BattleSettlementRewardResultResource::collection(
                Collection::make(data_get($this->resource, 'reward_results', []))
            )->resolve($request),
            'inventory_results' => (new BattleSettlementInventoryResultResource(
                data_get($this->resource, 'inventory_results', [])
            ))->resolve($request),
            'created_equipment_instances' => EquipmentInstanceResource::collection(
                Collection::make(data_get($this->resource, 'created_equipment_instances', []))
            )->resolve($request),
            'first_clear_reward_status' => [
                'has_reward' => (int) data_get($this->resource, 'first_clear_reward_status.has_reward', 0),
                'has_granted' => (int) data_get($this->resource, 'first_clear_reward_status.has_granted', 0),
                'grant_status' => data_get($this->resource, 'first_clear_reward_status.grant_status'),
            ],
            'settlement_summary' => [
                'drop_count' => (int) data_get($this->resource, 'settlement_summary.drop_count', 0),
                'reward_count' => (int) data_get($this->resource, 'settlement_summary.reward_count', 0),
                'created_equipment_instance_count' => (int) data_get($this->resource, 'settlement_summary.created_equipment_instance_count', 0),
            ],
        ];
    }
}
