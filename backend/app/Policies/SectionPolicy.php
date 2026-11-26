<?php

namespace App\Policies;

use App\Models\Section;
use App\Models\User;
use Illuminate\Auth\Access\Response;

/**
 * Teachers see and manage only their own sections.
 * Another teacher's section gets 404, so nobody learns it exists.
 */
class SectionPolicy
{
    public function view(User $user, Section $section): Response
    {
        return $user->isApprovedTeacher() && $section->teacher_id === $user->id
            ? Response::allow()
            : Response::denyAsNotFound();
    }

    public function update(User $user, Section $section): Response
    {
        return $this->view($user, $section);
    }
}
