<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('battle_contexts', function (Blueprint $table): void {
            $table->string('battle_context_id')->primary();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->unsignedBigInteger('character_id');
            $table->string('stage_difficulty_id');
            $table->string('status');
            $table->timestamp('settled_at')->nullable();
            $table->timestamps();

            $table->foreign('character_id')->references('character_id')->on('characters')->cascadeOnDelete();
            $table->foreign('stage_difficulty_id')->references('stage_difficulty_id')->on('stage_difficulties')->cascadeOnDelete();
            $table->index(['user_id', 'character_id', 'stage_difficulty_id'], 'battle_contexts_owner_index');
            $table->index(['status', 'created_at'], 'battle_contexts_status_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('battle_contexts');
    }
};
