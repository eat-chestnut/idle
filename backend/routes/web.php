<?php

use App\Http\Controllers\Admin\AdminDashboardController;
use App\Http\Controllers\Admin\AdminResourceController;
use App\Http\Controllers\Admin\Auth\AdminAuthController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::prefix('admin')->name('admin.')->group(function (): void {
    Route::middleware('guest:admin')->group(function (): void {
        Route::get('login', [AdminAuthController::class, 'showLogin'])->name('login');
        Route::post('login', [AdminAuthController::class, 'login'])->name('login.submit');
    });

    Route::middleware('auth:admin')->group(function (): void {
        Route::get('', AdminDashboardController::class)->name('dashboard');
        Route::post('logout', [AdminAuthController::class, 'logout'])->name('logout');

        Route::prefix('resources')->name('resources.')->group(function (): void {
            Route::get('{resource}', [AdminResourceController::class, 'index'])->name('index');
            Route::get('{resource}/create', [AdminResourceController::class, 'create'])->name('create');
            Route::post('{resource}', [AdminResourceController::class, 'store'])->name('store');
            Route::get('{resource}/{record}/edit', [AdminResourceController::class, 'edit'])->name('edit');
            Route::put('{resource}/{record}', [AdminResourceController::class, 'update'])->name('update');
        });
    });
});
