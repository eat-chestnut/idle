<?php

use App\Http\Controllers\Api\Battle\BattleController;
use App\Http\Controllers\Api\Character\CharacterController;
use App\Http\Controllers\Api\Equipment\EquipmentController;
use App\Http\Controllers\Api\Inventory\InventoryController;
use App\Http\Controllers\Api\Stage\StageController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:api'])->group(function (): void {
    Route::get('chapters', [StageController::class, 'chapters']);
    Route::get('stages/{stage_id}/difficulties', [StageController::class, 'difficulties']);
    Route::get(
        'stage-difficulties/{stage_difficulty_id}/first-clear-reward-status',
        [StageController::class, 'firstClearRewardStatus']
    );

    Route::prefix('battles')->group(function (): void {
        Route::post('prepare', [BattleController::class, 'prepare']);
        Route::post('settle', [BattleController::class, 'settle']);
    });

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
