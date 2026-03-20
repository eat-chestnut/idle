<?php

namespace App\Http\Resources\Api\Battle;

use App\Http\Resources\Api\Equipment\EquipmentSlotResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Collection;

class BattlePrepareResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'battle_context_id' => (string) data_get($this->resource, 'battle_context_id', ''),
            'stage_difficulty' => (new BattlePrepareStageDifficultyResource(
                data_get($this->resource, 'stage_difficulty', [])
            ))->resolve($request),
            'character' => (new BattlePrepareCharacterResource(
                data_get($this->resource, 'character', [])
            ))->resolve($request),
            'character_stats' => data_get($this->resource, 'character_stats', []),
            'slot_snapshot' => EquipmentSlotResource::collection(
                Collection::make(data_get($this->resource, 'slot_snapshot', []))
            )->resolve($request),
            'monster_list' => BattlePrepareMonsterResource::collection(
                Collection::make(data_get($this->resource, 'monster_list', []))
            )->resolve($request),
        ];
    }
}
