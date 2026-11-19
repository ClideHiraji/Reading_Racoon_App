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

        $user = LoginCode::isWellFormed($code) ? $this->findStudent($code) : null;

        if ($user?->student === null) {
            throw ValidationException::withMessages(['login_code' => __('auth.failed')]);
        }

        // Stored on the token, so the reply can say it and sanctum:prune-expired removes it (D-036).
        $minutes = (int) config('sanctum.expiration');
        $token = $user->createToken($request->input('device_name') ?? 'reading-racoon', ['*'],
            $minutes > 0 ? now()->addMinutes($minutes) : null);

        return response()->json([
            'token' => $token->plainTextToken,
            // Lets the game renew its sign-in before the token runs out.
            'expires_at' => $token->accessToken->expires_at?->utc()->toIso8601ZuluString(),
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

    /**
     * The student whose login code this is. Accounts made before D-036 still
     * hold the unkeyed hash: found that way once, they are upgraded to the
     * keyed hash on the spot, so after each child's next sign-in no
     * reversible hash of their code is left in the database.
     */
    private function findStudent(string $code): ?User
    {
        $students = fn () => User::query()->where('role', UserRole::Student)->with('student');

        $user = $students()->where('login_code_hash', LoginCode::hash($code))->first();
        if ($user !== null) {
            return $user;
        }

        $user = $students()->where('login_code_hash', LoginCode::legacyHash($code))->first();
        $user?->forceFill(['login_code_hash' => LoginCode::hash($code)])->save();

        return $user;
    }
}
