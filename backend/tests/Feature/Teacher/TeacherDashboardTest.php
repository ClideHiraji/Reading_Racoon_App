<?php

namespace Tests\Feature\Teacher;

use App\Actions\EnrollStudent;
use App\Actions\ReplayStudentEvents;
use App\Models\AccessSchedule;
use App\Models\AuditLog;
use App\Models\InterventionFlag;
use App\Models\Section;
use App\Models\Student;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Teacher dashboard, roster, student profile, schedule and reports
 * (FR-06, FR-12, FR-16, FR-17, FR-18), and that teachers only see their own sections.
 */
class TeacherDashboardTest extends TestCase
{
    use RefreshDatabase;

    private User $teacher;

    private Section $section;

    protected function setUp(): void
    {
        parent::setUp();

        $this->teacher = User::factory()->registered()->create(['name' => 'Maria Santos']);
        $this->section = $this->teacher->sections()->create(['name' => 'Grade 1 - Sampaguita']);
        $this->actingAs($this->teacher);
    }

    private function enroll(string $name, ?Section $section = null): Student
    {
        return app(EnrollStudent::class)->handle($section ?? $this->section, $name)['student'];
    }

    /** Stores events for a student and replays them, as POST /api/sync does. */
    private function play(Student $student, array $events): void
    {
        foreach ($events as $i => [$type, $payload]) {
            DB::table('sync_events')->insert(['uuid' => (string) Str::uuid(), 'student_id' => $student->id, 'type' => $type,
                'payload' => json_encode($payload), 'device_time' => now()->subMinutes(60 - $i)]);
        }
        app(ReplayStudentEvents::class)->handle($student);
    }

    private function answers(string $skill, int $level, int $times, bool $correct = true): array
    {
        return array_fill(0, $times, ['response', ['skill' => $skill, 'level' => $level, 'correct' => $correct, 'num_choices' => 3]]);
    }

    public function test_adding_a_learner_shows_their_login_code_once_and_it_works_in_the_game(): void
    {
        $response = $this->post(route('teacher.students.store', $this->section), ['name' => 'Ana'])
            ->assertRedirect(route('teacher.sections.show', $this->section));
        $code = session('new_code')['login_code'];
        $this->assertMatchesRegularExpression('/^[A-HJKMNP-Z2-9]{4}-[A-HJKMNP-Z2-9]{4}$/', $code);

        $this->get(route('teacher.sections.show', $this->section))->assertSee($code)->assertSee('won\'t be shown again', false);
        $this->get(route('teacher.sections.show', $this->section))->assertDontSee($code);

        $this->postJson('/api/auth/login', ['login_code' => $code])->assertOk()->assertJsonPath('user.name', 'Ana');
        $this->assertSame(1, AuditLog::where('action', 'student.add')->count());
    }

    public function test_a_new_code_replaces_the_old_one(): void
    {
        $this->post(route('teacher.students.store', $this->section), ['name' => 'Ana']);
        $old = session('new_code')['login_code'];
        $student = Student::sole();

        $this->post(route('teacher.students.code', $student))->assertRedirect();
        $new = session('new_code')['login_code'];

        $this->assertNotSame($old, $new);
        $this->postJson('/api/auth/login', ['login_code' => $old])->assertUnprocessable();
        $this->postJson('/api/auth/login', ['login_code' => $new])->assertOk();
    }

    public function test_removing_a_learner_deletes_their_data(): void
    {
        $student = $this->enroll('Ana');
        $this->play($student, $this->answers('phonics', 1, 2));

        $this->delete(route('teacher.students.destroy', $student))->assertRedirect(route('teacher.sections.show', $this->section));

        $this->assertDatabaseCount('students', 0);
        $this->assertDatabaseCount('sync_events', 0);
        $this->assertDatabaseCount('bkt_states', 0);
        $audit = AuditLog::where('action', 'student.remove')->sole();
        $this->assertSame($student->code, $audit->subject_id);
    }

