<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_reward_grants', function (Blueprint $table): void {
            $table->bigIncrements('reward_grant_id');
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('source_type');
            $table->string('source_id');
            $table->string('reward_group_id');
            $table->string('idempotency_key');
            $table->string('grant_status');
            $table->timestamp('granted_at')->nullable();
            $table->json('grant_payload_snapshot')->nullable();
            $table->timestamps();

            $table->foreign('reward_group_id')->references('reward_group_id')->on('reward_groups')->restrictOnDelete();
            $table->unique(['user_id', 'idempotency_key']);
            $table->unique(['user_id', 'source_type', 'source_id', 'reward_group_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_reward_grants');
    }
};
