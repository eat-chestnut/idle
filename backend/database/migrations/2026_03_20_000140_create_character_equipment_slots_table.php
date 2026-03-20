<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('character_equipment_slots', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('character_id');
            $table->string('slot_key');
            $table->unsignedBigInteger('equipped_instance_id')->nullable();
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->foreign('character_id')->references('character_id')->on('characters')->cascadeOnDelete();
            $table->foreign('equipped_instance_id')->references('equipment_instance_id')->on('inventory_equipment_instances')->nullOnDelete();
            $table->unique(['character_id', 'slot_key']);
            $table->unique('equipped_instance_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('character_equipment_slots');
    }
};
