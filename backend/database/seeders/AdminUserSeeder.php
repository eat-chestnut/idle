<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    public const DEFAULT_USERNAME = 'admin';

    public const DEFAULT_PASSWORD = 'admin123456';

    public function run(): void
    {
        $timestamp = now();

        DB::table('admin_users')->upsert([
            [
                'username' => self::DEFAULT_USERNAME,
                'name' => '后台管理员',
                'password' => Hash::make(self::DEFAULT_PASSWORD),
                'is_enabled' => true,
                'remember_token' => null,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['username'], [
            'name',
            'password',
            'is_enabled',
            'updated_at',
        ]);
    }
}
