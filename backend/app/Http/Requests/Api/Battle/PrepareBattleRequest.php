<?php

namespace App\Http\Requests\Api\Battle;

use App\Http\Requests\Api\ApiRequest;

class PrepareBattleRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'character_id' => ['required', 'integer', 'min:1'],
            'stage_difficulty_id' => ['required', 'string'],
        ];
    }
}
