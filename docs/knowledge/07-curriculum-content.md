# 07 — Curriculum and Content

## Framework
- **MATATAG Curriculum** (DepEd, SY 2024–25): Language and Reading & Literacy (LRL) domain, based on the **Science of Reading** (explicit, systematic instruction).
- **ARAL Program** (RA 12028, from SY 2025–26): tiers are **ARAL Basic** (non-readers) and **ARAL Plus** (emerging readers). The game's difficulty bands line up with these tiers (see [05-bkt-engine.md](05-bkt-engine.md)).
- The thesis positions the system as a localized implementation of DepEd **Project AGAP.AI** / **E-CAIR**.

## Five tracked sub-skills → MATATAG Grade 1 competencies → levels (thesis Table 3.7)

| Sub-skill | Competency codes | Levels |
|---|---|---|
| Phonological Awareness | RL1PA-I-1 chant rhymes/poems · I-2 segment 2–3 syllable words · I-3 identify rhyming words · I-4 say 2–3 rhyming words · I-5 identify initial sounds | 1–2 |
| Phonics and Word Study | RL1PWS-I-1 produce letter sounds (L1) · I-2 identify letters · I-3 isolate beginning/ending sounds · I-4 substitute sounds · I-5 sound out CVC, CVCC, CVVC | 1–3 |
| Vocabulary and Word Knowledge | RL1VWK-I-1 self/family/school/community words · I-2a/b naming and describing words · I-3 high-frequency words · I-4 content words (Math, SiKaP, GMRC) | 2–4 |
| Reading Fluency | RL1CAT-I-1 speed/accuracy/expression · RL1PWS-I-5 automaticity · RL1BPK-I-3a/b/c left-to-right, top-to-bottom, return sweep | 3–5 |
| Literal Comprehension | RL1CAT-I-2a details (character, setting, events) · 2b sequence · 2c infer feelings/traits · 2d predict ending · 2f cause–effect · 3a/b informational details, problem–solution | 3–5 |

Content follows the spiral progression RL1CAT-I-2a → 2g: literal questions come first, then inferential ones.

## Content rules
| Rule | Value |
|---|---|
| Language per level | **L1–2: Mother Tongue**, **L3–4: Filipino**, **L5: English** (MATATAG "bridge" strategy) |
| Passage length cap | **L3: 60 words**, **L4: 100 words**, **L5: 130 words** |
| Readability | Calibrated with the **Fry Readability Graph** |
| Cultural relevance | L3–5 use community-centric narratives familiar to Butuan City learners |
| Review | Teachers Delgado and Estremos check grade-appropriateness, vocabulary and cultural fit |
| Audio | Passages have narration support (TTS / recorded WAV) |

## Notes for content authoring
- Tag every question with sub-skill, level, competency code, language, task type, and correct answer + distractors.
- LLMs are weak at generating good distractors (Xiaochr et al., 2026), so humans should write or review all distractors.
- The fluency competency "read with speed and expression" needs speech input to assess properly. The game uses proxy tasks (word ordering, reading-order taps). State this limitation in the thesis.
- Advisor comment: the curriculum may have changed with the **three-term school year** next SY. Re-check with teachers. See open issues.
