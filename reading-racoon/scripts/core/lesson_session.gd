class_name LessonSession
extends RefCounted
## One lesson (8 items) on map level `level`: picks items, scores answers, runs
## BKT, hearts and Racoon's Rescue, and reports outcomes for the UI to show.
## No UI code here, so the whole loop is unit-tested.
## FR-03, FR-04, FR-13, FR-14, FR-15; loop from docs/knowledge/06-game-design.md.

const LESSON_LENGTH := 8
const XP_PER_CORRECT := 10
const COINS_PER_STAR := 5
const LEVEL_UP_COINS := 20

enum Mode { NORMAL, RECOVERY }

var model: StudentModel
var bank: QuestionBank
var hearts := HeartSystem.new()
var rng := RandomNumberGenerator.new()
var level := 1
var mode := Mode.NORMAL

var current: Dictionary = {}
var answered := 0
var lesson_length := LESSON_LENGTH
var results: Array = []          # normal items only: {id, skill, level, correct, ms}
var used_ids: Array = []
var last_id := ""
var sticky_skill := ""           # after a wrong answer, stay on the same skill
var level_up := false
var ended_early := false
var flags: Array = []            # intervention flags for the teacher (FR-17)
var events: Array = []           # drained by GameState into the sync queue (FR-11)

var rescue := {}                 # {skill, level, from_level, has_lower, answered, correct}


func _init(p_model: StudentModel, p_bank: QuestionBank, p_level: int,
		rng_seed: int = -1) -> void:
	model = p_model
	bank = p_bank
	level = p_level
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()


func in_rescue() -> bool:
	return mode == Mode.RECOVERY


## 0..1 for the top progress bar.
func progress() -> float:
	return float(answered) / lesson_length


func next_item() -> Dictionary:
	var target: Dictionary
	var recovery_items := false
	if mode == Mode.RECOVERY:
		target = {"skill": rescue.skill, "level": rescue.level}
		recovery_items = not rescue.has_lower
	elif sticky_skill != "":
		target = model.target_for(sticky_skill, level)
	else:
		target = model.pick_target(level, rng)
	current = bank.pick(target.skill, target.level, recovery_items, used_ids, last_id, rng)
	if current.is_empty():
		# No content for that skill-level: fall back to any skill with items here.
		for skill in SkillCatalog.active_skills(level):
			current = bank.pick(skill, level, false, used_ids, last_id, rng)
			if not current.is_empty():
				break
	if not current.is_empty():
		used_ids.append(current.id)
		last_id = current.id
	return current


## Scores the current item. Returns what the UI needs:
## correct, answer, hint, hearts, mood, level_up, mastered_now, and `next`:
## "continue" | "rescue_start" | "rescue_end" | "done" | "end_session".
func submit(answer, ms: int = 0) -> Dictionary:
	var item := current
	var correct := str(answer) == str(item.answer)
	var skill: String = item.sub_skill
	var item_level: int = item.level
	var rec := model.record(skill, item_level, correct, QuestionBank.num_choices(item))
	_event("response", {"item_id": item.id, "skill": skill, "level": item_level,
			"answer": str(answer), "correct": correct, "response_ms": ms, "rescue": in_rescue()})
	_event("bkt_state", {"skill": skill, "level": item_level, "p": rec.p_next,
			"posterior": rec.posterior, "attempts": rec.attempts,
			"mastered": model.state(skill, item_level).mastered})
	var out := {
		"correct": correct,
		"answer": item.answer,
		"hint": rec.hint,
		"mastered_now": rec.mastered_now,
		"level_up": false,
		"mood": "happy" if correct else ("thinking" if rec.hint else "encourage"),
		"skill": skill,
		"next": "continue",
	}
	if mode == Mode.RECOVERY:
		_submit_rescue(correct, out)
	else:
		_submit_normal(item, correct, ms, rec, out)
	out.hearts = rescue.correct if mode == Mode.RECOVERY else hearts.hearts
	return out


func _submit_normal(item: Dictionary, correct: bool, ms: int, rec: Dictionary,
		out: Dictionary) -> void:
	answered += 1
	results.append({"id": item.id, "skill": item.sub_skill, "level": item.level,
			"correct": correct, "ms": ms})
	sticky_skill = "" if correct else item.sub_skill
	if rec.level_up:
		level_up = true
		out.level_up = true
		out.mood = "celebrate"
		_event("level_up", {"to_level": model.highest_unlocked})
	match hearts.on_answer(item.sub_skill, correct):
		HeartSystem.Result.RECOVERY:
			_start_rescue(item.sub_skill, item.level)
			out.next = "rescue_start"
			return
		HeartSystem.Result.END_SESSION:
			ended_early = true
			_flag("rescue_limit", item.sub_skill, item.level, {})
			out.next = "end_session"
			return
	_event("hearts", {"hearts": hearts.hearts})
	if level_up or answered >= lesson_length:
		out.next = "done"


func _start_rescue(skill: String, from_level: int) -> void:
	var lower := from_level - 1
	var has_lower := lower >= SkillCatalog.min_level(skill)
	rescue = {"skill": skill, "level": lower if has_lower else from_level,
			"from_level": from_level, "has_lower": has_lower, "answered": 0, "correct": 0}
	mode = Mode.RECOVERY
	sticky_skill = ""
	_event("rescue_start", {"skill": skill, "level": from_level})


func _submit_rescue(correct: bool, out: Dictionary) -> void:
	rescue.answered += 1
	if correct:
		rescue.correct += 1
	if rescue.answered < HeartSystem.RECOVERY_ITEMS:
		return
	var full := hearts.finish_recovery(rescue.correct)
	out.rescue_full = full
	out.next = "rescue_end"
	mode = Mode.NORMAL
	if not full:
		# Partial recovery = "drop one tier" (D-004).
		var demoted := -1
		if rescue.has_lower and model.demote(rescue.skill, rescue.level):
			demoted = rescue.level
		_flag("rescue_partial", rescue.skill, rescue.from_level,
				{"correct": rescue.correct, "demoted_level": demoted})
	_event("rescue_end", {"skill": rescue.skill, "correct": rescue.correct, "full": full})
	if answered >= lesson_length:
		out.next = "done"


## Totals for the lesson-complete screen (FR-15).
func summary() -> Dictionary:
	var correct := 0
	for r in results:
		if r.correct:
			correct += 1
	var total := results.size()
	var accuracy := float(correct) / total if total > 0 else 0.0
	var stars := 1
	if accuracy >= 0.9:
		stars = 3
	elif accuracy >= 0.7:
		stars = 2
	return {
		"level": level,
		"correct": correct,
		"total": total,
		"accuracy": accuracy,
		"stars": stars,
		"xp": correct * XP_PER_CORRECT,
		"coins": stars * COINS_PER_STAR + (LEVEL_UP_COINS if level_up else 0),
		"level_up": level_up,
		"ended_early": ended_early,
		"results": results.duplicate(true),
	}


func drain_events() -> Array:
	var out := events
	events = []
	return out


func _flag(kind: String, skill: String, at_level: int, extra: Dictionary) -> void:
	var f := {"type": kind, "skill": skill, "level": at_level}
	f.merge(extra)
	flags.append(f)
	_event("flag", f)


func _event(kind: String, payload: Dictionary) -> void:
	events.append({"type": kind, "payload": payload})
