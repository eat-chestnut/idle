<?php

namespace App\Http\Resources\Api\Stage;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Collection;

class StageDifficultyListResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'stage_id' => (string) data_get($this->resource, 'stage_id', ''),
            'difficulties' => StageDifficultyResource::collection(
                Collection::make(data_get($this->resource, 'difficulties', []))
            )->resolve($request),
        ];
    }
}
