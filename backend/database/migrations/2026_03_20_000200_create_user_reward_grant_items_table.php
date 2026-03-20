<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_reward_grant_items', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('reward_grant_id');
            $table->string('item_id');
            $table->unsignedInteger('quantity');
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->foreign('reward_grant_id')->references('reward_grant_id')->on('user_reward_grants')->cascadeOnDelete();
            $table->foreign('item_id')->references('item_id')->on('items')->restrictOnDelete();
            $table->index(['reward_grant_id', 'sort_order'], 'user_reward_grant_items_order_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_reward_grant_items');
    }
};
