<?php

namespace App\Support;

final class ApiResponse
{
    public static function success(mixed $data = null): array
    {
        return [
            'code' => ErrorCode::OK,
            'message' => 'ok',
            'data' => $data,
        ];
    }

    public static function error(int $code, ?string $message = null): array
    {
        return [
            'code' => $code,
            'message' => $message ?? ErrorCode::message($code),
            'data' => null,
        ];
    }
}
