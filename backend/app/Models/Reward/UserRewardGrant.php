<?php

namespace App\Models\Reward;

use App\Enums\Reward\GrantStatus;
use App\Enums\Reward\RewardSourceType;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class UserRewardGrant extends Model
{
    protected $primaryKey = 'reward_grant_id';

    public $incrementing = true;

    protected $keyType = 'int';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'source_type' => RewardSourceType::class,
            'grant_status' => GrantStatus::class,
            'granted_at' => 'datetime',
            'grant_payload_snapshot' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function rewardGroup(): BelongsTo
    {
        return $this->belongsTo(RewardGroup::class, 'reward_group_id', 'reward_group_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(UserRewardGrantItem::class, 'reward_grant_id', 'reward_grant_id');
    }
}
