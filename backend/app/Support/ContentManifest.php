<?php

namespace App\Support;

use App\Models\ContentFile;
use App\Models\ContentItem;
use App\Models\Section;
use Illuminate\Support\Collection;

/**
 * What a section's tablets download: the published books and videos its teacher assigned,
 * shaped exactly like the game's content/library.json ("books") and content/watch.json ("items"),
 * so the game can save them as user://content/library.json and watch.json.
 */
final class ContentManifest
{
    /**
     * @return array{version: string, books: list<array<string, mixed>>, watch: list<array<string, mixed>>}
     */
    public static function for(Section $section): array
    {
        $items = self::items($section);

        return [
            'version' => self::version($items),
            'books' => $items->filter->isBook()->map(fn (ContentItem $item) => self::book($item))->values()->all(),
            'watch' => $items->reject->isBook()->map(fn (ContentItem $item) => self::video($item))->values()->all(),
        ];
    }

    /**
     * @return Collection<int, ContentItem>
     */
    public static function items(Section $section): Collection
    {
        return ContentItem::with('files')
            ->where('published', true)
            ->whereHas('sections', fn ($q) => $q->whereKey($section->id))
            ->orderBy('created_at')->orderBy('id')
            ->get();
    }

    /** True when the published item is assigned to the section: the game may download its files. */
    public static function allows(Section $section, ContentFile $file): bool
    {
        return $file->item !== null && $file->item->published
            && $file->item->sections()->whereKey($section->id)->exists();
    }

    /**
     * Changes whenever an item is added, removed, edited, published or gets a new file.
     *
     * @param  Collection<int, ContentItem>  $items
     */
    public static function version(Collection $items): string
    {
        $fingerprint = $items->map(fn (ContentItem $item) => [
            $item->id, $item->updated_at?->format('U.u'), $item->body, $item->files->pluck('sha256')->sort()->values(),
        ]);

        return substr(hash('sha256', json_encode($fingerprint)), 0, 16);
    }

    /**
     * @return array<string, mixed>
     */
    public static function book(ContentItem $item): array
    {
        $images = $item->files->where('role', 'page_image')->keyBy('page_index');
        $pages = [];
        foreach ($item->body['pages'] ?? [] as $i => $page) {
            if ($image = $images->get($i)) {
                $page['image_url'] = self::url($image);
                $page['image'] = 'user://content/'.$image->id.'.'.$image->extension();
                $page['image_sha256'] = $image->sha256;
            }
            $pages[] = $page;
        }

        return [
            'id' => $item->id,
            'title' => $item->title,
            'language' => $item->language,
            'level' => $item->level,
            'cover' => $item->scene,
            'credit' => $item->credit,
            'licence' => $item->licence,
            'source_url' => $item->source_url,
            'words' => $item->body['words'] ?? [],
            'pages' => $pages,
            'questions' => array_map(fn (array $q) => self::question($q), $item->body['questions'] ?? []),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public static function video(ContentItem $item): array
    {
        $file = $item->video();

        return array_filter([
            'id' => $item->id,
            'kind' => 'video',
            'title' => $item->title,
            'language' => $item->language,
            'scene' => $item->scene,
            'minutes' => $item->minutes,
            'credit' => $item->credit,
            'licence' => $item->licence,
            'source_url' => $item->source_url,
            // Where the game keeps the file once downloaded (MediaLibrary.video_ready checks it).
            'file' => 'user://content/'.$item->id.'.ogv',
            'file_url' => $file ? self::url($file) : null,
            'size_bytes' => $file?->size_bytes,
            'sha256' => $file?->sha256,
            'check' => isset($item->body['check']) ? self::question($item->body['check']) : null,
        ], fn ($value) => $value !== null);
    }

    /**
     * jsonb keeps object keys in its own order, so put questions back in the game's order:
     * {prompt, choices [{id, label, picture?}], answer}.
     *
     * @param  array<string, mixed>  $q
     * @return array<string, mixed>
     */
    private static function question(array $q): array
    {
        return [
            'prompt' => $q['prompt'] ?? '',
            'choices' => array_map(fn (array $c) => array_filter([
                'id' => $c['id'] ?? null, 'label' => $c['label'] ?? null, 'picture' => $c['picture'] ?? null,
            ], fn ($v) => $v !== null), $q['choices'] ?? []),
            'answer' => $q['answer'] ?? '',
        ];
    }

    /** Relative to the server's base URL, like every other API path the game calls. */
    public static function url(ContentFile $file): string
    {
        return '/api/content/files/'.$file->id;
    }
}
