<?php

namespace Tests\Feature\Admin;

use App\Models\Admin\AdminUser;
use Database\Seeders\AdminUserSeeder;
use Database\Seeders\DatabaseSeeder;
use Database\Seeders\TestUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
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

        $this->get('/admin/tools')
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

        $this->get('/admin/tools')->assertOk()->assertSee('后台运维工具');
    }

    public function test_reference_conflict_blocks_disable_and_delete(): void
    {
        $this->actingAs(AdminUser::query()->firstOrFail(), 'admin');

        $this->put('/admin/resources/reward-groups/reward_first_clear_001', [
            'reward_group_id' => 'reward_first_clear_001',
            'reward_group_name' => '招摇山首通奖励',
            'sort_order' => 1,
        ])->assertSessionHasErrors(['operation']);

        $this->assertDatabaseHas('reward_groups', [
            'reward_group_id' => 'reward_first_clear_001',
            'is_enabled' => true,
        ]);

        $this->delete('/admin/resources/reward-groups/reward_first_clear_001')
            ->assertSessionHasErrors(['operation']);

        $this->assertDatabaseHas('reward_groups', [
            'reward_group_id' => 'reward_first_clear_001',
        ]);
    }

    public function test_reward_retry_tool_can_retry_failed_grant(): void
    {
        $this->actingAs(AdminUser::query()->firstOrFail(), 'admin');

        $rewardGrantId = $this->createFailedRewardGrant([
            ['item_id' => 'mat_coin_001', 'quantity' => 100, 'sort_order' => 1],
            ['item_id' => 'mat_mark_001', 'quantity' => 2, 'sort_order' => 2],
            ['item_id' => 'eq_armor_001', 'quantity' => 1, 'sort_order' => 3],
        ], [
            'source_id' => 'stage_retry_failed_001',
        ]);

        $beforeCoinQuantity = (int) DB::table('inventory_stack_items')
            ->where('user_id', TestUserSeeder::TEST_USER_ID)
            ->where('item_id', 'mat_coin_001')
            ->value('quantity');
        $beforeEquipmentCount = (int) DB::table('inventory_equipment_instances')
            ->where('user_id', TestUserSeeder::TEST_USER_ID)
            ->where('item_id', 'eq_armor_001')
            ->count();

        $this->post('/admin/tools/reward-retry', [
            'reward_grant_id' => $rewardGrantId,
        ])->assertRedirect('/admin/tools');

        $this->assertDatabaseHas('user_reward_grants', [
            'reward_grant_id' => $rewardGrantId,
            'grant_status' => 'success',
        ]);

        $this->assertSame(
            $beforeCoinQuantity + 100,
            (int) DB::table('inventory_stack_items')
                ->where('user_id', TestUserSeeder::TEST_USER_ID)
                ->where('item_id', 'mat_coin_001')
                ->value('quantity')
        );

        $this->assertSame(
            $beforeEquipmentCount + 1,
            (int) DB::table('inventory_equipment_instances')
                ->where('user_id', TestUserSeeder::TEST_USER_ID)
                ->where('item_id', 'eq_armor_001')
                ->count()
        );
    }

    public function test_reward_retry_tool_rejects_non_failed_record(): void
    {
        $battleContextId = $this->prepareBattleContextId();

        $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => $battleContextId,
            'is_cleared' => 1,
            'killed_monsters' => ['monster_boss_001'],
        ], $this->apiHeaders())->assertOk()->assertJsonPath('code', 0);

        $rewardGrantId = (int) DB::table('user_reward_grants')
            ->where('user_id', TestUserSeeder::TEST_USER_ID)
            ->where('source_id', 'stage_nanshan_001_normal')
            ->value('reward_grant_id');

        $this->actingAs(AdminUser::query()->firstOrFail(), 'admin');

        $this->post('/admin/tools/reward-retry', [
            'reward_grant_id' => $rewardGrantId,
        ])->assertSessionHasErrors(['reward_retry']);
    }

    public function test_repair_tool_repairs_minimal_safe_scenarios(): void
    {
        $this->actingAs(AdminUser::query()->firstOrFail(), 'admin');

        DB::table('battle_contexts')->insert([
            'battle_context_id' => 'battle_ctx_20260320_999999_abcdef',
            'user_id' => TestUserSeeder::TEST_USER_ID,
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'status' => 'prepared',
            'settled_at' => now(),
            'created_at' => now()->subMinute(),
            'updated_at' => now(),
        ]);

        $repairRewardGrantId = $this->createSuccessfulRewardGrantWithoutGrantedAt();

        $this->post('/admin/tools/repair-battle-context', [
            'battle_context_id' => 'battle_ctx_20260320_999999_abcdef',
        ])->assertRedirect('/admin/tools');

        $this->assertDatabaseHas('battle_contexts', [
            'battle_context_id' => 'battle_ctx_20260320_999999_abcdef',
            'status' => 'settled',
        ]);

        $this->post('/admin/tools/repair-reward-grant', [
            'reward_grant_id' => $repairRewardGrantId,
        ])->assertRedirect('/admin/tools');

        $this->assertNotNull(
            DB::table('user_reward_grants')
                ->where('reward_grant_id', $repairRewardGrantId)
                ->value('granted_at')
        );
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

    private function createFailedRewardGrant(array $items, array $overrides = []): int
    {
        $rewardGrantId = (int) DB::table('user_reward_grants')->insertGetId([
            'user_id' => TestUserSeeder::TEST_USER_ID,
            'source_type' => 'first_clear',
            'source_id' => 'stage_retry_failed_default',
            'reward_group_id' => 'reward_first_clear_001',
            'idempotency_key' => 'retry-failed-'.uniqid('', true),
            'grant_status' => 'failed',
            'granted_at' => null,
            'grant_payload_snapshot' => json_encode([
                'battle_context_id' => 'battle_ctx_20260320_888888_retry01',
                'reward_items' => $items,
            ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'created_at' => now(),
            'updated_at' => now(),
            ...$overrides,
        ], 'reward_grant_id');

        foreach ($items as $item) {
            DB::table('user_reward_grant_items')->insert([
                'reward_grant_id' => $rewardGrantId,
                'item_id' => $item['item_id'],
                'quantity' => $item['quantity'],
                'sort_order' => $item['sort_order'],
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        return $rewardGrantId;
    }

    private function createSuccessfulRewardGrantWithoutGrantedAt(): int
    {
        $rewardGrantId = (int) DB::table('user_reward_grants')->insertGetId([
            'user_id' => TestUserSeeder::TEST_USER_ID,
            'source_type' => 'first_clear',
            'source_id' => 'stage_repair_reward_001',
            'reward_group_id' => 'reward_first_clear_001',
            'idempotency_key' => 'repair-success-'.uniqid('', true),
            'grant_status' => 'success',
            'granted_at' => null,
            'grant_payload_snapshot' => json_encode([
                'battle_context_id' => 'battle_ctx_20260320_777777_repair1',
            ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'created_at' => now()->subMinute(),
            'updated_at' => now(),
        ], 'reward_grant_id');

        DB::table('user_reward_grant_items')->insert([
            'reward_grant_id' => $rewardGrantId,
            'item_id' => 'mat_coin_001',
            'quantity' => 10,
            'sort_order' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $rewardGrantId;
    }
}
