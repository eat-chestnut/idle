<?php

namespace App\Services\Reward\Domain;

use App\Enums\Reward\GrantStatus;
use App\Enums\Reward\RewardSourceType;
use App\Exceptions\BusinessException;
use App\Models\Reward\RewardGroup;
use App\Models\Reward\RewardGroupBinding;
use App\Models\Reward\UserRewardGrant;
use App\Models\Reward\UserRewardGrantItem;
use App\Support\ErrorCode;
use Throwable;

class RewardGrantService
{
    public function validateRewardGrantContext(array $context): void
    {
        if ((int) data_get($context, 'user_id', 0) <= 0) {
            throw new BusinessException(ErrorCode::REWARD_CONTEXT_INVALID);
        }

        if (data_get($context, 'source_type') !== RewardSourceType::FIRST_CLEAR->value) {
            throw new BusinessException(ErrorCode::REWARD_CONTEXT_INVALID);
        }

        if (! is_string(data_get($context, 'source_id')) || data_get($context, 'source_id') === '') {
            throw new BusinessException(ErrorCode::REWARD_CONTEXT_INVALID);
        }

        if ((int) data_get($context, 'is_cleared', 0) !== 1) {
            throw new BusinessException(ErrorCode::REWARD_CONTEXT_INVALID);
        }

        if (! is_string(data_get($context, 'battle_context_id')) || data_get($context, 'battle_context_id') === '') {
            throw new BusinessException(ErrorCode::REWARD_CONTEXT_INVALID);
        }
    }

    public function assertRewardSourceValid(
        ?RewardGroupBinding $binding,
        ?RewardGroup $rewardGroup
    ): void {
        if ($binding === null) {
            throw new BusinessException(ErrorCode::REWARD_SOURCE_BINDING_NOT_FOUND);
        }

        if ($rewardGroup === null || ! $rewardGroup->is_enabled) {
            throw new BusinessException(ErrorCode::REWARD_GROUP_INVALID);
        }
    }

    public function assertRewardItemsNotEmpty(array $rewardItems): void
    {
        if ($rewardItems === []) {
            throw new BusinessException(ErrorCode::REWARD_GROUP_ITEMS_EMPTY);
        }
    }

    public function assertRewardGrantable(array $context, ?UserRewardGrant $existingGrantStatus = null): void
    {
        if ((int) data_get($context, 'is_cleared', 0) !== 1) {
            throw new BusinessException(ErrorCode::REWARD_CONTEXT_INVALID);
        }

        if ($existingGrantStatus !== null) {
            throw new BusinessException(ErrorCode::REWARD_ALREADY_GRANTED);
        }
    }

    public function buildRewardIdempotencyKey(array $context): string
    {
        return hash('sha256', implode('|', [
            'reward_grant',
            (string) data_get($context, 'user_id'),
            (string) data_get($context, 'source_type'),
            (string) data_get($context, 'source_id'),
            (string) data_get($context, 'battle_context_id'),
        ]));
    }

    public function buildRewardGrantRecordPayload(
        array $context,
        string $rewardGroupId,
        string $idempotencyKey,
        array $rewardItems
    ): array {
        return [
            'user_id' => (int) data_get($context, 'user_id'),
            'reward_group_id' => $rewardGroupId,
            'source_type' => (string) data_get($context, 'source_type'),
            'source_id' => (string) data_get($context, 'source_id'),
            'idempotency_key' => $idempotencyKey,
            'grant_status' => GrantStatus::PENDING->value,
            'grant_payload_snapshot' => [
                'battle_context_id' => (string) data_get($context, 'battle_context_id'),
                'reward_items' => array_map(
                    static fn (mixed $rewardItem): array => [
                        'item_id' => (string) data_get($rewardItem, 'item_id'),
                        'quantity' => (int) data_get($rewardItem, 'quantity', 0),
                        'sort_order' => (int) data_get($rewardItem, 'sort_order', 0),
                    ],
                    $rewardItems
                ),
            ],
        ];
    }

    public function createRewardGrantRecord(array $payload): UserRewardGrant
    {
        try {
            return UserRewardGrant::query()->create($payload);
        } catch (Throwable $throwable) {
            throw new BusinessException(ErrorCode::REWARD_GRANT_RECORD_CREATE_FAILED, previous: $throwable);
        }
    }

    public function buildRewardGrantItemRows(int $rewardGrantId, array $rewardGroupItems): array
    {
        return array_map(
            static fn (mixed $rewardGroupItem): array => [
                'reward_grant_id' => $rewardGrantId,
                'item_id' => (string) data_get($rewardGroupItem, 'item_id'),
                'quantity' => (int) data_get($rewardGroupItem, 'quantity', 0),
                'sort_order' => (int) data_get($rewardGroupItem, 'sort_order', 0),
                'created_at' => now(),
                'updated_at' => now(),
            ],
            $rewardGroupItems
        );
    }

