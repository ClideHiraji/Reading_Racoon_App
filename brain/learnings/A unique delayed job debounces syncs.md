---
type: learning
date: 2026-10-21
tags: [learning, laravel, queue]
---

# A unique delayed job debounces syncs

What happened: the game syncs after every lesson and every 2 minutes, but the Gemini teacher report should be written once per play session. A Laravel job that implements `ShouldBeUnique` takes its lock **when it is dispatched** and keeps it until it has run. Dispatching it with `->delay(10 minutes)` therefore drops every later dispatch for the same `uniqueId()` during those 10 minutes, and the one job that runs reads the latest data.

**So:** for "do this once after a burst of events", dispatch a unique job with a delay and load the data inside `handle()`, not in the constructor. Set `$uniqueFor` (here 1 hour): without a running queue worker the lock would otherwise never be released. Under `Queue::fake()` the lock is still taken, so a test can assert one push for two syncs.

Related: [[D-015 Gemini teacher report]], [[D-008 Offline sync contract]]
