<?php

namespace App\Http\Resources\Api\Battle;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BattlePrepareCharacterResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'character_id' => (int) data_get($this->resource, 'character_id', 0),
            'character_name' => (string) data_get($this->resource, 'character_name', ''),
            'class_id' => (string) data_get($this->resource, 'class_id', ''),
            'class_name' => (string) data_get($this->resource, 'class_name', ''),
            'level' => (int) data_get($this->resource, 'level', 0),
        ];
    }
}
