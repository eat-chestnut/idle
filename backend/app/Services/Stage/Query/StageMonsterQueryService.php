<?php

namespace App\Services\Stage\Query;

use App\Models\Monster\Monster;
use App\Models\Stage\StageMonsterBinding;
use Illuminate\Database\Eloquent\Collection;

class StageMonsterQueryService
{
    public function getStageMonsterBindings(string $stageDifficultyId): Collection
    {
        return StageMonsterBinding::query()
            ->where('stage_difficulty_id', $stageDifficultyId)
            ->orderBy('wave_no')
            ->orderBy('sort_order')
            ->get();
    }

    public function getMonsterMapByIds(array $monsterIds): array
    {
        if ($monsterIds === []) {
            return [];
        }

        return Monster::query()
            ->whereIn('monster_id', array_values(array_unique($monsterIds)))
            ->where('is_enabled', true)
            ->get()
            ->keyBy('monster_id')
            ->all();
    }
}
