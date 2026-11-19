<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Logs for the admin portal (FR-08, FR-22, NFR-04).
     *
     * - audit_logs: every admin and teacher action. Append-only: a trigger
     *   refuses UPDATE and DELETE, so no one can quietly rewrite history.
     *   actor_id has no foreign key for the same reason (deleting a user must
     *   not touch their audit trail).
     * - system_logs: what the system saw (sign-ins, failed sign-ins, access
     *   decisions, sync problems, server errors), with an anomaly flag.
     */
    public function up(): void
    {
        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('actor_id')->nullable();
            $table->string('actor_role', 16)->nullable();
            // Email or name at the time of the action, kept after the account is gone.
            $table->string('actor_label', 255)->nullable();
            $table->string('action', 64);
            $table->string('subject_type', 64)->nullable();
            $table->string('subject_id', 64)->nullable();
            $table->jsonb('details')->default('{}');
            $table->string('ip', 45)->nullable();
            $table->string('user_agent', 255)->nullable();
            $table->timestampTz('created_at', 6)->useCurrent();

            $table->index('created_at');
            $table->index(['actor_id', 'created_at']);
            $table->index('action');
        });

        // OR REPLACE: migrate:fresh drops tables but not functions.
        DB::unprepared(<<<'SQL'
            CREATE OR REPLACE FUNCTION audit_logs_append_only() RETURNS trigger AS $$
            BEGIN
                RAISE EXCEPTION 'audit_logs is append-only';
            END;
            $$ LANGUAGE plpgsql;

            CREATE TRIGGER audit_logs_no_update_or_delete
                BEFORE UPDATE OR DELETE ON audit_logs
                FOR EACH ROW EXECUTE FUNCTION audit_logs_append_only();
            SQL);

        Schema::create('system_logs', function (Blueprint $table) {
            $table->id();
            $table->string('level', 16)->default('info');
            $table->string('event', 64);
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('ip', 45)->nullable();
            $table->jsonb('context')->default('{}');
            $table->boolean('anomaly')->default(false);
            $table->timestampTz('created_at', 6)->useCurrent();

            $table->index('created_at');
            $table->index(['event', 'created_at']);
            $table->index(['anomaly', 'created_at']);
        });

        DB::statement("ALTER TABLE system_logs ADD CONSTRAINT system_logs_level_check CHECK (level IN ('info', 'warning', 'error', 'critical'))");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('system_logs');
        Schema::dropIfExists('audit_logs');
        DB::unprepared('DROP FUNCTION IF EXISTS audit_logs_append_only()');
    }
};
