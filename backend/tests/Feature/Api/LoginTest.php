<?php

namespace Tests\Feature\Api;

use App\Actions\EnrollStudent;
use App\Models\Section;
use App\Models\Student;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * POST /api/auth/login with the temporary student login code (FR-01, open issue 9).
 */
class LoginTest extends TestCase
{
    use RefreshDatabase;

    /** @return array{student: Student, login_code: string} */
    private function enroll(string $name = 'Ana'): array
    {
        return app(EnrollStudent::class)->handle(Section::factory()->create(), $name);
    }

    public function test_student_signs_in_with_the_login_code_and_can_sync(): void
    {
        ['student' => $student, 'login_code' => $code] = $this->enroll();

        $response = $this->postJson('/api/auth/login', ['login_code' => $code, 'device_name' => 'Tablet 3'])
            ->assertOk()
            ->assertJsonPath('token_type', 'Bearer')
            ->assertJsonPath('user.id', $student->user_id)
            ->assertJsonPath('user.role', 'student')
            ->assertJsonPath('user.name', 'Ana')
            ->assertJsonPath('student.id', $student->id)
            ->assertJsonPath('student.section_id', $student->section_id)
            ->assertJsonMissingPath('user.login_code_hash');

        $this->assertDatabaseHas('personal_access_tokens', [
            'tokenable_id' => $student->user_id,
            'name' => 'Tablet 3',
        ]);

        $id = (string) Str::uuid();
        $this->withToken($response->json('token'))
            ->postJson('/api/sync', ['events' => [[
                'id' => $id, 'type' => 'hearts', 'payload' => ['hearts' => 3], 'device_time' => '2026-10-20T04:34:56Z',
            ]]])
            ->assertOk()
            ->assertJsonPath('acknowledged', [$id]);
    }

    public function test_code_ignores_case_spaces_and_dashes(): void
    {
        $code = $this->enroll()['login_code'];
        $typed = strtolower(str_replace('-', ' ', $code));

        $this->postJson('/api/auth/login', ['login_code' => $typed])->assertOk();
    }

    public function test_wrong_code_is_refused_without_a_token(): void
    {
        $this->enroll();

        $this->postJson('/api/auth/login', ['login_code' => 'ABCD-2345'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['login_code']);
        $this->postJson('/api/auth/login', ['login_code' => 'not a code at all'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['login_code']);

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_code_is_required(): void
    {
        $this->postJson('/api/auth/login', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['login_code']);
    }

    public function test_only_a_hash_of_the_code_is_stored(): void
    {
        ['student' => $student, 'login_code' => $code] = $this->enroll();
        $normalized = str_replace('-', '', $code);

        $hash = $student->user->getRawOriginal('login_code_hash');
        $this->assertSame(hash('sha256', $normalized), $hash);
        $this->assertDatabaseMissing('users', ['login_code_hash' => $normalized]);
    }

    public function test_login_is_rate_limited_per_address(): void
    {
        for ($i = 0; $i < 60; $i++) {
            $this->postJson('/api/auth/login', ['login_code' => 'ABCD-2345'])->assertUnprocessable();
        }

        $this->postJson('/api/auth/login', ['login_code' => 'ABCD-2345'])->assertTooManyRequests();
    }
}
