<?php

namespace App\Console\Commands;

use App\Enums\UserRole;
use App\Models\AuditLog;
use App\Models\User;
use App\Support\AdminTotp;
use Illuminate\Console\Command;

/**
 * New TOTP secret for an admin who lost their phone (D-013). The old
 * authenticator entry stops working at once.
 */
class ResetAdminTwoFactor extends Command
{
    protected $signature = 'admin:reset-2fa
        {email : The admin\'s email address}
        {--qr : Also draw the setup QR code in the terminal}';

    protected $description = 'Give an admin a new TOTP two-factor secret';

    public function handle(AdminTotp $totp): int
    {
        $email = strtolower(trim($this->argument('email')));
        $admin = User::where('email', $email)->where('role', UserRole::Admin)->first();
        if ($admin === null) {
            $this->error('No admin with that email.');

            return self::FAILURE;
        }
        if (! $this->confirm("Replace the two-factor secret of {$email}? Their current authenticator entry stops working.", true)) {
            return self::FAILURE;
        }

        $secret = $totp->newSecret();
        $admin->forceFill(['two_factor_secret' => $secret, 'two_factor_last_step' => null])->save();
        AuditLog::record(null, 'admin.2fa_reset', $admin, ['email' => $email, 'via' => 'artisan']);

        $totp->printSetup($this, $email, $secret, (bool) $this->option('qr'));

        return self::SUCCESS;
    }
}
