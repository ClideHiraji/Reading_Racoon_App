<?php

namespace App\Enums;

/**
 * A teacher's self-registration waits for an admin's decision (FR-08).
 */
enum RegistrationStatus: string
{
    case Pending = 'pending';
    case Approved = 'approved';
    case Denied = 'denied';
}
