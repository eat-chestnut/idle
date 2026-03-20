<?php

namespace App\Services\Drop\Config;

use App\Models\Drop\DropGroup;
use App\Models\Drop\DropGroupBinding;
use App\Models\Drop\DropGroupItem;
use Illuminate\Support\Collection;

class DropConfigService
{
    public function getDropBindingsBySources(array $sources): array
    {
        if ($sources === []) {
            return [];
        }

        $sourceCollection = Collection::make($sources)
            ->filter(static fn (array $source): bool => isset($source['source_type'], $source['source_id']))
            ->groupBy('source_type');

        $query = DropGroupBinding::query()->with('dropGroup');

        $query->where(static function ($outerQuery) use ($sourceCollection): void {
            foreach ($sourceCollection as $sourceType => $sourceGroup) {
                $outerQuery->orWhere(static function ($innerQuery) use ($sourceType, $sourceGroup): void {
                    $innerQuery->where('source_type', $sourceType)
                        ->whereIn('source_id', $sourceGroup->pluck('source_id')->all());
                });
            }
        });

        return $query->get()
            ->keyBy(fn (DropGroupBinding $binding): string => $this->buildBindingKey(
                (string) data_get($binding, 'source_type.value', $binding->source_type),
                (string) $binding->source_id
            ))
            ->all();
    }

    public function getDropGroupMapByIds(array $dropGroupIds): array
    {
        if ($dropGroupIds === []) {
            return [];
        }

        return DropGroup::query()
            ->whereIn('drop_group_id', array_values(array_unique($dropGroupIds)))
            ->where('is_enabled', true)
            ->get()
            ->keyBy('drop_group_id')
            ->all();
    }

    public function getDropGroupItemsMapByGroupIds(array $dropGroupIds): array
    {
        if ($dropGroupIds === []) {
            return [];
        }

        return DropGroupItem::query()
            ->with('item')
            ->whereIn('drop_group_id', array_values(array_unique($dropGroupIds)))
            ->where('weight', '>', 0)
            ->whereHas('item', static fn ($query) => $query->where('is_enabled', true))
            ->orderBy('sort_order')
            ->get()
            ->groupBy('drop_group_id')
            ->map(static fn (Collection $items): array => $items->all())
            ->all();
    }

    public function buildBindingKey(string $sourceType, string $sourceId): string
    {
        return $sourceType.':'.$sourceId;
    }
}
