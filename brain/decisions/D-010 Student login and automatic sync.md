---
type: decision
status: decided
date: 2026-10-20
issue: 9
graphify: submitted
tags: [decision, login, sync, ux]
---

# D-010 Student login and automatic sync

**Decision:** students sign in **once per device** on a normal login screen with the **login code from their teacher** (the backend's 8-character codes, e.g. `K7PM-3QXA`). There is **no settings or "grown-ups" screen**: the server address is built into the app, and syncing is **fully automatic**.

- **Login screen:** the raccoon greets the child; 8 code boxes; a big on-screen keypad with only the 31 characters a code can contain (no 0/O/1/I/L), so no phone keyboard is needed. Short, kind messages read aloud: wrong code, no internet, too many tries. After signing in, the app opens straight to play every time, offline too.
- **Per-student data:** each student has their own profile and event queue on the device. "Not Ana? Switch student" on the start screen needs two taps and only works once everything is uploaded, so nothing is lost or mixed on a shared tablet. If the server ever rejects the token, the child types the code again and keeps all progress.
- **Server address:** project setting `reading_racoon/server_url` (`reading-racoon/project.godot`), set once before building the APK. Nobody at school types it.
- **Automatic sync:** a few seconds after start-up, after every lesson or test, when the app returns to the front, and every 2 minutes. With no internet it waits 30 s, 1, 2, 4… up to 10 minutes between tries, so it costs nothing offline. The post-test opens only when the teacher's server says so (`post_test_open` in `/api/config`).
- **No effect on play:** sync never runs while a lesson is on screen; reading the queue, building the JSON and trimming the queue run on a worker thread; HTTP runs on its own thread; uploads go in batches of 100. Measured on the dev laptop (headless, with the local server): 2,000 queued answers uploaded automatically in 17 s, with the worst frame at 11.6 ms and no frame over 33 ms. Reading 100 of 3,000 queued answers takes 3.6 ms and trimming takes 13 ms, both on the worker.

**Why**
- The user asked to remove the grown-ups section: a server address, manual sync and settings were above what teachers and parents with little tech experience can manage.
- The backend already issues login codes (interim answer to issue 9). A keypad of only valid characters makes typos impossible and works for a 6-year-old with help.
- Low-end phones (2 GB RAM) must stay smooth during play (NFR-01).

**Consequences**
- The build needs the right `server_url` (HTTPS for production; Android blocks plain HTTP by default).
- Picture passwords or QR cards (issue 9) can still come later; they would produce the same login code.
- The backend must accept the game's newer event types before release (D-008).

**Rejected:** a grown-ups settings screen with a typed server address and manual "sync now"; typing codes with the phone keyboard; syncing during lessons.

Details: [[10-open-issues]] issues 9-10, [[D-008 Offline sync contract]], [[03-architecture]].
