<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\ContentFile;
use App\Models\ContentItem;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * Every teacher's Library books and videos, for review: the admin can open the files and
 * unpublish anything unsuitable or not openly licensed.
 */
class ContentController extends Controller
{
    public function index(): View
    {
        return view('admin.content', [
            'items' => ContentItem::with(['owner', 'sections', 'files'])->latest()->paginate(50),
        ]);
    }

    public function unpublish(ContentItem $item): RedirectResponse
    {
        $item->forceFill(['published' => false, 'published_at' => null])->save();
        AuditLog::record(Auth::guard('admin')->user(), 'content.unpublish', ['content', $item->id],
            ['title' => $item->title, 'owner' => $item->owner?->email]);

        return back()->with('status', "\"{$item->title}\" is hidden from all tablets.");
    }

    public function file(ContentItem $item, ContentFile $file): BinaryFileResponse
    {
        abort_unless($file->content_item_id === $item->id && is_file($file->absolutePath()), 404);

        return response()->file($file->absolutePath(), ['Content-Type' => $file->mime]);
    }
}
