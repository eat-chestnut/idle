<?php

namespace App\Models\Stage;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Chapter extends Model
{
    protected $primaryKey = 'chapter_id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'bool',
        ];
    }

    public function stages(): HasMany
    {
        return $this->hasMany(ChapterStage::class, 'chapter_id', 'chapter_id');
    }
}
