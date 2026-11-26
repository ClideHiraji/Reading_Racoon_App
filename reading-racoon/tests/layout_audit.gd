extends SceneTree
## Layout audit for visual bugs (NFR-02), needs a window. Opens every screen and flags:
## - SPILL: a piece sticking out of the card, button or panel it sits in (checked in the box's
##   own frame, so tilted cards count too),
## - CUT: words cut off or shortened, or a word too long for its line (split in the middle),
## - OFFSCREEN / NOTCH: words or buttons past the screen edge, or under the notch or home bar,
## - OVERLAP: two texts drawn over each other (a dialog over its dimmed screen doesn't count),
## - SCROLL: tappable cards in a scroll list that swallow the touch (MOUSE_FILTER_STOP inside a
##   ScrollContainer), so dragging on them doesn't scroll.
## Saves <tag>_<screen>.png with the problems boxed, and <tag>_report.txt:
##   Godot.exe --path reading-racoon --resolution 450x800 -s res://tests/layout_audit.gd
##       -- --profile=audit --fresh --out=C:/some/folder --tag=phone --lang=fil [--safe-insets=58,29]

const TOL := 3.0
const COLORS := {"SPILL": Color.RED, "CUT": Color(1.0, 0.55, 0.0), "OFFSCREEN": Color.RED,
		"NOTCH": Color.RED, "OVERLAP": Color.MAGENTA}
const LESSON_ITEMS := ["pa1-01", "ph1-01", "vo3-07", "ph1-04", "pa2-09", "ph3-01", "ph2-09",
		"lc3-01", "lc5-07", "lc3-04"]
const MONDAY_MORNING := {"year": 2026, "month": 10, "day": 19, "weekday": 1, "hour": 7, "minute": 45, "second": 0}
const TUESDAY_EVENING := {"year": 2026, "month": 10, "day": 20, "weekday": 2, "hour": 18, "minute": 0, "second": 0}

var _out := "user://audit"
var _tag := "shot"
var _lang := "en"
var _lines := PackedStringArray()
var _counts := {}
var _gs: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
		elif a.begins_with("--lang="):
			_lang = a.trim_prefix("--lang=")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _open(path: String, frames := 8) -> void:
	change_scene_to_file(path)
	await _frames(frames)


