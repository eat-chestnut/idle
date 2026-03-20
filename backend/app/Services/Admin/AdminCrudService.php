<?php

namespace App\Services\Admin;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class AdminCrudService
{
    public function __construct(
        private readonly AdminResourceRegistry $adminResourceRegistry,
        private readonly AdminConfigValidationService $adminConfigValidationService,
        private readonly AdminReferenceCheckService $adminReferenceCheckService,
    ) {
    }

    public function store(string $resource, array $input): Model
    {
        $definition = $this->getConfigDefinition($resource);
        $validated = $this->adminConfigValidationService->validate($resource, $input);
        $payload = value($definition['payload'], $validated, null);
        $modelClass = $definition['model'];
        $this->adminReferenceCheckService->assertBeforeSave($resource, null, $payload);

        return DB::transaction(static fn (): Model => $modelClass::query()->create($payload));
    }

    public function update(string $resource, string $recordKey, array $input): Model
    {
        $definition = $this->getConfigDefinition($resource);
        $record = $this->findRecord($definition, $recordKey);
        $validated = $this->adminConfigValidationService->validate($resource, $input, $record);
        $payload = value($definition['payload'], $validated, $record);
        $this->adminReferenceCheckService->assertBeforeSave($resource, $record, $payload);

        return DB::transaction(function () use ($record, $payload): Model {
            $record->fill($payload);
            $record->save();

            return $record->refresh();
        });
    }

    public function findRecordByResource(string $resource, string $recordKey): Model
    {
        return $this->findRecord($this->getConfigDefinition($resource), $recordKey);
    }

    public function delete(string $resource, string $recordKey): void
    {
        $definition = $this->getConfigDefinition($resource);
        $record = $this->findRecord($definition, $recordKey);
        $this->adminReferenceCheckService->assertBeforeDelete($resource, $record);

        DB::transaction(static fn () => $record->delete());
    }

    private function getConfigDefinition(string $resource): array
    {
        $definition = $this->adminResourceRegistry->get($resource);

        if (($definition['mode'] ?? null) !== 'config') {
            throw new NotFoundHttpException();
        }

        return $definition;
    }

    private function findRecord(array $definition, string $recordKey): Model
    {
        $modelClass = $definition['model'];
        $primaryKey = $definition['primary_key'];
        $record = $modelClass::query()
            ->where($primaryKey, $recordKey)
            ->first();

        if ($record === null) {
            throw new NotFoundHttpException();
        }

        return $record;
    }
}
