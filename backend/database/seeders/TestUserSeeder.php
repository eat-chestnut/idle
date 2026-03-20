<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class TestUserSeeder extends Seeder
{
    public function run(): void
    {
        $timestamp = now();

        DB::table('users')->upsert([
            [
                'id' => 2001,
                'name' => '测试用户',
                'email' => 'test2001@example.com',
                'email_verified_at' => null,
                'password' => Hash::make('password'),
                'remember_token' => null,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['id'], [
            'name',
            'email',
            'password',
            'updated_at',
        ]);
    }
}
