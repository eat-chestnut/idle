<?php

namespace App\Services\Stage\Config;

use App\Models\Stage\Chapter;
use App\Models\Stage\ChapterStage;
use App\Models\Stage\StageDifficulty;
use Illuminate\Database\Eloquent\Collection;

class StageConfigService
{
    public function getEnabledChapterById(string $chapterId): ?Chapter
    {
        return Chapter::query()
            ->where('chapter_id', $chapterId)
            ->where('is_enabled', true)
            ->first();
    }

    public function getEnabledStagesByChapterId(string $chapterId): Collection
    {
        return ChapterStage::query()
            ->with('chapter')
            ->where('chapter_id', $chapterId)
            ->where('is_enabled', true)
            ->whereHas('chapter', static fn ($query) => $query->where('is_enabled', true))
            ->orderBy('stage_order')
            ->orderBy('stage_id')
            ->get();
    }

    public function getEnabledStageById(string $stageId): ?ChapterStage
    {
        return ChapterStage::query()
            ->with('chapter')
            ->where('stage_id', $stageId)
            ->where('is_enabled', true)
            ->whereHas('chapter', static fn ($query) => $query->where('is_enabled', true))
            ->first();
    }

    public function getEnabledDifficultiesByStageId(string $stageId): Collection
    {
        return StageDifficulty::query()
            ->with(['stage.chapter'])
            ->where('stage_id', $stageId)
            ->where('is_enabled', true)
            ->whereHas('stage', static function ($query): void {
                $query->where('is_enabled', true)
                    ->whereHas('chapter', static fn ($chapterQuery) => $chapterQuery->where('is_enabled', true));
            })
            ->orderBy('difficulty_order')
            ->get();
    }

    public function getEnabledStageDifficultyById(string $stageDifficultyId): ?StageDifficulty
    {
        return StageDifficulty::query()
            ->with(['stage.chapter'])
            ->where('stage_difficulty_id', $stageDifficultyId)
            ->where('is_enabled', true)
            ->whereHas('stage', static function ($query): void {
                $query->where('is_enabled', true)
                    ->whereHas('chapter', static fn ($chapterQuery) => $chapterQuery->where('is_enabled', true));
            })
            ->first();
    }
}
