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
		check(Icons.has_glyph(world.icon), "world icon '%s' has a glyph" % world.icon)
	for skill in SkillCatalog.SKILLS:
		check(Icons.has_glyph(SkillCatalog.ICONS[skill]), "skill icon for %s has a glyph" % skill)


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


# --- Hearts (D-004, counting from D-021) -------------------------------------------

func test_hearts_lose_and_gain_one() -> void:
	var h := HeartSystem.new()
	h.on_answer(false)
	h.on_answer(false)
	check(h.hearts == 1, "two wrong tries cost two hearts")
	h.on_answer(true)
	check(h.hearts == 2, "a right answer gives one heart back")
	h.on_answer(true)
	h.on_answer(true)
	check(h.hearts == 3, "never more than three hearts")
	for attempt in 2:
		h.on_answer(false)
		h.on_answer(false)
		check(h.on_answer(false) == HeartSystem.Result.RECOVERY, "no hearts left starts recovery")
		check(h.finish_recovery(3), "3/3 is a full recovery")
		check(h.hearts == 3, "full hearts after recovery")
	h.on_answer(false)
	h.on_answer(true)
	h.on_answer(false)
	h.on_answer(false)
	check(h.on_answer(false) == HeartSystem.Result.END_SESSION, "3rd trigger ends the session")


# --- Lesson session ---------------------------------------------------------------------

## Answers the current question wrong on every try it allows (D-021: two tries).
func miss(s: LessonSession) -> Dictionary:
	var out := s.submit(WRONG)
	while out.next == "retry":
		out = s.submit(WRONG)
	return out


func test_partial_rescue_demotes_lower_level() -> void:
	var m := StudentModel.new()
	master(m, PA, 1)
	master(m, PHONICS, 1)
	var s := LessonSession.new(m, bank(), 2, 7)
	var out := {}
	for i in 2:
		var item := s.next_item()
		check(item.sub_skill == PA and item.level == 2, "stays on PA L2 after wrong answers")
		out = miss(s)
	check(out.next == "rescue_start" and out.hearts == 0, "rescue after 3 wrong tries")
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
	for i in 2:
		s.next_item()
		miss(s)
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
		var out := s.submit(item.answer) if s.in_rescue() else miss(s)
		nexts.append(out.next)
		if out.next == "end_session":
			break
	check(nexts.count("rescue_start") == 2, "two rescues allowed")
	check(nexts.back() == "end_session" and s.ended_early, "3rd trigger ends the session")
	check(s.flags.back().type == "rescue_limit", "teacher flagged")


## D-021: two tries per question; only the first is BKT evidence.
func test_second_try_and_hint() -> void:
	var m := StudentModel.new()
	var s := LessonSession.new(m, bank(), 1, 5)
	var item := s.next_item()
	var skill: String = item.sub_skill
	var out := s.submit(WRONG, 900)
	check(out.next == "retry" and out.try == 1 and out.hearts == 2, "a wrong first try: same item, one heart less")
	check(out.hint, "every wrong first try brings Racoon's hint")
	check(m.state(skill, 1).attempts == 1, "the first try is BKT evidence")
	var p_after_first: float = m.state(skill, 1).p
	check(s.progress() == 0.0, "the item isn't over yet")
	out = s.submit(item.answer, 700)
	check(out.correct and out.next == "continue" and out.hearts == 3, "a right second try gives a heart back")
	check(m.state(skill, 1).attempts == 1 and m.state(skill, 1).p == p_after_first,
			"the second try leaves BKT alone")
	var r: Dictionary = s.results[0]
	check(not r.correct and r.solved and r.tries == 2, "recorded as solved on the second try")
	var resp: Array = s.events.filter(func(e): return e.type == "response")
	check(resp.size() == 1 and resp[0].payload.retry_correct and resp[0].payload.hint
			and resp[0].payload.low_pl, "one response event, carrying the second try and the hint")
	var sum := s.summary()
	check(sum.correct == 0 and sum.second_try == 1 and sum.accuracy == 0.5 and sum.xp == 5,
			"a second-try answer earns half")

	var strong := StudentModel.new()
	master(strong, PA, 1)
	strong.states[StudentModel.key(PHONICS, 1)].p = 0.9
	var s2 := LessonSession.new(strong, bank(), 1, 5)
	var it2 := s2.next_item()
	check(it2.sub_skill == PHONICS, "the unmastered skill comes up")
	var slip := s2.submit(WRONG)
	check(slip.hint and not s2.events[0].payload.low_pl, "a hint after a slip too, logged as high P(L)")
	slip = s2.submit(WRONG)
	check(slip.next == "continue" and not slip.correct and slip.hearts == 1,
			"a wrong second try ends the question with one heart left")


## D-021: a lesson plays on a copy; nothing reaches the child's model until it's kept.
func test_lesson_works_on_a_copy() -> void:
	var m := StudentModel.new()
	m.params = SkillCatalog.PARAMS.duplicate(true)
	m.params[PA].l0 = 0.5
	var c := m.copy()
	check(c != m and c.params[PA].l0 == 0.5, "the copy keeps the parameters")
	c.record(PA, 1, true, 3)
	check(m.state(PA, 1).attempts == 0 and c.state(PA, 1).attempts == 1, "the copy changes alone")


## D-021: every lesson question has its own hint and explanation, in its language.
func test_hint_text() -> void:
	var generic := ["Look again carefully. You can do it!", "Tingnan muli nang mabuti. Kaya mo 'yan!"]
	var b := bank()
	var fallback_hints := []
	var fallback_explains := []
	for it in b.items:
		var h := HintText.hint(it)
		var e := HintText.explain(it)
		check(h != "" and e != "" and not _has_emoji(h + e), "%s has a hint and an explanation" % it.id)
		if generic.has(h):
			fallback_hints.append(it.id)
		if e.begins_with("The answer is") or e.begins_with("Ang sagot ay"):
			fallback_explains.append(it.id)
	check(fallback_hints.is_empty(), "no question falls back to a generic hint %s" % str(fallback_hints))
	check(fallback_explains.is_empty(), "no question falls back to a bare answer %s" % str(fallback_explains))
	check(HintText.rime("cat") == "at" and HintText.rime("cake") == "ake", "rhyme endings")
	var by_id := {}
	for it in b.items:
		by_id[it.id] = it
	check(HintText.hint(by_id["pa1-01"]).contains("at"), "a rhyme hint names the ending")
	check(HintText.explain(by_id["pa1-01"]) == "Cat and hat rhyme. They both end with at.", "rhyme explained")
	check(HintText.explain(by_id["ph1-04"]) == "C-a-t spells cat.", "a word built letter by letter")
	check(HintText.explain(by_id["ph3-07"]) == "Ang a at so ay aso.", "Filipino word wheel explained")
	check(HintText.explain(by_id["fl3-01"]) == "Ang tamang ayos: Si Lito ay masaya.", "sentence order explained")
	check(HintText.explain(by_id["fl3-06"]) == "Ang buo: Ang pusa ay ngumiyaw.", "missing word explained")
	check(HintText.explain(by_id["lc3-04"]).begins_with("Una: Nawala ang bola ni Lito."), "story order explained")
	check(HintText.explain(by_id["lc3-03"]).contains("ilalim ng puno"), "a story answer quotes the story")


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
			var next := s.next_item()
			if next.id == last:
				repeats += 1
			last = next.id
			var out := s.submit(next.answer, 1200)
			if out.next == "done":
				break
		var sum := s.summary()
		check(sum.stars == 3 and sum.accuracy == 1.0, "all correct = 3 stars")
	check(m.highest_unlocked == 2, "level 2 unlocked by playing")
	var probe := LessonSession.new(StudentModel.new(), b, 1, 3)
	var item := probe.next_item()
	probe.submit(item.answer)
	var resp: Dictionary = probe.drain_events().filter(func(e): return e.type == "response")[0].payload
	check(resp.num_choices == QuestionBank.num_choices(item),
			"response events carry num_choices for the server's BKT replay")
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


