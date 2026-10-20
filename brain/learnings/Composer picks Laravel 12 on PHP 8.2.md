---
type: learning
date: 2026-10-20
tags: [learning, laravel, php, tooling]
---

# Composer picks Laravel 12 on PHP 8.2

What happened: `composer create-project laravel/laravel` installed Laravel 12, not 13. Composer picks the newest version your PHP can run, and Laravel 13 needs PHP 8.3+. XAMPP's PHP is 8.2.12. Its `pdo_pgsql` extension ships with XAMPP but is commented out in `php.ini`.

**So:** Laravel 12 is fine for the thesis (security fixes until Feb 2027), but PHP 8.2 security support ends Dec 2026. Pick PHP 8.3+ on the server when hosting is decided, then move to Laravel 13. Use `--no-scripts` with `create-project`, or it creates and migrates a SQLite database.

Related: [[D-001 Backend Laravel + PostgreSQL]]
