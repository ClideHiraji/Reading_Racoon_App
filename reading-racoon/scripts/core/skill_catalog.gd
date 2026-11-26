class_name SkillCatalog
extends RefCounted
## The five sub-skills, their level ranges and default BKT numbers (from the thesis).

const PA := "phonological_awareness"
const PHONICS := "phonics"
const VOCAB := "vocabulary"
const FLUENCY := "fluency"
const LIT_COMP := "literal_comprehension"

const SKILLS := [PA, PHONICS, VOCAB, FLUENCY, LIT_COMP]

## [lowest level, highest level] per sub-skill. 14 (skill, level) pairs in total.
const RANGES := {
	PA: [1, 2],
	PHONICS: [1, 3],
	VOCAB: [2, 4],
	FLUENCY: [3, 5],
	LIT_COMP: [3, 5],
}

## P(L0) start, P(T) learn, P(G) guess, P(S) slip.
const PARAMS := {
	PA: {"l0": 0.20, "t": 0.15, "g": 0.20, "s": 0.10},
	PHONICS: {"l0": 0.25, "t": 0.18, "g": 0.20, "s": 0.10},
	VOCAB: {"l0": 0.30, "t": 0.20, "g": 0.25, "s": 0.12},
	FLUENCY: {"l0": 0.15, "t": 0.12, "g": 0.15, "s": 0.08},
	LIT_COMP: {"l0": 0.20, "t": 0.15, "g": 0.20, "s": 0.10},
}

## Kid names and icons (res://assets/icons) for the skill bars on the path.
const NAMES := {PA: "Sounds", PHONICS: "Letters", VOCAB: "Words", FLUENCY: "Reading", LIT_COMP: "Stories"}
const ICONS := {PA: "ear", PHONICS: "pencil", VOCAB: "book", FLUENCY: "talk", LIT_COMP: "stories"}

const MAX_LEVEL := 5

## Map levels are worlds on the path, named after places in Butuan City.
## `scene` picks the PaperScenery landscape. `band` is the ARAL band teachers see.
const WORLDS := [
	{"name": "Agusan River", "icon": "waves", "scene": "river", "color": Color("2a9d8f"),
			"band": "ARAL Basic"},
	{"name": "Mango Grove", "icon": "tree", "scene": "grove", "color": Color("6aab4c"),
			"band": "ARAL Basic / Plus"},
	{"name": "Bahay Kubo Village", "icon": "hut", "scene": "village", "color": Color("b9875b"),
			"band": "ARAL Plus"},
	{"name": "Balangay Bay", "icon": "boat", "scene": "bay", "color": Color("3f80aa"),
			"band": "Approaching Proficient"},
	{"name": "Mount Mayapay", "icon": "mountain", "scene": "mountain", "color": Color("8e6aa0"),
			"band": "Grade-Level Proficient"},
]


static func min_level(skill: String) -> int:
	return RANGES[skill][0]


static func max_level(skill: String) -> int:
	return RANGES[skill][1]


static func is_active(skill: String, level: int) -> bool:
	return level >= min_level(skill) and level <= max_level(skill)


## Sub-skills that have tasks at this map level.
static func active_skills(level: int) -> Array[String]:
	var out: Array[String] = []
	for skill in SKILLS:
		if is_active(skill, level):
			out.append(skill)
	return out


static func world(level: int) -> Dictionary:
	return WORLDS[clampi(level, 1, MAX_LEVEL) - 1]