    public function test_consent_can_be_recorded_and_cleared(): void
    {
        $student = $this->enroll('Ana');

        $this->post(route('teacher.students.consent', $student), ['consent' => 1]);
        $this->assertNotNull($student->fresh()->consent_recorded_at);
        $this->assertSame($this->teacher->id, $student->fresh()->consent_recorded_by);

        $this->post(route('teacher.students.consent', $student), ['consent' => 0]);
        $this->assertNull($student->fresh()->consent_recorded_at);
    }

    public function test_the_dashboard_shows_mastery_bands_and_coloured_flags(): void
    {
        $ana = $this->enroll('Ana');
        $ben = $this->enroll('Ben');
        $this->play($ana, [...$this->answers('phonological_awareness', 1, 5), ...$this->answers('phonics', 1, 5)]);
        $this->play($ben, [
            ...$this->answers('vocabulary', 2, 6, correct: false),
            ['flag', ['type' => 'rescue_partial', 'skill' => 'phonics', 'level' => 1, 'correct' => 1, 'demoted_level' => -1]],
        ]);

        $response = $this->get(route('teacher.sections.show', $this->section))->assertOk();
        $response->assertSee('Ana')->assertSee('Ben')->assertSee($ana->code);
        $response->assertSee('L2 · ARAL Basic / Plus')->assertSee('L1 · ARAL Basic');
        $response->assertSee('Heart Recovery failed')->assertSee('badge-orange', false);
        $response->assertSee('Low mastery (P(L) &lt; 0.30)', false)->assertSee('badge-amber', false);
        $response->assertSee('chart.js@4.4.1', false);

        // Two learners x 2 phonics levels... Ana mastered PA L1 (1 of 2 PA levels for 2 learners = 25%).
        $bands = $response->viewData('stats')->bands;
        $this->assertSame(1, $bands['L1 · ARAL Basic']);
        $this->assertSame(1, $bands['L2 · ARAL Basic / Plus']);
        $this->assertSame(25, $response->viewData('stats')->skills['phonological_awareness']['mastered_pct']);
    }

    public function test_a_teacher_resolves_a_flag(): void
    {
        $student = $this->enroll('Ana');
        $this->play($student, [['flag', ['type' => 'rescue_limit', 'skill' => 'phonics', 'level' => 1]]]);
        $flag = InterventionFlag::sole();

        $this->post(route('teacher.flags.resolve', $flag))->assertRedirect();

        $flag->refresh();
        $this->assertSame('resolved', $flag->status);
        $this->assertSame($this->teacher->id, $flag->resolved_by);
    }

    public function test_the_student_profile_has_the_bkt_chart_and_session_history(): void
    {
        $student = $this->enroll('Ana');
        $this->play($student, [
            ...$this->answers('phonics', 1, 3),
            ['lesson_end', ['level' => 1, 'node' => 0, 'correct' => 7, 'total' => 8]],
            ['rescue_start', ['skill' => 'phonics', 'level' => 1]],
            ['rescue_end', []],
            ['usage', ['date' => now()->toDateString(), 'minutes' => 12, 'window' => 'after_school']],
        ]);

        $response = $this->get(route('teacher.students.show', $student))->assertOk();
        $response->assertSee('Mastery over time')->assertSee('bktChart', false);
        $response->assertSee('7/8 correct')->assertSee("Racoon's Rescue", false)->assertSee('12 min');
        $this->assertCount(3, $response->viewData('series')['phonics']);
        $this->assertSame(1, AuditLog::where('action', 'student.view')->count());
    }

