<?php

namespace Tests\Feature\Api;

use App\Models\Character\CharacterEquipmentSlot;
use Database\Seeders\DatabaseSeeder;
use Database\Seeders\TestUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PhaseOneCharacterEquipmentApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(DatabaseSeeder::class);
    }

    public function test_api_requires_bearer_token(): void
    {
        $this->getJson('/api/inventory')
            ->assertOk()
            ->assertJsonPath('code', 10002)
            ->assertJsonPath('message', '未登录或登录失效')
            ->assertJsonPath('data', null);
    }

    public function test_can_create_character_and_initialize_twelve_slots(): void
    {
        $response = $this->postJson(
            '/api/characters',
            [
                'class_id' => 'class_fashi',
                'character_name' => '白露',
            ],
            $this->authHeaders()
        );

        $response->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.character.class_id', 'class_fashi')
            ->assertJsonCount(12, 'data.equipment_slots');

        $characterId = (int) $response->json('data.character.character_id');

        $this->assertDatabaseHas('characters', [
            'character_id' => $characterId,
            'user_id' => TestUserSeeder::TEST_USER_ID,
            'class_id' => 'class_fashi',
            'character_name' => '白露',
        ]);

        $this->assertSame(
            12,
            CharacterEquipmentSlot::query()->where('character_id', $characterId)->count()
        );
    }

    public function test_can_read_character_detail_equipment_slots_and_inventory(): void
    {
        $this->getJson('/api/characters/1001', $this->authHeaders())
            ->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.character.character_id', 1001)
            ->assertJsonPath('data.character.class_id', 'class_jingang')
            ->assertJsonPath('data.character.is_active', 1);

        $this->getJson('/api/characters/1001/equipment-slots', $this->authHeaders())
            ->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.character_id', 1001)
            ->assertJsonCount(12, 'data.slots')
            ->assertJsonPath('data.slots.0.slot_key', 'main_weapon');

        $this->getJson('/api/inventory', $this->authHeaders())
            ->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonCount(3, 'data.stack_items')
            ->assertJsonCount(4, 'data.equipment_items');
    }

    public function test_equipping_two_handed_weapon_clears_sub_weapon(): void
    {
        $this->postJson('/api/characters/1001/equip', [
            'equipment_instance_id' => 5001,
            'target_slot_key' => 'main_weapon',
        ], $this->authHeaders())->assertOk()->assertJsonPath('code', 0);

        $this->postJson('/api/characters/1001/equip', [
            'equipment_instance_id' => 5002,
            'target_slot_key' => 'sub_weapon',
        ], $this->authHeaders())->assertOk()->assertJsonPath('code', 0);

        $response = $this->postJson('/api/characters/1001/equip', [
            'equipment_instance_id' => 5003,
            'target_slot_key' => 'main_weapon',
        ], $this->authHeaders());

        $response->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.character_id', 1001)
            ->assertJsonPath('data.equipped_instance_id', 5003)
            ->assertJsonPath('data.changed_slots.0', 'main_weapon')
            ->assertJsonPath('data.changed_slots.1', 'sub_weapon')
            ->assertJsonPath('data.slot_snapshot.0.equipped_instance_id', 5003)
            ->assertJsonPath('data.slot_snapshot.1.equipped_instance_id', null);

        $unequippedInstanceIds = $response->json('data.unequipped_instance_ids');
        sort($unequippedInstanceIds);

        $this->assertSame([5001, 5002], $unequippedInstanceIds);

        $this->assertDatabaseHas('character_equipment_slots', [
            'character_id' => 1001,
            'slot_key' => 'main_weapon',
            'equipped_instance_id' => 5003,
        ]);

        $this->assertDatabaseHas('character_equipment_slots', [
            'character_id' => 1001,
            'slot_key' => 'sub_weapon',
            'equipped_instance_id' => null,
        ]);
    }

    public function test_unequipping_main_weapon_clears_sub_weapon_together(): void
    {
        $this->postJson('/api/characters/1001/equip', [
            'equipment_instance_id' => 5001,
            'target_slot_key' => 'main_weapon',
        ], $this->authHeaders())->assertOk()->assertJsonPath('code', 0);

        $this->postJson('/api/characters/1001/equip', [
            'equipment_instance_id' => 5002,
            'target_slot_key' => 'sub_weapon',
        ], $this->authHeaders())->assertOk()->assertJsonPath('code', 0);

        $response = $this->postJson('/api/characters/1001/unequip', [
            'target_slot_key' => 'main_weapon',
        ], $this->authHeaders());

        $response->assertOk()
            ->assertJsonPath('code', 0)
            ->assertJsonPath('data.character_id', 1001)
            ->assertJsonPath('data.changed_slots.0', 'main_weapon')
            ->assertJsonPath('data.changed_slots.1', 'sub_weapon')
            ->assertJsonPath('data.slot_snapshot.0.equipped_instance_id', null)
            ->assertJsonPath('data.slot_snapshot.1.equipped_instance_id', null);

        $unequippedInstanceIds = $response->json('data.unequipped_instance_ids');
        sort($unequippedInstanceIds);

        $this->assertSame([5001, 5002], $unequippedInstanceIds);

        $this->assertDatabaseHas('character_equipment_slots', [
            'character_id' => 1001,
            'slot_key' => 'main_weapon',
            'equipped_instance_id' => null,
        ]);

        $this->assertDatabaseHas('character_equipment_slots', [
            'character_id' => 1001,
            'slot_key' => 'sub_weapon',
            'equipped_instance_id' => null,
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
