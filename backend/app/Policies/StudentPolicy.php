<?php

namespace App\Policies;

use App\Models\Student;
use App\Models\User;
use Illuminate\Auth\Access\Response;

/**
 * A teacher sees and manages only the learners in their own sections
 * (FR-06, FR-16, NFR-04). Others answer 404.
 */
class StudentPolicy
{
    public function view(User $user, Student $student): Response
    {
        return $user->isApprovedTeacher() && $student->section?->teacher_id === $user->id
            ? Response::allow()
            : Response::denyAsNotFound();
    }

    public function update(User $user, Student $student): Response
    {
        return $this->view($user, $student);
    }

    public function delete(User $user, Student $student): Response
    {
        return $this->view($user, $student);
    }
}
