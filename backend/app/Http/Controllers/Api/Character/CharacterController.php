<?php

namespace App\Http\Controllers\Api\Character;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Character\ActivateCharacterRequest;
use App\Http\Requests\Api\Character\CreateCharacterRequest;
use App\Http\Requests\Api\Character\ListCharactersRequest;
use App\Http\Resources\Api\Character\CharacterCreateResource;
use App\Http\Resources\Api\Character\CharacterDetailResource;
use App\Http\Resources\Api\Character\CharacterListResource;
use App\Http\Resources\Api\Equipment\EquipmentSlotListResource;
use App\Services\Character\Query\CharacterQueryService;
use App\Services\Character\Workflow\CharacterActivateWorkflow;
use App\Services\Character\Workflow\CharacterCreateWorkflow;
use App\Services\Equipment\Query\EquipmentQueryService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CharacterController extends Controller
{
    public function __construct(
        private readonly CharacterCreateWorkflow $characterCreateWorkflow,
        private readonly CharacterActivateWorkflow $characterActivateWorkflow,
        private readonly CharacterQueryService $characterQueryService,
        private readonly EquipmentQueryService $equipmentQueryService,
    ) {
    }

    public function index(ListCharactersRequest $request): JsonResponse
    {
        $payload = [
            'characters' => $this->characterQueryService->getOwnedCharacters(
                (int) $request->user()->getAuthIdentifier()
            ),
        ];

        return response()->json(
            ApiResponse::success((new CharacterListResource($payload))->resolve($request))
        );
    }

    public function store(CreateCharacterRequest $request): JsonResponse
    {
        $result = $this->characterCreateWorkflow->createCharacter(
            (int) $request->user()->getAuthIdentifier(),
            $request->validated()
        );

        return response()->json(
            ApiResponse::success((new CharacterCreateResource($result))->resolve($request))
        );
    }

    public function show(Request $request, int $character_id): JsonResponse
    {
        $character = $this->characterQueryService->getOwnedCharacterById(
            (int) $request->user()->getAuthIdentifier(),
            $character_id
        );

        return response()->json(
            ApiResponse::success((new CharacterDetailResource($character))->resolve($request))
        );
    }

    public function activate(ActivateCharacterRequest $request, int $character_id): JsonResponse
    {
        $result = $this->characterActivateWorkflow->activateCharacter(
            (int) $request->user()->getAuthIdentifier(),
            $character_id
        );

        return response()->json(
            ApiResponse::success((new CharacterDetailResource($result))->resolve($request))
        );
    }

    public function equipmentSlots(Request $request, int $character_id): JsonResponse
    {
        $this->characterQueryService->getOwnedCharacterById(
            (int) $request->user()->getAuthIdentifier(),
            $character_id
        );

        $payload = [
            'character_id' => $character_id,
            'slots' => $this->equipmentQueryService->getOrderedSlotSnapshot($character_id),
        ];

        return response()->json(
            ApiResponse::success((new EquipmentSlotListResource($payload))->resolve($request))
        );
    }
}
