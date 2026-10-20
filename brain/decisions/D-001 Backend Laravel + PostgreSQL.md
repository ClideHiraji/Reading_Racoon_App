---
type: decision
status: decided
date: 2026-10-17
issue: 1
graphify: submitted
tags: [decision, backend]
---

# D-001 Backend: Laravel + PostgreSQL

**Decision:** custom-coded **Laravel (PHP 8.x) + PostgreSQL 16+ + Sanctum**. No Firebase or other backend-as-a-service.

**Why**
- The professor told us to "hard code" the backend (build it ourselves). That's required.
- We chose PostgreSQL over the thesis's MySQL.

**Consequences**
- We build offline sync, remote config (`GET /api/config`), auth and the AI proxy in Laravel.
- Hosting must support PostgreSQL. Many cheap PHP hosts are MySQL-only.
- The manuscript must replace every "Firebase" and "MySQL" mention.

**Rejected:** Firebase (my original timeline recommendation), MySQL (the thesis default).

Details: [[03-architecture]], [[04-data-model]], [[10-open-issues]] issue 1.
