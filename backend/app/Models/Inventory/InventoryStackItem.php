<?php

namespace App\Models\Inventory;

use App\Models\Item\Item;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class InventoryStackItem extends Model
{
    protected $guarded = [];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function item(): BelongsTo
    {
        return $this->belongsTo(Item::class, 'item_id', 'item_id');
    }
}
