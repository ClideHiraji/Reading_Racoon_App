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

    public static function hash(string $input): string
    {
        return hash('sha256', self::normalize($input));
    }

    /** "K7PM3QXA" → "K7PM-3QXA", easier to read off a card. */
    public static function format(string $code): string
    {
        $code = self::normalize($code);

        return substr($code, 0, 4).'-'.substr($code, 4);
    }
}
