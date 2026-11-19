<?php

namespace Tests\Feature\Teacher;

use App\Enums\RegistrationStatus;
use App\Enums\UserRole;
use App\Models\Section;
use App\Models\SystemLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Teacher self-registration, approval gate and sign-in (FR-01, FR-08).
 */
class TeacherAuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_registration_creates_a_pending_teacher_with_their_section(): void
    {
        $this->post('/register', [
            'name' => 'Maria Santos', 'email' => 'Maria@School.test', 'school' => 'Butuan Central ES',
            'section_name' => 'Grade 1 - Sampaguita', 'password' => 'correct horse 1', 'password_confirmation' => 'correct horse 1',
        ])->assertRedirect(route('register.pending'));

        $teacher = User::where('email', 'maria@school.test')->sole();
        $this->assertSame(UserRole::Teacher, $teacher->role);
        $this->assertSame(RegistrationStatus::Pending, $teacher->registration->status);
        $this->assertSame(['Grade 1 - Sampaguita'], $teacher->sections()->pluck('name')->all());
        $this->assertGuest();
        $this->assertSame(1, SystemLog::where('event', 'teacher.registered')->count());
    }

    public function test_a_pending_or_denied_teacher_cannot_sign_in(): void
    {
        $pending = User::factory()->registered(RegistrationStatus::Pending)->create();
        $denied = User::factory()->registered(RegistrationStatus::Denied)->create();

        $this->post('/login', ['email' => $pending->email, 'password' => 'password'])
            ->assertSessionHasErrors(['email' => 'Your registration is waiting for approval. You can sign in once it is approved.']);
        $this->post('/login', ['email' => $denied->email, 'password' => 'password'])
            ->assertSessionHasErrors('email');
        $this->assertGuest();
    }

    public function test_an_approved_teacher_signs_in_and_lands_on_their_section(): void
    {
        $teacher = User::factory()->registered()->create();
        $section = $teacher->sections()->create(['name' => 'Grade 1 - Rosal']);

        $this->post('/login', ['email' => $teacher->email, 'password' => 'password'])->assertRedirect(route('teacher.home'));
        $this->assertAuthenticatedAs($teacher);

        $this->get('/teacher')->assertRedirect(route('teacher.sections.show', $section));
        $this->get(route('teacher.sections.show', $section))->assertOk()->assertSee('Grade 1 - Rosal');
        $this->assertNotNull($teacher->fresh()->last_login_at);
    }

    public function test_wrong_passwords_are_logged_and_locked_after_five_tries(): void
    {
        $teacher = User::factory()->registered()->create();

        for ($i = 0; $i < 5; $i++) {
            $this->post('/login', ['email' => $teacher->email, 'password' => 'nope'])->assertSessionHasErrors('email');
        }
        $this->post('/login', ['email' => $teacher->email, 'password' => 'password'])
            ->assertSessionHasErrors('email');
        $this->assertGuest();

        $logs = SystemLog::where('event', 'auth.failed')->orderBy('id')->get();
        $this->assertCount(5, $logs);
        $this->assertTrue($logs->last()->anomaly, 'five failures from one IP within 15 minutes');
        $this->assertFalse($logs->first()->anomaly);
    }

    public function test_admins_and_students_cannot_use_the_teacher_sign_in(): void
    {
        $admin = User::factory()->admin()->create();

        $this->post('/login', ['email' => $admin->email, 'password' => 'password'])
            ->assertSessionHasErrors(['email' => __('auth.failed')]);
        $this->assertGuest();
    }

    public function test_a_teacher_revoked_after_signing_in_is_signed_out(): void
    {
        $teacher = User::factory()->registered()->create();
        $teacher->sections()->create(['name' => 'Grade 1 - Rosal']);
        $this->actingAs($teacher);

        $teacher->registration->forceFill(['status' => RegistrationStatus::Denied])->save();

        $this->get('/teacher')->assertRedirect(route('login'));
        $this->assertGuest();
    }

    public function test_guests_are_sent_to_the_sign_in_page(): void
    {
        $section = Section::factory()->create();

        $this->get('/')->assertRedirect('/login');
        $this->get(route('teacher.sections.show', $section))->assertRedirect(route('login'));
        $this->get('/login')->assertOk()->assertSee('Teacher sign in');
    }
}
