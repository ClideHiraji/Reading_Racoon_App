<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * The latest copy of the child's save file from the game (PUT /api/student/profile),
     * so another laptop can continue where they left off (GET /api/student/me).
     */
    public function up(): void
    {
        Schema::table('students', function (Blueprint $table) {
            $table->jsonb('profile')->nullable();
            $table->timestampTz('profile_saved_at', 6)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('students', function (Blueprint $table) {
            $table->dropColumn(['profile', 'profile_saved_at']);
        });
    }
};
