<?php

namespace App\Models\Stage;

use App\Enums\Stage\DifficultyKey;
use App\Models\Reward\RewardGroupBinding;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class StageDifficulty extends Model
{
    protected $primaryKey = 'stage_difficulty_id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'difficulty_key' => DifficultyKey::class,
            'is_enabled' => 'bool',
        ];
    }

    public function stage(): BelongsTo
    {
        return $this->belongsTo(ChapterStage::class, 'stage_id', 'stage_id');
    }

    public function monsterBindings(): HasMany
    {
        return $this->hasMany(StageMonsterBinding::class, 'stage_difficulty_id', 'stage_difficulty_id');
    }

    public function rewardBindings(): HasMany
    {
        return $this->hasMany(RewardGroupBinding::class, 'source_id', 'stage_difficulty_id');
    }
}
