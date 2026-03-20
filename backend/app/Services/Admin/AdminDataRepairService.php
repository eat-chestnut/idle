<?php

namespace App\Services\Admin;

use App\Enums\Battle\BattleContextStatus;
use App\Enums\Reward\GrantStatus;
use App\Exceptions\BusinessException;
use App\Models\Battle\BattleContext;
use App\Models\Reward\UserRewardGrant;
use App\Support\ErrorCode;
use Illuminate\Support\Facades\Log;

class AdminDataRepairService
{
    public function repairBattleContext(string $battleContextId, array $operator = []): array
    {
        $battleContext = BattleContext::query()->find($battleContextId);

        if ($battleContext === null) {
            throw new BusinessException(ErrorCode::RESOURCE_NOT_FOUND, 'Battle Context 不存在');
        }

        $before = $this->buildBattleContextSnapshot($battleContext);
        $status = (string) data_get($battleContext, 'status.value', $battleContext->status);

        if ($status === BattleContextStatus::PREPARED->value && $battleContext->settled_at !== null) {
            $battleContext->forceFill([
                'status' => BattleContextStatus::SETTLED->value,
            ])->save();

            $action = 'prepared_to_settled';
        } elseif ($status === BattleContextStatus::SETTLED->value && $battleContext->settled_at === null) {
            $battleContext->forceFill([
                'settled_at' => $battleContext->updated_at ?? $battleContext->created_at ?? now(),
            ])->save();

            $action = 'fill_missing_settled_at';
        } else {
            throw new BusinessException(ErrorCode::ADMIN_OPERATION_FORBIDDEN, '当前 battle_context 不属于允许修复的安全场景');
        }

        $battleContext->refresh();
        $after = $this->buildBattleContextSnapshot($battleContext);

        Log::info('admin battle context repaired', [
            'admin_user_id' => data_get($operator, 'admin_user_id'),
            'admin_username' => data_get($operator, 'admin_username'),
            'battle_context_id' => $battleContextId,
            'repair_action' => $action,
            'before' => $before,
            'after' => $after,
        ]);

        return [
            'entity' => 'battle_context',
            'repair_action' => $action,
            'before' => $before,
            'after' => $after,
        ];
    }

    public function repairRewardGrant(int $rewardGrantId, array $operator = []): array
    {
        $rewardGrant = UserRewardGrant::query()
            ->with('items')
            ->find($rewardGrantId);

        if ($rewardGrant === null) {
            throw new BusinessException(ErrorCode::RESOURCE_NOT_FOUND, '发奖记录不存在');
        }

        $before = $this->buildRewardGrantSnapshot($rewardGrant);
        $grantStatus = (string) data_get($rewardGrant, 'grant_status.value', $rewardGrant->grant_status);

        if ($grantStatus === GrantStatus::SUCCESS->value && $rewardGrant->granted_at === null) {
            $rewardGrant->forceFill([
                'granted_at' => $rewardGrant->updated_at ?? $rewardGrant->created_at ?? now(),
            ])->save();

            $action = 'fill_missing_granted_at';
        } elseif ($grantStatus === GrantStatus::FAILED->value && $rewardGrant->granted_at !== null) {
            $rewardGrant->forceFill([
                'granted_at' => null,
            ])->save();

            $action = 'clear_failed_granted_at';
        } elseif (
            $grantStatus === GrantStatus::PENDING->value
            && $rewardGrant->granted_at !== null
            && $rewardGrant->items->isNotEmpty()
        ) {
            $rewardGrant->forceFill([
                'grant_status' => GrantStatus::SUCCESS->value,
            ])->save();

            $action = 'pending_to_success';
        } else {
            throw new BusinessException(ErrorCode::ADMIN_OPERATION_FORBIDDEN, '当前发奖记录不属于允许修复的安全场景');
        }

        $rewardGrant->refresh()->loadMissing('items');
        $after = $this->buildRewardGrantSnapshot($rewardGrant);

        Log::info('admin reward grant repaired', [
            'admin_user_id' => data_get($operator, 'admin_user_id'),
            'admin_username' => data_get($operator, 'admin_username'),
            'reward_grant_id' => $rewardGrantId,
            'repair_action' => $action,
            'before' => $before,
            'after' => $after,
        ]);

        return [
            'entity' => 'reward_grant',
            'repair_action' => $action,
            'before' => $before,
            'after' => $after,
        ];
    }

    private function buildBattleContextSnapshot(BattleContext $battleContext): array
    {
        return [
            'battle_context_id' => (string) $battleContext->battle_context_id,
            'status' => (string) data_get($battleContext, 'status.value', $battleContext->status),
            'settled_at' => optional($battleContext->settled_at)->format('Y-m-d H:i:s'),
            'updated_at' => optional($battleContext->updated_at)->format('Y-m-d H:i:s'),
        ];
    }

    private function buildRewardGrantSnapshot(UserRewardGrant $rewardGrant): array
    {
        return [
            'reward_grant_id' => (int) $rewardGrant->reward_grant_id,
            'grant_status' => (string) data_get($rewardGrant, 'grant_status.value', $rewardGrant->grant_status),
            'granted_at' => optional($rewardGrant->granted_at)->format('Y-m-d H:i:s'),
            'items_count' => $rewardGrant->items->count(),
            'updated_at' => optional($rewardGrant->updated_at)->format('Y-m-d H:i:s'),
        ];
    }
}