func test_login_code() -> void:
	check(LoginCode.normalize("k7pm-3qxa") == "K7PM3QXA", "case and dash ignored")
	check(LoginCode.is_valid("K7PM-3QXA") and LoginCode.is_valid("k7pm 3qxa"), "valid codes")
	check(not LoginCode.is_valid("K7PM-3QX"), "too short")
	check(not LoginCode.is_valid("K7PM-3QX0"), "0 is never in a code")
	check(LoginCode.format("K7PM3QXA") == "K7PM-3QXA", "shown with a dash")
	for ch in "01OIL":
		check(not LoginCode.ALPHABET.contains(ch), "%s left out (looks like another character)" % ch)


## The sync worker reads 100 events from the head and trims them without parsing
## the whole queue, so even a week offline (thousands of answers) stays cheap.
func test_queue_is_cheap_to_sync() -> void:
	var store := SaveStore.new("unit_test")
	store.wipe()
	for i in 3000:
		store.queue_event("response", {"item_id": "pa1-01", "correct": i % 2 == 0, "n": i})
	check(store.queue_size() == 3000, "3000 events queued")
	var t0 := Time.get_ticks_usec()
	var head := store.read_head(100)
	var read_ms := (Time.get_ticks_usec() - t0) / 1000.0
	check(head.size() == 100 and head[0].payload.n == 0, "head = the oldest 100, in order")
	t0 = Time.get_ticks_usec()
	store.remove_events(head.map(func(e): return e.id))
	var trim_ms := (Time.get_ticks_usec() - t0) / 1000.0
	check(store.queue_size() == 2900, "100 removed")
	check(store.read_head(1)[0].payload.n == 100, "the rest keeps its order")
	check(read_ms < 50.0, "reading 100 of 3000 takes %.1f ms" % read_ms)
	check(trim_ms < 250.0, "trimming takes %.1f ms (on the worker thread)" % trim_ms)
	print("  queue: read_head(100) %.1f ms, trim 3000->2900 %.1f ms" % [read_ms, trim_ms])
	store.wipe()


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


## Another laptop takes the server's save-file copy only when it's newer and nothing waits here.
func test_server_profile_copy() -> void:
	var older := "2026-12-01T00:30:12.123456Z"
	var newer := "2026-12-02T00:05:00.000001Z"
	check(SyncProtocol.take_server_profile(older, "", 0), "a laptop that never had this child takes the copy")
	check(SyncProtocol.take_server_profile(newer, older, 0), "a newer copy from another laptop wins")
	check(not SyncProtocol.take_server_profile(older, older, 0), "the same copy: keep this laptop's save")
	check(not SyncProtocol.take_server_profile(older, newer, 0), "an older copy never replaces a newer save")
	check(not SyncProtocol.take_server_profile(newer, older, 3), "answers waiting here: keep this laptop's save")
	check(not SyncProtocol.take_server_profile("", "", 0), "no copy on the server yet")

	var store := SaveStore.new("unit_test")
	store.wipe()
	check(store.server_copy_path == "user://profile_unit_test_server.json", "the copy record sits next to the profile")
	var copy := {"version": 1, "wallet": {"xp": 40, "coins": 15}, "assessments": {"pre": {"correct": 12, "total": 20}}}
	check(store.save_profile(copy), "the server's copy is written as this laptop's save")
	var back := store.load_profile()
	check(int(back.wallet.coins) == 15 and back.assessments.has("pre"), "coins and the pre-test come back")
	store.wipe()
	check(not FileAccess.file_exists(store.server_copy_path), "wipe removes the copy record too")


# --- Lossless queue and retries over the internet (D-036) ------------------------------------

## A crash between the two moves of SaveStore.replace_file() leaves only the
## .bak copy; the next start brings the queue back with every event.
func test_queue_survives_a_crash_mid_rewrite() -> void:
	var store := SaveStore.new("unit_test")
	store.wipe()
	var ids := []
	for i in 4:
		ids.append(store.queue_event("response", {"n": i}))
	DirAccess.rename_absolute(store.queue_path, store.queue_path + ".bak")
	check(not FileAccess.file_exists(store.queue_path), "crash: the queue file is gone")
	var reopened := SaveStore.new("unit_test")
	check(reopened.read_queue().map(func(e): return e.id) == ids, "recovered from .bak, order kept")
	check(not FileAccess.file_exists(store.queue_path + ".bak"), "the .bak is used up")
	check(SaveStore.write_json(store.profile_path, {"a": 1}) and SaveStore.write_json(store.profile_path, {"a": 2}),
			"atomic profile writes over an existing file")
	check(store.load_profile().get("a") == 2, "the newer profile wins")
	check(not FileAccess.file_exists(store.profile_path + ".tmp"), "no temp file left behind")
	store.wipe()


