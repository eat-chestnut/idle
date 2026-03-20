<?php

namespace App\Http\Requests\Api\Stage;

use App\Http\Requests\Api\ApiRequest;

class ChapterStageListRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'chapter_id' => ['required', 'string'],
        ];
    }

    public function validationData(): array
    {
        return array_merge($this->all(), [
            'chapter_id' => $this->route('chapter_id'),
        ]);
    }
}
