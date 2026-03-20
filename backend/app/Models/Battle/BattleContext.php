<?php

namespace App\Models\Battle;

use App\Enums\Battle\BattleContextStatus;
use App\Models\Character\Character;
use App\Models\Stage\StageDifficulty;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BattleContext extends Model
{
    protected $primaryKey = 'battle_context_id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'status' => BattleContextStatus::class,
            'settled_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function character(): BelongsTo
    {
        return $this->belongsTo(Character::class, 'character_id', 'character_id');
    }

    public function stageDifficulty(): BelongsTo
    {
        return $this->belongsTo(StageDifficulty::class, 'stage_difficulty_id', 'stage_difficulty_id');
    }
}
