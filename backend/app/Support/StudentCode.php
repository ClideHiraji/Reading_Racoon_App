<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;

/**
 * Pseudonymous student code, e.g. "RR-7K2M9Q", used instead of names in
 * research exports, logs and (later) Gemini prompts (RA 10173, NFR-04).
 * It is not a credential: the login code is separate and stored hashed.
 */
final class StudentCode
{
    public const PREFIX = 'RR-';

    public const LENGTH = 6;

    public static function generate(): string
    {
        $code = '';
        for ($i = 0; $i < self::LENGTH; $i++) {
            $code .= LoginCode::ALPHABET[random_int(0, strlen(LoginCode::ALPHABET) - 1)];
        }

        return self::PREFIX.$code;
    }

    public static function unique(): string
    {
        do {
            $code = self::generate();
        } while (DB::table('students')->where('code', $code)->exists());

        return $code;
    }
}
