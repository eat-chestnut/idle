<?php

namespace App\Models\Character;

use App\Models\GameClass\GameClass;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Character extends Model
{
    protected $primaryKey = 'character_id';

    public $incrementing = true;

    protected $keyType = 'int';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'extra_context' => 'array',
            'is_active' => 'bool',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function gameClass(): BelongsTo
    {
        return $this->belongsTo(GameClass::class, 'class_id', 'class_id');
    }

    public function equipmentSlots(): HasMany
    {
        return $this->hasMany(CharacterEquipmentSlot::class, 'character_id', 'character_id');
    }
}