func _run() -> void:
	_gs = root.get_node("GameState")
	root.get_node("Speech").volume = 0.0
	AudioServer.set_bus_mute(0, true)
	_gs.reset_progress()
	_gs.device = {"token": "", "student_name": "Ana", "student_id": 0}
	_gs.buddy = {"who": "", "lang": _lang}
	await _open("res://scenes/main.tscn")
	await _audit("start")
	await _open("res://scenes/login/login.tscn")
	await _audit("login")
	await _open("res://scenes/buddy/choose_buddy.tscn")
	await _audit("buddy")
	_gs.buddy = {"who": "rina", "lang": _lang}
	_gs.use_buddy_voice()
	root.get_node("Speech").volume = 0.0

	# A child partway through world 1, with some of everything collected (as section_shots.gd).
	_gs.assessments = {"pre": {"total": 20}}
	_gs.wallet = {"xp": 140, "coins": 120}
	_gs.model.highest_unlocked = 3
	_gs.path.world(1).done = 2
	_gs.access.schedule = AccessPolicy.DEFAULTS.duplicate()
	_gs._debug_now = TUESDAY_EVENING
	_gs.usage = {"date": _gs.today(), "minutes": 0.0, "free_minutes": 0.0}
	for g in ["adventure", "adventure", "adventure", "books", "games", "days", "watch"]:
		_gs.collection.earn(g, _gs.today())
	_gs.learn_words(PracticePool.picture_words(_gs.bank, 3).slice(0, 9), "lesson")
	_gs.collection.complete_goal("story", _gs.today())
	_gs.collection.mark_day(_gs.today())

	await _open("res://scenes/hub/hub.tscn")
	await _audit("home")
	Kit.reward(current_scene, _gs.talk("reward_sticker_time"),
			{"coins": 13, "stickers": ["speaker", "star"], "goals_done": true}, func(): pass)
	await _audit("reward_card")
	await _open("res://scenes/path/learning_path.tscn")
	await _audit("map")

	_gs._debug_now = MONDAY_MORNING
	for id in LESSON_ITEMS + _longest_items():
		await _lesson(id)
	_gs.last_summary = {"level": 1, "correct": 7, "total": 8, "accuracy": 0.875, "stars": 2,
			"xp": 70, "coins": 30, "level_up": false, "ended_early": false, "second_try": 1,
			"rewards": {"coins": 10, "stickers": [], "items": []},
			"results": [{"correct": true}, {"correct": true}, {"correct": false}, {"correct": true},
				{"correct": true}, {"correct": true}, {"correct": true}, {"correct": true}]}
	await _open("res://scenes/lesson/lesson_complete.tscn")
	await _audit("lesson_complete")

	_gs._debug_now = TUESDAY_EVENING
	await _open("res://scenes/practice/practice.tscn")
	await _audit("practice")
	_gs.practice_game = "memory_match"
	await _open("res://scenes/practice/memory_match.tscn")
	await _audit("memory_match")
	await _open("res://scenes/practice/rhyme_pop.tscn", 90)
	await _audit("rhyme_pop")
	await _open("res://scenes/practice/word_catch.tscn", 80)
	await _audit("word_catch")
	for game in ["syllable_train", "spin_words", "story_shuffle"]:
		_gs.practice_game = game
		await _open("res://scenes/practice/practice_round.tscn")
		await _audit(game)

	await _open("res://scenes/library/library.tscn")
	await _audit("library")
	for book in ["racoon-boat", "bangka-ni-lolo", "pagong-matsing"]:
		_gs.open_book = book
		await _open("res://scenes/library/reader.tscn")
		var reader := current_scene
		reader._reading = false
		reader._text.stop()
		reader._page = _longest_page(reader._pages())
		reader._show_page()
		await _audit("reader_" + book)
		reader._questions()
		await _audit("questions_" + book)

	await _open("res://scenes/watch/watch.tscn")
	await _audit("watch")
	for media in ["abc-chant", "read-bangka"]:
		_gs.open_media = media
		await _open("res://scenes/watch/player.tscn", 30)
		await _audit("player_" + media)

	for screen in ["stickers", "words", "today"]:
		await _open("res://scenes/collection/%s.tscn" % screen)
		await _audit(screen)

	await _open("res://scenes/shop/shop.tscn")
	var shop := current_scene
	for tab in shop.get_node("%Tabs").get_children():
		shop._on_tab(tab.get_meta("slot"))
		await _audit("closet_" + str(tab.get_meta("slot")))

	_gs._debug_now = {"year": 2026, "month": 10, "day": 20, "weekday": 2, "hour": 22, "minute": 0, "second": 0}
	await _open("res://scenes/lock/lock_screen.tscn")
	await _audit("lock_night")
	_gs._debug_now = {"year": 2026, "month": 10, "day": 24, "weekday": 6, "hour": 10, "minute": 0, "second": 0}
	await _open("res://scenes/lock/lock_screen.tscn")
	await _audit("lock_weekend")
	_finish()


## A lesson item as the child sees it: its story page, the task, the second try with Racoon's
## hint, then the answer (as task_shots.gd), and the "Stop now?" card.
func _lesson(id: String) -> void:
	var item := {}
	for it in _gs.bank.items:
		if it.id == id:
			item = it
	if item.is_empty():
		_lines.append("%s\tMISSING\tno item %s" % [id, id])
		return
	_gs.start_lesson(item.level, 0, false)
	await _frames(6)
	var lesson := current_scene
	if lesson._task:
		lesson._task.queue_free()
		lesson._task = null
	lesson.session.current = item
	lesson._item = item
	lesson._shown_passage = ""
	if item.has("passage"):
		lesson._show_story(item.passage)
		await _audit(id + "_story")
		lesson._task.done.emit()
	else:
		lesson._start_task()
	await _audit(id)
	var wrong := "__wrong__"
	for c in item.get("choices", []):
		if c is Dictionary and str(c.get("id", "")) != str(item.answer):
			wrong = str(c.id)
			break
	lesson._task.answered.emit(wrong, 800)
	await _audit(id + "_try_again")
	if item.task_type == "tap_choice" and is_instance_valid(lesson._task):
		lesson._task.answered.emit(wrong, 800)
		await _audit(id + "_answer")
	if id == LESSON_ITEMS[0]:
		lesson._on_close()
		await _audit("stop_dialog")


