<?php

namespace App\Reports;

use App\Support\SkillCatalog;

/**
 * The teacher-report prompt (FR-05, MLDLC Stage 3, D-015): a role definition,
 * the learner's numbers as a JSON block, and length and wording rules. It
 * lives on the server so it can be revised without a new APK.
 *
 * The JSON holds the student code and numbers only: no name, age or dates
 * (RA 10173, docs/knowledge/08-ai-integration.md).
 */
final class ReportPrompt
{
    /** Bump on any change to the wording or the JSON shape. Stored with every call and report. */
    public const VERSION = 'report-v1';

    /**
     * The JSON injected into the prompt, from StudentFacts::build(). It also
     * carries the template's strengths/needs split, so the AI writes about the
     * same sub-skills the lists under it show.
     *
     * @param  array<string, mixed>  $facts
     * @return array<string, mixed>
     */
    public static function input(array $facts): array
    {
        $groups = TemplateReportWriter::classify($facts);
        $labels = fn (array $skills) => array_map(fn (string $skill) => SkillCatalog::label($skill), $skills);

        $skills = [];
        $mastered = 0;
        $total = 0;
        foreach ($facts['skills'] as $s) {
            $mastered += count($s['mastered_levels']);
            $total += count($s['levels']);
            $skills[$s['label']] = [
                'unlocked' => $s['unlocked'],
                'current_level' => $s['current_level'],
                'current_level_mastered' => $s['current_mastered'],
                'p_mastery' => $s['p'],
                'answers_at_current_level' => $s['attempts'],
                'mastered_levels' => $s['mastered_levels'],
                'levels' => $s['levels'],
                'reviewing_after_heart_recovery' => $s['review'],
                'recent_accuracy_percent' => $s['recent_accuracy'],
                'recent_answers' => $s['recent_answers'],
            ];
        }

        $flags = [];
        foreach ($facts['open_flags'] as $flag) {
            $key = $flag['type'].'|'.$flag['sub_skill'];
            $flags[$key] ??= ['type' => $flag['type'], 'sub_skill' => $flag['sub_skill'] === null ? null : SkillCatalog::label($flag['sub_skill']), 'count' => 0];
            $flags[$key]['count']++;
        }

        return [
            'learner_code' => $facts['student_code'],
            'map_level' => $facts['highest_level'],
            'level_name' => $facts['level_name'],
            'world' => $facts['world'],
            'aral_band' => $facts['aral_band'],
            'answers' => $facts['responses'],
            'accuracy_percent' => $facts['accuracy'],
            'lessons' => $facts['lessons'],
            'average_stars' => $facts['average_stars'],
            'skill_levels_mastered' => $mastered,
            'skill_levels_total' => $total,
            'sub_skills' => $skills,
            'heart_recovery' => ['played' => $facts['rescues']['total'], 'not_completed' => $facts['rescues']['partial']],
            'open_teacher_flags' => array_values($flags),
            'pre_test' => self::score($facts['pre_test']),
            'post_test' => self::score($facts['post_test']),
            'pre_test_placed_on_map_level' => $facts['placed_level'],
            'strengths' => $labels($groups['strengths']),
            'needs_support' => $labels($groups['needs']),
        ];
    }

    /** Same JSON and prompt version: the stored report still fits (D-015). */
    public static function hash(array $input): string
    {
        return hash('sha256', self::VERSION.'|'.self::json($input));
    }

    /**
     * @param  array<string, mixed>  $input  self::input()
     * @return list<array{role: string, content: string}>
     */
    public static function messages(array $input, int $maxWords): array
    {
        $mastery = config('reading_racoon.bkt.mastery_p');
        $attempts = config('reading_racoon.bkt.mastery_min_attempts');
        $low = config('reading_racoon.bkt.hint_p');

        $system = <<<PROMPT
            You write short diagnostic summaries for Grade 1 teachers in the Philippines, from the numbers of a reading game.

            About the data: the game assesses five MATATAG reading sub-skills (Phonological Awareness, Phonics, Vocabulary, Reading Fluency, Literal Comprehension) on a map of 5 levels, using Bayesian Knowledge Tracing. p_mastery is the probability that the learner has mastered a sub-skill at its current level; a level counts as mastered at p_mastery {$mastery} or higher after at least {$attempts} answers, and below {$low} is low. aral_band is the learner's ARAL reading band. Heart Recovery is a short rescue game after the learner loses all hearts; when it is not completed, the sub-skill goes back one level for review. Open teacher flags: rescue_limit = Heart Recovery chances used up, rescue_partial = Heart Recovery failed, low_mastery = p_mastery stayed low.

            Rules:
            - Write exactly two paragraphs of plain text, separated by one blank line, at most {$maxWords} words in total. No headings, lists, bold or other formatting.
            - Paragraph 1: where the learner is (map level and ARAL band), how they are doing overall, and their strengths.
            - Paragraph 2: each sub-skill in needs_support, by name, with one concrete classroom activity for it that fits the MATATAG Grade 1 reading competencies. If needs_support is empty, say how to keep the learner progressing.
            - Use only facts and numbers that appear in the JSON. Do not calculate new numbers, estimate, or mention dates.
            - Refer to the learner as "the learner" or by learner_code. Never invent a name, age, gender or family detail.
            - Write for a teacher: warm, plain and professional. The summary supports the teacher's own judgement and does not replace it.
            PROMPT;

        return [
            ['role' => 'system', 'content' => $system],
            ['role' => 'user', 'content' => "Learner data (JSON):\n".self::json($input)],
        ];
    }

    /**
     * @param  array<string, array{correct: int, total: int}>  $scores  per sub-skill key
     * @return ?array{correct: int, total: int, percent: int, by_sub_skill: array<string, array{correct: int, total: int}>}
     */
    private static function score(array $scores): ?array
    {
        if ($scores === []) {
            return null;
        }
        $correct = array_sum(array_column($scores, 'correct'));
        $total = array_sum(array_column($scores, 'total'));
        $bySkill = [];
        foreach ($scores as $skill => $score) {
            $bySkill[SkillCatalog::label($skill)] = $score;
        }

        return ['correct' => $correct, 'total' => $total, 'percent' => $total > 0 ? (int) round(100 * $correct / $total) : 0, 'by_sub_skill' => $bySkill];
    }

    private static function json(array $input): string
    {
        return json_encode($input, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR);
    }
}
