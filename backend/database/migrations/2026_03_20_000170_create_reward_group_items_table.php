<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reward_group_items', function (Blueprint $table): void {
            $table->id();
            $table->string('reward_group_id');
            $table->string('item_id');
            $table->unsignedInteger('quantity');
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->foreign('reward_group_id')->references('reward_group_id')->on('reward_groups')->cascadeOnDelete();
            $table->foreign('item_id')->references('item_id')->on('items')->restrictOnDelete();
            $table->index(['reward_group_id', 'sort_order'], 'reward_group_items_order_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reward_group_items');
    }
};