## The items with the longest prompt and the longest answer words, in this language's levels.
func _longest_items() -> Array:
	var by_prompt := ["", 0]
	var by_choice := ["", 0]
	for it in _gs.bank.items:
		if str(it.get("language", "")).substr(0, 3) != _lang.substr(0, 3) and _lang != "en":
			continue
		var p := str(it.get("prompt", "")).length()
		if p > by_prompt[1]:
			by_prompt = [it.id, p]
		for c in it.get("choices", []):
			var l := str(c.get("label", "")).length() if c is Dictionary else str(c).length()
			if l > by_choice[1]:
				by_choice = [it.id, l]
	var out := []
	for id in [by_prompt[0], by_choice[0]]:
		if id != "" and not id in LESSON_ITEMS and not id in out:
			out.append(id)
	return out


func _longest_page(pages: Array) -> int:
	var best := 0
	for i in pages.size():
		if str(pages[i].get("text", "")).length() > str(pages[best].get("text", "")).length():
			best = i
	return best


# --- The checks ---------------------------------------------------------------------------------

func _audit(screen: String) -> void:
	await _frames(40)
	var view := root.get_visible_rect()
	var ins: Dictionary = root.get_node("Screen").insets()
	var safe := Rect2(view.position + Vector2(0, ins.top), view.size - Vector2(0, ins.top + ins.bottom))
	var found: Array = []
	var texts: Array = []
	var st := {"view": view, "safe": safe, "overlays": 0, "scroll_block": 0}
	_walk(current_scene, found, texts, st, {})
	_overlaps(texts, found)
	var img := root.get_texture().get_image()
	var k := Vector2(img.get_size()) / view.size
	for f in found:
		_frame(img, Rect2((f.rect.position - view.position) * k, f.rect.size * k), COLORS.get(f.kind, Color.RED))
	img.save_png("%s/%s_%s.png" % [_out, _tag, screen])
	if st.scroll_block > 0:
		found.append({"kind": "SCROLL", "rect": Rect2(), "path": "",
				"what": "%d tappable cards or words in a scroll list take the touch: dragging on them won't scroll" % st.scroll_block})
	for f in found:
		_counts[f.kind] = _counts.get(f.kind, 0) + 1
		_lines.append("%s\t%s\t%s\t%s" % [screen, f.kind, f.what, f.path])
	print("%s: %d" % [screen, found.size()])


func _walk(n: Node, found: Array, texts: Array, st: Dictionary, spilled: Dictionary) -> void:
	for c in n.get_children():
		if not c is Control:
			continue   # Node2D drawings (Racoon's puppet, confetti) aren't layout
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or _alpha(ctl) < 0.1:
			continue
		var r := ctl.get_global_rect()
		var view: Rect2 = st.view
		# A full-screen dim or panel: what's drawn after it is a layer above (a dialog).
		if (ctl is ColorRect or ctl is Panel) and r.get_area() >= view.get_area() * 0.9:
			st.overlays += 1
		var sub := spilled
		var box := _box_of(ctl, view)
		if box and not spilled.has(box) and not ctl.top_level and not ctl is Raccoon and not box.clip_contents \
				and ctl.size.x > 0 and ctl.size.y > 0:
			var inner := _rect_in(ctl, Rect2(Vector2.ZERO, ctl.size), box)
			var frame := Rect2(Vector2.ZERO, box.size)
			if not frame.grow(TOL).encloses(inner):
				found.append(_issue("SPILL", ctl, r, "%s sticks out of its %s (%s)" % [_name(ctl), _name(box), _by(frame, inner)]))
				sub = spilled.duplicate()
				sub[box] = true
		var scroll := _scroll_of(ctl)
		if ctl is Label and (ctl as Label).text.strip_edges() != "":
			_check_label(ctl, r, found, st, scroll)
			var tr := _text_rect(ctl)
			if scroll:
				tr = tr.intersection(scroll.get_global_rect())
			if tr.get_area() > 0:
				texts.append({"node": ctl, "rect": tr, "layer": st.overlays})
		elif ctl is Button and (ctl as Button).text.strip_edges() != "":
			_check_button(ctl, r, found, st, scroll)
		if (ctl is BaseButton or ctl is Label) and scroll and ctl.mouse_filter == Control.MOUSE_FILTER_STOP:
			st.scroll_block += 1
		_walk(ctl, found, texts, st, sub)


