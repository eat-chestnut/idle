<?php

namespace App\Models\Stage;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ChapterStage extends Model
{
    protected $table = 'chapter_stages';

    protected $primaryKey = 'stage_id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'bool',
        ];
    }

    public function chapter(): BelongsTo
    {
        return $this->belongsTo(Chapter::class, 'chapter_id', 'chapter_id');
    }

    public function difficulties(): HasMany
    {
        return $this->hasMany(StageDifficulty::class, 'stage_id', 'stage_id');
    }
}
