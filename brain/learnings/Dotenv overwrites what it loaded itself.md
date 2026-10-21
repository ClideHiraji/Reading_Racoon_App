---
type: learning
date: 2026-10-21
tags: [learning, laravel, testing, env]
---

# Dotenv overwrites what it loaded itself

What happened: once `ADMIN_PATH` was set in the developer's `backend/.env`, the admin tests passed alone but failed in the full run. The first test to boot Laravel loaded `.env` through Dotenv, whose repository is static for the whole PHPUnit process. Laravel's env repository is "immutable" only for variables defined *outside* Dotenv; a variable Dotenv loaded itself counts as its own, so every later app boot rewrote `ADMIN_PATH` from `.env` over the random value the admin tests had put in `$_SERVER`/`$_ENV`.

**So:** pin such variables in `phpunit.xml` with `<env name="ADMIN_PATH" value="" force="true"/>` (then Dotenv never loads them), set the per-test value before `createApplication()`, and in `tearDown()` reset it to `""` instead of unsetting it. A side effect worth having: the real secret from `.env` can never reach a test.

Related: [[D-013 Hidden admin portal]]
