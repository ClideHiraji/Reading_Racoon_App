<?php

use App\Support\StudentCode;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Columns for the teacher dashboard and admin portal (FR-06, FR-08, FR-16, NFR-04):
     * section ownership, a pseudonymous student code for exports and LLM prompts,
     * the parental consent record, and admin TOTP 2FA.
     */
    public function up(): void
    {
        // The teacher who owns the section; policies let teachers see only their own (FR-06).
        Schema::table('sections', function (Blueprint $table) {
            $table->foreignId('teacher_id')->nullable()->after('id')->constrained('users')->nullOnDelete();
        });

        Schema::table('students', function (Blueprint $table) {
            // Pseudonym like "RR-7K2M9Q" for research exports and AI prompts (RA 10173).
            // Not a credential: the login code stays separate and hashed.
            $table->char('code', 9)->nullable()->unique()->after('section_id');
            // Parental consent form received (RA 10173). Research exports include consented learners only.
            $table->timestampTz('consent_recorded_at')->nullable();
            $table->foreignId('consent_recorded_by')->nullable()->constrained('users')->nullOnDelete();
        });

        foreach (DB::table('students')->whereNull('code')->pluck('id') as $id) {
            DB::table('students')->where('id', $id)->update(['code' => StudentCode::unique()]);
        }

        Schema::table('users', function (Blueprint $table) {
            // Admin TOTP secret, encrypted with APP_KEY (cast "encrypted" on the model).
            $table->text('two_factor_secret')->nullable();
            // Last accepted TOTP time step, so a code can't be replayed.
            $table->bigInteger('two_factor_last_step')->nullable();
            $table->timestampTz('last_login_at')->nullable();
            $table->string('last_login_ip', 45)->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['two_factor_secret', 'two_factor_last_step', 'last_login_at', 'last_login_ip']);
        });
        Schema::table('students', function (Blueprint $table) {
            $table->dropConstrainedForeignId('consent_recorded_by');
            $table->dropColumn(['code', 'consent_recorded_at']);
        });
        Schema::table('sections', function (Blueprint $table) {
            $table->dropConstrainedForeignId('teacher_id');
        });
    }
};
