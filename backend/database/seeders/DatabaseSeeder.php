<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        $this->call([
            TestUserSeeder::class,
            ClassSeeder::class,
            ItemSeeder::class,
            EquipmentSeeder::class,
            MonsterSeeder::class,
            StageSeeder::class,
            DropSeeder::class,
            RewardSeeder::class,
            DebugPlayerStateSeeder::class,
        ]);
    }
}
