<?php

namespace App\Models\GameClass;

use App\Models\Character\Character;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class GameClass extends Model
{
    protected $table = 'classes';

    protected $primaryKey = 'class_id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'bool',
        ];
    }

    public function characters(): HasMany
    {
        return $this->hasMany(Character::class, 'class_id', 'class_id');
    }
}
