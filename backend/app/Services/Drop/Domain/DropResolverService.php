<?php

namespace App\Services\Drop\Domain;

use App\Enums\Drop\DropRollType;
use App\Enums\Drop\DropSourceType;
use App\Exceptions\BusinessException;
use App\Models\Drop\DropGroup;
use App\Models\Drop\DropGroupBinding;
use App\Models\Drop\DropGroupItem;
use App\Services\Drop\Config\DropConfigService;
use App\Services\Item\Config\ItemConfigService;
use App\Support\ErrorCode;
use Illuminate\Support\Facades\Log;
use Throwable;

class DropResolverService
{
    public function __construct(
        private readonly DropConfigService $dropConfigService,
        private readonly ItemConfigService $itemConfigService,
    ) {
    }

    public function resolve(array $context): array
    {
        try {
            $this->validateDropResolveContext($context);
            $sources = $this->groupSourcesForDropResolve($context);
            $bindingMap = $this->dropConfigService->getDropBindingsBySources($sources);
            $dropGroupIds = [];

            foreach ($sources as $source) {
                $bindingKey = $this->dropConfigService->buildBindingKey($source['source_type'], $source['source_id']);

                if (! isset($bindingMap[$bindingKey])) {
                    throw new BusinessException(ErrorCode::DROP_SOURCE_BINDING_NOT_FOUND);
                }

                $dropGroupIds[] = (string) $bindingMap[$bindingKey]->drop_group_id;
            }

            $dropGroupMap = $this->dropConfigService->getDropGroupMapByIds($dropGroupIds);
            $dropGroupItemsMap = $this->dropConfigService->getDropGroupItemsMapByGroupIds($dropGroupIds);
            $rawResults = [];

            foreach ($sources as $source) {
                $binding = $bindingMap[$this->dropConfigService->buildBindingKey($source['source_type'], $source['source_id'])];
                $dropGroupId = (string) $binding->drop_group_id;

                $rawResults = array_merge(
                    $rawResults,
                    $this->resolveDropForSource(
                        $source,
                        $binding,
                        $dropGroupMap[$dropGroupId] ?? null,
                        $dropGroupItemsMap[$dropGroupId] ?? []
                    )
                );
            }

            return $this->buildStandardDropResults($this->mergeDropResults($rawResults));
        } catch (BusinessException $exception) {
            Log::warning('drop resolve failed', [
                'stage_difficulty_id' => data_get($context, 'stage_difficulty_id'),
                'battle_context_id' => data_get($context, 'battle_context_id'),
                'killed_monster_ids' => data_get($context, 'killed_monster_ids', []),
                'error_code' => $exception->getErrorCode(),
            ]);

            throw $exception;
        } catch (Throwable $throwable) {
            Log::error('drop resolve crashed', [
                'stage_difficulty_id' => data_get($context, 'stage_difficulty_id'),
                'battle_context_id' => data_get($context, 'battle_context_id'),
                'killed_monster_ids' => data_get($context, 'killed_monster_ids', []),
                'message' => $throwable->getMessage(),
            ]);

            throw new BusinessException(ErrorCode::DROP_RESOLVE_FAILED, previous: $throwable);
        }
    }

    public function validateDropResolveContext(array $context): void
    {
        if (! is_string(data_get($context, 'stage_difficulty_id')) || data_get($context, 'stage_difficulty_id') === '') {
            throw new BusinessException(ErrorCode::DROP_CONTEXT_INVALID);
        }

        if (! is_string(data_get($context, 'battle_context_id')) || data_get($context, 'battle_context_id') === '') {
            throw new BusinessException(ErrorCode::DROP_CONTEXT_INVALID);
        }

        $killedMonsterIds = data_get($context, 'killed_monster_ids');

        if (! is_array($killedMonsterIds) || $killedMonsterIds === []) {
            throw new BusinessException(ErrorCode::DROP_CONTEXT_INVALID);
        }

        foreach ($killedMonsterIds as $monsterId) {
            if (! is_string($monsterId) || $monsterId === '') {
                throw new BusinessException(ErrorCode::DROP_CONTEXT_INVALID);
            }
        }
    }

    public function groupSourcesForDropResolve(array $context): array
    {
        $sources = [];

        foreach (data_get($context, 'killed_monster_ids', []) as $monsterId) {
            $sourceKey = DropSourceType::MONSTER->value.':'.$monsterId;

            if (! isset($sources[$sourceKey])) {
                $sources[$sourceKey] = [
                    'source_type' => DropSourceType::MONSTER->value,
                    'source_id' => $monsterId,
                    'kill_count' => 0,
                ];
            }

            $sources[$sourceKey]['kill_count']++;
        }

        return array_values($sources);
    }

