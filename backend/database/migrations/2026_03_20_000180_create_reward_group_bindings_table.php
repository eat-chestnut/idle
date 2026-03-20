<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reward_group_bindings', function (Blueprint $table): void {
            $table->id();
            $table->string('source_type');
            $table->string('source_id');
            $table->string('reward_group_id');
            $table->timestamps();

            $table->foreign('reward_group_id')->references('reward_group_id')->on('reward_groups')->cascadeOnDelete();
            $table->unique(['source_type', 'source_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reward_group_bindings');
    }
};
