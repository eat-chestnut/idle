<?php

namespace App\Models\Stage;

use App\Enums\Monster\MonsterRole;
use App\Models\Monster\Monster;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StageMonsterBinding extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'monster_role' => MonsterRole::class,
        ];
    }

    public function stageDifficulty(): BelongsTo
    {
        return $this->belongsTo(StageDifficulty::class, 'stage_difficulty_id', 'stage_difficulty_id');
    }

    public function monster(): BelongsTo
    {
        return $this->belongsTo(Monster::class, 'monster_id', 'monster_id');
    }
}
