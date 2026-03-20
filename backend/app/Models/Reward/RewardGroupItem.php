<?php

namespace App\Models\Reward;

use App\Models\Item\Item;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RewardGroupItem extends Model
{
    protected $guarded = [];

    public function rewardGroup(): BelongsTo
    {
        return $this->belongsTo(RewardGroup::class, 'reward_group_id', 'reward_group_id');
    }

    public function item(): BelongsTo
    {
        return $this->belongsTo(Item::class, 'item_id', 'item_id');
    }
}
