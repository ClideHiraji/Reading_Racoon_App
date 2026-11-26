<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Raccoon items a student bought, and which are worn. Built from the synced "purchase"
     * and "outfit" events. Item ids come from the shop list (reading_racoon.shop).
     */
    public function up(): void
    {
        Schema::create('student_items', function (Blueprint $table) {
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->string('item_id', 64);
            $table->string('slot', 32)->nullable();
            $table->boolean('equipped')->default(false);
            $table->integer('cost')->default(0);
            // Null for starter items, which every learner owns from the start.
            $table->timestampTz('acquired_at')->nullable();
            $table->timestampsTz();

            $table->primary(['student_id', 'item_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('student_items');
    }
};
