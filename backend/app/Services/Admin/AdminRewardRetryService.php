<?php

namespace App\Services\Admin;

use App\Exceptions\BusinessException;
use App\Models\Reward\UserRewardGrant;
use App\Services\Reward\Query\RewardGrantQueryService;
use App\Services\Reward\Workflow\RewardGrantWorkflow;
use App\Support\ErrorCode;
use Illuminate\Support\Facades\Log;

class AdminRewardRetryService
{
    public function __construct(
        private readonly RewardGrantQueryService $rewardGrantQueryService,
        private readonly RewardGrantWorkflow $rewardGrantWorkflow,
    ) {
    }

    public function retry(array $input, array $operator = []): array
    {
        $grantRecord = $this->resolveGrantRecord($input);

        if ($grantRecord === null) {
            throw new BusinessException(ErrorCode::RESOURCE_NOT_FOUND, '发奖记录不存在');
        }

        $grantStatus = (string) data_get($grantRecord, 'grant_status.value', $grantRecord->grant_status);

        if ($grantStatus !== 'failed') {
            throw new BusinessException(ErrorCode::ADMIN_OPERATION_FORBIDDEN, '仅允许对 failed 发奖记录执行补发');
        }

        $result = $this->rewardGrantWorkflow->retryGrant((int) $grantRecord->reward_grant_id);

        Log::info('admin reward retry executed', [
            'admin_user_id' => data_get($operator, 'admin_user_id'),
            'admin_username' => data_get($operator, 'admin_username'),
            'reward_grant_id' => (int) $grantRecord->reward_grant_id,
            'lookup_mode' => $this->resolveLookupMode($input),
            'source_type' => (string) data_get($grantRecord, 'source_type.value', $grantRecord->source_type),
            'source_id' => (string) $grantRecord->source_id,
            'result_grant_status' => data_get($result, 'grant_status'),
        ]);

        return [
            'lookup_mode' => $this->resolveLookupMode($input),
            'target' => $this->buildGrantSummary($grantRecord),
            'result' => $result,
        ];
    }

    private function resolveGrantRecord(array $input): ?UserRewardGrant
    {
        $rewardGrantId = (int) ($input['reward_grant_id'] ?? 0);

        if ($rewardGrantId > 0) {
            return $this->rewardGrantQueryService->getRewardGrantById($rewardGrantId);
        }

        $userId = (int) ($input['user_id'] ?? 0);
        $sourceType = (string) ($input['source_type'] ?? '');
        $sourceId = (string) ($input['source_id'] ?? '');

        if ($userId <= 0 || $sourceType === '' || $sourceId === '') {
            throw new BusinessException(ErrorCode::ADMIN_REWARD_RETRY_FAILED, '补发条件不完整');
        }

        return $this->rewardGrantQueryService->getLatestGrantBySource($userId, $sourceType, $sourceId);
    }

    private function buildGrantSummary(UserRewardGrant $grantRecord): array
    {
        return [
            'reward_grant_id' => (int) $grantRecord->reward_grant_id,
            'user_id' => (int) $grantRecord->user_id,
            'source_type' => (string) data_get($grantRecord, 'source_type.value', $grantRecord->source_type),
            'source_id' => (string) $grantRecord->source_id,
            'reward_group_id' => (string) $grantRecord->reward_group_id,
            'grant_status' => (string) data_get($grantRecord, 'grant_status.value', $grantRecord->grant_status),
        ];
    }

    private function resolveLookupMode(array $input): string
    {
        return (int) ($input['reward_grant_id'] ?? 0) > 0 ? 'reward_grant_id' : 'business_source';
    }
}
