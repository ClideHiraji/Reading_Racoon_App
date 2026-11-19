<?php

namespace App\Support;

/**
 * Temporary student login code, e.g. "K7PM-3QXA" (open issue 9: the real
 * login method for 6-year-olds is still undecided). FR-01, NFR-04.
 *
 * Codes are random, shown once when a student is enrolled, and stored only as
 * a SHA-256 hash, like Sanctum tokens. Input ignores case, spaces and dashes.
 */
final class LoginCode
{
    /** No 0/O or 1/I/L: children and teachers mix them up. 31^8 ≈ 8.5e11 codes. */
    public const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

    public const LENGTH = 8;

    /** A new random code in normalized form (8 characters, no dash). */
    public static function generate(): string
    {
        $code = '';
        for ($i = 0; $i < self::LENGTH; $i++) {
            $code .= self::ALPHABET[random_int(0, strlen(self::ALPHABET) - 1)];
        }

        return $code;
    }

    public static function normalize(string $input): string
    {
        return strtoupper((string) preg_replace('/[\s-]+/', '', $input));
    }

    public static function isWellFormed(string $input): bool
    {
        $code = self::normalize($input);

        return strlen($code) === self::LENGTH
            && strspn($code, self::ALPHABET) === self::LENGTH;
    }

    /**
     * What users.login_code_hash stores: an HMAC-SHA256 keyed with a server
     * secret (D-036). There are only 31^8 codes, so a plain SHA-256 from a
     * leaked database or backup could be reversed for every child in minutes
     * on one graphics card; without the key the hashes are useless.
     */
    public static function hash(string $input): string
    {
        return hash_hmac('sha256', self::normalize($input), self::key());
    }

    /**
     * The unkeyed SHA-256 used before D-036. Only for finding a not-yet-upgraded
     * account at sign-in (App\Http\Controllers\Api\LoginController).
     */
    public static function legacyHash(string $input): string
    {
        return hash('sha256', self::normalize($input));
    }

    /** A sub-key for login codes only, from LOGIN_CODE_KEY or else APP_KEY. */
    private static function key(): string
    {
        $secret = (string) config('reading_racoon.security.login_code_key') ?: (string) config('app.key');

        return hash_hmac('sha256', 'reading-racoon/login-code/v2', $secret, true);
    }

    /** "K7PM3QXA" → "K7PM-3QXA", easier to read off a card. */
    public static function format(string $code): string
    {
        $code = self::normalize($code);

        return substr($code, 0, 4).'-'.substr($code, 4);
    }
}
