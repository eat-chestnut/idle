<?php

namespace Database\Seeders;

use App\Enums\Drop\DropRollType;
use App\Enums\Drop\DropSourceType;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DropSeeder extends Seeder
{
    public function run(): void
    {
        $timestamp = now();

        DB::table('drop_groups')->upsert([
            [
                'drop_group_id' => 'drop_normal_001',
                'drop_group_name' => '普通怪基础掉落组',
                'roll_type' => DropRollType::WEIGHTED_REPEAT->value,
                'roll_times' => 2,
                'is_enabled' => true,
                'sort_order' => 1,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'drop_group_id' => 'drop_elite_001',
                'drop_group_name' => '精英怪掉落组',
                'roll_type' => DropRollType::WEIGHTED_REPEAT->value,
                'roll_times' => 3,
                'is_enabled' => true,
                'sort_order' => 2,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'drop_group_id' => 'drop_boss_001',
                'drop_group_name' => 'Boss 掉落组',
                'roll_type' => DropRollType::WEIGHTED_REPEAT->value,
                'roll_times' => 4,
                'is_enabled' => true,
                'sort_order' => 3,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['drop_group_id'], [
            'drop_group_name',
            'roll_type',
            'roll_times',
            'is_enabled',
            'sort_order',
            'updated_at',
        ]);

        $dropItems = [
            ['drop_group_id' => 'drop_normal_001', 'item_id' => 'mat_wood_001', 'weight' => 70, 'min_quantity' => 1, 'max_quantity' => 2, 'sort_order' => 1],
            ['drop_group_id' => 'drop_normal_001', 'item_id' => 'mat_stone_001', 'weight' => 30, 'min_quantity' => 1, 'max_quantity' => 1, 'sort_order' => 2],
            ['drop_group_id' => 'drop_elite_001', 'item_id' => 'mat_wood_001', 'weight' => 40, 'min_quantity' => 2, 'max_quantity' => 3, 'sort_order' => 1],
            ['drop_group_id' => 'drop_elite_001', 'item_id' => 'mat_stone_001', 'weight' => 30, 'min_quantity' => 1, 'max_quantity' => 2, 'sort_order' => 2],
            ['drop_group_id' => 'drop_elite_001', 'item_id' => 'eq_ring_001', 'weight' => 20, 'min_quantity' => 1, 'max_quantity' => 1, 'sort_order' => 3],
            ['drop_group_id' => 'drop_elite_001', 'item_id' => 'eq_bracelet_001', 'weight' => 10, 'min_quantity' => 1, 'max_quantity' => 1, 'sort_order' => 4],
            ['drop_group_id' => 'drop_boss_001', 'item_id' => 'mat_mark_001', 'weight' => 40, 'min_quantity' => 1, 'max_quantity' => 2, 'sort_order' => 1],
            ['drop_group_id' => 'drop_boss_001', 'item_id' => 'mat_coin_001', 'weight' => 25, 'min_quantity' => 20, 'max_quantity' => 40, 'sort_order' => 2],
            ['drop_group_id' => 'drop_boss_001', 'item_id' => 'eq_hammer_001', 'weight' => 15, 'min_quantity' => 1, 'max_quantity' => 1, 'sort_order' => 3],
            ['drop_group_id' => 'drop_boss_001', 'item_id' => 'eq_shield_001', 'weight' => 10, 'min_quantity' => 1, 'max_quantity' => 1, 'sort_order' => 4],
            ['drop_group_id' => 'drop_boss_001', 'item_id' => 'eq_staff_001', 'weight' => 10, 'min_quantity' => 1, 'max_quantity' => 1, 'sort_order' => 5],
        ];

        foreach ($dropItems as $dropItem) {
            DB::table('drop_group_items')->updateOrInsert(
                [
                    'drop_group_id' => $dropItem['drop_group_id'],
                    'sort_order' => $dropItem['sort_order'],
                ],
                [
                    'item_id' => $dropItem['item_id'],
                    'weight' => $dropItem['weight'],
                    'min_quantity' => $dropItem['min_quantity'],
                    'max_quantity' => $dropItem['max_quantity'],
                    'updated_at' => $timestamp,
                    'created_at' => $timestamp,
                ]
            );
        }

        DB::table('drop_group_bindings')->upsert([
            ['source_type' => DropSourceType::MONSTER->value, 'source_id' => 'monster_spirit_001', 'drop_group_id' => 'drop_normal_001', 'created_at' => $timestamp, 'updated_at' => $timestamp],
            ['source_type' => DropSourceType::MONSTER->value, 'source_id' => 'monster_wolf_001', 'drop_group_id' => 'drop_normal_001', 'created_at' => $timestamp, 'updated_at' => $timestamp],
            ['source_type' => DropSourceType::MONSTER->value, 'source_id' => 'monster_boar_001', 'drop_group_id' => 'drop_elite_001', 'created_at' => $timestamp, 'updated_at' => $timestamp],
            ['source_type' => DropSourceType::MONSTER->value, 'source_id' => 'monster_bird_001', 'drop_group_id' => 'drop_elite_001', 'created_at' => $timestamp, 'updated_at' => $timestamp],
            ['source_type' => DropSourceType::MONSTER->value, 'source_id' => 'monster_boss_001', 'drop_group_id' => 'drop_boss_001', 'created_at' => $timestamp, 'updated_at' => $timestamp],
            ['source_type' => DropSourceType::MONSTER->value, 'source_id' => 'monster_boss_002', 'drop_group_id' => 'drop_boss_001', 'created_at' => $timestamp, 'updated_at' => $timestamp],
        ], ['source_type', 'source_id'], [
            'drop_group_id',
            'updated_at',
        ]);
    }
}
