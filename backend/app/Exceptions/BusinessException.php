<?php

namespace App\Exceptions;

use App\Support\ErrorCode;
use RuntimeException;

class BusinessException extends RuntimeException
{
    public function __construct(
        protected readonly int $errorCode,
        ?string $message = null,
        ?\Throwable $previous = null
    ) {
        parent::__construct($message ?? ErrorCode::message($errorCode), $errorCode, $previous);
    }

    public function getErrorCode(): int
    {
        return $this->errorCode;
    }
}
