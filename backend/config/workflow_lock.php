<?php

return [
    'store' => env('WORKFLOW_LOCK_STORE', env('CACHE_STORE', 'database')),
    'prefix' => env('WORKFLOW_LOCK_PREFIX', 'workflow_lock'),
];
