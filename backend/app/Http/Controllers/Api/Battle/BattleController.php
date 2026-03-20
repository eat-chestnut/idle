<?php

namespace App\Http\Controllers\Api\Battle;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Battle\PrepareBattleRequest;
use App\Http\Requests\Api\Battle\SettleBattleRequest;
use App\Http\Resources\Api\Battle\BattlePrepareResource;
use App\Http\Resources\Api\Battle\BattleSettlementResource;
use App\Services\Battle\Workflow\BattleSettlementWorkflow;
use App\Services\Battle\Workflow\BattlePrepareWorkflow;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;

class BattleController extends Controller
{
    public function __construct(
        private readonly BattlePrepareWorkflow $battlePrepareWorkflow,
        private readonly BattleSettlementWorkflow $battleSettlementWorkflow,
    ) {
    }

    public function prepare(PrepareBattleRequest $request): JsonResponse
    {
        $result = $this->battlePrepareWorkflow->prepareBattle(
            (int) $request->user()->getAuthIdentifier(),
            (int) $request->validated()['character_id'],
            (string) $request->validated()['stage_difficulty_id']
        );

        return response()->json(
            ApiResponse::success((new BattlePrepareResource($result))->resolve($request))
        );
    }

    public function settle(SettleBattleRequest $request): JsonResponse
    {
        $result = $this->battleSettlementWorkflow->settleBattle(
            (int) $request->user()->getAuthIdentifier(),
            (int) $request->validated()['character_id'],
            (string) $request->validated()['stage_difficulty_id'],
            [
                'battle_context_id' => (string) $request->validated()['battle_context_id'],
                'is_cleared' => (int) $request->validated()['is_cleared'],
                'killed_monsters' => array_values($request->validated()['killed_monsters']),
            ]
        );

        return response()->json(
            ApiResponse::success((new BattleSettlementResource($result))->resolve($request))
        );
    }
}
