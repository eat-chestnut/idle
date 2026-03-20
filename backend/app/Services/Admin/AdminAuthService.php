<?php

namespace App\Services\Admin;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class AdminAuthService
{
    public function attempt(string $username, string $password, Request $request): bool
    {
        $authenticated = Auth::guard('admin')->attempt([
            'username' => $username,
            'password' => $password,
            'is_enabled' => true,
        ]);

        if ($authenticated) {
            $request->session()->regenerate();
        }

        return $authenticated;
    }

    public function logout(Request $request): void
    {
        Auth::guard('admin')->logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();
    }
}
