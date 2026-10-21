<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Teacher self-registration waits for an admin's decision (FR-08).
     * A teacher can sign in only while their registration is approved.
     */
    public function up(): void
    {
        Schema::create('teacher_registrations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('school', 150)->nullable();
            $table->string('status', 16)->default('pending');
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestampTz('reviewed_at')->nullable();
            $table->string('review_note', 500)->nullable();
            $table->timestampsTz();

            $table->index('status');
        });

        DB::statement("ALTER TABLE teacher_registrations ADD CONSTRAINT teacher_registrations_status_check CHECK (status IN ('pending', 'approved', 'denied'))");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('teacher_registrations');
    }
};
