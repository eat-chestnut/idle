<?php

namespace App\Http\Controllers\Api\Equipment;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Equipment\EquipItemRequest;
use App\Http\Requests\Api\Equipment\UnequipItemRequest;
use App\Http\Resources\Api\Equipment\EquipmentChangeResource;
use App\Services\Equipment\Workflow\EquipmentChangeWorkflow;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;

class EquipmentController extends Controller
{
    public function __construct(
        private readonly EquipmentChangeWorkflow $equipmentChangeWorkflow,
    ) {
    }

    public function equip(EquipItemRequest $request, int $character_id): JsonResponse
    {
        $result = $this->equipmentChangeWorkflow->equip(
            (int) $request->user()->getAuthIdentifier(),
            $character_id,
            (int) $request->validated()['equipment_instance_id'],
            (string) $request->validated()['target_slot_key']
        );

        return response()->json(
            ApiResponse::success((new EquipmentChangeResource($result))->resolve($request))
        );
    }

    public function unequip(UnequipItemRequest $request, int $character_id): JsonResponse
    {
        $result = $this->equipmentChangeWorkflow->unequip(
            (int) $request->user()->getAuthIdentifier(),
            $character_id,
            (string) $request->validated()['target_slot_key']
        );

        return response()->json(
            ApiResponse::success((new EquipmentChangeResource($result))->resolve($request))
        );
    }
}
