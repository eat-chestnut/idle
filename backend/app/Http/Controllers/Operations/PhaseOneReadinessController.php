<?php

namespace App\Http\Controllers\Operations;

use App\Http\Controllers\Controller;
use App\Services\Admin\AdminEnvironmentDiagnosisService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PhaseOneReadinessController extends Controller
{
    public function __invoke(Request $request, AdminEnvironmentDiagnosisService $adminEnvironmentDiagnosisService): JsonResponse
    {
        $report = $adminEnvironmentDiagnosisService->diagnose((string) $request->query('profile', 'interop'));
        $status = (bool) ($report['ready'] ?? false) ? 200 : 503;

        return response()
            ->json($report, $status)
            ->header('Cache-Control', 'no-store, no-cache, must-revalidate');
    }
}
