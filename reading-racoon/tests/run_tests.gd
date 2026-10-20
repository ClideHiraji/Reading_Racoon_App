extends SceneTree
## Headless unit tests for the core game logic (no UI). Exit code = failures.
## Run from the repo root:
##   "C:\Program Files\Godot\Godot.exe" --headless --path reading-racoon -s res://tests/run_tests.gd

const PA := SkillCatalog.PA
const PHONICS := SkillCatalog.PHONICS
const VOCAB := SkillCatalog.VOCAB
const WRONG := "__wrong__"

var _failures := 0
var _checks := 0
var _current := ""


func _init() -> void:
	for m in get_method_list():
		if m.name.begins_with("test_"):
			_current = m.name
			call(m.name)
	print("\n%d checks, %d failed" % [_checks, _failures])
	quit(_failures)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL %s: %s" % [_current, msg])


func near(a: float, b: float, tol: float, msg: String) -> void:
	check(absf(a - b) <= tol, "%s (got %.4f, want %.4f)" % [msg, a, b])


## True if the text has emoji or pictographic symbols (U+2600-27BF, U+1F000+).
func _has_emoji(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		if (c >= 0x2600 and c <= 0x27BF) or c >= 0x1F000:
			return true
	return false


func test_companion_lines_have_no_emoji() -> void:
	var text := FileAccess.get_file_as_string("res://content/companion_lines.json")
	check(not text.is_empty(), "companion lines load")
	check(not _has_emoji(text), "companion lines have no emoji (D-009)")
	for world in SkillCatalog.WORLDS:
		check(Icons.exists(world.icon), "world icon '%s' exists" % world.icon)
	for skill in SkillCatalog.SKILLS:
		check(Icons.exists(SkillCatalog.ICONS[skill]), "skill icon for %s exists" % skill)


func bank() -> QuestionBank:
	var b := QuestionBank.new()
	b.load_file()
	return b


func master(m: StudentModel, skill: String, level: int) -> Dictionary:
	var last := {}
	for i in StudentModel.MASTERY_MIN_ATTEMPTS:
		last = m.record(skill, level, true)
	return last


# --- BKT -------------------------------------------------------------------------

## Same numbers as brain/learnings/"BKT passes 0.95 after 3 correct".
func test_bkt_matches_simulation() -> void:
	var prm: Dictionary = SkillCatalog.PARAMS[PA]
	var p: float = prm.l0
	var want := [0.53, 0.87, 0.97]
	for i in 3:
		var post := BKT.posterior(p, true, prm.g, prm.s)
		near(post, want[i], 0.006, "PA posterior after %d correct" % (i + 1))
		p = BKT.transition(post, prm.t)
	near(BKT.posterior(prm.l0, false, prm.g, prm.s), 0.03, 0.005, "PA after 1 wrong")


func test_guess_rate_per_choices() -> void:
	near(BKT.guess_for(0.2, 0.1, 3), 1.0 / 3.0, 0.0001, "3 choices")
	near(BKT.guess_for(0.2, 0.1, 0), 0.2, 0.0001, "non-choice item keeps table value")
	check(BKT.guess_for(0.2, 0.6, 2) < 1.0 - 0.6, "1 - S > G is kept")


# --- Progression (D-003) ------------------------------------------------------------

func test_mastery_needs_five_attempts() -> void:
	var m := StudentModel.new()
	for i in 3:
		m.record(PA, 1, true)
	check(m.state(PA, 1).p > 0.95, "P(L) passes 0.95 after 3 correct")
	check(not m.state(PA, 1).mastered, "not mastered before 5 attempts")
	m.record(PA, 1, true)
	var r := m.record(PA, 1, true)
	check(r.mastered_now and m.state(PA, 1).mastered, "mastered on the 5th attempt")


func test_level_up_needs_every_active_skill() -> void:
	var m := StudentModel.new()
	var r := master(m, PA, 1)
	check(r.mastered_now and not r.level_up, "one skill mastered is not a Level Up")
	check(m.highest_unlocked == 1, "still on level 1")
	r = master(m, PHONICS, 1)
	check(r.level_up, "Level Up when PA and Phonics L1 are mastered")
	check(m.highest_unlocked == 2, "level 2 unlocked")


func test_hint_only_after_wrong() -> void:
	var m := StudentModel.new()
	check(m.record(PA, 1, false).hint, "hint after a wrong answer at low P(L)")
	var any_hint := false
	var fresh := StudentModel.new()
	for i in 6:
		any_hint = any_hint or fresh.record(PHONICS, 1, true).hint
	check(not any_hint, "never a hint after a correct answer")


func test_pick_target_weakest_then_review() -> void:
	var m := StudentModel.new()
	check(m.pick_target(1).skill == PA, "lowest P(L) first (PA 0.20 < Phonics 0.25)")
	master(m, PA, 1)
	check(m.pick_target(1).skill == PHONICS, "mastered skills are skipped")
	m.demote(PA, 1)
	var t := m.pick_target(2)
	check(t.skill == PA and t.level == 1, "a demoted skill is served from the level below")


func test_demote_caps_and_resets() -> void:
	var m := StudentModel.new()
	master(m, PA, 1)
	m.demote(PA, 1)
	var st := m.state(PA, 1)
	check(st.p <= StudentModel.DEMOTE_CAP, "P(L) capped at 0.70")
	check(st.attempts == 0 and not st.mastered and st.review, "attempts reset, unmastered, review")


# --- Hearts (D-004) -------------------------------------------------------------------

func test_hearts_refill_and_recovery_limit() -> void:
	var h := HeartSystem.new()
	h.on_answer(PA, false)
	h.on_answer(PA, false)
	check(h.hearts == 1, "two wrong answers cost two hearts")
	h.on_answer(PA, true)
	check(h.hearts == 3, "a correct answer refills hearts")
	for attempt in 2:
		h.on_answer(PA, false)
		h.on_answer(PA, false)
		check(h.on_answer(PA, false) == HeartSystem.Result.RECOVERY, "3rd wrong starts recovery")
		check(h.finish_recovery(3), "3/3 is a full recovery")
		check(h.hearts == 3, "full hearts after recovery")
	h.on_answer(PA, false)
	h.on_answer(PA, false)
	check(h.on_answer(PA, false) == HeartSystem.Result.END_SESSION, "3rd trigger ends the session")


func test_hearts_streak_is_per_skill() -> void:
	var h := HeartSystem.new()
	h.on_answer(PA, false)
	h.on_answer(PHONICS, false)
	check(h.streak == 1 and h.hearts == 2, "a new sub-skill starts a new streak")


# --- Lesson session ---------------------------------------------------------------------

func test_partial_rescue_demotes_lower_level() -> void:
	var m := StudentModel.new()
	master(m, PA, 1)
	master(m, PHONICS, 1)
	var s := LessonSession.new(m, bank(), 2, 7)
	var out := {}
	for i in 3:
		var item := s.next_item()
		check(item.sub_skill == PA and item.level == 2, "stays on PA L2 after wrong answers")
		out = s.submit(WRONG)
	check(out.next == "rescue_start" and out.hearts == 0, "rescue after 3 wrong")
	for i in 3:
		var item := s.next_item()
		check(item.sub_skill == PA and item.level == 1, "rescue items come from PA L1")
		out = s.submit(WRONG)
	check(out.next == "rescue_end" and not out.rescue_full, "partial rescue")
	var st := m.state(PA, 1)
	check(not st.mastered and st.review and st.p <= 0.70, "PA L1 demoted")
	check(s.flags.size() == 1 and s.flags[0].type == "rescue_partial", "teacher flag raised")
	check(s.flags[0].demoted_level == 1, "flag records the demoted level")
	var nxt := s.next_item()
	check(nxt.level == 1 and nxt.sub_skill == PA, "review items from PA L1 afterwards")


func test_rescue_at_lowest_level_uses_easy_items() -> void:
	var s := LessonSession.new(StudentModel.new(), bank(), 1, 3)
	for i in 3:
		s.next_item()
		s.submit(WRONG)
	check(s.in_rescue() and not s.rescue.has_lower, "rescue with no lower level")
	var item := s.next_item()
	check(item.recovery and item.level == 1, "easier recovery-tagged items at the same level")
	var out := {}
	for i in 3:
		if i > 0:
			item = s.next_item()
		out = s.submit(item.answer)
		if i < 2:
			check(out.hearts == i + 1, "a heart comes back per correct rescue answer")
	check(out.next == "rescue_end" and out.rescue_full and out.hearts == 3, "full rescue")
	check(s.flags.is_empty(), "no flag after a full rescue")


func test_third_rescue_ends_session() -> void:
	var s := LessonSession.new(StudentModel.new(), bank(), 1, 11)
	s.lesson_length = 50
	var nexts := []
	for i in 40:
		var item := s.next_item()
		var out := s.submit(item.answer if s.in_rescue() else WRONG)
		nexts.append(out.next)
		if out.next == "end_session":
			break
	check(nexts.count("rescue_start") == 2, "two rescues allowed")
	check(nexts.back() == "end_session" and s.ended_early, "3rd trigger ends the session")
	check(s.flags.back().type == "rescue_limit", "teacher flagged")


func test_all_correct_play_reaches_level_up() -> void:
	var m := StudentModel.new()
	var b := bank()
	var lessons := 0
	var repeats := 0
	while m.highest_unlocked == 1 and lessons < 5:
		lessons += 1
		var s := LessonSession.new(m, b, 1, lessons)
		var last := ""
		while true:
			var item := s.next_item()
			if item.id == last:
				repeats += 1
			last = item.id
			var out := s.submit(item.answer, 1200)
			if out.next == "done":
				break
		var sum := s.summary()
		check(sum.stars == 3 and sum.accuracy == 1.0, "all correct = 3 stars")
	check(m.highest_unlocked == 2, "level 2 unlocked by playing")
	check(lessons <= 2, "an all-correct learner clears world 1 in 2 lessons (took %d)" % lessons)
	check(repeats == 0, "never the same item twice in a row")


func test_summary_stars_and_rewards() -> void:
	var s := LessonSession.new(StudentModel.new(), bank(), 1, 5)
	for i in 8:
		s.results.append({"correct": i < 6})
	var sum := s.summary()
	check(sum.stars == 2 and sum.correct == 6, "75% = 2 stars")
	check(sum.xp == 60 and sum.coins == 10, "XP and coins")


# --- Path (D-007) ------------------------------------------------------------------------

func states(layout: Array) -> Array:
	return layout.map(func(n): return "%s:%s" % [n.kind, n.state])


func test_path_progress_rules() -> void:
	var p := PathProgress.new()
	check(states(p.layout(1, true, false)) == ["lesson:current", "lesson:locked", "chest:locked",
			"lesson:locked", "lesson:locked", "lesson:locked", "trophy:locked"], "fresh world")
	p.complete_lesson(1, 0)
	p.complete_lesson(1, 1)
	check(p.chest_ready(1) and p.open_chest(1) and not p.open_chest(1), "chest opens once")
	var early := states(p.layout(1, true, true))
	check(early == ["lesson:done", "lesson:done", "chest:open", "lesson:bonus", "lesson:bonus",
			"lesson:bonus", "trophy:won"], "jump ahead: remaining nodes become bonus")
	p.complete_lesson(1, 3, true)
	check(p.layout(1, true, true)[4].state == "bonus_done", "bonus node done")
	var q := PathProgress.new()
	for i in 5:
		q.complete_lesson(1, i)
	check(q.layout(1, true, false)[5].state == "practice", "5 lessons without mastery = practice")
	check(states(q.layout(2, false, false)).all(func(s): return s.ends_with("locked")),
			"locked world")


# --- Persistence (FR-11) --------------------------------------------------------------------

func test_save_round_trip() -> void:
	var store := SaveStore.new("unit_test")
	store.wipe()
	var m := StudentModel.new()
	master(m, PA, 1)
	m.record(PHONICS, 1, false, 3)
	var p := PathProgress.new()
	p.complete_lesson(1, 0)
	check(store.save_profile({"model": m.to_dict(), "path": p.to_dict()}), "profile saved")
	check(store.save_profile({"model": m.to_dict(), "path": p.to_dict()}), "saved again over it")
	var data := store.load_profile()
	var m2 := StudentModel.new()
	m2.from_dict(data.model)
	var p2 := PathProgress.new()
	p2.from_dict(data.path)
	check(m2.highest_unlocked == m.highest_unlocked, "highest level survives a save/load")
	for k in m.states:
		var a: Dictionary = m.states[k]
		var b: Dictionary = m2.states[k]
		check(absf(a.p - b.p) < 1e-9 and a.attempts == b.attempts and a.mastered == b.mastered
				and a.review == b.review, "%s survives a save/load" % k)
	check(p2.to_dict() == p.to_dict(), "path survives a save/load")
	store.wipe()


func test_event_queue_uuids() -> void:
	var store := SaveStore.new("unit_test")
	store.wipe()
	var re := RegEx.create_from_string(
			"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	for i in 50:
		store.queue_event("response", {"n": i})
	var events := store.read_queue()
	check(events.size() == 50, "50 events queued")
	var ids := {}
	for ev in events:
		ids[ev.id] = true
		check(re.search(ev.id) != null, "UUIDv4 format: %s" % ev.id)
	check(ids.size() == 50, "all UUIDs unique")
	store.wipe()


# --- Content (FR-09) ------------------------------------------------------------------------

func test_content_is_well_formed() -> void:
	var b := bank()
	var ids := {}
	for it in b.items:
		for field in ["id", "sub_skill", "level", "competency", "language", "task_type",
				"prompt", "tts_text", "choices", "answer"]:
			check(it.has(field), "%s has %s" % [it.get("id", "?"), field])
		check(not ids.has(it.id), "unique id %s" % it.id)
		ids[it.id] = true
		check(SkillCatalog.is_active(it.sub_skill, it.level), "%s level in skill range" % it.id)
		var choice_ids: Array = it.choices.map(func(c): return c.id)
		check(choice_ids.has(it.answer), "%s answer is a choice" % it.id)
		check(it.choices.size() >= 2 and it.choices.size() <= 4, "%s has 2-4 choices" % it.id)
		if it.task_type == "drag_letter":
			check(it.pattern.count("_") == 1, "%s has one gap" % it.id)
		var pictures: Array = it.choices.filter(func(c): return c.has("picture")) \
				.map(func(c): return c.picture)
		if it.has("picture"):
			pictures.append(it.picture)
		for p in pictures:
			check(Icons.exists(p), "%s picture '%s' has an SVG in assets/icons" % [it.id, p])
			check(Icons.PICTURE_COLORS.has(p), "%s picture '%s' has a paper color" % [it.id, p])
		check(not _has_emoji(JSON.stringify(it)), "%s has no emoji (D-009)" % it.id)
	for level in [1, 2]:
		for skill in SkillCatalog.active_skills(level):
			var normal := b.items.filter(func(it): return it.sub_skill == skill \
					and it.level == level and not it.recovery)
			check(normal.size() >= 5, "%s L%d has >= 5 items" % [skill, level])
			if SkillCatalog.min_level(skill) == level:
				var easy := b.items.filter(func(it): return it.sub_skill == skill \
						and it.level == level and it.recovery)
				check(easy.size() >= 3, "%s L%d has >= 3 recovery items" % [skill, level])
