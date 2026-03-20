<?php

namespace App\Http\Controllers\Admin\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Auth\AdminLoginRequest;
use App\Services\Admin\AdminAuthService;
use Illuminate\Http\RedirectResponse;
use Illuminate\View\View;

class AdminAuthController extends Controller
{
    public function __construct(
        private readonly AdminAuthService $adminAuthService,
    ) {
    }

    public function showLogin(): View
    {
        return view('admin.auth.login');
    }

    public function login(AdminLoginRequest $request): RedirectResponse
    {
        if (! $this->adminAuthService->attempt(
            (string) $request->validated()['username'],
            (string) $request->validated()['password'],
            $request
        )) {
            return back()
                ->withInput($request->safe()->only(['username']))
                ->withErrors([
                    'username' => '账号或密码错误',
                ]);
        }

        return redirect()->route('admin.dashboard');
    }

    public function logout(): RedirectResponse
    {
        $this->adminAuthService->logout(request());

        return redirect()->route('admin.login');
    }
}
