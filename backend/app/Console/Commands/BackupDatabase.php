<?php

namespace App\Console\Commands;

use App\Models\SystemLog;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use RuntimeException;
use Symfony\Component\Process\Process;
use Throwable;

/**
 * Nightly backup of the home server (see docs/deploy/home-server.md):
 *
 * 1. pg_dump in custom format to `<name>.dump.part`;
 * 2. pg_restore --list must read it back and find the sync_events data, and only then
 *    is it renamed to `.dump` (so a half-written dump never looks like a good one);
 * 3. copied to BACKUP_COPY_TO (another drive or a synced cloud folder) with the
 *    teachers' uploaded books and videos;
 * 4. only the newest BACKUP_KEEP dumps are kept in each folder.
 *
 * The password goes to pg_dump in its environment, never on the command line.
 * Restore: docs/deploy/home-server.md, "Restore a backup".
 */
class BackupDatabase extends Command
{
    protected $signature = 'app:backup';

    protected $description = 'Dump the database, verify the dump, copy it off-site and prune old dumps';

    public function handle(): int
    {
        $cfg = config('reading_racoon.backup');
        $dir = rtrim((string) $cfg['path'], '/\\');
        $name = 'reading_racoon-'.now()->utc()->format('Ymd-His').'.dump';
        $final = $dir.DIRECTORY_SEPARATOR.$name;
        $part = $final.'.part';

        try {
            File::ensureDirectoryExists($dir);
            $this->runTool([$cfg['pg_dump'], '--format=custom', '--compress=6', '--no-owner', '--no-privileges',
                '--file='.$part, ...$this->connectionArgs(), (string) DB::connection('pgsql')->getConfig('database')]);

            $list = $this->runTool([$cfg['pg_restore'], '--list', $part]);
            if (! str_contains($list, 'TABLE DATA public sync_events')) {
                throw new RuntimeException('pg_restore cannot find the sync_events data in the new dump');
            }
            if (! rename($part, $final)) {
                throw new RuntimeException("cannot rename {$part}");
            }
            $bytes = (int) filesize($final);

            $copied = false;
            if (filled($cfg['copy_to'])) {
                $copyDir = rtrim((string) $cfg['copy_to'], '/\\');
                File::ensureDirectoryExists($copyDir);
                File::copy($final, $copyDir.DIRECTORY_SEPARATOR.$name);
                $this->copyContent($copyDir.DIRECTORY_SEPARATOR.'content');
                $this->prune($copyDir, (int) $cfg['keep']);
                $copied = true;
            }
            $this->prune($dir, (int) $cfg['keep']);

            SystemLog::record('backup.done', 'info', ['file' => $name, 'bytes' => $bytes, 'copied' => $copied]);
            $this->info("Backup written: {$final} (".number_format($bytes / 1048576, 1).' MB)'.($copied ? ', copied off-site' : ''));

            return self::SUCCESS;
        } catch (Throwable $e) {
            if (is_file($part)) {
                @unlink($part);
            }
            report($e);
            try {
                SystemLog::record('backup.failed', 'error', ['message' => mb_substr($e->getMessage(), 0, 300)], anomaly: true);
            } catch (Throwable) {
                // The database may be down; the file log has the error.
            }
            $this->error('Backup failed: '.$e->getMessage());

            return self::FAILURE;
        }
    }

    /** @return list<string> */
    private function connectionArgs(): array
    {
        // The connection's resolved settings, so DB_URL is honoured too.
        $db = DB::connection('pgsql')->getConfig();

        return ['--host='.$db['host'], '--port='.$db['port'], '--username='.$db['username'], '--no-password'];
    }

    /** @param list<string> $command */
    private function runTool(array $command): string
    {
        $process = new Process($command, null, [
            'PGPASSWORD' => (string) DB::connection('pgsql')->getConfig('password'),
            'PGCONNECT_TIMEOUT' => '10',
        ], null, (float) config('reading_racoon.backup.timeout_seconds'));
        $process->run();
        if (! $process->isSuccessful()) {
            throw new RuntimeException(basename($command[0]).' failed: '.mb_substr(trim($process->getErrorOutput()), 0, 300));
        }

        return $process->getOutput();
    }

    /** Teachers' books and videos, copied once each (their names never change). */
    private function copyContent(string $target): void
    {
        $source = storage_path('app/private/content');
        if (! is_dir($source)) {
            return;
        }
        File::ensureDirectoryExists($target);
        foreach (File::files($source) as $file) {
            $to = $target.DIRECTORY_SEPARATOR.$file->getFilename();
            if (! is_file($to) || filesize($to) !== $file->getSize()) {
                File::copy($file->getPathname(), $to);
            }
        }
    }

    private function prune(string $dir, int $keep): void
    {
        $dumps = glob($dir.DIRECTORY_SEPARATOR.'reading_racoon-*.dump') ?: [];
        rsort($dumps);   // names sort by time
        foreach (array_slice($dumps, max(1, $keep)) as $old) {
            @unlink($old);
        }
    }
}
