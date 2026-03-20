<?php

namespace App\Services\Reward\Query;

use App\Enums\Reward\GrantStatus;
use App\Models\Reward\UserRewardGrant;

class RewardGrantQueryService
{
    public function getRewardGrantByIdempotencyKey(int $userId, string $idempotencyKey): ?UserRewardGrant
    {
        return UserRewardGrant::query()
            ->with(['items.item', 'rewardGroup'])
            ->where('user_id', $userId)
            ->where('idempotency_key', $idempotencyKey)
            ->first();
    }

    public function getExistingSuccessfulGrant(int $userId, string $sourceType, string $sourceId): ?UserRewardGrant
    {
        return UserRewardGrant::query()
            ->with(['items.item', 'rewardGroup'])
            ->where('user_id', $userId)
            ->where('source_type', $sourceType)
            ->where('source_id', $sourceId)
            ->where('grant_status', GrantStatus::SUCCESS->value)
            ->orderByDesc('reward_grant_id')
            ->first();
    }
}
