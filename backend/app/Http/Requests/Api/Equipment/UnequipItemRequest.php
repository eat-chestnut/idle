<?php

namespace App\Http\Requests\Api\Equipment;

use App\Http\Requests\Api\ApiRequest;

class UnequipItemRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'target_slot_key' => ['required', 'string', 'max:255'],
        ];
    }
}
