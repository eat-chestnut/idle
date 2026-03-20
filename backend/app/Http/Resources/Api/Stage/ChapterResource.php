<?php

namespace App\Http\Resources\Api\Stage;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ChapterResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'chapter_id' => (string) data_get($this->resource, 'chapter_id', ''),
            'chapter_name' => (string) data_get($this->resource, 'chapter_name', ''),
            'chapter_desc' => data_get($this->resource, 'chapter_desc'),
            'chapter_group' => data_get($this->resource, 'chapter_group'),
            'sort_order' => (int) data_get($this->resource, 'sort_order', 0),
            'unlock_condition' => data_get($this->resource, 'unlock_condition'),
        ];
    }
}
