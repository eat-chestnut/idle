<?php

namespace App\Enums\Monster;

enum MonsterRole: string
{
    case NORMAL_ENEMY = 'normal_enemy';
    case ELITE_ENEMY = 'elite_enemy';
    case BOSS_ENEMY = 'boss_enemy';
}
