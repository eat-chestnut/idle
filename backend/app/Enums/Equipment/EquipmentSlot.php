<?php

namespace App\Enums\Equipment;

enum EquipmentSlot: string
{
    case MAIN_WEAPON = 'main_weapon';
    case SUB_WEAPON = 'sub_weapon';
    case ARMOR = 'armor';
    case LEGGINGS = 'leggings';
    case GLOVES = 'gloves';
    case BOOTS = 'boots';
    case CLOAK = 'cloak';
    case NECKLACE = 'necklace';
    case RING = 'ring';
    case BRACELET = 'bracelet';
}
