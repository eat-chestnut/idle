<?php

namespace App\Models;

use App\Models\Character\Character;
use App\Models\Equipment\InventoryEquipmentInstance;
use App\Models\Inventory\InventoryStackItem;
use App\Models\Reward\UserRewardGrant;
// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'api_token',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'api_token',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function characters(): HasMany
    {
        return $this->hasMany(Character::class, 'user_id');
    }

    public function stackItems(): HasMany
    {
        return $this->hasMany(InventoryStackItem::class, 'user_id');
    }

    public function equipmentInstances(): HasMany
    {
        return $this->hasMany(InventoryEquipmentInstance::class, 'user_id');
    }

    public function rewardGrants(): HasMany
    {
        return $this->hasMany(UserRewardGrant::class, 'user_id');
    }
}
