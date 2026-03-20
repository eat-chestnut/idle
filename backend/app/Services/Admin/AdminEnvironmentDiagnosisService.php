<?php

namespace App\Services\Admin;

use App\Support\Lock\WorkflowLockService;
use Illuminate\Routing\Route as LaravelRoute;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Throwable;

class AdminEnvironmentDiagnosisService
{
    private const DEFAULT_PROFILE = 'interop';

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

    public function diagnose(string $profile = self::DEFAULT_PROFILE): array
    {
        $selectedProfile = $this->resolveProfile($profile);
        $appKey = $this->diagnoseAppKey();
        $database = $this->diagnoseDatabase();
        $runtimeDependencies = $this->diagnoseRuntimeDependencies();
        $workflowLock = $this->diagnoseWorkflowLock();
        $apiAuth = $this->diagnoseApiAuth();
        $apiCors = $this->diagnoseApiCors();
        $routes = $this->diagnoseRoutes();
        $seedData = $this->diagnoseSeedData();
        $adminBootstrap = $this->diagnoseAdminBootstrap();
        $contract = $this->diagnoseContractArtifact();

        $checks = [
            'app_key' => $appKey,
            'database' => $database,
            'runtime_dependencies' => $runtimeDependencies,
            'workflow_lock' => $workflowLock,
            'api_auth' => $apiAuth,
            'api_cors' => $apiCors,
            'routes' => $routes,
            'seed_data' => $seedData,
            'admin_bootstrap' => $adminBootstrap,
            'contract' => $contract,
        ];

        $profiles = [
            'service' => $this->buildProfile(
                $checks,
                'service',
                ['app_key', 'database'],
                '基础运行环境已就绪'
            ),
            'interop' => $this->buildProfile(
                $checks,
                'interop',
                ['app_key', 'database', 'workflow_lock', 'api_auth', 'api_cors', 'routes', 'seed_data', 'contract'],
                '第一阶段联调前提已就绪'
            ),
            'acceptance' => $this->buildProfile(
                $checks,
                'acceptance',
                ['app_key', 'database', 'workflow_lock', 'api_auth', 'api_cors', 'routes', 'seed_data', 'contract', 'admin_bootstrap'],
                '第一阶段验收前提已就绪'
            ),
        ];

        $runtimeWarning = $this->buildNonBlockingWarning('runtime_dependencies', $runtimeDependencies);

        if ($runtimeWarning !== null) {
            foreach ($profiles as &$profileReport) {
                $profileReport['warnings'][] = $runtimeWarning;
            }

            unset($profileReport);
        }

        $selectedReport = $profiles[$selectedProfile];

        return [
            'status' => (string) $selectedReport['status'],
            'ready' => (bool) $selectedReport['ready'],
            'selected_profile' => $selectedProfile,
            'app_env' => app()->environment(),
            'timestamp' => now()->format('Y-m-d H:i:s'),
            'checks' => $checks,
            'profiles' => $profiles,
            'summary' => [
                'failures' => (array) $selectedReport['failures'],
                'warnings' => (array) $selectedReport['warnings'],
                'commands' => [
                    'service' => 'php artisan phase-one:diagnose --profile=service --json',
                    'interop' => 'php artisan phase-one:diagnose --profile=interop --json',
                    'acceptance' => 'php artisan phase-one:diagnose --profile=acceptance --json',
                ],
                'endpoints' => [
                    'liveness' => '/up',
                    'readiness' => '/readyz',
                ],
            ],
        ];
    }

    private function diagnoseAppKey(): array
    {
        $key = (string) config('app.key', '');
        $ready = $key !== '';

        return [
            'status' => $ready ? 'ok' : 'failed',
            'ready' => $ready,
            'message' => $ready
                ? 'APP_KEY 已配置'
                : 'APP_KEY 缺失，请先执行 php artisan key:generate',
        ];
    }

    private function diagnoseDatabase(): array
    {
        $connection = (string) config('database.default', '');
        $driver = (string) config(sprintf('database.connections.%s.driver', $connection), '');

        try {
            $database = (string) DB::connection($connection)->getDatabaseName();
            DB::connection($connection)->getPdo();
        } catch (Throwable $throwable) {
            return [
                'status' => 'failed',
                'ready' => false,
                'connection' => $connection,
                'driver' => $driver,
                'database' => null,
                'message' => sprintf('数据库连接不可用：%s', $throwable->getMessage()),
            ];
        }

        return [
            'status' => 'ok',
            'ready' => true,
            'connection' => $connection,
            'driver' => $driver,
            'database' => $database,
            'message' => sprintf('数据库连接已就绪（%s/%s）', $connection, $driver),
        ];
    }