func _check_label(l: Label, r: Rect2, found: Array, st: Dictionary, scroll: Control) -> void:
	var font := l.get_theme_font("font")
	var px := l.get_theme_font_size("font_size")
	var sb := l.get_theme_stylebox("normal")
	var inner_w := l.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb else 0.0)
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var w := font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		if w > inner_w + 1.0:
			found.append(_issue("CUT", l, r, "\"%s\" needs %d px, has %d" % [_short(l.text), w, inner_w]))
	else:
		for word in l.text.replace("\n", " ").split(" ", false):
			var ww := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			if ww > inner_w + 1.0:
				found.append(_issue("CUT", l, r, "the word \"%s\" is wider than its line (%d px > %d): it gets split" % [word, ww, inner_w]))
				break
	if l.max_lines_visible >= 0 and l.get_line_count() > l.max_lines_visible:
		found.append(_issue("CUT", l, r, "\"%s\" shows %d of %d lines" % [_short(l.text), l.max_lines_visible, l.get_line_count()]))
	var clip := _clipper(l)
	if clip and not Rect2(Vector2.ZERO, clip.size).grow(TOL).encloses(_rect_in(l, _local_text_rect(l), clip)):
		found.append(_issue("CUT", l, r, "\"%s\" is cut off by its %s" % [_short(l.text), _name(clip)]))
	if not scroll:
		_check_edges(_text_rect(l), "\"%s\"" % _short(l.text), l, found, st)


func _check_button(b: Button, r: Rect2, found: Array, st: Dictionary, scroll: Control) -> void:
	if b.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var font := b.get_theme_font("font")
		var px := b.get_theme_font_size("font_size")
		var sb := b.get_theme_stylebox("normal")
		var avail := b.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb else 0.0)
		# An icon beside the text takes width; one above or below it (the Home tiles) doesn't.
		if b.icon and not b.expand_icon and b.vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER \
				and b.icon_alignment != HORIZONTAL_ALIGNMENT_CENTER:
			var ipx = b.get("icon_px")
			avail -= (float(ipx) if ipx != null else b.icon.get_width()) + b.get_theme_constant("h_separation")
		var w := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		if w > avail + 1.0:
			found.append(_issue("CUT", b, r, "button \"%s\" needs %d px, has %d" % [_short(b.text), w, avail]))
	if not scroll:
		_check_edges(r, "button \"%s\"" % _short(b.text), b, found, st)


func _check_edges(tr: Rect2, what: String, node: Control, found: Array, st: Dictionary) -> void:
	var view: Rect2 = st.view
	var safe: Rect2 = st.safe
	if not view.grow(TOL).encloses(tr):
		found.append(_issue("OFFSCREEN", node, tr, "%s runs off the screen (%s)" % [what, _by(view, tr)]))
	elif safe != view and (tr.position.y < safe.position.y - 1.0 or tr.end.y > safe.end.y + 1.0):
		found.append(_issue("NOTCH", node, tr, "%s is under the notch or home bar" % what))


func _overlaps(texts: Array, found: Array) -> void:
	for i in texts.size():
		for j in range(i + 1, texts.size()):
			var a: Dictionary = texts[i]
			var b: Dictionary = texts[j]
			if a.layer != b.layer or a.node.is_ancestor_of(b.node) or b.node.is_ancestor_of(a.node):
				continue
			var x: Rect2 = a.rect.intersection(b.rect)
			if x.get_area() > 40.0 and x.get_area() > 0.25 * minf(a.rect.get_area(), b.rect.get_area()) \
					and not _hidden_under(a.node, b.node, x):
				found.append(_issue("OVERLAP", b.node, x, "\"%s\" is drawn over \"%s\"" % [_short(b.node.text), _short(a.node.text)]))


## True when `top` (drawn later) sits in a card or panel of its own that covers this part of
## `under`: the lower text is hidden behind it (a badge on an avatar, the answer sheet over
## Racoon's bubble), not printed over it.
func _hidden_under(under: Control, top: Control, part: Rect2) -> bool:
	var p := top.get_parent()
	while p != null and p != current_scene and not p.is_ancestor_of(under):
		if (p is PanelContainer or p is Panel) and (p as Control).get_global_rect().grow(1.0).encloses(part):
			return true
		p = p.get_parent()
	return false


# --- Helpers ------------------------------------------------------------------------------------

