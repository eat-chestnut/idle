<?php

namespace App\Services\Reward\Config;

use App\Enums\Reward\RewardSourceType;
use App\Models\Reward\RewardGroupBinding;

class FirstClearRewardConfigService
{
    public function getEnabledBindingBySourceId(string $sourceId): ?RewardGroupBinding
    {
        return RewardGroupBinding::query()
            ->with('rewardGroup')
            ->where('source_type', RewardSourceType::FIRST_CLEAR->value)
            ->where('source_id', $sourceId)
            ->whereHas('rewardGroup', static fn ($query) => $query->where('is_enabled', true))
            ->first();
    }

    public function getEnabledBindingMapBySourceIds(array $sourceIds): array
    {
        if ($sourceIds === []) {
            return [];
        }

        return RewardGroupBinding::query()
            ->with('rewardGroup')
            ->where('source_type', RewardSourceType::FIRST_CLEAR->value)
            ->whereIn('source_id', array_values(array_unique($sourceIds)))
            ->whereHas('rewardGroup', static fn ($query) => $query->where('is_enabled', true))
            ->get()
            ->keyBy('source_id')
            ->all();
    }
}
