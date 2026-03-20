<?php

namespace App\Services\Character\Domain;

use App\Exceptions\BusinessException;
use App\Models\Character\Character;
use App\Support\ErrorCode;
use Throwable;

class CharacterActivateService
{
    public function deactivateOtherCharacters(int $userId, int $activeCharacterId): void
    {
        try {
            Character::query()
                ->where('user_id', $userId)
                ->where('character_id', '!=', $activeCharacterId)
                ->where('is_active', true)
                ->update(['is_active' => false]);
        } catch (Throwable $throwable) {
            throw new BusinessException(ErrorCode::CHARACTER_STATE_INVALID, previous: $throwable);
        }
    }

    public function activateCharacter(Character $character): Character
    {
        if ((bool) $character->is_active) {
            $character->loadMissing('gameClass');

            return $character;
        }

        try {
            $character->forceFill([
                'is_active' => true,
            ])->save();
        } catch (Throwable $throwable) {
            throw new BusinessException(ErrorCode::CHARACTER_STATE_INVALID, previous: $throwable);
        }

        $character->refresh();
        $character->loadMissing('gameClass');

        return $character;
    }
}
