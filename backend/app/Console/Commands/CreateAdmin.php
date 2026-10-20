<?php

namespace App\Console\Commands;

use App\Enums\UserRole;
use App\Models\AuditLog;
use App\Models\User;
use App\Support\AdminTotp;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rules\Password;

/**
 * The only way to create an admin (FR-08, D-012): there is no admin
 * registration page. Prints the TOTP setup key once, for an authenticator app.
 */
class CreateAdmin extends Command
{
    protected $signature = 'admin:create
        {email : The admin\'s email address}
        {--name= : Display name (defaults to the part of the email before @)}
        {--qr : Also draw the setup QR code in the terminal}';

    protected $description = 'Create an admin account with a password and TOTP two-factor sign-in';

    public function handle(AdminTotp $totp): int
    {
        $email = strtolower(trim($this->argument('email')));
        $name = $this->option('name') ?: strstr($email, '@', true);

        $validator = Validator::make(['email' => $email, 'name' => $name], [
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'name' => ['required', 'string', 'max:100'],
        ]);
        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $error) {
                $this->error($error);
            }

            return self::FAILURE;
        }

        $password = (string) $this->secret('Password (at least 12 characters, not shown)');
        if ($password !== (string) $this->secret('Repeat the password')) {
            $this->error('The passwords do not match.');

            return self::FAILURE;
        }
        $check = Validator::make(['password' => $password], ['password' => [Password::min(12)->letters()->numbers()]]);
        if ($check->fails()) {
            $this->error($check->errors()->first('password'));

            return self::FAILURE;
        }

        $secret = $totp->newSecret();
        $admin = new User(['name' => $name, 'email' => $email, 'password' => $password]);
        $admin->forceFill(['role' => UserRole::Admin, 'two_factor_secret' => $secret])->save();
        AuditLog::record(null, 'admin.created', $admin, ['email' => $email, 'via' => 'artisan']);

        $this->info("Admin {$email} created.");
        $totp->printSetup($this, $email, $secret, (bool) $this->option('qr'));

        return self::SUCCESS;
    }
}