    private function diagnoseRuntimeDependencies(): array
    {
        $sessionDriver = (string) config('session.driver', '');
        $queueConnection = (string) config('queue.default', '');
        $mailMailer = (string) config('mail.default', '');
        $cacheStore = (string) config('cache.default', '');
        $workflowLockStore = (string) config('workflow_lock.store', $cacheStore);

        $checks = [
            $this->checkResult('session_driver', ...$this->sessionDriverStatus($sessionDriver)),
            $this->checkResult('queue_connection', ...$this->queueConnectionStatus($queueConnection)),
            $this->checkResult('mail_mailer', $mailMailer !== '', sprintf('MAIL_MAILER=%s', $mailMailer !== '' ? $mailMailer : '(empty)')),
            $this->checkResult('cache_store', ...$this->cacheStoreStatus('CACHE_STORE', $cacheStore)),
            $this->checkResult('workflow_lock_store', ...$this->cacheStoreStatus('WORKFLOW_LOCK_STORE', $workflowLockStore)),
        ];

        $ready = ! collect($checks)->contains(static fn (array $check): bool => ! $check['ok']);

        return [
            'status' => $ready ? 'ok' : 'failed',
            'ready' => $ready,
            'checks' => $checks,
            'message' => $ready
                ? 'session / queue / mail / cache 已具备最小运行配置'
                : 'session / queue / mail / cache 存在缺失或未完成的前置配置',
        ];
    }

