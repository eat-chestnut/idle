<?php

namespace App\Services\Reward\Query;

use App\Enums\Reward\GrantStatus;
use App\Models\Reward\UserRewardGrant;

class RewardGrantQueryService
{
    public function getRewardGrantById(int $rewardGrantId, bool $forUpdate = false): ?UserRewardGrant
    {
        $query = UserRewardGrant::query()
            ->with(['items.item', 'rewardGroup'])
            ->where('reward_grant_id', $rewardGrantId);

        if ($forUpdate) {
            $query->lockForUpdate();
        }

        return $query->first();
    }

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

    public function getExistingSuccessfulGrantExcept(
        int $userId,
        string $sourceType,
        string $sourceId,
        int $exceptRewardGrantId
    ): ?UserRewardGrant {
        return UserRewardGrant::query()
            ->with(['items.item', 'rewardGroup'])
            ->where('user_id', $userId)
            ->where('source_type', $sourceType)
            ->where('source_id', $sourceId)
            ->where('grant_status', GrantStatus::SUCCESS->value)
            ->where('reward_grant_id', '!=', $exceptRewardGrantId)
            ->orderByDesc('reward_grant_id')
            ->first();
    }

    public function getLatestGrantBySource(int $userId, string $sourceType, string $sourceId): ?UserRewardGrant
    {
        return UserRewardGrant::query()
            ->with(['items.item', 'rewardGroup'])
            ->where('user_id', $userId)
            ->where('source_type', $sourceType)
            ->where('source_id', $sourceId)
            ->orderByDesc('reward_grant_id')
            ->first();
    }
}
