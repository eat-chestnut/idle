<?php

namespace App\Services\Battle\Domain;

use App\Enums\Monster\MonsterRole;
use App\Exceptions\BusinessException;
use App\Models\Character\Character;
use App\Models\Equipment\InventoryEquipmentInstance;
use App\Models\Stage\StageDifficulty;
use App\Models\Stage\StageMonsterBinding;
use App\Services\Character\Domain\CharacterStatService;
use App\Services\Character\Query\CharacterQueryService;
use App\Services\Equipment\Config\EquipmentTemplateConfigService;
use App\Services\Equipment\Query\EquipmentQueryService;
use App\Services\Stage\Config\StageConfigService;
use App\Services\Stage\Query\StageMonsterQueryService;
use App\Support\ErrorCode;
use Throwable;

class BattlePrepareService
{
    public function __construct(
        private readonly StageConfigService $stageConfigService,
        private readonly StageMonsterQueryService $stageMonsterQueryService,
        private readonly CharacterQueryService $characterQueryService,
        private readonly EquipmentQueryService $equipmentQueryService,
        private readonly EquipmentTemplateConfigService $equipmentTemplateConfigService,
        private readonly CharacterStatService $characterStatService,
    ) {
    }

    public function prepareBattle(
        int $userId,
        int $characterId,
        string $stageDifficultyId,
        string $battleContextId
    ): array
    {
        $stageDifficulty = $this->getBattleStageDifficulty($stageDifficultyId);
        $character = $this->getBattleCharacter($userId, $characterId);
        $bindings = $this->getBattleMonsterBindings($stageDifficultyId);
        $monsterMap = $this->getBattleMonsterMap($bindings);

        $slotMap = $this->equipmentQueryService->getCharacterSlotMap($characterId);
        $this->assertEquippedInstancesResolvable($slotMap);
        $equippedInstances = $this->equipmentQueryService->getEquippedInstancesByCharacter($slotMap);
        $equipmentTemplateMap = $this->getEquipmentTemplateMap($equippedInstances);
        $characterStats = $this->calculateCharacterStats($character, $equipmentTemplateMap);
        $monsterList = $this->buildBattleMonsterList($bindings, $monsterMap);
        $characterContext = $this->buildBattleCharacterContext(
            $character,
            $slotMap,
            $equippedInstances,
            $equipmentTemplateMap,
            $characterStats
        );

        return $this->buildBattlePreparePayload($battleContextId, $stageDifficulty, $monsterList, $characterContext);
    }

    private function getBattleStageDifficulty(string $stageDifficultyId): StageDifficulty
    {
        $stageDifficulty = $this->stageConfigService->getEnabledStageDifficultyById($stageDifficultyId);

        if ($stageDifficulty === null) {
            throw new BusinessException(ErrorCode::BATTLE_STAGE_DIFFICULTY_INVALID);
        }

        return $stageDifficulty;
    }

    private function getBattleCharacter(int $userId, int $characterId): Character
    {
        try {
            $character = $this->characterQueryService->getOwnedCharacterById($userId, $characterId);
        } catch (BusinessException $exception) {
            throw new BusinessException(ErrorCode::BATTLE_CHARACTER_INVALID, previous: $exception);
        }

        if (! $character->is_active) {
            throw new BusinessException(ErrorCode::BATTLE_CHARACTER_INVALID);
        }

        return $character;
    }

    private function getBattleMonsterBindings(string $stageDifficultyId): array
    {
        $bindings = $this->stageMonsterQueryService->getStageMonsterBindings($stageDifficultyId)->all();

        if ($bindings === []) {
            throw new BusinessException(ErrorCode::BATTLE_MONSTER_CONFIG_INVALID);
        }

        return $bindings;
    }

    private function getBattleMonsterMap(array $bindings): array
    {
        $monsterIds = array_map(
            static fn (StageMonsterBinding $binding): string => (string) $binding->monster_id,
            $bindings
        );

        $monsterMap = $this->stageMonsterQueryService->getMonsterMapByIds($monsterIds);

        foreach ($monsterIds as $monsterId) {
            if (! array_key_exists($monsterId, $monsterMap)) {
                throw new BusinessException(ErrorCode::BATTLE_MONSTER_CONFIG_INVALID);
            }
        }

        return $monsterMap;
    }

