<?php

namespace App\Services\Character\Workflow;

use App\Models\Character\Character;
use App\Services\Character\Domain\CharacterActivateService;
use App\Services\Character\Query\CharacterQueryService;
use Illuminate\Support\Facades\DB;

class CharacterActivateWorkflow
{
    public function __construct(
        private readonly CharacterQueryService $characterQueryService,
        private readonly CharacterActivateService $characterActivateService,
    ) {
    }

    public function activateCharacter(int $userId, int $characterId): Character
    {
        return DB::transaction(function () use ($userId, $characterId): Character {
            $character = $this->characterQueryService->getOwnedCharacterById($userId, $characterId);

            $this->characterActivateService->deactivateOtherCharacters($userId, $characterId);
            
            return $this->characterActivateService->activateCharacter($character);
        });
    }
}