    private function diagnoseWorkflowLock(): array
    {
        $report = $this->workflowLockService->diagnose();

        return [
            ...$report,
            'ready' => (bool) data_get($report, 'available', false),
            'warning' => $this->workflowLockWarning((string) data_get($report, 'store', '')),
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

    private function diagnoseApiCors(): array
    {
        $paths = array_values((array) config('cors.paths', []));
        $allowedOrigins = array_values((array) config('cors.allowed_origins', []));
        $allowedPatterns = array_values((array) config('cors.allowed_origins_patterns', []));
        $allowedHeaders = array_map(static fn (string $header): string => strtolower($header), (array) config('cors.allowed_headers', []));
        $allowedMethods = array_map(static fn (string $method): string => strtoupper($method), (array) config('cors.allowed_methods', []));

        $pathReady = in_array('api/*', $paths, true);
        $originsReady = $allowedOrigins !== [] || $allowedPatterns !== [];
        $headersReady = in_array('*', $allowedHeaders, true) || in_array('authorization', $allowedHeaders, true);
        $methodsReady = in_array('*', $allowedMethods, true) || collect(['GET', 'POST', 'OPTIONS'])->diff($allowedMethods)->isEmpty();
        $ready = $pathReady && $originsReady && $headersReady && $methodsReady;

        return [
            'status' => $ready ? 'ok' : 'failed',
            'ready' => $ready,
            'paths' => $paths,
            'allowed_origins' => $allowedOrigins,
            'allowed_origins_patterns' => $allowedPatterns,
            'message' => $ready
                ? 'phase-one API CORS 已配置'
                : 'phase-one API CORS 未完成最小联调配置，请检查 config/cors.php 与 CORS_ALLOWED_ORIGINS',
            'warning' => $this->corsWarning($allowedOrigins),
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

    private function diagnoseAdminBootstrap(): array
    {
        if (! Schema::hasTable('admin_users')) {
            return [
                'status' => 'failed',
                'ready' => false,
                'enabled_admin_count' => 0,
                'session_driver' => (string) config('session.driver', ''),
                'message' => 'admin_users 表缺失，请先完成 migrate',
            ];
        }

        $sessionDriver = (string) config('session.driver', '');
        $sessionReady = $this->isSessionDriverUsable($sessionDriver);
        $enabledAdminCount = (int) DB::table('admin_users')
            ->where('is_enabled', true)
            ->count();
        $ready = $sessionReady && $enabledAdminCount > 0;
        $problems = [];

        if (! $sessionReady) {
            $problems[] = sprintf('SESSION_DRIVER=%s 无法支撑后台登录', $sessionDriver !== '' ? $sessionDriver : '(empty)');
        }

        if ($enabledAdminCount === 0) {
            $problems[] = '后台管理员未初始化，请先执行 DatabaseSeeder 或 AdminUserSeeder';
        }

        return [
            'status' => $ready ? 'ok' : 'failed',
            'ready' => $ready,
            'enabled_admin_count' => $enabledAdminCount,
            'session_driver' => $sessionDriver,
            'message' => $ready
                ? '后台管理员与后台登录 session 已就绪'
                : implode('；', $problems),
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

    private function buildProfile(array $checks, string $profile, array $requiredChecks, string $successMessage): array
    {
        $failures = [];
        $warnings = [];

        foreach ($requiredChecks as $checkName) {
            $check = (array) ($checks[$checkName] ?? []);

            if (! (bool) ($check['ready'] ?? false)) {
                $failures[] = sprintf('%s: %s', $checkName, (string) ($check['message'] ?? '检查失败'));
            }

            $warning = $this->buildNonBlockingWarning($checkName, $check);

            if ($warning !== null) {
                $warnings[] = $warning;
            }
        }

        return [
            'status' => $failures === [] ? 'ok' : 'failed',
            'ready' => $failures === [],
            'required_checks' => $requiredChecks,
            'message' => $failures === [] ? $successMessage : sprintf('%s检查未通过', $this->profileLabel($profile)),
            'failures' => $failures,
            'warnings' => $warnings,
        ];
    }

    private function buildNonBlockingWarning(string $checkName, array $check): ?string
    {
        $warning = trim((string) ($check['warning'] ?? ''));

        if ($warning === '') {
            if ((bool) ($check['ready'] ?? false)) {
                return null;
            }

            return null;
        }

        return sprintf('%s: %s', $checkName, $warning);
    }

    private function checkResult(string $key, bool $ok, string $detail): array
    {
        return [
            'key' => $key,
            'ok' => $ok,
            'detail' => $detail,
        ];
    }

    private function resolveProfile(string $profile): string
    {
        return match ($profile) {
            'service', 'interop', 'acceptance' => $profile,
            default => self::DEFAULT_PROFILE,
        };
    }

    private function sessionDriverStatus(string $driver): array
    {
        $driver = trim($driver);

        if ($driver === '') {
            return [false, 'SESSION_DRIVER=(empty)'];
        }

        if (! $this->isSessionDriverUsable($driver)) {
            return [false, sprintf('SESSION_DRIVER=%s，仅允许 testing 环境使用 array', $driver)];
        }

        if ($driver === 'database' && ! $this->schemaTableExists((string) config('session.table', 'sessions'))) {
            return [false, sprintf('SESSION_DRIVER=database 但缺少 %s 表', (string) config('session.table', 'sessions'))];
        }

        return [true, sprintf('SESSION_DRIVER=%s', $driver)];
    }

    private function queueConnectionStatus(string $connection): array
    {
        $connection = trim($connection);

        if ($connection === '' || $connection === 'null') {
            return [false, sprintf('QUEUE_CONNECTION=%s', $connection === '' ? '(empty)' : $connection)];
        }

        if ($connection === 'database' && ! $this->schemaTableExists((string) config('queue.connections.database.table', 'jobs'))) {
            return [false, sprintf('QUEUE_CONNECTION=database 但缺少 %s 表', (string) config('queue.connections.database.table', 'jobs'))];
        }

        return [true, sprintf('QUEUE_CONNECTION=%s', $connection)];
    }

    private function cacheStoreStatus(string $label, string $store): array
    {
        $store = trim($store);

        if ($store === '' || $store === 'null') {
            return [false, sprintf('%s=%s', $label, $store === '' ? '(empty)' : $store)];
        }

        if ($store === 'array' && ! app()->environment('testing')) {
            return [false, sprintf('%s=array，仅允许 testing 环境使用', $label)];
        }

        if ($store === 'database' && ! $this->schemaTableExists((string) config('cache.stores.database.table', 'cache'))) {
            return [false, sprintf('%s=database 但缺少 %s 表', $label, (string) config('cache.stores.database.table', 'cache'))];
        }

        return [true, sprintf('%s=%s', $label, $store)];
    }

    private function isSessionDriverUsable(string $driver): bool
    {
        if ($driver === 'array' && ! app()->environment('testing')) {
            return false;
        }

        return $driver !== '';
    }

    private function schemaTableExists(string $table): bool
    {
        try {
            return Schema::hasTable($table);
        } catch (Throwable) {
            return false;
        }
    }

    private function workflowLockWarning(string $store): ?string
    {
        if ($store === 'array' && app()->environment('testing')) {
            return 'testing 环境允许 array；真实联调或部署请改为 file / redis / database 等正式 store';
        }

        if ($store === 'file' && ! app()->environment('testing')) {
            return 'file lock 只适合单机部署；多实例部署请改为 redis 等共享 store';
        }

        return null;
    }

    private function corsWarning(array $allowedOrigins): ?string
    {
        if (in_array('*', $allowedOrigins, true) && ! app()->environment(['local', 'testing'])) {
            return '当前允许所有来源，部署前建议收口为明确的前端域名列表';
        }

        return null;
    }

    private function profileLabel(string $profile): string
    {
        return match ($profile) {
            'service' => '服务存活',
            'acceptance' => '验收前提',
            default => '联调前提',
        };
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
