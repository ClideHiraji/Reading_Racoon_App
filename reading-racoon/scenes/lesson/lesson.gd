extends Control
## One lesson (D-007 layout, D-009 storybook look): close, progress bar and hearts
## on top, the prompt on a paper card, the task in the middle, and the raccoon
## standing on the world's paper-cut landscape. The rules live in LessonSession
## (scripts/core); this only shows them.
## FR-13 hearts and Racoon's Rescue, FR-14 hints, FR-20 read-aloud.
## D-021: a wrong first try greys out that choice and Racoon gives the question's
## hint (HintText); a wrong second try shows the answer and why on a paper sheet.
## No CONTINUE taps: Racoon says a short line and the lesson moves on by itself.
## Stopping halfway keeps nothing.
## D-024: Racoon acts out the lesson's moments (FR-14): he greets you, reads the question
## along with you, thinks over a hint, points at the answer, cheers a level up, and nudges
## after a long quiet spell. He stays calm while you read.

## One scene per task_type in content/levels*.json.
const TASKS := {
	"tap_choice": preload("res://scenes/tasks/tap_choice_task.tscn"),
	"drag_letter": preload("res://scenes/tasks/drag_letter_task.tscn"),
	"order_tiles": preload("res://scenes/tasks/order_tiles_task.tscn"),
	"spin_words": preload("res://scenes/tasks/spin_words_task.tscn"),
}
const RESCUE_PAPER := Color("dcebf0")
## How long each kind of feedback stays before the lesson moves on (seconds; it
## also waits for Racoon to finish talking).
const PAUSE_TEST := 0.7
const PAUSE_RIGHT := 1.1
const PAUSE_BIG := 2.0
const PAUSE_SPEECH_CAP := 8.0
const HEART_PX := 46.0
const HEART_W := HEART_PX * 0.81   # the drawn heart's width in its slot
const SIDE_W := 300.0   # Racoon's column on a laptop (D-023)
const NUDGE_AFTER := 20.0   # seconds on one question before Racoon points at it (D-024)

## A LessonSession, or an AssessmentSession for the pre/post-test (same interface).
var session: RefCounted
var _testing := false
var _item := {}
var _task: Control
var _outcome := {}
var _shown_passage := ""
var _overlay_primary: Callable
var _overlay_secondary: Callable
var _waiting := false     # feedback is showing; the lesson moves on by itself
var _wait_id := 0
var _hearts_shown := -1   # hearts on screen, to see one come back
var _task_id := 0         # a new question, or an answer, cancels Racoon's waiting moves

@onready var raccoon: Raccoon = %Raccoon
@onready var bubble: SpeechBubble = %Bubble
@onready var sheet: PanelContainer = %Sheet


func _ready() -> void:
	session = GameState.new_session()
	# Work the hearts and the lesson-complete star out while the lesson runs, so
	# they play smoothly the first time on slow phones (D-022).
	AnimatedHeart.warm()
	AnimatedStar.warm()
	_fit_shape()
	var world := SkillCatalog.world(GameState.lesson_world)
	%Scenery.scene = world.scene
	%CloseButton.pressed.connect(_on_close)
	%SpeakButton.pressed.connect(_speak)
	%StoryButton.pressed.connect(_peek_story)
	%ContinueButton.hide()
	%OverlayPrimary.pressed.connect(func(): _close_overlay(_overlay_primary))
	%OverlaySecondary.pressed.connect(func(): _close_overlay(_overlay_secondary))
	_update_hearts(HeartSystem.MAX_HEARTS)
	_testing = session is AssessmentSession
	if _testing:
		# Reading Adventure (FR-02/FR-10): no hearts, no right/wrong, just do your best.
		%Hearts.hide()
		_say(GameState.talk("lesson_test_hello"), "happy", "greet")
	else:
		_say(GameState.line("intro"), "happy", "greet")
	_next()


