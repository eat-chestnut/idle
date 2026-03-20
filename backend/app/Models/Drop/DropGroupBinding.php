<?php

namespace App\Models\Drop;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DropGroupBinding extends Model
{
    protected $guarded = [];

    public function dropGroup(): BelongsTo
    {
        return $this->belongsTo(DropGroup::class, 'drop_group_id', 'drop_group_id');
    }
}
