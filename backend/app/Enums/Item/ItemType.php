<?php

namespace App\Enums\Item;

enum ItemType: string
{
    case EQUIPMENT = 'equipment';
    case MATERIAL = 'material';
    case REWARD_ITEM = 'reward_item';
}
