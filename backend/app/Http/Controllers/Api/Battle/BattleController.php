<?php

namespace App\Http\Controllers\Api\Battle;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Battle\PrepareBattleRequest;
use App\Http\Resources\Api\Battle\BattlePrepareResource;
use App\Services\Battle\Workflow\BattlePrepareWorkflow;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;

class BattleController extends Controller
{
    public function __construct(
        private readonly BattlePrepareWorkflow $battlePrepareWorkflow,
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
}
