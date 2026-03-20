<?php

namespace App\Services\Inventory\Query;

use App\Models\Inventory\InventoryStackItem;

class InventoryWriteQueryService
{
    public function getExistingStackItemMap(int $userId, array $itemIds, bool $forUpdate = false): array
    {
        if ($itemIds === []) {
            return [];
        }

        $query = InventoryStackItem::query()
            ->where('user_id', $userId)
            ->whereIn('item_id', array_values(array_unique($itemIds)));

        if ($forUpdate) {
            $query->lockForUpdate();
        }

        return $query->get()->keyBy('item_id')->all();
    }
}
