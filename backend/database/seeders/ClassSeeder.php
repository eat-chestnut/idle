<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class ClassSeeder extends Seeder
{
    public function run(): void
    {
        $timestamp = now();

        DB::table('classes')->upsert([
            [
                'class_id' => 'class_jingang',
                'class_name' => '金刚',
                'is_enabled' => true,
                'sort_order' => 1,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'class_id' => 'class_fashi',
                'class_name' => '法师',
                'is_enabled' => true,
                'sort_order' => 2,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['class_id'], [
            'class_name',
            'is_enabled',
            'sort_order',
            'updated_at',
        ]);
    }
}
