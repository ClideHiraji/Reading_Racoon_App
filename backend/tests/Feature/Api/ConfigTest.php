<?php

namespace Tests\Feature\Api;

use Tests\TestCase;

/**
 * GET /api/config (FR-19). Needs no database.
 */
class ConfigTest extends TestCase
{
    public function test_config_is_public_and_serves_the_bkt_thresholds(): void
    {
        $this->getJson('/api/config')
            ->assertOk()
            ->assertJsonPath('content_version', 1)
            ->assertJsonPath('bkt.version', 1)
            ->assertJsonPath('bkt.mastery_p', 0.95)
            ->assertJsonPath('bkt.mastery_min_attempts', 5)
            ->assertJsonPath('bkt.hint_p', 0.3)
            ->assertJsonPath('bkt.demote_cap', 0.7)
            ->assertJsonPath('sync.max_batch', 500)
            ->assertJsonStructure(['server_time']);
    }

    public function test_config_serves_table_3_5_parameters_and_level_ranges(): void
    {
        $response = $this->getJson('/api/config')->assertOk();

        // [levels, P(L0), P(T), P(G), P(S)]: thesis Tables 3.5 and 3.7.
        $expected = [
            'phonological_awareness' => [[1, 2], 0.20, 0.15, 0.20, 0.10],
            'phonics' => [[1, 3], 0.25, 0.18, 0.20, 0.10],
            'vocabulary' => [[2, 4], 0.30, 0.20, 0.25, 0.12],
            'fluency' => [[3, 5], 0.15, 0.12, 0.15, 0.08],
            'literal_comprehension' => [[3, 5], 0.20, 0.15, 0.20, 0.10],
        ];

        $this->assertSame(array_keys($expected), array_keys($response->json('bkt.skills')));
        foreach ($expected as $skill => [$levels, $l0, $t, $g, $s]) {
            $response->assertJsonPath("bkt.skills.$skill", [
                'levels' => $levels, 'l0' => $l0, 't' => $t, 'g' => $g, 's' => $s,
            ]);
        }
    }

    public function test_server_time_is_utc_iso_8601(): void
    {
        $this->assertMatchesRegularExpression(
            '/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/',
            $this->getJson('/api/config')->json('server_time'),
        );
    }

    public function test_content_version_comes_from_the_environment(): void
    {
        config(['reading_racoon.content_version' => 7]);

        $this->getJson('/api/config')->assertJsonPath('content_version', 7);
    }
}
