<?php

namespace App\Models\Reward;

use App\Enums\Reward\RewardSourceType;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RewardGroupBinding extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'source_type' => RewardSourceType::class,
        ];
    }

    public function rewardGroup(): BelongsTo
    {
        return $this->belongsTo(RewardGroup::class, 'reward_group_id', 'reward_group_id');
    }
}
