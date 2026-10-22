extends Control
## Friendly lock screen for time-restricted access (FR-12, 06-game-design.md):
## "The game is sleeping" at night. In the day only Adventure locks and the hub
## explains it (D-015), so this screen is for night time.
## It never closes the app, and "Check again" re-asks the schedule.

const TEXTS := {
	"class_lock": ["Time for other lessons", "Come back during Reading time!", "book"],
	"daily_limit": ["Great work today!", "You played all your minutes. See you tomorrow!", "star"],
	"weekend_lock": ["It's the weekend", "Racoon is resting. See you on Monday!", "night"],
	"sleeping": ["The game is sleeping", "Shh... come back tomorrow!", "night"],
}
const NIGHT_SKY := Color("3f3354")

var _star: AnimatedStar


func _ready() -> void:
	%CheckButton.pressed.connect(_check)
	var d := GameState.hub_decision()
	_show(d if not AccessPolicy.is_open(d) else GameState.access_decision())


## Night uses the plum night colors, and the moon on a pale disc; a good day
## (daily limit) gets the gold star; Check again is a quiet button at night (D-022).
func _show(d: Dictionary) -> void:
	var t: Array = TEXTS.get(d.status, TEXTS.sleeping)
	%Title.text = t[0]
	%Text.text = t[1]
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
	Speech.say(t[1])


func _check() -> void:
	var d := GameState.hub_decision()
	if AccessPolicy.is_open(d):
		get_tree().change_scene_to_file(GameState.HUB_SCENE)
	else:
		_show(d)
		%Raccoon.set_mood("thinking")
