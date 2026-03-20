<?php

namespace App\Services\Stage\Config;

use App\Models\Stage\Chapter;
use Illuminate\Database\Eloquent\Collection;

class ChapterConfigService
{
    public function getEnabledChapters(): Collection
    {
        return Chapter::query()
            ->where('is_enabled', true)
            ->orderBy('sort_order')
            ->get();
    }
}
