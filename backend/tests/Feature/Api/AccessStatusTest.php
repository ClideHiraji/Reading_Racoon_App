<?php

namespace Tests\Feature\Api;

use App\Actions\EnrollStudent;
use App\Models\AccessSchedule;
use App\Models\Section;
use App\Models\Student;
use App\Models\SystemLog;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * GET /api/access/student/status: time-restricted access (FR-12,
 * docs/knowledge/06-game-design.md). Times below are Asia/Manila (UTC+8).
 * 2026-10-20 is a Tuesday; 2026-10-24 a Saturday.
 */
class AccessStatusTest extends TestCase
{
    use RefreshDatabase;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $this->student = app(EnrollStudent::class)->handle(Section::factory()->create(), 'Ana')['student'];
        Sanctum::actingAs($this->student->user);
    }

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    private function at(string $manilaTime)
    {
        $now = CarbonImmutable::parse($manilaTime, 'Asia/Manila');
        CarbonImmutable::setTestNow($now);
        Carbon::setTestNow($now);

        return $this->getJson('/api/access/student/status')->assertOk();
    }

    private function played(string $date, int $minutes): void
    {
        $this->student->dailyUsage()->create(['date' => $date, 'minutes' => $minutes]);
    }

    public function test_the_class_window_allows_everything_and_counts_down_to_its_end(): void
    {
        $this->at('2026-10-20 07:45')
            ->assertJsonPath('status', 'allowed')
            ->assertJsonPath('window', 'class')
            ->assertJsonPath('minutes_left', 45)
            ->assertJsonPath('opens_at', null)
            ->assertJsonPath('server_time', '2026-10-19T23:45:00Z')
            ->assertJsonPath('schedule', [
                'class_start' => '07:30', 'class_end' => '08:30',
                'after_school_start' => '15:00', 'after_school_end' => '17:00',
                'daily_minutes' => 30, 'weekends_open' => false, 'timezone' => 'Asia/Manila',
            ]);
    }

    public function test_other_school_hours_are_locked_until_the_next_window(): void
    {
        $this->at('2026-10-20 10:00')
            ->assertJsonPath('status', 'class_lock')
            ->assertJsonPath('minutes_left', 0)
            ->assertJsonPath('opens_at', '2026-10-20T07:00:00Z'); // 15:00 Manila

        $this->at('2026-10-20 19:00')
            ->assertJsonPath('status', 'class_lock')
            ->assertJsonPath('opens_at', '2026-10-20T23:30:00Z'); // tomorrow 07:30 Manila
    }

    public function test_after_school_play_is_capped_at_30_minutes_a_day(): void
    {
        $this->at('2026-10-20 15:10')
            ->assertJsonPath('status', 'after_school')
            ->assertJsonPath('window', 'after_school')
            ->assertJsonPath('minutes_left', 30);

        $this->played('2026-10-20', 22);
        $this->at('2026-10-20 15:10')
            ->assertJsonPath('minutes_left', 8)
            ->assertJsonPath('used_minutes', 22);

        // Near the end of the window, the window end wins.
        $this->at('2026-10-20 16:55')->assertJsonPath('minutes_left', 5);
    }

    public function test_the_daily_limit_locks_until_tomorrows_class(): void
    {
        $this->played('2026-10-20', 30);

        $this->at('2026-10-20 15:30')
            ->assertJsonPath('status', 'daily_limit')
            ->assertJsonPath('minutes_left', 0)
            ->assertJsonPath('opens_at', '2026-10-20T23:30:00Z');

        // Yesterday's minutes don't count today.
        $this->at('2026-10-21 15:30')->assertJsonPath('status', 'after_school');
    }

    public function test_weekends_are_locked_unless_the_teacher_opens_them(): void
    {
        $this->at('2026-10-24 10:00')
            ->assertJsonPath('status', 'weekend_lock')
            ->assertJsonPath('opens_at', '2026-10-25T23:30:00Z'); // Monday 07:30 Manila

        AccessSchedule::forSection($this->student->section_id)->fill(['weekends_open' => true, 'daily_minutes' => 20])->save();

        $this->at('2026-10-24 10:00')
            ->assertJsonPath('status', 'after_school')
            ->assertJsonPath('window', 'weekend')
            ->assertJsonPath('minutes_left', 20)
            ->assertJsonPath('schedule.weekends_open', true);

        $this->played('2026-10-24', 20);
        $this->at('2026-10-24 10:00')
            ->assertJsonPath('status', 'daily_limit')
            ->assertJsonPath('opens_at', '2026-10-24T16:00:00Z'); // Sunday 00:00 Manila
    }

    public function test_the_sections_own_schedule_is_used(): void
    {
        $schedule = new AccessSchedule(['class_start' => '09:00', 'class_end' => '10:00', 'after_school_start' => '16:00',
            'after_school_end' => '18:00', 'daily_minutes' => 45, 'weekends_open' => false]);
        $schedule->section_id = $this->student->section_id;
        $schedule->save();

        $this->at('2026-10-20 07:45')->assertJsonPath('status', 'class_lock');
        $this->at('2026-10-20 09:30')->assertJsonPath('status', 'allowed')->assertJsonPath('minutes_left', 30);
        $this->at('2026-10-20 16:00')->assertJsonPath('minutes_left', 45);
    }

    public function test_every_decision_is_logged_and_only_students_may_ask(): void
    {
        $this->at('2026-10-20 10:00');

        $log = SystemLog::where('event', 'access.check')->sole();
        $this->assertEquals(['student' => $this->student->code, 'status' => 'class_lock', 'minutes_left' => 0], $log->context);

        Sanctum::actingAs(User::factory()->create());
        $this->getJson('/api/access/student/status')->assertForbidden();
    }
}
