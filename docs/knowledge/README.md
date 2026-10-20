# Reading Racoon — Project Knowledge Base

Source of truth for what the system must do, distilled from the capstone thesis manuscript:

> **Game-Based Adaptive Reading Comprehension Assessment and Cognitive Development Mobile Application**
> King Clide R. Jagape · Sophia Lhyn A. Guhiting — BSIT, CCIS, Caraga State University – Main Campus (target: November 2026)

Extracted 2026-10-17 from the Google Docs HTML export (Chapters 1–3 + references). When the manuscript changes, update these files and note the date.

Decisions, the progress log and lessons learned live in the Obsidian brain: [brain/Home.md](../../brain/Home.md).

## Files

| File | What it covers |
|---|---|
| [01-project-overview.md](01-project-overview.md) | Problem, research questions, objectives, scope, setting, participants, timeline |
| [02-requirements.md](02-requirements.md) | Functional / non-functional requirements, device requirements, implied requirements |
| [03-architecture.md](03-architecture.md) | Roles, system architecture, tech stack, API, offline sync |
| [04-data-model.md](04-data-model.md) | ERD entities and the gaps to fill before building |
| [05-bkt-engine.md](05-bkt-engine.md) | Bayesian Knowledge Tracing math, parameters, difficulty mapping, EM |
| [06-game-design.md](06-game-design.md) | Mechanics, heart recovery, rewards, raccoon companion, time-restricted access, UI rules, user flows |
| [07-curriculum-content.md](07-curriculum-content.md) | MATATAG competency mapping, levels, language policy, content rules |
| [08-ai-integration.md](08-ai-integration.md) | LLM report + companion dialogue, prompts, MLDLC, evaluation criterion |
| [09-evaluation-deployment.md](09-evaluation-deployment.md) | Pre/post-test, TAM survey, observation checklist, statistics, deployment checklist |
| [10-open-issues.md](10-open-issues.md) | **Contradictions and decisions that must be resolved before/while coding** |
| [glossary.md](glossary.md) | Terms and acronyms |

## How to use

- Before building a feature, read its file **and** [10-open-issues.md](10-open-issues.md); several thesis sections disagree with each other.
- IDs like `FR-04`, `NFR-02` match Table 3.1 of the thesis. Reference them in commits, issues, and code comments.
- Once this repo is indexed in Graphify, record resolved decisions with Graphify `remember` (one fact per note) and mark them resolved in `10-open-issues.md`.
