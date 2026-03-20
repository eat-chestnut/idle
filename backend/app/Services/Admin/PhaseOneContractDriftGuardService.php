<?php

namespace App\Services\Admin;

use App\Http\Requests\Api\ApiRequest;
use App\Support\ApiResponse;
use App\Support\ErrorCode;
use Illuminate\Routing\Route as LaravelRoute;
use ReflectionMethod;
use ReflectionNamedType;
use Throwable;

class PhaseOneContractDriftGuardService
{
    private const OPENAPI_RELATIVE_PATH = 'docs/api/phase-one-frontend.openapi.json';

    private const FORMAL_DOC_RELATIVE_PATH = 'doc/codex/接口示例文档.md';

    private const AUTH_RULES_DOC_RELATIVE_PATH = 'doc/codex/认证与接口公共规则.md';

    public function check(): array
    {
        $actualRoutes = $this->collectActualRouteContracts();
        $formalDocPath = $this->repoRootPath(self::FORMAL_DOC_RELATIVE_PATH);
        $authRulesDocPath = $this->repoRootPath(self::AUTH_RULES_DOC_RELATIVE_PATH);
        $formalDoc = $this->loadTextFile($formalDocPath);
        $authRulesDoc = $this->loadTextFile($authRulesDocPath);
        $openApiResult = $this->loadOpenApiSpec();

        if (! $openApiResult['ok']) {
            $checks = [
                'openapi_routes' => [
                    'ok' => false,
                    'message' => (string) $openApiResult['message'],
                ],
                'openapi_request_fields' => [
                    'ok' => false,
                    'message' => (string) $openApiResult['message'],
                ],
                'formal_doc_routes' => [
                    'ok' => false,
                    'message' => $formalDoc === null
                        ? sprintf('根目录正式接口文档缺失：%s', self::FORMAL_DOC_RELATIVE_PATH)
                        : 'OpenAPI 未就绪，无法完成正式接口文档对齐检查',
                ],
                'auth_contract' => [
                    'ok' => false,
                    'message' => $authRulesDoc === null
                        ? sprintf('认证公共规则文档缺失：%s', self::AUTH_RULES_DOC_RELATIVE_PATH)
                        : 'OpenAPI 未就绪，无法完成 Bearer Token 口径检查',
                ],
                'response_envelope' => [
                    'ok' => false,
                    'message' => 'OpenAPI 未就绪，无法完成统一响应外壳检查',
                ],
            ];

            return $this->buildReport($checks, $actualRoutes);
        }

        $spec = $openApiResult['spec'];
        $openApiRoutes = $this->collectOpenApiRouteContracts($spec);
        $formalDocRoutes = $formalDoc === null
            ? [
                'ok' => false,
                'message' => sprintf('根目录正式接口文档缺失：%s', self::FORMAL_DOC_RELATIVE_PATH),
                'declared_count' => null,
                'documented_routes' => [],
            ]
            : $this->collectFormalDocumentedRoutes($formalDoc);

        $checks = [
            'openapi_routes' => $this->checkOpenApiRoutes($actualRoutes, $openApiRoutes),
            'openapi_request_fields' => $this->checkOpenApiRequestFields($actualRoutes, $openApiRoutes),
            'formal_doc_routes' => $this->checkFormalDocumentRoutes($actualRoutes, $formalDocRoutes),
            'auth_contract' => $this->checkAuthContract($actualRoutes, $openApiRoutes, $spec, $formalDoc, $authRulesDoc),
            'response_envelope' => $this->checkResponseEnvelope($openApiRoutes, $spec, $formalDoc, $authRulesDoc),
        ];

        return $this->buildReport($checks, $actualRoutes);
    }

