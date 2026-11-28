<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * PUT /api/student/profile: the game's whole save file for this child, kept as a copy.
 * Another laptop downloads it from GET /api/student/me at sign-in.
 * It's only a copy: the teacher pages and exports still come from the synced events.
 * To check by hand: SELECT profile_saved_at, length(profile::text) FROM students WHERE code = '...';
 */
class StudentProfileController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $student = $request->user()->student;
        abort_if($student === null, 403);

        $profile = $request->input('profile');
        abort_unless(is_array($profile) && ($profile === [] || ! array_is_list($profile)), 422, 'The profile must be a JSON object.');
        $json = json_encode($profile === [] ? new \stdClass : $profile, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION);
        $max = config('reading_racoon.sync.max_profile_bytes');
        // PostgreSQL jsonb refuses \u0000.
        abort_unless($json !== false && strlen($json) <= $max && ! str_contains($json, '\u0000'), 422, "The profile must be valid JSON of at most {$max} bytes.");

        // The database clock, so two laptops' copies are ordered the same way.
        $savedAt = DB::selectOne('select clock_timestamp() as now')->now;
        DB::table('students')->where('id', $student->id)->update(['profile' => $json, 'profile_saved_at' => $savedAt]);

        return response()->json(['saved_at' => self::time($savedAt)]);
    }

    /** UTC with microseconds, so two copies a moment apart still compare correctly as text. */
    public static function time(mixed $value): ?string
    {
        return $value === null ? null : \Carbon\CarbonImmutable::parse($value)->utc()->format('Y-m-d\TH:i:s.u\Z');
    }
}
