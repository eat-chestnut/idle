<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('equipments', function (Blueprint $table): void {
            $table->string('item_id')->primary();
            $table->string('equipment_slot');
            $table->string('rarity');
            $table->unsignedInteger('level_required')->default(1);
            $table->string('weapon_category')->nullable();
            $table->string('sub_weapon_category')->nullable();
            $table->boolean('is_two_handed')->default(false);
            $table->unsignedInteger('attack')->default(0);
            $table->unsignedInteger('physical_defense')->default(0);
            $table->unsignedInteger('magic_defense')->default(0);
            $table->unsignedInteger('hp')->default(0);
            $table->unsignedInteger('mana')->default(0);
            $table->unsignedInteger('attack_speed')->default(0);
            $table->unsignedInteger('crit_rate')->default(0);
            $table->unsignedInteger('spell_power')->default(0);
            $table->boolean('is_enabled')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->foreign('item_id')->references('item_id')->on('items')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('equipments');
    }
};
