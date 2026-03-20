<?php

namespace App\Services\Admin;

use App\Support\Lock\WorkflowLockService;
use Illuminate\Routing\Route as LaravelRoute;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Throwable;

class AdminEnvironmentDiagnosisService
{
    private const CONTRACT_PATH = 'docs/api/phase-one-frontend.openapi.json';

    private const TEST_USER_ID = 2001;

    private const DEBUG_CHARACTER_ID = 1001;

    private const DEBUG_CLASS_ID = 'class_jingang';

    private const DEBUG_STAGE_ID = 'stage_nanshan_001';

    private const DEBUG_STAGE_DIFFICULTY_ID = 'stage_nanshan_001_normal';

    private const DEBUG_REWARD_GROUP_ID = 'reward_first_clear_001';

    private const DEBUG_DROP_SOURCE_MONSTER_ID = 'monster_boss_001';

    public function __construct(
        private readonly WorkflowLockService $workflowLockService,
    ) {
    }

    public function diagnose(): array
    {
        $workflowLock = $this->diagnoseWorkflowLock();
        $apiAuth = $this->diagnoseApiAuth();
        $routes = $this->diagnoseRoutes();
        $seedData = $this->diagnoseSeedData();
        $contract = $this->diagnoseContractArtifact();

        $checks = [
            'workflow_lock' => $workflowLock,
            'api_auth' => $apiAuth,
            'routes' => $routes,
            'seed_data' => $seedData,
            'contract' => $contract,
        ];

        $failures = [];
        $warnings = [];

        foreach ($checks as $checkName => $check) {
            if (! (bool) ($check['ready'] ?? false)) {
                $failures[] = sprintf('%s: %s', $checkName, (string) ($check['message'] ?? '检查失败'));
            }
        }

        if ((bool) ($workflowLock['ready'] ?? false) && str_contains((string) $workflowLock['message'], 'array store')) {
            $warnings[] = (string) $workflowLock['message'];
        }

        return [
            'status' => $failures === [] ? 'ok' : 'failed',
            'ready' => $failures === [],
            'app_env' => app()->environment(),
            'timestamp' => now()->format('Y-m-d H:i:s'),
            'checks' => $checks,
            'summary' => [
                'failures' => $failures,
                'warnings' => $warnings,
            ],
        ];
    }

    private function diagnoseWorkflowLock(): array
    {
        $report = $this->workflowLockService->diagnose();

        return [
            ...$report,
            'ready' => (bool) data_get($report, 'available', false),
        ];
    }

    private function diagnoseApiAuth(): array
    {
        $driver = (string) config('auth.guards.api.driver', '');
        $provider = (string) config('auth.guards.api.provider', '');
        $hash = (bool) config('auth.guards.api.hash', false);
        $ready = $driver === 'token' && $provider === 'users' && $hash;

        return [
            'status' => $ready ? 'ok' : 'failed',
            'ready' => $ready,
            'guard' => 'api',
            'driver' => $driver,
            'provider' => $provider,
            'hash' => $hash,
            'message' => $ready
                ? 'api guard 已按 bearer token 方式配置'
                : 'api guard 未按当前联调要求配置为 hash token guard',
        ];
    }

    private function diagnoseRoutes(): array
    {
        $missing = [];
        $unprotected = [];

        foreach ($this->expectedRoutes() as $method => $uris) {
            foreach ($uris as $uri) {
                $route = $this->findRoute($method, $uri);

                if ($route === null) {
                    $missing[] = sprintf('%s %s', $method, $uri);
                    continue;
                }

                if (! in_array('auth:api', $route->gatherMiddleware(), true)) {
                    $unprotected[] = sprintf('%s %s', $method, $uri);
                }
            }
        }

        $ready = $missing === [] && $unprotected === [];

        return [
            'status' => $ready ? 'ok' : 'failed',
            'ready' => $ready,
            'expected_count' => array_sum(array_map('count', $this->expectedRoutes())),
            'missing' => $missing,
            'unprotected' => $unprotected,
            'message' => $ready
                ? '第一阶段前台 API 路由已就绪且全部挂载 auth:api'
                : '第一阶段前台 API 路由存在缺失或未认证保护',
        ];
    }

