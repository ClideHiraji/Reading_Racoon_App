---
type: decision
status: decided
date: 2026-10-20
issue: 7
graphify: submitted
tags: [decision, backend, teacher, web]
---

# D-012 Teacher web dashboard

**Decision:** the teacher dashboard is a set of **server-rendered Laravel Blade pages** inside `backend/`, not screens in the Godot app.

| Part | Choice |
|---|---|
| Sign-in | Email + password on the `web` session guard. Self-registration creates a **pending** account plus its first section; only teachers an admin approved can sign in, and a revoked teacher is signed out on the next click (FR-01, FR-08). |
| Access | Policies: a teacher sees only their own sections, learners and flags. Anything else answers **404**, so its existence isn't revealed. |
| Dashboard | Per section: mastery per sub-skill, ARAL band counts from the highest unlocked map level ([[D-003 BKT level progression]]), colour-coded open flags (red rescue limit, orange failed Heart Recovery, amber low P(L)), roster (FR-06, FR-17). |
| Roster | Add learners (first name or nickname only) with a one-time login code, new code, parental-consent record, remove = delete all their data (FR-16, RA 10173). |
| Profile | Chart.js 4.4.1 from jsDelivr: one P(L) line per (sub-skill, level), plus skill-levels, lessons, rescues, flags, play time. Tables repeat every number for offline use. |
| Schedule | Per section class window, after-school window, daily minutes, weekends ([[D-014 Time-restricted access rules]]). |
| Report | A diagnostic summary built **only from the numbers** (`TemplateReportWriter`), PDF via barryvdh/laravel-dompdf (FR-18). The Gemini report plugs in behind `App\Reports\DiagnosticReportWriter` later, with the template as its fallback ([[D-002 AI model Gemini]]). |
| Privacy | Learners get a pseudonymous `students.code` (`RR-XXXXXX`) used in reports, logs, exports and future AI prompts; the facts handed to a report writer never contain names. |

**Why**
- Teachers use laptops or school PCs; a web page needs no install, and server rendering keeps the UI simple and fast on school Wi-Fi.
- The thesis architecture note already allowed Blade for the portals, and it's far cheaper than teacher screens in Godot.
- 404 instead of 403 for other teachers' data follows the least-information rule used for the admin portal.

**Consequences**
- The Godot app is student-only. The teacher flow in the thesis (Figure "Teacher dashboard") maps onto these pages.
- The demo seeder creates an approved teacher with a random password printed once.
- Every teacher action (sign-in, views of learner data, roster changes, reports) is in the audit log, which the admin privacy audit reads.

**Rejected:** teacher screens in Godot (duplicate auth and charts, harder to print PDFs); a separate SPA (needs a build step and an API for every page).

Details: `backend/README.md` ("Teacher web pages"), [[10-open-issues]] issue 7.
