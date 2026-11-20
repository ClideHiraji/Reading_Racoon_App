<?php

namespace Tests\Feature\Api;

use App\Actions\EnrollStudent;
use App\Models\Section;
use App\Models\Student;
use App\Models\SystemLog;
use App\Support\LoginCode;
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
        $this->assertSame(LoginCode::hash($normalized), $hash);
        $this->assertDatabaseMissing('users', ['login_code_hash' => $normalized]);
        // Keyed (D-036): the plain SHA-256 a leaked backup could be brute-forced from is not stored.
        $this->assertNotSame(hash('sha256', $normalized), $hash);
        $this->assertSame(hash_hmac('sha256', $normalized, hash_hmac('sha256', 'reading-racoon/login-code/v2', config('app.key'), true)), $hash);
    }

    public function test_an_account_with_the_old_unkeyed_hash_signs_in_once_and_is_upgraded(): void
    {
        ['student' => $student, 'login_code' => $code] = $this->enroll();
        $student->user->forceFill(['login_code_hash' => LoginCode::legacyHash($code)])->save();

        $this->postJson('/api/auth/login', ['login_code' => $code])->assertOk();

        $this->assertSame(LoginCode::hash($code), $student->user->fresh()->getRawOriginal('login_code_hash'));
        $this->postJson('/api/auth/login', ['login_code' => $code])->assertOk();
    }

    public function test_a_new_login_code_key_retires_every_old_code(): void
    {
        ['login_code' => $code] = $this->enroll();
        config(['reading_racoon.security.login_code_key' => 'a-different-secret']);

        $this->postJson('/api/auth/login', ['login_code' => $code])->assertUnprocessable();
    }

    public function test_the_reply_says_when_the_token_expires(): void
    {
        ['login_code' => $code] = $this->enroll();

        $expires = $this->postJson('/api/auth/login', ['login_code' => $code])->assertOk()->json('expires_at');

        $this->assertNotNull($expires);
        $this->assertTrue(now()->addMinutes(config('sanctum.expiration'))->subMinute()->lessThan($expires));
    }

    public function test_sign_ins_are_logged_for_the_admin_without_the_code(): void
    {
        ['student' => $student, 'login_code' => $code] = $this->enroll();

        $this->postJson('/api/auth/login', ['login_code' => $code, 'device_name' => 'Tablet 3'])->assertOk();
        $this->postJson('/api/auth/login', ['login_code' => 'ABCD-2345', 'device_name' => 'Tablet 3'])->assertUnprocessable();
        $this->postJson('/api/auth/login', ['login_code' => 'hello', 'device_name' => 'Tablet 3'])->assertUnprocessable();

        $ok = SystemLog::where('event', 'student.login')->sole();
        $this->assertEquals(['student' => $student->code, 'device' => 'Tablet 3'], $ok->context);   // jsonb sorts keys
        $this->assertSame(['unknown', 'malformed'], SystemLog::where('event', 'student.login_failed')
            ->orderBy('id')->get()->map(fn (SystemLog $log) => $log->context['reason'])->all());
        $logged = SystemLog::all()->toJson();
        $this->assertStringNotContainsString(str_replace('-', '', $code), str_replace('-', '', $logged), 'never the code');
        $this->assertStringNotContainsString('ABCD', $logged);
    }

    public function test_typing_the_student_id_is_recognised_in_the_log(): void
    {
        ['student' => $student] = $this->enroll();

        // RR-K7P3QX fits the game's 8 boxes as RRK7P3QX, but it is not a login code.
        $this->postJson('/api/auth/login', ['login_code' => str_replace('-', '', $student->code)])->assertUnprocessable();

        $this->assertSame('student_id', SystemLog::where('event', 'student.login_failed')->sole()->context['reason']);
    }

    public function test_five_wrong_codes_from_one_tablet_are_an_anomaly(): void
    {
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/auth/login', ['login_code' => 'ABCD-2345'])->assertUnprocessable();
        }

        $this->assertSame([false, false, false, false, true], SystemLog::where('event', 'student.login_failed')
            ->orderBy('id')->pluck('anomaly')->all());
    }

    public function test_login_is_rate_limited_per_address(): void
    {
        for ($i = 0; $i < 60; $i++) {
            $this->postJson('/api/auth/login', ['login_code' => 'ABCD-2345'])->assertUnprocessable();
        }

        $this->postJson('/api/auth/login', ['login_code' => 'ABCD-2345'])->assertTooManyRequests();
    }
}
