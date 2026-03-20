<?php

namespace App\Http\Resources\Api\Stage;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Collection;

class ChapterStageListResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'chapter_id' => (string) data_get($this->resource, 'chapter_id', ''),
            'stages' => ChapterStageResource::collection(
                Collection::make(data_get($this->resource, 'stages', []))
            )->resolve($request),
        ];
    }
}
