<?php

namespace App\Enums\Reward;

enum GrantStatus: string
{
    case PENDING = 'pending';
    case SUCCESS = 'success';
    case FAILED = 'failed';
}
