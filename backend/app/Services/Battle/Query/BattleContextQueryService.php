<?php

namespace App\Services\Battle\Query;

use App\Models\Battle\BattleContext;

class BattleContextQueryService
{
    public function getBattleContextById(string $battleContextId, bool $forUpdate = false): ?BattleContext
    {
        $query = BattleContext::query()
            ->where('battle_context_id', $battleContextId);

        if ($forUpdate) {
            $query->lockForUpdate();
        }

        return $query->first();
    }
}
