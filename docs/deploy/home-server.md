---
type: runbook
date: 2026-11-19
status: active
tags: [deploy, backend, security, reliability, hosting]
---

# Run the server from the home laptop, reachable from any school

Runbook for [[D-036 Internet hosting from the home laptop]]. The Laravel API, teacher dashboard and admin portal run on the developer's Windows laptop at home; tablets and teachers reach them over the internet at a fixed **https** address. Nothing here uses `localhost` from the outside, and no port is opened on the home router.

## How a request travels

```
Tablet (Godot) ─https─▶ Cloudflare edge ◀═ outbound tunnel ═ cloudflared (laptop)
                                                              │ http, loopback only
                                                              ▼
                                         Apache 127.0.0.1:8090 (mod_php, 80 threads)
                                                              │
                                                              ▼
                       Laravel ──▶ PostgreSQL 127.0.0.1:5432 ◀── queue worker (replay, reports)
                                                              ◀── scheduler (02:30 backup, pruning)
                                     nightly pg_dump ──▶ BACKUP_PATH ──▶ BACKUP_COPY_TO (off the laptop)
```

| Piece | Why |
|---|---|
| **Cloudflare Tunnel** (recommended) | Outbound only, so it works behind CGNAT (common on PH home internet) with no router changes; free; TLS certificates handled; hides the home IP; DDoS protection. Needs a domain on Cloudflare DNS: ours is `readingracoon.me`, free for the first year from the GitHub Student Developer Pack (Namecheap). **Renew it before it lapses**, or every tablet loses the server. Limits on the free plan: 100 MB per upload, 100 s per request, no published bandwidth cap. Cloudflare's terms ask non-Enterprise sites to serve video and large files through paid products (Stream, R2), so keep teacher videos few and short. |
| Port forwarding + dynamic DNS | Not used: often impossible behind CGNAT, exposes the home IP, and you'd run your own certificates. |
| **Apache** (XAMPP / Apache Lounge) | Serves many requests at once. `php artisan serve` handles one at a time on Windows (`PHP_CLI_SERVER_WORKERS` is not supported there) and dropped connections in our tests. |
| Queue worker + scheduler | The BKT replay and Gemini reports run in the background; backups and pruning run nightly. |

## One-time setup

### 1. PostgreSQL
- `postgresql.conf`: `listen_addresses = 'localhost'`, keep `synchronous_commit = on` and `fsync = on` (an acknowledged event must survive a power cut), `max_connections = 100` or more (Apache has 80 threads).
- `pg_hba.conf`: only `host all all 127.0.0.1/32 scram-sha-256` and `::1/128`. No `trust` lines.
- The app's role owns only its database: `CREATE ROLE reading_racoon LOGIN PASSWORD '…'; CREATE DATABASE reading_racoon OWNER reading_racoon;`. Not a superuser.

### 2. PHP (`C:\xampp\php\php.ini`)
- **Turn OPcache on.** Measured: `GET /api/config` 290 ms without, 75 ms with; a 100-event sync 510 ms without, 120 ms with.
  ```ini
  zend_extension=opcache
  [opcache]
  opcache.enable=1
  opcache.memory_consumption=192
  opcache.interned_strings_buffer=16
  opcache.max_accelerated_files=20000
  opcache.validate_timestamps=1
  opcache.revalidate_freq=60
  ```
- `expose_php = Off`, `display_errors = Off`, `log_errors = On`.
- `upload_max_filesize = 60M`, `post_max_size = 64M`, `memory_limit = 256M`.
- PHP 8.2 gets security fixes only until 31 Dec 2026: plan PHP 8.3+ (then Laravel 13).

