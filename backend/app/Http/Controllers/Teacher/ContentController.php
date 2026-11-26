<?php

namespace App\Http\Controllers\Teacher;

use App\Actions\SaveContentItem;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\ContentFile;
use App\Models\ContentItem;
use App\Support\ContentForm;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * Library & Videos: a teacher adds openly licensed books and Ogg videos, gives them to their
 * sections and publishes them. Tablets download them from GET /api/content/manifest at
 * their next sync.
 */
class ContentController extends Controller
{
    public function index(Request $request): View
    {
        return view('teacher.content.index', [
            'items' => ContentItem::with(['sections', 'files'])->where('owner_id', $request->user()->id)->latest()->get(),
            'sections' => $request->user()->sections()->orderBy('name')->get(),
        ]);
    }

    public function createBook(Request $request): View
    {
        return $this->bookForm($request, null);
    }

    public function storeBook(Request $request, SaveContentItem $save): RedirectResponse
    {
        $item = $save->book(null, $request->user(), ContentForm::book($request, $this->sectionIds($request)), $this->pageSlots($request));
        AuditLog::record($request->user(), 'content.create', ['content', $item->id], ['kind' => 'book', 'title' => $item->title]);

        return redirect()->route('teacher.content.index')->with('status', "Book \"{$item->title}\" saved. Publish it when it's ready.");
    }

    public function createVideo(Request $request): View
    {
        return $this->videoForm($request, null);
    }

    public function storeVideo(Request $request, SaveContentItem $save): RedirectResponse
    {
        $item = $save->video(null, $request->user(), ContentForm::video($request, $this->sectionIds($request), creating: true));
        AuditLog::record($request->user(), 'content.create', ['content', $item->id], ['kind' => 'video', 'title' => $item->title]);

        return redirect()->route('teacher.content.index')->with('status', "Video \"{$item->title}\" uploaded. Publish it when it's ready.");
    }

    public function edit(Request $request, ContentItem $item): View
    {
        return $item->isBook() ? $this->bookForm($request, $item) : $this->videoForm($request, $item);
    }

    public function update(Request $request, ContentItem $item, SaveContentItem $save): RedirectResponse
    {
        $item = $item->isBook()
            ? $save->book($item, $request->user(), ContentForm::book($request, $this->sectionIds($request)), $this->pageSlots($request))
            : $save->video($item, $request->user(), ContentForm::video($request, $this->sectionIds($request), creating: false));
        AuditLog::record($request->user(), 'content.update', ['content', $item->id], ['title' => $item->title]);

        return redirect()->route('teacher.content.index')->with('status', "\"{$item->title}\" saved.");
    }

    public function assign(Request $request, ContentItem $item): RedirectResponse
    {
        $data = $request->validate([
            'sections' => ['nullable', 'array'],
            'sections.*' => ['integer', Rule::in($this->sectionIds($request))],
        ]);
        $item->sections()->sync(array_map('intval', $data['sections'] ?? []));
        AuditLog::record($request->user(), 'content.assign', ['content', $item->id], ['sections' => $data['sections'] ?? []]);

        return back()->with('status', "Sections updated for \"{$item->title}\".");
    }

    public function publish(Request $request, ContentItem $item): RedirectResponse
    {
        $publish = $request->boolean('published');
        if ($publish && ! $item->isBook() && $item->video() === null) {
            return back()->withErrors(['published' => 'Upload the video file before publishing.']);
        }
        if ($publish && $item->sections()->doesntExist()) {
            return back()->withErrors(['published' => "Choose at least one section for \"{$item->title}\" first: otherwise no tablet gets it."]);
        }
        $item->forceFill(['published' => $publish, 'published_at' => $publish ? now() : null])->save();
        AuditLog::record($request->user(), $publish ? 'content.publish' : 'content.unpublish', ['content', $item->id]);

        return back()->with('status', $publish
            ? "\"{$item->title}\" is published. Tablets in its sections get it at their next sync."
            : "\"{$item->title}\" is hidden from the tablets.");
    }

    public function destroy(Request $request, ContentItem $item, SaveContentItem $save): RedirectResponse
    {
        AuditLog::record($request->user(), 'content.delete', ['content', $item->id], ['title' => $item->title]);
        $save->delete($item);

        return redirect()->route('teacher.content.index')->with('status', "\"{$item->title}\" was deleted.");
    }

    /** The teacher's own preview of an uploaded video or page picture. */
    public function file(ContentItem $item, ContentFile $file): BinaryFileResponse
    {
        abort_unless($file->content_item_id === $item->id && is_file($file->absolutePath()), 404);

        return response()->file($file->absolutePath(), ['Content-Type' => $file->mime, 'Cache-Control' => 'private, no-store']);
    }

    private function bookForm(Request $request, ?ContentItem $item): View
    {
        return view('teacher.content.book', ['item' => $item, 'sections' => $request->user()->sections()->orderBy('name')->get()]);
    }

    private function videoForm(Request $request, ?ContentItem $item): View
    {
        return view('teacher.content.video', ['item' => $item, 'sections' => $request->user()->sections()->orderBy('name')->get()]);
    }

    /**
     * The book form's page slots: typed fields and uploaded pictures together.
     *
     * @return array<int, array<string, mixed>>
     */
    private function pageSlots(Request $request): array
    {
        return array_replace_recursive((array) $request->input('pages', []), (array) $request->file('pages', []));
    }

    /**
     * @return list<int>
     */
    private function sectionIds(Request $request): array
    {
        return $request->user()->sections()->pluck('id')->all();
    }
}
