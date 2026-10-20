<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Time-restricted access (FR-12, docs/knowledge/06-game-design.md): one
     * schedule per section, and the minutes each student played per day.
     * Times are wall-clock times in the school's time zone
     * (config reading_racoon.access.timezone).
     */
    public function up(): void
    {
        Schema::create('access_schedules', function (Blueprint $table) {
            $table->foreignId('section_id')->primary()->constrained()->cascadeOnDelete();
            $table->time('class_start');
            $table->time('class_end');
            $table->time('after_school_start');
            $table->time('after_school_end');
            $table->smallInteger('daily_minutes')->default(30);
            $table->boolean('weekends_open')->default(false);
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestampsTz();
        });

        // Projection of the synced "usage" events. `minutes` counts toward the
        // daily cap; minutes played inside the class window don't.
        Schema::create('daily_usage', function (Blueprint $table) {
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->date('date');
            $table->integer('minutes')->default(0);
            $table->integer('class_minutes')->default(0);
            $table->timestampsTz();

            $table->primary(['student_id', 'date']);
        });

        DB::statement('ALTER TABLE access_schedules ADD CONSTRAINT access_schedules_windows_check CHECK (class_start < class_end AND after_school_start < after_school_end)');
        DB::statement('ALTER TABLE access_schedules ADD CONSTRAINT access_schedules_daily_minutes_check CHECK (daily_minutes BETWEEN 0 AND 240)');
        DB::statement('ALTER TABLE daily_usage ADD CONSTRAINT daily_usage_minutes_check CHECK (minutes >= 0 AND class_minutes >= 0)');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('daily_usage');
        Schema::dropIfExists('access_schedules');
    }
};
