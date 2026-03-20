<?php

namespace App\Services\Equipment\Domain;

use App\Enums\Equipment\EquipmentSlot;
use App\Enums\Equipment\EquipmentSlotKey;
use App\Exceptions\BusinessException;
use App\Models\Character\Character;
use App\Models\Character\CharacterEquipmentSlot;
use App\Models\Equipment\Equipment;
use App\Models\Equipment\InventoryEquipmentInstance;
use App\Services\Character\Query\CharacterQueryService;
use App\Services\Equipment\Config\EquipmentTemplateConfigService;
use App\Services\Equipment\Query\EquipmentQueryService;
use App\Support\ErrorCode;
use Throwable;

class EquipmentWearService
{
    public function __construct(
        private readonly CharacterQueryService $characterQueryService,
        private readonly EquipmentQueryService $equipmentQueryService,
        private readonly EquipmentTemplateConfigService $equipmentTemplateConfigService,
    ) {
    }

    public function validateEquipRequest(
        int $userId,
        int $characterId,
        int $equipmentInstanceId,
        string $targetSlotKey
    ): void {
        $character = $this->characterQueryService->getOwnedCharacterById($userId, $characterId);
        $this->assertSlotKeyValid($targetSlotKey);

        $equipmentInstance = $this->equipmentQueryService->getEquipmentInstanceById($equipmentInstanceId);

        if ($equipmentInstance === null) {
            throw new BusinessException(ErrorCode::EQUIPMENT_INSTANCE_NOT_FOUND);
        }

        $this->assertInstanceOwner($userId, $equipmentInstance);

        if ($equipmentInstance->is_locked) {
            throw new BusinessException(ErrorCode::EQUIPMENT_INSTANCE_STATE_INVALID);
        }

        if ($this->equipmentQueryService->isEquipmentInstanceEquipped($equipmentInstanceId)) {
            throw new BusinessException(ErrorCode::EQUIPMENT_INSTANCE_ALREADY_EQUIPPED);
        }

        $equipmentTemplate = $this->equipmentTemplateConfigService->getEquipmentTemplateByItemId((string) $equipmentInstance->item_id);

        if ($equipmentTemplate === null) {
            throw new BusinessException(ErrorCode::EQUIPMENT_TEMPLATE_INVALID);
        }

        $this->assertSlotCompatible($equipmentTemplate, $targetSlotKey);
        $this->assertLevelRequirement($character, $equipmentTemplate);

        if ($targetSlotKey === EquipmentSlotKey::SUB_WEAPON->value) {
            $slotMap = $this->equipmentQueryService->getCharacterSlotMap($characterId);
            $mainWeaponTemplate = $slotMap[EquipmentSlotKey::MAIN_WEAPON->value]?->equippedInstance?->equipmentTemplate;
            $this->assertSubWeaponCompatible($mainWeaponTemplate, $equipmentTemplate);
        }
    }

    public function assertInstanceOwner(int $userId, InventoryEquipmentInstance $instance): void
    {
        if ((int) $instance->user_id !== $userId) {
            throw new BusinessException(ErrorCode::EQUIPMENT_INSTANCE_FORBIDDEN);
        }
    }

    public function assertSlotCompatible(Equipment $equipmentTemplate, string $targetSlotKey): void
    {
        $compatibleSlotKeys = match ($equipmentTemplate->equipment_slot) {
            EquipmentSlot::MAIN_WEAPON => [EquipmentSlotKey::MAIN_WEAPON->value],
            EquipmentSlot::SUB_WEAPON => [EquipmentSlotKey::SUB_WEAPON->value],
            EquipmentSlot::RING => [EquipmentSlotKey::RING_1->value, EquipmentSlotKey::RING_2->value],
            EquipmentSlot::BRACELET => [EquipmentSlotKey::BRACELET_1->value, EquipmentSlotKey::BRACELET_2->value],
            EquipmentSlot::ARMOR => [EquipmentSlotKey::ARMOR->value],
            EquipmentSlot::LEGGINGS => [EquipmentSlotKey::LEGGINGS->value],
            EquipmentSlot::GLOVES => [EquipmentSlotKey::GLOVES->value],
            EquipmentSlot::BOOTS => [EquipmentSlotKey::BOOTS->value],
            EquipmentSlot::CLOAK => [EquipmentSlotKey::CLOAK->value],
            EquipmentSlot::NECKLACE => [EquipmentSlotKey::NECKLACE->value],
        };

        if (! in_array($targetSlotKey, $compatibleSlotKeys, true)) {
            throw new BusinessException(ErrorCode::EQUIPMENT_SLOT_NOT_COMPATIBLE);
        }
    }

    public function assertLevelRequirement(Character $character, Equipment $equipmentTemplate): void
    {
        if ((int) $character->level < (int) $equipmentTemplate->level_required) {
            throw new BusinessException(ErrorCode::EQUIPMENT_LEVEL_REQUIREMENT_NOT_MET);
        }
    }

