<?php

namespace App\Enums\Common;

enum Rarity: string
{
    case COMMON = 'common';
    case RARE = 'rare';
    case EPIC = 'epic';
    case LEGENDARY = 'legendary';
}
