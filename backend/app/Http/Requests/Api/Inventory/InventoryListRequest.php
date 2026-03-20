<?php

namespace App\Http\Requests\Api\Inventory;

use App\Http\Requests\Api\ApiRequest;

class InventoryListRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'tab' => ['nullable', 'string', 'in:stack,equipment,all'],
            'page' => ['nullable', 'integer', 'min:1'],
            'page_size' => ['nullable', 'integer', 'min:1', 'max:100'],
        ];
    }
}
