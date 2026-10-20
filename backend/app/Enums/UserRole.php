<?php

namespace App\Enums;

/**
 * The three roles of FR-01. The role gates every API route.
 */
enum UserRole: string
{
    case Student = 'student';
    case Teacher = 'teacher';
    case Admin = 'admin';
}
