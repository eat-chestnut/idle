<?php

namespace App\Enums\Drop;

enum DropRollType: string
{
    case WEIGHTED_SINGLE = 'weighted_single';
    case WEIGHTED_REPEAT = 'weighted_repeat';
}
