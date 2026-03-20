<?php

namespace Database\Seeders;

use App\Enums\Common\Rarity;
use App\Enums\Item\ItemType;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class ItemSeeder extends Seeder
{
    public function run(): void
    {
        $timestamp = now();

        DB::table('items')->upsert([
            [
                'item_id' => 'mat_wood_001',
                'item_name' => '灵木',
                'item_type' => ItemType::MATERIAL->value,
                'rarity' => Rarity::COMMON->value,
                'icon' => 'items/mat_wood_001.png',
                'is_enabled' => true,
                'sort_order' => 1,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'item_id' => 'mat_stone_001',
                'item_name' => '灵石碎片',
                'item_type' => ItemType::MATERIAL->value,
                'rarity' => Rarity::COMMON->value,
                'icon' => 'items/mat_stone_001.png',
                'is_enabled' => true,
                'sort_order' => 2,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'item_id' => 'mat_coin_001',
                'item_name' => '灵石',
                'item_type' => ItemType::REWARD_ITEM->value,
                'rarity' => Rarity::RARE->value,
                'icon' => 'items/mat_coin_001.png',
                'is_enabled' => true,
                'sort_order' => 3,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'item_id' => 'mat_mark_001',
                'item_name' => '山魄印记',
                'item_type' => ItemType::REWARD_ITEM->value,
                'rarity' => Rarity::RARE->value,
                'icon' => 'items/mat_mark_001.png',
                'is_enabled' => true,
                'sort_order' => 4,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'item_id' => 'eq_hammer_001',
                'item_name' => '青石重锤',
                'item_type' => ItemType::EQUIPMENT->value,
                'rarity' => Rarity::COMMON->value,
                'icon' => 'equipments/eq_hammer_001.png',
                'is_enabled' => true,
                'sort_order' => 5,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'item_id' => 'eq_shield_001',
                'item_name' => '山纹木盾',
                'item_type' => ItemType::EQUIPMENT->value,
                'rarity' => Rarity::COMMON->value,
                'icon' => 'equipments/eq_shield_001.png',
                'is_enabled' => true,
                'sort_order' => 6,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'item_id' => 'eq_staff_001',
                'item_name' => '灵枝法杖',
                'item_type' => ItemType::EQUIPMENT->value,
                'rarity' => Rarity::RARE->value,
                'icon' => 'equipments/eq_staff_001.png',
                'is_enabled' => true,
                'sort_order' => 7,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'item_id' => 'eq_armor_001',
                'item_name' => '山皮护甲',
                'item_type' => ItemType::EQUIPMENT->value,
                'rarity' => Rarity::COMMON->value,
                'icon' => 'equipments/eq_armor_001.png',
                'is_enabled' => true,
                'sort_order' => 8,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'item_id' => 'eq_ring_001',
                'item_name' => '山灵戒',
                'item_type' => ItemType::EQUIPMENT->value,
                'rarity' => Rarity::RARE->value,
                'icon' => 'equipments/eq_ring_001.png',
                'is_enabled' => true,
                'sort_order' => 9,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            [
                'item_id' => 'eq_bracelet_001',
                'item_name' => '古藤手镯',
                'item_type' => ItemType::EQUIPMENT->value,
                'rarity' => Rarity::RARE->value,
                'icon' => 'equipments/eq_bracelet_001.png',
                'is_enabled' => true,
                'sort_order' => 10,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
        ], ['item_id'], [
            'item_name',
            'item_type',
            'rarity',
            'icon',
            'is_enabled',
            'sort_order',
            'updated_at',
        ]);
    }
}
