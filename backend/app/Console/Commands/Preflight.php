<?php

namespace App\Console\Commands;

use App\Support\AdminPortal;
use App\Support\Ops;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Symfony\Component\Process\Process;
use Throwable;

/**
 * `php artisan app:preflight`: checks that this machine is safe to put on the
 * internet and is keeping itself healthy (NFR-02, NFR-04, D-036). Run it after
 * every change to .env and before every school day of the evaluation.
 * FAIL lines must be fixed; the exit code is 1 while any remain.
 */
class Preflight extends Command
{
    protected $signature = 'app:preflight';

    protected $description = 'Check the production settings, services, queue, scheduler and backups';

    /** @var array<string, int> */
    private array $counts = ['PASS' => 0, 'WARN' => 0, 'FAIL' => 0];

    public function handle(): int
    {
        $prod = $this->laravel->isProduction();
        $url = (string) config('app.url');

        $this->line('<options=bold>Settings</>');
        $this->check($prod, 'APP_ENV is production', 'APP_ENV is '.config('app.env').' (fine for development only)', fail: false);
        $this->check(! config('app.debug'), 'APP_DEBUG is off', 'APP_DEBUG is on: error pages show code and settings to anyone', fail: $prod);
        $this->check(filled(config('app.key')), 'APP_KEY is set', 'APP_KEY is empty: run php artisan key:generate');
        $this->check(str_starts_with($url, 'https://'), "APP_URL is https ({$url})", "APP_URL is not https ({$url})", fail: $prod);
        $this->check((bool) config('session.secure'), 'Session cookies are https-only', 'SESSION_SECURE_COOKIE is not true', fail: $prod);
        $this->check((bool) config('session.encrypt'), 'Sessions are encrypted at rest', 'SESSION_ENCRYPT is not true', fail: false);
        $this->check(! in_array('debug', $this->logLevels(), true) || ! $prod,
            'Log level is not debug', 'LOG_LEVEL is debug in production', fail: false);
        $proxies = (array) config('trustedproxy.proxies');
        $this->check(array_intersect($proxies, ['*', '**', '0.0.0.0/0', '::/0']) === [],
            'Trusted proxies: '.(implode(', ', $proxies) ?: 'none'), 'TRUSTED_PROXIES trusts everyone: client IPs can be forged');
        $this->check(config('queue.default') !== 'sync' || ! $prod,
            'Queue: '.config('queue.default'), 'QUEUE_CONNECTION is sync: replays and reports run inside requests', fail: false);
        $this->check(AdminPortal::path() !== null, 'Admin portal is on (secret path set)', 'Admin portal is off (ADMIN_PATH unset or shorter than '.config('admin.min_path_length').')', fail: false);
        // Apache runs PHP in threads on Windows; reading .env on every request
        // there lost the database password under load (load test 2026-11-19).
        $this->check($this->laravel->configurationIsCached() || ! $prod, 'Configuration is cached',
            'Configuration is not cached: run php artisan config:cache (and again after every .env change)');
        $this->check($this->laravel->routesAreCached() || ! $prod, 'Routes are cached', 'Routes are not cached: php artisan route:cache', fail: false);
        $this->check(extension_loaded('Zend OPcache') && (bool) ini_get('opcache.enable'), 'OPcache is on',
            'OPcache is off in php.ini: every request recompiles Laravel (290 ms instead of 75 ms)', fail: false);
        $this->check(PHP_VERSION_ID >= 80300, 'PHP '.PHP_VERSION, 'PHP '.PHP_VERSION.': security support for 8.2 ends 31 Dec 2026, plan PHP 8.3+', fail: false);
        $this->check(is_writable(storage_path('logs')) && is_writable(storage_path('app')), 'storage/ is writable', 'storage/ is not writable');

        $this->line('<options=bold>Database</>');
        $dbUp = Ops::databaseUp();
        $this->check($dbUp, 'PostgreSQL answers', 'PostgreSQL does not answer');
        if ($dbUp) {
            $this->check($this->migrationsCurrent(), 'Every migration has run', 'Migrations are pending: php artisan migrate --force');
            $timeout = (string) (DB::selectOne('show statement_timeout')->statement_timeout ?? '0');
            $this->check($timeout !== '0', "statement_timeout is {$timeout}", 'statement_timeout is off', fail: false);
            $sync = (string) (DB::selectOne('show synchronous_commit')->synchronous_commit ?? '');
            $this->check($sync === 'on', 'synchronous_commit is on (acknowledged events survive a crash)', "synchronous_commit is {$sync}");
        }

        $this->line('<options=bold>Services</>');
        $lag = $dbUp ? Ops::queueLag() : null;
        $this->check($lag === null || $lag <= Ops::QUEUE_LAG_LIMIT,
            'Queue worker keeps up'.($lag !== null ? " (oldest waiting job: {$lag} s)" : ''),
            "A job has waited {$lag} s: is the queue worker running?", fail: false);
        $beat = Ops::sinceBeat('scheduler');
        $this->check($beat !== null && $beat <= Ops::SCHEDULER_LIMIT,
            'Scheduler is running (last beat '.($beat ?? '?').' s ago)',
            $beat === null ? 'The scheduler has never run: start php artisan schedule:work' : "No scheduler beat for {$beat} s", fail: false);

        $this->line('<options=bold>Backups</>');
        $backup = Ops::latestBackup();
        $age = $backup ? (int) round((time() - $backup['at']) / 3600) : null;
        $this->check($backup !== null && $age <= 26,
            $backup ? "Latest backup {$age} h old (".number_format($backup['bytes'] / 1048576, 1).' MB)' : '',
            $backup ? "Latest backup is {$age} h old" : 'No backup yet: php artisan app:backup', fail: false);
        $this->check($this->runs((string) config('reading_racoon.backup.pg_dump')), 'pg_dump runs',
            'pg_dump not found: set BACKUP_PG_DUMP to its full path', fail: false);
        $this->check(filled(config('reading_racoon.backup.copy_to')), 'Backups are copied off the laptop (BACKUP_COPY_TO)',
            'BACKUP_COPY_TO is empty: a stolen or dead laptop takes every backup with it', fail: false);

        $this->newLine();
        $this->line(sprintf('%d passed, %d warnings, %d failed', $this->counts['PASS'], $this->counts['WARN'], $this->counts['FAIL']));

        return $this->counts['FAIL'] > 0 ? self::FAILURE : self::SUCCESS;
    }

