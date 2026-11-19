---
type: decision
status: decided
date: 2026-10-21
issue: 22
graphify: submitted
tags: [decision, backend, content, library, privacy]
---

# D-019 Teacher content manifest

**Decision:** teachers add Library books and Watch & Listen videos on a **Library & Videos** page in the Laravel dashboard; the game downloads them from `GET /api/content/manifest` and `GET /api/content/files/{id}` ([[D-017 Practice Library Watch and collections]]).

| Part | Choice |
|---|---|
| What | Books (title, language en/fil/bis, level, cover scene, key words, up to 12 pages of text + scene + pictures + optional page picture, two picture questions) and Ogg Theora videos (`.ogv`, checked by its `OggS` magic bytes, up to 50 MB) with an optional check question. |
| Openly licensed only | Licence (CC BY 4.0, CC BY-SA 4.0, CC BY-NC 4.0, CC BY-NC-SA 4.0, CC BY 3.0, CC0, public domain), source link and credit line are required. The admin's Content page lists everything and can unpublish. |
| Who sees it | A teacher manages only their own items and assigns them only to their own sections. A tablet gets only **published** items assigned to **its learner's section**. |
| Manifest | `{version, books, watch, server_time}` in the game's own JSON shapes, so it is saved as `user://content/library.json` and `watch.json`. `version` (also the ETag) changes with any change to the set; `If-None-Match` gives 304. Videos carry `file` (local path), `file_url`, `size_bytes`, `sha256`; page pictures `image_url`, `image`, `image_sha256`. |
| Files | Private disk, `content/<uuid>.<ext>`, served only through the API with `X-Content-SHA256` and range support. No public URL, no learner or teacher data in names (RA 10173). |
| Ids | `tb-xxxxxxxx` (book) and `tv-xxxxxxxx` (video), so they never clash with the bundled items. |

**Why**
- The game already reads teacher items from `user://content/` in the bundled shapes; sending exactly those shapes keeps the client simple.
- Children must never browse the open internet, and only openly licensed material may be redistributed to tablets.
- SHA-256 and range requests make downloads on unstable school Wi-Fi safe to retry.

**Consequences**
- Only `.ogv` for now: converting MP4 on the server with ffmpeg is a follow-up. XAMPP's 40 MB upload limit must be raised for 50 MB videos (README).
- Picture names must come from the game's icon list (mirrored in `config/reading_racoon.php`); add new icons in both places.
- The game must download files, check `sha256`, and drop items that leave the manifest.

**Rejected:** public file URLs or a CDN (anyone with the link could fetch them); YouTube or other streaming links (open internet, RA 10173); MP4 (Godot plays Ogg Theora).

Details: `backend/README.md` ("GET /api/content/manifest"), [[10-open-issues]] issue 22.
