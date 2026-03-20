<?php

namespace App\Services\Reward\Config;

use App\Models\Reward\RewardGroup;
use App\Models\Reward\RewardGroupBinding;
use App\Models\Reward\RewardGroupItem;

class RewardConfigService
{
    public function getRewardBindingBySource(string $sourceType, string $sourceId): ?RewardGroupBinding
    {
        return RewardGroupBinding::query()
            ->with('rewardGroup')
            ->where('source_type', $sourceType)
            ->where('source_id', $sourceId)
            ->whereHas('rewardGroup', static fn ($query) => $query->where('is_enabled', true))
            ->first();
    }

    public function getRewardGroupById(string $rewardGroupId): ?RewardGroup
    {
        return RewardGroup::query()
            ->where('reward_group_id', $rewardGroupId)
            ->where('is_enabled', true)
            ->first();
    }

    public function getRewardGroupItemsByGroupId(string $rewardGroupId): array
    {
        return RewardGroupItem::query()
            ->with('item')
            ->where('reward_group_id', $rewardGroupId)
            ->orderBy('sort_order')
            ->get()
            ->all();
    }
}
