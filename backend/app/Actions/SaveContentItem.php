<?php

namespace App\Actions;

use App\Models\ContentFile;
use App\Models\ContentItem;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Creates or updates a Library book or a video from App\Support\ContentForm
 * output (D-019). Files go to the private disk as "content/<uuid>.<ext>",
 * with their size and SHA-256 recorded for the game's download check.
 */
final class SaveContentItem
{
    /**
     * @param  array{attributes: array<string, mixed>, body: array<string, mixed>, slots: array<int, int>, sections: list<int>}  $form
     * @param  array<int, array{image?: UploadedFile, remove_image?: mixed}>  $pages  the raw page slots (uploads)
     */
    public function book(?ContentItem $item, User $owner, array $form, array $pages): ContentItem
    {
        return DB::transaction(function () use ($item, $owner, $form, $pages) {
            $item = $this->save($item, 'book', $owner, $form);

            // Existing pictures belong to the slot they were shown in (slot = old page index).
            // A page's picture moves with it when blank pages before it are dropped.
            foreach ($item->files()->where('role', 'page_image')->get() as $file) {
                $slot = $file->page_index;
                $newIndex = $form['slots'][$slot] ?? null;
                $replaced = ($pages[$slot]['image'] ?? null) instanceof UploadedFile
                    || filter_var($pages[$slot]['remove_image'] ?? false, FILTER_VALIDATE_BOOLEAN);
                if ($newIndex === null || $replaced) {
                    $file->deleteWithFile();
                } elseif ($newIndex !== $slot) {
                    $file->update(['page_index' => $newIndex]);
                }
            }
            foreach ($pages as $slot => $page) {
                if (isset($page['image'], $form['slots'][$slot]) && $page['image'] instanceof UploadedFile) {
                    $this->storeFile($item, $page['image'], 'page_image', $form['slots'][$slot],
                        strtolower($page['image']->getClientOriginalExtension()) === 'png' ? 'png' : 'jpg');
                }
            }

            return $item->load('files', 'sections');
        });
    }

    /**
     * @param  array{attributes: array<string, mixed>, body: array<string, mixed>, file: ?UploadedFile, sections: list<int>}  $form
     */
    public function video(?ContentItem $item, User $owner, array $form): ContentItem
    {
        return DB::transaction(function () use ($item, $owner, $form) {
            $item = $this->save($item, 'video', $owner, $form);
            if ($form['file'] !== null) {
                $item->files()->where('role', 'video')->get()->each->deleteWithFile();
                $this->storeFile($item, $form['file'], 'video', null, 'ogv');
                $item->touch();
            }

            return $item->load('files', 'sections');
        });
    }

    /** Deletes the item, its files on disk and its section links. */
    public function delete(ContentItem $item): void
    {
        DB::transaction(function () use ($item) {
            $item->files->each->deleteWithFile();
            $item->sections()->detach();
            $item->delete();
        });
    }

    /**
     * @param  array{attributes: array<string, mixed>, body: array<string, mixed>, sections: list<int>}  $form
     */
    private function save(?ContentItem $item, string $kind, User $owner, array $form): ContentItem
    {
        if ($item === null) {
            $item = new ContentItem;
            $item->id = ContentItem::newId($kind);
            $item->kind = $kind;
            $item->owner_id = $owner->id;
        }
        $item->fill([...$form['attributes'], 'body' => $form['body']]);
        $item->save();
        $item->sections()->sync($form['sections']);

        return $item;
    }

    private function storeFile(ContentItem $item, UploadedFile $upload, string $role, ?int $page, string $extension): ContentFile
    {
        $file = new ContentFile([
            'role' => $role,
            'page_index' => $page,
            'mime' => match ($extension) {
                'ogv' => 'video/ogg',
                'png' => 'image/png',
                default => 'image/jpeg',
            },
            'size_bytes' => $upload->getSize(),
            'sha256' => hash_file('sha256', $upload->getRealPath()),
        ]);
        $file->id = (string) Str::uuid();
        $file->path = Storage::disk(config('reading_racoon.content.disk'))
            ->putFileAs('content', $upload, $file->id.'.'.$extension);
        $file->content_item_id = $item->id;
        $file->save();

        return $file;
    }
}
