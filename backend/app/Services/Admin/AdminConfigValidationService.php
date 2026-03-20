<?php

namespace App\Services\Admin;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class AdminConfigValidationService
{
    public function __construct(
        private readonly AdminResourceRegistry $adminResourceRegistry,
    ) {
    }

    /**
     * @throws ValidationException
     */
    public function validate(string $resource, array $input, ?Model $record = null): array
    {
        $definition = $this->adminResourceRegistry->get($resource);
        $normalizedInput = $this->normalizeCheckboxFields($definition, $input);
        $rules = value($definition['rules'], $record, $normalizedInput);
        $attributes = $definition['attributes'] ?? [];
        $validator = Validator::make($normalizedInput, $rules, [], $attributes);

        if (isset($definition['after_validation'])) {
            value($definition['after_validation'], $validator, $record, $normalizedInput);
        }

        return $validator->validate();
    }

    private function normalizeCheckboxFields(array $definition, array $input): array
    {
        foreach ($definition['fields'] ?? [] as $field) {
            if (($field['type'] ?? 'text') !== 'checkbox') {
                continue;
            }

            $input[$field['name']] = array_key_exists($field['name'], $input);
        }

        return $input;
    }
}
