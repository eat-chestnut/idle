<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('drop_groups', function (Blueprint $table): void {
            $table->string('drop_group_id')->primary();
            $table->string('drop_group_name');
            $table->string('roll_type');
            $table->unsignedInteger('roll_times')->default(1);
            $table->boolean('is_enabled')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('drop_groups');
    }
};
