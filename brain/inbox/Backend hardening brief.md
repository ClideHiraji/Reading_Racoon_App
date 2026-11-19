---
type: brief
date: 2026-11-19
status: done
tags: [brief, backend, security, reliability, sync, hosting]
---

# Brief: production-harden the backend for internet access from a home-hosted server

The user's request, rewritten as an engineering brief. Use it as the prompt for any later hardening pass.

## Context

- **System:** Reading Racoon, a Grade 1 reading game. A Godot 4.7 client (Android phones, Windows laptops) talks to a custom Laravel 12 API (PHP 8.2, Sanctum tokens) backed by PostgreSQL. The same Laravel app serves the teacher dashboard and a hidden admin portal, and calls Gemini from a queued job.
- **Deployment target:** the server runs on the developer's laptop at home (Windows 10, residential ISP, likely CGNAT, no static IP). Students and teachers reach it from school networks and mobile data, over the public internet, never `localhost`.
- **Constraints:** custom-coded backend (no BaaS, D-001); no budget beyond a domain; one maintainer; children's data (DPA 2012, privacy by design); thesis deadline November 2026.

## Objective

Make the client–server path **secure, fault-tolerant and lossless** across an unreliable WAN and an unreliable host:

1. **No data loss.** Every gameplay event the device records reaches PostgreSQL exactly once (at-least-once delivery + idempotent writes = effectively-once), survives app crashes, server restarts, power cuts and long offline periods, and is never acknowledged before it is durably committed.
2. **Graceful degradation.** When the server, tunnel, database or Gemini is down, the game keeps working offline, retries with capped exponential backoff and jitter, honours `Retry-After`, and resumes on its own. One failing dependency never takes down the others.
3. **Secure by default on the public internet.** TLS end to end at the edge, no inbound ports on the home router, least-privilege database access, short-lived and revocable tokens, rate limits keyed on the real client IP, hardened headers, no debug output, secrets out of the repo, and an audit trail.
4. **Operable by one person.** Services start on boot, health is observable from outside, backups run nightly and are restore-tested, and a runbook covers setup, failure modes and recovery.

## Scope of work

1. **Consolidate** the backend branches so the hardening applies to the server that will ship.
2. **Threat-model and audit** the API, dashboard, admin portal, schema and client against the OWASP API Security Top 10 and ASVS level 2: authN/authZ (IDOR/BOLA), input validation, mass assignment, injection, file uploads, rate limiting, secrets, headers, CORS, error leakage, dependency advisories.
3. **Reliability review** (SRE practice): timeouts and deadlines on every network call, retry budgets, idempotency keys, transactional boundaries, concurrency (races between overlapping syncs), N+1 and unbounded work per request, load shedding, health checks.
4. **Data layer review:** constraints and indexes, transaction isolation, connection handling, durability settings, backup/restore and retention.
5. **Client review:** atomic local writes (crash-safe queue), TLS verification, HTTPS-only server URL, retry policy, resumable downloads, behaviour on 401/403/413/422/429/5xx.
6. **Remote-hosting architecture:** an outbound-only tunnel (Cloudflare Tunnel with a domain; Tailscale Funnel as the no-domain fallback) in front of a real web server (not `php artisan serve`), trusted-proxy configuration, Windows services, power settings, monitoring.
7. **Fix** every confirmed defect with a regression test; **document** decisions (ADR in `brain/decisions/`), open issues and a runbook.
8. **Iterate:** after each round, re-audit the diff adversarially (fresh eyes) and repeat until no high or medium finding remains. Report what was verified and what wasn't.

## Definition of done

- All backend tests and game unit tests pass; new tests cover each fix.
- `composer audit` is clean; production `.env` template has secure defaults.
- The sync path is proven lossless under retries, duplicates, partial failures and concurrent requests.
- A runbook lets the user expose the laptop server at a stable HTTPS URL, keep it up, back it up and restore it.
- Every requirement ID touched (FR-xx, NFR-xx) is referenced in commits and code comments.
