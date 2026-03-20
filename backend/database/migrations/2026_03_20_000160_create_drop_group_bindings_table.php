<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('drop_group_bindings', function (Blueprint $table): void {
            $table->id();
            $table->string('source_type');
            $table->string('source_id');
            $table->string('drop_group_id');
            $table->timestamps();

            $table->foreign('drop_group_id')->references('drop_group_id')->on('drop_groups')->cascadeOnDelete();
            $table->unique(['source_type', 'source_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('drop_group_bindings');
    }
};
