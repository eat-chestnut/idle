<?php

namespace App\Http\Controllers\Api\Inventory;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Inventory\InventoryListRequest;
use App\Http\Resources\Api\Inventory\InventoryListResource;
use App\Services\Inventory\Query\InventoryQueryService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;

class InventoryController extends Controller
{
    public function __construct(
        private readonly InventoryQueryService $inventoryQueryService,
    ) {
    }

    public function index(InventoryListRequest $request): JsonResponse
    {
        $payload = $this->inventoryQueryService->getInventoryList(
            (int) $request->user()->getAuthIdentifier(),
            (string) ($request->validated()['tab'] ?? 'all')
        );

        return response()->json(
            ApiResponse::success((new InventoryListResource($payload))->resolve($request))
        );
    }
}