    private function diagnoseSeedData(): array
    {
        $requiredTables = [
            'users',
            'classes',
            'characters',
            'character_equipment_slots',
            'inventory_stack_items',
            'inventory_equipment_instances',
            'chapters',
            'chapter_stages',
            'stage_difficulties',
            'stage_monster_bindings',
            'drop_group_bindings',
            'reward_group_bindings',
            'reward_groups',
        ];

        $missingTables = array_values(array_filter(
            $requiredTables,
            static fn (string $table): bool => ! Schema::hasTable($table)
        ));

        if ($missingTables !== []) {
            return [
                'status' => 'failed',
                'ready' => false,
                'tables_missing' => $missingTables,
                'checks' => [],
                'message' => '关键业务表缺失，请先完成 migrate',
            ];
        }

        try {
            $stackItemCount = (int) DB::table('inventory_stack_items')
                ->where('user_id', self::TEST_USER_ID)
                ->count();
            $equipmentInstanceCount = (int) DB::table('inventory_equipment_instances')
                ->where('user_id', self::TEST_USER_ID)
                ->count();
            $slotCount = (int) DB::table('character_equipment_slots')
                ->where('character_id', self::DEBUG_CHARACTER_ID)
                ->count();

            $checks = [
                $this->checkResult(
                    'test_user',
                    DB::table('users')
                        ->where('id', self::TEST_USER_ID)
                        ->whereNotNull('api_token')
                        ->exists(),
                    sprintf('users.id=%d 且存在 api_token', self::TEST_USER_ID)
                ),
                $this->checkResult(
                    'debug_character',
                    DB::table('characters')
                        ->where('character_id', self::DEBUG_CHARACTER_ID)
                        ->where('user_id', self::TEST_USER_ID)
                        ->where('is_active', true)
                        ->exists(),
                    sprintf('characters.character_id=%d 归属 user_id=%d', self::DEBUG_CHARACTER_ID, self::TEST_USER_ID)
                ),
                $this->checkResult(
                    'debug_character_slots',
                    $slotCount === 12,
                    sprintf('character_id=%d 的固定槽位数=%d', self::DEBUG_CHARACTER_ID, $slotCount)
                ),
                $this->checkResult(
                    'inventory_baseline',
                    $stackItemCount >= 3 && $equipmentInstanceCount >= 4,
                    sprintf(
                        'user_id=%d 的 stack_items=%d, equipment_instances=%d',
                        self::TEST_USER_ID,
                        $stackItemCount,
                        $equipmentInstanceCount
                    )
                ),
                $this->checkResult(
                    'class_seed',
                    DB::table('classes')
                        ->where('class_id', self::DEBUG_CLASS_ID)
                        ->where('is_enabled', true)
                        ->exists(),
                    sprintf('classes.class_id=%s 已启用', self::DEBUG_CLASS_ID)
                ),
                $this->checkResult(
                    'stage_seed',
                    DB::table('chapters')
                        ->where('chapter_id', 'chapter_nanshan_001')
                        ->where('is_enabled', true)
                        ->exists()
                        && DB::table('chapter_stages')
                            ->where('stage_id', self::DEBUG_STAGE_ID)
                            ->where('is_enabled', true)
                            ->exists()
                        && DB::table('stage_difficulties')
                            ->where('stage_difficulty_id', self::DEBUG_STAGE_DIFFICULTY_ID)
                            ->where('is_enabled', true)
                            ->exists(),
                    sprintf(
                        'chapter_nanshan_001 -> %s -> %s 已启用',
                        self::DEBUG_STAGE_ID,
                        self::DEBUG_STAGE_DIFFICULTY_ID
                    )
                ),
                $this->checkResult(
                    'stage_monster_bindings',
                    DB::table('stage_monster_bindings')
                        ->where('stage_difficulty_id', self::DEBUG_STAGE_DIFFICULTY_ID)
                        ->count() > 0,
                    sprintf('%s 存在怪物绑定', self::DEBUG_STAGE_DIFFICULTY_ID)
                ),
                $this->checkResult(
                    'drop_binding',
                    DB::table('drop_group_bindings')
                        ->where('source_type', 'monster')
                        ->where('source_id', self::DEBUG_DROP_SOURCE_MONSTER_ID)
                        ->exists(),
                    sprintf('monster/%s 已绑定正式掉落组', self::DEBUG_DROP_SOURCE_MONSTER_ID)
                ),
                $this->checkResult(
                    'reward_binding',
                    DB::table('reward_group_bindings')
                        ->where('source_type', 'first_clear')
                        ->where('source_id', self::DEBUG_STAGE_DIFFICULTY_ID)
                        ->where('reward_group_id', self::DEBUG_REWARD_GROUP_ID)
                        ->exists()
                        && DB::table('reward_groups')
                            ->where('reward_group_id', self::DEBUG_REWARD_GROUP_ID)
                            ->where('is_enabled', true)
                            ->exists(),
                    sprintf(
                        'first_clear/%s -> %s 已绑定且奖励组启用',
                        self::DEBUG_STAGE_DIFFICULTY_ID,
                        self::DEBUG_REWARD_GROUP_ID
                    )
                ),
            ];
        } catch (Throwable $throwable) {
            return [
                'status' => 'failed',
                'ready' => false,
                'tables_missing' => [],
                'checks' => [],
                'message' => sprintf('seed 数据检查失败：%s', $throwable->getMessage()),
            ];
        }

        $ready = ! collect($checks)->contains(static fn (array $check): bool => ! $check['ok']);

        return [
            'status' => $ready ? 'ok' : 'failed',
            'ready' => $ready,
            'tables_missing' => [],
            'checks' => $checks,
            'message' => $ready
                ? '最小联调 seed 数据已就绪'
                : '最小联调 seed 数据不完整，请先执行 DatabaseSeeder',
        ];
    }

