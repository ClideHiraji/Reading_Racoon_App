---
type: decision
status: decided
date: 2026-10-20
issue: 7
graphify: submitted
tags: [decision, backend, admin, security, privacy]
---

# D-013 Hidden admin portal

**Decision:** the admin portal (FR-08, FR-22) is a Laravel web portal with **no public entrance**, as the user required.

| Layer | Rule |
|---|---|
| Secret path | Routes exist only under `ADMIN_PATH` from `.env` (≥ 32 random characters). Unset or short = the portal doesn't exist. The value is never in code, docs or git; `.env.example` has an empty placeholder. |
| Plain 404 | `ConcealAdminPortal` runs first. Every refusal (not signed in, no 2FA, wrong IP, expired, wrong method, throttled, CSRF) becomes the site's ordinary 404, rebuilt so **no session cookie** leaks. A catch-all route stops wrong HTTP methods from answering 405. Never 403, never a redirect to a sign-in page. |
| IP allowlist | Optional `ADMIN_ALLOWED_IPS` (IPs/CIDR), checked before the session starts. A blocked request is logged as a critical anomaly (someone outside knows the path). |
| Sign-in | Email + password + TOTP code (pragmarx/google2fa) in one form with one generic error; a code can't be replayed; 5 failures per IP or per email → 404 for 15 minutes; idle sessions end after 30 minutes; separate `admin` session guard. |
| Accounts | No admin registration. Only `php artisan admin:create` (and `admin:reset-2fa`), which print the TOTP setup key once in the terminal. The secret is stored encrypted with APP_KEY. |
| Headers | `X-Robots-Tag: noindex`, `Referrer-Policy: no-referrer` (the path must never travel in a Referer), `no-store`; no external assets; no links to it anywhere; not in robots.txt. |
| Audit | Every admin page view and action goes to `audit_logs`, which a PostgreSQL trigger makes append-only. |
| Features | Approve/deny/revoke teachers; system and audit logs with filters and anomaly highlighting; RA 10173 privacy audit; CSV research export of **consented learners only, by student code**. |

**Why**
- The user asked for an admin area that is not public and reachable only in a secret way. Each layer still holds if another fails: a leaked path still needs an allowed IP, the password and the phone.
- Identical 404s (body and cookies) mean scanning can't even tell the portal exists.
- RA 10173: learners are minors, so research data leaves the server only with consent and without names, and every access is traceable.

**Consequences**
- Setup steps (path, admin, 2FA enrolment) are in `backend/README.md`. Production must run with `APP_DEBUG=false` and HTTPS; behind a proxy, trusted proxies must be set for the IP allowlist.
- Losing the phone needs shell access (`admin:reset-2fa`), on purpose.
- Changing `ADMIN_PATH` needs `config:clear`/`route:clear`.

**Rejected:** a public `/admin` with a login page (reveals the target); 403 responses (confirm the path); admin screens in Godot; SMS or email codes (cost, and no mail server yet).

Details: `backend/README.md` ("Hidden admin portal: set up"), [[10-open-issues]] issue 7.
