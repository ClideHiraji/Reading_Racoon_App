extends Control
## One lesson (D-007 layout, D-009 storybook look): close, progress bar and hearts
## on top, the prompt on a paper card, the task in the middle, and the raccoon
## standing on the world's paper-cut landscape. A paper sheet slides up after
## each answer. The rules live in LessonSession (scripts/core); this only shows them.
## FR-13 hearts and Racoon's Rescue, FR-14 hints, FR-20 read-aloud.

## One scene per task_type in content/levels*.json.
const TASKS := {
	"tap_choice": preload("res://scenes/tasks/tap_choice_task.tscn"),
	"drag_letter": preload("res://scenes/tasks/drag_letter_task.tscn"),
	"order_tiles": preload("res://scenes/tasks/order_tiles_task.tscn"),
	"spin_words": preload("res://scenes/tasks/spin_words_task.tscn"),
}
const RESCUE_PAPER := Color("dcebf0")

## A LessonSession, or an AssessmentSession for the pre/post-test (same interface).
var session: RefCounted
var _testing := false
var _item := {}
var _task: Control
var _outcome := {}
var _shown_passage := ""
var _overlay_primary: Callable
var _overlay_secondary: Callable

@onready var raccoon: Raccoon = %Raccoon
@onready var bubble: SpeechBubble = %Bubble
@onready var sheet: PanelContainer = %Sheet


func _ready() -> void:
	session = GameState.new_session()
	var world := SkillCatalog.world(GameState.lesson_world)
	%Scenery.scene = world.scene
	%CloseButton.pressed.connect(_on_close)
	%SpeakButton.pressed.connect(_speak)
	%StoryButton.pressed.connect(_peek_story)
	%ContinueButton.pressed.connect(_on_continue)
	%OverlayPrimary.pressed.connect(func(): _close_overlay(_overlay_primary))
	%OverlaySecondary.pressed.connect(func(): _close_overlay(_overlay_secondary))
	_update_hearts(HeartSystem.MAX_HEARTS)
	_testing = session is AssessmentSession
	if _testing:
		# Reading Adventure (FR-02/FR-10): no hearts, no right/wrong, just do your best.
		%Hearts.hide()
		var pre: bool = session.kind == "pre"
		_say(GameState.line("adventure_intro"), "happy")
		_open_overlay("stories", Palette.TEAL, "Reading Adventure!" if pre else "Big Reading Day!",
				"Show Racoon what you can do. No hearts today, just try your best!", "LET'S GO!",
				_next)
		Speech.say("Reading Adventure! Show Racoon what you can do. Just try your best!")
		return
	_say(GameState.line("intro"), "happy")
	_next()


func _next() -> void:
	sheet.hide()
	_item = session.next_item()
	if _item.is_empty():
		push_error("Lesson: no content for level %d" % session.level)
		_finish()
		return
	if _task:
		_task.queue_free()
		_task = null
	_update_progress()
	%SpeakButton.visible = Speech.available(_item.get("language", "en"))
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


## Story first: the child reads (or listens to) the passage, then answers.
func _show_story(pid: String) -> void:
	var p: Dictionary = session.bank.passage(pid)
	_shown_passage = pid
	var page := StoryPage.new()
	page.setup(p)
	page.done.connect(_start_task)
	_task = page
	%TaskHolder.add_child(page)
	%StoryButton.visible = false
	%Prompt.text = p.get("title", "Story")
	Speech.say(p.get("text", ""), p.get("language", "en"))


func _peek_story() -> void:
	var p: Dictionary = session.bank.passage(_item.get("passage", ""))
	Speech.say(p.get("text", ""), p.get("language", "en"))
	_open_overlay("stories", Palette.TEAL, p.get("title", ""), p.get("text", ""), "OK", func(): pass)


func _speak() -> void:
	Speech.say(_item.get("tts_text", _item.get("prompt", "")), _item.get("language", "en"))


func _on_answered(answer: String, ms: int) -> void:
	var was_rescue: bool = session.in_rescue()
	_outcome = session.submit(answer, ms)
	GameState.record(session)   # saved after every answer (FR-11)
	var right := str(_outcome.answer)
	if _outcome.get("neutral", false):
		# Tests never reveal right or wrong; the child just moves on.
		_update_progress()
		Sfx.play("pop")
		_say(GameState.line("adventure_next"), "happy")
		_show_neutral_sheet()
		return
	_task.show_result(answer, right)
	Sfx.play("correct" if _outcome.correct else "wrong")
	_update_hearts(_outcome.hearts)
	_update_progress()

	var line := ""
	var mood: String = _outcome.mood
	if _outcome.correct:
		line = GameState.line("rescue_correct" if was_rescue else "correct")
	elif _outcome.hint:
		line = GameState.line("hint_" + _outcome.skill)
	else:
		line = GameState.line("incorrect")
	if _outcome.mastered_now and not _outcome.level_up:
		line = "You won the %s crown!" % SkillCatalog.NAMES[_outcome.skill]
		mood = "celebrate"
	if _outcome.level_up:
		line = GameState.line("level_up")
		Sfx.play("fanfare")
	if _outcome.has("rescue_full"):
		_end_rescue_look()
		line = GameState.line("rescue_full" if _outcome.rescue_full else "rescue_partial")
		mood = "celebrate" if _outcome.rescue_full else "encourage"
	_say(line, mood)
	var shown: String = _task.answer_text(right) if _task.has_method("answer_text") else _choice_label(right)
	_show_sheet(_outcome.correct, shown)


