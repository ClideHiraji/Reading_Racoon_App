extends Control
## One lesson (D-007 layout, D-009 storybook look): close, progress bar and hearts
## on top, the prompt on a paper card, the task in the middle, and the raccoon
## standing on the world's paper-cut landscape. A paper sheet slides up after
## each answer. The rules live in LessonSession (scripts/core); this only shows them.
## FR-13 hearts and Racoon's Rescue, FR-14 hints, FR-20 read-aloud.

const TAP_TASK := preload("res://scenes/tasks/tap_choice_task.tscn")
const DRAG_TASK := preload("res://scenes/tasks/drag_letter_task.tscn")
const RESCUE_PAPER := Color("dcebf0")

var session: LessonSession
var _item := {}
var _task: Control
var _outcome := {}
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
	%SpeakButton.visible = Speech.available()
	%ContinueButton.pressed.connect(_on_continue)
	%OverlayPrimary.pressed.connect(func(): _close_overlay(_overlay_primary))
	%OverlaySecondary.pressed.connect(func(): _close_overlay(_overlay_secondary))
	_update_hearts(HeartSystem.MAX_HEARTS)
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
	_task = (DRAG_TASK if _item.task_type == "drag_letter" else TAP_TASK).instantiate()
	%TaskHolder.add_child(_task)
	_task.setup(_item)
	_task.answered.connect(_on_answered)
	%Prompt.text = _item.prompt
	_update_progress()
	_speak()


func _speak() -> void:
	Speech.say(_item.get("tts_text", _item.get("prompt", "")))


func _on_answered(answer: String, ms: int) -> void:
	var was_rescue := session.in_rescue()
	_outcome = session.submit(answer, ms)
	GameState.record(session)   # saved after every answer (FR-11)
	var right := str(_outcome.answer)
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
	_show_sheet(_outcome.correct, _choice_label(right))


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
