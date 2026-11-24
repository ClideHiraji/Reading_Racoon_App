---
type: decision
status: decided
date: 2026-11-24
issue: 41
graphify: submitted
tags: [decision, teacher, admin, web, ux, accessibility]
---

# D-038 Dashboard trust fixes: Slipping, two help groups, freshness

**Decision:** a second Impeccable critique scored the redesign ([[D-037 Teacher dashboard needs-help first]]) 23/40, up from 20. It found that numbers and states contradicted each other, and that failure paths stranded people. The user chose all four recommendations: P1s plus every small fix, a "Slipping" state, two help groups with "Close all", and data freshness.

| Part | Choice |
|---|---|
| Slipping | A skill whose level was mastered, but whose P(L) has since fallen under 0.50, shows **Slipping** (orange, a downward triangle) instead of "Got it". Mastery still latches in BKT; only the label changes. |
| Help groups | "Needs your help (N)" lists children with at least one flag that doesn't look better. "Looks better: check and close (M)" collects the rest, with one **Close all** (`POST /teacher/flags/resolve`, ids checked against the policy) and Undo (`POST /teacher/flags/reopen`). My sections, the class page, the local nav and the roster badges all use this one definition. |
| Flags per skill | A child's flags on one skill-level are one row with every reason as a badge and one "Mark resolved". Resolving returns to where the teacher was (`#needs-help`, `#flags`) and the message names the child and skill. |
| Freshness | "Tablets last synced …" per class and "Last synced" per learner, from `sync_events.received_at` (the server's clock), next to "Last played" (the device's clock). Times older than a week show the date; the exact time is on hover. |
| Report | The report shows the child's name where the writer used the student code (the AI still sees only the code). A flag on a level the child has since mastered no longer puts the skill under "Needs support". |
| Failure paths | Branded 403/404/419/429/500/503 pages with a way back. They are static, so a refused admin request still looks exactly like any 404 (D-013). Every form is busy-locked after submit (no double posts). An idle warning comes 2 minutes before the session ends. Enter in a registration note no longer approves. Files lost after a validation error are explained. Publishing to no section is refused. |
| Admin | Alerts cover 7 days (a weekly visit). Failing security checks come first, worded as "not met". The audit log hides page views unless asked. Logs use 12-hour times. Export downloads confirm. |
| Accessibility | Map links work again (they were 0×0): every world filters the roster. No more clipped focus rings (navs wrap instead of scrolling). Menus close when focus leaves. No opacity-faded text. 44 px touch targets on touch screens. Forced-colour fixes. A print layout opens every disclosure and hides controls. A favicon. |

**Why**
- The class page said "6 need your help" over a list of 17. "Got it" sat next to an 18% estimate. A 99% skill was listed as needing support. These contradictions cost trust, which is exactly what the TAM "easy to read at a glance" item measures.
- On slow school Wi-Fi and shared laptops, double submits, silent expiry and Laravel's default error pages lose work.

**Consequences**
- `SectionStats`: `slip` state, `$lastSync`, `$flagCounts`, `activeRows()`, `betterRows()`, `betterFlagIds()`, `bySkill()`, `lastSectionSync()`. `PrivacyChecks` uses real plurals.
- Tests: 184 → 188 (bulk close and undo that ignores another teacher's flags; Slipping; consent undo and the 404 page; no publishing without a section). The 404 test now fails if raw Blade leaks.
- **Blade gotcha:** a directive glued to a word (`got it@if`, `page@endsection`) is not compiled. Use separate tags or double-quoted `@section` values.

**Rejected:** auto-closing recovered flags (the teacher decides, D-037); a client-side upload progress bar (an XHR upload would swallow the flash message); 24-hour admin windows.

Details: [[10-open-issues]] issue 41.
