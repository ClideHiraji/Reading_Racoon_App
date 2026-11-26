---
type: learning
date: 2026-11-26
status: confirmed
graphify: submitted
tags: [learning, godot, export, sync]
---

# Godot get_setting ignores feature overrides

In Godot 4.7, a feature-tag override in `project.godot` (for example `reading_racoon/server_url.release`) is **not** applied by `ProjectSettings.get_setting()`. Only `ProjectSettings.get_setting_with_override()` returns it. A scratch project with `test/url="base"` and `test/url.windows="win"`, run on Windows with Godot 4.7.2, printed `get_setting=base` and `with_override=win`.

So the runbook's first plan (add `server_url.release`, keep `sync.gd` as it was) would have shipped release builds pointing at `127.0.0.1`. `Sync.server()` now reads the setting with `get_setting_with_override`, guarded by `has_setting`.

**Consequence:** an `override.cfg` next to an exported game must set the same overridden key (`server_url.release`). A plain `server_url` line there is shadowed in builds whose `project.godot` carries the override.

Related: [[Laravel needs config cache under threaded Apache]], `docs/deploy/home-server.md` § 9.
