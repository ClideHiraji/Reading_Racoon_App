<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Teacher-picked Library books and Watch & Listen videos (game D-017,
     * D-019), assigned to sections and sent to the game by
     * GET /api/content/manifest. Files (videos, page pictures) live on the
     * private disk under random names: no student data, no public URL (RA 10173).
     */
    public function up(): void
    {
        Schema::create('content_items', function (Blueprint $table) {
            // "tb-xxxxxxxx" (book) or "tv-xxxxxxxx" (video): the id the game stores.
            $table->string('id', 20)->primary();
            $table->string('kind', 8);
            $table->string('title', 150);
            $table->string('language', 3);
            $table->string('level', 8)->nullable();
            // Book cover or video scene: one of the game's paper-cut scenes.
            $table->string('scene', 16);
            $table->string('credit', 500);
            $table->string('licence', 40);
            $table->string('source_url', 500);
            $table->smallInteger('minutes')->nullable();
            // Book: words, pages, questions. Video: check. Same shapes as the game's JSON.
            $table->jsonb('body')->default('{}');
            $table->boolean('published')->default(false);
            $table->timestampTz('published_at')->nullable();
            $table->foreignId('owner_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestampsTz(6);

            $table->index(['owner_id', 'created_at']);
        });

        Schema::create('content_item_section', function (Blueprint $table) {
            $table->string('content_item_id', 20);
            $table->foreignId('section_id')->constrained()->cascadeOnDelete();
            $table->primary(['content_item_id', 'section_id']);
            $table->foreign('content_item_id')->references('id')->on('content_items')->cascadeOnDelete();
            $table->index('section_id');
        });

        Schema::create('content_files', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('content_item_id', 20);
            // "video" (one per video item) or "page_image" (one per book page).
            $table->string('role', 12);
            $table->smallInteger('page_index')->nullable();
            $table->string('path', 255);
            $table->string('mime', 64);
            $table->bigInteger('size_bytes');
            $table->char('sha256', 64);
            $table->timestampsTz();

            $table->foreign('content_item_id')->references('id')->on('content_items')->cascadeOnDelete();
            $table->index('content_item_id');
        });

        DB::statement("ALTER TABLE content_items ADD CONSTRAINT content_items_kind_check CHECK (kind IN ('book', 'video'))");
        DB::statement("ALTER TABLE content_items ADD CONSTRAINT content_items_language_check CHECK (language IN ('en', 'fil', 'bis'))");
        DB::statement("ALTER TABLE content_files ADD CONSTRAINT content_files_role_check CHECK (role IN ('video', 'page_image'))");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('content_files');
        Schema::dropIfExists('content_item_section');
        Schema::dropIfExists('content_items');
    }
};
