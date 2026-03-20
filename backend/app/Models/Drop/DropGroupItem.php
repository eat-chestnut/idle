<?php

namespace App\Models\Drop;

use App\Models\Item\Item;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DropGroupItem extends Model
{
    protected $guarded = [];

    public function dropGroup(): BelongsTo
    {
        return $this->belongsTo(DropGroup::class, 'drop_group_id', 'drop_group_id');
    }

    public function item(): BelongsTo
    {
        return $this->belongsTo(Item::class, 'item_id', 'item_id');
    }
}
