<?php

namespace App\Http\Requests\Api\Battle;

use App\Http\Requests\Api\ApiRequest;

class SettleBattleRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'character_id' => ['required', 'integer', 'min:1'],
            'stage_difficulty_id' => ['required', 'string'],
            'battle_context_id' => ['required', 'string'],
            'is_cleared' => ['required', 'integer', 'in:0,1'],
            'killed_monsters' => ['required', 'array'],
            'killed_monsters.*' => ['string'],
        ];
    }
}
