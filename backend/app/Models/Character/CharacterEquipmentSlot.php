<?php

namespace App\Models\Character;

use App\Enums\Equipment\EquipmentSlotKey;
use App\Models\Equipment\InventoryEquipmentInstance;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CharacterEquipmentSlot extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'slot_key' => EquipmentSlotKey::class,
        ];
    }

    public function character(): BelongsTo
    {
        return $this->belongsTo(Character::class, 'character_id', 'character_id');
    }

    public function equippedInstance(): BelongsTo
    {
        return $this->belongsTo(InventoryEquipmentInstance::class, 'equipped_instance_id', 'equipment_instance_id');
    }
}
