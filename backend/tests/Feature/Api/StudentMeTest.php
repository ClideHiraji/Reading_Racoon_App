<?php

namespace Tests\Feature\Api;

use App\Actions\EnrollStudent;
use App\Models\Section;
use App\Models\Student;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * GET /api/student/me: the server's official state, shaped for the client's
 * StudentModel.from_dict() (FR-03, FR-07, D-008, D-010).
 */
class StudentMeTest extends TestCase
{
    use RefreshDatabase;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $section = Section::factory()->create(['name' => 'Grade 1 - Sampaguita']);
        $this->student = app(EnrollStudent::class)->handle($section, 'Ana')['student'];
    }

    public function test_a_new_student_gets_their_starting_state(): void
    {
        Sanctum::actingAs($this->student->user);

        $response = $this->getJson('/api/student/me')->assertOk()
            ->assertJsonPath('student.code', $this->student->code)
            ->assertJsonPath('student.name', 'Ana')
            ->assertJsonPath('student.section.name', 'Grade 1 - Sampaguita')
            ->assertJsonPath('model.highest_unlocked', 1)
            ->assertJsonPath('model.states.phonics:1', ['p' => 0.25, 'attempts' => 0, 'mastered' => false, 'review' => false])
            ->assertJsonPath('aral_band', 'ARAL Basic')
            ->assertJsonPath('wallet', ['xp' => 0, 'coins' => 0])
            ->assertJsonPath('items', [])
            ->assertJsonStructure(['server_time', 'bkt_version', 'path' => ['worlds'], 'equipped']);

        $this->assertCount(14, $response->json('model.states'));
        // Objects, not [] arrays, so Godot's JSON gives Dictionaries.
        $this->assertStringContainsString('"worlds":{}', $response->getContent());
        $this->assertStringContainsString('"equipped":{}', $response->getContent());
    }

    public function test_it_returns_the_replayed_state_after_a_sync(): void
    {
        Sanctum::actingAs($this->student->user);
        $events = [];
        foreach ([['phonological_awareness', 1], ['phonics', 1]] as [$skill, $level]) {
            for ($i = 0; $i < 5; $i++) {
                $events[] = ['id' => (string) Str::uuid(), 'type' => 'response', 'device_time' => '2026-10-20T01:00:00Z',
                    'payload' => ['skill' => $skill, 'level' => $level, 'correct' => true, 'num_choices' => 3]];
            }
        }
        $events[] = ['id' => (string) Str::uuid(), 'type' => 'chest', 'payload' => ['level' => 1], 'device_time' => '2026-10-20T01:00:01Z'];
        $events[] = ['id' => (string) Str::uuid(), 'type' => 'purchase', 'payload' => ['item_id' => 'bow', 'cost' => 10, 'slot' => 'hat'], 'device_time' => '2026-10-20T01:00:02Z'];
        $events[] = ['id' => (string) Str::uuid(), 'type' => 'equip', 'payload' => ['item_id' => 'bow', 'slot' => 'hat'], 'device_time' => '2026-10-20T01:00:03Z'];
        $this->postJson('/api/sync', ['events' => $events])->assertOk();

        $this->getJson('/api/student/me')->assertOk()
            ->assertJsonPath('model.highest_unlocked', 2)
            ->assertJsonPath('model.states.phonics:1.mastered', true)
            ->assertJsonPath('model.states.phonics:1.attempts', 5)
            ->assertJsonPath('aral_band', 'ARAL Basic / Plus')
            ->assertJsonPath('wallet.coins', 5)
            ->assertJsonPath('items', [['item_id' => 'bow', 'slot' => 'hat', 'equipped' => true]])
            ->assertJsonPath('equipped', ['hat' => 'bow'])
            ->assertJsonPath('path.worlds.1.chest', true);
    }

    public function test_only_students_can_read_it(): void
    {
        $this->getJson('/api/student/me')->assertUnauthorized();

        Sanctum::actingAs(User::factory()->create());
        $this->getJson('/api/student/me')->assertForbidden();
    }
}
