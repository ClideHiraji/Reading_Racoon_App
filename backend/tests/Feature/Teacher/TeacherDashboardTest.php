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
        $code = session('login_cards')[0]['login_code'];
        $this->assertMatchesRegularExpression('/^[A-HJKMNP-Z2-9]{4}-[A-HJKMNP-Z2-9]{4}$/', $code);

        $this->get(route('teacher.sections.show', $this->section))->assertSee($code)->assertSee('won\'t be shown again', false);
        $this->get(route('teacher.sections.show', $this->section))->assertDontSee($code);

        // The student ID is labelled so nobody types it into the game as a login code.
        $student = $this->section->students()->sole();
        $this->get(route('teacher.sections.show', $this->section))
            ->assertSee('Student ID '.$student->code.' · not the login code', false)
            ->assertSee('New login code');
        $this->get(route('teacher.students.show', $student))->assertSee('(for reports, not the login code)', false);

        $this->postJson('/api/auth/login', ['login_code' => $code])->assertOk()->assertJsonPath('user.name', 'Ana');
        $this->assertSame(1, AuditLog::where('action', 'student.add')->count());
    }

    public function test_a_new_code_replaces_the_old_one(): void
    {
        $this->post(route('teacher.students.store', $this->section), ['name' => 'Ana']);
        $old = session('login_cards')[0]['login_code'];
        $student = Student::sole();

        $this->post(route('teacher.students.code', $student))->assertRedirect();
        $new = session('login_cards')[0]['login_code'];

        $this->assertNotSame($old, $new);
        $this->postJson('/api/auth/login', ['login_code' => $old])->assertUnprocessable();
        $this->postJson('/api/auth/login', ['login_code' => $new])->assertOk();
    }

    public function test_a_whole_class_is_added_at_once_with_printable_login_cards(): void
    {
        $this->post(route('teacher.students.store', $this->section), ['names' => "Ana\n\n  Ben  \r\nCarlo\n"])
            ->assertRedirect(route('teacher.sections.show', $this->section));
        $cards = session('login_cards');
        $this->assertSame(['Ana', 'Ben', 'Carlo'], array_column($cards, 'name'));

        $page = $this->get(route('teacher.sections.show', $this->section))->assertOk()
            ->assertSee('Login cards for 3 learners')
            ->assertSee('data-print', false)
            ->assertSee('won\'t be shown again', false);
        foreach ($cards as $card) {
            // The code in 8 boxes split 4 + 4, like the game's keypad.
            [$left, $right] = explode('-', $card['login_code']);
            $boxes = implode('', array_map(fn ($c) => '<span class="box">'.$c.'</span>', str_split($left)))
                .'<span class="gap" aria-hidden="true"></span>'
                .implode('', array_map(fn ($c) => '<span class="box">'.$c.'</span>', str_split($right)));
            $this->assertStringContainsString($boxes, preg_replace('/>\s+</', '><', $page->getContent()));
            $this->postJson('/api/auth/login', ['login_code' => $card['login_code']])->assertOk()
                ->assertJsonPath('user.name', $card['name']);
        }

        // Shown once: a reload shows no codes.
        $again = $this->get(route('teacher.sections.show', $this->section))->assertDontSee('Login cards for');
        foreach ($cards as $card) {
            $again->assertDontSee($card['login_code']);
        }
        $this->assertSame(3, AuditLog::where('action', 'student.add')->count());
    }

    public function test_a_bad_class_list_adds_nobody(): void
    {
        $tooMany = implode("\n", array_map(fn ($i) => "Learner {$i}", range(1, 61)));
        $this->post(route('teacher.students.store', $this->section), ['names' => $tooMany])
            ->assertSessionHasErrors('names');
        $this->post(route('teacher.students.store', $this->section), ['names' => "Ana\n".str_repeat('x', 51)])
            ->assertSessionHasErrors('names.1');
        $this->post(route('teacher.students.store', $this->section), ['names' => "\n  \n"])
            ->assertSessionHasErrors('names');

        $this->assertSame(0, Student::count());
    }

    public function test_a_new_login_code_comes_as_a_card_to_print(): void
    {
        $this->post(route('teacher.students.store', $this->section), ['names' => 'Ana']);
        $student = Student::sole();

        $this->post(route('teacher.students.code', $student));

        $this->assertSame('Ana', session('login_cards')[0]['name']);
        $this->get(route('teacher.sections.show', $this->section))
            ->assertSee('Login card for Ana')
            ->assertSee('Print card');
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
        // Flags in a teacher's words, grouped by child, and the class on the reading map (D-037).
        $response->assertSee('Went back a level')->assertSee('badge-orange', false);
        $response->assertSee('Keeps missing a skill')->assertSee('badge-amber', false);
        $response->assertSee('class="map"', false)->assertSee('Mango Grove');
        $response->assertDontSee('cdn.jsdelivr.net', false); // charts are drawn on the server
        $this->assertSame(['Ben'], array_map(fn ($row) => $row['student']->displayName(), $response->viewData('stats')->needsHelp));

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

    public function test_a_resolved_flag_can_be_undone(): void
    {
        $student = $this->enroll('Ana');
        $this->play($student, [['flag', ['type' => 'rescue_limit', 'skill' => 'phonics', 'level' => 1]]]);
        $flag = InterventionFlag::sole();

        $this->post(route('teacher.flags.resolve', $flag))->assertSessionHas('undo_flag', $flag->id);
        $this->get(route('teacher.sections.show', $this->section))->assertSee('Undo')
            ->assertSee(route('teacher.flags.reopen', $flag), false);

        $this->post(route('teacher.flags.reopen', $flag))->assertRedirect();
        $this->assertSame('open', $flag->fresh()->status);
        $this->assertNull($flag->fresh()->resolved_by);
        $this->assertSame(1, AuditLog::where('action', 'flag.reopen')->count());
    }

    public function test_flags_that_look_better_close_together_and_never_touch_another_teachers(): void
    {
        $ana = $this->enroll('Ana');
        $this->play($ana, [...$this->answers('phonics', 1, 6, correct: false), ...$this->answers('phonics', 1, 4)]);
        $other = User::factory()->registered()->create();
        $carlo = $this->enroll('Carlo', $other->sections()->create(['name' => 'Grade 1 - Rosal']));
        $this->play($carlo, $this->answers('vocabulary', 2, 6, correct: false));
        $theirs = InterventionFlag::where('student_id', $carlo->id)->sole();

        $page = $this->get(route('teacher.sections.show', $this->section))->assertOk()
            ->assertSee('Looks better: check and close')->assertSee('Close all 1 that look better');
        $stats = $page->viewData('stats');
        $this->assertSame(0, $stats->needingHelpCount());
        $this->assertCount(1, $stats->betterRows());

        $this->post(route('teacher.flags.resolve-many'), ['ids' => [...$stats->betterFlagIds(), $theirs->id], 'anchor' => 'needs-help'])
            ->assertRedirect()->assertSessionHas('undo_flags');
        $this->assertSame('resolved', InterventionFlag::where('student_id', $ana->id)->sole()->status);
        $this->assertSame('open', $theirs->fresh()->status, "another teacher's flag is ignored");

        $this->post(route('teacher.flags.reopen-many'), ['ids' => $stats->betterFlagIds()]);
        $this->assertSame('open', InterventionFlag::where('student_id', $ana->id)->sole()->status);
    }

    public function test_a_mastered_skill_whose_estimate_falls_shows_as_slipping(): void
    {
        $ana = $this->enroll('Ana');
        $this->play($ana, [...$this->answers('phonological_awareness', 1, 5), ...$this->answers('phonological_awareness', 1, 8, correct: false)]);

        $stats = $this->get(route('teacher.sections.show', $this->section))->assertSee('Slipping')->viewData('stats');
        $this->assertSame('slip', $stats->states[$ana->id]['phonological_awareness']['key']);
        $this->get(route('teacher.students.show', $ana))->assertSee('Slipping');
    }

    public function test_recording_consent_can_be_undone_and_error_pages_offer_a_way_back(): void
    {
        $ana = $this->enroll('Ana');
        $this->post(route('teacher.students.consent', $ana), ['consent' => 1])->assertSessionHas('undo_consent', $ana->id);
        $this->get(route('teacher.sections.show', $this->section))->assertSee('Undo');

        $this->get('/teacher/students/999999')->assertNotFound()
            ->assertSee('<h1>We can&#039;t find that page</h1>', false)->assertSee('Go to Reading Racoon')->assertDontSee('@section', false);
    }

    public function test_a_learner_whose_game_checked_in_lately_shows_as_active_now(): void
    {
        $ana = $this->enroll('Ana');
        $this->play($ana, $this->answers('phonics', 1, 2));
        $token = $ana->user->createToken('Tablet 1')->accessToken;

        $token->forceFill(['last_used_at' => now()->subMinute()])->save();
        $this->assertArrayHasKey($ana->id, $this->get(route('teacher.sections.show', $this->section))->assertSee('Active now')->viewData('stats')->activeNow);
        $this->get(route('teacher.students.show', $ana))->assertSee('Active now');

        // Offline for longer than one missed check-in: the last played time again.
        $token->forceFill(['last_used_at' => now()->subMinutes(10)])->save();
        $this->get(route('teacher.sections.show', $this->section))->assertDontSee('Active now')->assertSee('Played');
    }

    public function test_a_low_mastery_flag_looks_better_once_the_child_recovers(): void
    {
        $ben = $this->enroll('Ben');
        $this->play($ben, $this->answers('phonics', 1, 6, correct: false));
        $this->assertSame('low_mastery', InterventionFlag::sole()->type);

        $stats = $this->get(route('teacher.sections.show', $this->section))->viewData('stats');
        $this->assertFalse($stats->needsHelp[0]['flags'][0]['better']);
        $this->assertSame(1, $stats->needingHelpCount());
        $this->assertSame('help', $stats->states[$ben->id]['phonics']['key']);

        // Four right answers lift phonics L1 past 50%: still open, now marked "looks better".
        $this->play($ben, $this->answers('phonics', 1, 4));
        $response = $this->get(route('teacher.sections.show', $this->section))->assertSee('Looks better now');
        $stats = $response->viewData('stats');
        $this->assertTrue($stats->needsHelp[0]['flags'][0]['better']);
        $this->assertSame(0, $stats->needingHelpCount());
        $this->assertSame('open', InterventionFlag::sole()->status, 'flags never close by themselves');
    }

    public function test_risky_learner_actions_live_on_the_learner_page_with_confirmations(): void
    {
        $ana = $this->enroll('Ana');
        $ana->forceFill(['consent_recorded_at' => now(), 'consent_recorded_by' => $this->teacher->id])->save();

        $this->get(route('teacher.sections.show', $this->section))->assertOk()
            ->assertDontSee('name="_method" value="DELETE"', false)
            ->assertDontSee(route('teacher.students.code', $ana), false);
        $this->get(route('teacher.students.show', $ana))->assertOk()
            ->assertSee('name="_method" value="DELETE"', false)
            ->assertSee(route('teacher.students.code', $ana), false)
            ->assertSee('This cannot be undone.')
            ->assertSee('Clear consent')
            ->assertSee('left out of research exports');
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
        $response->assertSee('Mastery over time')->assertSee('id="skill-history"', false)->assertSee('<svg class="history"', false);
        $response->assertSee('7/8 correct')->assertSee("Racoon's Rescue", false)->assertSee('12 min');
        $this->assertCount(3, $response->viewData('series')['phonics:1']);
        $this->assertSame(1, AuditLog::where('action', 'student.view')->count());
    }

    public function test_the_schedule_editor_validates_and_the_game_sees_the_new_schedule(): void
    {
        $day = ['free_play_minutes' => 45, 'day_start' => '06:00', 'day_end' => '21:00'];
        $this->put(route('teacher.schedule.update', $this->section), [
            'class_start' => '08:00', 'class_end' => '09:00', 'after_school_start' => '08:30', 'after_school_end' => '10:00', 'daily_minutes' => 30, ...$day,
        ])->assertSessionHasErrors('after_school_start');
        $this->put(route('teacher.schedule.update', $this->section), [
            'class_start' => '09:00', 'class_end' => '08:00', 'after_school_start' => '15:00', 'after_school_end' => '17:00', 'daily_minutes' => 300, ...$day,
        ])->assertSessionHasErrors(['class_end', 'daily_minutes']);
        $this->put(route('teacher.schedule.update', $this->section), [
            'class_start' => '08:00', 'class_end' => '09:00', 'after_school_start' => '16:00', 'after_school_end' => '22:00', 'daily_minutes' => 30, ...$day,
        ])->assertSessionHasErrors('after_school_start'); // ends after bedtime
        $this->put(route('teacher.schedule.update', $this->section), [
            'class_start' => '08:00', 'class_end' => '09:00', 'after_school_start' => '16:00', 'after_school_end' => '18:00', 'daily_minutes' => 30,
            'free_play_minutes' => 45, 'day_start' => '21:00', 'day_end' => '06:00',
        ])->assertSessionHasErrors('day_end');

        $this->put(route('teacher.schedule.update', $this->section), [
            'class_start' => '08:00', 'class_end' => '09:00', 'after_school_start' => '16:00', 'after_school_end' => '18:00',
            'daily_minutes' => 45, 'weekends_open' => '1', 'free_play_minutes' => 60, 'day_start' => '06:30', 'day_end' => '20:00',
        ])->assertRedirect(route('teacher.sections.show', $this->section));

        $schedule = AccessSchedule::findOrFail($this->section->id);
        $this->assertSame(['08:00', 45, true, $this->teacher->id], [$schedule->hm('class_start'), $schedule->daily_minutes, $schedule->weekends_open, $schedule->updated_by]);

        $student = $this->enroll('Ana');
        Sanctum::actingAs($student->user);
        $this->getJson('/api/access/student/status')->assertJsonPath('schedule.after_school_start', '16:00')
            ->assertJsonPath('schedule.daily_minutes', 45)
            ->assertJsonPath('schedule.free_play_minutes', 60)
            ->assertJsonPath('schedule.day_start', '06:30')
            ->assertJsonPath('schedule.day_end', '20:00');
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
        $response->assertSee("{$student->displayName()} is on Map Level 1", false)->assertDontSee("Learner {$student->code} is on", false);
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
