<?php

namespace App\Http\Controllers\Teacher;

use App\Actions\ReplayStudentEvents;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Student;
use App\Reports\DiagnosticReportWriter;
use App\Reports\StudentFacts;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\Response;

/**
 * A learner's diagnostic report (FR-05) and its PDF export (FR-18). The text
 * comes from App\Reports\DiagnosticReportWriter: the stored Gemini paragraphs
 * for the current numbers, else the numbers-only template (D-012, D-018).
 */
class ReportController extends Controller
{
    public function show(Request $request, Student $student, ReplayStudentEvents $replayer, DiagnosticReportWriter $writer): View
    {
        AuditLog::record($request->user(), 'report.view', ['student', $student->code]);

        return view('teacher.report', $this->data($student, $replayer, $writer));
    }

    public function pdf(Request $request, Student $student, ReplayStudentEvents $replayer, DiagnosticReportWriter $writer): Response
    {
        AuditLog::record($request->user(), 'report.pdf', ['student', $student->code]);

        return Pdf::loadView('teacher.report-pdf', $this->data($student, $replayer, $writer))
            ->setPaper('a4')
            ->download("reading-racoon-report-{$student->code}.pdf");
    }

    /**
     * @return array<string, mixed>
     */
    private function data(Student $student, ReplayStudentEvents $replayer, DiagnosticReportWriter $writer): array
    {
        $student->load(['user', 'section.teacher', 'bktStates', 'pathProgress', 'interventionFlags']);
        $facts = StudentFacts::build($student, $replayer->replay($student));

        return [
            'student' => $student,
            'facts' => $facts,
            'report' => $writer->write($facts),
            'timezone' => config('reading_racoon.access.timezone'),
        ];
    }
}
