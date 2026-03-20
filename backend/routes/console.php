<?php

use App\Services\Admin\AdminEnvironmentDiagnosisService;
use App\Services\Admin\PhaseOneContractDriftGuardService;
use App\Support\Lock\WorkflowLockService;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('workflow-lock:check {--json : 以 JSON 输出诊断结果}', function (): int {
    $report = app(WorkflowLockService::class)->diagnose();

    if ((bool) $this->option('json')) {
        $this->line(json_encode($report, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));

        return (bool) data_get($report, 'available', false) ? 0 : 1;
    }

    $this->table(['key', 'value'], [
        ['status', (string) data_get($report, 'status')],
        ['available', (bool) data_get($report, 'available', false) ? 'yes' : 'no'],
        ['app_env', (string) data_get($report, 'app_env')],
        ['store', (string) data_get($report, 'store')],
        ['store_class', (string) data_get($report, 'store_class')],
        ['lock_class', (string) data_get($report, 'lock_class')],
        ['first_acquired', data_get($report, 'first_acquired') ? 'yes' : 'no'],
        ['second_acquired', data_get($report, 'second_acquired') === null ? 'n/a' : (data_get($report, 'second_acquired') ? 'yes' : 'no')],
        ['message', (string) data_get($report, 'message')],
        ['exception', (string) data_get($report, 'exception')],
    ]);

    if ((bool) data_get($report, 'available', false)) {
        $this->info('workflow lock check passed');

        return 0;
    }

    $this->error('workflow lock check failed');

    return 1;
})->purpose('Check workflow lock capability for critical battle/reward flows');

Artisan::command('phase-one:diagnose
    {--json : 以 JSON 输出第一阶段联调诊断结果}
    {--profile=interop : 诊断维度，可选 service / interop / acceptance}', function (): int {
    $profile = (string) $this->option('profile');
    $report = app(AdminEnvironmentDiagnosisService::class)->diagnose($profile);

    if ((bool) $this->option('json')) {
        $this->line(json_encode($report, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));

        return (bool) data_get($report, 'ready', false) ? 0 : 1;
    }

    $this->line(sprintf('selected_profile: %s', (string) data_get($report, 'selected_profile', $profile)));

    $profileRows = [];

    foreach ((array) data_get($report, 'profiles', []) as $name => $profileReport) {
        $profileRows[] = [
            $name,
            (bool) data_get($profileReport, 'ready', false) ? 'ok' : 'failed',
            (string) data_get($profileReport, 'message', ''),
        ];
    }

    $this->table(['profile', 'status', 'message'], $profileRows);

    $rows = [];

    foreach ((array) data_get($report, 'checks', []) as $name => $check) {
        $rows[] = [
            $name,
            (bool) data_get($check, 'ready', false) ? 'ok' : 'failed',
            (string) data_get($check, 'message', ''),
        ];
    }

    $this->table(['check', 'status', 'message'], $rows);

    $failures = (array) data_get($report, 'summary.failures', []);
    $warnings = (array) data_get($report, 'summary.warnings', []);

    foreach ($warnings as $warning) {
        $this->warn((string) $warning);
    }

    if ($failures === []) {
        $this->info('phase-one diagnosis passed');

        return 0;
    }

    foreach ($failures as $failure) {
        $this->error((string) $failure);
    }

    $this->error('phase-one diagnosis failed');

    return 1;
})->purpose('Diagnose phase-one frontend API interop readiness');

Artisan::command('phase-one:contract-drift-check
    {--json : 以 JSON 输出 phase-one API 契约防漂移检查结果}', function (): int {
    $report = app(PhaseOneContractDriftGuardService::class)->check();

    if ((bool) $this->option('json')) {
        $this->line(json_encode($report, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));

        return (bool) data_get($report, 'ready', false) ? 0 : 1;
    }

    $this->line(sprintf('actual_route_count: %d', (int) data_get($report, 'actual_route_count', 0)));
    $this->line(sprintf('openapi: %s', (string) data_get($report, 'contract_sources.openapi')));
    $this->line(sprintf('formal_doc: %s', (string) data_get($report, 'contract_sources.formal_doc')));

    $rows = [];

    foreach ((array) data_get($report, 'checks', []) as $name => $check) {
        $rows[] = [
            $name,
            (bool) data_get($check, 'ok', false) ? 'ok' : 'failed',
            (string) data_get($check, 'message', ''),
        ];
    }

    $this->table(['check', 'status', 'message'], $rows);

    $failures = (array) data_get($report, 'summary.failures', []);

    if ($failures === []) {
        $this->info('phase-one contract drift check passed');

        return 0;
    }

    foreach ($failures as $failure) {
        $this->error((string) $failure);
    }

    $this->error('phase-one contract drift check failed');

    return 1;
})->purpose('Guard phase-one frontend API contract against route/request/doc drift');
