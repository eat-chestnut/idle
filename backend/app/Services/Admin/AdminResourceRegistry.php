<?php

namespace App\Services\Admin;

use App\Enums\Battle\BattleContextStatus;
use App\Enums\Common\Rarity;
use App\Enums\Drop\DropRollType;
use App\Enums\Drop\DropSourceType;
use App\Enums\Equipment\BindType;
use App\Enums\Equipment\EquipmentSlot;
use App\Enums\Equipment\EquipmentSlotKey;
use App\Enums\Equipment\SubWeaponCategory;
use App\Enums\Equipment\WeaponCategory;
use App\Enums\Item\ItemType;
use App\Enums\Monster\MonsterRole;
use App\Enums\Reward\GrantStatus;
use App\Enums\Reward\RewardSourceType;
use App\Enums\Stage\DifficultyKey;
use App\Models\Battle\BattleContext;
use App\Models\Character\Character;
use App\Models\Character\CharacterEquipmentSlot;
use App\Models\Drop\DropGroup;
use App\Models\Drop\DropGroupBinding;
use App\Models\Drop\DropGroupItem;
use App\Models\Equipment\Equipment;
use App\Models\Equipment\InventoryEquipmentInstance;
use App\Models\GameClass\GameClass;
use App\Models\Inventory\InventoryStackItem;
use App\Models\Item\Item;
use App\Models\Monster\Monster;
use App\Models\Reward\RewardGroup;
use App\Models\Reward\RewardGroupBinding;
use App\Models\Reward\RewardGroupItem;
use App\Models\Reward\UserRewardGrant;
use App\Models\Reward\UserRewardGrantItem;
use App\Models\Stage\Chapter;
use App\Models\Stage\ChapterStage;
use App\Models\Stage\StageDifficulty;
use App\Models\Stage\StageMonsterBinding;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Enum;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class AdminResourceRegistry
{
    public function get(string $resource): array
    {
        $definition = $this->resources()[$resource] ?? null;

        if ($definition === null) {
            throw new NotFoundHttpException();
        }

        return $definition + [
            'resource' => $resource,
        ];
    }

    public function navigation(): array
    {
        $navigation = [];

        foreach ($this->resources() as $resource => $definition) {
            $section = $definition['section'];
            $navigation[$section][] = [
                'resource' => $resource,
                'title' => $definition['title'],
                'mode' => $definition['mode'],
                'nav_key' => $resource,
                'url' => route('admin.resources.index', ['resource' => $resource]),
            ];
        }

        $navigation['运维工具'][] = [
            'resource' => null,
            'title' => '引用检查 / 补发 / 修复',
            'mode' => 'tool',
            'nav_key' => 'tools',
            'url' => route('admin.tools.index'),
        ];

        return $navigation;
    }

    public function configResourceOptions(): array
    {
        $options = [];

        foreach ($this->resources() as $resource => $definition) {
            if (($definition['mode'] ?? null) !== 'config') {
                continue;
            }

            $options[$resource] = (string) $definition['title'];
        }

        return $options;
    }

    private function resources(): array
    {
        return [
            ...$this->configResources(),
            ...$this->queryResources(),
        ];
    }

    private function configResources(): array
    {
        return [
            'classes' => [
                'title' => '职业管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => GameClass::class,
                'primary_key' => 'class_id',
                'query' => fn (): Builder => GameClass::query()->orderBy('sort_order')->orderBy('class_id'),
                'filters' => [
                    ['name' => 'class_id', 'label' => '职业 ID', 'type' => 'text'],
                    ['name' => 'class_name', 'label' => '职业名称', 'type' => 'text'],
                    ['name' => 'is_enabled', 'label' => '启用状态', 'type' => 'select', 'options' => fn (): array => $this->booleanOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyLikeFilter($query, 'class_id', $filters);
                    $this->applyLikeFilter($query, 'class_name', $filters);
                    $this->applyBooleanFilter($query, 'is_enabled', $filters);
                },
                'columns' => [
                    ['label' => '职业 ID', 'value' => fn (GameClass $row): string => (string) $row->class_id],
                    ['label' => '职业名称', 'value' => fn (GameClass $row): string => (string) $row->class_name],
                    ['label' => '启用', 'value' => fn (GameClass $row): string => $this->boolLabel((bool) $row->is_enabled)],
                    ['label' => '排序', 'value' => fn (GameClass $row): int => (int) $row->sort_order],
                    ['label' => '更新时间', 'value' => fn (GameClass $row): string => (string) optional($row->updated_at)->format('Y-m-d H:i:s')],
                ],
                'fields' => [
                    ['name' => 'class_id', 'label' => '职业 ID', 'type' => 'text', 'readonly_on_edit' => true],
                    ['name' => 'class_name', 'label' => '职业名称', 'type' => 'text'],
                    ['name' => 'is_enabled', 'label' => '启用', 'type' => 'checkbox'],
                    ['name' => 'sort_order', 'label' => '排序', 'type' => 'number', 'min' => 0],
                ],
                'rules' => fn (?Model $record): array => [
                    'class_id' => ['required', 'string', Rule::unique('classes', 'class_id')->ignore($record?->class_id, 'class_id')],
                    'class_name' => ['required', 'string'],
                    'is_enabled' => ['boolean'],
                    'sort_order' => ['required', 'integer', 'min:0'],
                ],
                'attributes' => [
                    'class_id' => '职业 ID',
                    'class_name' => '职业名称',
                    'is_enabled' => '启用状态',
                    'sort_order' => '排序',
                ],
                'payload' => fn (array $input): array => [
                    'class_id' => (string) $input['class_id'],
                    'class_name' => (string) $input['class_name'],
                    'is_enabled' => (bool) $input['is_enabled'],
                    'sort_order' => (int) $input['sort_order'],
                ],
            ],
            'items' => [
                'title' => '物品管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => Item::class,
                'primary_key' => 'item_id',
                'query' => fn (): Builder => Item::query()->orderBy('sort_order')->orderBy('item_id'),
                'filters' => [
                    ['name' => 'item_id', 'label' => '物品 ID', 'type' => 'text'],
                    ['name' => 'item_name', 'label' => '物品名称', 'type' => 'text'],
                    ['name' => 'item_type', 'label' => '物品类型', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(ItemType::class, true)],
                    ['name' => 'rarity', 'label' => '稀有度', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(Rarity::class, true)],
                    ['name' => 'is_enabled', 'label' => '启用状态', 'type' => 'select', 'options' => fn (): array => $this->booleanOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyLikeFilter($query, 'item_id', $filters);
                    $this->applyLikeFilter($query, 'item_name', $filters);
                    $this->applyExactFilter($query, 'item_type', $filters);
                    $this->applyExactFilter($query, 'rarity', $filters);
                    $this->applyBooleanFilter($query, 'is_enabled', $filters);
                },
                'columns' => [
                    ['label' => '物品 ID', 'value' => fn (Item $row): string => (string) $row->item_id],
                    ['label' => '物品名称', 'value' => fn (Item $row): string => (string) $row->item_name],
                    ['label' => '类型', 'value' => fn (Item $row): string => (string) data_get($row, 'item_type.value', $row->item_type)],
                    ['label' => '稀有度', 'value' => fn (Item $row): string => (string) data_get($row, 'rarity.value', $row->rarity)],
                    ['label' => '启用', 'value' => fn (Item $row): string => $this->boolLabel((bool) $row->is_enabled)],
                    ['label' => '排序', 'value' => fn (Item $row): int => (int) $row->sort_order],
                ],
                'fields' => [
                    ['name' => 'item_id', 'label' => '物品 ID', 'type' => 'text', 'readonly_on_edit' => true],
                    ['name' => 'item_name', 'label' => '物品名称', 'type' => 'text'],
                    ['name' => 'item_type', 'label' => '物品类型', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(ItemType::class)],
                    ['name' => 'rarity', 'label' => '稀有度', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(Rarity::class)],
                    ['name' => 'icon', 'label' => '图标', 'type' => 'text'],
                    ['name' => 'is_enabled', 'label' => '启用', 'type' => 'checkbox'],
                    ['name' => 'sort_order', 'label' => '排序', 'type' => 'number', 'min' => 0],
                ],
                'rules' => fn (?Model $record): array => [
                    'item_id' => ['required', 'string', Rule::unique('items', 'item_id')->ignore($record?->item_id, 'item_id')],
                    'item_name' => ['required', 'string'],
                    'item_type' => ['required', new Enum(ItemType::class)],
                    'rarity' => ['required', new Enum(Rarity::class)],
                    'icon' => ['nullable', 'string'],
                    'is_enabled' => ['boolean'],
                    'sort_order' => ['required', 'integer', 'min:0'],
                ],
                'attributes' => [
                    'item_id' => '物品 ID',
                    'item_name' => '物品名称',
                    'item_type' => '物品类型',
                    'rarity' => '稀有度',
                    'icon' => '图标',
                    'is_enabled' => '启用状态',
                    'sort_order' => '排序',
                ],
                'payload' => fn (array $input): array => [
                    'item_id' => (string) $input['item_id'],
                    'item_name' => (string) $input['item_name'],
                    'item_type' => (string) $input['item_type'],
                    'rarity' => (string) $input['rarity'],
                    'icon' => $this->nullableString($input['icon'] ?? null),
                    'is_enabled' => (bool) $input['is_enabled'],
                    'sort_order' => (int) $input['sort_order'],
                ],
            ],
            'equipment-templates' => [
                'title' => '装备模板管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => Equipment::class,
                'primary_key' => 'item_id',
                'query' => fn (): Builder => Equipment::query()->with('item')->orderBy('sort_order')->orderBy('item_id'),
                'filters' => [
                    ['name' => 'item_id', 'label' => '装备物品 ID', 'type' => 'text'],
                    ['name' => 'equipment_slot', 'label' => '装备位', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(EquipmentSlot::class, true)],
                    ['name' => 'weapon_category', 'label' => '武器分类', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(WeaponCategory::class, true)],
                    ['name' => 'sub_weapon_category', 'label' => '副武器分类', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(SubWeaponCategory::class, true)],
                    ['name' => 'is_enabled', 'label' => '启用状态', 'type' => 'select', 'options' => fn (): array => $this->booleanOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyLikeFilter($query, 'item_id', $filters);
                    $this->applyExactFilter($query, 'equipment_slot', $filters);
                    $this->applyExactFilter($query, 'weapon_category', $filters);
                    $this->applyExactFilter($query, 'sub_weapon_category', $filters);
                    $this->applyBooleanFilter($query, 'is_enabled', $filters);
                },
                'columns' => [
                    ['label' => '装备物品 ID', 'value' => fn (Equipment $row): string => (string) $row->item_id],
                    ['label' => '物品名称', 'value' => fn (Equipment $row): string => (string) data_get($row, 'item.item_name', '')],
                    ['label' => '装备位', 'value' => fn (Equipment $row): string => (string) data_get($row, 'equipment_slot.value', $row->equipment_slot)],
                    ['label' => '武器分类', 'value' => fn (Equipment $row): string => (string) data_get($row, 'weapon_category.value', data_get($row, 'weapon_category', ''))],
                    ['label' => '副武器分类', 'value' => fn (Equipment $row): string => (string) data_get($row, 'sub_weapon_category.value', data_get($row, 'sub_weapon_category', ''))],
                    ['label' => '双手', 'value' => fn (Equipment $row): string => $this->boolLabel((bool) $row->is_two_handed)],
                    ['label' => '启用', 'value' => fn (Equipment $row): string => $this->boolLabel((bool) $row->is_enabled)],
                ],
                'fields' => [
                    ['name' => 'item_id', 'label' => '物品 ID', 'type' => 'select', 'options' => fn (): array => $this->equipmentItemOptions(), 'readonly_on_edit' => true],
                    ['name' => 'equipment_slot', 'label' => '装备位', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(EquipmentSlot::class)],
                    ['name' => 'rarity', 'label' => '稀有度', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(Rarity::class)],
                    ['name' => 'level_required', 'label' => '等级需求', 'type' => 'number', 'min' => 1],
                    ['name' => 'weapon_category', 'label' => '武器分类', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(WeaponCategory::class, true, '未设置')],
                    ['name' => 'sub_weapon_category', 'label' => '副武器分类', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(SubWeaponCategory::class, true, '未设置')],
                    ['name' => 'is_two_handed', 'label' => '双手武器', 'type' => 'checkbox'],
                    ['name' => 'attack', 'label' => '攻击', 'type' => 'number', 'min' => 0],
                    ['name' => 'physical_defense', 'label' => '物防', 'type' => 'number', 'min' => 0],
                    ['name' => 'magic_defense', 'label' => '法防', 'type' => 'number', 'min' => 0],
                    ['name' => 'hp', 'label' => '生命', 'type' => 'number', 'min' => 0],
                    ['name' => 'mana', 'label' => '法力', 'type' => 'number', 'min' => 0],
                    ['name' => 'attack_speed', 'label' => '攻速', 'type' => 'number', 'min' => 0],
                    ['name' => 'crit_rate', 'label' => '暴击率', 'type' => 'number', 'min' => 0],
                    ['name' => 'spell_power', 'label' => '法术强度', 'type' => 'number', 'min' => 0],
                    ['name' => 'is_enabled', 'label' => '启用', 'type' => 'checkbox'],
                    ['name' => 'sort_order', 'label' => '排序', 'type' => 'number', 'min' => 0],
                ],
                'rules' => fn (?Model $record): array => [
                    'item_id' => ['required', 'string', Rule::exists('items', 'item_id'), Rule::unique('equipments', 'item_id')->ignore($record?->item_id, 'item_id')],
                    'equipment_slot' => ['required', new Enum(EquipmentSlot::class)],
                    'rarity' => ['required', new Enum(Rarity::class)],
                    'level_required' => ['required', 'integer', 'min:1'],
                    'weapon_category' => ['nullable', new Enum(WeaponCategory::class)],
                    'sub_weapon_category' => ['nullable', new Enum(SubWeaponCategory::class)],
                    'is_two_handed' => ['boolean'],
                    'attack' => ['required', 'integer', 'min:0'],
                    'physical_defense' => ['required', 'integer', 'min:0'],
                    'magic_defense' => ['required', 'integer', 'min:0'],
                    'hp' => ['required', 'integer', 'min:0'],
                    'mana' => ['required', 'integer', 'min:0'],
                    'attack_speed' => ['required', 'integer', 'min:0'],
                    'crit_rate' => ['required', 'integer', 'min:0'],
                    'spell_power' => ['required', 'integer', 'min:0'],
                    'is_enabled' => ['boolean'],
                    'sort_order' => ['required', 'integer', 'min:0'],
                ],
                'after_validation' => function (Validator $validator, ?Model $record, array $input): void {
                    $validator->after(function (Validator $validator) use ($input): void {
                        $item = Item::query()->find($input['item_id']);

                        if ($item === null || data_get($item, 'item_type.value', $item->item_type) !== ItemType::EQUIPMENT->value) {
                            $validator->errors()->add('item_id', '所选物品必须是装备类型');
                        }

                        $equipmentSlot = $input['equipment_slot'];
                        $weaponCategory = $this->nullableString($input['weapon_category'] ?? null);
                        $subWeaponCategory = $this->nullableString($input['sub_weapon_category'] ?? null);
                        $isTwoHanded = (bool) ($input['is_two_handed'] ?? false);

                        if ($equipmentSlot !== EquipmentSlot::MAIN_WEAPON->value && $weaponCategory !== null) {
                            $validator->errors()->add('weapon_category', '只有主武器可以设置武器分类');
                        }

                        if ($equipmentSlot !== EquipmentSlot::SUB_WEAPON->value && $subWeaponCategory !== null) {
                            $validator->errors()->add('sub_weapon_category', '只有副武器可以设置副武器分类');
                        }

                        if ($equipmentSlot === EquipmentSlot::SUB_WEAPON->value && $isTwoHanded) {
                            $validator->errors()->add('is_two_handed', '副武器不能配置为双手武器');
                        }
                    });
                },
                'attributes' => [
                    'item_id' => '物品 ID',
                    'equipment_slot' => '装备位',
                    'rarity' => '稀有度',
                    'level_required' => '等级需求',
                    'weapon_category' => '武器分类',
                    'sub_weapon_category' => '副武器分类',
                    'is_two_handed' => '双手武器',
                    'sort_order' => '排序',
                ],
                'payload' => fn (array $input): array => [
                    'item_id' => (string) $input['item_id'],
                    'equipment_slot' => (string) $input['equipment_slot'],
                    'rarity' => (string) $input['rarity'],
                    'level_required' => (int) $input['level_required'],
                    'weapon_category' => $this->nullableString($input['weapon_category'] ?? null),
                    'sub_weapon_category' => $this->nullableString($input['sub_weapon_category'] ?? null),
                    'is_two_handed' => (bool) $input['is_two_handed'],
                    'attack' => (int) $input['attack'],
                    'physical_defense' => (int) $input['physical_defense'],
                    'magic_defense' => (int) $input['magic_defense'],
                    'hp' => (int) $input['hp'],
                    'mana' => (int) $input['mana'],
                    'attack_speed' => (int) $input['attack_speed'],
                    'crit_rate' => (int) $input['crit_rate'],
                    'spell_power' => (int) $input['spell_power'],
                    'is_enabled' => (bool) $input['is_enabled'],
                    'sort_order' => (int) $input['sort_order'],
                ],
            ],
            'chapters' => [
                'title' => '章节管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => Chapter::class,
                'primary_key' => 'chapter_id',
                'query' => fn (): Builder => Chapter::query()->orderBy('sort_order')->orderBy('chapter_id'),
                'filters' => [
                    ['name' => 'chapter_id', 'label' => '章节 ID', 'type' => 'text'],
                    ['name' => 'chapter_name', 'label' => '章节名称', 'type' => 'text'],
                    ['name' => 'is_enabled', 'label' => '启用状态', 'type' => 'select', 'options' => fn (): array => $this->booleanOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyLikeFilter($query, 'chapter_id', $filters);
                    $this->applyLikeFilter($query, 'chapter_name', $filters);
                    $this->applyBooleanFilter($query, 'is_enabled', $filters);
                },
                'columns' => [
                    ['label' => '章节 ID', 'value' => fn (Chapter $row): string => (string) $row->chapter_id],
                    ['label' => '章节名称', 'value' => fn (Chapter $row): string => (string) $row->chapter_name],
                    ['label' => '启用', 'value' => fn (Chapter $row): string => $this->boolLabel((bool) $row->is_enabled)],
                    ['label' => '排序', 'value' => fn (Chapter $row): int => (int) $row->sort_order],
                ],
                'fields' => [
                    ['name' => 'chapter_id', 'label' => '章节 ID', 'type' => 'text', 'readonly_on_edit' => true],
                    ['name' => 'chapter_name', 'label' => '章节名称', 'type' => 'text'],
                    ['name' => 'is_enabled', 'label' => '启用', 'type' => 'checkbox'],
                    ['name' => 'sort_order', 'label' => '排序', 'type' => 'number', 'min' => 0],
                ],
                'rules' => fn (?Model $record): array => [
                    'chapter_id' => ['required', 'string', Rule::unique('chapters', 'chapter_id')->ignore($record?->chapter_id, 'chapter_id')],
                    'chapter_name' => ['required', 'string'],
                    'is_enabled' => ['boolean'],
                    'sort_order' => ['required', 'integer', 'min:0'],
                ],
                'attributes' => [
                    'chapter_id' => '章节 ID',
                    'chapter_name' => '章节名称',
                    'is_enabled' => '启用状态',
                    'sort_order' => '排序',
                ],
                'payload' => fn (array $input): array => [
                    'chapter_id' => (string) $input['chapter_id'],
                    'chapter_name' => (string) $input['chapter_name'],
                    'is_enabled' => (bool) $input['is_enabled'],
                    'sort_order' => (int) $input['sort_order'],
                ],
            ],
            'stages' => [
                'title' => '关卡管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => ChapterStage::class,
                'primary_key' => 'stage_id',
                'query' => fn (): Builder => ChapterStage::query()->with('chapter')->orderBy('chapter_id')->orderBy('stage_order')->orderBy('stage_id'),
                'filters' => [
                    ['name' => 'stage_id', 'label' => '关卡 ID', 'type' => 'text'],
                    ['name' => 'chapter_id', 'label' => '章节 ID', 'type' => 'select', 'options' => fn (): array => $this->chapterOptions(true)],
                    ['name' => 'stage_name', 'label' => '关卡名称', 'type' => 'text'],
                    ['name' => 'is_enabled', 'label' => '启用状态', 'type' => 'select', 'options' => fn (): array => $this->booleanOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyLikeFilter($query, 'stage_id', $filters);
                    $this->applyExactFilter($query, 'chapter_id', $filters);
                    $this->applyLikeFilter($query, 'stage_name', $filters);
                    $this->applyBooleanFilter($query, 'is_enabled', $filters);
                },
                'columns' => [
                    ['label' => '关卡 ID', 'value' => fn (ChapterStage $row): string => (string) $row->stage_id],
                    ['label' => '关卡名称', 'value' => fn (ChapterStage $row): string => (string) $row->stage_name],
                    ['label' => '章节', 'value' => fn (ChapterStage $row): string => sprintf('%s / %s', $row->chapter_id, data_get($row, 'chapter.chapter_name', ''))],
                    ['label' => '关卡顺序', 'value' => fn (ChapterStage $row): int => (int) $row->stage_order],
                    ['label' => '启用', 'value' => fn (ChapterStage $row): string => $this->boolLabel((bool) $row->is_enabled)],
                ],
                'fields' => [
                    ['name' => 'stage_id', 'label' => '关卡 ID', 'type' => 'text', 'readonly_on_edit' => true],
                    ['name' => 'chapter_id', 'label' => '章节 ID', 'type' => 'select', 'options' => fn (): array => $this->chapterOptions()],
                    ['name' => 'stage_name', 'label' => '关卡名称', 'type' => 'text'],
                    ['name' => 'stage_order', 'label' => '关卡顺序', 'type' => 'number', 'min' => 0],
                    ['name' => 'is_enabled', 'label' => '启用', 'type' => 'checkbox'],
                ],
                'rules' => fn (?Model $record, array $input): array => [
                    'stage_id' => ['required', 'string', Rule::unique('chapter_stages', 'stage_id')->ignore($record?->stage_id, 'stage_id')],
                    'chapter_id' => ['required', 'string', Rule::exists('chapters', 'chapter_id')],
                    'stage_name' => ['required', 'string'],
                    'stage_order' => [
                        'required',
                        'integer',
                        'min:0',
                        Rule::unique('chapter_stages', 'stage_order')
                            ->where(fn ($query) => $query->where('chapter_id', $input['chapter_id'] ?? null))
                            ->ignore($record?->stage_id, 'stage_id'),
                    ],
                    'is_enabled' => ['boolean'],
                ],
                'attributes' => [
                    'stage_id' => '关卡 ID',
                    'chapter_id' => '章节 ID',
                    'stage_name' => '关卡名称',
                    'stage_order' => '关卡顺序',
                    'is_enabled' => '启用状态',
                ],
                'payload' => fn (array $input): array => [
                    'stage_id' => (string) $input['stage_id'],
                    'chapter_id' => (string) $input['chapter_id'],
                    'stage_name' => (string) $input['stage_name'],
                    'stage_order' => (int) $input['stage_order'],
                    'is_enabled' => (bool) $input['is_enabled'],
                ],
            ],
            'stage-difficulties' => [
                'title' => '关卡难度管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => StageDifficulty::class,
                'primary_key' => 'stage_difficulty_id',
                'query' => fn (): Builder => StageDifficulty::query()->with('stage')->orderBy('stage_id')->orderBy('difficulty_order')->orderBy('stage_difficulty_id'),
                'filters' => [
                    ['name' => 'stage_difficulty_id', 'label' => '难度 ID', 'type' => 'text'],
                    ['name' => 'stage_id', 'label' => '关卡 ID', 'type' => 'select', 'options' => fn (): array => $this->stageOptions(true)],
                    ['name' => 'difficulty_key', 'label' => '难度 Key', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(DifficultyKey::class, true)],
                    ['name' => 'is_enabled', 'label' => '启用状态', 'type' => 'select', 'options' => fn (): array => $this->booleanOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyLikeFilter($query, 'stage_difficulty_id', $filters);
                    $this->applyExactFilter($query, 'stage_id', $filters);
                    $this->applyExactFilter($query, 'difficulty_key', $filters);
                    $this->applyBooleanFilter($query, 'is_enabled', $filters);
                },
                'columns' => [
                    ['label' => '难度 ID', 'value' => fn (StageDifficulty $row): string => (string) $row->stage_difficulty_id],
                    ['label' => '关卡', 'value' => fn (StageDifficulty $row): string => sprintf('%s / %s', $row->stage_id, data_get($row, 'stage.stage_name', ''))],
                    ['label' => '难度 Key', 'value' => fn (StageDifficulty $row): string => (string) data_get($row, 'difficulty_key.value', $row->difficulty_key)],
                    ['label' => '难度名称', 'value' => fn (StageDifficulty $row): string => (string) $row->difficulty_name],
                    ['label' => '推荐战力', 'value' => fn (StageDifficulty $row): int => (int) $row->recommended_power],
                    ['label' => '启用', 'value' => fn (StageDifficulty $row): string => $this->boolLabel((bool) $row->is_enabled)],
                ],
                'fields' => [
                    ['name' => 'stage_difficulty_id', 'label' => '难度 ID', 'type' => 'text', 'readonly_on_edit' => true],
                    ['name' => 'stage_id', 'label' => '关卡 ID', 'type' => 'select', 'options' => fn (): array => $this->stageOptions()],
                    ['name' => 'difficulty_key', 'label' => '难度 Key', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(DifficultyKey::class)],
                    ['name' => 'difficulty_name', 'label' => '难度名称', 'type' => 'text'],
                    ['name' => 'recommended_power', 'label' => '推荐战力', 'type' => 'number', 'min' => 0],
                    ['name' => 'difficulty_order', 'label' => '难度排序', 'type' => 'number', 'min' => 0],
                    ['name' => 'is_enabled', 'label' => '启用', 'type' => 'checkbox'],
                ],
                'rules' => fn (?Model $record, array $input): array => [
                    'stage_difficulty_id' => ['required', 'string', Rule::unique('stage_difficulties', 'stage_difficulty_id')->ignore($record?->stage_difficulty_id, 'stage_difficulty_id')],
                    'stage_id' => ['required', 'string', Rule::exists('chapter_stages', 'stage_id')],
                    'difficulty_key' => [
                        'required',
                        new Enum(DifficultyKey::class),
                        Rule::unique('stage_difficulties', 'difficulty_key')
                            ->where(fn ($query) => $query->where('stage_id', $input['stage_id'] ?? null))
                            ->ignore($record?->stage_difficulty_id, 'stage_difficulty_id'),
                    ],
                    'difficulty_name' => ['required', 'string'],
                    'recommended_power' => ['required', 'integer', 'min:0'],
                    'difficulty_order' => ['required', 'integer', 'min:0'],
                    'is_enabled' => ['boolean'],
                ],
                'attributes' => [
                    'stage_difficulty_id' => '难度 ID',
                    'stage_id' => '关卡 ID',
                    'difficulty_key' => '难度 Key',
                    'difficulty_name' => '难度名称',
                    'recommended_power' => '推荐战力',
                    'difficulty_order' => '难度排序',
                    'is_enabled' => '启用状态',
                ],
                'payload' => fn (array $input): array => [
                    'stage_difficulty_id' => (string) $input['stage_difficulty_id'],
                    'stage_id' => (string) $input['stage_id'],
                    'difficulty_key' => (string) $input['difficulty_key'],
                    'difficulty_name' => (string) $input['difficulty_name'],
                    'recommended_power' => (int) $input['recommended_power'],
                    'difficulty_order' => (int) $input['difficulty_order'],
                    'is_enabled' => (bool) $input['is_enabled'],
                ],
            ],
            'monsters' => [
                'title' => '怪物管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => Monster::class,
                'primary_key' => 'monster_id',
                'query' => fn (): Builder => Monster::query()->orderBy('sort_order')->orderBy('monster_id'),
                'filters' => [
                    ['name' => 'monster_id', 'label' => '怪物 ID', 'type' => 'text'],
                    ['name' => 'monster_name', 'label' => '怪物名称', 'type' => 'text'],
                    ['name' => 'is_enabled', 'label' => '启用状态', 'type' => 'select', 'options' => fn (): array => $this->booleanOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyLikeFilter($query, 'monster_id', $filters);
                    $this->applyLikeFilter($query, 'monster_name', $filters);
                    $this->applyBooleanFilter($query, 'is_enabled', $filters);
                },
                'columns' => [
                    ['label' => '怪物 ID', 'value' => fn (Monster $row): string => (string) $row->monster_id],
                    ['label' => '怪物名称', 'value' => fn (Monster $row): string => (string) $row->monster_name],
                    ['label' => '攻击', 'value' => fn (Monster $row): int => (int) $row->attack],
                    ['label' => '生命', 'value' => fn (Monster $row): int => (int) $row->hp],
                    ['label' => '启用', 'value' => fn (Monster $row): string => $this->boolLabel((bool) $row->is_enabled)],
                    ['label' => '排序', 'value' => fn (Monster $row): int => (int) $row->sort_order],
                ],
                'fields' => [
                    ['name' => 'monster_id', 'label' => '怪物 ID', 'type' => 'text', 'readonly_on_edit' => true],
                    ['name' => 'monster_name', 'label' => '怪物名称', 'type' => 'text'],
                    ['name' => 'attack', 'label' => '攻击', 'type' => 'number', 'min' => 0],
                    ['name' => 'physical_defense', 'label' => '物防', 'type' => 'number', 'min' => 0],
                    ['name' => 'magic_defense', 'label' => '法防', 'type' => 'number', 'min' => 0],
                    ['name' => 'hp', 'label' => '生命', 'type' => 'number', 'min' => 0],
                    ['name' => 'mana', 'label' => '法力', 'type' => 'number', 'min' => 0],
                    ['name' => 'attack_speed', 'label' => '攻速', 'type' => 'number', 'min' => 0],
                    ['name' => 'crit_rate', 'label' => '暴击率', 'type' => 'number', 'min' => 0],
                    ['name' => 'spell_power', 'label' => '法术强度', 'type' => 'number', 'min' => 0],
                    ['name' => 'is_enabled', 'label' => '启用', 'type' => 'checkbox'],
                    ['name' => 'sort_order', 'label' => '排序', 'type' => 'number', 'min' => 0],
                ],
                'rules' => fn (?Model $record): array => [
                    'monster_id' => ['required', 'string', Rule::unique('monsters', 'monster_id')->ignore($record?->monster_id, 'monster_id')],
                    'monster_name' => ['required', 'string'],
                    'attack' => ['required', 'integer', 'min:0'],
                    'physical_defense' => ['required', 'integer', 'min:0'],
                    'magic_defense' => ['required', 'integer', 'min:0'],
                    'hp' => ['required', 'integer', 'min:0'],
                    'mana' => ['required', 'integer', 'min:0'],
                    'attack_speed' => ['required', 'integer', 'min:0'],
                    'crit_rate' => ['required', 'integer', 'min:0'],
                    'spell_power' => ['required', 'integer', 'min:0'],
                    'is_enabled' => ['boolean'],
                    'sort_order' => ['required', 'integer', 'min:0'],
                ],
                'payload' => fn (array $input): array => [
                    'monster_id' => (string) $input['monster_id'],
                    'monster_name' => (string) $input['monster_name'],
                    'attack' => (int) $input['attack'],
                    'physical_defense' => (int) $input['physical_defense'],
                    'magic_defense' => (int) $input['magic_defense'],
                    'hp' => (int) $input['hp'],
                    'mana' => (int) $input['mana'],
                    'attack_speed' => (int) $input['attack_speed'],
                    'crit_rate' => (int) $input['crit_rate'],
                    'spell_power' => (int) $input['spell_power'],
                    'is_enabled' => (bool) $input['is_enabled'],
                    'sort_order' => (int) $input['sort_order'],
                ],
            ],
            'stage-monster-bindings' => [
                'title' => '关卡难度怪物绑定管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => StageMonsterBinding::class,
                'primary_key' => 'id',
                'query' => fn (): Builder => StageMonsterBinding::query()->with(['stageDifficulty', 'monster'])->orderBy('stage_difficulty_id')->orderBy('wave_no')->orderBy('sort_order'),
                'filters' => [
                    ['name' => 'stage_difficulty_id', 'label' => '难度 ID', 'type' => 'select', 'options' => fn (): array => $this->stageDifficultyOptions(true)],
                    ['name' => 'monster_id', 'label' => '怪物 ID', 'type' => 'select', 'options' => fn (): array => $this->monsterOptions(true)],
                    ['name' => 'monster_role', 'label' => '怪物角色', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(MonsterRole::class, true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyExactFilter($query, 'stage_difficulty_id', $filters);
                    $this->applyExactFilter($query, 'monster_id', $filters);
                    $this->applyExactFilter($query, 'monster_role', $filters);
                },
                'columns' => [
                    ['label' => 'ID', 'value' => fn (StageMonsterBinding $row): int => (int) $row->id],
                    ['label' => '难度 ID', 'value' => fn (StageMonsterBinding $row): string => (string) $row->stage_difficulty_id],
                    ['label' => '怪物', 'value' => fn (StageMonsterBinding $row): string => sprintf('%s / %s', $row->monster_id, data_get($row, 'monster.monster_name', ''))],
                    ['label' => '怪物角色', 'value' => fn (StageMonsterBinding $row): string => (string) data_get($row, 'monster_role.value', $row->monster_role)],
                    ['label' => '波次', 'value' => fn (StageMonsterBinding $row): int => (int) $row->wave_no],
                    ['label' => '排序', 'value' => fn (StageMonsterBinding $row): int => (int) $row->sort_order],
                ],
                'fields' => [
                    ['name' => 'stage_difficulty_id', 'label' => '难度 ID', 'type' => 'select', 'options' => fn (): array => $this->stageDifficultyOptions()],
                    ['name' => 'monster_id', 'label' => '怪物 ID', 'type' => 'select', 'options' => fn (): array => $this->monsterOptions()],
                    ['name' => 'monster_role', 'label' => '怪物角色', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(MonsterRole::class)],
                    ['name' => 'wave_no', 'label' => '波次', 'type' => 'number', 'min' => 1],
                    ['name' => 'sort_order', 'label' => '排序', 'type' => 'number', 'min' => 0],
                ],
                'rules' => fn (): array => [
                    'stage_difficulty_id' => ['required', 'string', Rule::exists('stage_difficulties', 'stage_difficulty_id')],
                    'monster_id' => ['required', 'string', Rule::exists('monsters', 'monster_id')],
                    'monster_role' => ['required', new Enum(MonsterRole::class)],
                    'wave_no' => ['required', 'integer', 'min:1'],
                    'sort_order' => ['required', 'integer', 'min:0'],
                ],
                'payload' => fn (array $input): array => [
                    'stage_difficulty_id' => (string) $input['stage_difficulty_id'],
                    'monster_id' => (string) $input['monster_id'],
                    'monster_role' => (string) $input['monster_role'],
                    'wave_no' => (int) $input['wave_no'],
                    'sort_order' => (int) $input['sort_order'],
                ],
            ],
            'drop-groups' => [
                'title' => '掉落组管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => DropGroup::class,
                'primary_key' => 'drop_group_id',
                'query' => fn (): Builder => DropGroup::query()->orderBy('sort_order')->orderBy('drop_group_id'),
                'filters' => [
                    ['name' => 'drop_group_id', 'label' => '掉落组 ID', 'type' => 'text'],
                    ['name' => 'roll_type', 'label' => '抽取规则', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(DropRollType::class, true)],
                    ['name' => 'is_enabled', 'label' => '启用状态', 'type' => 'select', 'options' => fn (): array => $this->booleanOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyLikeFilter($query, 'drop_group_id', $filters);
                    $this->applyExactFilter($query, 'roll_type', $filters);
                    $this->applyBooleanFilter($query, 'is_enabled', $filters);
                },
                'columns' => [
                    ['label' => '掉落组 ID', 'value' => fn (DropGroup $row): string => (string) $row->drop_group_id],
                    ['label' => '掉落组名称', 'value' => fn (DropGroup $row): string => (string) $row->drop_group_name],
                    ['label' => '抽取规则', 'value' => fn (DropGroup $row): string => (string) data_get($row, 'roll_type.value', $row->roll_type)],
                    ['label' => '抽取次数', 'value' => fn (DropGroup $row): int => (int) $row->roll_times],
                    ['label' => '启用', 'value' => fn (DropGroup $row): string => $this->boolLabel((bool) $row->is_enabled)],
                ],
                'fields' => [
                    ['name' => 'drop_group_id', 'label' => '掉落组 ID', 'type' => 'text', 'readonly_on_edit' => true],
                    ['name' => 'drop_group_name', 'label' => '掉落组名称', 'type' => 'text'],
                    ['name' => 'roll_type', 'label' => '抽取规则', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(DropRollType::class)],
                    ['name' => 'roll_times', 'label' => '抽取次数', 'type' => 'number', 'min' => 1],
                    ['name' => 'is_enabled', 'label' => '启用', 'type' => 'checkbox'],
                    ['name' => 'sort_order', 'label' => '排序', 'type' => 'number', 'min' => 0],
                ],
                'rules' => fn (?Model $record): array => [
                    'drop_group_id' => ['required', 'string', Rule::unique('drop_groups', 'drop_group_id')->ignore($record?->drop_group_id, 'drop_group_id')],
                    'drop_group_name' => ['required', 'string'],
                    'roll_type' => ['required', new Enum(DropRollType::class)],
                    'roll_times' => ['required', 'integer', 'min:1'],
                    'is_enabled' => ['boolean'],
                    'sort_order' => ['required', 'integer', 'min:0'],
                ],
                'payload' => fn (array $input): array => [
                    'drop_group_id' => (string) $input['drop_group_id'],
                    'drop_group_name' => (string) $input['drop_group_name'],
                    'roll_type' => (string) $input['roll_type'],
                    'roll_times' => (int) $input['roll_times'],
                    'is_enabled' => (bool) $input['is_enabled'],
                    'sort_order' => (int) $input['sort_order'],
                ],
            ],
            'drop-group-items' => [
                'title' => '掉落组明细管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => DropGroupItem::class,
                'primary_key' => 'id',
                'query' => fn (): Builder => DropGroupItem::query()->with(['dropGroup', 'item'])->orderBy('drop_group_id')->orderBy('sort_order'),
                'filters' => [
                    ['name' => 'drop_group_id', 'label' => '掉落组 ID', 'type' => 'select', 'options' => fn (): array => $this->dropGroupOptions(true)],
                    ['name' => 'item_id', 'label' => '物品 ID', 'type' => 'select', 'options' => fn (): array => $this->itemOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyExactFilter($query, 'drop_group_id', $filters);
                    $this->applyExactFilter($query, 'item_id', $filters);
                },
                'columns' => [
                    ['label' => 'ID', 'value' => fn (DropGroupItem $row): int => (int) $row->id],
                    ['label' => '掉落组', 'value' => fn (DropGroupItem $row): string => sprintf('%s / %s', $row->drop_group_id, data_get($row, 'dropGroup.drop_group_name', ''))],
                    ['label' => '物品', 'value' => fn (DropGroupItem $row): string => sprintf('%s / %s', $row->item_id, data_get($row, 'item.item_name', ''))],
                    ['label' => '权重', 'value' => fn (DropGroupItem $row): int => (int) $row->weight],
                    ['label' => '数量区间', 'value' => fn (DropGroupItem $row): string => sprintf('%d - %d', $row->min_quantity, $row->max_quantity)],
                    ['label' => '排序', 'value' => fn (DropGroupItem $row): int => (int) $row->sort_order],
                ],
                'fields' => [
                    ['name' => 'drop_group_id', 'label' => '掉落组 ID', 'type' => 'select', 'options' => fn (): array => $this->dropGroupOptions()],
                    ['name' => 'item_id', 'label' => '物品 ID', 'type' => 'select', 'options' => fn (): array => $this->itemOptions()],
                    ['name' => 'weight', 'label' => '权重', 'type' => 'number', 'min' => 0],
                    ['name' => 'min_quantity', 'label' => '最小数量', 'type' => 'number', 'min' => 1],
                    ['name' => 'max_quantity', 'label' => '最大数量', 'type' => 'number', 'min' => 1],
                    ['name' => 'sort_order', 'label' => '排序', 'type' => 'number', 'min' => 0],
                ],
                'rules' => fn (): array => [
                    'drop_group_id' => ['required', 'string', Rule::exists('drop_groups', 'drop_group_id')],
                    'item_id' => ['required', 'string', Rule::exists('items', 'item_id')],
                    'weight' => ['required', 'integer', 'min:0'],
                    'min_quantity' => ['required', 'integer', 'min:1'],
                    'max_quantity' => ['required', 'integer', 'min:1'],
                    'sort_order' => ['required', 'integer', 'min:0'],
                ],
                'after_validation' => function (Validator $validator, ?Model $record, array $input): void {
                    $validator->after(function (Validator $validator) use ($input): void {
                        if ((int) $input['min_quantity'] > (int) $input['max_quantity']) {
                            $validator->errors()->add('max_quantity', '最大数量必须大于等于最小数量');
                        }
                    });
                },
                'payload' => fn (array $input): array => [
                    'drop_group_id' => (string) $input['drop_group_id'],
                    'item_id' => (string) $input['item_id'],
                    'weight' => (int) $input['weight'],
                    'min_quantity' => (int) $input['min_quantity'],
                    'max_quantity' => (int) $input['max_quantity'],
                    'sort_order' => (int) $input['sort_order'],
                ],
            ],
            'drop-group-bindings' => [
                'title' => '掉落来源绑定管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => DropGroupBinding::class,
                'primary_key' => 'id',
                'query' => fn (): Builder => DropGroupBinding::query()->with('dropGroup')->orderBy('source_type')->orderBy('source_id'),
                'filters' => [
                    ['name' => 'source_type', 'label' => '来源类型', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(DropSourceType::class, true)],
                    ['name' => 'source_id', 'label' => '来源 ID', 'type' => 'select', 'options' => fn (): array => $this->monsterOptions(true)],
                    ['name' => 'drop_group_id', 'label' => '掉落组 ID', 'type' => 'select', 'options' => fn (): array => $this->dropGroupOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyExactFilter($query, 'source_type', $filters);
                    $this->applyExactFilter($query, 'source_id', $filters);
                    $this->applyExactFilter($query, 'drop_group_id', $filters);
                },
                'columns' => [
                    ['label' => 'ID', 'value' => fn (DropGroupBinding $row): int => (int) $row->id],
                    ['label' => '来源类型', 'value' => fn (DropGroupBinding $row): string => (string) data_get($row, 'source_type.value', $row->source_type)],
                    ['label' => '来源 ID', 'value' => fn (DropGroupBinding $row): string => (string) $row->source_id],
                    ['label' => '掉落组', 'value' => fn (DropGroupBinding $row): string => sprintf('%s / %s', $row->drop_group_id, data_get($row, 'dropGroup.drop_group_name', ''))],
                    ['label' => '更新时间', 'value' => fn (DropGroupBinding $row): string => (string) optional($row->updated_at)->format('Y-m-d H:i:s')],
                ],
                'fields' => [
                    ['name' => 'source_type', 'label' => '来源类型', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(DropSourceType::class)],
                    ['name' => 'source_id', 'label' => '来源 ID', 'type' => 'select', 'options' => fn (): array => $this->monsterOptions()],
                    ['name' => 'drop_group_id', 'label' => '掉落组 ID', 'type' => 'select', 'options' => fn (): array => $this->dropGroupOptions()],
                ],
                'rules' => fn (?Model $record, array $input): array => [
                    'source_type' => [
                        'required',
                        new Enum(DropSourceType::class),
                        Rule::unique('drop_group_bindings', 'source_type')
                            ->where(fn ($query) => $query->where('source_id', $input['source_id'] ?? null))
                            ->ignore($record?->id),
                    ],
                    'source_id' => ['required', 'string', Rule::exists('monsters', 'monster_id')],
                    'drop_group_id' => ['required', 'string', Rule::exists('drop_groups', 'drop_group_id')],
                ],
                'payload' => fn (array $input): array => [
                    'source_type' => (string) $input['source_type'],
                    'source_id' => (string) $input['source_id'],
                    'drop_group_id' => (string) $input['drop_group_id'],
                ],
            ],
            'reward-groups' => [
                'title' => '奖励组管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => RewardGroup::class,
                'primary_key' => 'reward_group_id',
                'query' => fn (): Builder => RewardGroup::query()->orderBy('sort_order')->orderBy('reward_group_id'),
                'filters' => [
                    ['name' => 'reward_group_id', 'label' => '奖励组 ID', 'type' => 'text'],
                    ['name' => 'is_enabled', 'label' => '启用状态', 'type' => 'select', 'options' => fn (): array => $this->booleanOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyLikeFilter($query, 'reward_group_id', $filters);
                    $this->applyBooleanFilter($query, 'is_enabled', $filters);
                },
                'columns' => [
                    ['label' => '奖励组 ID', 'value' => fn (RewardGroup $row): string => (string) $row->reward_group_id],
                    ['label' => '奖励组名称', 'value' => fn (RewardGroup $row): string => (string) $row->reward_group_name],
                    ['label' => '启用', 'value' => fn (RewardGroup $row): string => $this->boolLabel((bool) $row->is_enabled)],
                    ['label' => '排序', 'value' => fn (RewardGroup $row): int => (int) $row->sort_order],
                ],
                'fields' => [
                    ['name' => 'reward_group_id', 'label' => '奖励组 ID', 'type' => 'text', 'readonly_on_edit' => true],
                    ['name' => 'reward_group_name', 'label' => '奖励组名称', 'type' => 'text'],
                    ['name' => 'is_enabled', 'label' => '启用', 'type' => 'checkbox'],
                    ['name' => 'sort_order', 'label' => '排序', 'type' => 'number', 'min' => 0],
                ],
                'rules' => fn (?Model $record): array => [
                    'reward_group_id' => ['required', 'string', Rule::unique('reward_groups', 'reward_group_id')->ignore($record?->reward_group_id, 'reward_group_id')],
                    'reward_group_name' => ['required', 'string'],
                    'is_enabled' => ['boolean'],
                    'sort_order' => ['required', 'integer', 'min:0'],
                ],
                'payload' => fn (array $input): array => [
                    'reward_group_id' => (string) $input['reward_group_id'],
                    'reward_group_name' => (string) $input['reward_group_name'],
                    'is_enabled' => (bool) $input['is_enabled'],
                    'sort_order' => (int) $input['sort_order'],
                ],
            ],
            'reward-group-items' => [
                'title' => '奖励组明细管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => RewardGroupItem::class,
                'primary_key' => 'id',
                'query' => fn (): Builder => RewardGroupItem::query()->with(['rewardGroup', 'item'])->orderBy('reward_group_id')->orderBy('sort_order'),
                'filters' => [
                    ['name' => 'reward_group_id', 'label' => '奖励组 ID', 'type' => 'select', 'options' => fn (): array => $this->rewardGroupOptions(true)],
                    ['name' => 'item_id', 'label' => '物品 ID', 'type' => 'select', 'options' => fn (): array => $this->itemOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyExactFilter($query, 'reward_group_id', $filters);
                    $this->applyExactFilter($query, 'item_id', $filters);
                },
                'columns' => [
                    ['label' => 'ID', 'value' => fn (RewardGroupItem $row): int => (int) $row->id],
                    ['label' => '奖励组', 'value' => fn (RewardGroupItem $row): string => sprintf('%s / %s', $row->reward_group_id, data_get($row, 'rewardGroup.reward_group_name', ''))],
                    ['label' => '物品', 'value' => fn (RewardGroupItem $row): string => sprintf('%s / %s', $row->item_id, data_get($row, 'item.item_name', ''))],
                    ['label' => '数量', 'value' => fn (RewardGroupItem $row): int => (int) $row->quantity],
                    ['label' => '排序', 'value' => fn (RewardGroupItem $row): int => (int) $row->sort_order],
                ],
                'fields' => [
                    ['name' => 'reward_group_id', 'label' => '奖励组 ID', 'type' => 'select', 'options' => fn (): array => $this->rewardGroupOptions()],
                    ['name' => 'item_id', 'label' => '物品 ID', 'type' => 'select', 'options' => fn (): array => $this->itemOptions()],
                    ['name' => 'quantity', 'label' => '数量', 'type' => 'number', 'min' => 1],
                    ['name' => 'sort_order', 'label' => '排序', 'type' => 'number', 'min' => 0],
                ],
                'rules' => fn (): array => [
                    'reward_group_id' => ['required', 'string', Rule::exists('reward_groups', 'reward_group_id')],
                    'item_id' => ['required', 'string', Rule::exists('items', 'item_id')],
                    'quantity' => ['required', 'integer', 'min:1'],
                    'sort_order' => ['required', 'integer', 'min:0'],
                ],
                'payload' => fn (array $input): array => [
                    'reward_group_id' => (string) $input['reward_group_id'],
                    'item_id' => (string) $input['item_id'],
                    'quantity' => (int) $input['quantity'],
                    'sort_order' => (int) $input['sort_order'],
                ],
            ],
            'reward-group-bindings' => [
                'title' => '奖励来源绑定管理',
                'section' => '配置管理',
                'mode' => 'config',
                'model' => RewardGroupBinding::class,
                'primary_key' => 'id',
                'query' => fn (): Builder => RewardGroupBinding::query()->with('rewardGroup')->orderBy('source_type')->orderBy('source_id'),
                'filters' => [
                    ['name' => 'source_type', 'label' => '来源类型', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(RewardSourceType::class, true)],
                    ['name' => 'source_id', 'label' => '来源 ID', 'type' => 'select', 'options' => fn (): array => $this->stageDifficultyOptions(true)],
                    ['name' => 'reward_group_id', 'label' => '奖励组 ID', 'type' => 'select', 'options' => fn (): array => $this->rewardGroupOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyExactFilter($query, 'source_type', $filters);
                    $this->applyExactFilter($query, 'source_id', $filters);
                    $this->applyExactFilter($query, 'reward_group_id', $filters);
                },
                'columns' => [
                    ['label' => 'ID', 'value' => fn (RewardGroupBinding $row): int => (int) $row->id],
                    ['label' => '来源类型', 'value' => fn (RewardGroupBinding $row): string => (string) data_get($row, 'source_type.value', $row->source_type)],
                    ['label' => '来源 ID', 'value' => fn (RewardGroupBinding $row): string => (string) $row->source_id],
                    ['label' => '奖励组', 'value' => fn (RewardGroupBinding $row): string => sprintf('%s / %s', $row->reward_group_id, data_get($row, 'rewardGroup.reward_group_name', ''))],
                    ['label' => '更新时间', 'value' => fn (RewardGroupBinding $row): string => (string) optional($row->updated_at)->format('Y-m-d H:i:s')],
                ],
                'fields' => [
                    ['name' => 'source_type', 'label' => '来源类型', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(RewardSourceType::class)],
                    ['name' => 'source_id', 'label' => '来源 ID', 'type' => 'select', 'options' => fn (): array => $this->stageDifficultyOptions()],
                    ['name' => 'reward_group_id', 'label' => '奖励组 ID', 'type' => 'select', 'options' => fn (): array => $this->rewardGroupOptions()],
                ],
                'rules' => fn (?Model $record, array $input): array => [
                    'source_type' => [
                        'required',
                        new Enum(RewardSourceType::class),
                        Rule::unique('reward_group_bindings', 'source_type')
                            ->where(fn ($query) => $query->where('source_id', $input['source_id'] ?? null))
                            ->ignore($record?->id),
                    ],
                    'source_id' => ['required', 'string', Rule::exists('stage_difficulties', 'stage_difficulty_id')],
                    'reward_group_id' => ['required', 'string', Rule::exists('reward_groups', 'reward_group_id')],
                ],
                'payload' => fn (array $input): array => [
                    'source_type' => (string) $input['source_type'],
                    'source_id' => (string) $input['source_id'],
                    'reward_group_id' => (string) $input['reward_group_id'],
                ],
            ],
        ];
    }

    private function queryResources(): array
    {
        return [
            'characters' => [
                'title' => '角色查询页',
                'section' => '查询页',
                'mode' => 'query',
                'model' => Character::class,
                'primary_key' => 'character_id',
                'query' => fn (): Builder => Character::query()->with('gameClass')->orderByDesc('character_id'),
                'filters' => [
                    ['name' => 'character_id', 'label' => '角色 ID', 'type' => 'text'],
                    ['name' => 'user_id', 'label' => '用户 ID', 'type' => 'text'],
                    ['name' => 'class_id', 'label' => '职业 ID', 'type' => 'select', 'options' => fn (): array => $this->classOptions(true)],
                    ['name' => 'is_active', 'label' => '启用状态', 'type' => 'select', 'options' => fn (): array => $this->booleanOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyExactFilter($query, 'character_id', $filters);
                    $this->applyExactFilter($query, 'user_id', $filters);
                    $this->applyExactFilter($query, 'class_id', $filters);
                    $this->applyBooleanFilter($query, 'is_active', $filters);
                },
                'columns' => [
                    ['label' => '角色 ID', 'value' => fn (Character $row): int => (int) $row->character_id],
                    ['label' => '用户 ID', 'value' => fn (Character $row): int => (int) $row->user_id],
                    ['label' => '职业', 'value' => fn (Character $row): string => sprintf('%s / %s', $row->class_id, data_get($row, 'gameClass.class_name', ''))],
                    ['label' => '角色名', 'value' => fn (Character $row): string => (string) $row->character_name],
                    ['label' => '等级', 'value' => fn (Character $row): int => (int) $row->level],
                    ['label' => '经验', 'value' => fn (Character $row): int => (int) $row->exp],
                    ['label' => '启用', 'value' => fn (Character $row): string => $this->boolLabel((bool) $row->is_active)],
                    ['label' => '更新时间', 'value' => fn (Character $row): string => (string) optional($row->updated_at)->format('Y-m-d H:i:s')],
                ],
            ],
            'character-equipment-slots' => [
                'title' => '角色穿戴槽查询页',
                'section' => '查询页',
                'mode' => 'query',
                'model' => CharacterEquipmentSlot::class,
                'primary_key' => 'id',
                'query' => fn (): Builder => CharacterEquipmentSlot::query()->with(['character', 'equippedInstance.equipmentTemplate.item'])->orderByDesc('character_id')->orderBy('sort_order'),
                'filters' => [
                    ['name' => 'character_id', 'label' => '角色 ID', 'type' => 'text'],
                    ['name' => 'slot_key', 'label' => '槽位', 'type' => 'select', 'options' => fn (): array => $this->slotKeyOptions(true)],
                    ['name' => 'equipped_instance_id', 'label' => '装备实例 ID', 'type' => 'text'],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyExactFilter($query, 'character_id', $filters);
                    $this->applyExactFilter($query, 'slot_key', $filters);
                    $this->applyExactFilter($query, 'equipped_instance_id', $filters);
                },
                'columns' => [
                    ['label' => '角色 ID', 'value' => fn (CharacterEquipmentSlot $row): int => (int) $row->character_id],
                    ['label' => '角色名', 'value' => fn (CharacterEquipmentSlot $row): string => (string) data_get($row, 'character.character_name', '')],
                    ['label' => '槽位', 'value' => fn (CharacterEquipmentSlot $row): string => (string) data_get($row, 'slot_key.value', $row->slot_key)],
                    ['label' => '装备实例 ID', 'value' => fn (CharacterEquipmentSlot $row): string => (string) ($row->equipped_instance_id ?? '-')],
                    ['label' => '装备名称', 'value' => fn (CharacterEquipmentSlot $row): string => (string) data_get($row, 'equippedInstance.equipmentTemplate.item.item_name', '')],
                    ['label' => '装备位', 'value' => fn (CharacterEquipmentSlot $row): string => (string) data_get($row, 'equippedInstance.equipmentTemplate.equipment_slot.value', data_get($row, 'equippedInstance.equipmentTemplate.equipment_slot', ''))],
                ],
            ],
            'inventory-stack-items' => [
                'title' => '可堆叠背包查询页',
                'section' => '查询页',
                'mode' => 'query',
                'model' => InventoryStackItem::class,
                'primary_key' => 'id',
                'query' => fn (): Builder => InventoryStackItem::query()->with('item')->orderByDesc('updated_at'),
                'filters' => [
                    ['name' => 'user_id', 'label' => '用户 ID', 'type' => 'text'],
                    ['name' => 'item_id', 'label' => '物品 ID', 'type' => 'select', 'options' => fn (): array => $this->itemOptions(true)],
                    ['name' => 'item_type', 'label' => '物品类型', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(ItemType::class, true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyExactFilter($query, 'user_id', $filters);
                    $this->applyExactFilter($query, 'item_id', $filters);

                    if (($filters['item_type'] ?? '') !== '') {
                        $query->whereHas('item', fn (Builder $itemQuery) => $itemQuery->where('item_type', $filters['item_type']));
                    }
                },
                'columns' => [
                    ['label' => '用户 ID', 'value' => fn (InventoryStackItem $row): int => (int) $row->user_id],
                    ['label' => '物品', 'value' => fn (InventoryStackItem $row): string => sprintf('%s / %s', $row->item_id, data_get($row, 'item.item_name', ''))],
                    ['label' => '类型', 'value' => fn (InventoryStackItem $row): string => (string) data_get($row, 'item.item_type.value', data_get($row, 'item.item_type', ''))],
                    ['label' => '稀有度', 'value' => fn (InventoryStackItem $row): string => (string) data_get($row, 'item.rarity.value', data_get($row, 'item.rarity', ''))],
                    ['label' => '数量', 'value' => fn (InventoryStackItem $row): int => (int) $row->quantity],
                    ['label' => '更新时间', 'value' => fn (InventoryStackItem $row): string => (string) optional($row->updated_at)->format('Y-m-d H:i:s')],
                ],
            ],
            'inventory-equipment-instances' => [
                'title' => '装备实例查询页',
                'section' => '查询页',
                'mode' => 'query',
                'model' => InventoryEquipmentInstance::class,
                'primary_key' => 'equipment_instance_id',
                'query' => fn (): Builder => InventoryEquipmentInstance::query()->with(['equipmentTemplate.item', 'equippedSlot'])->orderByDesc('equipment_instance_id'),
                'filters' => [
                    ['name' => 'equipment_instance_id', 'label' => '实例 ID', 'type' => 'text'],
                    ['name' => 'user_id', 'label' => '用户 ID', 'type' => 'text'],
                    ['name' => 'item_id', 'label' => '装备物品 ID', 'type' => 'select', 'options' => fn (): array => $this->equipmentItemOptions(true)],
                    ['name' => 'bind_type', 'label' => '绑定类型', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(BindType::class, true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyExactFilter($query, 'equipment_instance_id', $filters);
                    $this->applyExactFilter($query, 'user_id', $filters);
                    $this->applyExactFilter($query, 'item_id', $filters);
                    $this->applyExactFilter($query, 'bind_type', $filters);
                },
                'columns' => [
                    ['label' => '实例 ID', 'value' => fn (InventoryEquipmentInstance $row): int => (int) $row->equipment_instance_id],
                    ['label' => '用户 ID', 'value' => fn (InventoryEquipmentInstance $row): int => (int) $row->user_id],
                    ['label' => '装备', 'value' => fn (InventoryEquipmentInstance $row): string => sprintf('%s / %s', $row->item_id, data_get($row, 'equipmentTemplate.item.item_name', ''))],
                    ['label' => '绑定类型', 'value' => fn (InventoryEquipmentInstance $row): string => (string) data_get($row, 'bind_type.value', $row->bind_type)],
                    ['label' => '强化等级', 'value' => fn (InventoryEquipmentInstance $row): int => (int) $row->enhance_level],
                    ['label' => '耐久', 'value' => fn (InventoryEquipmentInstance $row): string => sprintf('%d / %d', $row->durability, $row->max_durability)],
                    ['label' => '已锁定', 'value' => fn (InventoryEquipmentInstance $row): string => $this->boolLabel((bool) $row->is_locked)],
                    ['label' => '穿戴槽位', 'value' => fn (InventoryEquipmentInstance $row): string => (string) data_get($row, 'equippedSlot.slot_key.value', data_get($row, 'equippedSlot.slot_key', ''))],
                    ['label' => '创建时间', 'value' => fn (InventoryEquipmentInstance $row): string => (string) optional($row->created_at)->format('Y-m-d H:i:s')],
                ],
            ],
            'reward-grants' => [
                'title' => '发奖记录查询页',
                'section' => '查询页',
                'mode' => 'query',
                'model' => UserRewardGrant::class,
                'primary_key' => 'reward_grant_id',
                'query' => fn (): Builder => UserRewardGrant::query()->with('rewardGroup')->orderByDesc('reward_grant_id'),
                'filters' => [
                    ['name' => 'reward_grant_id', 'label' => '发奖记录 ID', 'type' => 'text'],
                    ['name' => 'user_id', 'label' => '用户 ID', 'type' => 'text'],
                    ['name' => 'source_type', 'label' => '来源类型', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(RewardSourceType::class, true)],
                    ['name' => 'grant_status', 'label' => '发奖状态', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(GrantStatus::class, true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyExactFilter($query, 'reward_grant_id', $filters);
                    $this->applyExactFilter($query, 'user_id', $filters);
                    $this->applyExactFilter($query, 'source_type', $filters);
                    $this->applyExactFilter($query, 'grant_status', $filters);
                },
                'columns' => [
                    ['label' => '发奖记录 ID', 'value' => fn (UserRewardGrant $row): int => (int) $row->reward_grant_id],
                    ['label' => '用户 ID', 'value' => fn (UserRewardGrant $row): int => (int) $row->user_id],
                    ['label' => '奖励组', 'value' => fn (UserRewardGrant $row): string => sprintf('%s / %s', $row->reward_group_id, data_get($row, 'rewardGroup.reward_group_name', ''))],
                    ['label' => '来源', 'value' => fn (UserRewardGrant $row): string => sprintf('%s / %s', data_get($row, 'source_type.value', $row->source_type), $row->source_id)],
                    ['label' => '幂等键', 'value' => fn (UserRewardGrant $row): string => (string) $row->idempotency_key],
                    ['label' => '状态', 'value' => fn (UserRewardGrant $row): string => (string) data_get($row, 'grant_status.value', $row->grant_status)],
                    ['label' => '创建时间', 'value' => fn (UserRewardGrant $row): string => (string) optional($row->created_at)->format('Y-m-d H:i:s')],
                    ['label' => '发放时间', 'value' => fn (UserRewardGrant $row): string => (string) optional($row->granted_at)->format('Y-m-d H:i:s')],
                ],
            ],
            'reward-grant-items' => [
                'title' => '发奖明细查询页',
                'section' => '查询页',
                'mode' => 'query',
                'model' => UserRewardGrantItem::class,
                'primary_key' => 'id',
                'query' => fn (): Builder => UserRewardGrantItem::query()->with(['rewardGrant', 'item'])->orderByDesc('reward_grant_id')->orderBy('sort_order'),
                'filters' => [
                    ['name' => 'reward_grant_id', 'label' => '发奖记录 ID', 'type' => 'text'],
                    ['name' => 'item_id', 'label' => '物品 ID', 'type' => 'select', 'options' => fn (): array => $this->itemOptions(true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyExactFilter($query, 'reward_grant_id', $filters);
                    $this->applyExactFilter($query, 'item_id', $filters);
                },
                'columns' => [
                    ['label' => '发奖记录 ID', 'value' => fn (UserRewardGrantItem $row): int => (int) $row->reward_grant_id],
                    ['label' => '来源', 'value' => fn (UserRewardGrantItem $row): string => sprintf('%s / %s', data_get($row, 'rewardGrant.source_type.value', data_get($row, 'rewardGrant.source_type', '')), data_get($row, 'rewardGrant.source_id', ''))],
                    ['label' => '物品', 'value' => fn (UserRewardGrantItem $row): string => sprintf('%s / %s', $row->item_id, data_get($row, 'item.item_name', ''))],
                    ['label' => '数量', 'value' => fn (UserRewardGrantItem $row): int => (int) $row->quantity],
                    ['label' => '排序', 'value' => fn (UserRewardGrantItem $row): int => (int) $row->sort_order],
                    ['label' => '创建时间', 'value' => fn (UserRewardGrantItem $row): string => (string) optional($row->created_at)->format('Y-m-d H:i:s')],
                ],
            ],
            'battle-contexts' => [
                'title' => 'Battle Context 查询页',
                'section' => '查询页',
                'mode' => 'query',
                'model' => BattleContext::class,
                'primary_key' => 'battle_context_id',
                'query' => fn (): Builder => BattleContext::query()->with(['user', 'character', 'stageDifficulty'])->orderByDesc('created_at'),
                'filters' => [
                    ['name' => 'battle_context_id', 'label' => 'Battle Context ID', 'type' => 'text'],
                    ['name' => 'user_id', 'label' => '用户 ID', 'type' => 'text'],
                    ['name' => 'character_id', 'label' => '角色 ID', 'type' => 'text'],
                    ['name' => 'stage_difficulty_id', 'label' => '难度 ID', 'type' => 'select', 'options' => fn (): array => $this->stageDifficultyOptions(true)],
                    ['name' => 'status', 'label' => '状态', 'type' => 'select', 'options' => fn (): array => $this->enumOptions(BattleContextStatus::class, true)],
                ],
                'apply_filters' => function (Builder $query, array $filters): void {
                    $this->applyLikeFilter($query, 'battle_context_id', $filters);
                    $this->applyExactFilter($query, 'user_id', $filters);
                    $this->applyExactFilter($query, 'character_id', $filters);
                    $this->applyExactFilter($query, 'stage_difficulty_id', $filters);
                    $this->applyExactFilter($query, 'status', $filters);
                },
                'columns' => [
                    ['label' => 'Battle Context ID', 'value' => fn (BattleContext $row): string => (string) $row->battle_context_id],
                    ['label' => '用户 ID', 'value' => fn (BattleContext $row): int => (int) $row->user_id],
                    ['label' => '角色', 'value' => fn (BattleContext $row): string => sprintf('%d / %s', $row->character_id, data_get($row, 'character.character_name', ''))],
                    ['label' => '难度 ID', 'value' => fn (BattleContext $row): string => (string) $row->stage_difficulty_id],
                    ['label' => '状态', 'value' => fn (BattleContext $row): string => (string) data_get($row, 'status.value', $row->status)],
                    ['label' => '准备时间', 'value' => fn (BattleContext $row): string => (string) optional($row->created_at)->format('Y-m-d H:i:s')],
                    ['label' => '结算时间', 'value' => fn (BattleContext $row): string => (string) optional($row->settled_at)->format('Y-m-d H:i:s')],
                ],
            ],
        ];
    }

    private function applyLikeFilter(Builder $query, string $column, array $filters): void
    {
        if (($filters[$column] ?? '') !== '') {
            $query->where($column, 'like', '%'.$filters[$column].'%');
        }
    }

    private function applyExactFilter(Builder $query, string $column, array $filters): void
    {
        if (($filters[$column] ?? '') !== '') {
            $query->where($column, $filters[$column]);
        }
    }

    private function applyBooleanFilter(Builder $query, string $column, array $filters): void
    {
        if (($filters[$column] ?? '') === '') {
            return;
        }

        $query->where($column, (bool) $filters[$column]);
    }

    private function classOptions(bool $withAll = false): array
    {
        return $this->withOptionalAll(
            GameClass::query()->orderBy('sort_order')->pluck('class_name', 'class_id')->all(),
            $withAll
        );
    }

    private function itemOptions(bool $withAll = false): array
    {
        return $this->withOptionalAll(
            Item::query()->orderBy('sort_order')->pluck('item_name', 'item_id')->all(),
            $withAll
        );
    }

    private function equipmentItemOptions(bool $withAll = false): array
    {
        return $this->withOptionalAll(
            Item::query()
                ->where('item_type', ItemType::EQUIPMENT->value)
                ->orderBy('sort_order')
                ->pluck('item_name', 'item_id')
                ->all(),
            $withAll
        );
    }

    private function chapterOptions(bool $withAll = false): array
    {
        return $this->withOptionalAll(
            Chapter::query()->orderBy('sort_order')->pluck('chapter_name', 'chapter_id')->all(),
            $withAll
        );
    }

    private function stageOptions(bool $withAll = false): array
    {
        return $this->withOptionalAll(
            ChapterStage::query()->orderBy('chapter_id')->orderBy('stage_order')->pluck('stage_name', 'stage_id')->all(),
            $withAll
        );
    }

    private function stageDifficultyOptions(bool $withAll = false): array
    {
        return $this->withOptionalAll(
            StageDifficulty::query()
                ->orderBy('stage_id')
                ->orderBy('difficulty_order')
                ->get()
                ->mapWithKeys(fn (StageDifficulty $difficulty): array => [
                    $difficulty->stage_difficulty_id => sprintf(
                        '%s (%s)',
                        $difficulty->stage_difficulty_id,
                        $difficulty->difficulty_name
                    ),
                ])->all(),
            $withAll
        );
    }

    private function monsterOptions(bool $withAll = false): array
    {
        return $this->withOptionalAll(
            Monster::query()->orderBy('sort_order')->pluck('monster_name', 'monster_id')->all(),
            $withAll
        );
    }

    private function dropGroupOptions(bool $withAll = false): array
    {
        return $this->withOptionalAll(
            DropGroup::query()->orderBy('sort_order')->pluck('drop_group_name', 'drop_group_id')->all(),
            $withAll
        );
    }

    private function rewardGroupOptions(bool $withAll = false): array
    {
        return $this->withOptionalAll(
            RewardGroup::query()->orderBy('sort_order')->pluck('reward_group_name', 'reward_group_id')->all(),
            $withAll
        );
    }

    private function slotKeyOptions(bool $withAll = false): array
    {
        return $this->withOptionalAll(
            Collection::make(EquipmentSlotKey::orderedValues())
                ->mapWithKeys(fn (string $slotKey): array => [$slotKey => $slotKey])
                ->all(),
            $withAll
        );
    }

    private function enumOptions(string $enumClass, bool $withAll = false, string $allLabel = '全部'): array
    {
        $options = Collection::make($enumClass::cases())
            ->mapWithKeys(fn ($case): array => [$case->value => $case->value])
            ->all();

        return $this->withOptionalAll($options, $withAll, $allLabel);
    }

    private function booleanOptions(bool $withAll = false): array
    {
        $options = [
            '1' => '是',
            '0' => '否',
        ];

        return $this->withOptionalAll($options, $withAll);
    }

    private function withOptionalAll(array $options, bool $withAll, string $allLabel = '全部'): array
    {
        if (! $withAll) {
            return $options;
        }

        return ['' => $allLabel] + $options;
    }

    private function boolLabel(bool $value): string
    {
        return $value ? '是' : '否';
    }

    private function nullableString(mixed $value): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }
}
