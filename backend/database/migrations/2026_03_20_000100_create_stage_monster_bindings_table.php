<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stage_monster_bindings', function (Blueprint $table): void {
            $table->id();
            $table->string('stage_difficulty_id');
            $table->string('monster_id');
            $table->string('monster_role');
            $table->unsignedInteger('wave_no');
            $table->unsignedInteger('sort_order');
            $table->timestamps();

            $table->foreign('stage_difficulty_id')->references('stage_difficulty_id')->on('stage_difficulties')->cascadeOnDelete();
            $table->foreign('monster_id')->references('monster_id')->on('monsters')->cascadeOnDelete();
            $table->index(['stage_difficulty_id', 'wave_no', 'sort_order'], 'stage_monster_bindings_order_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stage_monster_bindings');
    }
};
