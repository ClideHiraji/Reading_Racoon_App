<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

/**
 * A video or book-page picture on the private disk, named by its UUID
 * (D-019). The game downloads it through GET /api/content/files/{id} and
 * checks `sha256`.
 */
class ContentFile extends Model
{
    use HasUuids;

    protected $fillable = ['role', 'page_index', 'path', 'mime', 'size_bytes', 'sha256'];

    protected function casts(): array
    {
        return [
            'page_index' => 'integer',
            'size_bytes' => 'integer',
        ];
    }

    /**
     * @return BelongsTo<ContentItem, $this>
     */
    public function item(): BelongsTo
    {
        return $this->belongsTo(ContentItem::class, 'content_item_id');
    }

    public function extension(): string
    {
        return pathinfo($this->path, PATHINFO_EXTENSION);
    }

    public function absolutePath(): string
    {
        return Storage::disk(config('reading_racoon.content.disk'))->path($this->path);
    }

    /** Removes the stored file together with the row. */
    public function deleteWithFile(): void
    {
        Storage::disk(config('reading_racoon.content.disk'))->delete($this->path);
        $this->delete();
    }
}