## An app killed mid-append leaves half a line. The next event must still be
## readable, and the broken line is moved aside (not left at the head forever).
func test_a_half_written_line_never_swallows_the_next_event() -> void:
	var store := SaveStore.new("unit_test")
	store.wipe()
	var first := store.queue_event("response", {"n": 0})
	var f := FileAccess.open(store.queue_path, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string('{"device_time":"2026-11-19T01:00:00Z","id":"00000000-0000-4000-8000-0000000000')
	f.close()
	var second := store.queue_event("response", {"n": 1})
	var queued := store.read_queue().map(func(e): return e.id)
	check(queued == [first, second], "both whole events read; the broken line skipped")
	store.remove_events([first])
	check(store.read_queue().map(func(e): return e.id) == [second], "only the unsent event stays")
	check(store.queue_size() == 1, "the broken line left the queue")
	var side := FileAccess.get_file_as_string(store.queue_path.get_basename() + "_rejected.jsonl")
	check(side.contains("truncated"), "and was kept in the side file for debugging")
	store.wipe()


## A queue copied through a Windows tool can gain CR line ends: still whole events.
func test_crlf_lines_are_not_mistaken_for_damage() -> void:
	var store := SaveStore.new("unit_test")
	store.wipe()
	var a := store.queue_event("response", {"n": 0})
	var b := store.queue_event("response", {"n": 1})
	var text := FileAccess.get_file_as_string(store.queue_path).replace("\n", "\r\n")
	var f := FileAccess.open(store.queue_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	store.remove_events([a])
	check(store.read_queue().map(func(e): return e.id) == [b], "the unsent CRLF event stays queued")
	store.wipe()


func test_retry_policy() -> void:
	check(is_equal_approx(SyncProtocol.backoff(1, 0.0, 0.0), 15.0), "first retry: 15-30 s")
	check(is_equal_approx(SyncProtocol.backoff(1, 0.0, 1.0), 30.0), "first retry ceiling 30 s")
	check(is_equal_approx(SyncProtocol.backoff(3, 0.0, 1.0), 120.0), "doubles each time")
	for n in [8, 20, 1000]:
		var w := SyncProtocol.backoff(n, 0.0, 0.7)
		check(w >= 300.0 and w <= 600.0, "capped at 10 min after %d failures (%.0f s)" % [n, w])
	check(SyncProtocol.backoff(2, 0.0, 0.1) != SyncProtocol.backoff(2, 0.0, 0.9), "jitter spreads a classroom")
	check(is_equal_approx(SyncProtocol.backoff(1, 900.0, 0.5), 900.0), "Retry-After asks for longer: wait that long")
	check(is_equal_approx(SyncProtocol.backoff(1, 99999.0, 0.5), 3600.0), "but never more than an hour")
	check(is_equal_approx(SyncProtocol.retry_after(PackedStringArray(["Content-Type: x", "Retry-After: 45"])), 45.0),
			"Retry-After seconds read")
	check(SyncProtocol.retry_after(PackedStringArray(["retry-after: Wed, 21 Oct 2026 07:28:00 GMT"])) == 0.0,
			"a date form falls back to backoff")
	check(SyncProtocol.retry_after(PackedStringArray()) == 0.0, "no header")


func test_release_builds_talk_https_only() -> void:
	check(SyncProtocol.is_allowed_server("https://racoon.example.org", false), "https in release")
	check(not SyncProtocol.is_allowed_server("http://racoon.example.org", false), "plain http to the internet refused")
	check(not SyncProtocol.is_allowed_server("http://192.168.1.20:8000", false), "plain http on Wi-Fi refused")
	check(SyncProtocol.is_allowed_server("http://127.0.0.1:8000", false), "a server on this machine")
	check(SyncProtocol.is_allowed_server("http://localhost:8000/", false), "localhost")
	check(not SyncProtocol.is_allowed_server("http://localhost.evil.example", false), "not a lookalike host")
	check(SyncProtocol.is_allowed_server("http://192.168.1.20:8000", true), "anything in a debug build")
	check(not SyncProtocol.is_allowed_server("", true), "no server")


func test_download_chunks_must_continue_the_part() -> void:
	var h := PackedStringArray(["Content-Type: video/ogg", "Content-Range: bytes 4194304-8388607/9000000"])
	check(SyncProtocol.range_starts_at(h, 4194304), "the chunk starts where the part ends")
	check(not SyncProtocol.range_starts_at(h, 0), "a chunk from elsewhere is refused")
	check(not SyncProtocol.range_starts_at(PackedStringArray(["Content-Length: 5"]), 0), "no Content-Range")


# --- Play-time limits (FR-12) ---------------------------------------------------------------

func _at(weekday: int, hhmm: String) -> Dictionary:
	var p := hhmm.split(":")
	return {"weekday": weekday, "hour": int(p[0]), "minute": int(p[1])}


func test_access_policy() -> void:
	var s := {"class_start": "07:30", "class_end": "08:30", "after_school_start": "15:00",
			"after_school_end": "17:00", "daily_minutes": 30, "weekends_open": false}
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
	# Same answers as the server's AccessDecider for any schedule a teacher can save.
	check(AccessPolicy.decide(s, _at(0, "22:00"), 0).status == "sleeping", "open weekend still sleeps at night")
	check(AccessPolicy.decide(s, _at(3, "17:30"), 0).status == "class_lock", "awake weekday outside the windows: locked")
	check(AccessPolicy.decide(s, _at(3, "16:50"), 0).minutes_left == 10, "minutes left stop at the window's end")
	s.after_school_start = "14:00"
	s.after_school_end = "16:00"
	var early := AccessPolicy.decide(s, _at(3, "14:30"), 0)
	check(early.status == "after_school" and early.minutes_left == 30, "after school from 14:00: 14:30 is open")
	check(AccessPolicy.adventure_opens(s, _at(3, "10:00"), 0) == "14:00", "opens at the teacher's after-school time")
	check(AccessPolicy.adventure_opens(s, _at(5, "18:00"), 0) == "06:00", "open weekend: Saturday opens at day start")
	check(AccessPolicy.adventure_opens(s, _at(6, "05:00"), 0) == "06:00", "open weekend: opens at day start")
	check(AccessPolicy.adventure_opens(s, _at(0, "18:00"), 30.0) == "07:30", "Sunday cap used: Monday's class")

	# The tablet reads the school's clock: 06:30 UTC is 14:30 in Manila, even on a
	# tablet set to New York (UTC-5).
	var unix := Time.get_unix_time_from_datetime_string("2026-11-25T06:30:00")
	s.timezone = "Asia/Manila"
	var manila := AccessPolicy.school_clock(unix, s, -300)
	check(manila.hour == 14 and manila.minute == 30 and manila.weekday == 3, "school clock is Manila time")
	check(AccessPolicy.decide(s, manila, 0).status == "after_school", "wrong device zone: after school still open")
	check(AccessPolicy.school_clock(unix, {}, -300).hour == 1, "no schedule yet: the device's own zone")


## D-016: everything the child taps on the core palette takes dark ink text that
## passes WCAG AA (4.5:1).
func test_palette_text_contrast() -> void:
	var faces := {"blue": Palette.BLUE, "cream": Palette.CREAM, "yellow": Palette.YELLOW,
			"orange": Palette.ORANGE, "leaf": Palette.LEAF, "light plum": Palette.PLUM_LIGHT,
			"locked": Color("efe9d2"), "card": Palette.CARD}   # locked: Practice's LOCKED face
	for name in faces:
		var c: Color = faces[name]
		check(Palette.text_on(c) == Palette.INK, "%s takes dark text" % name)
		check(Palette.contrast(c, Palette.INK) >= 4.5, "%s with ink passes 4.5:1 (%.1f)" % [
				name, Palette.contrast(c, Palette.INK)])
	check(Palette.text_on(Palette.PLUM_DEEP) == Palette.CARD, "dark faces still get light text")
	for c in [Palette.YELLOW, Palette.MANGO_DEEP, Palette.ORANGE, Palette.BLUE, Palette.LEAF]:
		check(Palette.contrast(Palette.readable(c), Palette.CARD) >= 4.5, "readable(%s) reads on cream" % c.to_html(false))
	near(Palette.contrast(Color.WHITE, Color.BLACK), 21.0, 0.01, "contrast of white on black")


## D-015: only Adventure follows the school schedule; the hub sleeps at night and
## Practice, Library and Watch share a free-play timer outside Reading time.
func test_hub_and_free_play_access() -> void:
	var s := AccessPolicy.DEFAULTS.duplicate()
	check(AccessPolicy.hub({}, _at(3, "23:00")).status == "allowed", "no schedule yet = hub open")
	check(AccessPolicy.hub(s, _at(1, "10:00")).status == "allowed", "hub open in other class hours")
	check(AccessPolicy.hub(s, _at(6, "10:00")).status == "allowed", "hub open on Saturday")
	check(AccessPolicy.hub(s, _at(2, "21:00")).status == "sleeping", "hub asleep from 9 PM")
	check(AccessPolicy.hub(s, _at(2, "05:59")).status == "sleeping", "hub asleep before 6 AM")

	check(AccessPolicy.free_play(s, _at(1, "07:45"), 99).status == "allowed", "Reading time: free play has no timer")
	var day := AccessPolicy.free_play(s, _at(1, "10:00"), 15.0)
	check(day.status == "free_play" and day.minutes_left == 30, "other class hours: 30 of 45 min left")
	check(AccessPolicy.counts_minutes(day), "free-play minutes count outside Reading time")
	check(AccessPolicy.free_play(s, _at(3, "18:00"), 45.0).status == "free_limit", "free-play timer used up")
	check(AccessPolicy.is_open(AccessPolicy.free_play(s, _at(0, "10:00"), 0)), "free play open on Sunday")
	check(AccessPolicy.free_play(s, _at(3, "22:00"), 0).status == "sleeping", "free play asleep at night")
	s.free_play_minutes = 20
	check(AccessPolicy.free_play(s, _at(3, "18:00"), 20.0).status == "free_limit", "teacher sets the timer")

	check(AccessPolicy.adventure_opens(s, _at(1, "06:30"), 0) == "07:30", "opens at class time")
	check(AccessPolicy.adventure_opens(s, _at(1, "10:00"), 0) == "15:00", "opens after school")
	check(AccessPolicy.adventure_opens(s, _at(1, "10:00"), 30.0) == "07:30", "cap used: tomorrow's class")
	check(AccessPolicy.adventure_opens(s, _at(1, "18:00"), 0) == "07:30", "evening: tomorrow's class")
	check(AccessPolicy.adventure_opens({}, _at(1, "18:00"), 0) == "", "no schedule: no time")
	check(AccessPolicy.clock_text("07:30") == "7:30 AM" and AccessPolicy.clock_text("15:00") == "3:00 PM"
			and AccessPolicy.clock_text("00:05") == "12:05 AM", "clock text")

	for id in HubSections.ALL:
		var info: Dictionary = HubSections.ALL[id]
		check(Icons.has_glyph(info.icon), "hub section icon '%s' has a glyph" % info.icon)
		check(Icons.has_picture(info.icon), "hub section icon '%s' has a full-colour drawing (D-027)" % info.icon)
		check(info.kind in ["adventure", "free", "collection"], "%s has a time rule" % id)
		check(info.scene == "" or ResourceLoader.exists(info.scene), "%s scene exists" % id)


# --- Shop (FR-07) ----------------------------------------------------------------------------

## D-044: the opening plays once per launch, and never in a test or debug run.
func test_intro_plays_once() -> void:
	var had := Intro.played
	Intro.played = false
	check(Intro.should_play({}), "the opening plays when the game starts")
	check(not Intro.should_play({"no-intro": ""}) and not Intro.should_play({"profile": "smoke"}),
			"test and debug runs skip the opening")
	Intro.played = true
	check(not Intro.should_play({}), "the opening plays once per launch")
	check(Intro.LIFT_AT + Intro.LIFT_TIME < 3.5, "the opening is short: under 3.5 s")
	Intro.played = had


func test_wardrobe() -> void:
	var w := Wardrobe.new()
	check(w.owns("scarf_teal") and not w.is_worn("scarf_teal"), "owns the river scarf but starts without it (D-024)")
	check(w.owns("open_book") and w.equipped.is_empty(), "owns the open book; wears nothing at first")
	check(w.wear("open_book") and w.equipped.get("paws", "") == "open_book", "the book goes in his paws")
	w.take_off("paws")
	check(Wardrobe.slot_name("paws", "roco") == "In his paws" and Wardrobe.slot_name("paws", "rina") == "In her paws",
			"the paws tab follows the buddy (D-033)")
	check(Wardrobe.slot_name("hat", "rina") == "Hats" and Wardrobe.slot_name("pet", "roco") == "Pets",
			"the other tabs are the same for both buddies")
	var wallet := {"coins": 10, "xp": 0}
	check(w.buy("party_hat", wallet) == "poor" and wallet.coins == 10, "can't buy without coins")
	wallet.coins = 100
	check(w.buy("party_hat", wallet) == "bought", "buys with enough coins")
	check(wallet.coins == 70 and w.is_worn("party_hat"), "coins spent and the hat is worn")
	check(w.buy("party_hat", wallet) == "owned" and wallet.coins == 70, "never pays twice")
	check(not w.wear("lei"), "can't wear what you don't own")
	wallet.coins = 150
	w.buy("flower_crown", wallet)
	check(w.is_worn("flower_crown") and not w.is_worn("party_hat"), "one item per slot")
	w.take_off("hat")
	check(not w.equipped.has("hat"), "take off a hat")
	var w2 := Wardrobe.new()
	var saved := w.to_dict()
	saved.owned.append("not_an_item")
	w2.from_dict(saved)
	check(w2.owns("flower_crown") and w2.owns("party_hat") and not w2.owns("not_an_item"),
			"owned items survive a save/load; unknown ids are dropped")
	var old := Wardrobe.new()
	old.from_dict({"owned": ["scarf_teal"], "equipped": {"neck": "scarf_teal"}})
	check(old.is_worn("scarf_teal") and old.owns("open_book"), "an older save keeps its scarf on and gets the free book")
	for id in Wardrobe.ITEMS:
		check(Wardrobe.SLOTS.has(Wardrobe.ITEMS[id].slot), "%s has a real slot" % id)


## His head and its outline are meshes the game builds when the scene loads (fine round the cheek
## fur); a scene saved with them as plain quads must still get every triangle back (2026-11-17).
func test_racoon_scene_draws_his_head() -> void:
	var pp: RacoonPuppet = load("res://scenes/companion/racoon_puppet.tscn").instantiate()
	pp._ensure_nodes()
	for path in ["Body/Head/Skull", "Body/Head/HeadLine"]:
		var part: Polygon2D = pp.get_node(path)
		check(part.polygons.size() > 100 and part.polygon.size() > 100, "%s is a full mesh (%d triangles)" % [path, part.polygons.size()])
	pp.free()


## D-030: what he holds in his paws is stiff. An arm that points, waves or goes to his chin never
## stretches it; it rides in his other paw instead.
func test_paws_item_is_stiff() -> void:
	var pp: RacoonPuppet = load("res://scenes/companion/racoon_puppet.tscn").instantiate()
	pp._ensure_nodes()
	# [pose, which paw holds it: "both", "left" or "right"]
	var cases := {"held in both paws": [{}, "both"],
		"right arm points up": [{"armR": 1.0, "tRx": 330.0, "tRy": 120.0}, "left"],
		"left paw at his chin": [{"armL": 1.0, "tLx": 185.0, "tLy": 255.0}, "right"],
		"right paw lifted a little (it tilts, still in both)": [{"liftR": 1.2}, "both"],
		"right paw let go (right_paw_free)": [{"freeR": 1.0}, "left"]}
	for label in cases:
		pp.p = pp.pose.duplicate()
		pp.p.merge({"bookS": 1.0, "hold": 1.0}, true)
		pp.p.merge(cases[label][0], true)
		var f: Dictionary = pp._rig_frame()
		var xf: Transform2D = f.book.xf
		check(absf(xf.x.length() - 1.0) < 0.01 and absf(xf.y.length() - 1.0) < 0.01 and absf(xf.x.dot(xf.y)) < 0.01,
				"the item in his paws keeps its shape: %s" % label)
		var holds := "both" if f.book.grip < 0.5 else ("right" if f.book.byRight > 0.5 else "left")
		check(holds == cases[label][1], "%s: held in %s paw(s), got %s" % [label, cases[label][1], holds])
	pp.free()


## D-026: five tiers, prices that rise with them, items earned (never bought) by real goals, and
## every item drawn on the Closet's sheet.
func test_closet_tiers() -> void:
	var bands := {"silver": [20, 40], "violet": [60, 90], "gold": [150, 250], "diamond": [400, 500]}
	var per_tier := {}
	var earned_diamonds := 0
	var rig = JSON.parse_string(FileAccess.get_file_as_string("res://assets/racoon/racoon_rig.json"))
	for id in Wardrobe.ITEMS:
		var it: Dictionary = Wardrobe.ITEMS[id]
		check(Wardrobe.TIERS.has(it.tier), "%s has a real tier" % id)
		per_tier[it.tier] = int(per_tier.get(it.tier, 0)) + 1
		if Wardrobe.is_earned_item(id):
			check(int(it.price) == 0 and Wardrobe.earn_text(id) != "", "%s is earned, not sold, and says how" % id)
			if it.tier == "diamond":
				earned_diamonds += 1
		elif int(it.price) > 0:
			var b: Array = bands.get(it.tier, [0, 0])
			check(int(it.price) >= b[0] and int(it.price) <= b[1], "%s costs what a %s item costs" % [id, it.tier])
		else:
			check(it.tier == "copper", "%s is free, so it's copper" % id)
		if Wardrobe.is_code_drawn(id):
			check((it.slot == "pet" and Pet.has_kind(id)) or (it.slot == "hat" and Halo.has_kind(id)),
					"%s is drawn in code: a pet (D-029) or a halo (D-031)" % id)
			continue
		if Wardrobe.wind_of(id) != "":
			check(Wardrobe.is_scarf(id) and WindScarf.has_style(Wardrobe.wind_of(id)),
					"%s is a scarf whose tails WindScarf draws (D-031)" % id)
		var tex: String = id + ".band" if Wardrobe.is_scarf(id) else id
		check(rig.textures.has(tex) and rig.textures[tex].sheet == "closet_" + str(it.slot),
				"%s is drawn on its slot's sheet (closet/%s)" % [id, it.slot])
	for t in Wardrobe.TIER_ORDER:
		check(int(per_tier.get(t, 0)) >= 3, "the %s tier has at least 3 items" % t)
	# D-031: windblown diamond scarves and a halo
	var windy := 0
	for id in Wardrobe.new().items_in("neck"):
		if Wardrobe.wind_of(id) != "" and Wardrobe.ITEMS[id].tier == "diamond":
			windy += 1
	check(windy >= 3, "three diamond scarves blow in the wind (D-031)")
	check(Wardrobe.ITEMS.has("star_halo") and Wardrobe.ITEMS.star_halo.slot == "hat", "the Star halo is a hat (D-031)")
	# D-029: clothes instead of pins, and pets
	check(not Wardrobe.SLOTS.has("badge") and Wardrobe.SLOTS.has("top") and Wardrobe.SLOTS.has("pet"), "tops and pets, no pins")
	check(Wardrobe.new().items_in("top").size() >= 10, "at least 10 tops and dresses")
	for kind in Pet.KINDS:
		check(Wardrobe.ITEMS.has(kind) and Wardrobe.ITEMS[kind].slot == "pet", "pet %s is in the Closet" % kind)
	var w2 := Wardrobe.new()
	w2.from_dict({"owned": ["pin_star", "cap"], "equipped": {"badge": "pin_star", "hat": "cap"}})
	check(not w2.owns("pin_star") and not w2.equipped.has("badge"), "an old save's pins are dropped")
	check(earned_diamonds >= 1 and earned_diamonds <= 2, "one or two diamond items are earned with a big goal")
	check(int(Wardrobe.ITEMS.scarf_rainbow.earn[1]) == Collection.STICKERS.size(), "the Rainbow scarf needs every sticker")
	check(int(Wardrobe.ITEMS.crystal_book.earn[1]) == SkillCatalog.MAX_LEVEL, "the Crystal storybook needs every world")
	var w := Wardrobe.new()
	check(w.buy("cap", {"coins": 999}) == "earn" and not w.owns("cap"), "an earned item can't be bought")
	check(w.grant_earned({"lessons": 0}).is_empty(), "nothing earned before the first lesson")
	var got := w.grant_earned({"lessons": 1, "books": 1})
	check(got.has("cap") and got.has("round_glasses") and not got.has("book_tee") and w.owns("cap"),
			"a first lesson and a first book earn the River cap and reading glasses")
	check(w.grant_earned({"lessons": 1, "books": 1}).is_empty(), "an item is earned once")
	var order: Array = w.items_in("hat").map(func(i): return Wardrobe.tier_of(i).rank)
	var sorted := order.duplicate()
	sorted.sort()
	check(order == sorted, "the Closet lists copper first, diamond last")

	check(Wardrobe.ITEMS.size() >= 27, "the catalogue (content/closet.json) loads every item")
	for id in Wardrobe.ITEMS:
		var rc: Dictionary = Wardrobe.ITEMS[id].get("recolor", {})
		if not rc.is_empty():
			check(Wardrobe.ITEMS.has(rc.of) and Wardrobe.ITEMS[rc.of].slot == Wardrobe.ITEMS[id].slot,
					"%s recolours an item in the same slot" % id)


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
	check(sum.passed.size() == 5 and sum.passed.values().all(func(v): return v),
			"every skill passed on a perfect test (D-021)")
	var post := AssessmentSession.new(StudentModel.new(), "post")
	for i in 20:
		post.next_item()
		post.submit("__wrong__")
	check(post.summary().placed_level == 0, "the post-test never re-places the child")
	check(post.summary().passed.values().count(true) == 0, "nothing passed on an all-wrong test")


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
			check(Icons.exists(p), "%s picture '%s' can be shown" % [it.id, p])
			check(Icons.PICTURE_COLORS.has(p), "%s picture '%s' has a paper color" % [it.id, p])
			check(Icons.has_picture(p), "%s picture '%s' has a full-colour drawing (D-027)" % [it.id, p])
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


# --- Practice, Library, Watch & Listen, collections (D-017) ---------------------------------

func test_collection_stickers_and_goals() -> void:
	var c := Collection.new()
	var ids := {}
	for id in Collection.STICKERS:
		var s: Dictionary = Collection.STICKERS[id]
		check(Collection.GROUPS.has(s.group), "sticker %s has a group" % id)
		check(Icons.exists(id), "sticker %s has an SVG" % id)
		check(Icons.has_picture(id), "sticker %s has a full-colour drawing (D-027)" % id)
		ids[id] = true
	check(ids.size() == 40, "40 stickers in the album (got %d)" % ids.size())
	check(c.earn("games", "2026-10-21") == "ball", "games stickers come in album order")
	check(c.earn_once_a_day("games", "2026-10-21") == "bee", "a games sticker once a day")
	check(c.earn_once_a_day("games", "2026-10-21") == "", "no second one the same day")
	check(c.earn_once_a_day("games", "2026-10-22") == "frog", "another one the next day")
	for i in 10:
		c.earn("goals", "2026-10-21")
	check(c.count("goals") == 6 and c.earn("goals", "2026-10-21") == "", "a full group gives no more")
	check(c.mark_day("2026-10-21") and not c.mark_day("2026-10-21"), "a day counts once")
	var a := c.complete_goal("story", "2026-10-21")
	check(a.new and not a.all, "first goal done")
	check(not c.complete_goal("story", "2026-10-21").new, "a goal counts once a day")
	c.complete_goal("game", "2026-10-21")
	var last := c.complete_goal("lesson", "2026-10-21")
	check(last.new and last.all, "all three goals done")
	check(c.goals_left("2026-10-21") == 0 and c.goals_left("2026-10-22") == 3, "goals start fresh each day")
	check(not c.complete_goal("nap", "2026-10-22").new, "unknown goals are ignored")
	check(c.finish("racoon-boat", "2026-10-21") and not c.finish("racoon-boat", "2026-10-22"),
			"a book is finished once")
	var back := Collection.new()
	back.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check(back.count() == c.count() and back.is_finished("racoon-boat") and back.days.size() == 1,
			"collection survives saving")


func test_collection_words() -> void:
	var c := Collection.new()
	check(c.add_word("Isda.", "fish", "fil", "book", "2026-10-21"), "a new word is added")
	check(not c.add_word("isda", "fish", "fil", "game", "2026-10-21"), "a word is added once")
	check(not c.add_word("Si Lito", "", "fil", "book", "2026-10-21"), "two words are not a word")
	check(not c.add_word("2", "hand", "en", "lesson", "2026-10-21"), "numbers are not words")
	check(c.add_word("niño", "", "fil", "book", "2026-10-21"), "ñ is a letter")
	check(c.word_list("fil") == ["isda", "niño"] and c.word_list("en").is_empty(), "words by language")
	var b := bank()
	var got := {}
	for id in ["pa1-01", "ph1-04", "ph2-09", "ph3-01", "vo2-01"]:
		for w in Collection.words_from_item(b.item(id)):
			got[w.word] = w
	check(got.has("hat") and got.has("cat"), "rhyme item gives the answer and the word")
	check(got.has("cat") and got.cat.picture == "cat", "drag-the-letter gives the built word")
	check(got.has("hat"), "word wheel gives the spun word")
	check(got.has("isda") and got.isda.lang == "fil", "syllables give the Filipino word")
	check(got.has("book"), "picture vocabulary gives the word")
	check(Collection.words_from_item(b.item("ph1-01")).is_empty(), "letter items give no word")


## D-027: the redrawn pictures load, are drawn in their own colours, and fall back to the tinted
## silhouette where there's no drawing.
func test_full_colour_pictures() -> void:
	var names := []
	for f in DirAccess.get_files_at("res://assets/pictures"):
		if f.ends_with(".svg"):
			names.append(f.get_basename())
	check(names.size() >= 63, "63 full-colour pictures (got %d)" % names.size())
	for ui in ["coin", "sticker", "wordbook", "hat", "scarf", "glasses", "star", "book"]:
		check(Icons.has_picture(ui), "the UI picture %s is drawn (D-027)" % ui)
	check(Icons.exists("cat") and not Icons.has_glyph("ant") and Icons.exists("ant"),
			"a picture with no glyph can still be shown (D-027)")
	for g2 in PracticePool.GAMES:
		check(Icons.has_picture(g2.icon), "practice game %s has a full-colour picture" % g2.id)
	for n in names:
		var t := Icons.picture_tex(n)
		check(t != null and t.get_width() >= 256, "picture %s loads at 256 px or more" % n)
	var r := Icons.picture_rect("cat", 100)
	check(r.texture == Icons.picture_tex("cat") and r.self_modulate == Color.WHITE, "a picture is drawn untinted")
	r.free()
	var g := Icons.picture_rect("play", 100, Palette.TEAL)
	check(g.texture == Icons.tex("play") and g.self_modulate == Palette.TEAL, "no drawing: the tinted glyph")
	g.free()
	var s := Kit.sticker("sun", 124)
	var pic := s.get_child(0) as TextureRect
	check(pic != null and pic.texture == Icons.picture_tex("sun"), "a sticker shows its full-colour picture")
	s.free()
	var b := ChunkyButton.new()
	b.full_color = true
	b.icon_name = "bulb"
	check(b.icon == Icons.picture_tex("bulb"), "a full-colour button shows the picture")
	b.icon_name = "play"
	check(b.icon == Icons.tex("play"), "a full-colour button without a picture shows the glyph")
	b.full_color = false
	b.icon_name = "bulb"
	check(b.icon == Icons.tex("bulb"), "a plain button keeps the tinted glyph")
	b.free()


func test_practice_pool() -> void:
	var b := bank()
	var words := PracticePool.picture_words(b, 1)
	check(words.size() >= 6, "level 1 has words with pictures for Memory Match (%d)" % words.size())
	for w in words:
		check(Icons.exists(w.picture), "practice word %s has a picture" % w.word)
	check(PracticePool.rhymes(b, 1).size() >= 2, "level 1 has rhyme rounds")
	check(PracticePool.unlocked("rhyme_pop", b, 1), "Rhyme Pop opens at level 1")
	check(PracticePool.game("memory_match").is_empty(), "Memory Match isn't a Practice game (D-043)")
	for g in PracticePool.GAMES:
		var met := b.items.filter(func(it): return str(it.get("variant", "")) == g.id 				or (g.has("task") and it.task_type == g.task and str(it.get("variant", "")) == g.variant))
		check(not met.is_empty(), "%s is in the adventure too (D-043)" % g.name)
		var first: int = met.reduce(func(lo, it): return mini(lo, int(it.level)), 99)
		check(PracticePool.unlocked(g.id, b, first), "%s opens in Practice by the world it's in (%d)" % [g.name, first])
	check(not PracticePool.unlocked("word_catch", b, 1), "Word Catch waits for level 2")
	check(PracticePool.lock_text("word_catch", b, 1) == "Finish Level 1", "Word Catch says what opens it")
	check(PracticePool.unlocked("word_catch", b, 2), "Word Catch opens at level 2")
	check(not PracticePool.unlocked("spin_words", b, 1) and PracticePool.unlocked("spin_words", b, 2),
			"Spin the Words opens with its first items")
	check(PracticePool.unlocked("syllable_train", b, 2), "Syllable Train opens at level 2")
	check(not PracticePool.unlocked("story_shuffle", b, 2) and PracticePool.unlocked("story_shuffle", b, 3),
			"Story Shuffle opens with the first stories")
	check(PracticePool.lock_text("story_shuffle", b, 2) == "Reach Level 3", "Story Shuffle lock text")
	check(PracticePool.coins_for(0) == 2 and PracticePool.coins_for(9) == 5, "practice coins 2 to 5")
	for g in PracticePool.GAMES:
		check(ResourceLoader.exists(g.scene), "%s scene exists" % g.id)
		check(Icons.exists(g.icon), "%s icon exists" % g.id)
		check(g.skill in PracticePool.SKILLS, "%s has a skill" % g.id)


func test_media_library_content() -> void:
	var m := MediaLibrary.new()
	m.load_all()
	check(m.books.size() >= 8, "8 Library books (%d)" % m.books.size())
	var langs := {}
	var ids := {}
	for b in m.books:
		check(not ids.has(b.id), "unique book id %s" % b.id)
		ids[b.id] = true
		langs[Collection.lang_of(b.language)] = true
		check(b.pages.size() >= 5, "%s has at least 5 pages" % b.id)
		check(b.questions.size() == 2, "%s has 2 questions" % b.id)
		check(str(b.get("credit", "")) != "", "%s has a credit" % b.id)
		for p in b.pages:
			check(str(p.text) != "" and p.text.split(" ").size() <= 12, "%s page is short" % b.id)
			for pic in p.get("pictures", []):
				check(Icons.exists(pic), "%s picture %s exists" % [b.id, pic])
		for q in b.questions:
			check(q.choices.map(func(c): return c.id).has(q.answer), "%s question answer is a choice" % b.id)
		for w in b.words:
			check(Collection.clean_word(w.word) != "" and Icons.exists(w.picture), "%s word %s" % [b.id, w.word])
	check(langs.has("en") and langs.has("fil") and langs.has("bis"), "books in English, Filipino, Bisaya")
	check(m.books_in("bis").size() >= 2, "Bisaya filter finds the Bisaya books")
	check(m.books_in("").front().level == "easy", "easiest books first")
	check(m.watch.size() >= 6, "Watch & Listen items (%d)" % m.watch.size())
	for w in m.watch:
		check(MediaLibrary.KINDS.has(w.kind), "%s has a known kind" % w.id)
		var lines := m.lines_of(w)
		check(not lines.is_empty(), "%s has lines to play" % w.id)
		for l in lines:
			for pic in l.get("pictures", []):
				check(Icons.exists(pic), "%s picture %s exists" % [w.id, pic])
		if w.has("check"):
			check(w.check.choices.map(func(c): return c.id).has(w.check.answer), "%s check answer" % w.id)
	check(MediaLibrary.video_ready({"kind": "song"}), "songs need no download")
	check(not MediaLibrary.video_ready({"kind": "video", "file": "user://content/none.ogv"}),
			"videos wait for their download")
	for f in ["res://content/library.json", "res://content/watch.json"]:
		check(not _has_emoji(FileAccess.get_file_as_string(f)), "%s has no emoji (D-009)" % f)


func test_read_along_word_starts() -> void:
	var speech := preload("res://scripts/autoload/speech.gd")
	check(speech.base_lang("bis-placeholder") == "bis" and speech.base_lang("fil") == "fil"
			and speech.base_lang("en-placeholder") == "en", "voices for English, Filipino, Bisaya")
	var starts := Array(speech.word_starts("May bangka  si Lolo."))
	check(starts == [0, 4, 12, 15], "word starts for read-along (%s)" % str(starts))


# --- Teacher content download (D-020, server D-019) ---------------------------------------

const SHA_A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const SHA_B := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"


func _manifest() -> Dictionary:
	return {"version": "v1", "books": [
		{"id": "tb-one", "title": "T", "language": "fil", "pages": [
			{"text": "May bangka.", "scene": "river", "pictures": ["boat"],
				"image": "user://content/7b0c.png", "image_url": "/api/content/files/7b0c", "image_sha256": SHA_A},
			{"text": "Masama.", "scene": "river", "image": "user://content/../profile.json",
				"image_url": "/api/content/files/x", "image_sha256": SHA_A},
			{"text": "Ibang host.", "scene": "river", "image": "user://content/x.png",
				"image_url": "https://evil.example/x.png", "image_sha256": SHA_A}]},
		{"id": "", "title": "no id", "pages": [{"text": "x"}]},
		{"id": "tb-empty", "title": "no pages", "pages": []}],
		"watch": [
		{"id": "tv-good", "kind": "video", "title": "V", "file": "user://content/tv-good.ogv",
			"file_url": "/api/content/files/1e5d", "size_bytes": 1000, "sha256": SHA_B},
		{"id": "tv-bad", "kind": "video", "title": "V", "file": "user://profile.json",
			"file_url": "/api/content/files/1e5e", "sha256": SHA_B},
		{"id": "tv-nosha", "kind": "video", "title": "V", "file": "user://content/tv-nosha.ogv",
			"file_url": "/api/content/files/1e5f", "sha256": "not-a-hash"},
		{"id": "tv-song", "kind": "song", "title": "S", "lines": []}]}


func test_content_paths_are_safe() -> void:
	check(ContentPlan.safe_local("user://content/tv-p4r8s2dz.ogv"), "a video in user://content/ is safe")
	check(ContentPlan.safe_local("user://content/7b0c-11.PNG"), "a page picture is safe")
	for bad in ["user://content/../profile.json", "user://profile.json", "user://content/sub/x.png",
			"res://content/x.png", "user://content/x.gd", "user://content/.hidden.png",
			"user://content/a b.png", "user://content/x\\y.png", "user://content/"]:
		check(not ContentPlan.safe_local(bad), "unsafe path refused: %s" % bad)
	check(ContentPlan.safe_url("/api/content/files/1e5d"), "a server file path is fine")
	check(not ContentPlan.safe_url("https://evil.example/x") and not ContentPlan.safe_url("/api/../x"),
			"other hosts and climbing paths are refused")


func test_content_plan() -> void:
	var cleaned := ContentPlan.clean(_manifest())
	check(cleaned.books.size() == 1 and cleaned.books[0].id == "tb-one", "only well-formed books stay")
	var pages: Array = cleaned.books[0].pages
	check(pages[0].has("image") and not pages[1].has("image") and not pages[2].has("image"),
			"unsafe page pictures are dropped, the pages stay")
	check(cleaned.watch.size() == 1 and cleaned.watch[0].id == "tv-good", "only safe videos with a hash stay")
	var needed := ContentPlan.files(cleaned)
	check(needed.size() == 2, "a video and a page picture to fetch")
	var have := {"user://content/7b0c.png": SHA_A, "user://content/tv-good.ogv": SHA_A,
			"user://content/old.ogv": SHA_B}
	var fetch := ContentPlan.to_download(needed, have)
	check(fetch.size() == 1 and fetch[0].local == "user://content/tv-good.ogv", "a replaced video is fetched again")
	check(ContentPlan.to_delete(needed, have) == ["user://content/old.ogv"], "a removed item's file is deleted")
	check(ContentPlan.to_download(needed, {}).size() == 2, "nothing on the tablet: fetch both")


func test_file_sha256() -> void:
	var path := "user://test_sha.bin"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("abc")
	f.close()
	check(ContentPlan.file_sha256(path) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
			"SHA-256 of a saved file")
	check(ContentPlan.file_sha256("user://missing.bin") == "", "a missing file has no hash")
	DirAccess.remove_absolute(path)


## The team's Lottie animations play as vector shapes (D-022): every half-frame
## builds, and the start and end look like the design, in the hearts' colors.
func test_lottie_animations() -> void:
	var star := _lottie(AnimatedStar.FILE, {})
	check(star.duration() > 1.5 and star.duration() < 2.0, "the star plays for about 1.85 s")
	check(_every_frame_builds(star), "every half-frame of the star builds")
	check(star._build(0.0).is_empty(), "the star starts at nothing (it pops in)")
	check(_count(star._build(55.0), 1, Color(0, 0, 0, 0)) > 0, "the settled star has its gradient facets")
	star.free()
	var regain_kind: Dictionary = AnimatedHeart.KINDS.regain
	var regain := _lottie(regain_kind.file, regain_kind.colors)
	check(regain.duration() > 3.0 and regain.duration() < 3.5, "Regain Heart plays for 3.25 s, like the team's video")
	check(_every_frame_builds(regain), "every half-frame of Regain Heart builds")
	var start := regain._build(0.0)
	check(start.size() > 0 and _count(start, 0, Color("d9cfa2")) + _count(start, 2, Color("d9cfa2")) == start.size(),
			"Regain Heart starts as the pale empty heart (the one Broken Heart ends on)")
	check(_count(regain._build(77.5), 0, Palette.CORAL) > 0, "and ends as a coral heart")
	regain.free()
	var break_kind: Dictionary = AnimatedHeart.KINDS["break"]
	var broken := _lottie(break_kind.file, break_kind.colors)
	check(_every_frame_builds(broken), "every half-frame of Broken Heart builds")
	check(_count(broken._build(0.0), 0, Palette.CORAL) > 0, "Broken Heart starts as a coral heart")
	var empty := broken._build(44.5)
	check(empty.size() > 0 and _count(empty, 0, Palette.CORAL) == 0, "and ends with only the pale empty heart")
	broken.free()


## The star plays from its bake (tools/lottie-bake): every half-frame is there
## already, it was baked from today's star.json, and it matches what the player
## builds from the .json.
func test_star_bake() -> void:
	var path := AnimatedStar.FILE
	var bake := load(LottieBake.path_for(path)) as LottieBake
	check(bake != null, "the star has a bake (run tools/lottie-bake/bake.gd)")
	if bake == null:
		return
	check(bake.source_sha256 == FileAccess.get_sha256(path),
			"the bake matches star.json (bake it again after changing the star)")
	var live := _lottie(path, {})
	var half_frames := 0
	var f := live._ip
	while f < live._op:
		half_frames += 1
		f += 0.5
	check(bake.frames.size() == half_frames, "every half-frame is baked (%d)" % half_frames)
	for at in [0.0, 20.0, 27.5, 40.0, 55.0]:
		check(_same_commands(bake.frames.get(at, []), live._build(at)), "baked frame %s matches the live one" % at)
	var baked := LottiePlayer.new()
	baked.load_lottie(path)
	check(baked._data.get("baked", false) and is_equal_approx(baked.duration(), live.duration()),
			"the game loads the bake, with the star's timing")
	baked.free()
	live.free()


## Draw commands match: same points, triangles and colors; gradients by their colors.
func _same_commands(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		for k in ["t", "pts", "idx", "col", "uvs", "w", "round", "soft", "ring"]:
			if a[i].has(k) != b[i].has(k) or (a[i].has(k) and a[i][k] != b[i][k]):
				return false
		if a[i].has("tex") and (a[i].tex as GradientTexture1D).gradient.colors \
				!= (b[i].tex as GradientTexture1D).gradient.colors:
			return false
	return true


## A player that reads the .json itself (not a bake), to check how it builds frames.
func _lottie(path: String, colors: Dictionary) -> LottiePlayer:
	var p := LottiePlayer.new()
	p.load_lottie(path, colors, false)
	return p


func _every_frame_builds(p: LottiePlayer) -> bool:
	var f := p._ip
	while f < p._op:
		if typeof(p._build(f)) != TYPE_ARRAY:
			return false
		f += 0.5
	return true


## How many draw commands are of a kind (0 fill, 1 gradient, 2 stroke) and, if
## `color` isn't transparent, of that color.
func _count(commands: Array, kind: int, color: Color) -> int:
	var n := 0
	for c in commands:
		if int(c.t) == kind and (color.a == 0.0 or (c.col as Color).is_equal_approx(color)):
			n += 1
	return n


# --- D-033: the buddies Roco and Rina, and the talk language -------------------------------------

## Every menu line is in all three languages, with the same %s / %d slots as the English, no emoji.
func test_talk_table_is_complete() -> void:
	var talk = JSON.parse_string(FileAccess.get_file_as_string("res://content/talk.json"))
	check(typeof(talk) == TYPE_DICTIONARY, "talk.json loads")
	var en: Dictionary = talk.en
	var slots := RegEx.new()
	slots.compile("%[sd]")
	for lang in ["fil", "bis"]:
		var t: Dictionary = talk[lang]
		check(t.keys().size() == en.keys().size(), "%s has as many lines as English" % lang)
		for key in en:
			check(t.has(key) and str(t[key]).strip_edges() != "", "%s has '%s'" % [lang, key])
			var want := slots.search_all(str(en[key])).map(func(m): return m.get_string())
			var got := slots.search_all(str(t.get(key, ""))).map(func(m): return m.get_string())
			check(want == got, "%s '%s' keeps the slots %s" % [lang, key, want])
			check(not _has_emoji(str(t.get(key, ""))), "%s '%s' has no emoji" % [lang, key])


## The buddy's Filipino and Bisaya lines cover every state but the hints (those follow the lesson).
func test_buddy_lines_cover_every_state() -> void:
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/companion_lines.json"))
	for path in ["res://content/companion_lines.fil.json", "res://content/companion_lines.bis.json"]:
		var text := FileAccess.get_file_as_string(path)
		var d = JSON.parse_string(text)
		check(typeof(d) == TYPE_DICTIONARY, "%s loads" % path)
		check(not _has_emoji(text), "%s has no emoji" % path)
		for state in en:
			if state == "note" or str(state).begins_with("hint_"):
				continue
			check(d.has(state) and d[state] is Array and not d[state].is_empty(), "%s has '%s'" % [path, state])


## D-035: recorded clips are named as the voice lab names them, and a known line has its clip.
func test_recorded_voice_clips() -> void:
	var speech = load("res://scripts/autoload/speech.gd")
	check(speech.clip_key("roco", "en", "A heart came back!") == "07fff55d98f1723e", "clip names match the voice lab's")
	check(ResourceLoader.exists("res://assets/voice/07fff55d98f1723e.mp3"), "Roco's 'A heart came back!' is recorded")
	var bad := 0
	for f in DirAccess.get_files_at("res://assets/voice"):
		var key := f.get_basename()
		if f.ends_with(".mp3") and not (key.length() == 16 and key.is_valid_hex_number()):
			bad += 1
	check(bad == 0, "every clip is named by its key")


## Rina's inner ears are pink; Roco's keep the drawing's own color.
func test_rina_has_her_details() -> void:
	var pp: RacoonPuppet = load("res://scenes/companion/racoon_puppet.tscn").instantiate()
	pp._ensure_nodes()
	check(pp._ear_tint(0.5) == Color(1, 1, 1, 0.5), "Roco's inner ears: the drawing's color")
	pp.girl = true
	check(pp._ear_tint(0.5) == Color(RacoonPuppet.GIRL_EAR, 0.5), "Rina's inner ears: pink")
	check(pp._bow_n != null and pp._bow_n.get_parent() == pp._head_items, "Rina's bow sits with the head items")
	var front: Dictionary = RacoonPuppet._head_decal(-44.0, -82.0, 0.0, 1.0, 0.0)
	var back: Dictionary = RacoonPuppet._head_decal(-44.0, -82.0, PI, 1.0, 0.0)
	check(front.v > 0.3 and back.v < 0.0, "the bow faces you from the front and hides from behind")
	pp.free()




## The laptop crash (NFR-01): FitBox took turns between two scales forever. A story question's
## cards wrap, so they are shorter when wider: the smaller scale made them wide enough to need
## less height, the bigger scale then fit, and made them narrow and tall again.
func test_fit_box_settles() -> void:
	var box := Vector2(876, 442)
	var need_at := func(width: float) -> Vector2: return Vector2(190, 452 if width > 1000.0 else 564)
	var s := 1.0
	var state := {}
	var seen: Array[float] = []
	for i in 8:
		# A node keeps its scale as a float32, so feed it back the way the node does.
		s = Vector2(FitBox.next_scale(s, need_at.call(box.x / s), box, state), 0).x
		seen.append(s)
	check(seen[5] == seen[6] and seen[6] == seen[7], "the scale settles (got %s)" % [seen])
	check(need_at.call(box.x / s).y * s <= box.y + 0.5, "and the task fits")
	# First laid out too narrow (its words stacked), then at its real width: it grows back.
	state = {}
	s = FitBox.next_scale(1.0, Vector2(190, 1400), box, state)
	s = FitBox.next_scale(s, Vector2(190, 400), box, state)
	check(s == 1.0, "a first guess made at the wrong width doesn't stick (got %s)" % s)
	check(FitBox.next_scale(1.0, Vector2(300, 200), box, {}) == 1.0, "a task that fits stays full size")
	check(FitBox.next_scale(0.5, Vector2.ZERO, box, {}) == 0.5, "an empty task keeps its scale")
