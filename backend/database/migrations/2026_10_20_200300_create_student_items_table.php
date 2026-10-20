<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Raccoon customisations a student bought, and which are equipped (FR-07).
     * Projection of the synced "purchase" and "equip" events. Item ids come from
     * the game's shop catalogue.
     */
    public function up(): void
    {
        Schema::create('student_items', function (Blueprint $table) {
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->string('item_id', 64);
            $table->string('slot', 32)->nullable();
            $table->boolean('equipped')->default(false);
            $table->integer('cost')->default(0);
            $table->timestampTz('acquired_at');
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