## Laptops (D-023): Racoon and his bubble stand in a column on the left with the
## prompt and the task beside them, and the answer sheet covers only the task's
## side so Racoon stays in view. Phones keep the portrait stack. Both keep clear
## of a notch.
func _fit_shape() -> void:
	var margin: MarginContainer = $Margin
	if Kit.landscape():
		var col: VBoxContainer = $Margin/VBox
		col.add_theme_constant_override("separation", 16)
		var body := HBoxContainer.new()
		body.name = "Body"
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 24)
		col.add_child(body)
		var side := VBoxContainer.new()
		side.name = "Side"
		side.custom_minimum_size = Vector2(SIDE_W, 0)
		side.alignment = BoxContainer.ALIGNMENT_END
		side.add_theme_constant_override("separation", 30)
		body.add_child(side)
		var main := VBoxContainer.new()
		main.name = "Main"
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.add_theme_constant_override("separation", 16)
		body.add_child(main)
		for n: Control in [%RescueBanner, $Margin/VBox/PromptCard, %TaskHolder]:
			n.reparent(main, false)
		bubble.tail = "down"
		bubble.tail_x = 110.0
		bubble.size_flags_vertical = Control.SIZE_SHRINK_END
		bubble.reparent(side, false)
		raccoon.custom_minimum_size = Vector2(200, 200)
		raccoon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		raccoon.reparent(side, false)
		$Margin/VBox/CompanionRow.queue_free()
		for edge in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + edge, 40)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 10)
		%Scenery.offset_top = -190
		sheet.offset_left = 40 + SIDE_W + 12
		sheet.offset_top = -200   # just the answer and why, the choices stay in view
	Kit.fit_safe(margin)


func _next() -> void:
	Speech.new_question()   # what he was saying about the last one stops here (D-032)
	sheet.hide()
	_item = session.next_item()
	if _item.is_empty():
		push_error("Lesson: no content for level %d" % session.level)
		_finish()
		return
	if _task:
		_task.queue_free()
		_task = null
	if not _testing and not session.in_rescue():
		_update_hearts(session.hearts.hearts)
	_update_progress()
	%SpeakButton.visible = Speech.available(_lang())
	%StoryButton.visible = _item.has("passage")
	var pid: String = _item.get("passage", "")
	if pid != "" and pid != _shown_passage:
		_show_story(pid)
	else:
		_start_task()


func _start_task() -> void:
	if _task:
		_task.queue_free()
	_task = TASKS.get(_item.task_type, TASKS.tap_choice).instantiate()
	%TaskHolder.add_child(_task)
	_task.setup(_item)
	_task.answered.connect(_on_answered)
	%Prompt.text = _item.prompt
	%StoryButton.visible = _item.has("passage")
	_speak()
	_task_id += 1
	_read_prompt(_task_id)
	_nudge_later(_task_id)


## Story first: the child reads (or listens to) the passage, then answers.
func _show_story(pid: String) -> void:
	var p: Dictionary = session.bank.passage(pid)
	_shown_passage = pid
	var page := StoryPage.new()
	page.setup(p)
	page.done.connect(_after_story)
	_task = page
	%TaskHolder.add_child(page)
	%StoryButton.visible = false
	%Prompt.text = p.get("title", "Story")   # the page reads itself aloud (D-022)


## The story's done: its reading stops (D-032) and its question starts.
func _after_story() -> void:
	Speech.new_question()
	_start_task()


func _peek_story() -> void:
	var p: Dictionary = session.bank.passage(_item.get("passage", ""))
	Speech.say(p.get("text", ""), p.get("language", "en"))
	_open_overlay("stories", Palette.BLUE, p.get("title", ""), p.get("text", ""), "OK", func(): pass)


func _speak() -> void:
	Speech.say(_item.get("tts_text", _item.get("prompt", "")), _lang())


func _lang() -> String:
	return _item.get("language", "en")


