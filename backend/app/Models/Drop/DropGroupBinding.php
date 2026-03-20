<?php

namespace App\Models\Drop;

use App\Enums\Drop\DropSourceType;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DropGroupBinding extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'source_type' => DropSourceType::class,
        ];
    }

    public function dropGroup(): BelongsTo
    {
        return $this->belongsTo(DropGroup::class, 'drop_group_id', 'drop_group_id');
    }
}