func _on_continue() -> void:
	Sfx.play("pop")
	match _outcome.get("next", "continue"):
		"rescue_start":
			_start_rescue_look()
		"done":
			_finish()
		"end_session":
			sheet.hide()
			_say(GameState.line("session_end"), "sleepy")
			_open_overlay("night", Palette.PLUM, "Let's rest!", GameState.line("session_end"), "OK",
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
	_say(text, "encourage")
	Speech.say(text)
	_open_overlay("heart_plus", Palette.CORAL, "Racoon's Rescue!",
			"Answer 3 easy ones to get your hearts back.", "OK!", _next)


func _end_rescue_look() -> void:
	%Bg.material.set_shader_parameter("paper", Palette.PAPER)
	%RescueBanner.hide()


func _update_rescue_label() -> void:
	%RescueLabel.text = "Racoon's Rescue  %d / %d" % [session.rescue.get("answered", 0),
			HeartSystem.RECOVERY_ITEMS]


# --- Sheet, hearts, progress --------------------------------------------------------

func _show_neutral_sheet() -> void:
	_show_sheet(true, "")
	var sb: StyleBoxFlat = sheet.get_theme_stylebox("panel").duplicate()
	sb.bg_color = Palette.pale(Palette.TEAL, 0.8)
	sheet.add_theme_stylebox_override("panel", sb)
	var disc: StyleBoxFlat = %SheetDisc.get_theme_stylebox("panel").duplicate()
	disc.bg_color = Palette.TEAL
	%SheetDisc.add_theme_stylebox_override("panel", disc)
	%SheetIcon.texture = Icons.tex("sparkles")
	%SheetTitle.text = "Thank you!"
	%SheetTitle.add_theme_color_override("font_color", Palette.TEAL_DEEP)
	%ContinueButton.face_color = Palette.TEAL


func _show_sheet(correct: bool, answer_text: String) -> void:
	var color := Palette.RIGHT if correct else Palette.ALMOST
	var sb: StyleBoxFlat = sheet.get_theme_stylebox("panel").duplicate()
	sb.bg_color = Palette.pale(color, 0.78)
	sheet.add_theme_stylebox_override("panel", sb)
	var disc: StyleBoxFlat = %SheetDisc.get_theme_stylebox("panel").duplicate()
	disc.bg_color = color
	%SheetDisc.add_theme_stylebox_override("panel", disc)
	%SheetIcon.texture = Icons.tex("check" if correct else "bulb")
	%SheetTitle.text = ["Great job!", "Awesome!", "You got it!"].pick_random() if correct \
			else "Almost!"
	%SheetTitle.add_theme_color_override("font_color", Palette.deep(color))
	%SheetDetail.text = "" if correct else "The answer is: %s" % answer_text
	%SheetDetail.visible = not correct
	%ContinueButton.face_color = color
	sheet.show()
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


func _update_hearts(count: int) -> void:
	var box: HBoxContainer = %Hearts
	for c in box.get_children():
		c.queue_free()
	for i in HeartSystem.MAX_HEARTS:
		var full := i < count
		var heart := Icons.rect("heart", 46, Palette.CORAL if full else Palette.PAPER_DEEP.darkened(0.1))
		box.add_child(heart)
	if session.in_rescue():
		_update_rescue_label()


func _update_progress() -> void:
	create_tween().tween_property(%Progress, "value", session.progress(), 0.3)


func _say(text: String, mood: String) -> void:
	raccoon.set_mood(mood)
	bubble.say(text)


# --- Leaving -------------------------------------------------------------------------

func _on_close() -> void:
	_open_overlay("raccoon", Palette.NIPA, "Stop the lesson?",
			"Your answers are saved, but you won't get stars.", "KEEP PLAYING", func(): pass,
			"STOP", _leave)


func _leave() -> void:
	Speech.stop()
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


func _close_overlay(action: Callable) -> void:
	%Overlay.hide()
	if action.is_valid():
		action.call()