func _on_answered(answer: String, ms: int) -> void:
	var was_rescue: bool = session.in_rescue()
	_task_id += 1
	# Nothing is saved until the lesson ends (D-021): GameState.finish_lesson().
	_outcome = session.submit(answer, ms)
	var right := str(_outcome.answer)
	if _outcome.get("neutral", false):
		# Tests never reveal right or wrong: a word from Racoon, then the next one.
		_update_progress()
		Sfx.play("pop")
		_say(GameState.line("adventure_next"), "happy")
		_advance_after(PAUSE_TEST)
		return
	if _outcome.next == "retry":
		_try_again(answer)
		return
	_task.show_result(answer, right)
	Sfx.play("correct" if _outcome.correct else "wrong")
	_update_hearts(_outcome.hearts)
	_update_progress()

	if not _outcome.correct:
		# Out of tries (or out of hearts): the answer and why, then on we go.
		if _outcome.has("rescue_full"):
			_end_rescue_look()
		_show_answer(right)
		return
	var line := GameState.line("rescue_correct" if was_rescue else (
			"correct" if _outcome.try == 1 else "correct_retry"))
	var mood: String = _outcome.mood
	var moment := ""
	var pause := PAUSE_RIGHT
	if _outcome.mastered_now and not _outcome.level_up:
		line = "You won the %s crown!" % SkillCatalog.NAMES[_outcome.skill]
		mood = "celebrate"
		pause = PAUSE_BIG
	if _outcome.level_up:
		line = GameState.line("level_up")
		moment = "level_up"
		Sfx.play("fanfare")
		pause = PAUSE_BIG
	if _outcome.has("rescue_full"):
		_end_rescue_look()
		line = GameState.line("rescue_full" if _outcome.rescue_full else "rescue_partial")
		mood = "celebrate" if _outcome.rescue_full else "encourage"
		moment = "rescue_won" if _outcome.rescue_full else ""
		pause = PAUSE_BIG
	_say(line, mood, moment)
	Speech.say(line)
	_advance_after(pause)


## A wrong first try: no answer yet. The choice greys out, a heart goes, and
## Racoon gives this question's hint so the child can work it out (D-021, FR-14).
func _try_again(answer: String) -> void:
	Sfx.play("wrong")
	_update_hearts(_outcome.hearts)
	var hint := HintText.hint(_item)
	_say(hint, "thinking", "hint", %Prompt.get_global_rect().get_center())
	Speech.say(hint, _lang())
	if _task.has_method("try_again"):
		_task.try_again(answer)
	else:
		_start_task()


## Moves on by itself after `seconds` and after Racoon stops talking (D-021).
## It waits while a card (the stop dialog, a story) is open. Calling
## _on_continue() first, as the tests do, cancels it.
func _advance_after(seconds: float) -> void:
	_waiting = true
	_wait_id += 1
	var id := _wait_id
	await get_tree().create_timer(seconds).timeout
	var cap := PAUSE_SPEECH_CAP
	while is_inside_tree() and id == _wait_id and (%Overlay.visible or (Speech.speaking() and cap > 0.0)):
		await get_tree().create_timer(0.15).timeout
		cap -= 0.15
	if is_inside_tree() and id == _wait_id and _waiting:
		_on_continue()


func _on_continue() -> void:
	if not _waiting:
		return
	_waiting = false
	_wait_id += 1
	match _outcome.get("next", "continue"):
		"rescue_start":
			_start_rescue_look()
		"done":
			_finish()
		"end_session":
			sheet.hide()
			_say(GameState.line("session_end"), "sleepy")
			_open_overlay("night", Palette.PLUM_LIGHT, GameState.talk("lets_rest"), GameState.line("session_end"), "OK",
					_finish)
		_:
			_next()


# --- Racoon's Rescue (Heart Recovery, D-004) ---------------------------------------

func _start_rescue_look() -> void:
	sheet.hide()
	%Bg.material.set_shader_parameter("paper", RESCUE_PAPER)
	%RescueBanner.show()
	_update_rescue_label()
	var text := GameState.line("rescue_start")
	_say(text, "encourage", "rescue")
	Speech.say(text)
	_open_overlay("heart_plus", Palette.CORAL, GameState.talk("rescue_title"), GameState.talk("rescue_how"), "OK!", _next)


