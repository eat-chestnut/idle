<?php

namespace App\Models\Equipment;

use App\Enums\Equipment\BindType;
use App\Models\Character\CharacterEquipmentSlot;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class InventoryEquipmentInstance extends Model
{
    protected $primaryKey = 'equipment_instance_id';

    public $incrementing = true;

    protected $keyType = 'int';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'bind_type' => BindType::class,
            'is_locked' => 'bool',
            'extra_attributes' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function equipmentTemplate(): BelongsTo
    {
        return $this->belongsTo(Equipment::class, 'item_id', 'item_id');
    }

    public function equippedSlot(): HasOne
    {
        return $this->hasOne(CharacterEquipmentSlot::class, 'equipped_instance_id', 'equipment_instance_id');
    }
}