    private function buildReport(array $checks, array $actualRoutes): array
    {
        $failures = [];

        foreach ($checks as $name => $check) {
            if ((bool) ($check['ok'] ?? false)) {
                continue;
            }

            $details = array_values(array_filter(
                array_map(static function (mixed $detail): string {
                    return trim((string) $detail);
                }, (array) ($check['details'] ?? [])),
                static fn (string $detail): bool => $detail !== ''
            ));

            if ($details === []) {
                $details[] = (string) ($check['message'] ?? $name);
            }

            foreach ($details as $detail) {
                $failures[] = sprintf('[%s] %s', $name, $detail);
            }
        }

        $ready = $failures === [];

        return [
            'status' => $ready ? 'ok' : 'failed',
            'ready' => $ready,
            'message' => $ready
                ? 'phase-one API 契约未发现漂移'
                : 'phase-one API 契约发现漂移，请先同步真实代码、OpenAPI 与根目录正式文档',
            'contract_sources' => [
                'real_code' => [
                    'routes' => 'routes/api.php',
                    'requests' => 'app/Http/Requests/Api',
                    'response_shell' => 'app/Support/ApiResponse.php',
                ],
                'openapi' => self::OPENAPI_RELATIVE_PATH,
                'formal_doc' => self::FORMAL_DOC_RELATIVE_PATH,
                'auth_rules_doc' => self::AUTH_RULES_DOC_RELATIVE_PATH,
            ],
            'actual_route_count' => count($actualRoutes),
            'actual_routes' => array_values(array_keys($actualRoutes)),
            'checks' => $checks,
            'summary' => [
                'failures' => $failures,
                'commands' => [
                    'contract_drift_check' => 'php artisan phase-one:contract-drift-check --json',
                ],
            ],
        ];
    }

    private function collectActualRouteContracts(): array
    {
        $contracts = [];

        foreach (app('router')->getRoutes()->getRoutes() as $route) {
            if (! str_starts_with($route->uri(), 'api/')) {
                continue;
            }

            foreach ($this->supportedHttpMethods($route) as $method) {
                $path = '/'.$route->uri();
                $key = sprintf('%s %s', $method, $path);
                $routeParameters = array_values($route->parameterNames());
                sort($routeParameters);
                $requestContract = $this->resolveRequestContract($route, $method);

                $contracts[$key] = [
                    'method' => $method,
                    'path' => $path,
                    'route_parameters' => $routeParameters,
                    'request_contract' => $requestContract,
                    'auth_protected' => in_array('auth:api', $route->gatherMiddleware(), true),
                ];
            }
        }

        ksort($contracts);

        return $contracts;
    }

    private function supportedHttpMethods(LaravelRoute $route): array
    {
        $methods = array_values(array_filter(
            $route->methods(),
            static fn (string $method): bool => in_array($method, ['GET', 'POST'], true)
        ));

        sort($methods);

        return $methods;
    }

    private function resolveRequestContract(LaravelRoute $route, string $method): array
    {
        $requestClass = $this->resolveRequestClass($route);
        $routeParameters = array_values($route->parameterNames());
        sort($routeParameters);

        if ($requestClass === null) {
            return [
                'request_class' => null,
                'path_parameters' => $routeParameters,
                'query_parameters' => [],
                'body_fields' => [],
                'required_body_fields' => [],
            ];
        }

        /** @var ApiRequest $request */
        $request = new $requestClass();
        $rules = $request->rules();
        $topLevelFields = array_values(array_filter(
            array_keys($rules),
            static fn (string $field): bool => ! str_contains($field, '.')
        ));
        sort($topLevelFields);

        $pathParameters = $routeParameters;
        $payloadFields = array_values(array_diff($topLevelFields, $routeParameters));
        $requiredPayloadFields = array_values(array_filter(
            $payloadFields,
            fn (string $field): bool => $this->ruleSetContainsRequired($rules[$field] ?? [])
        ));

        sort($pathParameters);
        sort($payloadFields);
        sort($requiredPayloadFields);

        return [
            'request_class' => $requestClass,
            'path_parameters' => $pathParameters,
            'query_parameters' => $method === 'GET' ? $payloadFields : [],
            'body_fields' => $method === 'POST' ? $payloadFields : [],
            'required_body_fields' => $method === 'POST' ? $requiredPayloadFields : [],
        ];
    }

