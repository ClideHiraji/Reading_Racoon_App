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

const TASK_TYPES := ["tap_choice", "drag_letter", "order_tiles", "spin_words"]
const WORD_CAPS := {3: 60, 4: 100, 5: 130}


# --- Sync (FR-11, D-008) -------------------------------------------------------------------

func test_sync_protocol() -> void:
	var queue := []
	for i in 7:
		queue.append({"id": "id-%d" % i, "type": "response", "payload": {"n": i},
				"device_time": "2026-10-20T04:00:0%dZ" % i})
	var body := SyncProtocol.batch(queue, 5)
	check(body.events.size() == 5 and body.events[0].id == "id-0", "oldest first, at most max_batch")
	check(body.events[4].keys().size() == 4, "only id, type, payload, device_time are sent")
	var ok := SyncProtocol.handle_reply(200, {"acknowledged": ["id-0", "id-1"],
			"rejected": [{"id": "id-2", "reason": "invalid"}]})
	check(ok.ack.size() == 2 and ok.rejected.size() == 1, "200: acknowledged and rejected ids")
	for code in [0, 401, 422, 500]:
		var none := SyncProtocol.handle_reply(code, {"acknowledged": ["id-0"]})
		check(none.ack.is_empty() and none.rejected.is_empty(), "%d drops nothing" % code)
	var device := Time.get_unix_time_from_datetime_string("2026-10-20T04:00:00")
	check(SyncProtocol.clock_offset("2026-10-20T04:05:00Z", device) == 300, "server 5 min ahead")
	check(SyncProtocol.clock_offset("2026-10-20T03:59:00.000000Z", device) == -60, "fractions and Z ignored")
	var p := SyncProtocol.params_from_config({"bkt": {"skills": {
			"phonics": {"l0": 0.3, "t": 0.2, "g": 0.2, "s": 0.1},
			"vocabulary": {"l0": 0.3, "t": 0.2, "g": 0.95, "s": 0.1}}}})
	check(is_equal_approx(p.phonics.l0, 0.3), "remote BKT parameters are used (FR-19)")
	check(is_equal_approx(p.vocabulary.g, SkillCatalog.PARAMS.vocabulary.g), "1 - S > G is enforced")


func test_queue_removal() -> void:
	var store := SaveStore.new("unit_test")
	store.wipe()
	var ids := []
	for i in 5:
		ids.append(store.queue_event("response", {"n": i}))
	store.remove_events([ids[0], ids[2]], [{"id": ids[4], "reason": "invalid"}])
	var left := store.read_queue().map(func(e): return e.id)
	check(left == [ids[1], ids[3]], "acknowledged and rejected events leave; order kept")
	store.wipe()


# --- Play-time limits (FR-12) ---------------------------------------------------------------

func _at(weekday: int, hhmm: String) -> Dictionary:
	var p := hhmm.split(":")
	return {"weekday": weekday, "hour": int(p[0]), "minute": int(p[1])}


func test_access_policy() -> void:
	var s := {"class_start": "07:30", "class_end": "08:30", "school_start": "07:00",
			"school_end": "15:00", "after_school_start": "15:00", "after_school_end": "17:00",
			"daily_minutes": 30, "weekends_open": false}
	check(AccessPolicy.decide({}, _at(3, "10:00"), 0).status == "allowed", "no schedule yet = open")
	check(AccessPolicy.decide(s, _at(1, "07:45"), 99).status == "allowed", "class window: open, no cap")
	check(AccessPolicy.decide(s, _at(1, "10:00"), 0).status == "class_lock", "other subjects: locked")
	var after := AccessPolicy.decide(s, _at(2, "15:30"), 12.0)
	check(after.status == "after_school" and after.minutes_left == 18, "after school: 18 of 30 min left")
	check(AccessPolicy.counts_minutes(after), "after-school minutes count")
	check(AccessPolicy.decide(s, _at(2, "16:00"), 30.0).status == "daily_limit", "cap reached")
	check(AccessPolicy.decide(s, _at(4, "21:00"), 0).status == "sleeping", "night: sleeping")
	check(AccessPolicy.decide(s, _at(6, "10:00"), 0).status == "weekend_lock", "Saturday off by default")
	s.weekends_open = true
	var sat := AccessPolicy.decide(s, _at(0, "10:00"), 5.0)
	check(sat.status == "after_school" and sat.minutes_left == 25, "open weekend uses the daily cap")
	check(not AccessPolicy.is_open(AccessPolicy.decide(s, _at(0, "10:00"), 30.0)), "weekend cap reached")


# --- Shop (FR-07) ----------------------------------------------------------------------------

