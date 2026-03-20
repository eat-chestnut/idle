<?php

namespace App\Http\Resources\Api\Stage;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Collection;

class ChapterListResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'chapters' => ChapterResource::collection(
                Collection::make(data_get($this->resource, 'chapters', []))
            )->resolve($request),
        ];
    }
}