### 3. Apache
- Update XAMPP's Apache (2.4.58 here, from 2023) to the current Apache Lounge 2.4 build.
- At the end of `C:\xampp\apache\conf\httpd.conf`:
  ```apache
  Define RR_BACKEND "C:/ReadingRacoon/backend"
  Include "C:/ReadingRacoon/backend/ops/windows/apache-reading-racoon.conf"
  ```
  It listens on `127.0.0.1:8090` only (not 8080, which the PostgreSQL installer's Enterprise Manager often holds; set `Define RR_PORT` before the `Include` to choose another), hides the version, drops slow clients, rotates its logs daily (7 kept) and serves only `backend/public`.
- Install it as a service (XAMPP Control Panel, "Svc" box, or `httpd.exe -k install`), startup type Automatic. In `services.msc` → Apache2.4 → Recovery, set all three failures to "Restart the Service". Do the same for the PostgreSQL service and, later, Cloudflared.

### 4. Laravel
```bat
copy backend\.env.production.example backend\.env
:: fill APP_URL, DB_PASSWORD, BACKUP_*, ADMIN_PATH, LLM_*
php artisan key:generate
php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan app:preflight
```
**`config:cache` is required, not an optimisation.** Apache runs PHP in threads on Windows, where reading `.env` on every request isn't thread-safe: under load, requests lost the database password (`fe_sendauth: no password supplied`, 4 of 300 requests in our load test). Cached config never reads `.env`. Run `php artisan config:cache` again after every `.env` change. `app:preflight` fails while it's missing.

Keep a copy of `APP_KEY` (and `LOGIN_CODE_KEY` if set) in a password manager: without it, teacher sessions, admin two-factor secrets and every child's login code stop working.

### 5. Background services
From an **administrator** PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File backend\ops\windows\install-tasks.ps1
```
It registers `ReadingRacoon-Queue` and `ReadingRacoon-Scheduler`: they start at boot as SYSTEM and restart after any crash (`run-forever.ps1`, logs in `storage/logs/queue-work-*.log`, `schedule-work-*.log`).

### 6. The tunnel (Cloudflare)
This is how `readingracoon.me` was set up (2026-11-26): a tunnel managed from the Cloudflare dashboard, so the laptop needs no config file.

1. **Domain:** add it to Cloudflare (free plan), then at the registrar (Namecheap → Domain List → Manage → Nameservers → Custom DNS) enter Cloudflare's two name servers. You can do the next steps while they take effect (minutes to 48 hours).
2. **Old DNS records:** in Cloudflare → DNS → Records, delete what you don't use. A Student Pack domain comes pointed at GitHub Pages (`A` records `185.199.108.153` to `185.199.111.153`). Cloudflare copies them in, and the site then shows GitHub's 404 page instead of the server.
3. **Install `cloudflared`:** the Windows `.msi` from Cloudflare's downloads, or `winget install Cloudflare.cloudflared`. The `.msi` installs quietly, with no window.
4. **Create the tunnel:** Zero Trust → Networks → Tunnels → Create a tunnel → Cloudflared, name `reading-racoon`. Copy its Windows install command (`cloudflared.exe service install <token>`) and run it in an **Administrator Command Prompt**. In PowerShell, a command that starts with a quoted path needs `& ` in front, or it fails with "Unexpected token 'service'". The token is the tunnel's password: never paste it into chats, notes or the repo. The tunnel shows **Healthy** once the service connects.
5. **Route the domain:** in the tunnel, Published application routes → Add: subdomain empty, domain `readingracoon.me`, path empty, service **HTTP**, URL `127.0.0.1:8090` (the Apache site from step 3). No HTTP Host header override: Laravel builds its links from `APP_URL`.
6. In `services.msc` → Cloudflared → Recovery, set all three failures to "Restart the Service".
7. **Dashboard security** (check each rule's expression preview before you deploy it):
   - SSL/TLS → Edge Certificates: **Always Use HTTPS** on, minimum TLS 1.2.
   - Security → Bots: **Bot Fight Mode off**.
   - Security → WAF → **Custom rules**: action *Skip* (Browser Integrity Check, Security Level, Bot Fight Mode) when URI Path **starts with** `/api/`. The preview must read `starts_with(http.request.uri.path, "/api/")`, not `eq`. The game is not a browser; without this Cloudflare may answer it with a challenge page instead of JSON.
   - Security → WAF → **Rate limiting rules** (one is free; not a custom rule): URI Path equals `/api/auth/login`, 100 requests per 10 s per IP, then Block for 10 s. The preview must show a rate limit. A *custom* rule with Block on that path refuses every sign-in. Laravel limits too; this stops floods before they reach the laptop.
   - Never turn on "Under Attack" mode for this hostname (it blocks the game).
8. Set `APP_URL=https://readingracoon.me` and `TRUSTED_PROXIES=127.0.0.1,::1`, then `php artisan config:cache`.
9. **Check from outside:** on a phone using mobile data, open `https://readingracoon.me/api/health`. It should show `"status":"ok"`.

### 7. The laptop itself
- Power (plugged in): never sleep, never hibernate, lid close does nothing: `powercfg /change standby-timeout-ac 0`, `powercfg /change hibernate-timeout-ac 0`, and Control Panel → Power Options → "Choose what closing the lid does" → Do nothing.
- Its battery is the UPS: a power cut doesn't stop it. Keep it plugged in and charged.
- Windows Update: set active hours to cover school hours (6 AM–9 PM) so restarts happen at night. All services start again by themselves.
- Use wired Ethernet to the router if you can.
- Disk encryption (BitLocker or Device Encryption) on: the laptop holds children's data (RA 10173).
- Exclude `backend\storage` and the PostgreSQL data folder from real-time antivirus scanning only if the antivirus slows writes noticeably.

### 8. Monitoring
Add a free uptime monitor (UptimeRobot or Healthchecks.io) on `https://readingracoon.me/api/health`, every 5 minutes, alerting your phone:
- **503 / no answer:** the database, Apache, the tunnel, the internet or the laptop is down.
- **200 with `"status":"degraded"`:** the API works, but the queue worker or scheduler stopped (the dashboard gets stale, backups stop). Set a keyword alert on `"status":"ok"`.

### 9. The game build
The server address is the project setting `reading_racoon/server_url`. `project.godot` has a release override, so exported release builds use the tunnel and debug runs (the editor, debug APKs) keep the local server:
```ini
[reading_racoon]
server_url="http://127.0.0.1:8000"
server_url.release="https://readingracoon.me"
```
The game reads it with `ProjectSettings.get_setting_with_override` (`sync.gd`): plain `get_setting` ignores `.release` overrides.

To point a built game at another server without rebuilding it, put an `override.cfg` next to the `.exe` with `server_url.release="https://…"` under `[reading_racoon]`. A plain `server_url` line there is ignored by builds that carry the release override. (The 2026-11-26 Windows beta was built before the override existed, so its plain `server_url` line works.) Android builds can't take an `override.cfg`; rebuild them instead.

Release builds refuse any `http://` address except `127.0.0.1`/`localhost` (`SyncProtocol.is_allowed_server`). Android needs the `INTERNET` and `ACCESS_NETWORK_STATE` permissions in the export preset.

## Every school day of the evaluation
`php artisan app:preflight` in `backend/`. Every line PASS, or a WARN you understand.

## What happens when something fails

The game never loses a recorded event: it keeps its queue on the device (written atomically, recovered after a crash), the server stores each event once by its UUID, and an event leaves the device only after the server has committed it.

| Failure | Tablets | Server | Recovery |
|---|---|---|---|
| Home internet or laptop off | Play offline; queue grows; retries 15 s → 10 min with jitter | — | Automatic when back; backlog uploads in batches of 100 |
| Tunnel/Cloudflare down | Same | Running | cloudflared reconnects by itself |
| Apache stopped | Same | — | The service's Recovery setting restarts it |
| PostgreSQL down | Same (503 → retry) | `/api/health` 503 | The service's Recovery setting restarts it; check disk space |
| Queue worker stopped | Unaffected (sync is acknowledged) | Dashboard stale; health `degraded` | Task restarts it; check `queue-work-*.log` |
| Scheduler stopped | Unaffected | No backups; health `degraded` | Task restarts it |
| Server busy (429/503) | Waits as long as `Retry-After` asks | — | — |
| Download cut off | Resumes from the last 4 MB chunk | — | Automatic |
| Power cut | — | Runs on battery | — |
| Laptop stolen or dead | Queue waits on devices | Gone | Restore the latest off-site backup on another PC, point the tunnel at it |

## Restore a backup
Always into an **empty** database (restoring over a live one with `--clean` fails on dependent tables):
```bat
set PGPASSWORD=...
"C:\Program Files\PostgreSQL\18\bin\createdb.exe" -h 127.0.0.1 -U postgres -O reading_racoon reading_racoon_restored
"C:\Program Files\PostgreSQL\18\bin\pg_restore.exe" --no-owner --no-privileges --exit-on-error -h 127.0.0.1 -U reading_racoon -d reading_racoon_restored backend\storage\app\backups\reading_racoon-YYYYMMDD-HHMMSS.dump
```
Then set `DB_DATABASE=reading_racoon_restored`, `php artisan config:cache`, and copy the `content` folder from the backup to `backend/storage/app/private/content`. Do a restore drill once before the evaluation starts and once in the middle; a backup that has never been restored isn't a backup.

## Updating the server
`C:\ReadingRacoon` holds only `backend` (since 2026-11-28: `git sparse-checkout set --cone backend`), so `git pull` skips the game and the notes. To get every folder back: `git sparse-checkout disable`.

```bat
php artisan down --retry=60
git pull
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan config:cache && php artisan route:cache && php artisan view:cache
php artisan queue:restart
php artisan up
php artisan app:preflight
```
While it's down, the API answers 503 with `Retry-After: 60`; tablets keep their queues and try again. Run `composer audit` before every update.

## Measured capacity (2026-11-19, this laptop: 8 cores, Apache 80 threads, OPcache, PostgreSQL 18)
- One sync of 100 events: about 120 ms. `GET /api/config`: about 75 ms. Each request opens a PostgreSQL connection (about 50 ms on Windows).
- Worst case: 30 tablets each uploading 5 backlogged batches at the same instant (150 requests, 15,000 events): all acknowledged, none lost or stored twice, no errors, finished in 10 s (median 2.3 s). The same 150 requests again (a retry storm): the same.
- A classroom of 40 tablets syncing every two minutes is about 0.3 requests per second, roughly 50 times below what the laptop sustained. If it is ever too slow, add PgBouncer (connection pooling) before anything else.
