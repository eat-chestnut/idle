<?php

namespace App\Enums\Equipment;

enum EquipmentSlotKey: string
{
    case MAIN_WEAPON = 'main_weapon';
    case SUB_WEAPON = 'sub_weapon';
    case ARMOR = 'armor';
    case LEGGINGS = 'leggings';
    case GLOVES = 'gloves';
    case BOOTS = 'boots';
    case CLOAK = 'cloak';
    case NECKLACE = 'necklace';
    case RING_1 = 'ring_1';
    case RING_2 = 'ring_2';
    case BRACELET_1 = 'bracelet_1';
    case BRACELET_2 = 'bracelet_2';

    public static function orderedValues(): array
    {
        return [
            self::MAIN_WEAPON->value,
            self::SUB_WEAPON->value,
            self::ARMOR->value,
            self::LEGGINGS->value,
            self::GLOVES->value,
            self::BOOTS->value,
            self::CLOAK->value,
            self::NECKLACE->value,
            self::RING_1->value,
            self::RING_2->value,
            self::BRACELET_1->value,
            self::BRACELET_2->value,
        ];
    }
}
