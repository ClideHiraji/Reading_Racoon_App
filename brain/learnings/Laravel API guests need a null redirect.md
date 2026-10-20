---
type: learning
date: 2026-10-20
tags: [learning, laravel, api, auth]
---

# Laravel API guests need a null redirect

What happened: an unauthenticated `POST /api/sync` without an `Accept: application/json` header returned **500**, not 401. Laravel's auth middleware builds the guest redirect *before* the exception handler runs, and the default redirect calls `route('login')`, which doesn't exist in an API-only app. `shouldRenderJsonWhen()` alone doesn't fix it. The Godot client's `HTTPRequest` doesn't send that header unless told to.

**So:** in `bootstrap/app.php`, `$middleware->redirectGuestsTo(fn (Request $r) => $r->is('api/*') ? null : route('login'))`, plus `shouldRenderJsonWhen` for `api/*`. A feature test that posts without the header caught it; it only surfaced once PostgreSQL was installed and the DB tests could run.

Related: [[D-008 Offline sync contract]], [[Laravel rewrites JSON strings by default]]
