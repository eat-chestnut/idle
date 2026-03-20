<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventory_stack_items', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('item_id');
            $table->unsignedInteger('quantity');
            $table->timestamps();

            $table->foreign('item_id')->references('item_id')->on('items')->restrictOnDelete();
            $table->unique(['user_id', 'item_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_stack_items');
    }
};
