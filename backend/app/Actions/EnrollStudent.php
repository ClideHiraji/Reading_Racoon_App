<?php

namespace App\Actions;

use App\Enums\UserRole;
use App\Models\Section;
use App\Models\Student;
use App\Models\User;
use App\Support\LoginCode;
use App\Support\SkillCatalog;
use App\Support\StudentCode;
use Illuminate\Support\Facades\DB;

/**
 * Adds a learner to a section (FR-16): a student user with a fresh login code,
 * a pseudonymous student code for exports (RA 10173), the 14 BKT states at each sub-skill's P(L0) (FR-03, D-003), an empty wallet,
 * the starter outfit and path progress at map level 1.
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

            $student = $user->student()->make(['section_id' => $section->id]);
            $student->forceFill(['code' => StudentCode::unique()])->save();

            $student->bktStates()->createMany(array_map(fn (array $state) => [
                'sub_skill' => $state['skill'],
                'level' => $state['level'],
                'p_mastery' => SkillCatalog::params($state['skill'])['l0'],
            ], SkillCatalog::states()));
            $student->wallet()->create();
            $student->pathProgress()->create();
            // Starter outfit, as Wardrobe in the client (FR-07).
            foreach (config('reading_racoon.shop.starter') as $item) {
                $student->items()->make(['item_id' => $item, 'slot' => config("reading_racoon.shop.items.$item.slot"),
                    'equipped' => true, 'cost' => 0])->save();
            }

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
