<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Raw log of the gameplay events the client queues offline and uploads to
     * POST /api/sync (FR-11, docs/knowledge/03-architecture.md "Offline and sync").
     */
    public function up(): void
    {
        Schema::create('sync_events', function (Blueprint $table) {
            // Arrival order. Device times have 1-second resolution, so replays
            // (server-side BKT) order by id, which follows the client's queue order.
            $table->id();
            // The client's UUIDv4: the idempotency key, so retried batches never duplicate.
            $table->uuid('uuid')->unique();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->string('type', 32);
            $table->jsonb('payload');
            $table->timestampTz('device_time', 6);
            $table->timestampTz('received_at', 6)->useCurrent();

            $table->index(['student_id', 'type']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sync_events');
    }
};
