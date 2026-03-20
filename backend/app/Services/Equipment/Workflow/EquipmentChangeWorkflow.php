<?php

namespace App\Services\Equipment\Workflow;

use App\Enums\Equipment\EquipmentSlotKey;
use App\Exceptions\BusinessException;
use App\Services\Character\Query\CharacterQueryService;
use App\Services\Equipment\Config\EquipmentTemplateConfigService;
use App\Services\Equipment\Domain\EquipmentChangeResultService;
use App\Services\Equipment\Domain\EquipmentUnequipService;
use App\Services\Equipment\Domain\EquipmentWearService;
use App\Services\Equipment\Query\EquipmentQueryService;
use App\Support\ErrorCode;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class EquipmentChangeWorkflow
{
    public function __construct(
        private readonly CharacterQueryService $characterQueryService,
        private readonly EquipmentQueryService $equipmentQueryService,
        private readonly EquipmentTemplateConfigService $equipmentTemplateConfigService,
        private readonly EquipmentWearService $equipmentWearService,
        private readonly EquipmentUnequipService $equipmentUnequipService,
        private readonly EquipmentChangeResultService $equipmentChangeResultService,
    ) {
    }

    public function equip(int $userId, int $characterId, int $equipmentInstanceId, string $targetSlotKey): array
    {
        $this->equipmentWearService->validateEquipRequest(
            $userId,
            $characterId,
            $equipmentInstanceId,
            $targetSlotKey
        );

        $character = $this->characterQueryService->getOwnedCharacterById($userId, $characterId);
        $equipmentInstance = $this->equipmentQueryService->getEquipmentInstanceById($equipmentInstanceId);

        if ($equipmentInstance === null) {
            throw new BusinessException(ErrorCode::EQUIPMENT_INSTANCE_NOT_FOUND);
        }

        $equipmentTemplate = $this->equipmentTemplateConfigService->getEquipmentTemplateByItemId((string) $equipmentInstance->item_id);

        if ($equipmentTemplate === null) {
            throw new BusinessException(ErrorCode::EQUIPMENT_TEMPLATE_INVALID);
        }

        try {
            return DB::transaction(function () use (
                $character,
                $equipmentInstance,
                $equipmentTemplate,
                $targetSlotKey
            ): array {
                $slotMap = $this->equipmentQueryService->getCharacterSlotMap((int) $character->character_id, true);

                $plan = $this->equipmentWearService->buildEquipPlan([
                    'character' => $character,
                    'equipment_instance' => $equipmentInstance,
                    'equipment_template' => $equipmentTemplate,
                    'target_slot_key' => $targetSlotKey,
                    'slot_map' => $slotMap,
                ]);

                $changedSlots = $this->equipmentWearService->applyEquipPlan($plan, $slotMap);

                return $this->equipmentChangeResultService->buildEquipmentChangeResult(
                    (int) $character->character_id,
                    $changedSlots,
                    [
                        'equipped_instance_id' => (int) $equipmentInstance->equipment_instance_id,
                        'unequipped_instance_ids' => $plan['unequipped_instance_ids'],
                    ]
                );
            });
        } catch (BusinessException $exception) {
            Log::warning('equipment_change_failed', [
                'user_id' => $userId,
                'character_id' => $characterId,
                'equipment_instance_id' => $equipmentInstanceId,
                'target_slot_key' => $targetSlotKey,
                'error_code' => $exception->getErrorCode(),
            ]);

            throw $exception;
        } catch (Throwable $throwable) {
            Log::error('equipment_change_failed', [
                'user_id' => $userId,
                'character_id' => $characterId,
                'equipment_instance_id' => $equipmentInstanceId,
                'target_slot_key' => $targetSlotKey,
                'exception' => $throwable,
            ]);

            throw new BusinessException(ErrorCode::EQUIPMENT_CHANGE_FAILED, previous: $throwable);
        }
    }

    public function unequip(int $userId, int $characterId, string $targetSlotKey): array
    {
        $this->equipmentUnequipService->validateUnequipRequest($userId, $characterId, $targetSlotKey);

        try {
            return DB::transaction(function () use ($characterId, $targetSlotKey): array {
                $slotMap = $this->equipmentQueryService->getCharacterSlotMap($characterId, true);
                $targetSlotRow = $slotMap[$targetSlotKey] ?? null;

                if ($targetSlotRow === null || $targetSlotRow->equipped_instance_id === null) {
                    throw new BusinessException(ErrorCode::EQUIPMENT_SLOT_EMPTY);
                }

                $changedSlots = [$targetSlotKey];
                $unequippedInstanceIds = [(int) $targetSlotRow->equipped_instance_id];

                $this->equipmentUnequipService->clearSlotInstance($targetSlotRow);

                if ($targetSlotKey === EquipmentSlotKey::MAIN_WEAPON->value) {
                    $subWeaponSlot = $slotMap[EquipmentSlotKey::SUB_WEAPON->value] ?? null;

                    if ($subWeaponSlot !== null && $subWeaponSlot->equipped_instance_id !== null) {
                        $changedSlots[] = EquipmentSlotKey::SUB_WEAPON->value;
                        $unequippedInstanceIds[] = (int) $subWeaponSlot->equipped_instance_id;
                        $this->equipmentUnequipService->clearSlotInstance($subWeaponSlot);
                    }
                }

                return $this->equipmentChangeResultService->buildEquipmentChangeResult(
                    $characterId,
                    $changedSlots,
                    [
                        'unequipped_instance_ids' => $unequippedInstanceIds,
                    ]
                );
            });
        } catch (BusinessException $exception) {
            Log::warning('equipment_change_failed', [
                'user_id' => $userId,
                'character_id' => $characterId,
                'target_slot_key' => $targetSlotKey,
                'error_code' => $exception->getErrorCode(),
            ]);

            throw $exception;
        } catch (Throwable $throwable) {
            Log::error('equipment_change_failed', [
                'user_id' => $userId,
                'character_id' => $characterId,
                'target_slot_key' => $targetSlotKey,
                'exception' => $throwable,
            ]);

            throw new BusinessException(ErrorCode::EQUIPMENT_CHANGE_FAILED, previous: $throwable);
        }
    }
}
