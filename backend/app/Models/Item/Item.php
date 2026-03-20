<?php

namespace App\Models\Item;

use App\Enums\Common\Rarity;
use App\Enums\Item\ItemType;
use App\Models\Drop\DropGroupItem;
use App\Models\Equipment\Equipment;
use App\Models\Inventory\InventoryStackItem;
use App\Models\Reward\RewardGroupItem;
use App\Models\Reward\UserRewardGrantItem;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Item extends Model
{
    protected $primaryKey = 'item_id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'item_type' => ItemType::class,
            'rarity' => Rarity::class,
            'is_enabled' => 'bool',
        ];
    }

    public function equipment(): HasOne
    {
        return $this->hasOne(Equipment::class, 'item_id', 'item_id');
    }

    public function stackItems(): HasMany
    {
        return $this->hasMany(InventoryStackItem::class, 'item_id', 'item_id');
    }

    public function dropGroupItems(): HasMany
    {
        return $this->hasMany(DropGroupItem::class, 'item_id', 'item_id');
    }

    public function rewardGroupItems(): HasMany
    {
        return $this->hasMany(RewardGroupItem::class, 'item_id', 'item_id');
    }

    public function rewardGrantItems(): HasMany
    {
        return $this->hasMany(UserRewardGrantItem::class, 'item_id', 'item_id');
    }
}
