<?php

namespace Tests\Feature\Admin;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use PragmaRX\Google2FA\Google2FA;
use Tests\TestCase;

/**
 * Boots the app with a random ADMIN_PATH (routes are registered at boot, so
 * it must be in the environment before the app is created). The value exists
 * only for the length of one test; no real secret is ever written down.
 */
abstract class AdminTestCase extends TestCase
{
    use RefreshDatabase;

    protected string $adminPath;

    protected function adminPathForTest(): string
    {
        return Str::random(40);
    }

    public function createApplication()
    {
        $this->adminPath = $this->adminPathForTest();
        $_ENV['ADMIN_PATH'] = $_SERVER['ADMIN_PATH'] = $this->adminPath;
        putenv('ADMIN_PATH='.$this->adminPath);

        return parent::createApplication();
    }

    protected function tearDown(): void
    {
        parent::tearDown();
        unset($_ENV['ADMIN_PATH'], $_SERVER['ADMIN_PATH']);
        putenv('ADMIN_PATH');
    }

    protected function admin(string $path = ''): string
    {
        return '/'.$this->adminPath.($path === '' ? '' : '/'.ltrim($path, '/'));
    }

    /** @return array{0: User, 1: string} the admin and their TOTP secret */
    protected function makeAdmin(string $email = 'root@school.test'): array
    {
        $secret = app(Google2FA::class)->generateSecretKey(32);
        $admin = User::factory()->admin()->create(['email' => $email, 'password' => 'a long admin password 1']);
        $admin->forceFill(['two_factor_secret' => $secret])->save();

        return [$admin, $secret];
    }

    protected function code(string $secret): string
    {
        return app(Google2FA::class)->getCurrentOtp($secret);
    }

    protected function signIn(User $admin, string $secret)
    {
        return $this->post($this->admin(), ['email' => $admin->email, 'password' => 'a long admin password 1', 'code' => $this->code($secret)]);
    }
}
