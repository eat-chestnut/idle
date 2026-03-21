<?php

namespace App\Http\Resources\Api\Stage;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ChapterStageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'stage_id' => (string) data_get($this->resource, 'stage_id', ''),
            'stage_name' => (string) data_get($this->resource, 'stage_name', ''),
            'stage_order' => (int) data_get($this->resource, 'stage_order', 0),
        ];
    }
}