    public function resolveDropForSource(
        array $source,
        DropGroupBinding $binding,
        ?DropGroup $dropGroup,
        array $groupItems
    ): array {
        if ($dropGroup === null || ! $dropGroup->is_enabled) {
            throw new BusinessException(ErrorCode::DROP_GROUP_INVALID);
        }

        if ($groupItems === []) {
            throw new BusinessException(ErrorCode::DROP_GROUP_ITEMS_EMPTY);
        }

        $results = [];

        for ($killIndex = 0; $killIndex < (int) $source['kill_count']; $killIndex++) {
            $sourceMeta = [
                'source_type' => $source['source_type'],
                'source_id' => $source['source_id'],
                'drop_group_id' => (string) $binding->drop_group_id,
            ];

            $results = match ($dropGroup->roll_type) {
                DropRollType::WEIGHTED_SINGLE => array_merge($results, [
                    $this->drawWeightedSingle($groupItems, $sourceMeta),
                ]),
                DropRollType::WEIGHTED_REPEAT => array_merge(
                    $results,
                    $this->drawWeightedRepeat($groupItems, (int) $dropGroup->roll_times, $sourceMeta)
                ),
                default => throw new BusinessException(ErrorCode::DROP_ROLL_TYPE_INVALID),
            };
        }

        return $results;
    }

    public function drawWeightedSingle(array $groupItems, array $sourceMeta): array
    {
        $pickedItem = $this->pickOneByWeight($groupItems);

        return [
            'item_id' => (string) $pickedItem->item_id,
            'quantity' => $this->rollQuantity($pickedItem),
            'source_type' => $sourceMeta['source_type'],
            'source_id' => $sourceMeta['source_id'],
            'drop_group_id' => $sourceMeta['drop_group_id'],
        ];
    }

    public function drawWeightedRepeat(array $groupItems, int $rollTimes, array $sourceMeta): array
    {
        $results = [];

        for ($index = 0; $index < $rollTimes; $index++) {
            $results[] = $this->drawWeightedSingle($groupItems, $sourceMeta);
        }

        return $results;
    }

    public function pickOneByWeight(array $groupItems): DropGroupItem
    {
        $validItems = array_values(array_filter(
            $groupItems,
            static fn (DropGroupItem $groupItem): bool => (int) $groupItem->weight > 0
        ));

        if ($validItems === []) {
            throw new BusinessException(ErrorCode::DROP_WEIGHT_INVALID);
        }

        $totalWeight = array_sum(array_map(
            static fn (DropGroupItem $groupItem): int => (int) $groupItem->weight,
            $validItems
        ));

        if ($totalWeight <= 0) {
            throw new BusinessException(ErrorCode::DROP_WEIGHT_INVALID);
        }

        $rolled = random_int(1, $totalWeight);
        $currentWeight = 0;

        foreach ($validItems as $groupItem) {
            $currentWeight += (int) $groupItem->weight;

            if ($rolled <= $currentWeight) {
                return $groupItem;
            }
        }

        throw new BusinessException(ErrorCode::DROP_WEIGHT_INVALID);
    }

    public function mergeDropResults(array $rawResults): array
    {
        $mergedResults = [];

        foreach ($rawResults as $rawResult) {
            $itemId = (string) $rawResult['item_id'];

            if (! isset($mergedResults[$itemId])) {
                $mergedResults[$itemId] = [
                    'item_id' => $itemId,
                    'quantity' => 0,
                ];
            }

            $mergedResults[$itemId]['quantity'] += (int) $rawResult['quantity'];
        }

        return array_values($mergedResults);
    }

    public function buildStandardDropResults(array $mergedResults): array
    {
        if ($mergedResults === []) {
            return [];
        }

        $itemMap = $this->itemConfigService->getEnabledItemMapByIds(array_column($mergedResults, 'item_id'));
        $standardResults = [];

        foreach ($mergedResults as $mergedResult) {
            $itemId = (string) $mergedResult['item_id'];
            $item = $itemMap[$itemId] ?? null;

            if ($item === null) {
                throw new BusinessException(ErrorCode::DROP_RESULT_BUILD_FAILED);
            }

            $standardResults[] = [
                'item_id' => $itemId,
                'item_name' => (string) $item->item_name,
                'item_type' => (string) data_get($item, 'item_type.value', $item->item_type),
                'rarity' => (string) data_get($item, 'rarity.value', $item->rarity),
                'icon' => $item->icon,
                'quantity' => (int) $mergedResult['quantity'],
            ];
        }

        return $standardResults;
    }

    private function rollQuantity(DropGroupItem $groupItem): int
    {
        $minQuantity = (int) $groupItem->min_quantity;
        $maxQuantity = (int) $groupItem->max_quantity;

        if ($minQuantity <= 0 || $maxQuantity < $minQuantity) {
            throw new BusinessException(ErrorCode::DROP_WEIGHT_INVALID);
        }

        return random_int($minQuantity, $maxQuantity);
    }
}