    public function test_the_schedule_editor_validates_and_the_game_sees_the_new_schedule(): void
    {
        $this->put(route('teacher.schedule.update', $this->section), [
            'class_start' => '08:00', 'class_end' => '09:00', 'after_school_start' => '08:30', 'after_school_end' => '10:00', 'daily_minutes' => 30,
        ])->assertSessionHasErrors('after_school_start');
        $this->put(route('teacher.schedule.update', $this->section), [
            'class_start' => '09:00', 'class_end' => '08:00', 'after_school_start' => '15:00', 'after_school_end' => '17:00', 'daily_minutes' => 300,
        ])->assertSessionHasErrors(['class_end', 'daily_minutes']);

        $this->put(route('teacher.schedule.update', $this->section), [
            'class_start' => '08:00', 'class_end' => '09:00', 'after_school_start' => '16:00', 'after_school_end' => '18:00',
            'daily_minutes' => 45, 'weekends_open' => '1',
        ])->assertRedirect(route('teacher.sections.show', $this->section));

        $schedule = AccessSchedule::findOrFail($this->section->id);
        $this->assertSame(['08:00', 45, true, $this->teacher->id], [$schedule->hm('class_start'), $schedule->daily_minutes, $schedule->weekends_open, $schedule->updated_by]);

        $student = $this->enroll('Ana');
        Sanctum::actingAs($student->user);
        $this->getJson('/api/access/student/status')->assertJsonPath('schedule.after_school_start', '16:00')
            ->assertJsonPath('schedule.daily_minutes', 45);
    }

    public function test_the_report_is_built_from_the_numbers_and_exports_as_pdf(): void
    {
        $student = $this->enroll('Ana');
        $this->play($student, [
            ...$this->answers('phonological_awareness', 1, 5),
            ...$this->answers('phonics', 1, 6, correct: false),
            ['lesson_end', ['level' => 1, 'node' => 0, 'correct' => 5, 'total' => 11]],
        ]);

        $response = $this->get(route('teacher.students.report', $student))->assertOk();
        $response->assertSee("Learner {$student->code} is on Map Level 1", false);
        $response->assertSee('Mastered 1 of 14 skill-levels: Phonological Awareness L1.');
        $response->assertSee('Needs support in Phonics');
        $response->assertSee('word families');
        $this->assertSame('template', $response->viewData('report')->generatedBy);

        $pdf = $this->get(route('teacher.students.report.pdf', $student))->assertOk();
        $this->assertSame('application/pdf', $pdf->headers->get('Content-Type'));
        $this->assertStringStartsWith('%PDF', $pdf->getContent());
        $this->assertStringContainsString($student->code, $pdf->headers->get('Content-Disposition'));
    }

    public function test_teachers_only_see_their_own_sections_and_learners(): void
    {
        $other = User::factory()->registered()->create();
        $otherSection = $other->sections()->create(['name' => 'Grade 1 - Rosal']);
        $theirs = $this->enroll('Carlo', $otherSection);
        $this->play($theirs, [['flag', ['type' => 'rescue_limit', 'skill' => 'phonics', 'level' => 1]]]);
        $flag = InterventionFlag::sole();

        $this->get(route('teacher.sections.show', $otherSection))->assertNotFound();
        $this->get(route('teacher.schedule.edit', $otherSection))->assertNotFound();
        $this->post(route('teacher.students.store', $otherSection), ['name' => 'Spy'])->assertNotFound();
        $this->get(route('teacher.students.show', $theirs))->assertNotFound();
        $this->get(route('teacher.students.report.pdf', $theirs))->assertNotFound();
        $this->delete(route('teacher.students.destroy', $theirs))->assertNotFound();
        $this->post(route('teacher.flags.resolve', $flag))->assertNotFound();

        $this->assertDatabaseHas('students', ['id' => $theirs->id]);
        $this->assertSame('open', $flag->fresh()->status);
        $this->get(route('teacher.sections.show', $this->section))->assertDontSee('Carlo');
    }

    public function test_students_cannot_open_teacher_pages(): void
    {
        $student = $this->enroll('Ana');
        $this->actingAs($student->user);

        $this->get(route('teacher.sections.show', $this->section))->assertRedirect(route('login'));
        $this->assertGuest();
    }
}
