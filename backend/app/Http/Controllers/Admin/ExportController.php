<?php

namespace App\Http\Controllers\Admin;

use App\Actions\ReplayStudentEvents;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Student;
use App\Support\SectionStats;
use App\Support\SkillCatalog;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Research data export as CSV (FR-08, RQ1, docs/knowledge/09-evaluation-deployment.md):
 * pre/post-test scores and BKT history, identified by student code only and
 * limited to learners whose parental consent is on file (RA 10173, D-013).
 */
class ExportController extends Controller
{
    public function index(): View
    {
        return view('admin.export', [
            'consented' => Student::whereNotNull('consent_recorded_at')->count(),
            'total' => Student::count(),
        ]);
    }

    public function students(ReplayStudentEvents $replayer): StreamedResponse
    {
        $count = $this->consented()->count();
        AuditLog::record(Auth::guard('admin')->user(), 'export.students', null, ['learners' => $count]);

        return $this->csv('reading-racoon-students-'.now()->format('Ymd-His').'.csv', function ($out) use ($replayer) {
            $states = SkillCatalog::states();
            $skills = SkillCatalog::skills();
            $header = ['student_code', 'section_id', 'enrolled_on', 'placed_level', 'highest_level', 'aral_band', 'skill_levels_mastered',
                'responses', 'accuracy_pct', 'lessons', 'xp', 'coins', 'pre_taken_utc', 'pre_correct', 'pre_total',
                'post_taken_utc', 'post_correct', 'post_total'];
            foreach (['pre', 'post'] as $test) {
                foreach ($skills as $skill) {
                    array_push($header, "{$test}_{$skill}_correct", "{$test}_{$skill}_total");
                }
            }
            foreach ($states as $s) {
                $header[] = "p_{$s['skill']}_l{$s['level']}";
            }
            fputcsv($out, $header);

            $this->consented()->with(['bktStates', 'pathProgress', 'wallet'])->orderBy('code')
                ->each(function (Student $student) use ($out, $replayer, $states, $skills) {
                    $replay = $replayer->replay($student);
                    $p = $student->bktStates->keyBy(fn ($s) => "{$s->sub_skill}:{$s->level}");
                    $sum = fn (string $test, string $field) => array_sum(array_column($replay->assessments[$test], $field));
                    $row = [
                        $student->code, $student->section_id, $student->created_at->toDateString(), $replay->placedLevel ?? '',
                        SectionStats::highest($student), SkillCatalog::level(SectionStats::highest($student))['band'],
                        $student->bktStates->whereNotNull('mastered_at')->count(), $replay->responses,
                        $replay->responses ? round(100 * $replay->correctResponses / $replay->responses, 1) : '',
                        count($replay->lessons), $student->wallet?->xp ?? 0, $student->wallet?->coins ?? 0,
                        $replay->assessedAt['pre']?->toIso8601ZuluString() ?? '', $sum('pre', 'correct'), $sum('pre', 'total'),
                        $replay->assessedAt['post']?->toIso8601ZuluString() ?? '', $sum('post', 'correct'), $sum('post', 'total'),
                    ];
                    foreach (['pre', 'post'] as $test) {
                        foreach ($skills as $skill) {
                            array_push($row, $replay->assessments[$test][$skill]['correct'] ?? 0, $replay->assessments[$test][$skill]['total'] ?? 0);
                        }
                    }
                    foreach ($states as $s) {
                        $row[] = round($p["{$s['skill']}:{$s['level']}"]->p_mastery ?? 0, 4);
                    }
                    fputcsv($out, $row);
                }, 50);
        });
    }

    public function bktHistory(ReplayStudentEvents $replayer): StreamedResponse
    {
        $count = $this->consented()->count();
        AuditLog::record(Auth::guard('admin')->user(), 'export.bkt_history', null, ['learners' => $count]);

        return $this->csv('reading-racoon-bkt-history-'.now()->format('Ymd-His').'.csv', function ($out) use ($replayer) {
            fputcsv($out, ['student_code', 'seq', 'device_time_utc', 'sub_skill', 'level', 'correct',
                'posterior', 'p_next', 'attempts', 'mastered_now', 'level_up']);
            $this->consented()->orderBy('code')->each(function (Student $student) use ($out, $replayer) {
                foreach ($replayer->replay($student)->history as $i => $h) {
                    fputcsv($out, [$student->code, $i + 1, $h['time']->toIso8601ZuluString(), $h['skill'], $h['level'],
                        (int) $h['correct'], round($h['posterior'], 6), round($h['p'], 6),
                        $h['attempts'], (int) $h['mastered_now'], (int) $h['level_up']]);
                }
            }, 50);
        });
    }

    /**
     * @return Builder<Student>
     */
    private function consented()
    {
        return Student::whereNotNull('consent_recorded_at');
    }

    private function csv(string $filename, callable $write): StreamedResponse
    {
        return response()->streamDownload(function () use ($write) {
            $out = fopen('php://output', 'w');
            $write($out);
            fclose($out);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }
}
