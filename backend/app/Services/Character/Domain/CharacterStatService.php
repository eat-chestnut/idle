<?php

namespace App\Services\Character\Domain;

use BackedEnum;

class CharacterStatService
{
    public function calculate(array|object $character, iterable $equipmentTemplates = []): array
    {
        $stats = [
            'strength' => (int) data_get($character, 'added_strength', 0),
            'mana_stat' => (int) data_get($character, 'added_mana', 0),
            'constitution' => (int) data_get($character, 'added_constitution', 0),
            'dexterity' => (int) data_get($character, 'added_dexterity', 0),
            'attack' => 0,
            'physical_defense' => 0,
            'magic_defense' => 0,
            'hp' => 0,
            'mana' => 0,
            'attack_speed' => 0,
            'crit_rate' => 0,
            'spell_power' => 0,
        ];

        foreach ($equipmentTemplates as $equipmentTemplate) {
            $stats['attack'] += (int) data_get($equipmentTemplate, 'attack', 0);
            $stats['physical_defense'] += (int) data_get($equipmentTemplate, 'physical_defense', 0);
            $stats['magic_defense'] += (int) data_get($equipmentTemplate, 'magic_defense', 0);
            $stats['hp'] += (int) data_get($equipmentTemplate, 'hp', 0);
            $stats['mana'] += (int) data_get($equipmentTemplate, 'mana', 0);
            $stats['attack_speed'] += (int) data_get($equipmentTemplate, 'attack_speed', 0);
            $stats['crit_rate'] += (int) data_get($equipmentTemplate, 'crit_rate', 0);
            $stats['spell_power'] += (int) data_get($equipmentTemplate, 'spell_power', 0);
        }

        return array_map(
            static fn (mixed $value): mixed => $value instanceof BackedEnum ? $value->value : $value,
            $stats
        );
    }
}
