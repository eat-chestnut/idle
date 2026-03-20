<?php

namespace Tests\Feature\Api;

use App\Enums\Reward\GrantStatus;
use App\Enums\Reward\RewardSourceType;
use Database\Seeders\DatabaseSeeder;
use Database\Seeders\TestUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PhaseOneBattlePrepareApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(DatabaseSeeder::class);
    }

    public function test_stage_and_battle_api_require_bearer_token(): void
    {
        $this->getJson('/api/chapters')
            ->assertOk()
            ->assertJsonPath('code', 10002)
            ->assertJsonPath('message', '未登录或登录失效')
            ->assertJsonPath('data', null);

        $this->postJson('/api/battles/prepare', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
        ])->assertOk()
            ->assertJsonPath('code', 10002)
            ->assertJsonPath('message', '未登录或登录失效')
            ->assertJsonPath('data', null);
    }

    public function test_can_read_chapters(): void
    {
        $this->getJson('/api/chapters', $this->authHeaders())
            ->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonCount(1, 'data.chapters')
            ->assertJsonPath('data.chapters.0.chapter_id', 'chapter_nanshan_001')
            ->assertJsonPath('data.chapters.0.chapter_name', '南山一经')
            ->assertJsonPath('data.chapters.0.chapter_desc', null)
            ->assertJsonPath('data.chapters.0.chapter_group', null)
            ->assertJsonPath('data.chapters.0.unlock_condition', null);
    }

    public function test_can_read_stage_difficulties_with_first_clear_reward_summary(): void
    {
        $this->getJson('/api/stages/stage_nanshan_001/difficulties', $this->authHeaders())
            ->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.stage_id', 'stage_nanshan_001')
            ->assertJsonCount(2, 'data.difficulties')
            ->assertJsonPath('data.difficulties.0.stage_difficulty_id', 'stage_nanshan_001_normal')
            ->assertJsonPath('data.difficulties.0.first_clear_reward.has_reward', 1)
            ->assertJsonPath('data.difficulties.0.first_clear_reward.has_granted', 0)
            ->assertJsonPath('data.difficulties.0.first_clear_reward.reward_group_id', 'reward_first_clear_001')
            ->assertJsonPath('data.difficulties.1.stage_difficulty_id', 'stage_nanshan_001_hard')
            ->assertJsonPath('data.difficulties.1.first_clear_reward.has_reward', 1)
            ->assertJsonPath('data.difficulties.1.first_clear_reward.reward_group_id', 'reward_first_clear_001');
    }

    public function test_can_read_first_clear_reward_status_and_distinguish_failed_grant(): void
    {
        DB::table('user_reward_grants')->insert([
            'user_id' => TestUserSeeder::TEST_USER_ID,
            'source_type' => RewardSourceType::FIRST_CLEAR->value,
            'source_id' => 'stage_nanshan_001_normal',
            'reward_group_id' => 'reward_first_clear_001',
            'idempotency_key' => 'reward-debug-failed-001',
            'grant_status' => GrantStatus::FAILED->value,
            'granted_at' => null,
            'grant_payload_snapshot' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->getJson(
            '/api/stage-difficulties/stage_nanshan_001_normal/first-clear-reward-status',
            $this->authHeaders()
        )->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.source_type', 'first_clear')
            ->assertJsonPath('data.source_id', 'stage_nanshan_001_normal')
            ->assertJsonPath('data.has_reward', 1)
            ->assertJsonPath('data.reward_group_id', 'reward_first_clear_001')
            ->assertJsonPath('data.has_granted', 0)
            ->assertJsonPath('data.grant_status', 'failed');
    }

    public function test_battle_prepare_returns_formal_payload_from_equipment_and_monster_binding(): void
    {
        $this->postJson('/api/characters/1001/equip', [
            'equipment_instance_id' => 5001,
            'target_slot_key' => 'main_weapon',
        ], $this->authHeaders())->assertOk()->assertJsonPath('code', 0);

        $this->postJson('/api/characters/1001/equip', [
            'equipment_instance_id' => 5002,
            'target_slot_key' => 'sub_weapon',
        ], $this->authHeaders())->assertOk()->assertJsonPath('code', 0);

        $this->postJson('/api/characters/1001/equip', [
            'equipment_instance_id' => 5004,
            'target_slot_key' => 'armor',
        ], $this->authHeaders())->assertOk()->assertJsonPath('code', 0);

        $response = $this->postJson('/api/battles/prepare', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_nanshan_001_normal',
        ], $this->authHeaders());

        $response->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.stage_difficulty.stage_difficulty_id', 'stage_nanshan_001_normal')
            ->assertJsonPath('data.character.character_id', 1001)
            ->assertJsonPath('data.character.class_id', 'class_jingang')
            ->assertJsonPath('data.character_stats.attack', 12)
            ->assertJsonPath('data.character_stats.physical_defense', 20)
            ->assertJsonPath('data.character_stats.magic_defense', 6)
            ->assertJsonPath('data.character_stats.hp', 30)
            ->assertJsonPath('data.character_stats.mana', 0)
            ->assertJsonPath('data.character_stats.attack_speed', 10)
            ->assertJsonPath('data.character_stats.crit_rate', 2)
            ->assertJsonCount(12, 'data.slot_snapshot')
            ->assertJsonPath('data.slot_snapshot.0.equipped_instance_id', 5001)
            ->assertJsonPath('data.slot_snapshot.1.equipped_instance_id', 5002)
            ->assertJsonPath('data.slot_snapshot.2.equipped_instance_id', 5004)
            ->assertJsonCount(4, 'data.monster_list')
            ->assertJsonPath('data.monster_list.0.monster_id', 'monster_spirit_001')
            ->assertJsonPath('data.monster_list.1.monster_id', 'monster_wolf_001')
            ->assertJsonPath('data.monster_list.2.monster_id', 'monster_boar_001')
            ->assertJsonPath('data.monster_list.3.monster_id', 'monster_boss_001')
            ->assertJsonPath('data.monster_list.3.wave_no', 2)
            ->assertJsonPath('data.monster_list.0.attack_interval', null);

        $this->assertStringStartsWith('battle_ctx_', (string) $response->json('data.battle_context_id'));
    }

    public function test_invalid_stage_or_difficulty_returns_formal_error_code(): void
    {
        $this->getJson('/api/stages/stage_unknown/difficulties', $this->authHeaders())
            ->assertOk()
            ->assertJsonPath('code', 10302)
            ->assertJsonPath('data', null);

        $this->getJson(
            '/api/stage-difficulties/stage_unknown_normal/first-clear-reward-status',
            $this->authHeaders()
        )->assertOk()
            ->assertJsonPath('code', 10303)
            ->assertJsonPath('data', null);

        $this->postJson('/api/battles/prepare', [
            'character_id' => 1001,
            'stage_difficulty_id' => 'stage_unknown_normal',
        ], $this->authHeaders())->assertOk()
            ->assertJsonPath('code', 10403)
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
