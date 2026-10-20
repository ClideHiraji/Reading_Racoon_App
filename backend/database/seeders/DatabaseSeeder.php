<?php

namespace Database\Seeders;

use App\Actions\EnrollStudent;
use App\Enums\RegistrationStatus;
use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    /**
     * Local demo data: an approved teacher who owns one section with two
     * students. The teacher's random password and the students' login codes
     * are printed once (only hashes are stored), so note them now.
     * Admins are never seeded: use php artisan admin:create (D-012).
     */
    public function run(EnrollStudent $enroll): void
    {
        $password = Str::password(16, symbols: false);
        $teacher = new User(['name' => 'Demo Teacher', 'email' => 'teacher@demo.test', 'password' => $password]);
        $teacher->forceFill(['role' => UserRole::Teacher])->save();
        $teacher->registration()->make(['school' => 'Demo School'])
            ->forceFill(['status' => RegistrationStatus::Approved, 'reviewed_at' => now()])->save();
        $this->command?->info("Teacher teacher@demo.test: password {$password}");

        $section = $teacher->sections()->create(['name' => 'Grade 1 - Demo']);
        foreach (['Ana', 'Ben'] as $name) {
            $code = $enroll->handle($section, $name)['login_code'];
            $this->command?->info("Student {$name}: login code {$code}");
        }
    }
}
