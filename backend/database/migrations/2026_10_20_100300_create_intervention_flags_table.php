<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Teacher alerts (FR-17): a failed Heart Recovery (rescue_partial), the
     * recovery limit (rescue_limit), or low P(L) after 5+ attempts (low_mastery).
     */
    public function up(): void
    {
        Schema::create('intervention_flags', function (Blueprint $table) {
            // Flags are raised offline on the device, so the key is a UUID: the id of
            // the "flag" sync event that raised it, or a new one for server-side flags.
            $table->uuid('id')->primary();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->string('type', 32);
            $table->string('sub_skill', 32)->nullable();
            $table->smallInteger('level')->nullable();
            $table->jsonb('details')->default('{}');
            $table->string('status', 16)->default('open');
            $table->timestampTz('raised_at');
            $table->timestampTz('resolved_at')->nullable();
            $table->foreignId('resolved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestampsTz();

            $table->index(['student_id', 'status']);
        });

        DB::statement("ALTER TABLE intervention_flags ADD CONSTRAINT intervention_flags_status_check CHECK (status IN ('open', 'resolved'))");
        DB::statement('ALTER TABLE intervention_flags ADD CONSTRAINT intervention_flags_level_check CHECK (level BETWEEN 1 AND 5)');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('intervention_flags');
    }
};