func test_wardrobe() -> void:
	var w := Wardrobe.new()
	check(w.owns("scarf_teal") and w.is_worn("scarf_teal"), "starts with the river scarf on")
	var wallet := {"coins": 10, "xp": 0}
	check(w.buy("salakot", wallet) == "poor" and wallet.coins == 10, "can't buy without coins")
	wallet.coins = 100
	check(w.buy("salakot", wallet) == "bought", "buys with enough coins")
	check(wallet.coins == 40 and w.is_worn("salakot"), "coins spent and the hat is worn")
	check(w.buy("salakot", wallet) == "owned" and wallet.coins == 40, "never pays twice")
	check(not w.wear("lei"), "can't wear what you don't own")
	w.buy("party_hat", wallet)
	check(w.is_worn("party_hat") and not w.is_worn("salakot"), "one item per slot")
	w.take_off("hat")
	check(not w.equipped.has("hat"), "take off a hat")
	var w2 := Wardrobe.new()
	var saved := w.to_dict()
	saved.owned.append("not_an_item")
	w2.from_dict(saved)
	check(w2.owns("salakot") and w2.owns("party_hat") and not w2.owns("not_an_item"),
			"owned items survive a save/load; unknown ids are dropped")
	for id in Wardrobe.ITEMS:
		check(Wardrobe.SLOTS.has(Wardrobe.ITEMS[id].slot), "%s has a real slot" % id)


# --- Pre/post-test (FR-02, FR-10) -------------------------------------------------------------

func test_tests_follow_the_blueprint() -> void:
	var practice := {}
	for it in bank().items:
		practice[it.id] = true
	var seen := {}
	for kind in ["pre", "post"]:
		var b := QuestionBank.new()
		check(b.load_file(AssessmentSession.FILES[kind]), "%s-test loads" % kind)
		check(b.items.size() == 20, "%s-test has 20 items" % kind)
		var counts := {}
		for it in b.items:
			counts[it.sub_skill] = counts.get(it.sub_skill, 0) + 1
			check(not practice.has(it.id) and not seen.has(it.id), "%s is not reused" % it.id)
			seen[it.id] = true
			check(SkillCatalog.is_active(it.sub_skill, it.level), "%s level in skill range" % it.id)
			var want := "en" if it.level in [1, 2, 5] else "fil"
			check(str(it.language).begins_with(want), "%s follows the language bridge" % it.id)
			if it.has("passage"):
				var p := b.passage(it.passage)
				check(not p.is_empty(), "%s story exists" % it.id)
				if not p.is_empty():
					check(str(p.text).split(" ", false).size() <= WORD_CAPS.get(int(p.level), 60),
							"%s story within word cap" % it.passage)
			if it.task_type == "order_tiles":
				var keys: Array = it.tiles.map(func(t): return QuestionBank.tile_key(t))
				var ans := Array(str(it.answer).split("|"))
				keys.sort()
				ans.sort()
				check(keys == ans, "%s answer uses every tile" % it.id)
			else:
				check(it.choices.map(func(c): return str(c.id)).has(str(it.answer)), "%s answer is a choice" % it.id)
			check(not _has_emoji(JSON.stringify(it)), "%s has no emoji" % it.id)
		for skill in AssessmentSession.BLUEPRINT:
			check(counts.get(skill, 0) == AssessmentSession.BLUEPRINT[skill],
					"%s-test has %d %s items" % [kind, AssessmentSession.BLUEPRINT[skill], skill])


func _results(correct_by_skill: Dictionary) -> Array:
	var out := []
	for skill in AssessmentSession.BLUEPRINT:
		for i in AssessmentSession.BLUEPRINT[skill]:
			out.append({"skill": skill, "correct": correct_by_skill.get(skill, false)})
	return out


func test_placement() -> void:
	var m := StudentModel.new()
	var all_right := {}
	for s in SkillCatalog.SKILLS:
		all_right[s] = true
	check(m.place(_results(all_right)) == 2, "a perfect pre-test starts at level 2 (PA L2 still to learn)")
	check(m.state(PA, 1).mastered and m.state(PHONICS, 1).mastered, "L1 skills placed as mastered")
	check(m.state(SkillCatalog.FLUENCY, 3).mastered, "Fluency L3 placed as mastered")
	check(not m.state(PA, 2).mastered, "only the lowest level is placed")
	check(m.place(_results({})) == 1, "an all-wrong pre-test starts at level 1")
	check(m.state(PA, 1).p < 0.2, "wrong answers lower P(L)")
	check(m.place(_results({PA: true})) == 1, "Phonics L1 still open keeps level 1")


