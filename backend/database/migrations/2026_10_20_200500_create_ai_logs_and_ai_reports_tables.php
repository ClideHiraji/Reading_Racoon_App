<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * The Gemini teacher report (FR-05, FR-21, D-018).
     *
     * - ai_logs: every LLM call, failed ones too: task, prompt version, model,
     *   the JSON injected into the prompt (student code and scores, never a
     *   name), the reply, why it was refused, latency and tokens (MLDLC Stage 6).
     * - ai_reports: the AI-written paragraphs for one exact set of facts
     *   (facts_hash). paragraphs is null when every attempt failed and the
     *   template was used, so the same facts are not sent again.
     *
     * Both cascade with the student: removing a learner deletes all their data (RA 10173).
     */
    public function up(): void
    {
        Schema::create('ai_logs', function (Blueprint $table) {
            $table->id();
            $table->string('task', 32);
            $table->string('prompt_version', 32);
            $table->string('model', 64);
            $table->foreignId('student_id')->nullable()->constrained()->cascadeOnDelete();
            $table->jsonb('input');
            $table->text('output')->nullable();
            $table->string('status', 16);
            $table->string('error', 255)->nullable();
            $table->integer('latency_ms');
            $table->integer('prompt_tokens')->nullable();
            $table->integer('completion_tokens')->nullable();
            $table->timestampTz('created_at', 6)->useCurrent();

            $table->index('created_at');
            $table->index(['student_id', 'created_at']);
            $table->index(['status', 'created_at']);
        });

        DB::statement("ALTER TABLE ai_logs ADD CONSTRAINT ai_logs_status_check CHECK (status IN ('ok', 'invalid', 'blocked', 'error'))");

        Schema::create('ai_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->char('facts_hash', 64);
            $table->jsonb('paragraphs')->nullable();
            // The model id, or "template" when the AI output was not used.
            $table->string('generated_by', 64);
            $table->string('prompt_version', 32);
            $table->foreignId('ai_log_id')->nullable()->constrained('ai_logs')->nullOnDelete();
            $table->timestampTz('generated_at');

            $table->unique(['student_id', 'facts_hash']);
            $table->index(['student_id', 'generated_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ai_reports');
        Schema::dropIfExists('ai_logs');
    }
};
