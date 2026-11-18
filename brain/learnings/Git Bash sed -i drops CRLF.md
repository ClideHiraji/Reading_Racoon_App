---
type: learning
date: 2026-11-17
status: active
tags: [learning, windows, tooling]
---

# Git Bash sed -i drops CRLF

On Windows, `sed -i` from Git Bash rewrote `scenes/shop/shop.gd` with LF line endings although the file had CRLF. A one-line edit would have shown up as the whole file changed.

**How to apply:**
- Before editing a project file from the shell, check its line endings (`file <path>`).
- Edit CRLF files with a script that keeps them: read with `newline=""`, replace with `\r\n`-aware strings, write with `newline=""`.
- Run `file` again afterwards; if the endings changed, convert back before copying the file anywhere.

Related: [[Python write_text makes CRLF on Windows]].
