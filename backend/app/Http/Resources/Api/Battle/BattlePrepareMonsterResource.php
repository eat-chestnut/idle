<?php

namespace App\Http\Resources\Api\Battle;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BattlePrepareMonsterResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'monster_id' => (string) data_get($this->resource, 'monster_id', ''),
            'monster_name' => (string) data_get($this->resource, 'monster_name', ''),
            'monster_role' => (string) data_get($this->resource, 'monster_role', ''),
            'wave_no' => (int) data_get($this->resource, 'wave_no', 0),
            'sort_order' => (int) data_get($this->resource, 'sort_order', 0),
            'base_hp' => (int) data_get($this->resource, 'base_hp', 0),
            'base_attack' => (int) data_get($this->resource, 'base_attack', 0),
            'base_physical_defense' => (int) data_get($this->resource, 'base_physical_defense', 0),
            'base_magic_defense' => (int) data_get($this->resource, 'base_magic_defense', 0),
            'attack_interval' => data_get($this->resource, 'attack_interval'),
            'attack_range' => data_get($this->resource, 'attack_range'),
            'move_speed' => data_get($this->resource, 'move_speed'),
        ];
    }
}
