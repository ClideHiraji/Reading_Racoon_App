<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class LoginRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'login_code' => ['required', 'string', 'max:32'],
            // Names the Sanctum token, e.g. "Tablet 3", so a lost device can be signed out.
            'device_name' => ['nullable', 'string', 'max:100'],
        ];
    }
}
