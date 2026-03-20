<?php

namespace Tests\Feature\Console;

use Illuminate\Support\Facades\Artisan;
use Tests\TestCase;

class WorkflowLockCheckCommandTest extends TestCase
{
    public function test_workflow_lock_check_command_reports_available_store(): void
    {
        config(['workflow_lock.store' => 'array']);

        $exitCode = Artisan::call('workflow-lock:check', ['--json' => true]);

        $this->assertSame(0, $exitCode);

        $report = json_decode(trim(Artisan::output()), true, 512, JSON_THROW_ON_ERROR);

        $this->assertTrue((bool) data_get($report, 'available'));
        $this->assertSame('array', data_get($report, 'store'));
        $this->assertSame('ok', data_get($report, 'status'));
    }

    public function test_workflow_lock_check_command_reports_null_store_as_unavailable(): void
    {
        config(['workflow_lock.store' => 'null']);

        $exitCode = Artisan::call('workflow-lock:check', ['--json' => true]);

        $this->assertSame(1, $exitCode);

        $report = json_decode(trim(Artisan::output()), true, 512, JSON_THROW_ON_ERROR);

        $this->assertFalse((bool) data_get($report, 'available'));
        $this->assertSame('null', data_get($report, 'store'));
        $this->assertStringContainsString('NoLock', (string) data_get($report, 'message'));
    }
}
