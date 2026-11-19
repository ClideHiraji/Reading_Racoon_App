<?php

namespace Database\Factories;

use App\Models\Section;
use App\Models\Student;
use App\Models\User;
use App\Support\StudentCode;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * A bare student row for tests. Real students come from
 * App\Actions\EnrollStudent, which also creates their login code and game state.
 *
 * @extends Factory<Student>
 */
class StudentFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory()->student(),
            'section_id' => Section::factory(),
            'code' => StudentCode::generate(),
        ];
    }
}
