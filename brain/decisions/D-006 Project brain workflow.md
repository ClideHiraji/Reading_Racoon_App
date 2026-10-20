---
type: decision
status: decided
date: 2026-10-20
issue: none
graphify: submitted
tags: [decision, workflow]
---

# D-006 Project brain: Obsidian + Graphify

**Decision:** the project folder is the Obsidian vault. Knowledge lives in two places, each with its own job:

| Where | Holds | Read by |
|---|---|---|
| `docs/knowledge/` | The spec: what the system must do | People + Claude (via CLAUDE.md) |
| `brain/` | Decisions, devlog, learnings | People in Obsidian + Claude |
| Graphify memory | One short note per decision and learning | Any agent through Graphify `recall` |

**Routine**
1. At session start: read [[Home]] and the latest devlog, and run Graphify `recall`.
2. When a decision is made: add a note in `brain/decisions/`, add a Graphify `remember`, and update [[10-open-issues]].
3. When a lesson is learned: add a note in `brain/learnings/` and a Graphify `remember`.
4. At session end: write today's note in `brain/devlog/`, then commit and push.

**Why:** Graphify doesn't index markdown ([[Graphify does not index markdown]]), and Obsidian can't be queried by agents. Using both covers people and agents.
