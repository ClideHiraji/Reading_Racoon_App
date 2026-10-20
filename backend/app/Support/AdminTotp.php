<?php

namespace App\Support;

use BaconQrCode\Renderer\PlainTextRenderer;
use BaconQrCode\Writer;
use Illuminate\Console\Command;
use PragmaRX\Google2FA\Google2FA;

/**
 * TOTP enrolment for admins (D-013): RFC 6238, 30-second codes, works with
 * Google Authenticator, Microsoft Authenticator, Aegis, 2FAS, etc.
 * Enrolment happens only in the server terminal, never on a web page.
 */
final class AdminTotp
{
    public function __construct(private readonly Google2FA $google2fa) {}

    /** A new random base32 secret (160 bits). */
    public function newSecret(): string
    {
        return $this->google2fa->generateSecretKey(32);
    }

    public function printSetup(Command $command, string $email, string $secret, bool $qr): void
    {
        $uri = $this->google2fa->getQRCodeUrl(config('admin.totp_issuer'), $email, $secret);

        $command->newLine();
        $command->warn('Two-factor setup. Shown only now: do not screenshot, share or store it anywhere else.');
        $command->line('1. In your authenticator app choose "Add account" > "Enter a setup key".');
        $command->line('   Account: '.$email);
        $command->line('   Key:     '.trim(chunk_split($secret, 4, ' ')));
        $command->line('   Type:    time-based (TOTP), 6 digits, 30 seconds');
        $command->line('2. Or scan the QR code (php artisan admin:... --qr), or paste this URI into a password manager:');
        $command->line('   '.$uri);
        if ($qr) {
            $command->newLine();
            $command->line((new Writer(new PlainTextRenderer(1)))->writeString($uri));
        }
        $command->line('3. Sign in on the admin portal with your email, password and the 6-digit code.');
    }
}
