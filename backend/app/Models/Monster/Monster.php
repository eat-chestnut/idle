<?php

namespace App\Models\Monster;

use App\Models\Stage\StageMonsterBinding;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Monster extends Model
{
    protected $primaryKey = 'monster_id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'bool',
        ];
    }

    public function stageBindings(): HasMany
    {
        return $this->hasMany(StageMonsterBinding::class, 'monster_id', 'monster_id');
    }
}
