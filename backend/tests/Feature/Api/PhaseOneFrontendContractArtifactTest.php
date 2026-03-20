<?php

namespace Tests\Feature\Api;

use App\Services\Admin\PhaseOneContractDriftGuardService;
use Illuminate\Support\Facades\Artisan;
use Tests\TestCase;

class PhaseOneFrontendContractArtifactTest extends TestCase
{
    public function test_phase_one_contract_drift_guard_reports_current_contract_sources_in_sync(): void
    {
        $report = app(PhaseOneContractDriftGuardService::class)->check();

        $this->assertTrue((bool) data_get($report, 'ready'));
        $this->assertSame('ok', data_get($report, 'status'));
        $this->assertCount(14, (array) data_get($report, 'actual_routes', []));
        $this->assertTrue((bool) data_get($report, 'checks.openapi_routes.ok'));
        $this->assertTrue((bool) data_get($report, 'checks.openapi_request_fields.ok'));
        $this->assertTrue((bool) data_get($report, 'checks.formal_doc_routes.ok'));
        $this->assertTrue((bool) data_get($report, 'checks.auth_contract.ok'));
        $this->assertTrue((bool) data_get($report, 'checks.response_envelope.ok'));
        $this->assertSame([], data_get($report, 'summary.failures'));
    }

    public function test_phase_one_contract_drift_check_command_outputs_json_report(): void
    {
        $exitCode = Artisan::call('phase-one:contract-drift-check', ['--json' => true]);

        $this->assertSame(0, $exitCode);

        $report = json_decode(trim(Artisan::output()), true, 512, JSON_THROW_ON_ERROR);

        $this->assertTrue((bool) data_get($report, 'ready'));
        $this->assertSame('ok', data_get($report, 'status'));
        $this->assertSame(
            'php artisan phase-one:contract-drift-check --json',
            data_get($report, 'summary.commands.contract_drift_check')
        );
    }
}
