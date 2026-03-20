<?php

namespace Tests\Feature\Console;

use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Tests\TestCase;

class PhaseOneEnvironmentDiagnoseCommandTest extends TestCase
{
    use RefreshDatabase;

    public function test_phase_one_diagnose_reports_ready_when_seed_and_lock_are_available(): void
    {
        config(['workflow_lock.store' => 'array']);

        $this->seed(DatabaseSeeder::class);

        $exitCode = Artisan::call('phase-one:diagnose', ['--json' => true]);

        $this->assertSame(0, $exitCode);

        $report = json_decode(trim(Artisan::output()), true, 512, JSON_THROW_ON_ERROR);

        $this->assertTrue((bool) data_get($report, 'ready'));
        $this->assertSame('ok', data_get($report, 'status'));
        $this->assertTrue((bool) data_get($report, 'checks.workflow_lock.ready'));
        $this->assertTrue((bool) data_get($report, 'checks.seed_data.ready'));
        $this->assertTrue((bool) data_get($report, 'checks.api_auth.ready'));
        $this->assertTrue((bool) data_get($report, 'checks.routes.ready'));
        $this->assertTrue((bool) data_get($report, 'checks.contract.ready'));
        $this->assertSame([], data_get($report, 'summary.failures'));
    }

    public function test_phase_one_diagnose_reports_missing_seed_and_lock_capability(): void
    {
        config(['workflow_lock.store' => 'null']);

        $exitCode = Artisan::call('phase-one:diagnose', ['--json' => true]);

        $this->assertSame(1, $exitCode);

        $report = json_decode(trim(Artisan::output()), true, 512, JSON_THROW_ON_ERROR);

        $this->assertFalse((bool) data_get($report, 'ready'));
        $this->assertSame('failed', data_get($report, 'status'));
        $this->assertFalse((bool) data_get($report, 'checks.workflow_lock.ready'));
        $this->assertFalse((bool) data_get($report, 'checks.seed_data.ready'));
        $this->assertStringContainsString('NoLock', (string) data_get($report, 'checks.workflow_lock.message'));
        $this->assertStringContainsString('DatabaseSeeder', (string) data_get($report, 'checks.seed_data.message'));
        $this->assertNotEmpty(data_get($report, 'summary.failures'));
    }
}
