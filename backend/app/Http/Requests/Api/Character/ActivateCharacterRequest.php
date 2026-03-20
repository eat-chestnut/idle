<?php

namespace App\Http\Requests\Api\Character;

use App\Http\Requests\Api\ApiRequest;

class ActivateCharacterRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'character_id' => ['required', 'integer', 'min:1'],
        ];
    }

    public function validationData(): array
    {
        return array_merge($this->all(), [
            'character_id' => $this->route('character_id'),
        ]);
    }
}
