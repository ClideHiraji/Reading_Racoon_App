---
type: learning
date: 2026-11-19
status: confirmed
tags: [learning, php, godot, testing, windows]
---

# PHP built-in server drops connections on Windows

`php -S` / `php artisan serve` on Windows serves one request at a time (`PHP_CLI_SERVER_WORKERS` isn't supported there) and, between back-to-back Godot clients, sometimes breaks the connection after answering: Godot's `HTTPRequest` reports `RESULT_CONNECTION_ERROR` (4) with code 0, here on the manifest's `304 Not Modified`. The content e2e failed on 4 of 8 runs; the same test through Apache failed 0 of 9.

**So:** never judge the game's networking against `artisan serve`. Run end-to-end tests through Apache (`backend/ops/windows/apache-reading-racoon.conf` with a throwaway config on another port), and never serve production with it.

**Two more e2e traps:**
- The game's `user://` folder is named after `config/name`, so a scratch copy called "Reading Racoon" shares the sign-in token and downloads with the developer's own game. Rename the copy ("Reading Racoon E2E").
- Laravel's test client builds the next URL from the previous request: after an https request through the tunnel headers, a plain `$this->get()` is https too.

Seen while testing [[D-036 Internet hosting from the home laptop]].
