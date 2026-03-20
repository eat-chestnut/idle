<?php

namespace Tests\Feature\Api;

use App\Enums\Battle\BattleContextStatus;
use App\Enums\Drop\DropRollType;
use App\Exceptions\BusinessException;
use App\Services\Battle\Workflow\BattleSettlementWorkflow;
use App\Support\Lock\WorkflowLockService;
use Database\Seeders\DatabaseSeeder;
use Database\Seeders\TestUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PhaseOneBattleSettlementApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(DatabaseSeeder::class);
    }

    public function test_settle_api_requires_bearer_token(): void
    {
        $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => 'battle_ctx_20260320_120000_ab12cd',
            'is_cleared' => 0,
            'killed_monsters' => ['monster_spirit_001'],
        ])->assertOk()
            ->assertJsonPath('code', 10002)
            ->assertJsonPath('message', '未登录或登录失效')
            ->assertJsonPath('data', null);
    }

    public function test_invalid_battle_context_returns_formal_error_code(): void
    {
        $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => 'invalid_ctx',
            'is_cleared' => 0,
            'killed_monsters' => ['monster_spirit_001'],
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 10501)
            ->assertJsonPath('data', null);
    }

    public function test_nonexistent_battle_context_returns_formal_error_code(): void
    {
        $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => 'battle_ctx_20260320_120000_ab12cd',
            'is_cleared' => 0,
            'killed_monsters' => ['monster_spirit_001'],
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 10501)
            ->assertJsonPath('data', null);
    }

    public function test_can_settle_battle_with_formal_drop_results(): void
    {
        $this->forceDropGroupToSingleResult('drop_normal_001', 'mat_wood_001', 1);
        $battleContextId = $this->prepareBattleContextId();

        $response = $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => $battleContextId,
            'is_cleared' => 0,
            'killed_monsters' => ['monster_spirit_001'],
        ], $this->authHeaders());

        $response->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.stage_difficulty.stage_difficulty_id', 'stage_nanshan_001_normal')
            ->assertJsonPath('data.is_cleared', 0)
            ->assertJsonCount(1, 'data.drop_results')
            ->assertJsonPath('data.drop_results.0.item_id', 'mat_wood_001')
            ->assertJsonPath('data.drop_results.0.quantity', 1)
            ->assertJsonCount(0, 'data.reward_results')
            ->assertJsonPath('data.inventory_results.stack_results.0.item_id', 'mat_wood_001')
            ->assertJsonPath('data.inventory_results.stack_results.0.before_quantity', 10)
            ->assertJsonPath('data.inventory_results.stack_results.0.after_quantity', 11)
            ->assertJsonCount(0, 'data.created_equipment_instances')
            ->assertJsonPath('data.first_clear_reward_status.has_reward', 1)
            ->assertJsonPath('data.first_clear_reward_status.has_granted', 0);

        $this->assertDatabaseHas('inventory_stack_items', [
            'user_id' => TestUserSeeder::TEST_USER_ID,
            'item_id' => 'mat_wood_001',
            'quantity' => 11,
        ]);
        $this->assertDatabaseHas('battle_contexts', [
            'battle_context_id' => $battleContextId,
            'status' => BattleContextStatus::SETTLED->value,
        ]);
    }

    public function test_first_clear_reward_is_granted_once_and_equipment_objects_become_instances(): void
    {
        $this->forceDropGroupToSingleResult('drop_boss_001', 'eq_staff_001', 1);

        $firstContextId = $this->prepareBattleContextId();
        $firstResponse = $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => $firstContextId,
            'is_cleared' => 1,
            'killed_monsters' => ['monster_boss_001'],
        ], $this->authHeaders());

        $firstResponse->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonCount(1, 'data.drop_results')
            ->assertJsonPath('data.drop_results.0.item_id', 'eq_staff_001')
            ->assertJsonCount(1, 'data.reward_results')
            ->assertJsonPath('data.reward_results.0.reward_group_id', 'reward_first_clear_001')
            ->assertJsonPath('data.reward_results.0.grant_status', 'success')
            ->assertJsonPath('data.first_clear_reward_status.has_granted', 1)
            ->assertJsonPath('data.first_clear_reward_status.grant_status', 'success')
            ->assertJsonCount(2, 'data.created_equipment_instances')
            ->assertJsonPath('data.settlement_summary.reward_count', 1)
            ->assertJsonPath('data.settlement_summary.created_equipment_instance_count', 2);

        $this->assertDatabaseCount('user_reward_grants', 1);
        $this->assertDatabaseCount('user_reward_grant_items', 3);
        $this->assertDatabaseCount('inventory_equipment_instances', 6);

        $secondContextId = $this->prepareBattleContextId();
        $secondResponse = $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => $secondContextId,
            'is_cleared' => 1,
            'killed_monsters' => ['monster_boss_001'],
        ], $this->authHeaders());

        $secondResponse->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonCount(0, 'data.reward_results')
            ->assertJsonPath('data.first_clear_reward_status.has_granted', 1)
            ->assertJsonPath('data.first_clear_reward_status.grant_status', 'success')
            ->assertJsonCount(1, 'data.created_equipment_instances')
            ->assertJsonPath('data.settlement_summary.reward_count', 0);

        $this->assertDatabaseCount('user_reward_grants', 1);
        $this->assertDatabaseCount('inventory_equipment_instances', 7);
    }

    public function test_battle_context_must_match_owner_and_cannot_be_replayed(): void
    {
        $battleContextId = $this->prepareBattleContextId();

        DB::table('users')->insert([
            'id' => 3001,
            'name' => 'Other User',
            'email' => 'other@example.com',
            'password' => bcrypt('password'),
            'api_token' => hash('sha256', 'other-test-token-2002'),
            'email_verified_at' => null,
            'remember_token' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('characters')->insert([
            'character_id' => 3001,
            'user_id' => 3001,
            'class_id' => 'class_jingang',
            'character_name' => '借用角色',
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

        try {
            $this->app->make(BattleSettlementWorkflow::class)->settleBattle(3001, 3001, 'stage_nanshan_001_normal', [
                'battle_context_id' => $battleContextId,
                'is_cleared' => 0,
                'killed_monsters' => ['monster_spirit_001'],
            ]);

            $this->fail('Expected battle settlement to reject cross-user battle context.');
        } catch (BusinessException $exception) {
            $this->assertSame(10501, $exception->getErrorCode());
        }

        $this->assertDatabaseHas('battle_contexts', [
            'battle_context_id' => $battleContextId,
            'status' => BattleContextStatus::PREPARED->value,
        ]);

        $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_hard',
            'battle_context_id' => $battleContextId,
            'is_cleared' => 0,
            'killed_monsters' => ['monster_spirit_001'],
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 10501)
            ->assertJsonPath('data', null);

        $this->assertDatabaseHas('battle_contexts', [
            'battle_context_id' => $battleContextId,
            'status' => BattleContextStatus::PREPARED->value,
        ]);

        $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => $battleContextId,
            'is_cleared' => 0,
            'killed_monsters' => ['monster_spirit_001'],
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 0);

        $this->assertDatabaseHas('battle_contexts', [
            'battle_context_id' => $battleContextId,
            'status' => BattleContextStatus::SETTLED->value,
        ]);

        $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => $battleContextId,
            'is_cleared' => 0,
            'killed_monsters' => ['monster_spirit_001'],
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 10501)
            ->assertJsonPath('data', null);
    }

    public function test_reward_failure_persists_failed_grant_record_and_prevents_battle_context_replay(): void
    {
        $this->forceDropGroupToSingleResult('drop_boss_001', 'mat_coin_001', 10);
        $beforeCoinQuantity = (int) DB::table('inventory_stack_items')
            ->where('user_id', TestUserSeeder::TEST_USER_ID)
            ->where('item_id', 'mat_coin_001')
            ->value('quantity');
        $beforeEquipmentCount = (int) DB::table('inventory_equipment_instances')
            ->where('user_id', TestUserSeeder::TEST_USER_ID)
            ->count();

        DB::table('items')
            ->where('item_id', 'eq_armor_001')
            ->update(['is_enabled' => false]);

        $battleContextId = $this->prepareBattleContextId();

        $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => $battleContextId,
            'is_cleared' => 1,
            'killed_monsters' => ['monster_boss_001'],
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 10505)
            ->assertJsonPath('data', null);

        $rewardGrantId = (int) DB::table('user_reward_grants')
            ->where('user_id', TestUserSeeder::TEST_USER_ID)
            ->where('source_type', 'first_clear')
            ->where('source_id', 'stage_nanshan_001_normal')
            ->value('reward_grant_id');

        $this->assertGreaterThan(0, $rewardGrantId);
        $this->assertSame(
            $beforeCoinQuantity + 10,
            (int) DB::table('inventory_stack_items')
                ->where('user_id', TestUserSeeder::TEST_USER_ID)
                ->where('item_id', 'mat_coin_001')
                ->value('quantity')
        );
        $this->assertSame(
            $beforeEquipmentCount,
            (int) DB::table('inventory_equipment_instances')
                ->where('user_id', TestUserSeeder::TEST_USER_ID)
                ->count()
        );

        $this->assertDatabaseHas('battle_contexts', [
            'battle_context_id' => $battleContextId,
            'status' => BattleContextStatus::SETTLED->value,
        ]);
        $this->assertDatabaseHas('user_reward_grants', [
            'reward_grant_id' => $rewardGrantId,
            'grant_status' => 'failed',
            'granted_at' => null,
        ]);
        $this->assertDatabaseCount('user_reward_grants', 1);
        $this->assertDatabaseCount('user_reward_grant_items', 3);

        $failureSnapshot = json_decode((string) DB::table('user_reward_grants')
            ->where('reward_grant_id', $rewardGrantId)
            ->value('grant_payload_snapshot'), true, 512, JSON_THROW_ON_ERROR);

        $this->assertSame(10802, data_get($failureSnapshot, 'last_failure.error_code'));
        $this->assertSame($battleContextId, data_get($failureSnapshot, 'battle_context_id'));
        $this->assertCount(3, data_get($failureSnapshot, 'reward_items', []));

        $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => $battleContextId,
            'is_cleared' => 1,
            'killed_monsters' => ['monster_boss_001'],
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 10501)
            ->assertJsonPath('data', null);
    }

    public function test_battle_settlement_returns_clear_error_when_workflow_lock_is_busy(): void
    {
        $battleContextId = $this->prepareBattleContextId();
        $workflowLockService = $this->app->make(WorkflowLockService::class);
        $lock = Cache::store((string) config('workflow_lock.store'))
            ->lock($workflowLockService->battleSettlementKey($battleContextId), 30);

        $this->assertTrue($lock->get());

        try {
            $this->postJson('/api/battles/settle', [
                'character_id' => 1001,
                'stage_difficulty_id' => 'stage_nanshan_001_normal',
                'battle_context_id' => $battleContextId,
                'is_cleared' => 0,
                'killed_monsters' => ['monster_spirit_001'],
            ], $this->authHeaders())->assertOk()
                ->assertJsonPath('code', 10006)
                ->assertJsonPath('message', '战斗结算正在处理中，请勿重复提交')
                ->assertJsonPath('data', null);

            $this->assertDatabaseHas('battle_contexts', [
                'battle_context_id' => $battleContextId,
                'status' => BattleContextStatus::PREPARED->value,
            ]);
        } finally {
            $lock->release();
        }
    }

    public function test_battle_settlement_returns_formal_error_when_lock_capability_is_unavailable(): void
    {
        $battleContextId = $this->prepareBattleContextId();
        config(['workflow_lock.store' => 'null']);

        $this->postJson('/api/battles/settle', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => $battleContextId,
            'is_cleared' => 0,
            'killed_monsters' => ['monster_spirit_001'],
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 10011)
            ->assertJsonPath('message', 'workflow lock store [null] 返回 NoLock，无法提供正式互斥能力')
            ->assertJsonPath('data', null);

        $this->assertDatabaseHas('battle_contexts', [
            'battle_context_id' => $battleContextId,
            'status' => BattleContextStatus::PREPARED->value,
        ]);
    }

    private function prepareBattleContextId(): string
    {
        $response = $this->postJson('/api/battles/prepare', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
        ], $this->authHeaders());

        $response->assertOk()->assertJsonPath('code', 0);

        return (string) $response->json('data.battle_context_id');
    }

    private function forceDropGroupToSingleResult(string $dropGroupId, string $itemId, int $quantity): void
    {
        DB::table('drop_groups')
            ->where('drop_group_id', $dropGroupId)
            ->update([
                'roll_type' => DropRollType::WEIGHTED_REPEAT->value,
                'roll_times' => 1,
            ]);

        DB::table('drop_group_items')
            ->where('drop_group_id', $dropGroupId)
            ->update([
                'weight' => 0,
                'min_quantity' => 1,
                'max_quantity' => 1,
            ]);

        DB::table('drop_group_items')
            ->where('drop_group_id', $dropGroupId)
            ->where('item_id', $itemId)
            ->update([
                'weight' => 100,
                'min_quantity' => $quantity,
                'max_quantity' => $quantity,
            ]);
    }

    private function authHeaders(): array
    {
        return [
            'Accept' => 'application/json',
            'Authorization' => 'Bearer '.TestUserSeeder::TEST_USER_TOKEN,
        ];
    }
}
