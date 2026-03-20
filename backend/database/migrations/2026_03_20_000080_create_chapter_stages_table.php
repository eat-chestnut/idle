<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('chapter_stages', function (Blueprint $table): void {
            $table->string('stage_id')->primary();
            $table->string('chapter_id');
            $table->string('stage_name');
            $table->unsignedInteger('stage_order')->default(0);
            $table->boolean('is_enabled')->default(true);
            $table->timestamps();

            $table->foreign('chapter_id')->references('chapter_id')->on('chapters')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chapter_stages');
    }
};
