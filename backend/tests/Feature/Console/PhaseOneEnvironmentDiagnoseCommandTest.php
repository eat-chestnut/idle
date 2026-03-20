<?php

namespace Tests\Feature\Console;

use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
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
        $this->assertTrue((bool) data_get($report, 'checks.api_cors.ready'));
        $this->assertTrue((bool) data_get($report, 'checks.routes.ready'));
        $this->assertTrue((bool) data_get($report, 'checks.contract.ready'));
        $this->assertTrue((bool) data_get($report, 'profiles.service.ready'));
        $this->assertTrue((bool) data_get($report, 'profiles.interop.ready'));
        $this->assertTrue((bool) data_get($report, 'profiles.acceptance.ready'));
        $this->assertSame([], data_get($report, 'summary.failures'));
    }

    public function test_phase_one_diagnose_reports_missing_seed_and_lock_capability(): void
    {
        config(['app.key' => null]);
        config(['workflow_lock.store' => 'null']);

        $exitCode = Artisan::call('phase-one:diagnose', ['--json' => true]);

        $this->assertSame(1, $exitCode);

        $report = json_decode(trim(Artisan::output()), true, 512, JSON_THROW_ON_ERROR);

        $this->assertFalse((bool) data_get($report, 'ready'));
        $this->assertSame('failed', data_get($report, 'status'));
        $this->assertFalse((bool) data_get($report, 'checks.app_key.ready'));
        $this->assertFalse((bool) data_get($report, 'checks.workflow_lock.ready'));
        $this->assertFalse((bool) data_get($report, 'checks.seed_data.ready'));
        $this->assertStringContainsString('APP_KEY', (string) data_get($report, 'checks.app_key.message'));
        $this->assertStringContainsString('NoLock', (string) data_get($report, 'checks.workflow_lock.message'));
        $this->assertStringContainsString('DatabaseSeeder', (string) data_get($report, 'checks.seed_data.message'));
        $this->assertNotEmpty(data_get($report, 'summary.failures'));
    }

    public function test_phase_one_diagnose_can_distinguish_interop_and_acceptance_profiles(): void
    {
        config(['workflow_lock.store' => 'array']);

        $this->seed(DatabaseSeeder::class);
        DB::table('admin_users')->delete();

        $interopExitCode = Artisan::call('phase-one:diagnose', ['--json' => true]);
        $interopReport = json_decode(trim(Artisan::output()), true, 512, JSON_THROW_ON_ERROR);

        $this->assertSame(0, $interopExitCode);
        $this->assertTrue((bool) data_get($interopReport, 'ready'));
        $this->assertTrue((bool) data_get($interopReport, 'profiles.interop.ready'));
        $this->assertFalse((bool) data_get($interopReport, 'profiles.acceptance.ready'));
        $this->assertFalse((bool) data_get($interopReport, 'checks.admin_bootstrap.ready'));

        $acceptanceExitCode = Artisan::call('phase-one:diagnose', [
            '--json' => true,
            '--profile' => 'acceptance',
        ]);

        $acceptanceReport = json_decode(trim(Artisan::output()), true, 512, JSON_THROW_ON_ERROR);

        $this->assertSame(1, $acceptanceExitCode);
        $this->assertSame('acceptance', data_get($acceptanceReport, 'selected_profile'));
        $this->assertFalse((bool) data_get($acceptanceReport, 'ready'));
        $this->assertStringContainsString('后台管理员未初始化', (string) data_get($acceptanceReport, 'checks.admin_bootstrap.message'));
    }
}
