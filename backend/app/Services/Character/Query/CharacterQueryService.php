<?php

namespace App\Services\Character\Query;

use App\Exceptions\BusinessException;
use App\Models\Character\Character;
use App\Support\ErrorCode;
use Illuminate\Database\Eloquent\Collection;

class CharacterQueryService
{
    public function getCharacterById(int $characterId): ?Character
    {
        return Character::query()
            ->with('gameClass')
            ->find($characterId);
    }

    public function getOwnedCharacterById(int $userId, int $characterId): Character
    {
        $character = $this->getCharacterById($characterId);

        if ($character === null) {
            throw new BusinessException(ErrorCode::CHARACTER_NOT_FOUND);
        }

        if ((int) $character->user_id !== $userId) {
            throw new BusinessException(ErrorCode::CHARACTER_FORBIDDEN);
        }

        return $character;
    }

    public function countUserCharacters(int $userId): int
    {
        return Character::query()
            ->where('user_id', $userId)
            ->count();
    }

    public function getOwnedCharacters(int $userId): Collection
    {
        return Character::query()
            ->with('gameClass')
            ->where('user_id', $userId)
            ->orderByDesc('is_active')
            ->orderBy('character_id')
            ->get();
    }

    public function existsUserCharacterName(int $userId, string $characterName): bool
    {
        return Character::query()
            ->where('user_id', $userId)
            ->where('character_name', $characterName)
            ->exists();
    }
}
