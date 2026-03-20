<?php

namespace Tests\Feature\Admin;

use App\Models\Admin\AdminUser;
use Database\Seeders\AdminUserSeeder;
use Database\Seeders\DatabaseSeeder;
use Database\Seeders\TestUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PhaseOneAdminPagesTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(DatabaseSeeder::class);
    }

    public function test_admin_routes_require_login(): void
    {
        $this->get('/admin')
            ->assertRedirect('/admin/login');

        $this->get('/admin/resources/battle-contexts')
            ->assertRedirect('/admin/login');
    }

    public function test_admin_can_login_and_query_real_state_pages(): void
    {
        $battleContextId = $this->prepareBattleContextId();

        $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => $battleContextId,
            'is_cleared' => 1,
            'killed_monsters' => ['monster_boss_001'],
        ], $this->apiHeaders())->assertOk()->assertJsonPath('code', 0);

        $this->post('/admin/login', [
            'username' => AdminUserSeeder::DEFAULT_USERNAME,
            'password' => AdminUserSeeder::DEFAULT_PASSWORD,
        ])->assertRedirect('/admin');

        $this->get('/admin/resources/battle-contexts')
            ->assertOk()
            ->assertSee('Battle Context 查询页')
            ->assertSee($battleContextId)
            ->assertSee('settled');

        $this->get('/admin/resources/reward-grants')
            ->assertOk()
            ->assertSee('reward_first_clear_001')
            ->assertSee('success');

        $this->get('/admin/resources/reward-grant-items')
            ->assertOk()
            ->assertSee('mat_coin_001')
            ->assertSee('eq_armor_001');

        $this->get('/admin/resources/characters')
            ->assertOk()
            ->assertSee('角色查询页')
            ->assertSee('1001');

        $this->get('/admin/resources/inventory-stack-items')
            ->assertOk()
            ->assertSee('可堆叠背包查询页')
            ->assertSee('mat_coin_001');

        $this->get('/admin/resources/inventory-equipment-instances')
            ->assertOk()
            ->assertSee('装备实例查询页')
            ->assertSee('eq_armor_001');
    }

    public function test_admin_can_maintain_drop_and_reward_configuration_pages(): void
    {
        $this->actingAs(AdminUser::query()->firstOrFail(), 'admin');

        $this->post('/admin/resources/drop-groups', [
            'drop_group_id' => 'drop_admin_999',
            'drop_group_name' => '后台测试掉落组',
            'roll_type' => 'weighted_repeat',
            'roll_times' => 2,
            'is_enabled' => 1,
            'sort_order' => 99,
        ])->assertRedirect('/admin/resources/drop-groups');

        $this->assertDatabaseHas('drop_groups', [
            'drop_group_id' => 'drop_admin_999',
            'drop_group_name' => '后台测试掉落组',
            'roll_type' => 'weighted_repeat',
            'roll_times' => 2,
            'is_enabled' => true,
        ]);

        $this->put('/admin/resources/drop-group-bindings/1', [
            'source_type' => 'monster',
            'source_id' => 'monster_spirit_001',
            'drop_group_id' => 'drop_admin_999',
        ])->assertRedirect('/admin/resources/drop-group-bindings');

        $this->assertDatabaseHas('drop_group_bindings', [
            'id' => 1,
            'source_type' => 'monster',
            'source_id' => 'monster_spirit_001',
            'drop_group_id' => 'drop_admin_999',
        ]);

        $this->post('/admin/resources/reward-groups', [
            'reward_group_id' => 'reward_admin_999',
            'reward_group_name' => '后台测试奖励组',
            'is_enabled' => 1,
            'sort_order' => 99,
        ])->assertRedirect('/admin/resources/reward-groups');

        $this->assertDatabaseHas('reward_groups', [
            'reward_group_id' => 'reward_admin_999',
            'reward_group_name' => '后台测试奖励组',
            'is_enabled' => true,
        ]);

        $this->put('/admin/resources/reward-group-bindings/1', [
            'source_type' => 'first_clear',
            'source_id' => 'stage_nanshan_001_normal',
            'reward_group_id' => 'reward_admin_999',
        ])->assertRedirect('/admin/resources/reward-group-bindings');

        $this->assertDatabaseHas('reward_group_bindings', [
            'id' => 1,
            'source_type' => 'first_clear',
            'source_id' => 'stage_nanshan_001_normal',
            'reward_group_id' => 'reward_admin_999',
        ]);
    }

    public function test_all_admin_resource_indexes_render_and_config_create_pages_open(): void
    {
        $this->actingAs(AdminUser::query()->firstOrFail(), 'admin');

        $indexResources = [
            'classes',
            'items',
            'equipment-templates',
            'chapters',
            'stages',
            'stage-difficulties',
            'monsters',
            'stage-monster-bindings',
            'drop-groups',
            'drop-group-items',
            'drop-group-bindings',
            'reward-groups',
            'reward-group-items',
            'reward-group-bindings',
            'characters',
            'character-equipment-slots',
            'inventory-stack-items',
            'inventory-equipment-instances',
            'reward-grants',
            'reward-grant-items',
            'battle-contexts',
        ];

        foreach ($indexResources as $resource) {
            $this->get('/admin/resources/'.$resource)->assertOk();
        }

        $configResources = [
            'classes',
            'items',
            'equipment-templates',
            'chapters',
            'stages',
            'stage-difficulties',
            'monsters',
            'stage-monster-bindings',
            'drop-groups',
            'drop-group-items',
            'drop-group-bindings',
            'reward-groups',
            'reward-group-items',
            'reward-group-bindings',
        ];

        foreach ($configResources as $resource) {
            $this->get('/admin/resources/'.$resource.'/create')->assertOk();
        }
    }

    private function prepareBattleContextId(): string
    {
        $response = $this->postJson('/api/battles/prepare', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
        ], $this->apiHeaders());

        $response->assertOk()->assertJsonPath('code', 0);

        return (string) $response->json('data.battle_context_id');
    }

    private function apiHeaders(): array
    {
        return [
            'Accept' => 'application/json',
            'Authorization' => 'Bearer '.TestUserSeeder::TEST_USER_TOKEN,
        ];
    }
}
