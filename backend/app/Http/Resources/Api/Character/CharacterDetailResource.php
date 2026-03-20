<?php

namespace App\Http\Resources\Api\Character;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CharacterDetailResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'character' => (new CharacterResource($this->resource))->resolve($request),
        ];
    }
}
