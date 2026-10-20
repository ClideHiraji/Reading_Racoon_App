<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * One row per student for the learning path and the reward wallet.
     */
    public function up(): void
    {
        // Highest unlocked map level (the ARAL band comes from it, D-003) and the
        // client's per-world path state, {"1": {"done": 2, "chest": false, "bonus": []}}
        // (PathProgress.to_dict, D-007). jsonb because the path layout is UI detail.
        Schema::create('path_progress', function (Blueprint $table) {
            $table->foreignId('student_id')->primary()->constrained()->cascadeOnDelete();
            $table->smallInteger('highest_unlocked')->default(1);
            $table->jsonb('worlds')->default('{}');
            $table->timestampsTz();
        });

        // XP and coin balance (FR-07, FR-15). The shop's purchase ledger comes later.
        Schema::create('student_wallets', function (Blueprint $table) {
            $table->foreignId('student_id')->primary()->constrained()->cascadeOnDelete();
            $table->integer('xp')->default(0);
            $table->integer('coins')->default(0);
            $table->timestampsTz();
        });

        DB::statement('ALTER TABLE path_progress ADD CONSTRAINT path_progress_highest_unlocked_check CHECK (highest_unlocked BETWEEN 1 AND 5)');
        DB::statement('ALTER TABLE student_wallets ADD CONSTRAINT student_wallets_balance_check CHECK (xp >= 0 AND coins >= 0)');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('student_wallets');
        Schema::dropIfExists('path_progress');
    }
};
