<?php

namespace Database\Factories;

use App\Enums\RegistrationStatus;
use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /**
     * A teacher by default.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'role' => UserRole::Teacher,
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => static::$password ??= Hash::make('password'),
            'remember_token' => Str::random(10),
        ];
    }

    /**
     * A student user: no email or password (they sign in with a login code).
     */
    public function student(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => UserRole::Student,
            'name' => fake()->firstName(),
            'email' => null,
            'email_verified_at' => null,
            'password' => null,
            'remember_token' => null,
        ]);
    }

    public function admin(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => UserRole::Admin,
        ]);
    }

    /**
     * A teacher with a registration in the given state (FR-08).
     */
    public function registered(RegistrationStatus $status = RegistrationStatus::Approved): static
    {
        return $this->afterCreating(function (User $user) use ($status) {
            $user->registration()->make(['school' => 'Butuan Central ES'])->forceFill([
                'status' => $status,
                'reviewed_at' => $status === RegistrationStatus::Pending ? null : now(),
            ])->save();
        });
    }

    /**
     * Indicate that the model's email address should be unverified.
     */
    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }
}