func test_assessment_session() -> void:
	var m := StudentModel.new()
	var s := AssessmentSession.new(m, "pre")
	var out := {}
	var n := 0
	while true:
		var it := s.next_item()
		if it.is_empty():
			break
		n += 1
		out = s.submit(it.answer, 1000)
		check(out.neutral and not out.hint and out.hearts == 3, "neutral outcome, no hints, no hearts")
		if out.next == "done":
			break
	check(n == 20 and out.next == "done", "20 items then done")
	var sum := s.summary()
	check(sum.correct == 20 and sum.placed_level == 2, "scores and placement in the summary")
	check(sum.scores[SkillCatalog.LIT_COMP].total == 8, "raw scores per sub-skill")
	var types := s.drain_events().map(func(e): return e.type)
	check(types.count("response") == 20 and types.has("placement") and types.has("assessment"),
			"responses, placement and scores queued for sync")
	var post := AssessmentSession.new(StudentModel.new(), "post")
	for i in 20:
		var it := post.next_item()
		post.submit("__wrong__")
	check(post.summary().placed_level == 0, "the post-test never re-places the child")


## Stories follow the word caps in 07-curriculum-content.md and have questions.
func test_passages_follow_word_caps() -> void:
	var b := bank()
	check(b.passages.size() >= 8, "at least 8 stories")
	for id in b.passages:
		var p: Dictionary = b.passages[id]
		var words := str(p.text).split(" ", false).size()
		var lvl := int(p.level)
		check(words <= WORD_CAPS.get(lvl, 60), "%s has %d words (cap %d)" % [id, words, WORD_CAPS.get(lvl, 60)])
		check(p.has("title") and p.has("scene") and p.has("language"), "%s has title, scene, language" % id)
		var qs := b.items.filter(func(it): return it.get("passage", "") == id and not it.recovery)
		check(qs.size() >= 3, "%s has >= 3 questions" % id)
		check(not _has_emoji(str(p.text)), "%s has no emoji" % id)


func test_story_questions_stay_together() -> void:
	var m := StudentModel.new()
	m.highest_unlocked = 3
	var s := LessonSession.new(m, bank(), 3, 21)
	var switches := 0
	var last := ""
	for i in 8:
		var item := s.next_item()
		if item.sub_skill == SkillCatalog.LIT_COMP:
			if last != "" and item.passage != last:
				switches += 1
			last = item.passage
		s.submit(item.answer)
	check(switches <= 1, "a lesson does not hop between stories (%d switches)" % switches)


func test_content_is_well_formed() -> void:
	var b := bank()
	var ids := {}
	for it in b.items:
		for field in ["id", "sub_skill", "level", "competency", "language", "task_type",
				"prompt", "tts_text", "answer"]:
			check(it.has(field), "%s has %s" % [it.get("id", "?"), field])
		check(TASK_TYPES.has(it.task_type), "%s has a known task type" % it.id)
		var want_lang := "en" if it.level in [1, 2, 5] else "fil"
		check(str(it.language).begins_with(want_lang), "%s language follows the L3-4 Filipino / L5 English bridge" % it.id)
		if it.has("passage"):
			check(not b.passage(it.passage).is_empty(), "%s story %s exists" % [it.id, it.passage])
		if it.task_type == "order_tiles":
			var keys: Array = it.tiles.map(func(t): return QuestionBank.tile_key(t))
			var sorted_answer := Array(str(it.answer).split("|"))
			sorted_answer.sort()
			keys.sort()
			check(keys == sorted_answer, "%s answer uses every tile once" % it.id)
			check(keys.size() >= 2 and keys.size() <= 7, "%s has 2-7 tiles" % it.id)
			for t in it.tiles:
				if t is Dictionary and t.has("picture"):
					check(Icons.exists(t.picture), "%s tile picture %s exists" % [it.id, t.picture])
			check(not _has_emoji(JSON.stringify(it)), "%s has no emoji (D-009)" % it.id)
			continue
		check(it.has("choices"), "%s has choices" % it.id)
		if it.task_type == "spin_words":
			check(it.has("rime"), "%s has a word ending" % it.id)
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
	for level in range(1, SkillCatalog.MAX_LEVEL + 1):
		for skill in SkillCatalog.active_skills(level):
			var normal := b.items.filter(func(it): return it.sub_skill == skill \
					and it.level == level and not it.recovery)
			check(normal.size() >= 5, "%s L%d has >= 5 items" % [skill, level])
			if SkillCatalog.min_level(skill) == level:
				var easy := b.items.filter(func(it): return it.sub_skill == skill \
						and it.level == level and it.recovery)
				check(easy.size() >= 3, "%s L%d has >= 3 recovery items" % [skill, level])
