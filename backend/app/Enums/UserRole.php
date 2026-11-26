<?php

namespace App\Enums;

/**
 * The three user roles. The role guards every API route.
 */
enum UserRole: string
{
    case Student = 'student';
    case Teacher = 'teacher';
    case Admin = 'admin';
}
