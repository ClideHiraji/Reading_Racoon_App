<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ContentFile;
use App\Support\ContentManifest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\Response;

/**
 * Teacher-picked Library books and videos for the game.
 * Student token only; a learner sees only what their section was given.
 */
class ContentController extends Controller
{
    /**
     * GET /api/content/manifest. Sends an ETag with the version: a request with
     * If-None-Match set to the current version gets 304 and no body.
     */
    public function manifest(Request $request): JsonResponse|Response
    {
        $student = $request->user()->student;
        abort_if($student === null, 403);

        $manifest = ContentManifest::for($student->section);
        $etag = '"'.$manifest['version'].'"';
        if (in_array($etag, $request->getETags(), true)) {
            return response()->noContent(304)->setEtag($manifest['version']);
        }

        return response()->json([...$manifest, 'server_time' => now()->utc()->toIso8601ZuluString()])
            ->setEtag($manifest['version']);
    }

    /**
     * GET /api/content/files/{file}: the video or page picture, with its SHA-256
     * in X-Content-SHA256. Anything not assigned to the learner's section is 404.
     * Range requests work, so a dropped download can resume.
     */
    public function file(Request $request, ContentFile $file): BinaryFileResponse
    {
        $student = $request->user()->student;
        abort_if($student === null, 403);
        abort_unless(ContentManifest::allows($student->section, $file) && is_file($file->absolutePath()), 404);

        return response()->file($file->absolutePath(), [
            'Content-Type' => $file->mime,
            'Content-Disposition' => 'inline; filename="'.$file->id.'.'.$file->extension().'"',
            'X-Content-SHA256' => $file->sha256,
            'Cache-Control' => 'private, max-age=0',
        ]);
    }
}
