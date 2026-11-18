extends Control
## Friendly lock screen for time-restricted access (FR-12, 06-game-design.md):
## "The game is sleeping" at night. In the day only Adventure locks and the hub
## explains it (D-015), so this screen is for night time.
## It never closes the app, and "Check again" re-asks the schedule.

## Each lock's title and line: keys in content/talk.json, in the buddy's language (D-033).
## Each lock's title and line: keys in content/talk.json, in the buddy's language (D-033).
## Each lock's title and line: keys in content/talk.json, in the buddy's language (D-033).
## Each lock's title and line: keys in content/talk.json, in the buddy's language (D-033).
const TEXTS := {
	"class_lock": ["lock_class_title", "lock_class", "book"],
	"daily_limit": ["lock_limit_title", "lock_limit", "star"],
	"weekend_lock": ["lock_weekend_title", "lock_weekend", "night"],
	"sleeping": ["lock_sleep_title", "lock_sleep", "night"],
}
const NIGHT_SKY := Color("3f3354")

var _star: AnimatedStar


func _ready() -> void:
	_fit_shape()
	%CheckButton.pressed.connect(_check)
	var d := GameState.hub_decision()
	_show(d if not AccessPolicy.is_open(d) else GameState.access_decision())


## Night uses the plum night colors, and the moon on a pale disc; a good day
## (daily limit) gets the gold star; Check again is a quiet button at night (D-022).
## Laptops (D-023): the message and CHECK AGAIN on the left, Racoon on the right
## above the village. Both shapes keep clear of a notch.
func _fit_shape() -> void:
	var margin: MarginContainer = $Margin
	if Kit.landscape():
		var row: Control = $Margin/VBox/RaccoonRow
		row.reparent(self, false)
		row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		row.offset_left = -500
		row.offset_right = -60
		row.offset_top = -420
		row.offset_bottom = -90
		$Margin/VBox.alignment = BoxContainer.ALIGNMENT_CENTER
		margin.add_theme_constant_override("margin_left", 80)
		margin.add_theme_constant_override("margin_right", 560)
		margin.add_theme_constant_override("margin_top", 40)
		margin.add_theme_constant_override("margin_bottom", 40)
		$Scenery.offset_top = -300
	Kit.fit_safe(margin)


func _show(d: Dictionary) -> void:
	var t: Array = TEXTS.get(d.status, TEXTS.sleeping)
	%Title.text = GameState.talk(t[0])
	%Text.text = GameState.talk(t[1])
	%Icon.texture = Icons.tex(t[2])
	var night: bool = d.status in ["sleeping", "weekend_lock"]
	%Bg.material.set_shader_parameter("paper", NIGHT_SKY if night else Palette.PAPER)
	%Title.add_theme_color_override("font_color", Palette.CARD if night else Palette.INK)
	%Text.add_theme_color_override("font_color", Palette.pale(Palette.PLUM_LIGHT, 0.5) if night else Palette.INK_SOFT)
	var disc_box: StyleBoxFlat = $Margin/VBox/DiscRow/Disc.get_theme_stylebox("panel").duplicate()
	disc_box.bg_color = Palette.pale(Palette.PLUM_LIGHT, 0.55) if night else Palette.YELLOW
	$Margin/VBox/DiscRow/Disc.add_theme_stylebox_override("panel", disc_box)
	%Icon.self_modulate = Palette.PLUM_DEEP if night else Color.WHITE
	var good_day: bool = d.status == "daily_limit"
	$Margin/VBox/DiscRow/Disc.visible = not good_day
	if good_day and _star == null:
		_star = AnimatedStar.make(220)
		$Margin/VBox/DiscRow/Disc.get_parent().add_child(_star)
	var check: ChunkyButton = %CheckButton
	check.face_color = Palette.PLUM_LIGHT if night else Palette.ORANGE
	%Raccoon.set_mood("sleepy" if night or good_day else "encourage")
	Speech.say(%Text.text)


func _check() -> void:
	var d := GameState.hub_decision()
	if AccessPolicy.is_open(d):
		get_tree().change_scene_to_file(GameState.HUB_SCENE)
	else:
		_show(d)
		%Raccoon.set_mood("thinking")
