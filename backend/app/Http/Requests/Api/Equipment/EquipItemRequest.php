<?php

namespace App\Http\Requests\Api\Equipment;

use App\Http\Requests\Api\ApiRequest;

class EquipItemRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'equipment_instance_id' => ['required', 'integer', 'min:1'],
            'target_slot_key' => ['required', 'string', 'max:255'],
        ];
    }
}
