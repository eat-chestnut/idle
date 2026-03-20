<?php

namespace App\Models\Reward;

use App\Models\Item\Item;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserRewardGrantItem extends Model
{
    protected $guarded = [];

    public function rewardGrant(): BelongsTo
    {
        return $this->belongsTo(UserRewardGrant::class, 'reward_grant_id', 'reward_grant_id');
    }

    public function item(): BelongsTo
    {
        return $this->belongsTo(Item::class, 'item_id', 'item_id');
    }
}
