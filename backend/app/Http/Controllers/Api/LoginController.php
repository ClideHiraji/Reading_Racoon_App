<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Models\User;
use App\Support\LoginCode;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

/**
 * POST /api/auth/login: issues a Sanctum token (FR-01).
 *
 * Students sign in with their login code. This is TEMPORARY until open
 * issue 9 picks the real method for 6-year-olds (picture PIN, QR card or
 * tap-your-name). Teacher and admin email + password login comes with the
 * teacher dashboard slice.
 */
class LoginController extends Controller
{
    public function __invoke(LoginRequest $request): JsonResponse
    {
        $code = $request->string('login_code')->toString();

        $user = LoginCode::isWellFormed($code)
            ? User::query()
                ->where('role', UserRole::Student)
                ->where('login_code_hash', LoginCode::hash($code))
                ->with('student')
                ->first()
            : null;

        if ($user?->student === null) {
            throw ValidationException::withMessages(['login_code' => __('auth.failed')]);
        }

        $token = $user->createToken($request->input('device_name') ?? 'reading-racoon');

        return response()->json([
            'token' => $token->plainTextToken,
            'token_type' => 'Bearer',
            'user' => [
                'id' => $user->id,
                'role' => $user->role,
                'name' => $user->name,
            ],
            'student' => [
                'id' => $user->student->id,
                'section_id' => $user->student->section_id,
            ],
        ]);
    }
}
