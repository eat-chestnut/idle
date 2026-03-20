<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('monsters', function (Blueprint $table): void {
            $table->string('monster_id')->primary();
            $table->string('monster_name');
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
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('monsters');
    }
};
