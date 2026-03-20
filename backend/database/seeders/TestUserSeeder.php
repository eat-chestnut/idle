<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class TestUserSeeder extends Seeder
{
    public const TEST_USER_ID = 2001;

    public const TEST_USER_TOKEN = 'test-token-2001';

    public function run(): void
    {
        $timestamp = now();

        DB::table('users')->upsert([
            [
                'id' => self::TEST_USER_ID,
                'name' => '测试用户',
                'email' => 'test2001@example.com',
                'email_verified_at' => null,
                'password' => Hash::make('password'),
                'api_token' => hash('sha256', self::TEST_USER_TOKEN),
                'remember_token' => null,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['id'], [
            'name',
            'email',
            'password',
            'api_token',
            'updated_at',
        ]);
    }
}
