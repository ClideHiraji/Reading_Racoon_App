<?php

namespace Database\Seeders;

use App\Actions\EnrollStudent;
use App\Models\Section;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Local demo data: one section with two students. Their login codes are
     * printed once (only hashes are stored), so note them for the game client.
     */
    public function run(EnrollStudent $enroll): void
    {
        $section = Section::create(['name' => 'Grade 1 - Demo']);

        foreach (['Ana', 'Ben'] as $name) {
            $code = $enroll->handle($section, $name)['login_code'];
            $this->command?->info("Student {$name}: login code {$code}");
        }
    }
}
