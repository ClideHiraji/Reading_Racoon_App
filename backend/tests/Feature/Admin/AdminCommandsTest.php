<?php

namespace Tests\Feature\Admin;

use App\Enums\UserRole;
use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use PragmaRX\Google2FA\Google2FA;

/**
 * Admins exist only through artisan (D-013): admin:create and admin:reset-2fa.
 */
class AdminCommandsTest extends AdminTestCase
{
    private const PASSWORD = 'Correct horse battery 9';

    public function test_admin_create_makes_an_admin_with_an_encrypted_totp_secret(): void
    {
        $this->artisan('admin:create', ['email' => 'Root@School.test', '--name' => 'IT Office'])
            ->expectsQuestion('Password (at least 12 characters, not shown)', self::PASSWORD)
            ->expectsQuestion('Repeat the password', self::PASSWORD)
            ->expectsOutputToContain('Admin root@school.test created.')
            ->expectsOutputToContain('otpauth://totp/')
            ->assertSuccessful();

        $admin = User::where('email', 'root@school.test')->sole();
        $this->assertSame(UserRole::Admin, $admin->role);
        $this->assertSame(32, strlen($admin->two_factor_secret));
        $raw = DB::table('users')->where('id', $admin->id)->value('two_factor_secret');
        $this->assertNotSame($admin->two_factor_secret, $raw, 'stored encrypted');
        $this->assertSame(1, AuditLog::where('action', 'admin.created')->count());

        // The printed secret works for signing in.
        $this->post($this->admin(), ['email' => 'root@school.test', 'password' => self::PASSWORD,
            'code' => app(Google2FA::class)->getCurrentOtp($admin->two_factor_secret)])->assertRedirect($this->admin('home'));
    }

    public function test_admin_create_refuses_weak_or_mismatched_passwords_and_duplicates(): void
    {
        $this->artisan('admin:create', ['email' => 'root@school.test'])
            ->expectsQuestion('Password (at least 12 characters, not shown)', 'short1')
            ->expectsQuestion('Repeat the password', 'short1')
            ->assertFailed();
        $this->artisan('admin:create', ['email' => 'root@school.test'])
            ->expectsQuestion('Password (at least 12 characters, not shown)', self::PASSWORD)
            ->expectsQuestion('Repeat the password', 'something else 123')
            ->assertFailed();
        $this->assertDatabaseCount('users', 0);

        User::factory()->create(['email' => 'taken@school.test']);
        $this->artisan('admin:create', ['email' => 'taken@school.test'])->assertFailed();
    }

    public function test_reset_2fa_replaces_the_secret(): void
    {
        [$admin, $old] = $this->makeAdmin();

        $this->artisan('admin:reset-2fa', ['email' => $admin->email])
            ->expectsConfirmation("Replace the two-factor secret of {$admin->email}? Their current authenticator entry stops working.", 'yes')
            ->expectsOutputToContain('otpauth://totp/')
            ->assertSuccessful();

        $this->assertNotSame($old, $admin->fresh()->two_factor_secret);
        $this->assertSame(1, AuditLog::where('action', 'admin.2fa_reset')->count());
        $this->artisan('admin:reset-2fa', ['email' => 'nobody@school.test'])->assertFailed();
    }
}
