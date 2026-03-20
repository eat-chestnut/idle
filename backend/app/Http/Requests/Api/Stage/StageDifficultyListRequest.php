<?php

namespace App\Http\Requests\Api\Stage;

use App\Http\Requests\Api\ApiRequest;

class StageDifficultyListRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'stage_id' => ['required', 'string'],
        ];
    }

    public function validationData(): array
    {
        return array_merge($this->all(), [
            'stage_id' => $this->route('stage_id'),
        ]);
    }
}
