<?php

namespace App\Models\Drop;

use App\Enums\Drop\DropRollType;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DropGroup extends Model
{
    protected $primaryKey = 'drop_group_id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'roll_type' => DropRollType::class,
            'is_enabled' => 'bool',
        ];
    }

    public function items(): HasMany
    {
        return $this->hasMany(DropGroupItem::class, 'drop_group_id', 'drop_group_id');
    }

    public function bindings(): HasMany
    {
        return $this->hasMany(DropGroupBinding::class, 'drop_group_id', 'drop_group_id');
    }
}
