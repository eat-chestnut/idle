<?php

namespace Tests\Feature\Api;

use Tests\TestCase;

class PhaseOneFrontendContractArtifactTest extends TestCase
{
    public function test_openapi_contract_covers_current_phase_one_public_api_routes(): void
    {
        $spec = json_decode(
            (string) file_get_contents(base_path('docs/api/phase-one-frontend.openapi.json')),
            true,
            512,
            JSON_THROW_ON_ERROR
        );

        $documentedPaths = array_keys((array) data_get($spec, 'paths', []));
        sort($documentedPaths);

        $actualRouteMap = [];

        foreach (app('router')->getRoutes()->getRoutes() as $route) {
            if (! str_starts_with($route->uri(), 'api/')) {
                continue;
            }

            $methods = array_values(array_map(
                'strtolower',
                array_filter(
                    $route->methods(),
                    static fn (string $method): bool => in_array($method, ['GET', 'POST'], true)
                )
            ));

            if ($methods === []) {
                continue;
            }

            $actualRouteMap['/'.$route->uri()] = $methods;
        }

        ksort($actualRouteMap);

        $this->assertSame(array_keys($actualRouteMap), $documentedPaths);

        foreach ($actualRouteMap as $path => $methods) {
            $this->assertEqualsCanonicalizing(
                $methods,
                array_keys((array) data_get($spec, "paths.{$path}", [])),
                sprintf('OpenAPI contract is missing methods for [%s].', $path)
            );
        }
    }

    public function test_openapi_contract_keeps_key_request_fields_in_sync(): void
    {
        $spec = json_decode(
            (string) file_get_contents(base_path('docs/api/phase-one-frontend.openapi.json')),
            true,
            512,
            JSON_THROW_ON_ERROR
        );

        $this->assertSame(
            ['class_id', 'character_name'],
            data_get($spec, 'paths./api/characters.post.requestBody.content.application/json.schema.required')
        );

        $this->assertSame(
            ['tab', 'page', 'page_size'],
            array_map(
                static function (array $parameter) use ($spec): string {
                    if (isset($parameter['name'])) {
                        return (string) $parameter['name'];
                    }

                    $parameterKey = basename((string) $parameter['$ref']);

                    return (string) data_get($spec, "components.parameters.{$parameterKey}.name");
                },
                data_get($spec, 'paths./api/inventory.get.parameters', [])
            )
        );

        $this->assertSame(
            ['character_id', 'stage_difficulty_id'],
            data_get($spec, 'paths./api/battles/prepare.post.requestBody.content.application/json.schema.required')
        );

        $this->assertSame(
            ['character_id', 'stage_difficulty_id', 'battle_context_id', 'is_cleared', 'killed_monsters'],
            data_get($spec, 'paths./api/battles/settle.post.requestBody.content.application/json.schema.required')
        );
    }
}
