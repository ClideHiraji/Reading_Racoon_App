<?php

namespace App\Http\Controllers\Teacher;

use App\Enums\RegistrationStatus;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Models\SystemLog;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rules\Password;
use Illuminate\View\View;

/**
 * Teacher self-registration (FR-01, FR-08). The account stays pending until an
 * admin approves it; the teacher can't sign in before that.
 */
class RegisterController extends Controller
{
    public function create(): View
    {
        return view('auth.register');
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::min(10)],
            'school' => ['nullable', 'string', 'max:150'],
            'section_name' => ['required', 'string', 'max:100'],
        ]);

        $user = DB::transaction(function () use ($data) {
            $user = new User(['name' => $data['name'], 'email' => strtolower($data['email']), 'password' => $data['password']]);
            $user->forceFill(['role' => UserRole::Teacher])->save();
            $user->registration()->make(['school' => $data['school'] ?? null])
                ->forceFill(['status' => RegistrationStatus::Pending])->save();
            $user->sections()->create(['name' => $data['section_name']]);

            return $user;
        });

        SystemLog::record('teacher.registered', 'info', ['email' => $user->email], userId: $user->id);

        return redirect()->route('register.pending');
    }

    public function pending(): View
    {
        return view('auth.pending');
    }
}
