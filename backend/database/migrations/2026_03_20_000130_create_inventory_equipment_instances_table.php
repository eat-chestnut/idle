<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventory_equipment_instances', function (Blueprint $table): void {
            $table->bigIncrements('equipment_instance_id');
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('item_id');
            $table->string('bind_type');
            $table->unsignedInteger('enhance_level')->default(0);
            $table->unsignedInteger('durability')->default(100);
            $table->unsignedInteger('max_durability')->default(100);
            $table->boolean('is_locked')->default(false);
            $table->json('extra_attributes')->nullable();
            $table->timestamps();

            $table->foreign('item_id')->references('item_id')->on('equipments')->restrictOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_equipment_instances');
    }
};
