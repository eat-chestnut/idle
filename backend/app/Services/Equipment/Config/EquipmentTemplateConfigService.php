<?php

namespace App\Services\Equipment\Config;

use App\Enums\Equipment\SubWeaponCategory;
use App\Enums\Equipment\WeaponCategory;
use App\Models\Equipment\Equipment;

class EquipmentTemplateConfigService
{
    /**
     * This compatibility map is inferred from the current enum set and the
     * repository's existing debug seed combinations for phase-one validation.
     */
    private const ALLOWED_SUB_WEAPON_CATEGORIES = [
        WeaponCategory::SWORD->value => [
            SubWeaponCategory::SHIELD->value,
            SubWeaponCategory::TALISMAN->value,
        ],
        WeaponCategory::BLADE->value => [
            SubWeaponCategory::SHIELD->value,
            SubWeaponCategory::TALISMAN->value,
        ],
        WeaponCategory::STAFF->value => [
            SubWeaponCategory::ORB->value,
            SubWeaponCategory::TALISMAN->value,
        ],
        WeaponCategory::HAMMER->value => [
            SubWeaponCategory::SHIELD->value,
        ],
        WeaponCategory::SPEAR->value => [],
        WeaponCategory::BOW->value => [
            SubWeaponCategory::QUIVER->value,
        ],
    ];

    public function getEquipmentTemplateByItemId(string $itemId): ?Equipment
    {
        return Equipment::query()
            ->with('item')
            ->where('item_id', $itemId)
            ->where('is_enabled', true)
            ->first();
    }

    public function getEquipmentTemplateMapByItemIds(array $itemIds): array
    {
        if ($itemIds === []) {
            return [];
        }

        return Equipment::query()
            ->with('item')
            ->whereIn('item_id', array_values(array_unique($itemIds)))
            ->where('is_enabled', true)
            ->get()
            ->keyBy('item_id')
            ->all();
    }

    public function getAllowedSubWeaponCategories(?WeaponCategory $weaponCategory): array
    {
        if ($weaponCategory === null) {
            return [];
        }

        return self::ALLOWED_SUB_WEAPON_CATEGORIES[$weaponCategory->value] ?? [];
    }
}
