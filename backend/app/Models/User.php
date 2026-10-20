<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use App\Enums\RegistrationStatus;
use App\Enums\UserRole;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/**
 * Auth root for students, teachers and admins (FR-01). `role` and
 * `login_code_hash` are not mass assignable; set them with forceFill.
 */
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'login_code_hash',
        'remember_token',
        'two_factor_secret',
        'two_factor_last_step',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'role' => UserRole::class,
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            // Admin TOTP secret, encrypted at rest with APP_KEY (FR-08, NFR-04).
            'two_factor_secret' => 'encrypted',
            'two_factor_last_step' => 'integer',
            'last_login_at' => 'datetime',
        ];
    }

    /**
     * @return HasOne<Student, $this>
     */
    public function student(): HasOne
    {
        return $this->hasOne(Student::class);
    }

    /**
     * A teacher's self-registration (FR-08).
     *
     * @return HasOne<TeacherRegistration, $this>
     */
    public function registration(): HasOne
    {
        return $this->hasOne(TeacherRegistration::class);
    }

    /**
     * Sections this teacher owns (FR-06).
     *
     * @return HasMany<Section, $this>
     */
    public function sections(): HasMany
    {
        return $this->hasMany(Section::class, 'teacher_id');
    }

    public function hasRole(UserRole $role): bool
    {
        return $this->role === $role;
    }

    /** A teacher whose registration an admin approved; only they may sign in (FR-08). */
    public function isApprovedTeacher(): bool
    {
        // Asked fresh every time: an admin may have revoked the teacher since the model was loaded.
        return $this->role === UserRole::Teacher
            && $this->registration()->where('status', RegistrationStatus::Approved)->exists();
    }
}
