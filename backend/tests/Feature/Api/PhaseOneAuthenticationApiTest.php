<?php

namespace Tests\Feature\Api;

use Database\Seeders\DatabaseSeeder;
use Database\Seeders\TestUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PhaseOneAuthenticationApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(DatabaseSeeder::class);
    }

    public function test_all_phase_one_frontend_routes_require_bearer_token(): void
    {
        $cases = [
            ['method' => 'GET', 'uri' => '/api/chapters', 'payload' => []],
            ['method' => 'GET', 'uri' => '/api/chapters/chapter_nanshan_001/stages', 'payload' => []],
            ['method' => 'GET', 'uri' => '/api/stages/stage_nanshan_001/difficulties', 'payload' => []],
            ['method' => 'GET', 'uri' => '/api/stage-difficulties/stage_nanshan_001_normal/first-clear-reward-status', 'payload' => []],
            ['method' => 'GET', 'uri' => '/api/characters', 'payload' => []],
            ['method' => 'POST', 'uri' => '/api/characters', 'payload' => [
                'class_id' => 'class_fashi',
                'character_name' => '未鉴权角色',
            ]],
            ['method' => 'GET', 'uri' => '/api/characters/1001', 'payload' => []],
            ['method' => 'POST', 'uri' => '/api/characters/1001/activate', 'payload' => []],
            ['method' => 'GET', 'uri' => '/api/characters/1001/equipment-slots', 'payload' => []],
            ['method' => 'POST', 'uri' => '/api/characters/1001/equip', 'payload' => [
                'equipment_instance_id' => 5001,
                'target_slot_key' => 'main_weapon',
            ]],
            ['method' => 'POST', 'uri' => '/api/characters/1001/unequip', 'payload' => [
                'target_slot_key' => 'main_weapon',
            ]],
            ['method' => 'GET', 'uri' => '/api/inventory?tab=all&page=1&page_size=20', 'payload' => []],
            ['method' => 'POST', 'uri' => '/api/battles/prepare', 'payload' => [
                'character_id' => 1001,
                'stage_difficulty_id' => 'stage_nanshan_001_normal',
            ]],
            ['method' => 'POST', 'uri' => '/api/battles/settle', 'payload' => [
                'character_id' => 1001,
                'stage_difficulty_id' => 'stage_nanshan_001_normal',
                'battle_context_id' => 'battle_ctx_20260320_120000_auth01',
                'is_cleared' => 0,
                'killed_monsters' => ['monster_spirit_001'],
            ]],
        ];

        foreach ($cases as $case) {
            $response = $case['method'] === 'GET'
                ? $this->getJson($case['uri'])
                : $this->postJson($case['uri'], $case['payload']);

            $response->assertOk()
                ->assertJsonPath('code', 10002)
                ->assertJsonPath('message', '未登录或登录失效')
                ->assertJsonPath('data', null);
        }
    }

    public function test_character_create_uses_authenticated_user_context_even_when_user_id_is_provided(): void
    {
        $response = $this->postJson('/api/characters', [
            'class_id' => 'class_fashi',
            'character_name' => '鉴权边界角',
            'user_id' => 9999,
        ], $this->authHeaders());

        $response->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.character.class_id', 'class_fashi');

        $characterId = (int) $response->json('data.character.character_id');

        $this->assertDatabaseHas('characters', [
            'character_id' => $characterId,
            'user_id' => TestUserSeeder::TEST_USER_ID,
            'character_name' => '鉴权边界角',
        ]);
    }

    public function test_character_read_and_battle_prepare_reject_other_users_character(): void
    {
        DB::table('users')->insert([
            'id' => 3001,
            'name' => 'Other User',
            'email' => 'owner3001@example.com',
            'password' => bcrypt('password'),
            'api_token' => hash('sha256', 'owner-3001-token'),
            'email_verified_at' => null,
            'remember_token' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('characters')->insert([
            'character_id' => 3001,
            'user_id' => 3001,
            'class_id' => 'class_jingang',
            'character_name' => '他人角色',
            'level' => 1,
            'exp' => 0,
            'unspent_stat_points' => 0,
            'added_strength' => 0,
            'added_mana' => 0,
            'added_constitution' => 0,
            'added_dexterity' => 0,
            'long_term_growth_stage' => null,
            'extra_context' => null,
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->getJson('/api/characters/3001', $this->authHeaders())
            ->assertOk()
            ->assertJsonPath('code', 10102)
            ->assertJsonPath('message', '无权访问该角色')
            ->assertJsonPath('data', null);

        $this->getJson('/api/characters/3001/equipment-slots', $this->authHeaders())
            ->assertOk()
            ->assertJsonPath('code', 10102)
            ->assertJsonPath('message', '无权访问该角色')
            ->assertJsonPath('data', null);

        $this->postJson('/api/battles/prepare', [
            'character_id' => 3001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 10402)
            ->assertJsonPath('message', '战斗角色无效')
            ->assertJsonPath('data', null);

        $this->postJson('/api/characters/3001/activate', [], $this->authHeaders())
            ->assertOk()
            ->assertJsonPath('code', 10102)
            ->assertJsonPath('message', '无权访问该角色')
            ->assertJsonPath('data', null);
    }

    public function test_cannot_equip_equipment_instance_owned_by_another_user(): void
    {
        DB::table('users')->insert([
            'id' => 3002,
            'name' => 'Equipment Owner',
            'email' => 'owner3002@example.com',
            'password' => bcrypt('password'),
            'api_token' => hash('sha256', 'owner-3002-token'),
            'email_verified_at' => null,
            'remember_token' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('inventory_equipment_instances')->insert([
            'equipment_instance_id' => 9001,
            'user_id' => 3002,
            'item_id' => 'eq_ring_001',
            'bind_type' => 'unbound',
            'enhance_level' => 0,
            'durability' => 100,
            'max_durability' => 100,
            'is_locked' => false,
            'extra_attributes' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->postJson('/api/characters/1001/equip', [
            'equipment_instance_id' => 9001,
            'target_slot_key' => 'ring_1',
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 10202)
            ->assertJsonPath('message', '装备不归属当前用户')
            ->assertJsonPath('data', null);
    }

    private function authHeaders(): array
    {
        return [
            'Accept' => 'application/json',
            'Authorization' => 'Bearer '.TestUserSeeder::TEST_USER_TOKEN,
        ];
    }
}
