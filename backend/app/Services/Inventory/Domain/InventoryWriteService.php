<?php

namespace App\Services\Inventory\Domain;

use App\Enums\Equipment\BindType;
use App\Enums\Item\ItemType;
use App\Exceptions\BusinessException;
use App\Models\Equipment\InventoryEquipmentInstance;
use App\Models\Inventory\InventoryStackItem;
use App\Services\Equipment\Config\EquipmentTemplateConfigService;
use App\Services\Equipment\Query\EquipmentQueryService;
use App\Services\Inventory\Query\InventoryWriteQueryService;
use App\Services\Item\Config\ItemConfigService;
use App\Support\ErrorCode;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class InventoryWriteService
{
    public function __construct(
        private readonly ItemConfigService $itemConfigService,
        private readonly InventoryWriteQueryService $inventoryWriteQueryService,
        private readonly EquipmentTemplateConfigService $equipmentTemplateConfigService,
        private readonly EquipmentQueryService $equipmentQueryService,
    ) {
    }

    public function write(int $userId, array $objects, array $context = []): array
    {
        try {
            $this->validateInventoryWriteContext($userId, $objects, $context);
            $itemMap = $this->itemConfigService->getEnabledItemMapByIds(array_column($objects, 'item_id'));

            if (count($itemMap) !== count(array_unique(array_column($objects, 'item_id')))) {
                throw new BusinessException(ErrorCode::INVENTORY_ITEM_INVALID);
            }

            $splitObjects = $this->splitInventoryObjects($objects, $itemMap);
            $equipmentTemplateMap = $this->equipmentTemplateConfigService->getEquipmentTemplateMapByItemIds(
                array_map(static fn (array $item): string => $item['item_id'], $splitObjects['equipment_items'])
            );

            if (count($equipmentTemplateMap) !== count(array_unique(array_map(
                static fn (array $item): string => $item['item_id'],
                $splitObjects['equipment_items']
            )))) {
                throw new BusinessException(ErrorCode::INVENTORY_EQUIPMENT_TEMPLATE_INVALID);
            }

            return DB::transaction(function () use ($userId, $splitObjects, $equipmentTemplateMap, $context): array {
                $existingStacks = $this->inventoryWriteQueryService->getExistingStackItemMap(
                    $userId,
                    array_map(static fn (array $item): string => $item['item_id'], $splitObjects['stack_items']),
                    true
                );

                $stackRows = $this->buildStackWriteRows($userId, $splitObjects['stack_items'], $existingStacks);
                $stackResults = $this->applyStackWrites($stackRows);
                $instancePayloads = $this->buildEquipmentInstancePayloads(
                    $userId,
                    $splitObjects['equipment_items'],
                    $equipmentTemplateMap,
                    $context
                );
                $instanceResults = $this->createEquipmentInstances($instancePayloads);

                return $this->buildInventoryWriteResult($stackResults, $instanceResults, $context);
            });
        } catch (BusinessException $exception) {
            Log::warning('inventory write failed', [
                'user_id' => $userId,
                'source' => data_get($context, 'source'),
                'source_type' => data_get($context, 'source_type'),
                'source_id' => data_get($context, 'source_id'),
                'error_code' => $exception->getErrorCode(),
            ]);

            throw $exception;
        } catch (Throwable $throwable) {
            Log::error('inventory write crashed', [
                'user_id' => $userId,
                'source' => data_get($context, 'source'),
                'source_type' => data_get($context, 'source_type'),
                'source_id' => data_get($context, 'source_id'),
                'message' => $throwable->getMessage(),
            ]);

            throw new BusinessException(ErrorCode::INVENTORY_WRITE_FAILED, previous: $throwable);
        }
    }

    public function writeRewards(int $userId, array $rewardItems, array $context = []): array
    {
        return $this->write($userId, $rewardItems, array_merge($context, [
            'source' => data_get($context, 'source', 'reward'),
        ]));
    }

    public function writeDrops(int $userId, array $dropItems, array $context = []): array
    {
        return $this->write($userId, $dropItems, array_merge($context, [
            'source' => data_get($context, 'source', 'drop'),
        ]));
    }

    public function emptyResult(): array
    {
        return [
            'stack_results' => [],
            'equipment_instance_results' => [],
            'created_equipment_instances' => [],
            'written_item_ids' => [],
            'summary' => [
                'stack_write_count' => 0,
                'equipment_instance_count' => 0,
            ],
        ];
    }

    public function validateInventoryWriteContext(int $userId, array $objects, array $context = []): void
    {
        if ($userId <= 0 || $objects === []) {
            throw new BusinessException(ErrorCode::INVENTORY_WRITE_CONTEXT_INVALID);
        }

        foreach ($objects as $object) {
            if (! is_string(data_get($object, 'item_id')) || data_get($object, 'item_id') === '') {
                throw new BusinessException(ErrorCode::INVENTORY_WRITE_CONTEXT_INVALID);
            }

            if (! is_int(data_get($object, 'quantity')) || (int) data_get($object, 'quantity') <= 0) {
                throw new BusinessException(ErrorCode::INVENTORY_WRITE_CONTEXT_INVALID);
            }
        }
    }

    public function splitInventoryObjects(array $objects, array $itemMap): array
    {
        $stackItems = [];
        $equipmentItems = [];

        foreach ($objects as $object) {
            $itemId = (string) $object['item_id'];
            $item = $itemMap[$itemId] ?? null;

            if ($item === null) {
                throw new BusinessException(ErrorCode::INVENTORY_ITEM_INVALID);
            }

            $itemType = data_get($item, 'item_type.value', $item->item_type);

            if ($itemType === ItemType::EQUIPMENT->value) {
                for ($index = 0; $index < (int) $object['quantity']; $index++) {
                    $equipmentItems[] = [
                        'item_id' => $itemId,
                        'quantity' => 1,
                    ];
                }

                continue;
            }

            if (! isset($stackItems[$itemId])) {
                $stackItems[$itemId] = [
                    'item_id' => $itemId,
                    'quantity' => 0,
                ];
            }

            $stackItems[$itemId]['quantity'] += (int) $object['quantity'];
        }

        return [
            'stack_items' => array_values($stackItems),
            'equipment_items' => $equipmentItems,
        ];
    }

    public function buildStackWriteRows(int $userId, array $stackItems, array $existingStacks): array
    {
        $rows = [];

        foreach ($stackItems as $stackItem) {
            $itemId = (string) $stackItem['item_id'];
            $beforeQuantity = (int) data_get($existingStacks[$itemId] ?? null, 'quantity', 0);
            $addQuantity = (int) $stackItem['quantity'];

            $rows[] = [
                'user_id' => $userId,
                'item_id' => $itemId,
                'before_quantity' => $beforeQuantity,
                'add_quantity' => $addQuantity,
                'after_quantity' => $beforeQuantity + $addQuantity,
                'action' => $beforeQuantity > 0 ? 'increment' : 'create',
            ];
        }

        return $rows;
    }

    public function applyStackWrites(array $rows): array
    {
        $results = [];

        foreach ($rows as $row) {
            try {
                InventoryStackItem::query()->updateOrCreate(
                    [
                        'user_id' => $row['user_id'],
                        'item_id' => $row['item_id'],
                    ],
                    [
                        'quantity' => $row['after_quantity'],
                    ]
                );
            } catch (Throwable $throwable) {
                throw new BusinessException(ErrorCode::INVENTORY_STACK_WRITE_FAILED, previous: $throwable);
            }

            $results[] = [
                'item_id' => (string) $row['item_id'],
                'before_quantity' => (int) $row['before_quantity'],
                'add_quantity' => (int) $row['add_quantity'],
                'after_quantity' => (int) $row['after_quantity'],
                'action' => (string) $row['action'],
            ];
        }

        return $results;
    }

    public function buildEquipmentInstancePayloads(
        int $userId,
        array $equipmentItems,
        array $equipmentTemplateMap,
        array $context = []
    ): array {
        $payloads = [];

        foreach ($equipmentItems as $equipmentItem) {
            $itemId = (string) $equipmentItem['item_id'];

            if (! isset($equipmentTemplateMap[$itemId])) {
                throw new BusinessException(ErrorCode::INVENTORY_EQUIPMENT_TEMPLATE_INVALID);
            }

            $payloads[] = [
                'user_id' => $userId,
                'item_id' => $itemId,
                'bind_type' => BindType::UNBOUND->value,
                'enhance_level' => 0,
                'durability' => 100,
                'max_durability' => 100,
                'is_locked' => false,
                'extra_attributes' => null,
            ];
        }

        return $payloads;
    }

    public function createEquipmentInstances(array $payloads): array
    {
        $results = [];

        foreach ($payloads as $payload) {
            try {
                $instance = InventoryEquipmentInstance::query()->create($payload);
                $instance->load(['equipmentTemplate.item']);
            } catch (Throwable $throwable) {
                throw new BusinessException(ErrorCode::INVENTORY_EQUIPMENT_INSTANCE_CREATE_FAILED, previous: $throwable);
            }

            $results[] = [
                'equipment_instance_result' => [
                    'equipment_instance_id' => (int) $instance->equipment_instance_id,
                    'item_id' => (string) $instance->item_id,
                    'bind_type' => (string) data_get($instance, 'bind_type.value', $instance->bind_type),
                    'enhance_level' => (int) $instance->enhance_level,
                    'durability' => (int) $instance->durability,
                    'max_durability' => (int) $instance->max_durability,
                ],
                'created_equipment_instance' => $this->equipmentQueryService->buildEquipmentInstanceSnapshot($instance),
            ];
        }

        return $results;
    }

    public function buildInventoryWriteResult(array $stackResults = [], array $instanceResults = [], array $context = []): array
    {
        try {
            $equipmentInstanceResults = array_map(
                static fn (array $result): array => $result['equipment_instance_result'],
                $instanceResults
            );
            $createdEquipmentInstances = array_map(
                static fn (array $result): array => $result['created_equipment_instance'],
                $instanceResults
            );

            return [
                'stack_results' => $stackResults,
                'equipment_instance_results' => $equipmentInstanceResults,
                'created_equipment_instances' => $createdEquipmentInstances,
                'written_item_ids' => array_values(array_unique(array_merge(
                    array_map(static fn (array $stackResult): string => $stackResult['item_id'], $stackResults),
                    array_map(static fn (array $equipmentResult): string => $equipmentResult['item_id'], $equipmentInstanceResults)
                ))),
                'summary' => [
                    'stack_write_count' => count($stackResults),
                    'equipment_instance_count' => count($equipmentInstanceResults),
                ],
            ];
        } catch (Throwable $throwable) {
            throw new BusinessException(ErrorCode::INVENTORY_RESULT_BUILD_FAILED, previous: $throwable);
        }
    }
}
