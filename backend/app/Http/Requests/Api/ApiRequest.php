<?php

namespace App\Http\Requests\Api;

use App\Exceptions\BusinessException;
use App\Support\ErrorCode;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;

abstract class ApiRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function failedValidation(Validator $validator): void
    {
        throw new BusinessException($this->validationErrorCode());
    }

    protected function validationErrorCode(): int
    {
        return ErrorCode::INVALID_PARAMS;
    }
}
