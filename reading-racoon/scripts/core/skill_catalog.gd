class_name SkillCatalog
extends RefCounted
## The five tracked sub-skills, their level ranges and default BKT parameters.
## Ranges: thesis Table 3.7 (docs/knowledge/07-curriculum-content.md).
## Parameters: thesis Table 3.5 (docs/knowledge/05-bkt-engine.md). FR-03, FR-09.

const PA := "phonological_awareness"
const PHONICS := "phonics"
const VOCAB := "vocabulary"
const FLUENCY := "fluency"
const LIT_COMP := "literal_comprehension"

const SKILLS := [PA, PHONICS, VOCAB, FLUENCY, LIT_COMP]

## [lowest level, highest level] per sub-skill: 14 (sub-skill, level) states in total (D-003).
const RANGES := {
	PA: [1, 2],
	PHONICS: [1, 3],
	VOCAB: [2, 4],
	FLUENCY: [3, 5],
	LIT_COMP: [3, 5],
}

## P(L0) prior, P(T) learn, P(G) guess, P(S) slip.
const PARAMS := {
	PA: {"l0": 0.20, "t": 0.15, "g": 0.20, "s": 0.10},
	PHONICS: {"l0": 0.25, "t": 0.18, "g": 0.20, "s": 0.10},
	VOCAB: {"l0": 0.30, "t": 0.20, "g": 0.25, "s": 0.12},
	FLUENCY: {"l0": 0.15, "t": 0.12, "g": 0.15, "s": 0.08},
	LIT_COMP: {"l0": 0.20, "t": 0.15, "g": 0.20, "s": 0.10},
}

## Kid-facing names and icons for the skill rings on the path.
const NAMES := {PA: "Sounds", PHONICS: "Letters", VOCAB: "Words", FLUENCY: "Reading", LIT_COMP: "Stories"}
const ICONS := {PA: "👂", PHONICS: "🔤", VOCAB: "📖", FLUENCY: "🗣", LIT_COMP: "📚"}

const MAX_LEVEL := 5

## Map levels are themed worlds on the learning path (D-007).
## Band = ARAL band shown to teachers (docs/knowledge/05-bkt-engine.md).
const WORLDS := [
	{"name": "Sound Forest", "icon": "🌲", "color": Color("6bbf59"), "band": "ARAL Basic"},
	{"name": "Word River", "icon": "🌊", "color": Color("3fa7d6"), "band": "ARAL Basic / Plus"},
	{"name": "Sentence Hills", "icon": "⛰", "color": Color("f29e4c"), "band": "ARAL Plus"},
	{"name": "Story Village", "icon": "🏡", "color": Color("b07cc6"), "band": "Approaching Proficient"},
	{"name": "Reading Castle", "icon": "🏰", "color": Color("e5596b"), "band": "Grade-Level Proficient"},
]


static func min_level(skill: String) -> int:
	return RANGES[skill][0]


static func max_level(skill: String) -> int:
	return RANGES[skill][1]


static func is_active(skill: String, level: int) -> bool:
	return level >= min_level(skill) and level <= max_level(skill)


## Sub-skills that have tasks at map level `level`.
static func active_skills(level: int) -> Array[String]:
	var out: Array[String] = []
	for skill in SKILLS:
		if is_active(skill, level):
			out.append(skill)
	return out


static func world(level: int) -> Dictionary:
	return WORLDS[clampi(level, 1, MAX_LEVEL) - 1]
