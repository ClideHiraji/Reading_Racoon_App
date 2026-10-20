<?php

namespace App\Actions;

use App\Enums\UserRole;
use App\Models\Section;
use App\Models\Student;
use App\Models\User;
use App\Support\LoginCode;
use App\Support\SkillCatalog;
use Illuminate\Support\Facades\DB;

/**
 * Adds a learner to a section (FR-16): a student user with a fresh login code,
 * the 14 BKT states at each sub-skill's P(L0) (FR-03, D-003), an empty wallet
 * and path progress at map level 1.
 */
final class EnrollStudent
{
    /**
     * The login code (formatted like "K7PM-3QXA") is only available here.
     *
     * @return array{student: Student, login_code: string}
     */
    public function handle(Section $section, string $name): array
    {
        return DB::transaction(function () use ($section, $name) {
            $code = $this->uniqueCode();

            $user = new User(['name' => $name]);
            $user->forceFill([
                'role' => UserRole::Student,
                'login_code_hash' => LoginCode::hash($code),
            ])->save();

            $student = $user->student()->create(['section_id' => $section->id]);

            $student->bktStates()->createMany(array_map(fn (array $state) => [
                'sub_skill' => $state['skill'],
                'level' => $state['level'],
                'p_mastery' => SkillCatalog::params($state['skill'])['l0'],
            ], SkillCatalog::states()));
            $student->wallet()->create();
            $student->pathProgress()->create();

            return ['student' => $student, 'login_code' => LoginCode::format($code)];
        });
    }

    private function uniqueCode(): string
    {
        do {
            $code = LoginCode::generate();
        } while (User::where('login_code_hash', LoginCode::hash($code))->exists());

        return $code;
    }
}
