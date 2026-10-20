<?php

namespace Tests\Feature\Admin;

use App\Models\AuditLog;
use App\Models\SystemLog;
use App\Models\User;
use Illuminate\Support\Str;

/**
 * The admin portal is not public (FR-08, D-012): reachable only under the
 * secret ADMIN_PATH, from an allowed IP, with password AND TOTP. Everything
 * else is the site's ordinary 404.
 */
class AdminConcealmentTest extends AdminTestCase
{
    public function test_without_the_secret_path_every_guess_is_a_404(): void
    {
        foreach (['/admin', '/admin/login', '/administrator', '/dashboard', '/'.Str::random(40), '/'.Str::random(40).'/home'] as $url) {
            $this->get($url)->assertNotFound();
        }
        $this->post('/admin', ['email' => 'x', 'password' => 'y', 'code' => '1'])->assertNotFound();
    }

    public function test_a_refused_admin_request_looks_exactly_like_any_other_404(): void
    {
        config(['app.debug' => false]);

        $unknown = $this->get('/'.Str::random(40).'/home');
        $refused = $this->get($this->admin('home'));         // real route, not signed in
        $method = $this->put($this->admin());                 // wrong method on a real route

        foreach ([$refused, $method] as $response) {
            $response->assertNotFound();
            $this->assertSame($unknown->getContent(), $response->getContent());
            $this->assertEmpty($response->headers->getCookies(), 'no session cookie gives the path away');
            $this->assertFalse($response->headers->has('X-Robots-Tag'));
        }
    }

    public function test_the_sign_in_form_is_only_under_the_secret_path_and_never_indexed(): void
    {
        $this->get($this->admin())
            ->assertOk()
            ->assertSee('Authenticator code')
            ->assertHeader('X-Robots-Tag', 'noindex, nofollow, noarchive')
            ->assertHeader('Referrer-Policy', 'no-referrer')
            ->assertDontSee('cdn.jsdelivr.net', false);
    }

    public function test_requests_from_an_ip_outside_the_allowlist_are_404_before_anything_else(): void
    {
        config(['admin.allowed_ips' => ['203.0.113.7', '10.20.0.0/16']]);
        [$admin, $secret] = $this->makeAdmin();

        $this->get($this->admin())->assertNotFound();            // tests come from 127.0.0.1
        $this->signIn($admin, $secret)->assertNotFound();
        $this->assertGuest('admin');
        $this->assertTrue(SystemLog::where('event', 'admin.ip_blocked')->first()->anomaly);

        $this->withServerVariables(['REMOTE_ADDR' => '203.0.113.7'])->get($this->admin())->assertOk();
        $this->withServerVariables(['REMOTE_ADDR' => '10.20.5.9'])->get($this->admin())->assertOk();
    }

    public function test_password_without_a_valid_totp_code_never_gets_in(): void
    {
        [$admin, $secret] = $this->makeAdmin();

        $this->post($this->admin(), ['email' => $admin->email, 'password' => 'a long admin password 1', 'code' => '000000'])
            ->assertRedirect($this->admin())
            ->assertSessionHasErrors(['email' => 'These credentials do not match.']);
        $this->post($this->admin(), ['email' => $admin->email, 'password' => 'a long admin password 1'])
            ->assertSessionHasErrors('code');

        $this->assertGuest('admin');
        $this->get($this->admin('home'))->assertNotFound();
        $this->assertSame('totp', SystemLog::where('event', 'admin.login_failed')->first()->context['failed']);
    }

    public function test_an_admin_without_an_enrolled_secret_cannot_sign_in(): void
    {
        [$admin] = $this->makeAdmin();
        $admin->forceFill(['two_factor_secret' => null])->save();

        $this->post($this->admin(), ['email' => $admin->email, 'password' => 'a long admin password 1', 'code' => '123456'])
            ->assertSessionHasErrors('email');
        $this->assertGuest('admin');
    }

    public function test_password_and_totp_sign_in_and_a_code_cannot_be_replayed(): void
    {
        [$admin, $secret] = $this->makeAdmin();
        $code = $this->code($secret);

        $this->post($this->admin(), ['email' => $admin->email, 'password' => 'a long admin password 1', 'code' => $code])
            ->assertRedirect($this->admin('home'));
        $this->assertAuthenticatedAs($admin, 'admin');
        $this->get($this->admin('home'))->assertOk()->assertSee('Overview')->assertHeader('Cache-Control', 'no-store, private');
        $this->assertSame(1, AuditLog::where('action', 'admin.login')->count());
        $this->assertSame(1, AuditLog::where('action', 'admin.view')->count());

        $this->post($this->admin('logout'))->assertRedirect($this->admin());
        $this->get($this->admin('home'))->assertNotFound();

        $this->post($this->admin(), ['email' => $admin->email, 'password' => 'a long admin password 1', 'code' => $code])
            ->assertSessionHasErrors('email');
        $this->assertGuest('admin');
    }

    public function test_five_failures_lock_the_form_into_a_404(): void
    {
        [$admin, $secret] = $this->makeAdmin();

        for ($i = 0; $i < 5; $i++) {
            $this->post($this->admin(), ['email' => $admin->email, 'password' => 'wrong', 'code' => '123456'])->assertRedirect();
        }
        $this->signIn($admin, $secret)->assertNotFound();
        $this->assertGuest('admin');

        $this->assertTrue(SystemLog::where('event', 'admin.login_failed')->latest('id')->first()->anomaly);
        $this->assertSame(1, SystemLog::where('event', 'admin.login_throttled')->count());
    }

    public function test_an_idle_admin_session_expires_into_a_404(): void
    {
        [$admin, $secret] = $this->makeAdmin();
        $this->signIn($admin, $secret);

        $this->travel(config('admin.idle_minutes') + 1)->minutes();

        $this->get($this->admin('home'))->assertNotFound();
        $this->assertGuest('admin');
    }

    public function test_teachers_and_teacher_sessions_never_reach_the_portal(): void
    {
        $teacher = User::factory()->registered()->create(['password' => 'a long admin password 1']);

        $this->post($this->admin(), ['email' => $teacher->email, 'password' => 'a long admin password 1', 'code' => '123456'])
            ->assertSessionHasErrors('email');
        $this->assertSame('account', SystemLog::where('event', 'admin.login_failed')->first()->context['failed']);

        $this->actingAs($teacher)->get($this->admin('home'))->assertNotFound();
        $this->actingAs($teacher, 'admin')->get($this->admin('home'))->assertNotFound();
    }

    public function test_an_admin_cannot_use_the_teacher_sign_in(): void
    {
        [$admin] = $this->makeAdmin();

        $this->post('/login', ['email' => $admin->email, 'password' => 'a long admin password 1'])->assertSessionHasErrors('email');
        $this->assertGuest();
    }

    public function test_no_public_page_links_to_the_portal(): void
    {
        $teacher = User::factory()->registered()->create();
        $section = $teacher->sections()->create(['name' => 'Grade 1 - Rosal']);

        foreach (['/login', '/register', '/register/sent'] as $url) {
            $this->get($url)->assertDontSee($this->adminPath, false);
        }
        $this->actingAs($teacher)->get(route('teacher.sections.show', $section))->assertDontSee($this->adminPath, false);
        $this->assertStringNotContainsString($this->adminPath, (string) file_get_contents(public_path('robots.txt')));
    }
}
