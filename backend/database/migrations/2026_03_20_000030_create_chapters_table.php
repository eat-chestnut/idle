<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('chapters', function (Blueprint $table): void {
            $table->string('chapter_id')->primary();
            $table->string('chapter_name');
            $table->unsignedInteger('sort_order')->default(0);
            $table->boolean('is_enabled')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chapters');
    }
};
