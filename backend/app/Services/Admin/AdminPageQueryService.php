<?php

namespace App\Services\Admin;

use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class AdminPageQueryService
{
    public function __construct(
        private readonly AdminResourceRegistry $adminResourceRegistry,
        private readonly AdminCrudService $adminCrudService,
    ) {
    }

    public function buildIndexPageData(string $resource, Request $request): array
    {
        $definition = $this->adminResourceRegistry->get($resource);
        /** @var Builder $query */
        $query = value($definition['query']);
        $filters = $request->only(array_map(
            static fn (array $filter): string => $filter['name'],
            $definition['filters'] ?? []
        ));

        if (isset($definition['apply_filters'])) {
            value($definition['apply_filters'], $query, $filters);
        }

        /** @var LengthAwarePaginator $paginator */
        $paginator = $query->paginate(20)->appends($filters);

        return [
            'title' => $definition['title'],
            'resource' => $resource,
            'mode' => $definition['mode'],
            'navigation' => $this->adminResourceRegistry->navigation(),
            'columns' => array_map(static fn (array $column): string => $column['label'], $definition['columns']),
            'rows' => array_map(
                fn (Model $row): array => $this->transformRow($definition, $resource, $row),
                $paginator->items()
            ),
            'filters' => $this->resolveInputs($definition['filters'] ?? [], $filters, null, false),
            'paginator' => $paginator,
        ];
    }

    public function buildFormPageData(string $resource, ?string $recordKey = null): array
    {
        $definition = $this->adminResourceRegistry->get($resource);

        if (($definition['mode'] ?? null) !== 'config') {
            throw new NotFoundHttpException();
        }

        $record = $recordKey === null ? null : $this->adminCrudService->findRecordByResource($resource, $recordKey);

        return [
            'title' => $record === null ? '新建'.$definition['title'] : '编辑'.$definition['title'],
            'page_title' => $definition['title'],
            'resource' => $resource,
            'navigation' => $this->adminResourceRegistry->navigation(),
            'fields' => $this->resolveInputs($definition['fields'], [], $record, true),
            'form_action' => $record === null
                ? route('admin.resources.store', ['resource' => $resource])
                : route('admin.resources.update', ['resource' => $resource, 'record' => $record->getAttribute($definition['primary_key'])]),
            'form_method' => $record === null ? 'POST' : 'PUT',
            'back_url' => route('admin.resources.index', ['resource' => $resource]),
        ];
    }

    private function transformRow(array $definition, string $resource, Model $row): array
    {
        $rowData = [
            'cells' => array_map(
                fn (array $column): string => $this->normalizeValue(value($column['value'], $row)),
                $definition['columns']
            ),
        ];

        if (($definition['mode'] ?? null) === 'config') {
            $rowData['edit_url'] = route('admin.resources.edit', [
                'resource' => $resource,
                'record' => $row->getAttribute($definition['primary_key']),
            ]);
        }

        return $rowData;
    }

    private function resolveInputs(array $inputs, array $currentValues = [], ?Model $record = null, bool $forForm = false): array
    {
        return array_map(function (array $input) use ($currentValues, $record, $forForm): array {
            $value = $forForm
                ? old($input['name'], $record?->getAttribute($input['name']) ?? ($input['default'] ?? (($input['type'] ?? 'text') === 'checkbox' ? false : '')))
                : ($currentValues[$input['name']] ?? '');

            return $input + [
                'value' => $value,
                'options_resolved' => isset($input['options']) ? value($input['options']) : [],
                'readonly' => $forForm && ($record !== null) && ($input['readonly_on_edit'] ?? false),
            ];
        }, $inputs);
    }

    private function normalizeValue(mixed $value): string
    {
        if ($value === null || $value === '') {
            return '-';
        }

        if (is_bool($value)) {
            return $value ? '是' : '否';
        }

        if (is_array($value)) {
            return json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?: '-';
        }

        return (string) $value;
    }
}
