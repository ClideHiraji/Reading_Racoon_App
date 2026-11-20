---
type: decision
status: decided
date: 2026-11-20
issue: 41
graphify: submitted
tags: [decision, teacher, admin, web, ux, accessibility]
---

# D-037 Teacher dashboard: needs-help first, plain states

**Decision:** the teacher dashboard and admin portal were redesigned after an Impeccable critique (20/40) so a teacher can see at a glance who needs help, in plain words. The user chose all four recommended options.

| Part | Choice |
|---|---|
| Class page | Opens with a summary line (learners, how many need help, not played yet, consent forms), then **Needs your help**: one row per child with their open flags, most urgent first, then **Class progress**, then **Learners**. A sticky in-page nav links the three. |
| Mastery words | Teachers see **Got it / Practising / Needs help / Not started / Not reached yet** (Needs help = P(L) < 0.30 after 5+ answers, the low-mastery flag rule). P(L) numbers stay one click away ("Show the mastery numbers", "All 14 skill-levels") and in the exports. |
| Flags | Grouped by child and renamed by what happened: "Out of rescue tries" (rescue_limit), "Went back a level" (rescue_partial), "Keeps missing a skill" (low_mastery). A flag "Looks better now" once its skill-level was mastered again after the flag, or a low-mastery P(L) reaches 50%. **Flags never close by themselves**: the teacher marks them resolved, with Undo (`POST /teacher/flags/{flag}/reopen`, audited as `flag.reopen`). |
| Signature | "Where the class is on the reading map": learners per world (Agusan River → Mount Mayapay, each an ARAL band) drawn on the map route; clicking a world filters the learner list. |
| Learner list | One state pill per sub-skill, search, "Show" filters (need help, not played, consent missing, a map level, needs help in a skill) and sorting, all without a page load; the URL keeps the filter. On phones each learner is a card. |
| Risky actions | New login code, Remove and Clear consent moved from every roster row to a **Manage** section on the learner page, each with a confirmation that states the consequence. Recording consent stays on the list. Admin Deny/Revoke confirm and name the sections and learners affected. |
| Learner page | Breadcrumb, previous/next learner, facts row, open flags, one small chart per sub-skill (server-drawn SVG), recent lessons, play time. |
| Admin | Overview leads with **Needs your attention** (registrations waiting, failing privacy checks, anomalies, errors); nav shows counts; privacy checks sorted worst first (`App\Support\PrivacyChecks`); the audit feed hides page views. |
| Accessibility | Buttons on `#1f776c` (white 5.37:1), a solid 3px focus ring, skip link, `aria-current`, text on every status, learner names in button labels, labelled inputs, errors next to their field. |
| Speed | Chart.js (205 KB from jsDelivr) is gone: charts are HTML/SVG from the server, so they work offline and in print, and the CSP no longer allows jsDelivr. CSS and JS are static, cached files (`public/css/portal.css`, `public/js/portal.js`). The class page fell from 158 KB, 90 forms and 112 buttons to 121 KB, 34 forms and 69 buttons. |

**Why**
- The thesis evaluation asks whether the teacher dashboard is "easy to read at a glance" (TAM). The old class page opened with two charts and a red "28" flag count, and the children who needed help sat 924 px down in a flat, time-sorted list with duplicates.
- Teachers (ESL, between classes) can't act on "Avg P(L) now" or "Heart Recovery failed".
- Product principle 5: teachers stay in charge, so recovery is shown, never applied.

**Consequences**
- `SectionStats` gained `skillState()`, `looksBetter()`, `flagRow()`, `$states`, `$skillStates`, `$levels`, `$finished`, `$needsHelp`; `SkillHistory` draws the small charts.
- Tests: 179 → 184 (undo, looks-better, risky actions on the learner page, admin overview, revoke confirmation); the CSP test now checks that scripts come only from this site.
- The dev server (`php artisan serve`) caches compiled views for up to 60 s (OPcache `revalidate_freq`).

**Rejected:** auto-resolving recovered flags (takes the decision from the teacher); keeping Chart.js with a local copy (still a script and a canvas without a table twin); a separate page per tab (more requests, harder to scan on a phone).

Details: [[10-open-issues]] issue 41, [[D-012 Teacher web dashboard]], [[D-013 Hidden admin portal]].
