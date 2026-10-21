---
type: learning
date: 2026-10-21
status: confirmed
tags: [learning, windows, tooling]
---

# Python write_text makes CRLF on Windows

`pathlib.Path.write_text()` (and `open(..., "w")`) turn every `\n` into `\r\n` on Windows, so a scripted edit silently converts a whole LF file (`.gd`, `.tres`) to CRLF and git shows every line changed.

**Fix:** edit files as bytes: `p.write_bytes(text.encode("utf-8"))` after `p.read_bytes().decode("utf-8")`, or pass `newline=""`. The CRLF docs (`docs/knowledge/*.md`) keep their CRLF the same way.

Related: [[Gitignore slash patterns are anchored]] (another Windows tooling trap).
