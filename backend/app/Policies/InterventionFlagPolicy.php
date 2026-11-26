<?php

namespace App\Policies;

use App\Models\InterventionFlag;
use App\Models\User;
use Illuminate\Auth\Access\Response;

/**
 * Only the learner's own teacher can resolve their flag.
 */
class InterventionFlagPolicy
{
    public function update(User $user, InterventionFlag $flag): Response
    {
        return $user->isApprovedTeacher() && $flag->student?->section?->teacher_id === $user->id
            ? Response::allow()
            : Response::denyAsNotFound();
    }
}
