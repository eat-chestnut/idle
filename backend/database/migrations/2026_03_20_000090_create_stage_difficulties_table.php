<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stage_difficulties', function (Blueprint $table): void {
            $table->string('stage_difficulty_id')->primary();
            $table->string('stage_id');
            $table->string('difficulty_key');
            $table->string('difficulty_name');
            $table->unsignedInteger('recommended_power')->default(0);
            $table->unsignedInteger('difficulty_order')->default(0);
            $table->boolean('is_enabled')->default(true);
            $table->timestamps();

            $table->foreign('stage_id')->references('stage_id')->on('chapter_stages')->cascadeOnDelete();
            $table->unique(['stage_id', 'difficulty_key']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stage_difficulties');
    }
};
