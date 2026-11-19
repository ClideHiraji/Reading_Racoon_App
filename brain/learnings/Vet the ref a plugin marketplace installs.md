---
type: learning
date: 2026-11-19
status: active
tags: [learning, tooling, security, claude-code]
---

# Vet the ref a plugin marketplace installs

A Claude Code marketplace can install a plugin from a different branch than the repo's front page. Read the marketplace's `.claude-plugin/marketplace.json` first, then review the exact `source` it names (`url` + `ref`, or `git-subdir` + `sha`), not the default branch.

**What happened:** GodotPrompter's README points at `jame581/skillsmith`. That marketplace installs `godot-prompter` from the `plugin-bundle` branch (commit `ca1e5a9`), not `master` (`426e8ab`), which is what a quick look at the repo shows. The review was redone on `plugin-bundle`.

**How to check after installing:** `~/.claude/plugins/installed_plugins.json` records each plugin's `gitCommitSha`. A `diff -rq` of the reviewed copy against the install folder under `~/.claude/plugins/cache/` should show only Claude Code's `.in_use` marker. For `npx skills add` installs, diff `~/.claude/skills/<name>` against the reviewed copy.

**Also seen:**
- In Git Bash, a path argument that starts with `/` (for example a `git sparse-checkout set --no-cone /plugins/x/` pattern) is rewritten to `C:/Program Files/Git/plugins/x/`, so the checkout comes out empty. Use cone mode with paths that don't start with `/`, or set `MSYS_NO_PATHCONV=1`.
- Laravel Boost only registers its commands when `APP_ENV=local` or `APP_DEBUG=true`, so a worktree with no `.env` says "no commands defined in the boost namespace".

Related: [[2026-11-19]].