func _end_rescue_look() -> void:
	%Bg.material.set_shader_parameter("paper", Palette.PAPER)
	%RescueBanner.hide()


func _update_rescue_label() -> void:
	%RescueLabel.text = GameState.talk("rescue_label", [session.rescue.get("answered", 0), HeartSystem.RECOVERY_ITEMS])


# --- Answer sheet, hearts, progress -----------------------------------------------------

## A heart slot the size of the old heart icon, with a heart from the team's
## animations drawn in its middle: animated when it changes, a still end frame
## otherwise, so every heart in the row has the same shape (D-022).
func _heart_slot(heart: AnimatedHeart, slot_name: String) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(HEART_PX, HEART_PX)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.name = slot_name
	slot.add_child(heart)
	slot.resized.connect(func(): heart.center_on(slot.size * 0.5))
	return slot


## The paper sheet after a wrong second try: the answer, and why (HintText.explain),
## read aloud. It has no button; the lesson moves on once Racoon has explained.
func _show_answer(right: String) -> void:
	var shown: String = _task.answer_text(right) if _task.has_method("answer_text") else _choice_label(right)
	var why := HintText.explain(_item)
	var color := Palette.ALMOST
	var sb: StyleBoxFlat = sheet.get_theme_stylebox("panel").duplicate()
	sb.bg_color = Palette.pale(color, 0.78)
	sheet.add_theme_stylebox_override("panel", sb)
	var disc: StyleBoxFlat = %SheetDisc.get_theme_stylebox("panel").duplicate()
	disc.bg_color = color
	%SheetDisc.add_theme_stylebox_override("panel", disc)
	%SheetIcon.texture = Icons.tex("bulb")
	%SheetTitle.text = "The answer is: %s" % shown
	%SheetTitle.add_theme_color_override("font_color",
			Palette.readable(Palette.deep(color), sb.bg_color))
	%SheetDetail.text = why
	%SheetDetail.visible = true
	_say(GameState.line("incorrect"), "encourage", "answer", _answer_spot(right))
	Speech.say(why, _lang())
	sheet.show()
	_advance_after(clampf(1.2 + why.split(" ").size() * 0.32, 2.5, 6.0))
	await get_tree().process_frame
	var target := size.y - sheet.size.y
	sheet.position.y = size.y
	create_tween().tween_property(sheet, "position:y", target, 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _choice_label(id: String) -> String:
	for c in _item.get("choices", []):
		if str(c.id) == id:
			return c.get("label", id)
	return id


## A heart that comes back (a right answer, or the end of Racoon's Rescue) fills
## in with the Regain Heart animation; a heart that is lost (a wrong try) cracks
## and falls away with Broken Heart, the rightmost first (FR-13, D-021). The rest
## are those animations' still end frames, full or empty, so they all match.
func _update_hearts(count: int) -> void:
	var box: HBoxContainer = %Hearts
	for c in box.get_children():
		box.remove_child(c)   # out now, so the new slots keep their names
		c.queue_free()
	var from := _hearts_shown if _hearts_shown >= 0 else count
	for i in HeartSystem.MAX_HEARTS:
		if i >= from and i < count:
			box.add_child(_heart_slot(AnimatedHeart.make(HEART_W, (i - from) * 0.15, "regain"), "RegainedHeart"))
		elif i >= count and i < from:
			box.add_child(_heart_slot(AnimatedHeart.make(HEART_W, (from - 1 - i) * 0.15, "break"), "BrokenHeart"))
		else:
			box.add_child(_heart_slot(AnimatedHeart.still(HEART_W, i < count), "Heart"))
	_hearts_shown = count
	if session.in_rescue():
		_update_rescue_label()


func _update_progress() -> void:
	create_tween().tween_property(%Progress, "value", session.progress(), 0.3)


## Racoon says a line: a mood, or one of his lesson moments (D-024) with a spot on screen to
## look or point at, and his mouth moves while the bubble shows it.
func _say(text: String, mood: String, moment := "", spot := Vector2.INF) -> void:
	if moment != "":
		raccoon.mood = mood
		raccoon.moment(moment, spot)
	else:
		raccoon.set_mood(mood)
	raccoon.talk(clampf(text.split(" ", false).size() * 0.3, 0.8, 4.0))
	bubble.say(text)


## Racoon reads the question along with you: his eyes follow the words (D-024, calm, no
## words of his own). He waits for a move he's in the middle of, like his hello.
func _read_prompt(id: int) -> void:
	await get_tree().process_frame   # the label has its new size
	var waited := 0.0
	while is_inside_tree() and id == _task_id and raccoon.busy and waited < 4.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if not is_inside_tree() or id != _task_id or raccoon.busy:
		return
	var label: Label = %Prompt
	var r := label.get_global_rect()
	var px := label.get_theme_font_size("font_size")
	var w := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	w = minf(w * label.get_global_transform().get_scale().x, r.size.x)
	var y := r.get_center().y
	raccoon.read_along(Vector2(r.position.x, y), Vector2(r.position.x + w, y), label.text.split(" ", false).size())


## A long quiet spell on one question: Racoon points at it, once, without a word (D-024).
func _nudge_later(id: int) -> void:
	await get_tree().create_timer(NUDGE_AFTER).timeout
	if is_inside_tree() and id == _task_id and not %Overlay.visible and not sheet.visible and not raccoon.busy:
		raccoon.moment("nudge", %TaskHolder.get_global_rect().get_center())


## Where the right answer is on screen, for Racoon to point at: its card or letter, else the task.
func _answer_spot(right: String) -> Vector2:
	for key in ["_cards", "_tiles"]:
		var found = _task.get(key) if _task else null
		if found is Dictionary and found.get(right) is Control:
			return (found[right] as Control).get_global_rect().get_center()
	return %TaskHolder.get_global_rect().get_center()


# --- Leaving -------------------------------------------------------------------------

## Stopping halfway keeps nothing (D-021): the session's copy of the model and its
## events are simply dropped, and the lesson or test starts over next time.
func _on_close() -> void:
	var what := "this Reading Adventure" if _testing else "this lesson"
	_open_overlay("raccoon", Palette.NIPA, "Stop now?",
			"If you stop, you will start %s again next time." % what, "KEEP PLAYING", func(): pass,
			"STOP", _leave)


func _leave() -> void:
	Speech.stop()
	_waiting = false
	_wait_id += 1
	if _testing:
		GameState.lesson_mode = "lesson"
	get_tree().change_scene_to_file("res://scenes/path/learning_path.tscn")


func _finish() -> void:
	Speech.stop()
	GameState.finish_lesson(session)
	get_tree().change_scene_to_file("res://scenes/lesson/lesson_complete.tscn")


func _open_overlay(icon: String, icon_bg: Color, title: String, text: String, primary: String,
		on_primary: Callable, secondary: String = "", on_secondary: Callable = Callable()) -> void:
	%OverlayIcon.texture = Icons.tex(icon)
	var disc: StyleBoxFlat = %OverlayDisc.get_theme_stylebox("panel").duplicate()
	disc.bg_color = icon_bg
	%OverlayDisc.add_theme_stylebox_override("panel", disc)
	%OverlayTitle.text = title
	%OverlayText.text = text
	%OverlayPrimary.text = primary
	%OverlaySecondary.text = secondary
	%OverlaySecondary.visible = secondary != ""
	_overlay_primary = on_primary
	_overlay_secondary = on_secondary
	%Overlay.show()
	var card: Control = %OverlayCard
	card.pivot_offset = card.size / 2
	card.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


## Android Back or Escape (D-023): an open card takes its main answer (OK, or
## KEEP PLAYING on "Stop now?"); otherwise Back asks before stopping, like ✕.
func go_back() -> void:
	if %Overlay.visible:
		_close_overlay(_overlay_primary)
	else:
		_on_close()


func _close_overlay(action: Callable) -> void:
	%Overlay.hide()
	if action.is_valid():
		action.call()
