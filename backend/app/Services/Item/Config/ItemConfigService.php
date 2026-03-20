<?php

namespace App\Services\Item\Config;

use App\Models\Item\Item;

class ItemConfigService
{
    public function getEnabledItemMapByIds(array $itemIds): array
    {
        if ($itemIds === []) {
            return [];
        }

        return Item::query()
            ->with('equipment')
            ->whereIn('item_id', array_values(array_unique($itemIds)))
            ->where('is_enabled', true)
            ->get()
            ->keyBy('item_id')
            ->all();
    }
}
