<?php

namespace App\Services\Character\Config;

use App\Models\GameClass\GameClass;

class ClassConfigService
{
    public function getEnabledClassById(string $classId): ?GameClass
    {
        return GameClass::query()
            ->where('class_id', $classId)
            ->where('is_enabled', true)
            ->first();
    }
}
