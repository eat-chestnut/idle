<?php

namespace App\Models\Reward;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class RewardGroup extends Model
{
    protected $primaryKey = 'reward_group_id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'bool',
        ];
    }

    public function items(): HasMany
    {
        return $this->hasMany(RewardGroupItem::class, 'reward_group_id', 'reward_group_id');
    }

    public function bindings(): HasMany
    {
        return $this->hasMany(RewardGroupBinding::class, 'reward_group_id', 'reward_group_id');
    }

    public function grants(): HasMany
    {
        return $this->hasMany(UserRewardGrant::class, 'reward_group_id', 'reward_group_id');
    }
}
