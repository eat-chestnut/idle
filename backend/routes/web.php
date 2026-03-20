<?php

use App\Http\Controllers\Admin\AdminDashboardController;
use App\Http\Controllers\Admin\AdminResourceController;
use App\Http\Controllers\Admin\AdminToolController;
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
        Route::get('tools', [AdminToolController::class, 'index'])->name('tools.index');
        Route::post('tools/reference-check', [AdminToolController::class, 'checkReferences'])->name('tools.reference-check');
        Route::post('tools/reward-retry', [AdminToolController::class, 'retryReward'])->name('tools.reward-retry');
        Route::post('tools/repair-battle-context', [AdminToolController::class, 'repairBattleContext'])->name('tools.repair-battle-context');
        Route::post('tools/repair-reward-grant', [AdminToolController::class, 'repairRewardGrant'])->name('tools.repair-reward-grant');

        Route::prefix('resources')->name('resources.')->group(function (): void {
            Route::get('{resource}', [AdminResourceController::class, 'index'])->name('index');
            Route::get('{resource}/create', [AdminResourceController::class, 'create'])->name('create');
            Route::post('{resource}', [AdminResourceController::class, 'store'])->name('store');
            Route::get('{resource}/{record}/edit', [AdminResourceController::class, 'edit'])->name('edit');
            Route::put('{resource}/{record}', [AdminResourceController::class, 'update'])->name('update');
            Route::delete('{resource}/{record}', [AdminResourceController::class, 'destroy'])->name('destroy');
        });
    });
});
