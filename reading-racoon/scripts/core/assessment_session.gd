class_name AssessmentSession
extends RefCounted
## Pre-test (FR-02) and post-test (FR-10): the 20 blueprint items in a fixed order,
## played like a lesson (the "Reading Adventure") but with no hearts, no hints and
## neutral feedback, so the scores measure the child, not the help. Raw scores are
## kept per sub-skill for the study (RQ1, RQ4, RQ5). The pre-test also places the
## child on the path (StudentModel.place, 05-bkt-engine.md).
## Same interface as LessonSession so the lesson screen can run both.

const FILES := {"pre": "res://content/pretest.json", "post": "res://content/posttest.json"}
const COMPLETE_COINS := 30
const BLUEPRINT := {
	SkillCatalog.PA: 3, SkillCatalog.PHONICS: 3, SkillCatalog.VOCAB: 3,
	SkillCatalog.FLUENCY: 3, SkillCatalog.LIT_COMP: 8,
}

var kind := "pre"
var model: StudentModel
var bank: QuestionBank
var level := 1                    # only used for the lesson screen's scenery
var hearts := HeartSystem.new()   # unused; keeps the LessonSession interface
var rescue := {}
var flags: Array = []
var ended_early := false
var current: Dictionary = {}
var results: Array = []
var events: Array = []
var placed_level := 0

var _index := -1


func _init(p_model: StudentModel, p_kind: String, p_bank: QuestionBank = null) -> void:
	model = p_model
	kind = p_kind
	if p_bank:
		bank = p_bank
	else:
		bank = QuestionBank.new()
		bank.load_file(FILES[kind])


func in_rescue() -> bool:
	return false


func progress() -> float:
	return float(results.size()) / maxi(bank.items.size(), 1)


func next_item() -> Dictionary:
	_index += 1
	current = bank.items[_index] if _index < bank.items.size() else {}
	return current


## Scores without telling the child right or wrong (`neutral`), and without
## touching BKT: the pre-test feeds BKT once, through place(), at the end.
func submit(answer, ms: int = 0) -> Dictionary:
	var item := current
	var correct := str(answer) == str(item.answer)
	results.append({"id": item.id, "skill": item.sub_skill, "level": item.level,
			"correct": correct, "ms": ms})
	events.append({"type": "response", "payload": {"item_id": item.id, "skill": item.sub_skill,
			"level": item.level, "answer": str(answer), "correct": correct, "response_ms": ms,
			"assessment": kind}})
	var done := results.size() >= bank.items.size()
	if done:
		_finish()
	return {
		"correct": correct, "answer": item.answer, "neutral": true, "hint": false,
		"mastered_now": false, "level_up": false, "mood": "happy", "skill": item.sub_skill,
		"hearts": HeartSystem.MAX_HEARTS, "next": "done" if done else "continue",
	}


func _finish() -> void:
	if kind == "pre":
		placed_level = model.place(results)
		events.append({"type": "placement", "payload": {"start_level": placed_level}})
	events.append({"type": "assessment", "payload": {"kind": kind, "scores": scores(),
			"correct": _correct(), "total": results.size()}})


## Per sub-skill, for the results screen (D-021): passed when the BKT replay of
## its answers reaches mastery, the same rule the pre-test placement uses.
func passed() -> Dictionary:
	var out := {}
	var by_skill := StudentModel.answers_by_skill(results)
	for skill in by_skill:
		out[skill] = StudentModel.replay(model.params[skill], by_skill[skill]).mastered
	return out


## Raw scores per sub-skill: {skill: {"correct": n, "total": n}}.
func scores() -> Dictionary:
	var out := {}
	for r in results:
		if not out.has(r.skill):
			out[r.skill] = {"correct": 0, "total": 0}
		out[r.skill].total += 1
		if r.correct:
			out[r.skill].correct += 1
	return out


func _correct() -> int:
	return results.filter(func(r): return r.correct).size()


func summary() -> Dictionary:
	var total := results.size()
	return {
		"kind": kind, "level": level, "correct": _correct(), "total": total,
		"accuracy": float(_correct()) / total if total > 0 else 0.0,
		"scores": scores(), "passed": passed(), "placed_level": placed_level, "stars": 0,
		"xp": total * 5,
		"coins": COMPLETE_COINS, "level_up": false, "ended_early": false,
		"results": results.duplicate(true),
		"date": Time.get_date_string_from_system(),
	}


func drain_events() -> Array:
	var out := events
	events = []
	return out
