<?php

namespace App\Http\Resources\Api\Character;

use BackedEnum;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CharacterResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'character_id' => (int) data_get($this->resource, 'character_id'),
            'character_name' => (string) data_get($this->resource, 'character_name', ''),
            'class_id' => (string) data_get($this->resource, 'class_id', ''),
            'class_name' => (string) data_get($this->resource, 'gameClass.class_name', ''),
            'level' => (int) data_get($this->resource, 'level', 0),
            'exp' => (int) data_get($this->resource, 'exp', 0),
            'is_active' => (int) ((bool) data_get($this->resource, 'is_active', false)),
            'unspent_stat_points' => (int) data_get($this->resource, 'unspent_stat_points', 0),
            'added_strength' => (int) data_get($this->resource, 'added_strength', 0),
            'added_mana' => (int) data_get($this->resource, 'added_mana', 0),
            'added_constitution' => (int) data_get($this->resource, 'added_constitution', 0),
            'added_dexterity' => (int) data_get($this->resource, 'added_dexterity', 0),
            'long_term_growth_stage' => $this->normalizeValue(data_get($this->resource, 'long_term_growth_stage')),
        ];
    }

    private function normalizeValue(mixed $value): mixed
    {
        return $value instanceof BackedEnum ? $value->value : $value;
    }
}
