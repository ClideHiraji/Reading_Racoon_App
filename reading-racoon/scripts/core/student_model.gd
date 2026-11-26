class_name StudentModel
extends RefCounted
## One child's BKT state per (sub-skill, level), 14 in total, plus the highest
## unlocked map level. Rules in docs/knowledge/05-bkt-engine.md.

const MASTERY_P := 0.95
const MASTERY_MIN_ATTEMPTS := 5
const HINT_P := 0.30
## A partial rescue caps the lower skill level at this value.
const DEMOTE_CAP := 0.70

## "skill:level" -> {p, attempts, mastered, review}
## p = chance they know it next time. review = lost mastery in a failed rescue.
var states := {}
var highest_unlocked := 1
var params := SkillCatalog.PARAMS


func _init() -> void:
	reset()


func reset() -> void:
	states.clear()
	for skill in SkillCatalog.SKILLS:
		for level in range(SkillCatalog.min_level(skill), SkillCatalog.max_level(skill) + 1):
			states[key(skill, level)] = _fresh(skill)
	highest_unlocked = 1


static func key(skill: String, level: int) -> String:
	return "%s:%d" % [skill, level]


func has_state(skill: String, level: int) -> bool:
	return states.has(key(skill, level))


func state(skill: String, level: int) -> Dictionary:
	return states[key(skill, level)]


## Applies one answer: update, mastery check, then the learning step.
## `num_choices` > 1 marks a choice item (guess = 1 / choices).
func record(skill: String, level: int, correct: bool, num_choices: int = 0) -> Dictionary:
	var st := state(skill, level)
	var prm: Dictionary = params[skill]
	var g := BKT.guess_for(prm.g, prm.s, num_choices)
	var post := BKT.posterior(st.p, correct, g, prm.s)
	st.attempts += 1
	var mastered_now := false
	if not st.mastered and post >= MASTERY_P and st.attempts >= MASTERY_MIN_ATTEMPTS:
		st.mastered = true
		st.review = false
		mastered_now = true
	st.p = BKT.transition(post, prm.t)
	var level_up := false
	if mastered_now and level == highest_unlocked and is_level_complete(level) \
			and highest_unlocked < SkillCatalog.MAX_LEVEL:
		highest_unlocked += 1
		level_up = true
	return {
		"skill": skill,
		"level": level,
		"correct": correct,
		"posterior": post,
		"p_next": st.p,
		"attempts": st.attempts,
		"mastered_now": mastered_now,
		"level_up": level_up,
		# Hints only after a wrong answer.
		"hint": not correct and post < HINT_P,
	}


## True when every active sub-skill at `level` is mastered (the Level Up rule).
func is_level_complete(level: int) -> bool:
	for skill in SkillCatalog.active_skills(level):
		if not state(skill, level).mastered:
			return false
	return true


## Which (skill, level) the next question at map level `level` should practice.
## Skills under review come from the level below until mastered again;
## otherwise the unmastered skill with the lowest p.
func pick_target(level: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var best := {}
	var best_score := INF
	for skill in SkillCatalog.active_skills(level):
		var target := target_for(skill, level)
		var st := state(skill, target.level)
		if st.mastered:
			continue
		# Review items first, then the weakest skill.
		var score: float = st.p - (1.0 if st.review else 0.0)
		if score < best_score:
			best_score = score
			best = target
	if best.is_empty():
		# Everything mastered here: sometimes review any active skill.
		var skills := SkillCatalog.active_skills(level)
		var i := rng.randi_range(0, skills.size() - 1) if rng else 0
		best = {"skill": skills[i], "level": level}
	return best


## The level a skill is practiced at while playing map level `level`.
func target_for(skill: String, level: int) -> Dictionary:
	var lower := level - 1
	if has_state(skill, lower) and state(skill, lower).review:
		return {"skill": skill, "level": lower}
	return {"skill": skill, "level": level}


## Pre-test placement: replay each sub-skill's answers from P(L0) and mark it mastered
## when the final value reaches 0.95 (no minimum tries here). Start at the lowest
## map level that still has an unmastered skill. Returns that level.
## Uses the table guess rates, not 1/choices: with 3-choice guessing, 3 right
## answers only reach about 0.90 and nobody could ever be placed.
func place(results: Array) -> int:
	reset()
	var by_skill := answers_by_skill(results)
	for skill in by_skill:
		var st := state(skill, SkillCatalog.min_level(skill))
		var r := replay(params[skill], by_skill[skill])
		st.p = r.p
		st.attempts = by_skill[skill].size()
		st.mastered = r.mastered
	highest_unlocked = SkillCatalog.MAX_LEVEL
	for level in range(1, SkillCatalog.MAX_LEVEL + 1):
		if not is_level_complete(level):
			highest_unlocked = level
			break
	return highest_unlocked


## Test answers grouped by sub-skill: {skill: [true, false, ...]} in order.
static func answers_by_skill(results: Array) -> Dictionary:
	var by_skill := {}
	for r in results:
		if not by_skill.has(r.skill):
			by_skill[r.skill] = []
		by_skill[r.skill].append(bool(r.correct))
	return by_skill


## Replays one sub-skill's test answers from P(L0) with the table guess rate:
## {p, posterior, mastered}. Used by placement and by the test results screen ("passed").
static func replay(prm: Dictionary, answers: Array) -> Dictionary:
	var p: float = prm.l0
	var post := p
	for correct in answers:
		post = BKT.posterior(p, correct, prm.g, prm.s)
		p = BKT.transition(post, prm.t)
	return {"p": p, "posterior": post, "mastered": post >= MASTERY_P}


## A separate model with the same states and numbers. Lessons and tests work on a copy;
## only a finished one is copied back.
func copy() -> StudentModel:
	var m := StudentModel.new()
	m.params = params
	m.from_dict(to_dict())
	return m


## Failed rescue: the skill level loses mastery and must be practiced again.
func demote(skill: String, level: int) -> bool:
	if not has_state(skill, level):
		return false
	var st := state(skill, level)
	st.p = minf(st.p, DEMOTE_CAP)
	st.attempts = 0
	st.mastered = false
	st.review = true
	return true


## Progress 0..1 per active skill, only for the rings on the path banner.
func skill_progress(level: int) -> Array:
	var out := []
	for skill in SkillCatalog.active_skills(level):
		var st := state(skill, level)
		var l0: float = params[skill].l0
		var value := 1.0
		if not st.mastered:
			var by_p := clampf((st.p - l0) / (MASTERY_P - l0), 0.0, 1.0)
			var by_attempts := clampf(float(st.attempts) / MASTERY_MIN_ATTEMPTS, 0.0, 1.0)
			value = minf(0.95, 0.6 * by_p + 0.4 * by_attempts)
		out.append({"skill": skill, "progress": value, "mastered": st.mastered,
				"review": has_state(skill, level - 1) and state(skill, level - 1).review})
	return out


func to_dict() -> Dictionary:
	return {"states": states.duplicate(true), "highest_unlocked": highest_unlocked}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("states", {})
	for k in saved:
		if states.has(k):
			var s: Dictionary = saved[k]
			states[k] = {
				"p": float(s.get("p", states[k].p)),
				"attempts": int(s.get("attempts", 0)),
				"mastered": bool(s.get("mastered", false)),
				"review": bool(s.get("review", false)),
			}
	highest_unlocked = clampi(int(data.get("highest_unlocked", 1)), 1, SkillCatalog.MAX_LEVEL)


func _fresh(skill: String) -> Dictionary:
	return {"p": float(params[skill].l0), "attempts": 0, "mastered": false, "review": false}