    private function diagnoseContractArtifact(): array
    {
        $relativePath = self::CONTRACT_PATH;
        $absolutePath = base_path($relativePath);

        if (! is_file($absolutePath)) {
            return [
                'status' => 'failed',
                'ready' => false,
                'path' => $relativePath,
                'message' => '前台 API 契约文件不存在',
            ];
        }

        try {
            $decoded = json_decode((string) file_get_contents($absolutePath), true, 512, JSON_THROW_ON_ERROR);
            $hasPaths = is_array(data_get($decoded, 'paths'));
        } catch (Throwable $throwable) {
            return [
                'status' => 'failed',
                'ready' => false,
                'path' => $relativePath,
                'message' => sprintf('前台 API 契约文件不可解析：%s', $throwable->getMessage()),
            ];
        }

        return [
            'status' => $hasPaths ? 'ok' : 'failed',
            'ready' => $hasPaths,
            'path' => $relativePath,
            'message' => $hasPaths
                ? '前台 API 契约文件已就绪'
                : '前台 API 契约文件缺少 paths 结构',
        ];
    }

    private function checkResult(string $key, bool $ok, string $detail): array
    {
        return [
            'key' => $key,
            'ok' => $ok,
            'detail' => $detail,
        ];
    }

    private function findRoute(string $method, string $uri): ?LaravelRoute
    {
        foreach (app('router')->getRoutes()->getRoutes() as $route) {
            if ('/'.$route->uri() !== $uri) {
                continue;
            }

            if (! in_array($method, $route->methods(), true)) {
                continue;
            }

            return $route;
        }

        return null;
    }

    private function expectedRoutes(): array
    {
        return [
            'GET' => [
                '/api/chapters',
                '/api/stages/{stage_id}/difficulties',
                '/api/stage-difficulties/{stage_difficulty_id}/first-clear-reward-status',
                '/api/characters/{character_id}',
                '/api/characters/{character_id}/equipment-slots',
                '/api/inventory',
            ],
            'POST' => [
                '/api/battles/prepare',
                '/api/battles/settle',
                '/api/characters',
                '/api/characters/{character_id}/equip',
                '/api/characters/{character_id}/unequip',
            ],
        ];
    }
}
