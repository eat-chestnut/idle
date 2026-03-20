<?php

namespace Tests\Feature\Http;

use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PhaseOneReadinessEndpointTest extends TestCase
{
    use RefreshDatabase;

    public function test_up_endpoint_can_be_used_as_liveness_probe(): void
    {
        $this->get('/up')->assertOk();
    }

    public function test_readyz_returns_ok_when_phase_one_interop_prerequisites_are_ready(): void
    {
        config(['workflow_lock.store' => 'array']);

        $this->seed(DatabaseSeeder::class);

        $this->getJson('/readyz')
            ->assertOk()
            ->assertJsonPath('selected_profile', 'interop')
            ->assertJsonPath('ready', true)
            ->assertJsonPath('profiles.service.ready', true)
            ->assertJsonPath('profiles.interop.ready', true)
            ->assertJsonPath('profiles.acceptance.ready', true);
    }

    public function test_readyz_returns_service_unavailable_when_acceptance_prerequisite_is_missing(): void
    {
        config(['workflow_lock.store' => 'array']);

        $this->seed(DatabaseSeeder::class);
        DB::table('admin_users')->delete();

        $this->getJson('/readyz?profile=acceptance')
            ->assertStatus(503)
            ->assertJsonPath('selected_profile', 'acceptance')
            ->assertJsonPath('ready', false)
            ->assertJsonPath('profiles.interop.ready', true)
            ->assertJsonPath('profiles.acceptance.ready', false)
            ->assertJsonPath('checks.admin_bootstrap.ready', false)
            ->assertJsonPath('checks.admin_bootstrap.message', '后台管理员未初始化，请先执行 DatabaseSeeder 或 AdminUserSeeder');
    }
}
