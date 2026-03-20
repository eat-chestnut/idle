<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('drop_group_items', function (Blueprint $table): void {
            $table->id();
            $table->string('drop_group_id');
            $table->string('item_id');
            $table->unsignedInteger('weight');
            $table->unsignedInteger('min_quantity');
            $table->unsignedInteger('max_quantity');
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->foreign('drop_group_id')->references('drop_group_id')->on('drop_groups')->cascadeOnDelete();
            $table->foreign('item_id')->references('item_id')->on('items')->restrictOnDelete();
            $table->index(['drop_group_id', 'sort_order'], 'drop_group_items_order_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('drop_group_items');
    }
};
