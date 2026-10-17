# 01 — Project Overview

## One-line summary
A Godot 4 mobile game (the thesis says Unity; switched 2026-10-17, see open issue 19) for **Grade 1 learners** that assesses reading comprehension through gameplay ("stealth assessment"), adapts difficulty in real time with **Bayesian Knowledge Tracing (BKT)**, uses an LLM to write **teacher diagnostic reports** and **raccoon-companion dialogue**, and gives teachers a dashboard and admins an oversight portal.

## Setting and people
- **School:** Ampayon Elementary School, Butuan City, Agusan del Norte, Philippines.
- **Teachers / content reviewers:** Teacher Irish Delgado (Advanced section, 36 students, all functional readers) and Teacher Estremos (Regular section, 26 students, ~16 functional readers, 3 ARAL Basic).
- **Participants:** 62 Grade 1 learners (~52 functional readers). Written parental consent required; data anonymized with student ID codes.
- **Evaluators (TAM survey):** 2 Grade 1 teachers + 3 IT professionals (N = 5).

## Problem
- PH reading crisis: 48.76% of Grade 3 learners not reading at grade level (CRLA SY 2024–25); proficiency collapse 30.5% (G3) → 0.47% (G12) (EDCOM II, 2026); PISA 2022: 76% below minimum reading proficiency.
- Teachers rely on manual Phil-IRI / EGRA: heavy admin burden, non-adaptive, cause test anxiety in young learners.
- Regular-section learners face poverty, unstable families, absenteeism, no home support → tool must work **without home reinforcement**.
- School internet is unstable → **offline gameplay** is required.

## Research questions (Statement of the Problem)
1. Baseline reading comprehension of Grade 1 learners (pre-test, with parental consent, RA 10173 compliant)?
2. What game mechanics, UI elements, and adaptive algorithms are needed for an AI-driven assessment that adjusts difficulty?
3. How do IT experts and Grade 1 teachers rate acceptability (functionality, usability, reliability, curriculum alignment)?
4. Post-test scores after using the system?
5. Is there a significant pre/post difference?

## Objectives
1. Design and develop a game-based system that adaptively assesses Grade 1 reading comprehension.
2. Implement adaptive mechanisms that adjust difficulty based on performance to support cognitive development.
3. Evaluate effectiveness and usability through learner data and teacher feedback within **4 months**.

## Scope and limitations
- Grade 1 only, one school. Reading comprehension + cognitive support (attention, memory, basic reasoning).
- Effectiveness depends on device access, technology availability, teacher guidance.
- 4-month evaluation may not capture long-term cognitive outcomes.

## Theoretical framework
- **Vygotsky's ZPD**, operationalized by **BKT**: keep each learner at the right challenge level.
- **Csikszentmihalyi's Flow Theory**: matching challenge to skill keeps learners engaged and lowers anxiety.
- **TAM-C (Combined Technology Acceptance Model)**: Perceived Usefulness + Perceived Ease of Use, used to evaluate teacher/expert acceptance.

## Research and software methodology
- **Design-Based Research (DBR)**, the Generic Model for Design Research: preliminary analysis, agile prototyping, semi-summative reflection.
- **Agile**, run in six phases: Planning → Designing → Developing → Testing → Deploying → Reviewing.
- IPO conceptual framework. Input: problem context, participants, MATATAG, assessment limits. Process: BKT engine, game-based assessment, AI, data management. Output: better comprehension, less admin work, validated acceptability.

## Timeline (Gantt, 10 months, 2026)
| Phase | Dates |
|---|---|
| Planning | Feb 2026 (requirements, teacher interviews, feasibility) |
| Designing | Mar–Apr 2026 (Figma wireframes, game blueprints, UI/UX prototypes) |
| Developing | May–Aug 2026 (BKT, mechanics, GPT API, backend) |
| Testing | Jun–early Oct 2026 (4-month learner evaluation, pre/post, TAM) |
| Deploying | late Sep–Oct 2026 |
| Reviewing | Oct–Nov 2026 (analysis, final documentation) |

> As of 2026-10-17 this repo has no code yet, so the build is behind the Gantt schedule. See [10-open-issues.md](10-open-issues.md).

## Teacher interview insights that drive design
- Delgado: GBL works in her class; warns against total AI dependence reducing critical thinking. Suggests **"Spin the Words"** (word family like -OCK + picture → identify word); colorful visuals.
- Estremos: learners have low confidence and fear mistakes, some cry when struggling with phonics; tool must be standalone and visually rich.
- Both: no digital real-time tracking tool currently in use.