    private function getEquipmentTemplateMap(array $equippedInstances): array
    {
        $itemIds = array_values(array_unique(array_map(
            static fn (InventoryEquipmentInstance $instance): string => (string) $instance->item_id,
            $equippedInstances
        )));

        $templateMap = $this->equipmentTemplateConfigService->getEquipmentTemplateMapByItemIds($itemIds);

        foreach ($itemIds as $itemId) {
            if (! array_key_exists($itemId, $templateMap)) {
                throw new BusinessException(ErrorCode::BATTLE_CHARACTER_STATS_CALCULATE_FAILED);
            }
        }

        return $templateMap;
    }

    private function assertEquippedInstancesResolvable(array $slotMap): void
    {
        foreach ($slotMap as $slotRow) {
            if ($slotRow->equipped_instance_id !== null && $slotRow->equippedInstance === null) {
                throw new BusinessException(ErrorCode::BATTLE_CHARACTER_INVALID);
            }
        }
    }

    private function calculateCharacterStats(Character $character, array $equipmentTemplateMap): array
    {
        try {
            return $this->characterStatService->calculate($character, array_values($equipmentTemplateMap));
        } catch (Throwable $throwable) {
            throw new BusinessException(ErrorCode::BATTLE_CHARACTER_STATS_CALCULATE_FAILED, previous: $throwable);
        }
    }

    private function buildBattleMonsterList(array $bindings, array $monsterMap): array
    {
        return array_map(function (StageMonsterBinding $binding) use ($monsterMap): array {
            $monster = $monsterMap[(string) $binding->monster_id];

            return [
                'monster_id' => (string) $monster->monster_id,
                'monster_name' => (string) $monster->monster_name,
                'monster_role' => $this->normalizeMonsterRole($binding->monster_role),
                'wave_no' => (int) $binding->wave_no,
                'sort_order' => (int) $binding->sort_order,
                'base_hp' => (int) $monster->hp,
                'base_attack' => (int) $monster->attack,
                'base_physical_defense' => (int) $monster->physical_defense,
                'base_magic_defense' => (int) $monster->magic_defense,
                'attack_interval' => null,
                'attack_range' => null,
                'move_speed' => null,
            ];
        }, $bindings);
    }

    private function buildBattleCharacterContext(
        Character $character,
        array $slotMap,
        array $equippedInstances,
        array $equipmentTemplateMap,
        array $characterStats
    ): array {
        return [
            'character' => [
                'character_id' => (int) $character->character_id,
                'character_name' => (string) $character->character_name,
                'class_id' => (string) $character->class_id,
                'class_name' => (string) data_get($character, 'gameClass.class_name', ''),
                'level' => (int) $character->level,
            ],
            'character_stats' => $characterStats,
            'slot_snapshot' => $this->equipmentQueryService->buildOrderedSlotSnapshotFromSlotMap($slotMap),
            'equipped_instances' => array_map(
                fn (InventoryEquipmentInstance $instance): array => $this->equipmentQueryService->buildEquipmentInstanceSnapshot($instance),
                array_values($equippedInstances)
            ),
            'equipment_template_map' => $equipmentTemplateMap,
        ];
    }

    private function buildBattlePreparePayload(
        string $battleContextId,
        StageDifficulty $stageDifficulty,
        array $monsterList,
        array $characterContext
    ): array {
        if ($battleContextId === '') {
            throw new BusinessException(ErrorCode::BATTLE_CONTEXT_BUILD_FAILED);
        }

        return [
            'battle_context_id' => $battleContextId,
            'stage_difficulty' => [
                'stage_difficulty_id' => (string) $stageDifficulty->stage_difficulty_id,
                'difficulty_key' => (string) data_get($stageDifficulty, 'difficulty_key.value', data_get($stageDifficulty, 'difficulty_key', '')),
                'difficulty_name' => (string) $stageDifficulty->difficulty_name,
                'recommended_power' => (int) $stageDifficulty->recommended_power,
            ],
            'character' => $characterContext['character'],
            'character_stats' => $characterContext['character_stats'],
            'slot_snapshot' => $characterContext['slot_snapshot'],
            'monster_list' => $monsterList,
        ];
    }

    private function normalizeMonsterRole(mixed $monsterRole): string
    {
        if ($monsterRole instanceof MonsterRole) {
            return $monsterRole->value;
        }

        return (string) $monsterRole;
    }
}
