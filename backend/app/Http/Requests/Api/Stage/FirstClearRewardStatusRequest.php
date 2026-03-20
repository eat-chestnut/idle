<?php

namespace App\Http\Requests\Api\Stage;

use App\Http\Requests\Api\ApiRequest;

class FirstClearRewardStatusRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'stage_difficulty_id' => ['required', 'string'],
        ];
    }

    public function validationData(): array
    {
        return array_merge($this->all(), [
            'stage_difficulty_id' => $this->route('stage_difficulty_id'),
        ]);
    }
}
