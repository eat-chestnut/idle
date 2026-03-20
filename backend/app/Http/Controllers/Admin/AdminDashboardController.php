<?php

namespace App\Http\Controllers\Admin;

use Illuminate\Http\RedirectResponse;

class AdminDashboardController
{
    public function __invoke(): RedirectResponse
    {
        return redirect()->route('admin.resources.index', ['resource' => 'battle-contexts']);
    }
}
