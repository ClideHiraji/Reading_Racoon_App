---
type: learning
date: 2026-10-20
tags: [learning, laravel, postgresql, testing]
---

# migrate fresh keeps PostgreSQL functions

What happened: after adding a migration with a trigger function (`audit_logs_append_only()`, which makes the audit log append-only), the **second** test run failed everywhere with `function "audit_logs_append_only" already exists`. `RefreshDatabase` runs `migrate:fresh`, which drops all **tables** (and their triggers) but not standalone **functions**.

**So:** write trigger functions as `CREATE OR REPLACE FUNCTION`, and drop them in `down()`. Triggers can stay plain `CREATE TRIGGER`, since dropping the table drops them.

Related: [[D-012 Hidden admin portal]], [[Laravel timestamptz needs a UTC session]]
