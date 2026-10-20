<?php

namespace Tests\Unit;

use App\Reports\AiReportCheck;
use Tests\TestCase;
use UnexpectedValueException;

/**
 * The checks a Gemini report must pass before a teacher sees it (FR-05, D-015).
 */
class AiReportCheckTest extends TestCase
{
    private const INPUT = [
        'learner_code' => 'RR-7K2M9Q',
        'map_level' => 3,
        'accuracy_percent' => 64,
        'average_stars' => 2.5,
        'sub_skills' => ['Reading Fluency' => ['p_mastery' => 0.42, 'levels' => [3, 4, 5]]],
        'strengths' => [],
        'needs_support' => ['Reading Fluency'],
    ];

    private function text(string $extra = '', string $fluency = 'fluency'): string
    {
        return 'The learner RR-7K2M9Q is on map level 3 and answers 64% of questions correctly, with 2.5 stars on average. '
            .'They work hard in every lesson and enjoy the stories. '.$extra
            ."\n\n"
            ."Their {$fluency} needs support: P(L) is 42% (0.42), below the 95% mastery mark. "
            .'Use echo reading of short sentences and reread the same text two or three times each day.';
    }

    private function reason(string $text): string
    {
        try {
            AiReportCheck::paragraphs($text, self::INPUT, 120);
        } catch (UnexpectedValueException $e) {
            return $e->getMessage();
        }

        return 'passed';
    }

    public function test_a_reply_built_from_the_facts_passes(): void
    {
        $paragraphs = AiReportCheck::paragraphs('  **'.$this->text()."**\n", self::INPUT, 120);

        $this->assertCount(2, $paragraphs);
        $this->assertStringStartsWith('The learner RR-7K2M9Q', $paragraphs[0]);
        $this->assertStringNotContainsString('**', $paragraphs[1]);
    }

    public function test_numbers_must_come_from_the_facts_or_the_bkt_thresholds(): void
    {
        $this->assertSame('passed', $this->reason($this->text('Mastery needs at least 5 answers above 0.95; below 0.3 is low.')));
        $this->assertSame('number 70 is not in the facts', $this->reason($this->text('Aim for 70% next week.')));
        $this->assertSame('number 2026 is not in the facts', $this->reason($this->text('Keep going in 2026.')));
    }

    public function test_the_learner_code_digits_are_not_read_as_numbers_but_other_codes_fail(): void
    {
        $this->assertSame('passed', $this->reason($this->text('Learner rr-7k2m9q is improving.')));
        $this->assertSame('names another learner code (RR-ABCDEF)', $this->reason($this->text('So is RR-ABCDEF.')));
    }

    public function test_the_needs_support_skill_must_be_named_by_label_or_plain_name(): void
    {
        $this->assertSame('passed', $this->reason($this->text(fluency: 'Reading Fluency')));
        $this->assertSame('does not name Reading Fluency, which needs support', $this->reason($this->text(fluency: 'reading speed')));
    }

    public function test_length_and_formatting(): void
    {
        $this->assertSame('expected 2 paragraphs, got 1', $this->reason(str_replace("\n\n", ' ', $this->text())));
        $this->assertSame('formatted as a list or heading', $this->reason("# Report\n\n".$this->text()));
        $this->assertSame('formatted as a list or heading', $this->reason(str_replace("\n\n", "\n\n1. ", $this->text())));
        $this->assertMatchesRegularExpression('/^\d+ words, expected 40-120$/', $this->reason($this->text(str_repeat('Lovely work. ', 40))));
        $this->assertMatchesRegularExpression('/^\d+ words, expected 40-120$/', $this->reason("Short.\n\nAlso short fluency."));
    }
}
