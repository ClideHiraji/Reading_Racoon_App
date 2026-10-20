<?php

namespace Tests\Unit;

use App\Support\LoginCode;
use PHPUnit\Framework\TestCase;

class LoginCodeTest extends TestCase
{
    public function test_generated_codes_use_only_unambiguous_characters(): void
    {
        for ($i = 0; $i < 200; $i++) {
            $code = LoginCode::generate();

            $this->assertSame(LoginCode::LENGTH, strlen($code));
            $this->assertTrue(LoginCode::isWellFormed($code));
            $this->assertDoesNotMatchRegularExpression('/[01IOL]/', $code);
        }
    }

    public function test_input_ignores_case_spaces_and_dashes(): void
    {
        $this->assertSame('K7PM3QXA', LoginCode::normalize(" k7pm-3q xa\t"));
        $this->assertSame(LoginCode::hash('K7PM3QXA'), LoginCode::hash('k7pm - 3qxa'));
        $this->assertTrue(LoginCode::isWellFormed('k7pm-3qxa'));
    }

    public function test_malformed_input_is_not_a_code(): void
    {
        $this->assertFalse(LoginCode::isWellFormed('K7PM3QX'));     // too short
        $this->assertFalse(LoginCode::isWellFormed('K7PM3QXAB'));   // too long
        $this->assertFalse(LoginCode::isWellFormed('K7PM3QX0'));    // 0 is not in the alphabet
        $this->assertFalse(LoginCode::isWellFormed('K7PM_3QXA'));
        $this->assertFalse(LoginCode::isWellFormed(''));
    }

    public function test_hash_is_sha256_of_the_normalized_code(): void
    {
        $this->assertSame(hash('sha256', 'K7PM3QXA'), LoginCode::hash('k7pm-3qxa'));
    }

    public function test_format_splits_the_code_for_cards(): void
    {
        $this->assertSame('K7PM-3QXA', LoginCode::format('k7pm3qxa'));
    }
}
