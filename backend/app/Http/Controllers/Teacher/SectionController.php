<?php

namespace App\Http\Controllers\Teacher;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Section;
use App\Support\SectionStats;
use App\Support\SkillCatalog;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * The teacher's sections and the class dashboard (FR-06, FR-17): mastery per
 * sub-skill, ARAL band counts from the highest unlocked map level, open
 * intervention flags and the roster.
 */
class SectionController extends Controller
{
    public function index(Request $request): View|RedirectResponse
    {
        $sections = $request->user()->sections()->withCount('students')->orderBy('name')->get();
        if ($sections->count() === 1 && ! $request->has('all')) {
            return redirect()->route('teacher.sections.show', $sections->first());
        }

        return view('teacher.home', ['sections' => $sections]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate(['name' => ['required', 'string', 'max:100']]);
        $section = $request->user()->sections()->create($data);
        AuditLog::record($request->user(), 'section.create', $section, ['name' => $section->name]);

        return redirect()->route('teacher.sections.show', $section)->with('status', "Section \"{$section->name}\" created.");
    }

    public function show(Request $request, Section $section): View
    {
        $stats = SectionStats::for($section);
        AuditLog::record($request->user(), 'section.view', $section);

        return view('teacher.section', [
            'section' => $section,
            'stats' => $stats,
            'otherSections' => $request->user()->sections()->whereKeyNot($section->id)->orderBy('name')->get(),
            'skillLabels' => array_map(fn ($s) => SkillCatalog::label($s), SkillCatalog::skills()),
        ]);
    }
}