    public function extractRewardItemsFromSnapshot(UserRewardGrant $grantRecord): array
    {
        $snapshotRewardItems = data_get($grantRecord->grant_payload_snapshot, 'reward_items', []);

        if (! is_array($snapshotRewardItems)) {
            return [];
        }

        return array_values(array_filter(
            array_map(
                static fn (mixed $rewardItem): ?array => is_array($rewardItem)
                    && is_string(data_get($rewardItem, 'item_id'))
                    && data_get($rewardItem, 'item_id') !== ''
                    && (int) data_get($rewardItem, 'quantity', 0) > 0
                    ? [
                        'item_id' => (string) data_get($rewardItem, 'item_id'),
                        'quantity' => (int) data_get($rewardItem, 'quantity', 0),
                        'sort_order' => (int) data_get($rewardItem, 'sort_order', 0),
                    ]
                    : null,
                $snapshotRewardItems
            )
        ));
    }

    public function insertRewardGrantItems(array $rows): void
    {
        try {
            UserRewardGrantItem::query()->insert($rows);
        } catch (Throwable $throwable) {
            throw new BusinessException(ErrorCode::REWARD_GRANT_ITEMS_CREATE_FAILED, previous: $throwable);
        }
    }

    public function markRewardGrantSuccess(int $rewardGrantId): void
    {
        $updated = UserRewardGrant::query()
            ->where('reward_grant_id', $rewardGrantId)
            ->update([
                'grant_status' => GrantStatus::SUCCESS->value,
                'granted_at' => now(),
                'updated_at' => now(),
            ]);

        if ($updated !== 1) {
            throw new BusinessException(ErrorCode::REWARD_GRANT_MARK_FAILED);
        }
    }

    public function markRewardGrantFailed(int $rewardGrantId, array $errorMeta = []): void
    {
        $grantRecord = UserRewardGrant::query()->find($rewardGrantId);

        if ($grantRecord === null) {
            throw new BusinessException(ErrorCode::REWARD_GRANT_MARK_FAILED);
        }

        $snapshot = $grantRecord->grant_payload_snapshot;

        if (! is_array($snapshot)) {
            $snapshot = [];
        }

        if ($errorMeta !== []) {
            $snapshot['failure_count'] = max(0, (int) data_get($snapshot, 'failure_count', 0)) + 1;
            $snapshot['last_failure'] = $errorMeta + [
                'failed_at' => now()->format('Y-m-d H:i:s'),
            ];
        }

        $updated = UserRewardGrant::query()
            ->where('reward_grant_id', $rewardGrantId)
            ->update([
                'grant_status' => GrantStatus::FAILED->value,
                'granted_at' => null,
                'grant_payload_snapshot' => $snapshot,
                'updated_at' => now(),
            ]);

        if ($updated !== 1) {
            throw new BusinessException(ErrorCode::REWARD_GRANT_MARK_FAILED);
        }
    }

    public function buildRewardGrantResult(
        UserRewardGrant $grantRecord,
        array $rewardItems,
        array $inventoryResults = [],
        array $instanceResults = []
    ): array {
        return [
            'reward_grant_id' => (int) $grantRecord->reward_grant_id,
            'source_type' => (string) data_get($grantRecord, 'source_type.value', $grantRecord->source_type),
            'source_id' => (string) $grantRecord->source_id,
            'reward_group_id' => (string) $grantRecord->reward_group_id,
            'grant_status' => (string) data_get($grantRecord, 'grant_status.value', $grantRecord->grant_status),
            'reward_items' => array_map(
                static fn ($rewardItem): array => [
                    'item_id' => (string) data_get($rewardItem, 'item_id'),
                    'item_name' => (string) data_get($rewardItem, 'item.item_name', ''),
                    'item_type' => (string) data_get($rewardItem, 'item.item_type.value', data_get($rewardItem, 'item.item_type', '')),
                    'rarity' => (string) data_get($rewardItem, 'item.rarity.value', data_get($rewardItem, 'item.rarity', '')),
                    'icon' => data_get($rewardItem, 'item.icon'),
                    'quantity' => (int) data_get($rewardItem, 'quantity', 0),
                ],
                $rewardItems
            ),
            'inventory_results' => $inventoryResults,
            'created_equipment_instances' => $instanceResults,
            'idempotency_key' => (string) $grantRecord->idempotency_key,
        ];
    }
}