    private function check(bool $ok, string $pass, string $problem, bool $fail = true): void
    {
        $status = $ok ? 'PASS' : ($fail ? 'FAIL' : 'WARN');
        $this->counts[$status]++;
        $color = ['PASS' => 'green', 'WARN' => 'yellow', 'FAIL' => 'red'][$status];
        $this->line("  <fg={$color}>{$status}</> ".($ok ? $pass : $problem));
    }

    /** @return list<string> the levels of the default log channel, or of each channel a stack writes to */
    private function logLevels(): array
    {
        $default = (string) config('logging.default');
        $channels = config("logging.channels.{$default}.driver") === 'stack'
            ? (array) config("logging.channels.{$default}.channels") : [$default];

        return array_map(fn ($c) => (string) config("logging.channels.{$c}.level", 'debug'), $channels);
    }

    private function migrationsCurrent(): bool
    {
        try {
            Artisan::call('migrate:status', ['--pending' => true]);

            return ! str_contains(Artisan::output(), 'Pending');
        } catch (Throwable) {
            return false;
        }
    }

    private function runs(string $binary): bool
    {
        try {
            $process = new Process([$binary, '--version'], null, null, null, 10.0);
            $process->run();

            return $process->isSuccessful();
        } catch (Throwable) {
            return false;
        }
    }
}
