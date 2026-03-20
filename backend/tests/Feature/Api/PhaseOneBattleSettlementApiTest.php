<?php

namespace Tests\Feature\Api;

use App\Enums\Drop\DropRollType;
use Database\Seeders\DatabaseSeeder;
use Database\Seeders\TestUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
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

    public function test_settlement_rolls_back_all_written_state_when_reward_chain_fails(): void
    {
        $this->forceDropGroupToSingleResult('drop_boss_001', 'mat_coin_001', 10);
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

        $this->assertDatabaseHas('inventory_stack_items', [
            'user_id' => TestUserSeeder::TEST_USER_ID,
            'item_id' => 'mat_coin_001',
            'quantity' => 20,
        ]);

        $this->assertDatabaseCount('user_reward_grants', 0);
        $this->assertDatabaseCount('user_reward_grant_items', 0);
        $this->assertDatabaseCount('inventory_equipment_instances', 4);
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
