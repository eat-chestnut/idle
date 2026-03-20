<?php

namespace App\Http\Controllers\Admin;

use App\Enums\Reward\RewardSourceType;
use App\Exceptions\BusinessException;
use App\Http\Controllers\Controller;
use App\Services\Admin\AdminDataRepairService;
use App\Services\Admin\AdminReferenceCheckService;
use App\Services\Admin\AdminResourceRegistry;
use App\Services\Admin\AdminRewardRetryService;
use App\Support\Lock\WorkflowLockService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rules\Enum;
use Illuminate\View\View;

class AdminToolController extends Controller
{
    public function __construct(
        private readonly AdminResourceRegistry $adminResourceRegistry,
        private readonly AdminReferenceCheckService $adminReferenceCheckService,
        private readonly AdminRewardRetryService $adminRewardRetryService,
        private readonly AdminDataRepairService $adminDataRepairService,
        private readonly WorkflowLockService $workflowLockService,
    ) {}

    public function index(Request $request): View
    {
        return view('admin.tools.index', [
            'title' => '后台运维工具',
            'navigation' => $this->adminResourceRegistry->navigation(),
            'nav_key' => 'tools',
            'resource' => null,
            'tool_result' => session('tool_result'),
            'config_resources' => $this->adminResourceRegistry->configResourceOptions(),
            'reward_source_types' => $this->enumOptions(RewardSourceType::class, true),
            'lock_diagnostic' => $this->workflowLockService->diagnose(),
            'reference_defaults' => [
                'resource' => (string) $request->query('reference_resource', ''),
                'record_key' => (string) $request->query('reference_record', ''),
            ],
        ]);
    }

    public function checkReferences(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'resource' => ['required', 'string', 'in:'.implode(',', array_keys($this->adminResourceRegistry->configResourceOptions()))],
            'record_key' => ['required', 'string'],
        ]);

        try {
            $summary = $this->adminReferenceCheckService->inspect(
                (string) $validated['resource'],
                (string) $validated['record_key']
            );

            return $this->redirectWithToolResult('配置引用检查结果', [
                'resource' => $summary['resource_title'],
                'record_key' => $summary['record_key'],
                'record_label' => $summary['record_label'],
                'block_disable' => $summary['block_disable'] ? '是' : '否',
                'block_delete' => $summary['block_delete'] ? '是' : '否',
            ], [
                'payload' => $summary,
            ]);
        } catch (BusinessException $exception) {
            return back()
                ->withInput()
                ->withErrors(['reference_check' => $exception->getMessage()]);
        }
    }

    public function retryReward(Request $request): RedirectResponse
    {
        $validator = Validator::make($request->all(), [
            'reward_grant_id' => ['nullable', 'integer', 'min:1'],
            'user_id' => ['nullable', 'integer', 'min:1'],
            'source_type' => ['nullable', new Enum(RewardSourceType::class)],
            'source_id' => ['nullable', 'string'],
        ]);

        $validator->after(function ($validator) use ($request): void {
            $hasRewardGrantId = (int) $request->input('reward_grant_id', 0) > 0;
            $hasBusinessSource = (int) $request->input('user_id', 0) > 0
                && (string) $request->input('source_type', '') !== ''
                && (string) $request->input('source_id', '') !== '';

            if (! $hasRewardGrantId && ! $hasBusinessSource) {
                $validator->errors()->add('reward_grant_id', '请提供 reward_grant_id，或填写 user_id + source_type + source_id');
            }
        });

        $validated = $validator->validate();

        try {
            $result = $this->adminRewardRetryService->retry($validated, $this->currentOperator());

            return $this->redirectWithToolResult('奖励补发执行结果', [
                'lookup_mode' => (string) data_get($result, 'lookup_mode'),
                'reward_grant_id' => (string) data_get($result, 'result.reward_grant_id'),
                'grant_status' => (string) data_get($result, 'result.grant_status'),
                'source_id' => (string) data_get($result, 'result.source_id'),
            ], [
                'payload' => $result,
            ]);
        } catch (BusinessException $exception) {
            return back()
                ->withInput()
                ->withErrors(['reward_retry' => $exception->getMessage()]);
        }
    }

    public function repairBattleContext(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'battle_context_id' => ['required', 'string'],
        ]);

        try {
            $result = $this->adminDataRepairService->repairBattleContext(
                (string) $validated['battle_context_id'],
                $this->currentOperator()
            );

            return $this->redirectWithToolResult('Battle Context 修复结果', [
                'entity' => 'battle_context',
                'repair_action' => (string) data_get($result, 'repair_action'),
                'battle_context_id' => (string) data_get($result, 'after.battle_context_id'),
            ], [
                'payload' => $result,
            ]);
        } catch (BusinessException $exception) {
            return back()
                ->withInput()
                ->withErrors(['battle_context_repair' => $exception->getMessage()]);
        }
    }

    public function repairRewardGrant(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'reward_grant_id' => ['required', 'integer', 'min:1'],
        ]);

        try {
            $result = $this->adminDataRepairService->repairRewardGrant(
                (int) $validated['reward_grant_id'],
                $this->currentOperator()
            );

            return $this->redirectWithToolResult('发奖记录修复结果', [
                'entity' => 'reward_grant',
                'repair_action' => (string) data_get($result, 'repair_action'),
                'reward_grant_id' => (string) data_get($result, 'after.reward_grant_id'),
            ], [
                'payload' => $result,
            ]);
        } catch (BusinessException $exception) {
            return back()
                ->withInput()
                ->withErrors(['reward_grant_repair' => $exception->getMessage()]);
        }
    }

    private function currentOperator(): array
    {
        return [
            'admin_user_id' => auth('admin')->id(),
            'admin_username' => auth('admin')->user()?->username,
        ];
    }

    private function redirectWithToolResult(string $title, array $summary, array $extra = []): RedirectResponse
    {
        return redirect()
            ->route('admin.tools.index')
            ->with('tool_result', [
                'title' => $title,
                'summary' => $summary,
                ...$extra,
            ]);
    }

    private function enumOptions(string $enumClass, bool $withAll = false): array
    {
        $options = [];

        foreach ($enumClass::cases() as $case) {
            $options[$case->value] = $case->value;
        }

        if (! $withAll) {
            return $options;
        }

        return ['' => '请选择'] + $options;
    }
}
