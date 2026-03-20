<?php

namespace App\Http\Resources\Api\Character;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Collection;

class CharacterListResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'characters' => CharacterResource::collection(
                Collection::make(data_get($this->resource, 'characters', []))
            )->resolve($request),
        ];
    }
}