## The card, button or panel a control sits in (not a page-sized background, and nothing past a
## scroll list, whose content is meant to be taller than it).
func _box_of(ctl: Control, view: Rect2) -> Control:
	var p := ctl.get_parent()
	while p != null and p != current_scene.get_parent():
		if p is ScrollContainer:
			return null
		if (p is PanelContainer or p is Panel or p is BaseButton) and (p as Control).get_global_rect().get_area() < view.get_area() * 0.9:
			return p
		p = p.get_parent()
	return null


func _scroll_of(ctl: Control) -> Control:
	var p := ctl.get_parent()
	while p != null and p != current_scene.get_parent():
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


func _clipper(ctl: Control) -> Control:
	var p := ctl.get_parent()
	while p != null and p != current_scene.get_parent():
		if p is ScrollContainer:
			return null
		if p is Control and (p as Control).clip_contents:
			return p
		p = p.get_parent()
	return null


## A rect in `ctl`'s own coordinates, seen in `frame`'s coordinates (rotation and scale included).
func _rect_in(ctl: Control, local: Rect2, frame: Control) -> Rect2:
	return (frame.get_global_transform().affine_inverse() * ctl.get_global_transform()) * local


func _local_text_rect(l: Label) -> Rect2:
	var font := l.get_theme_font("font")
	var px := l.get_theme_font_size("font_size")
	var lines := maxi(l.get_visible_line_count(), 1)
	var h := minf(lines * (font.get_height(px) + l.get_theme_constant("line_spacing")), l.size.y)
	var w := l.size.x
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		w = font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := 0.0
	if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x = (l.size.x - w) / 2.0
	elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = l.size.x - w
	var y := 0.0
	if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y = (l.size.y - h) / 2.0
	elif l.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		y = l.size.y - h
	return Rect2(x, y, w, h)


func _text_rect(l: Label) -> Rect2:
	return l.get_global_transform() * _local_text_rect(l)


func _alpha(ctl: CanvasItem) -> float:
	var a := ctl.self_modulate.a
	var p: Node = ctl
	while p is CanvasItem:
		a *= (p as CanvasItem).modulate.a
		p = p.get_parent()
	return a


func _by(frame: Rect2, r: Rect2) -> String:
	var parts := PackedStringArray()
	if r.position.x < frame.position.x - TOL:
		parts.append("left %d" % (frame.position.x - r.position.x))
	if r.end.x > frame.end.x + TOL:
		parts.append("right %d" % (r.end.x - frame.end.x))
	if r.position.y < frame.position.y - TOL:
		parts.append("top %d" % (frame.position.y - r.position.y))
	if r.end.y > frame.end.y + TOL:
		parts.append("bottom %d" % (r.end.y - frame.end.y))
	return ", ".join(parts) + " px"


func _name(ctl: Control) -> String:
	if ctl is Label:
		return "\"%s\"" % _short(ctl.text)
	if ctl is Button and (ctl as Button).text != "":
		return "button \"%s\"" % _short(ctl.text)
	return "%s %s" % [ctl.get_class(), ctl.name]


func _short(t: String) -> String:
	t = t.replace("\n", " ")
	return t if t.length() <= 40 else t.substr(0, 38) + "…"


func _issue(kind: String, node: Control, rect: Rect2, what: String) -> Dictionary:
	return {"kind": kind, "rect": rect, "what": what, "path": str(current_scene.get_path_to(node))}


func _frame(img: Image, r: Rect2, col: Color) -> void:
	var full := Rect2i(Vector2i.ZERO, img.get_size())
	var rr := Rect2i(r.position.floor(), r.size.ceil())
	for edge in [Rect2i(rr.position.x, rr.position.y, rr.size.x, 3), Rect2i(rr.position.x, rr.end.y - 3, rr.size.x, 3),
			Rect2i(rr.position.x, rr.position.y, 3, rr.size.y), Rect2i(rr.end.x - 3, rr.position.y, 3, rr.size.y)]:
		var e: Rect2i = edge.intersection(full)
		if e.size.x > 0 and e.size.y > 0:
			img.fill_rect(e, col)


func _finish() -> void:
	var head := PackedStringArray(["%s: %s" % [_tag, JSON.stringify(_counts)]])
	var f := FileAccess.open("%s/%s_report.txt" % [_out, _tag], FileAccess.WRITE)
	f.store_string("\n".join(head + _lines) + "\n")
	f.close()
	print(head[0])
	quit()
