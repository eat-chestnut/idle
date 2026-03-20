<?php

namespace Tests\Unit\Support;

use App\Support\Lock\WorkflowLockService;
use Tests\TestCase;

class WorkflowLockServiceTest extends TestCase
{
    public function test_diagnose_reports_available_lock_for_testing_array_store(): void
    {
        config(['workflow_lock.store' => 'array']);

        $report = $this->app->make(WorkflowLockService::class)->diagnose();

        $this->assertTrue((bool) data_get($report, 'available'));
        $this->assertSame('ok', data_get($report, 'status'));
        $this->assertSame('array', data_get($report, 'store'));
    }

    public function test_diagnose_reports_no_lock_store_as_unavailable(): void
    {
        config(['workflow_lock.store' => 'null']);

        $report = $this->app->make(WorkflowLockService::class)->diagnose();

        $this->assertFalse((bool) data_get($report, 'available'));
        $this->assertSame('failed', data_get($report, 'status'));
        $this->assertStringContainsString('NoLock', (string) data_get($report, 'message'));
    }
}
