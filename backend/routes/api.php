<?php

use App\Http\Controllers\Api\Character\CharacterController;
use App\Http\Controllers\Api\Equipment\EquipmentController;
use App\Http\Controllers\Api\Inventory\InventoryController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:api'])->group(function (): void {
    Route::prefix('characters')->group(function (): void {
        Route::post('', [CharacterController::class, 'store']);
        Route::get('{character_id}', [CharacterController::class, 'show'])
            ->whereNumber('character_id');
        Route::get('{character_id}/equipment-slots', [CharacterController::class, 'equipmentSlots'])
            ->whereNumber('character_id');
        Route::post('{character_id}/equip', [EquipmentController::class, 'equip'])
            ->whereNumber('character_id');
        Route::post('{character_id}/unequip', [EquipmentController::class, 'unequip'])
            ->whereNumber('character_id');
    });

    Route::get('inventory', [InventoryController::class, 'index']);
});
