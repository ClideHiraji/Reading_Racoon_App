<?php

namespace App\Policies;

use App\Models\ContentItem;
use App\Models\User;
use Illuminate\Auth\Access\Response;

/**
 * A teacher edits only the books and videos they added (D-019). Others answer 404.
 */
class ContentItemPolicy
{
    public function update(User $user, ContentItem $item): Response
    {
        return $user->isApprovedTeacher() && $item->owner_id === $user->id
            ? Response::allow()
            : Response::denyAsNotFound();
    }
}
