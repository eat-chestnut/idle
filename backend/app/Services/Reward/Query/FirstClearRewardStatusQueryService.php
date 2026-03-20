<?php

namespace App\Services\Reward\Query;

use App\Enums\Reward\GrantStatus;
use App\Enums\Reward\RewardSourceType;
use App\Exceptions\BusinessException;
use App\Models\Reward\RewardGroupBinding;
use App\Models\Reward\UserRewardGrant;
use App\Support\ErrorCode;
use Illuminate\Support\Collection;
use Throwable;

class FirstClearRewardStatusQueryService
{
    public function getSummaryMap(int $userId, array $bindingMap): array
    {
        try {
            $grantGroups = $this->getGrantGroups($userId, array_keys($bindingMap));
            $summaryMap = [];

            foreach ($bindingMap as $sourceId => $binding) {
                $summaryMap[$sourceId] = $this->buildSummaryPayload(
                    $binding,
                    $this->resolveGrantForBinding($grantGroups->get($sourceId, collect()), $binding)
                );
            }

            return $summaryMap;
        } catch (Throwable $throwable) {
            throw new BusinessException(ErrorCode::FIRST_CLEAR_REWARD_STATUS_QUERY_FAILED, previous: $throwable);
        }
    }

    public function getStatus(int $userId, string $sourceId, ?RewardGroupBinding $binding): array
    {
        if ($binding === null) {
            return [
                'source_type' => RewardSourceType::FIRST_CLEAR->value,
                'source_id' => $sourceId,
                'has_reward' => 0,
                'reward_group_id' => null,
                'has_granted' => 0,
                'grant_status' => null,
            ];
        }

        try {
            $grant = $this->resolveGrantForBinding(
                $this->getGrantGroups($userId, [$sourceId])->get($sourceId, collect()),
                $binding
            );

            return [
                'source_type' => RewardSourceType::FIRST_CLEAR->value,
                'source_id' => $sourceId,
                ...$this->buildSummaryPayload($binding, $grant),
            ];
        } catch (Throwable $throwable) {
            throw new BusinessException(ErrorCode::FIRST_CLEAR_REWARD_STATUS_QUERY_FAILED, previous: $throwable);
        }
    }

    private function getGrantGroups(int $userId, array $sourceIds): Collection
    {
        if ($sourceIds === []) {
            return collect();
        }

        return UserRewardGrant::query()
            ->where('user_id', $userId)
            ->where('source_type', RewardSourceType::FIRST_CLEAR->value)
            ->whereIn('source_id', $sourceIds)
            ->orderByDesc('reward_grant_id')
            ->get()
            ->groupBy('source_id');
    }

    private function resolveGrantForBinding(Collection $grants, RewardGroupBinding $binding): ?UserRewardGrant
    {
        if ($grants->isEmpty()) {
            return null;
        }

        return $grants->first(
            static fn (UserRewardGrant $grant): bool => (string) $grant->reward_group_id === (string) $binding->reward_group_id
        );
    }

    private function buildSummaryPayload(RewardGroupBinding $binding, ?UserRewardGrant $grant): array
    {
        $grantStatus = $grant === null
            ? null
            : $this->normalizeGrantStatus($grant->grant_status);

        return [
            'has_reward' => 1,
            'reward_group_id' => (string) $binding->reward_group_id,
            'has_granted' => $grantStatus === GrantStatus::SUCCESS->value ? 1 : 0,
            'grant_status' => $grantStatus,
        ];
    }

    private function normalizeGrantStatus(mixed $grantStatus): ?string
    {
        if ($grantStatus instanceof GrantStatus) {
            return $grantStatus->value;
        }

        return $grantStatus === null ? null : (string) $grantStatus;
    }
}
