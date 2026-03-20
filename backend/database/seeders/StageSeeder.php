<?php

namespace Database\Seeders;

use App\Enums\Monster\MonsterRole;
use App\Enums\Stage\DifficultyKey;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class StageSeeder extends Seeder
{
    public function run(): void
    {
        $timestamp = now();

        DB::table('chapters')->upsert([
            [
                'chapter_id' => 'chapter_nanshan_001',
                'chapter_name' => '南山一经',
                'sort_order' => 1,
                'is_enabled' => true,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['chapter_id'], [
            'chapter_name',
            'sort_order',
            'is_enabled',
            'updated_at',
        ]);

        DB::table('chapter_stages')->upsert([
            [
                'stage_id' => 'stage_nanshan_001',
                'chapter_id' => 'chapter_nanshan_001',
                'stage_name' => '招摇山',
                'stage_order' => 1,
                'is_enabled' => true,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'stage_id' => 'stage_nanshan_002',
                'chapter_id' => 'chapter_nanshan_001',
                'stage_name' => '堂庭山',
                'stage_order' => 2,
                'is_enabled' => true,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['stage_id'], [
            'chapter_id',
            'stage_name',
            'stage_order',
            'is_enabled',
            'updated_at',
        ]);

        DB::table('stage_difficulties')->upsert([
            [
                'stage_difficulty_id' => 'stage_nanshan_001_normal',
                'stage_id' => 'stage_nanshan_001',
                'difficulty_key' => DifficultyKey::NORMAL->value,
                'difficulty_name' => '普通',
                'recommended_power' => 100,
                'difficulty_order' => 1,
                'is_enabled' => true,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'stage_difficulty_id' => 'stage_nanshan_001_hard',
                'stage_id' => 'stage_nanshan_001',
                'difficulty_key' => DifficultyKey::HARD->value,
                'difficulty_name' => '困难',
                'recommended_power' => 180,
                'difficulty_order' => 2,
                'is_enabled' => true,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'stage_difficulty_id' => 'stage_nanshan_002_normal',
                'stage_id' => 'stage_nanshan_002',
                'difficulty_key' => DifficultyKey::NORMAL->value,
                'difficulty_name' => '普通',
                'recommended_power' => 150,
                'difficulty_order' => 1,
                'is_enabled' => true,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'stage_difficulty_id' => 'stage_nanshan_002_hard',
                'stage_id' => 'stage_nanshan_002',
                'difficulty_key' => DifficultyKey::HARD->value,
                'difficulty_name' => '困难',
                'recommended_power' => 260,
                'difficulty_order' => 2,
                'is_enabled' => true,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['stage_difficulty_id'], [
            'stage_id',
            'difficulty_key',
            'difficulty_name',
            'recommended_power',
            'difficulty_order',
            'is_enabled',
            'updated_at',
        ]);

        $bindings = [
            ['stage_difficulty_id' => 'stage_nanshan_001_normal', 'monster_id' => 'monster_spirit_001', 'monster_role' => MonsterRole::NORMAL_ENEMY->value, 'wave_no' => 1, 'sort_order' => 1],
            ['stage_difficulty_id' => 'stage_nanshan_001_normal', 'monster_id' => 'monster_wolf_001', 'monster_role' => MonsterRole::NORMAL_ENEMY->value, 'wave_no' => 1, 'sort_order' => 2],
            ['stage_difficulty_id' => 'stage_nanshan_001_normal', 'monster_id' => 'monster_boar_001', 'monster_role' => MonsterRole::ELITE_ENEMY->value, 'wave_no' => 1, 'sort_order' => 3],
            ['stage_difficulty_id' => 'stage_nanshan_001_normal', 'monster_id' => 'monster_boss_001', 'monster_role' => MonsterRole::BOSS_ENEMY->value, 'wave_no' => 2, 'sort_order' => 1],
            ['stage_difficulty_id' => 'stage_nanshan_001_hard', 'monster_id' => 'monster_spirit_001', 'monster_role' => MonsterRole::NORMAL_ENEMY->value, 'wave_no' => 1, 'sort_order' => 1],
            ['stage_difficulty_id' => 'stage_nanshan_001_hard', 'monster_id' => 'monster_wolf_001', 'monster_role' => MonsterRole::NORMAL_ENEMY->value, 'wave_no' => 1, 'sort_order' => 2],
            ['stage_difficulty_id' => 'stage_nanshan_001_hard', 'monster_id' => 'monster_bird_001', 'monster_role' => MonsterRole::ELITE_ENEMY->value, 'wave_no' => 1, 'sort_order' => 3],
            ['stage_difficulty_id' => 'stage_nanshan_001_hard', 'monster_id' => 'monster_boss_001', 'monster_role' => MonsterRole::BOSS_ENEMY->value, 'wave_no' => 2, 'sort_order' => 1],
            ['stage_difficulty_id' => 'stage_nanshan_002_normal', 'monster_id' => 'monster_spirit_001', 'monster_role' => MonsterRole::NORMAL_ENEMY->value, 'wave_no' => 1, 'sort_order' => 1],
            ['stage_difficulty_id' => 'stage_nanshan_002_normal', 'monster_id' => 'monster_boar_001', 'monster_role' => MonsterRole::ELITE_ENEMY->value, 'wave_no' => 1, 'sort_order' => 2],
            ['stage_difficulty_id' => 'stage_nanshan_002_normal', 'monster_id' => 'monster_boss_002', 'monster_role' => MonsterRole::BOSS_ENEMY->value, 'wave_no' => 2, 'sort_order' => 1],
            ['stage_difficulty_id' => 'stage_nanshan_002_hard', 'monster_id' => 'monster_wolf_001', 'monster_role' => MonsterRole::NORMAL_ENEMY->value, 'wave_no' => 1, 'sort_order' => 1],
            ['stage_difficulty_id' => 'stage_nanshan_002_hard', 'monster_id' => 'monster_bird_001', 'monster_role' => MonsterRole::ELITE_ENEMY->value, 'wave_no' => 1, 'sort_order' => 2],
            ['stage_difficulty_id' => 'stage_nanshan_002_hard', 'monster_id' => 'monster_boss_002', 'monster_role' => MonsterRole::BOSS_ENEMY->value, 'wave_no' => 2, 'sort_order' => 1],
        ];

        foreach ($bindings as $binding) {
            DB::table('stage_monster_bindings')->updateOrInsert(
                [
                    'stage_difficulty_id' => $binding['stage_difficulty_id'],
                    'wave_no' => $binding['wave_no'],
                    'sort_order' => $binding['sort_order'],
                ],
                [
                    'monster_id' => $binding['monster_id'],
                    'monster_role' => $binding['monster_role'],
                    'updated_at' => $timestamp,
                    'created_at' => $timestamp,
                ]
            );
        }
    }
}
