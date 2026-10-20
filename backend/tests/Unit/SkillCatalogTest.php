<?php

namespace Tests\Unit;

use App\Support\SkillCatalog;
use Tests\TestCase;

class SkillCatalogTest extends TestCase
{
    public function test_there_are_14_skill_level_states(): void
    {
        // Table 3.7 ranges, D-003.
        $this->assertSame([
            'phonological_awareness:1', 'phonological_awareness:2',
            'phonics:1', 'phonics:2', 'phonics:3',
            'vocabulary:2', 'vocabulary:3', 'vocabulary:4',
            'fluency:3', 'fluency:4', 'fluency:5',
            'literal_comprehension:3', 'literal_comprehension:4', 'literal_comprehension:5',
        ], array_map(fn (array $s) => "{$s['skill']}:{$s['level']}", SkillCatalog::states()));
    }

    public function test_parameters_keep_one_minus_slip_above_guess(): void
    {
        // A learner who knows the skill must beat a guesser (docs/knowledge/05-bkt-engine.md).
        foreach (SkillCatalog::skills() as $skill) {
            $p = SkillCatalog::params($skill);
            $this->assertGreaterThan($p['g'], 1 - $p['s'], $skill);
            foreach (['l0', 't', 'g', 's'] as $key) {
                $this->assertGreaterThan(0, $p[$key], "$skill.$key");
                $this->assertLessThan(1, $p[$key], "$skill.$key");
            }
        }
    }
}
