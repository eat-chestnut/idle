<?php

namespace Tests\Feature\Api;

use App\Enums\Battle\BattleContextStatus;
use App\Enums\Drop\DropRollType;
use App\Enums\Reward\GrantStatus;
use Database\Seeders\DatabaseSeeder;
use Database\Seeders\TestUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PhaseOnePlayerJourneySmokeTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(DatabaseSeeder::class);
    }

    public function test_phase_one_player_journey_smoke(): void
    {
        $this->getJson('/api/inventory')
            ->assertOk()
            ->assertJsonPath('code', 10002)
            ->assertJsonPath('data', null);

        $this->forceDropGroupToSingleResult('drop_boss_001', 'mat_coin_001', 20);

        $this->getJson(
            '/api/stage-difficulties/stage_nanshan_001_normal/first-clear-reward-status',
            $this->authHeaders()
        )->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.has_reward', 1)
            ->assertJsonPath('data.has_granted', 0)
            ->assertJsonPath('data.grant_status', null);

        $createResponse = $this->postJson('/api/characters', [
            'class_id' => 'class_jingang',
            'character_name' => '联调烟测角',
        ], $this->authHeaders());

        $createResponse->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.character.class_id', 'class_jingang')
            ->assertJsonPath('data.character.is_active', 0)
            ->assertJsonCount(12, 'data.equipment_slots');

        $createdCharacterId = (int) $createResponse->json('data.character.character_id');
        $activeCharacterId = 1001;

        $this->getJson("/api/characters/{$createdCharacterId}", $this->authHeaders())
            ->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.character.character_id', $createdCharacterId)
            ->assertJsonPath('data.character.character_name', '联调烟测角')
            ->assertJsonPath('data.character.is_active', 0);

        $this->postJson("/api/characters/{$activeCharacterId}/equip", [
            'equipment_instance_id' => 5001,
            'target_slot_key' => 'main_weapon',
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.equipped_instance_id', 5001);

        $this->postJson("/api/characters/{$activeCharacterId}/equip", [
            'equipment_instance_id' => 5002,
            'target_slot_key' => 'sub_weapon',
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.equipped_instance_id', 5002);

        $this->getJson("/api/characters/{$activeCharacterId}/equipment-slots", $this->authHeaders())
            ->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.slots.0.slot_key', 'main_weapon')
            ->assertJsonPath('data.slots.0.equipped_instance_id', 5001)
            ->assertJsonPath('data.slots.1.slot_key', 'sub_weapon')
            ->assertJsonPath('data.slots.1.equipped_instance_id', 5002);

        $prepareResponse = $this->postJson('/api/battles/prepare', [
            'character_id' => $activeCharacterId,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
        ], $this->authHeaders());

        $prepareResponse->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.character.character_id', $activeCharacterId)
            ->assertJsonPath('data.stage_difficulty.stage_difficulty_id', 'stage_nanshan_001_normal')
            ->assertJsonPath('data.slot_snapshot.0.equipped_instance_id', 5001)
            ->assertJsonPath('data.slot_snapshot.1.equipped_instance_id', 5002);

        $battleContextId = (string) $prepareResponse->json('data.battle_context_id');

        $settleResponse = $this->postJson('/api/battles/settle', [
            'character_id' => $activeCharacterId,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
            'battle_context_id' => $battleContextId,
            'is_cleared' => 1,
            'killed_monsters' => ['monster_boss_001'],
        ], $this->authHeaders());

        $settleResponse->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.stage_difficulty.stage_difficulty_id', 'stage_nanshan_001_normal')
            ->assertJsonPath('data.is_cleared', 1)
            ->assertJsonPath('data.reward_results.0.reward_group_id', 'reward_first_clear_001')
            ->assertJsonPath('data.reward_results.0.grant_status', 'success')
            ->assertJsonPath('data.created_equipment_instances.0.item_id', 'eq_armor_001')
            ->assertJsonPath('data.first_clear_reward_status.has_reward', 1)
            ->assertJsonPath('data.first_clear_reward_status.has_granted', 1)
            ->assertJsonPath('data.first_clear_reward_status.grant_status', 'success')
            ->assertJsonPath('data.settlement_summary.reward_count', 1)
            ->assertJsonPath('data.settlement_summary.created_equipment_instance_count', 1);

        $this->getJson(
            '/api/stage-difficulties/stage_nanshan_001_normal/first-clear-reward-status',
            $this->authHeaders()
        )->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.has_granted', 1)
            ->assertJsonPath('data.grant_status', 'success');

        $this->assertDatabaseHas('battle_contexts', [
            'battle_context_id' => $battleContextId,
            'status' => BattleContextStatus::SETTLED->value,
        ]);
        $this->assertDatabaseHas('user_reward_grants', [
            'user_id' => TestUserSeeder::TEST_USER_ID,
            'source_type' => 'first_clear',
            'source_id' => 'stage_nanshan_001_normal',
            'grant_status' => GrantStatus::SUCCESS->value,
        ]);
        $this->assertSame(
            5,
            (int) DB::table('inventory_equipment_instances')
                ->where('user_id', TestUserSeeder::TEST_USER_ID)
                ->count()
        );
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
