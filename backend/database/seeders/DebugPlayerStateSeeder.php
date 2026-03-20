<?php

namespace Database\Seeders;

use App\Enums\Equipment\BindType;
use App\Enums\Equipment\EquipmentSlotKey;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DebugPlayerStateSeeder extends Seeder
{
    public function run(): void
    {
        $timestamp = now();

        DB::table('characters')->upsert([
            [
                'character_id' => 1001,
                'user_id' => 2001,
                'class_id' => 'class_jingang',
                'character_name' => '青山',
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
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['character_id'], [
            'user_id',
            'class_id',
            'character_name',
            'level',
            'exp',
            'unspent_stat_points',
            'added_strength',
            'added_mana',
            'added_constitution',
            'added_dexterity',
            'long_term_growth_stage',
            'extra_context',
            'is_active',
            'updated_at',
        ]);

        foreach (EquipmentSlotKey::orderedValues() as $sortOrder => $slotKey) {
            DB::table('character_equipment_slots')->updateOrInsert(
                [
                    'character_id' => 1001,
                    'slot_key' => $slotKey,
                ],
                [
                    'equipped_instance_id' => null,
                    'sort_order' => $sortOrder + 1,
                    'created_at' => $timestamp,
                    'updated_at' => $timestamp,
                ]
            );
        }

        DB::table('inventory_stack_items')->upsert([
            [
                'user_id' => 2001,
                'item_id' => 'mat_wood_001',
                'quantity' => 10,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'user_id' => 2001,
                'item_id' => 'mat_stone_001',
                'quantity' => 5,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'user_id' => 2001,
                'item_id' => 'mat_coin_001',
                'quantity' => 20,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['user_id', 'item_id'], [
            'quantity',
            'updated_at',
        ]);

        DB::table('inventory_equipment_instances')->upsert([
            [
                'equipment_instance_id' => 5001,
                'user_id' => 2001,
                'item_id' => 'eq_hammer_001',
                'bind_type' => BindType::UNBOUND->value,
                'enhance_level' => 0,
                'durability' => 100,
                'max_durability' => 100,
                'is_locked' => false,
                'extra_attributes' => null,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'equipment_instance_id' => 5002,
                'user_id' => 2001,
                'item_id' => 'eq_shield_001',
                'bind_type' => BindType::UNBOUND->value,
                'enhance_level' => 0,
                'durability' => 100,
                'max_durability' => 100,
                'is_locked' => false,
                'extra_attributes' => null,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'equipment_instance_id' => 5003,
                'user_id' => 2001,
                'item_id' => 'eq_staff_001',
                'bind_type' => BindType::UNBOUND->value,
                'enhance_level' => 0,
                'durability' => 100,
                'max_durability' => 100,
                'is_locked' => false,
                'extra_attributes' => null,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'equipment_instance_id' => 5004,
                'user_id' => 2001,
                'item_id' => 'eq_armor_001',
                'bind_type' => BindType::UNBOUND->value,
                'enhance_level' => 0,
                'durability' => 100,
                'max_durability' => 100,
                'is_locked' => false,
                'extra_attributes' => null,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['equipment_instance_id'], [
            'user_id',
            'item_id',
            'bind_type',
            'enhance_level',
            'durability',
            'max_durability',
            'is_locked',
            'extra_attributes',
            'updated_at',
        ]);
    }
}
