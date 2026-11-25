---
type: decision
status: decided
date: 2026-11-25
issue: 41
graphify: submitted
tags: [decision, teacher, admin, web, ux, mobile, accessibility]
---

# D-039 Dashboard on a phone: compact cards, in-place actions, Menu

**Decision:** a phone-only Impeccable critique of the dashboard and admin portal scored 24/40. It found layouts that broke on real phones and actions that lost the teacher's place. The user chose all four recommendations: the P1s plus the small fixes, compact learner cards, in-place resolve with an inline Undo, and an admin Menu button.

| Part | Choice |
|---|---|
| Breakpoints | The phone layout covers portrait up to 760 px and landscape phones up to 960×520 (it was 760 px wide only, so landscape got the desktop grid). "Needs your help" rows stack below 1100 px, so a flag's Mark resolved never runs off a tablet. |
| Layout breaks | Section menus anchor to the left and never exceed the screen. Skill counts and badges wrap. Card labels take at most 40% of the card, and sit above their values below 26em (narrow phones, large text). `table.table-cards > tbody > tr > td` beats `table.compact td`, so "Recent lessons" no longer draws labels over values. |
| Compact learner cards | On screens only (print keeps every column), each learner is one card: name and activity, a summary line ("L2 Forest · 3 got it · 1 practising"), any "Needs help" or "Slipping" skills by name, Report, and Record consent when it's missing. The skill columns and the Student ID line are hidden on phones. On the demo class, cards went from 460–590 px to about 130 px and the page from 16.8 to 8.8 screens. |
| In place, with Undo | Mark resolved, Close all and Record consent post with `fetch`, follow the redirect, and read the confirmation and its Undo from the returned page (`main .alert-ok`). The row turns into "Resolved… · Undo" right where it was; Undo restores it. Counts (`[data-sync]`: summary, sticky nav, heading, roster row, filter options) are copied from that page, so the server stays the only source of numbers. If anything fails, the form posts the normal way (these actions are safe to repeat). |
| Close all | Closes only the flags of the children listed under "Looks better" (it also reached children still under "Needs your help"). The button names the flags ("Close all 19 flags"); the heading names the children. |
| Timed-out page | The page checks the elapsed time when the teacher returns to it and before any submit. When the server has already ended the session, the page says so and offers a reload instead of losing the tap to "Page expired". |
| Navigation | Admin links fold behind a Menu button on phones (the count of waiting items shows on it; Sign out comes last). Without JavaScript the links stay visible. The class page's sticky nav is opaque, one row of short labels, and shows "5/20" while the list is filtered. The teacher's Sign out sits apart from the links. |
| Touch and typing | 44 px buttons, nav links, Report and admin panel links on touch screens; small inline links get an invisible 44 px tap area. Fields use 16 px text on touch screens, so iPhones don't zoom in. Minute fields have a number keypad, the names box capitalises names, and the sign-in page focuses the email field only with a mouse. |
| Small fixes | "Choose a world", "on this device", a triangle on disclosures (the chevron read as a tick), "N need your help" on My sections is a link, the Activity sort puts playing-now first, Approve and Deny sit further apart, and the template report says "mastery estimate", "Racoon's Rescue" and "once/N times". |

**Why**
- The class page is a 5-minute check between classes on a phone. Each action reloaded the whole page on mobile data, hid its own confirmation above the screen and reset the teacher's place, so she could tap twice or lose track.
- 360 px Androids and landscape are what teachers use, and both broke.

**Consequences**
- `portal.js`: idle state moved first; `setBusy`/`clearBusy`; `submitInPlace`, `doneInPlace`, `undoInPlace`, `sync` (dispatches `portal:synced`, the roster re-reads its rows); delegated roster-filter links; the Menu toggle.
- Views: `data-inline` forms inside `data-inline-scope` elements; `data-sync` keys on the class page; the roster's last cell is the phone summary (hidden on wide screens, so no column moves).
- `SectionStats::betterFlagIds()` reads `betterRows()` only. The single-child resolve message is "Resolved for Jasmine: Phonics L1 (3 flags)."
- Tests: 189 → 190 (the markup the in-place script relies on, before and after the redirect).

**Rejected:** a JSON API for the actions (a second source of counts to keep in step); a phone "Today" view and dark mode (not chosen this round); a compact header with a "More" menu (the three header buttons wrap to two rows; acceptable for now).

Details: [[10-open-issues]] issue 41. Builds on [[D-038 Dashboard trust fixes]].
