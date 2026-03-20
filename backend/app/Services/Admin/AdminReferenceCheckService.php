<?php

namespace App\Services\Admin;

use App\Enums\Drop\DropSourceType;
use App\Enums\Reward\RewardSourceType;
use App\Exceptions\BusinessException;
use App\Models\Battle\BattleContext;
use App\Models\Drop\DropGroupBinding;
use App\Models\Drop\DropGroupItem;
use App\Models\Equipment\Equipment;
use App\Models\Equipment\InventoryEquipmentInstance;
use App\Models\Inventory\InventoryStackItem;
use App\Models\Monster\Monster;
use App\Models\Reward\RewardGroupBinding;
use App\Models\Reward\RewardGroupItem;
use App\Models\Reward\UserRewardGrant;
use App\Models\Reward\UserRewardGrantItem;
use App\Models\Stage\ChapterStage;
use App\Models\Stage\StageDifficulty;
use App\Models\Stage\StageMonsterBinding;
use App\Support\ErrorCode;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class AdminReferenceCheckService
{
    public function __construct(
        private readonly AdminResourceRegistry $adminResourceRegistry,
    ) {
    }

    public function inspect(string $resource, string $recordKey): array
    {
        return $this->inspectRecord($resource, $this->findConfigRecord($resource, $recordKey));
    }

    public function inspectRecord(string $resource, Model $record): array
    {
        $definition = $this->getConfigDefinition($resource);
        $primaryKey = (string) ($definition['primary_key'] ?? 'id');
        $summary = $this->buildReferenceSummary($resource, $record);

        return [
            'resource' => $resource,
            'resource_title' => (string) ($definition['title'] ?? $resource),
            'record_key' => (string) $record->getAttribute($primaryKey),
            'record_label' => $this->buildRecordLabel($resource, $record),
            'block_disable' => $summary['disable_references'] !== [],
            'block_delete' => $summary['delete_references'] !== [],
            'disable_references' => $summary['disable_references'],
            'delete_references' => $summary['delete_references'],
        ];
    }

    public function assertBeforeSave(string $resource, ?Model $record, array $payload): void
    {
        if ($record === null || ! $this->supportsEnableToggle($record, $payload)) {
            return;
        }

        $currentEnabled = (bool) $record->getAttribute('is_enabled');
        $nextEnabled = (bool) ($payload['is_enabled'] ?? $currentEnabled);

        if (! $currentEnabled || $nextEnabled) {
            return;
        }

        $summary = $this->inspectRecord($resource, $record);

        if (! $summary['block_disable']) {
            return;
        }

        throw new BusinessException(
            ErrorCode::ADMIN_OPERATION_FORBIDDEN,
            $this->buildBlockedMessage('禁用', $summary['disable_references'])
        );
    }

    public function assertBeforeDelete(string $resource, Model $record): void
    {
        $summary = $this->inspectRecord($resource, $record);

        if (! $summary['block_delete']) {
            return;
        }

        throw new BusinessException(
            ErrorCode::ADMIN_OPERATION_FORBIDDEN,
            $this->buildBlockedMessage('删除', $summary['delete_references'])
        );
    }

    public function findConfigRecord(string $resource, string $recordKey): Model
    {
        $definition = $this->getConfigDefinition($resource);
        $modelClass = $definition['model'];
        $primaryKey = $definition['primary_key'];
        $record = $modelClass::query()
            ->where($primaryKey, $recordKey)
            ->first();

        if ($record === null) {
            throw new BusinessException(ErrorCode::RESOURCE_NOT_FOUND, '配置记录不存在');
        }

        return $record;
    }

    private function getConfigDefinition(string $resource): array
    {
        $definition = $this->adminResourceRegistry->get($resource);

        if (($definition['mode'] ?? null) !== 'config') {
            throw new NotFoundHttpException();
        }

        return $definition;
    }

    private function buildReferenceSummary(string $resource, Model $record): array
    {
        $disableReferences = [];
        $deleteReferences = [];

        match ($resource) {
            'chapters' => $this->pushReference(
                $disableReferences,
                $deleteReferences,
                $this->buildReference(
                    '关卡引用',
                    ChapterStage::query()->where('chapter_id', (string) $record->getAttribute('chapter_id'))->orderBy('stage_order'),
                    'stage_id'
                )
            ),
            'stages' => $this->pushReference(
                $disableReferences,
                $deleteReferences,
                $this->buildReference(
                    '关卡难度引用',
                    StageDifficulty::query()->where('stage_id', (string) $record->getAttribute('stage_id'))->orderBy('difficulty_order'),
                    'stage_difficulty_id'
                )
            ),
            'stage-difficulties' => $this->buildStageDifficultyReferences($record, $disableReferences, $deleteReferences),
            'monsters' => $this->buildMonsterReferences($record, $disableReferences, $deleteReferences),
            'drop-groups' => $this->pushReference(
                $disableReferences,
                $deleteReferences,
                $this->buildReference(
                    '掉落来源绑定引用',
                    DropGroupBinding::query()->where('drop_group_id', (string) $record->getAttribute('drop_group_id'))->orderBy('source_type')->orderBy('source_id'),
                    static fn (DropGroupBinding $binding): string => sprintf('%s / %s', $binding->source_type, $binding->source_id)
                )
            ),
            'reward-groups' => $this->buildRewardGroupReferences($record, $disableReferences, $deleteReferences),
            'items' => $this->buildItemReferences($record, $disableReferences, $deleteReferences),
            'equipment-templates' => $this->pushReference(
                $disableReferences,
                $deleteReferences,
                $this->buildReference(
                    '装备实例引用',
                    InventoryEquipmentInstance::query()->where('item_id', (string) $record->getAttribute('item_id'))->orderByDesc('equipment_instance_id'),
                    'equipment_instance_id'
                )
            ),
            default => null,
        };

        return [
            'disable_references' => $disableReferences,
            'delete_references' => $deleteReferences,
        ];
    }

    private function buildStageDifficultyReferences(Model $record, array &$disableReferences, array &$deleteReferences): void
    {
        $stageDifficultyId = (string) $record->getAttribute('stage_difficulty_id');

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '怪物绑定引用',
                StageMonsterBinding::query()->where('stage_difficulty_id', $stageDifficultyId)->orderBy('wave_no')->orderBy('sort_order'),
                static fn (StageMonsterBinding $binding): string => sprintf('wave %d / %s', $binding->wave_no, $binding->monster_id)
            )
        );

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '奖励来源绑定引用',
                RewardGroupBinding::query()
                    ->where('source_type', RewardSourceType::FIRST_CLEAR->value)
                    ->where('source_id', $stageDifficultyId)
                    ->orderByDesc('id'),
                static fn (RewardGroupBinding $binding): string => (string) $binding->reward_group_id
            )
        );

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                'Battle Context 业务记录引用',
                BattleContext::query()->where('stage_difficulty_id', $stageDifficultyId)->orderByDesc('created_at'),
                'battle_context_id',
                ['delete']
            )
        );

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '发奖记录业务引用',
                UserRewardGrant::query()
                    ->where('source_type', RewardSourceType::FIRST_CLEAR->value)
                    ->where('source_id', $stageDifficultyId)
                    ->orderByDesc('reward_grant_id'),
                'reward_grant_id',
                ['delete']
            )
        );
    }

    private function buildMonsterReferences(Model $record, array &$disableReferences, array &$deleteReferences): void
    {
        $monsterId = (string) $record->getAttribute('monster_id');

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '关卡怪物绑定引用',
                StageMonsterBinding::query()->where('monster_id', $monsterId)->orderBy('stage_difficulty_id')->orderBy('wave_no'),
                static fn (StageMonsterBinding $binding): string => sprintf('%s / wave %d', $binding->stage_difficulty_id, $binding->wave_no)
            )
        );

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '掉落来源绑定引用',
                DropGroupBinding::query()
                    ->where('source_type', DropSourceType::MONSTER->value)
                    ->where('source_id', $monsterId)
                    ->orderByDesc('id'),
                static fn (DropGroupBinding $binding): string => (string) $binding->drop_group_id
            )
        );
    }

    private function buildRewardGroupReferences(Model $record, array &$disableReferences, array &$deleteReferences): void
    {
        $rewardGroupId = (string) $record->getAttribute('reward_group_id');

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '奖励来源绑定引用',
                RewardGroupBinding::query()->where('reward_group_id', $rewardGroupId)->orderBy('source_type')->orderBy('source_id'),
                static fn (RewardGroupBinding $binding): string => sprintf(
                    '%s / %s',
                    data_get($binding, 'source_type.value', $binding->source_type),
                    $binding->source_id
                )
            )
        );

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '发奖记录业务引用',
                UserRewardGrant::query()->where('reward_group_id', $rewardGroupId)->orderByDesc('reward_grant_id'),
                'reward_grant_id',
                ['delete']
            )
        );
    }

    private function buildItemReferences(Model $record, array &$disableReferences, array &$deleteReferences): void
    {
        $itemId = (string) $record->getAttribute('item_id');

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '装备模板引用',
                Equipment::query()->where('item_id', $itemId)->orderBy('item_id'),
                'item_id'
            )
        );

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '掉落组明细引用',
                DropGroupItem::query()->where('item_id', $itemId)->orderBy('drop_group_id')->orderBy('sort_order'),
                static fn (DropGroupItem $item): string => sprintf('%s / #%d', $item->drop_group_id, $item->sort_order)
            )
        );

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '奖励组明细引用',
                RewardGroupItem::query()->where('item_id', $itemId)->orderBy('reward_group_id')->orderBy('sort_order'),
                static fn (RewardGroupItem $item): string => sprintf('%s / #%d', $item->reward_group_id, $item->sort_order)
            )
        );

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '可堆叠背包业务引用',
                InventoryStackItem::query()->where('item_id', $itemId)->orderByDesc('updated_at'),
                static fn (InventoryStackItem $item): string => sprintf('user %d', $item->user_id),
                ['delete']
            )
        );

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '发奖明细业务引用',
                UserRewardGrantItem::query()->where('item_id', $itemId)->orderByDesc('reward_grant_id'),
                static fn (UserRewardGrantItem $item): string => sprintf('grant %d', $item->reward_grant_id),
                ['delete']
            )
        );

        $this->pushReference(
            $disableReferences,
            $deleteReferences,
            $this->buildReference(
                '装备实例业务引用',
                InventoryEquipmentInstance::query()->where('item_id', $itemId)->orderByDesc('equipment_instance_id'),
                'equipment_instance_id',
                ['delete']
            )
        );
    }

    private function buildReference(
        string $label,
        Builder $query,
        string|callable $exampleResolver,
        array $blockActions = ['disable', 'delete']
    ): ?array {
        $count = (clone $query)->count();

        if ($count === 0) {
            return null;
        }

        $examples = (clone $query)
            ->limit(5)
            ->get()
            ->map(function (Model $model) use ($exampleResolver): string {
                if (is_callable($exampleResolver)) {
                    return (string) $exampleResolver($model);
                }

                return (string) data_get($model, $exampleResolver);
            })
            ->filter(static fn (string $value): bool => $value !== '')
            ->values()
            ->all();

        return [
            'label' => $label,
            'count' => $count,
            'examples' => $examples,
            'block_actions' => $blockActions,
        ];
    }

    private function pushReference(array &$disableReferences, array &$deleteReferences, ?array $reference): void
    {
        if ($reference === null) {
            return;
        }

        if (in_array('disable', $reference['block_actions'], true)) {
            $disableReferences[] = $reference;
        }

        if (in_array('delete', $reference['block_actions'], true)) {
            $deleteReferences[] = $reference;
        }
    }

    private function buildBlockedMessage(string $action, array $references): string
    {
        $segments = array_map(
            static fn (array $reference): string => sprintf('%s(%d)', $reference['label'], $reference['count']),
            $references
        );

        return sprintf('当前配置仍存在下游引用，禁止%s：%s', $action, implode('、', $segments));
    }

    private function buildRecordLabel(string $resource, Model $record): string
    {
        return match ($resource) {
            'chapters' => (string) $record->getAttribute('chapter_name'),
            'stages' => (string) $record->getAttribute('stage_name'),
            'stage-difficulties' => (string) $record->getAttribute('difficulty_name'),
            'monsters' => (string) $record->getAttribute('monster_name'),
            'drop-groups' => (string) $record->getAttribute('drop_group_name'),
            'reward-groups' => (string) $record->getAttribute('reward_group_name'),
            'items' => (string) $record->getAttribute('item_name'),
            'equipment-templates' => (string) $record->getAttribute('item_id'),
            default => (string) $record->getKey(),
        };
    }

    private function supportsEnableToggle(Model $record, array $payload): bool
    {
        return array_key_exists('is_enabled', $payload) || array_key_exists('is_enabled', $record->getAttributes());
    }
}
