<?php

namespace App\Support\Ids;

use Illuminate\Support\Str;

class BattleContextIdGenerator
{
    public function generate(): string
    {
        return 'battle_ctx_'.now()->format('Ymd_His').'_'.Str::lower(Str::random(6));
    }
}
