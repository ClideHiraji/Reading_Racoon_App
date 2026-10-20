<?php

namespace Tests\Feature;

use App\Actions\EnrollStudent;
use App\Enums\UserRole;
use App\Models\Section;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EnrollStudentTest extends TestCase
{
    use RefreshDatabase;

    public function test_enrolling_creates_the_student_and_their_starting_game_state(): void
    {
        $section = Section::factory()->create();

        ['student' => $student, 'login_code' => $code] = app(EnrollStudent::class)->handle($section, 'Ana');

        $this->assertMatchesRegularExpression('/^[A-HJKMNP-Z2-9]{4}-[A-HJKMNP-Z2-9]{4}$/', $code);
        $this->assertSame(UserRole::Student, $student->user->role);
        $this->assertNull($student->user->email);
        $this->assertNull($student->user->password);
        $this->assertSame($section->id, $student->section_id);

        // 14 BKT states, each starting at its sub-skill's P(L0) (Table 3.5, D-003).
        $states = $student->bktStates()->orderBy('id')->get()
            ->map(fn ($s) => [$s->sub_skill, $s->level, $s->p_mastery, $s->attempts, $s->mastered_at, $s->review])
            ->all();
        $this->assertEquals([
            ['phonological_awareness', 1, 0.20, 0, null, false],
            ['phonological_awareness', 2, 0.20, 0, null, false],
            ['phonics', 1, 0.25, 0, null, false],
            ['phonics', 2, 0.25, 0, null, false],
            ['phonics', 3, 0.25, 0, null, false],
            ['vocabulary', 2, 0.30, 0, null, false],
            ['vocabulary', 3, 0.30, 0, null, false],
            ['vocabulary', 4, 0.30, 0, null, false],
            ['fluency', 3, 0.15, 0, null, false],
            ['fluency', 4, 0.15, 0, null, false],
            ['fluency', 5, 0.15, 0, null, false],
            ['literal_comprehension', 3, 0.20, 0, null, false],
            ['literal_comprehension', 4, 0.20, 0, null, false],
            ['literal_comprehension', 5, 0.20, 0, null, false],
        ], $states);

        $wallet = $student->wallet()->first();
        $this->assertSame([0, 0], [$wallet->xp, $wallet->coins]);

        $path = $student->pathProgress()->first();
        $this->assertSame(1, $path->highest_unlocked);
        $this->assertSame([], $path->worlds);
    }

    public function test_every_student_gets_a_different_code(): void
    {
        $section = Section::factory()->create();
        $enroll = app(EnrollStudent::class);

        $codes = collect(range(1, 20))->map(fn ($i) => $enroll->handle($section, "Kid $i")['login_code']);

        $this->assertCount(20, $codes->unique());
    }
}
