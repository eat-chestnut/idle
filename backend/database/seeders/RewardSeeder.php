<?php

namespace Database\Seeders;

use App\Enums\Reward\RewardSourceType;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class RewardSeeder extends Seeder
{
    public function run(): void
    {
        $timestamp = now();

        DB::table('reward_groups')->upsert([
            [
                'reward_group_id' => 'reward_first_clear_001',
                'reward_group_name' => '招摇山首通奖励',
                'is_enabled' => true,
                'sort_order' => 1,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'reward_group_id' => 'reward_first_clear_002',
                'reward_group_name' => '堂庭山首通奖励',
                'is_enabled' => true,
                'sort_order' => 2,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['reward_group_id'], [
            'reward_group_name',
            'is_enabled',
            'sort_order',
            'updated_at',
        ]);

        $rewardItems = [
            ['reward_group_id' => 'reward_first_clear_001', 'item_id' => 'mat_coin_001', 'quantity' => 100, 'sort_order' => 1],
            ['reward_group_id' => 'reward_first_clear_001', 'item_id' => 'mat_mark_001', 'quantity' => 2, 'sort_order' => 2],
            ['reward_group_id' => 'reward_first_clear_001', 'item_id' => 'eq_armor_001', 'quantity' => 1, 'sort_order' => 3],
            ['reward_group_id' => 'reward_first_clear_002', 'item_id' => 'mat_coin_001', 'quantity' => 180, 'sort_order' => 1],
            ['reward_group_id' => 'reward_first_clear_002', 'item_id' => 'mat_mark_001', 'quantity' => 3, 'sort_order' => 2],
            ['reward_group_id' => 'reward_first_clear_002', 'item_id' => 'eq_ring_001', 'quantity' => 1, 'sort_order' => 3],
        ];

        foreach ($rewardItems as $rewardItem) {
            DB::table('reward_group_items')->updateOrInsert(
                [
                    'reward_group_id' => $rewardItem['reward_group_id'],
                    'sort_order' => $rewardItem['sort_order'],
                ],
                [
                    'item_id' => $rewardItem['item_id'],
                    'quantity' => $rewardItem['quantity'],
                    'updated_at' => $timestamp,
                    'created_at' => $timestamp,
                ]
            );
        }

        DB::table('reward_group_bindings')->upsert([
            ['source_type' => RewardSourceType::FIRST_CLEAR->value, 'source_id' => 'stage_nanshan_001_normal', 'reward_group_id' => 'reward_first_clear_001', 'created_at' => $timestamp, 'updated_at' => $timestamp],
            ['source_type' => RewardSourceType::FIRST_CLEAR->value, 'source_id' => 'stage_nanshan_001_hard', 'reward_group_id' => 'reward_first_clear_001', 'created_at' => $timestamp, 'updated_at' => $timestamp],
            ['source_type' => RewardSourceType::FIRST_CLEAR->value, 'source_id' => 'stage_nanshan_002_normal', 'reward_group_id' => 'reward_first_clear_002', 'created_at' => $timestamp, 'updated_at' => $timestamp],
            ['source_type' => RewardSourceType::FIRST_CLEAR->value, 'source_id' => 'stage_nanshan_002_hard', 'reward_group_id' => 'reward_first_clear_002', 'created_at' => $timestamp, 'updated_at' => $timestamp],
        ], ['source_type', 'source_id'], [
            'reward_group_id',
            'updated_at',
        ]);
    }
}
