<?php

namespace App\Enums;

/**
 * A teacher's sign-up waits for an admin's decision.
 */
enum RegistrationStatus: string
{
    case Pending = 'pending';
    case Approved = 'approved';
    case Denied = 'denied';
}