    private function resolveRequestClass(LaravelRoute $route): ?string
    {
        $controllerClass = $route->getControllerClass();
        $method = $route->getActionMethod();

        if ($controllerClass === null || $method === null || ! method_exists($controllerClass, $method)) {
            return null;
        }

        $reflection = new ReflectionMethod($controllerClass, $method);

        foreach ($reflection->getParameters() as $parameter) {
            $type = $parameter->getType();

            if (! $type instanceof ReflectionNamedType || $type->isBuiltin()) {
                continue;
            }

            $typeName = $type->getName();

            if (is_subclass_of($typeName, ApiRequest::class)) {
                return $typeName;
            }
        }

        return null;
    }

    private function ruleSetContainsRequired(mixed $ruleSet): bool
    {
        foreach ((array) $ruleSet as $rule) {
            if (is_string($rule)) {
                foreach (explode('|', $rule) as $fragment) {
                    if (trim($fragment) === 'required') {
                        return true;
                    }
                }
            }

            if (is_object($rule) && method_exists($rule, '__toString') && trim((string) $rule) === 'required') {
                return true;
            }
        }

        return false;
    }

    private function loadOpenApiSpec(): array
    {
        $path = base_path(self::OPENAPI_RELATIVE_PATH);

        if (! is_file($path)) {
            return [
                'ok' => false,
                'message' => sprintf('OpenAPI 契约文件缺失：%s', self::OPENAPI_RELATIVE_PATH),
                'spec' => [],
            ];
        }

        try {
            $decoded = json_decode((string) file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
        } catch (Throwable $throwable) {
            return [
                'ok' => false,
                'message' => sprintf('OpenAPI 契约文件不可解析：%s', $throwable->getMessage()),
                'spec' => [],
            ];
        }

        if (! is_array(data_get($decoded, 'paths'))) {
            return [
                'ok' => false,
                'message' => 'OpenAPI 契约文件缺少 paths 结构',
                'spec' => [],
            ];
        }

        return [
            'ok' => true,
            'message' => 'OpenAPI 契约文件已就绪',
            'spec' => $decoded,
        ];
    }

    private function collectOpenApiRouteContracts(array $spec): array
    {
        $contracts = [];

        foreach ((array) data_get($spec, 'paths', []) as $path => $pathItem) {
            foreach (['get', 'post'] as $httpMethod) {
                if (! isset($pathItem[$httpMethod])) {
                    continue;
                }

                $method = strtoupper($httpMethod);
                $operation = (array) $pathItem[$httpMethod];
                $key = sprintf('%s %s', $method, $path);

                $contracts[$key] = [
                    'method' => $method,
                    'path' => $path,
                    'path_parameters' => $this->collectOperationParameterNames($pathItem, $operation, $spec, 'path'),
                    'query_parameters' => $this->collectOperationParameterNames($pathItem, $operation, $spec, 'query'),
                    'body_fields' => $this->collectRequestBodyFieldNames($operation, $spec),
                    'required_body_fields' => $this->collectRequiredRequestBodyFields($operation, $spec),
                    'has_bearer_security' => $this->operationHasBearerSecurity($spec, $operation),
                    'success_envelope' => $this->operationResponseContainsEnvelope(
                        $operation,
                        $spec,
                        '#/components/schemas/ApiSuccessEnvelope'
                    ),
                    'error_envelope' => $this->operationResponseContainsEnvelope(
                        $operation,
                        $spec,
                        '#/components/schemas/ApiErrorResponse'
                    ),
                ];
            }
        }

        ksort($contracts);

        return $contracts;
    }

    private function collectOperationParameterNames(array $pathItem, array $operation, array $spec, string $location): array
    {
        $parameters = [];

        foreach (array_merge((array) ($pathItem['parameters'] ?? []), (array) ($operation['parameters'] ?? [])) as $parameter) {
            $resolved = $this->resolveOpenApiNode((array) $parameter, $spec);

            if (($resolved['in'] ?? null) !== $location) {
                continue;
            }

            $parameters[] = (string) ($resolved['name'] ?? '');
        }

        $parameters = array_values(array_filter($parameters, static fn (string $name): bool => $name !== ''));
        sort($parameters);

        return array_values(array_unique($parameters));
    }

    private function collectRequestBodyFieldNames(array $operation, array $spec): array
    {
        $schema = $this->resolveRequestBodySchema($operation, $spec);
        $fields = $this->collectSchemaPropertyNames($schema, $spec);
        sort($fields);

        return array_values(array_unique($fields));
    }

    private function collectRequiredRequestBodyFields(array $operation, array $spec): array
    {
        $schema = $this->resolveRequestBodySchema($operation, $spec);
        $required = $this->collectSchemaRequiredFields($schema, $spec);
        sort($required);

        return array_values(array_unique($required));
    }

    private function resolveRequestBodySchema(array $operation, array $spec): array
    {
        $requestBody = $this->resolveOpenApiNode((array) ($operation['requestBody'] ?? []), $spec);
        $schema = (array) data_get($requestBody, 'content.application/json.schema', []);

        return $this->resolveOpenApiNode($schema, $spec);
    }

    private function collectSchemaPropertyNames(array $schema, array $spec): array
    {
        $resolved = $this->resolveOpenApiNode($schema, $spec);
        $properties = array_keys((array) ($resolved['properties'] ?? []));

        foreach (['allOf', 'oneOf', 'anyOf'] as $combinator) {
            foreach ((array) ($resolved[$combinator] ?? []) as $part) {
                $properties = array_merge($properties, $this->collectSchemaPropertyNames((array) $part, $spec));
            }
        }

        $properties = array_values(array_filter(
            array_map(static fn (mixed $property): string => (string) $property, $properties),
            static fn (string $property): bool => $property !== ''
        ));
        sort($properties);

        return array_values(array_unique($properties));
    }

    private function collectSchemaRequiredFields(array $schema, array $spec): array
    {
        $resolved = $this->resolveOpenApiNode($schema, $spec);
        $required = array_values(array_map(
            static fn (mixed $field): string => (string) $field,
            (array) ($resolved['required'] ?? [])
        ));

        foreach (['allOf', 'oneOf', 'anyOf'] as $combinator) {
            foreach ((array) ($resolved[$combinator] ?? []) as $part) {
                $required = array_merge($required, $this->collectSchemaRequiredFields((array) $part, $spec));
            }
        }

        $required = array_values(array_filter($required, static fn (string $field): bool => $field !== ''));
        sort($required);

        return array_values(array_unique($required));
    }

    private function resolveOpenApiNode(array $node, array $spec): array
    {
        if (! isset($node['$ref']) || ! is_string($node['$ref']) || ! str_starts_with($node['$ref'], '#/')) {
            return $node;
        }

        $path = str_replace('/', '.', substr($node['$ref'], 2));
        $resolved = data_get($spec, $path, []);

        return is_array($resolved) ? $resolved : [];
    }

    private function collectFormalDocumentedRoutes(string $content): array
    {
        $officialSection = explode("\n## 15. 当前未纳入正式前台契约的旧示例", $content, 2)[0];
        preg_match_all('/- 请求方式：`(?<method>GET|POST)`\s*- 路由：`(?<path>\/api\/[^`]+)`/u', $officialSection, $matches, PREG_SET_ORDER);

        $documentedRoutes = [];

        foreach ($matches as $match) {
            $documentedRoutes[] = sprintf('%s %s', $match['method'], $match['path']);
        }

        sort($documentedRoutes);
        $documentedRoutes = array_values(array_unique($documentedRoutes));

        preg_match('/当前 phase-one 前台正式接口共\s*(\d+)\s*个/u', $officialSection, $countMatch);
        $declaredCount = isset($countMatch[1]) ? (int) $countMatch[1] : null;

        return [
            'ok' => true,
            'message' => '根目录正式接口文档已加载',
            'declared_count' => $declaredCount,
            'documented_routes' => $documentedRoutes,
            'official_section' => $officialSection,
        ];
    }

    private function checkOpenApiRoutes(array $actualRoutes, array $openApiRoutes): array
    {
        $actualKeys = array_keys($actualRoutes);
        $openApiKeys = array_keys($openApiRoutes);
        $missing = array_values(array_diff($actualKeys, $openApiKeys));
        $stale = array_values(array_diff($openApiKeys, $actualKeys));
        sort($missing);
        sort($stale);

        $details = [];

        foreach ($missing as $routeKey) {
            $details[] = sprintf('OpenAPI 缺少真实接口：%s', $routeKey);
        }

        foreach ($stale as $routeKey) {
            $details[] = sprintf('OpenAPI 仍保留已不存在接口：%s', $routeKey);
        }

        $ok = $details === [];

        return [
            'ok' => $ok,
            'actual_route_count' => count($actualKeys),
            'openapi_route_count' => count($openApiKeys),
            'missing_in_openapi' => $missing,
            'stale_in_openapi' => $stale,
            'message' => $ok
                ? 'OpenAPI 已覆盖当前 phase-one 前台正式接口'
                : 'OpenAPI 与真实路由存在漂移',
            'details' => $details,
        ];
    }

    private function checkOpenApiRequestFields(array $actualRoutes, array $openApiRoutes): array
    {
        $details = [];

        foreach ($actualRoutes as $routeKey => $actual) {
            $openApi = $openApiRoutes[$routeKey] ?? null;

            if ($openApi === null) {
                continue;
            }

            $actualRequest = $actual['request_contract'];
            $comparisons = [
                'path 参数' => [
                    'actual' => $actualRequest['path_parameters'],
                    'openapi' => $openApi['path_parameters'],
                ],
                'query 参数' => [
                    'actual' => $actualRequest['query_parameters'],
                    'openapi' => $openApi['query_parameters'],
                ],
                'body 字段' => [
                    'actual' => $actualRequest['body_fields'],
                    'openapi' => $openApi['body_fields'],
                ],
                '必填 body 字段' => [
                    'actual' => $actualRequest['required_body_fields'],
                    'openapi' => $openApi['required_body_fields'],
                ],
            ];

            foreach ($comparisons as $label => $comparison) {
                if ($comparison['actual'] === $comparison['openapi']) {
                    continue;
                }

                $details[] = sprintf(
                    '%s 的%s不一致：真实代码=%s，OpenAPI=%s',
                    $routeKey,
                    $label,
                    $this->stringifyList($comparison['actual']),
                    $this->stringifyList($comparison['openapi'])
                );
            }
        }

        $ok = $details === [];

        return [
            'ok' => $ok,
            'message' => $ok
                ? 'OpenAPI request/path/query 字段已与真实 ApiRequest 对齐'
                : 'OpenAPI request/path/query 字段与真实 ApiRequest 存在漂移',
            'details' => $details,
        ];
    }

    private function checkFormalDocumentRoutes(array $actualRoutes, array $formalDocRoutes): array
    {
        if (! ($formalDocRoutes['ok'] ?? false)) {
            return $formalDocRoutes;
        }

        $actualKeys = array_keys($actualRoutes);
        $documentedKeys = (array) ($formalDocRoutes['documented_routes'] ?? []);
        $missing = array_values(array_diff($actualKeys, $documentedKeys));
        $stale = array_values(array_diff($documentedKeys, $actualKeys));
        sort($missing);
        sort($stale);

        $details = [];

        foreach ($missing as $routeKey) {
            $details[] = sprintf('根目录正式接口文档缺少真实接口：%s', $routeKey);
        }

        foreach ($stale as $routeKey) {
            $details[] = sprintf('根目录正式接口文档仍保留已不存在接口：%s', $routeKey);
        }

        $declaredCount = $formalDocRoutes['declared_count'] ?? null;

        if ($declaredCount === null) {
            $details[] = '根目录正式接口文档缺少“当前 phase-one 前台正式接口共 N 个”声明';
        } elseif ($declaredCount !== count($actualKeys)) {
            $details[] = sprintf(
                '根目录正式接口文档声明接口数=%d，但真实接口数=%d',
                $declaredCount,
                count($actualKeys)
            );
        }

        $ok = $details === [];

        return [
            'ok' => $ok,
            'declared_count' => $declaredCount,
            'documented_route_count' => count($documentedKeys),
            'message' => $ok
                ? '根目录正式接口文档只保留当前真实存在的 phase-one 正式接口'
                : '根目录正式接口文档与真实接口范围存在漂移',
            'details' => $details,
        ];
    }

    private function checkAuthContract(
        array $actualRoutes,
        array $openApiRoutes,
        array $spec,
        ?string $formalDoc,
        ?string $authRulesDoc
    ): array {
        $details = [];
        $unprotectedRoutes = array_values(array_keys(array_filter(
            $actualRoutes,
            static fn (array $route): bool => ! $route['auth_protected']
        )));

        foreach ($unprotectedRoutes as $routeKey) {
            $details[] = sprintf('真实前台接口未挂载 auth:api：%s', $routeKey);
        }

        $bearerScheme = (array) data_get($spec, 'components.securitySchemes.BearerAuth', []);
        $schemeReady = ($bearerScheme['type'] ?? null) === 'http'
            && strtolower((string) ($bearerScheme['scheme'] ?? '')) === 'bearer';

        if (! $schemeReady) {
            $details[] = 'OpenAPI 缺少 BearerAuth 安全方案，或方案未声明为 http bearer';
        }

        $routesMissingSecurity = array_values(array_filter(
            array_keys($actualRoutes),
            fn (string $routeKey): bool => isset($openApiRoutes[$routeKey]) && ! $openApiRoutes[$routeKey]['has_bearer_security']
        ));

        foreach ($routesMissingSecurity as $routeKey) {
            $details[] = sprintf('OpenAPI 未声明 BearerAuth：%s', $routeKey);
        }

        if ($formalDoc === null || ! str_contains($formalDoc, 'Authorization: Bearer <token>')) {
            $details[] = sprintf('根目录正式接口文档缺少 Bearer Token 调用示例：%s', self::FORMAL_DOC_RELATIVE_PATH);
        }

        if ($authRulesDoc === null) {
            $details[] = sprintf('认证公共规则文档缺失：%s', self::AUTH_RULES_DOC_RELATIVE_PATH);
        } else {
            if (! str_contains($authRulesDoc, 'Authorization: Bearer <token>')) {
                $details[] = sprintf('认证公共规则文档缺少 Authorization: Bearer <token> 口径：%s', self::AUTH_RULES_DOC_RELATIVE_PATH);
            }

            if (! str_contains($authRulesDoc, 'Bearer Token')) {
                $details[] = sprintf('认证公共规则文档缺少 Bearer Token 正式口径说明：%s', self::AUTH_RULES_DOC_RELATIVE_PATH);
            }
        }

        $ok = $details === [];

        return [
            'ok' => $ok,
            'message' => $ok
                ? 'Bearer Token 认证口径在真实路由、OpenAPI 与根目录文档之间保持一致'
                : 'Bearer Token 认证口径存在漂移',
            'details' => $details,
        ];
    }

    private function checkResponseEnvelope(
        array $openApiRoutes,
        array $spec,
        ?string $formalDoc,
        ?string $authRulesDoc
    ): array {
        $details = [];

        $successResponse = ApiResponse::success(['contract' => 'guard']);
        $errorResponse = ApiResponse::error(ErrorCode::INVALID_PARAMS);

        if (array_keys($successResponse) !== ['code', 'message', 'data']) {
            $details[] = '真实 ApiResponse::success 顶层字段不再是 code/message/data';
        }

        if (($successResponse['code'] ?? null) !== ErrorCode::OK || ($successResponse['message'] ?? null) !== 'ok') {
            $details[] = '真实 ApiResponse::success 不再固定返回 code=0, message=ok';
        }

        if (
            array_keys($errorResponse) !== ['code', 'message', 'data']
            || ! array_key_exists('data', $errorResponse)
            || $errorResponse['data'] !== null
        ) {
            $details[] = '真实 ApiResponse::error 不再固定返回 code/message/data 且 data=null';
        }

        $successEnvelope = (array) data_get($spec, 'components.schemas.ApiSuccessEnvelope', []);
        $errorEnvelope = (array) data_get($spec, 'components.schemas.ApiErrorResponse', []);

        if ($this->collectSchemaRequiredFields($successEnvelope, $spec) !== ['code', 'data', 'message']) {
            $details[] = 'OpenAPI ApiSuccessEnvelope 顶层字段不再是 code/message/data';
        }

        if (($successEnvelope['properties']['code']['const'] ?? null) !== 0 || ($successEnvelope['properties']['message']['const'] ?? null) !== 'ok') {
            $details[] = 'OpenAPI ApiSuccessEnvelope 不再固定声明 code=0, message=ok';
        }

        if ($this->collectSchemaRequiredFields($errorEnvelope, $spec) !== ['code', 'data', 'message']) {
            $details[] = 'OpenAPI ApiErrorResponse 顶层字段不再是 code/message/data';
        }

        if (($errorEnvelope['properties']['data']['type'] ?? null) !== 'null') {
            $details[] = 'OpenAPI ApiErrorResponse 不再固定声明 data=null';
        }

        foreach ($openApiRoutes as $routeKey => $route) {
            if (! $route['success_envelope']) {
                $details[] = sprintf('OpenAPI 200 响应未复用统一成功外壳：%s', $routeKey);
            }

            if (! $route['error_envelope']) {
                $details[] = sprintf('OpenAPI 200 响应未声明统一失败外壳：%s', $routeKey);
            }
        }

        if ($formalDoc === null || ! str_contains($formalDoc, '"code": 0') || ! str_contains($formalDoc, '"data": null')) {
            $details[] = sprintf('根目录正式接口文档缺少统一响应外壳示例：%s', self::FORMAL_DOC_RELATIVE_PATH);
        }

        if ($authRulesDoc === null || ! str_contains($authRulesDoc, '"code": 0') || ! str_contains($authRulesDoc, '"data": null')) {
            $details[] = sprintf('认证公共规则文档缺少统一响应外壳说明：%s', self::AUTH_RULES_DOC_RELATIVE_PATH);
        }

        $ok = $details === [];

        return [
            'ok' => $ok,
            'message' => $ok
                ? '统一响应外壳在真实代码、OpenAPI 与根目录文档之间保持一致'
                : '统一响应外壳存在漂移',
            'details' => $details,
        ];
    }

    private function operationHasBearerSecurity(array $spec, array $operation): bool
    {
        $securityEntries = array_merge(
            (array) data_get($spec, 'security', []),
            (array) data_get($operation, 'security', [])
        );

        foreach ($securityEntries as $entry) {
            if (is_array($entry) && array_key_exists('BearerAuth', $entry)) {
                return true;
            }
        }

        return false;
    }

    private function operationResponseContainsEnvelope(array $operation, array $spec, string $targetRef): bool
    {
        $schema = (array) data_get($operation, 'responses.200.content.application/json.schema', []);

        return $this->schemaContainsReference($schema, $spec, $targetRef);
    }

    private function schemaContainsReference(array $schema, array $spec, string $targetRef, array $visited = []): bool
    {
        if (($schema['$ref'] ?? null) === $targetRef) {
            return true;
        }

        if (isset($schema['$ref']) && is_string($schema['$ref'])) {
            if (in_array($schema['$ref'], $visited, true)) {
                return false;
            }

            $visited[] = $schema['$ref'];

            return $this->schemaContainsReference(
                $this->resolveOpenApiNode($schema, $spec),
                $spec,
                $targetRef,
                $visited
            );
        }

        foreach (['allOf', 'oneOf', 'anyOf'] as $combinator) {
            foreach ((array) ($schema[$combinator] ?? []) as $part) {
                if ($this->schemaContainsReference((array) $part, $spec, $targetRef, $visited)) {
                    return true;
                }
            }
        }

        return false;
    }

    private function loadTextFile(string $path): ?string
    {
        if (! is_file($path)) {
            return null;
        }

        return file_get_contents($path) ?: null;
    }

    private function repoRootPath(string $relativePath): string
    {
        return dirname(base_path()).DIRECTORY_SEPARATOR.$relativePath;
    }

    private function stringifyList(array $values): string
    {
        if ($values === []) {
            return '[]';
        }

        return '['.implode(', ', $values).']';
    }
}
