<?php

namespace App\Http\Requests\Api\Character;

use App\Http\Requests\Api\ApiRequest;

class CreateCharacterRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'class_id' => ['required', 'string', 'max:255'],
            'character_name' => ['required', 'string', 'max:255'],
        ];
    }
}
