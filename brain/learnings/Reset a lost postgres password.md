---
type: learning
date: 2026-10-20
tags: [learning, postgresql, windows, setup]
---

# Reset a lost postgres password

What happened: a PostgreSQL 18 reinstall on Windows reused the old data folder, so the `postgres` password typed in the new installer didn't apply, and nobody remembered the old one. Renaming the data folder while the installer runs doesn't help: the installer has already decided to reuse it, never creates a new one, and the service then fails with error 1067.

**So:**
1. Notepad as administrator → `C:\Program Files\PostgreSQL\18\data\pg_hba.conf`: change `scram-sha-256` to `trust` on the two `host all all 127.0.0.1/32` and `::1/128` lines, save, and **Restart** `postgresql-x64-18` in `services.msc`.
2. Set a new password without being asked for the old one: `psql.exe -h 127.0.0.1 -U postgres -c "\password postgres"`.
3. Put `scram-sha-256` back on both lines and restart again. While it says `trust`, any program on the PC can log in as the superuser.

Also: starting a Windows service needs admin rights, so Claude can't do it; and the reply buttons in the Claude app only send text, they don't perform the step.

Related: [[D-001 Backend Laravel + PostgreSQL]], [[Composer picks Laravel 12 on PHP 8.2]]
