<?php

namespace App\Enums\Battle;

enum BattleContextStatus: string
{
    case PREPARED = 'prepared';
    case SETTLED = 'settled';
}
