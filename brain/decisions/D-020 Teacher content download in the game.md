---
type: decision
status: decided
date: 2026-10-21
issue: 22
graphify: submitted
tags: [decision, sync, content, offline, security]
---

# D-020 Teacher content download in the game

**Decision:** the game downloads the books and videos teachers pick on the dashboard (server side: D-019 on the dashboard branch, `GET /api/content/manifest` and `/api/content/files/{id}`) into `user://content/`, as the user asked: **Wi-Fi only, SHA-256 checked, never during a lesson**.

- **When:** `Sync` checks for changes every 15 minutes (first after 20 s) once the server answers, only when signed in, not in a lesson, and on Wi-Fi. The manifest is fetched with `If-None-Match` on its version, so an unchanged class costs one tiny `304`.
- **What it writes:** `library.json` and `watch.json` in the game's own shapes (they show as "From your teacher"), and `state.json` (manifest version, the student it belongs to, the verified files and their hashes).
- **Files:** one at a time, each to `<name>.part`; the SHA-256 is computed on a worker thread and only a matching file is moved into place, so the Library and Watch never see half a file. A wrong hash is deleted and tried again next time. A lesson starting cancels the download and deletes the part. Files of items that left the manifest are deleted.
- **Wi-Fi:** Godot has no network-type API, so on Android the game asks Android whether the network is metered (`ConnectivityManager.isActiveNetworkMetered()` through the AndroidRuntime singleton; the export needs `ACCESS_NETWORK_STATE`). If Android can't tell, it assumes mobile data and waits. Desktop counts as Wi-Fi; debug builds can pretend with `--metered`.
- **Trust:** the server decides what to show, never where to write: `ContentPlan` accepts only plain file names directly in `user://content/` with `.ogv/.png/.jpg/.jpeg`, file URLs only under `/api/content/files/`, and 64-hex hashes; anything else is dropped (a page keeps its text and paper scene).
- **Reader:** a teacher book's page picture replaces the drawn scene on that page, and its first picture is the book's cover.

**Why**
- The user asked for Wi-Fi-only downloads with a SHA-256 check that never run during a lesson (performance and data costs on school phones, NFR-01).
- Checking every path and hash keeps a broken or compromised server from overwriting the child's profile or showing a corrupted video.

**Consequences**
- Android export (to do) must enable `ACCESS_NETWORK_STATE` and `INTERNET`; if a phone's Android can't report metered networks, its videos never download (books still list and show their text).
- Interrupted downloads start over (no resume yet), even though the server supports Range requests.
- Checked end to end against the local server: on mobile data nothing downloads; on Wi-Fi a book picture and a video download and verify; an unchanged manifest is a 304; a tampered video is refused with no leftovers; a removed video is deleted from the tablet (`tests/content_e2e.gd`).

**Rejected:** downloading on any network; trusting the server's file paths; resuming partial files without a hash check.

Details: [[D-017 Practice Library Watch and collections]], [[10-open-issues]] issue 22.
