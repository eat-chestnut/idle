<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('characters', function (Blueprint $table): void {
            $table->bigIncrements('character_id');
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('class_id');
            $table->string('character_name');
            $table->unsignedInteger('level')->default(1);
            $table->unsignedInteger('exp')->default(0);
            $table->unsignedInteger('unspent_stat_points')->default(0);
            $table->unsignedInteger('added_strength')->default(0);
            $table->unsignedInteger('added_mana')->default(0);
            $table->unsignedInteger('added_constitution')->default(0);
            $table->unsignedInteger('added_dexterity')->default(0);
            $table->string('long_term_growth_stage')->nullable();
            $table->json('extra_context')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->foreign('class_id')->references('class_id')->on('classes')->restrictOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('characters');
    }
};