    public function assertSubWeaponCompatible(?Equipment $mainWeaponTemplate, Equipment $subWeaponTemplate): void
    {
        if ($mainWeaponTemplate === null || $mainWeaponTemplate->equipment_slot !== EquipmentSlot::MAIN_WEAPON) {
            throw new BusinessException(ErrorCode::EQUIPMENT_SUB_WEAPON_NOT_COMPATIBLE);
        }

        if ($mainWeaponTemplate->is_two_handed) {
            throw new BusinessException(ErrorCode::EQUIPMENT_SUB_WEAPON_NOT_COMPATIBLE);
        }

        $allowedSubWeaponCategories = $this->equipmentTemplateConfigService->getAllowedSubWeaponCategories(
            $mainWeaponTemplate->weapon_category
        );

        $targetSubWeaponCategory = $subWeaponTemplate->sub_weapon_category?->value;

        if (
            $targetSubWeaponCategory === null
            || ! in_array($targetSubWeaponCategory, $allowedSubWeaponCategories, true)
        ) {
            throw new BusinessException(ErrorCode::EQUIPMENT_SUB_WEAPON_NOT_COMPATIBLE);
        }
    }

    public function buildEquipPlan(array $context): array
    {
        /** @var Equipment $equipmentTemplate */
        $equipmentTemplate = $context['equipment_template'];
        /** @var InventoryEquipmentInstance $equipmentInstance */
        $equipmentInstance = $context['equipment_instance'];
        /** @var array<string, CharacterEquipmentSlot> $slotMap */
        $slotMap = $context['slot_map'];
        $targetSlotKey = $context['target_slot_key'];

        $targetSlotRow = $slotMap[$targetSlotKey] ?? null;

        if ($targetSlotRow === null) {
            throw new BusinessException(ErrorCode::EQUIPMENT_SLOT_INVALID);
        }

        $slotUpdates = [
            $targetSlotKey => (int) $equipmentInstance->equipment_instance_id,
        ];
        $changedSlots = [$targetSlotKey];
        $unequippedInstanceIds = [];
        $linkageSlotKeys = [];

        if ($targetSlotRow->equipped_instance_id !== null) {
            $unequippedInstanceIds[] = (int) $targetSlotRow->equipped_instance_id;
        }

        if ($targetSlotKey === EquipmentSlotKey::MAIN_WEAPON->value) {
            $subWeaponSlot = $slotMap[EquipmentSlotKey::SUB_WEAPON->value] ?? null;

            if ($equipmentTemplate->is_two_handed) {
                if ($subWeaponSlot !== null && $subWeaponSlot->equipped_instance_id !== null) {
                    $slotUpdates[EquipmentSlotKey::SUB_WEAPON->value] = null;
                    $changedSlots[] = EquipmentSlotKey::SUB_WEAPON->value;
                    $linkageSlotKeys[] = EquipmentSlotKey::SUB_WEAPON->value;
                    $unequippedInstanceIds[] = (int) $subWeaponSlot->equipped_instance_id;
                }
            } elseif ($subWeaponSlot !== null && $subWeaponSlot->equipped_instance_id !== null) {
                $subWeaponTemplate = $subWeaponSlot->equippedInstance?->equipmentTemplate;

                if ($subWeaponTemplate !== null) {
                    $this->assertSubWeaponCompatible($equipmentTemplate, $subWeaponTemplate);
                }
            }
        }

        return [
            'slot_updates' => $slotUpdates,
            'changed_slots' => $changedSlots,
            'unequipped_instance_ids' => array_values(array_unique($unequippedInstanceIds)),
            'linkage_slot_keys' => $linkageSlotKeys,
        ];
    }

    public function applyEquipPlan(array $plan, array $slotMap): array
    {
        try {
            foreach ($plan['slot_updates'] as $slotKey => $equippedInstanceId) {
                /** @var CharacterEquipmentSlot $slotRow */
                $slotRow = $slotMap[$slotKey];
                $slotRow->equipped_instance_id = $equippedInstanceId;
                $slotRow->save();
            }
        } catch (Throwable $throwable) {
            $errorCode = empty($plan['linkage_slot_keys'])
                ? ErrorCode::EQUIPMENT_CHANGE_FAILED
                : ErrorCode::EQUIPMENT_MAIN_SUB_LINKAGE_FAILED;

            throw new BusinessException($errorCode, previous: $throwable);
        }

        return $this->sortSlotKeys($plan['changed_slots']);
    }

    public function assertSlotKeyValid(string $targetSlotKey): void
    {
        if (! in_array($targetSlotKey, EquipmentSlotKey::orderedValues(), true)) {
            throw new BusinessException(ErrorCode::EQUIPMENT_SLOT_INVALID);
        }
    }

    public function sortSlotKeys(array $slotKeys): array
    {
        return array_values(array_intersect(
            EquipmentSlotKey::orderedValues(),
            array_values(array_unique($slotKeys))
        ));
    }
}
