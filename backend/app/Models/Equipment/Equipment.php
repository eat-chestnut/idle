<?php

namespace App\Models\Equipment;

use App\Enums\Common\Rarity;
use App\Enums\Equipment\EquipmentSlot;
use App\Enums\Equipment\SubWeaponCategory;
use App\Enums\Equipment\WeaponCategory;
use App\Models\Item\Item;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Equipment extends Model
{
    protected $table = 'equipments';

    protected $primaryKey = 'item_id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'equipment_slot' => EquipmentSlot::class,
            'rarity' => Rarity::class,
            'weapon_category' => WeaponCategory::class,
            'sub_weapon_category' => SubWeaponCategory::class,
            'is_two_handed' => 'bool',
            'is_enabled' => 'bool',
        ];
    }

    public function item(): BelongsTo
    {
        return $this->belongsTo(Item::class, 'item_id', 'item_id');
    }

    public function equipmentInstances(): HasMany
    {
        return $this->hasMany(InventoryEquipmentInstance::class, 'item_id', 'item_id');
    }
}
