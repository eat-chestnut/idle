<?php

namespace App\Http\Controllers\Api\Stage;

use App\Exceptions\BusinessException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Stage\ChapterStageListRequest;
use App\Http\Requests\Api\Stage\ChapterListRequest;
use App\Http\Requests\Api\Stage\FirstClearRewardStatusRequest;
use App\Http\Requests\Api\Stage\StageDifficultyListRequest;
use App\Http\Resources\Api\Stage\ChapterStageListResource;
use App\Http\Resources\Api\Stage\ChapterListResource;
use App\Http\Resources\Api\Stage\FirstClearRewardStatusResource;
use App\Http\Resources\Api\Stage\StageDifficultyListResource;
use App\Services\Reward\Config\FirstClearRewardConfigService;
use App\Services\Reward\Query\FirstClearRewardStatusQueryService;
use App\Services\Stage\Config\ChapterConfigService;
use App\Services\Stage\Config\StageConfigService;
use App\Support\ApiResponse;
use App\Support\ErrorCode;
use Illuminate\Http\JsonResponse;

class StageController extends Controller
{
    public function __construct(
        private readonly ChapterConfigService $chapterConfigService,
        private readonly StageConfigService $stageConfigService,
        private readonly FirstClearRewardConfigService $firstClearRewardConfigService,
        private readonly FirstClearRewardStatusQueryService $firstClearRewardStatusQueryService,
    ) {
    }

    public function chapters(ChapterListRequest $request): JsonResponse
    {
        return response()->json(
            ApiResponse::success(
                (new ChapterListResource([
                    'chapters' => $this->chapterConfigService->getEnabledChapters(),
                ]))->resolve($request)
            )
        );
    }

    public function stages(ChapterStageListRequest $request, string $chapter_id): JsonResponse
    {
        $chapter = $this->stageConfigService->getEnabledChapterById($chapter_id);

        if ($chapter === null) {
            throw new BusinessException(ErrorCode::CHAPTER_NOT_FOUND);
        }

        return response()->json(
            ApiResponse::success(
                (new ChapterStageListResource([
                    'chapter_id' => $chapter_id,
                    'stages' => $this->stageConfigService->getEnabledStagesByChapterId($chapter_id),
                ]))->resolve($request)
            )
        );
    }

    public function difficulties(StageDifficultyListRequest $request, string $stage_id): JsonResponse
    {
        $stage = $this->stageConfigService->getEnabledStageById($stage_id);

        if ($stage === null) {
            throw new BusinessException(ErrorCode::STAGE_NOT_FOUND);
        }

        $difficulties = $this->stageConfigService->getEnabledDifficultiesByStageId($stage_id);
        $bindingMap = $this->firstClearRewardConfigService->getEnabledBindingMapBySourceIds(
            $difficulties->pluck('stage_difficulty_id')->all()
        );
        $rewardSummaryMap = $this->firstClearRewardStatusQueryService->getSummaryMap(
            (int) $request->user()->getAuthIdentifier(),
            $bindingMap
        );

        $payload = [
            'stage_id' => $stage_id,
            'difficulties' => $difficulties->map(
                static function ($difficulty) use ($rewardSummaryMap): array {
                    return [
                        'stage_difficulty_id' => (string) $difficulty->stage_difficulty_id,
                        'difficulty_key' => $difficulty->difficulty_key,
                        'difficulty_name' => (string) $difficulty->difficulty_name,
                        'difficulty_order' => (int) $difficulty->difficulty_order,
                        'recommended_power' => (int) $difficulty->recommended_power,
                        'first_clear_reward' => $rewardSummaryMap[(string) $difficulty->stage_difficulty_id] ?? [
                            'has_reward' => 0,
                            'has_granted' => 0,
                            'reward_group_id' => null,
                        ],
                    ];
                }
            )->all(),
        ];

        return response()->json(
            ApiResponse::success((new StageDifficultyListResource($payload))->resolve($request))
        );
    }

    public function firstClearRewardStatus(
        FirstClearRewardStatusRequest $request,
        string $stage_difficulty_id
    ): JsonResponse {
        $stageDifficulty = $this->stageConfigService->getEnabledStageDifficultyById($stage_difficulty_id);

        if ($stageDifficulty === null) {
            throw new BusinessException(ErrorCode::STAGE_DIFFICULTY_NOT_FOUND);
        }

        $payload = $this->firstClearRewardStatusQueryService->getStatus(
            (int) $request->user()->getAuthIdentifier(),
            $stage_difficulty_id,
            $this->firstClearRewardConfigService->getEnabledBindingBySourceId($stage_difficulty_id)
        );

        return response()->json(
            ApiResponse::success((new FirstClearRewardStatusResource($payload))->resolve($request))
        );
    }
}
