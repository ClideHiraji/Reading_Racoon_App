---
type: decision
status: accepted
date: 2026-11-19
issue: 40
graphify: submitted
tags: [decision, backend, hosting, security, reliability, sync]
---

# D-036 Internet hosting from the home laptop

**Decision:** The Laravel server runs on the developer's Windows laptop at home and is reached from schools over the internet at one fixed https address: **Cloudflare Tunnel** (outbound only, own domain) → **Apache** on `127.0.0.1:8080` → Laravel → PostgreSQL on loopback, with a queue worker and scheduler kept alive as startup tasks. The domain is `readingracoon.me`; Tailscale Funnel, used before the domain, was removed on 2026-11-28 and is no longer a fallback. Never `php artisan serve`. Runbook: `docs/deploy/home-server.md`.

**What changed to make that safe and lossless**
- *Delivery:* an event leaves the device only after the server has committed it; the server stores each event once by UUID. The device queue is rewritten atomically (temp + rename, `.bak` recovery), a half-written line can't swallow the next event, and CR line ends are not damage.
- *Fault isolation:* the acknowledgement depends only on the insert. The BKT replay (43 µs per stored event) runs in a debounced `ReplayStudent` job (unique until processing), or inline when the worker is down.
- *Retries:* 15 s to 10 min exponential backoff with equal jitter, `Retry-After` honoured, interval jittered, one quick retry for reads; videos download in resumable 4 MB Range chunks.
- *Edge and identity:* only the local connector is a trusted proxy (`TRUSTED_PROXIES`), so rate limits and the admin allowlist see real client IPs; links come from the https `APP_URL`; release builds talk https only.
- *Browser and secrets:* nonce CSP, HSTS, nosniff, frame-ancestors none; Chart.js pinned by SRI; no CORS; login codes stored as HMAC-SHA256 with a server key (upgraded at next sign-in); device tokens expire after a school year (`rr_` prefix).
- *Limits:* PostgreSQL connect/statement/lock/idle-in-transaction timeouts; Apache drops slow clients.
- *Operations:* nightly verified `pg_dump` with an off-site copy and a restore drill, log retention, token pruning, `/api/health` for an uptime monitor, `php artisan app:preflight`.

**Why**
- Philippine home internet is often behind CGNAT: port forwarding may be impossible, and an outbound tunnel needs no router change and hides the home IP. Cloudflare's free plan also gives TLS and DDoS protection (limits: 100 MB uploads, 100 s requests).
- `php artisan serve` handles one request at a time on Windows (`PHP_CLI_SERVER_WORKERS` unsupported) and dropped connections in our tests (Godot `RESULT_CONNECTION_ERROR` on 4 of 8 runs; 0 of 9 on Apache).
- Under Apache's threaded PHP, reading `.env` per request lost the database password under load, so `config:cache` is required (preflight fails without it). OPcache was off in XAMPP: 290 → 75 ms per request.
- Measured on this laptop: 150 backlogged uploads at once (15,000 events), then again as a retry storm: 0 errors, every event stored exactly once, median 2.3 s. A class of 40 tablets is about 50× below that.

**Consequences**
- The user buys a domain (about US$10 a year) and sets up Cloudflare, Apache, OPcache and the startup tasks once, following the runbook.
- The laptop must stay on, plugged in and never sleep during the evaluation; it is a single point of failure, so backups go off the laptop.
- The teacher dashboard updates a few seconds after a sync (the replay job), not inside it.
- A login code depends on `APP_KEY` (or `LOGIN_CODE_KEY`): back it up.

**Rejected:** port forwarding with dynamic DNS (CGNAT, exposed home IP, own certificates); `php artisan serve` in production; a paid VPS (the thesis has no budget; still the cleanest upgrade if one appears); a `(student_id, id)` index on `sync_events` (EXPLAIN at 300,000 rows: PostgreSQL doesn't use it; pages take 1–7 ms already); persistent PDO connections (would save ~50 ms a request but risk leaking transaction state; PgBouncer first if ever needed).

Details: [[10-open-issues]] issue 40, `docs/deploy/home-server.md`, [[D-001 Backend Laravel + PostgreSQL]], [[D-008 Offline sync contract]], [[D-011 Server-side BKT replay]], [[D-020 Teacher content download in the game]].
