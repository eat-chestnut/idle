<?php

namespace App\Support\Lock;

use App\Exceptions\BusinessException;
use App\Support\ErrorCode;
use Illuminate\Cache\ArrayStore;
use Illuminate\Cache\NoLock;
use Illuminate\Contracts\Cache\Lock;
use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Contracts\Cache\Repository;
use Illuminate\Support\Facades\Cache;
use Throwable;

class WorkflowLockService
{
    public function withBattleSettlementLock(string $battleContextId, callable $callback): mixed
    {
        return $this->withLock(
            $this->battleSettlementKey($battleContextId),
            10,
            0,
            ErrorCode::TOO_MANY_REQUESTS,
            '战斗结算正在处理中，请勿重复提交',
            $callback
        );
    }

    public function withRewardGrantLock(int $userId, string $sourceType, string $sourceId, callable $callback): mixed
    {
        return $this->withLock(
            $this->rewardGrantKey($userId, $sourceType, $sourceId),
            10,
            3,
            ErrorCode::TOO_MANY_REQUESTS,
            '奖励发放正在处理中，请稍后重试',
            $callback
        );
    }

    public function withRewardRetryLock(int $rewardGrantId, callable $callback): mixed
    {
        return $this->withLock(
            $this->rewardRetryKey($rewardGrantId),
            10,
            0,
            ErrorCode::TOO_MANY_REQUESTS,
            '奖励补发正在处理中，请勿重复提交',
            $callback
        );
    }

    public function battleSettlementKey(string $battleContextId): string
    {
        return $this->formatKey('battle_settlement', $battleContextId);
    }

    public function rewardGrantKey(int $userId, string $sourceType, string $sourceId): string
    {
        return $this->formatKey('reward_grant', implode(':', [$userId, $sourceType, $sourceId]));
    }

    public function rewardRetryKey(int $rewardGrantId): string
    {
        return $this->formatKey('reward_retry', (string) $rewardGrantId);
    }

    public function diagnose(): array
    {
        $report = [
            'status' => 'failed',
            'available' => false,
            'app_env' => app()->environment(),
            'store' => $this->storeName(),
            'store_class' => null,
            'lock_class' => null,
            'first_acquired' => false,
            'second_acquired' => null,
            'message' => '',
            'exception' => null,
        ];

        $firstLock = null;
        $secondLock = null;
        $firstAcquired = false;
        $secondAcquired = false;
        $diagnosticKey = $this->formatKey('diagnostic', sprintf('%s:%s', now()->format('YmdHis'), uniqid('', true)));

        try {
            $repository = $this->resolveStore();
            $store = $repository->getStore();

            $report['store_class'] = $store::class;

            if ($store instanceof ArrayStore && ! app()->environment('testing')) {
                throw new BusinessException(
                    ErrorCode::LOCK_CAPABILITY_UNAVAILABLE,
                    sprintf('workflow lock store [%s] 使用 array，仅允许 testing 环境使用', $this->storeName())
                );
            }

            $firstLock = $repository->lock($diagnosticKey, 5);
            $report['lock_class'] = $firstLock::class;

            if ($firstLock instanceof NoLock) {
                throw new BusinessException(
                    ErrorCode::LOCK_CAPABILITY_UNAVAILABLE,
                    sprintf('workflow lock store [%s] 返回 NoLock，无法提供正式互斥能力', $this->storeName())
                );
            }

            $firstAcquired = $firstLock->get();
            $report['first_acquired'] = $firstAcquired;

            if (! $firstAcquired) {
                throw new BusinessException(
                    ErrorCode::LOCK_CAPABILITY_UNAVAILABLE,
                    'workflow lock 自检失败：首次获取锁未成功'
                );
            }

            $secondLock = $repository->lock($diagnosticKey, 5);
            $secondAcquired = $secondLock->get();
            $report['second_acquired'] = $secondAcquired;

            if ($secondAcquired) {
                throw new BusinessException(
                    ErrorCode::LOCK_CAPABILITY_UNAVAILABLE,
                    'workflow lock 自检失败：同 key 第二次获取未被阻止'
                );
            }

            $report['status'] = 'ok';
            $report['available'] = true;
            $report['message'] = $store instanceof ArrayStore
                ? 'workflow lock 自检通过；testing 环境允许 array store，部署环境请使用共享 store'
                : 'workflow lock 自检通过';
        } catch (BusinessException $exception) {
            $report['message'] = $exception->getMessage();
            $report['exception'] = sprintf('%s (%d)', $exception->getMessage(), $exception->getErrorCode());
        } catch (Throwable $throwable) {
            $report['message'] = 'workflow lock 自检失败';
            $report['exception'] = sprintf('%s: %s', $throwable::class, $throwable->getMessage());
        } finally {
            if ($secondAcquired) {
                try {
                    $secondLock?->release();
                } catch (Throwable) {
                }
            }

            if ($firstAcquired) {
                try {
                    $firstLock?->release();
                } catch (Throwable) {
                }
            }
        }

        return $report;
    }

    private function withLock(
        string $key,
        int $seconds,
        int $waitSeconds,
        int $busyErrorCode,
        string $busyMessage,
        callable $callback
    ): mixed {
        $lock = $this->createLock($key, $seconds);
        $acquired = false;

        try {
            try {
                $acquired = $waitSeconds > 0
                    ? (bool) $lock->block($waitSeconds)
                    : (bool) $lock->get();
            } catch (LockTimeoutException) {
                throw new BusinessException($busyErrorCode, $busyMessage);
            } catch (Throwable $throwable) {
                throw $this->buildCapabilityException($throwable);
            }

            if (! $acquired) {
                throw new BusinessException($busyErrorCode, $busyMessage);
            }

            return $callback();
        } finally {
            if ($acquired) {
                try {
                    $lock->release();
                } catch (Throwable) {
                }
            }
        }
    }

    private function createLock(string $key, int $seconds): Lock
    {
        try {
            $repository = $this->resolveStore();
            $store = $repository->getStore();

            if ($store instanceof ArrayStore && ! app()->environment('testing')) {
                throw new BusinessException(
                    ErrorCode::LOCK_CAPABILITY_UNAVAILABLE,
                    sprintf('workflow lock store [%s] 使用 array，仅允许 testing 环境使用', $this->storeName())
                );
            }

            $lock = $repository->lock($key, $seconds);

            if ($lock instanceof NoLock) {
                throw new BusinessException(
                    ErrorCode::LOCK_CAPABILITY_UNAVAILABLE,
                    sprintf('workflow lock store [%s] 返回 NoLock，无法提供正式互斥能力', $this->storeName())
                );
            }

            return $lock;
        } catch (BusinessException $exception) {
            throw $exception;
        } catch (Throwable $throwable) {
            throw $this->buildCapabilityException($throwable);
        }
    }

    private function resolveStore(): Repository
    {
        return Cache::store($this->storeName());
    }

    private function storeName(): string
    {
        return (string) config('workflow_lock.store', config('cache.default'));
    }

    private function prefix(): string
    {
        return trim((string) config('workflow_lock.prefix', 'workflow_lock'), ':');
    }

    private function formatKey(string $scope, string $subject): string
    {
        return sprintf('%s:%s:%s', $this->prefix(), $scope, $subject);
    }

    private function buildCapabilityException(Throwable $throwable): BusinessException
    {
        return new BusinessException(
            ErrorCode::LOCK_CAPABILITY_UNAVAILABLE,
            sprintf('workflow lock 不可用，请检查 cache store [%s] 的 lock 能力', $this->storeName()),
            $throwable
        );
    }
}
