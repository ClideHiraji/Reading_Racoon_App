<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * One BKT state per (student, sub-skill, level): 14 per student (D-003,
     * docs/knowledge/05-bkt-engine.md). FR-03, FR-04.
     */
    public function up(): void
    {
        Schema::create('bkt_states', function (Blueprint $table) {
            $table->id();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->string('sub_skill', 32);
            $table->smallInteger('level');
            // P(L) for the next opportunity, after the learning transition
            // (the client's StudentModel "p").
            $table->double('p_mastery');
            $table->integer('attempts')->default(0);
            $table->timestampTz('mastered_at')->nullable();
            // Un-mastered by a failed Heart Recovery and waiting to be shown again (D-004).
            $table->boolean('review')->default(false);
            $table->timestampsTz();

            $table->unique(['student_id', 'sub_skill', 'level']);
        });

        DB::statement("ALTER TABLE bkt_states ADD CONSTRAINT bkt_states_sub_skill_check CHECK (sub_skill IN (
            'phonological_awareness', 'phonics', 'vocabulary', 'fluency', 'literal_comprehension'))");
        DB::statement('ALTER TABLE bkt_states ADD CONSTRAINT bkt_states_level_check CHECK (level BETWEEN 1 AND 5)');
        DB::statement('ALTER TABLE bkt_states ADD CONSTRAINT bkt_states_p_mastery_check CHECK (p_mastery BETWEEN 0 AND 1)');
        DB::statement('ALTER TABLE bkt_states ADD CONSTRAINT bkt_states_attempts_check CHECK (attempts >= 0)');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('bkt_states');
    }
};
