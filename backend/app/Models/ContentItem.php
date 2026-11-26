<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

/**
 * A teacher-picked Library book or Watch & Listen video. `body` holds the same shapes as
 * the game's content JSON: words, pages and questions for a book; the optional check
 * question for a video.
 */
class ContentItem extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = ['title', 'language', 'level', 'scene', 'credit', 'licence', 'source_url', 'minutes', 'body'];

    protected function casts(): array
    {
        return [
            'body' => 'array',
            'minutes' => 'integer',
            'published' => 'boolean',
            'published_at' => 'datetime',
        ];
    }

    /** A new id: "tb-" for books, "tv-" for videos, then 8 random characters. */
    public static function newId(string $kind): string
    {
        do {
            $id = ($kind === 'book' ? 'tb-' : 'tv-').Str::lower(Str::random(8));
        } while (static::whereKey($id)->exists());

        return $id;
    }

    public function isBook(): bool
    {
        return $this->kind === 'book';
    }

    /**
     * @return BelongsToMany<Section, $this>
     */
    public function sections(): BelongsToMany
    {
        return $this->belongsToMany(Section::class, 'content_item_section');
    }

    /**
     * @return HasMany<ContentFile, $this>
     */
    public function files(): HasMany
    {
        return $this->hasMany(ContentFile::class);
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function video(): ?ContentFile
    {
        return $this->files->firstWhere('role', 'video');
    }
}
