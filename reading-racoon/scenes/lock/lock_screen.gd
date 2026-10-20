extends Control
## Friendly lock screen for time-restricted access (FR-12, 06-game-design.md):
## "Come back during Reading time", "Game is sleeping", "Great work today!".
## It never closes the app, and "Check again" re-asks the schedule.

const TEXTS := {
	"class_lock": ["Time for other lessons", "Come back during Reading time!", "book"],
	"daily_limit": ["Great work today!", "You played all your minutes. See you tomorrow!", "star"],
	"weekend_lock": ["It's the weekend", "Racoon is resting. See you on Monday!", "night"],
	"sleeping": ["The game is sleeping", "Shh... come back tomorrow!", "night"],
}


func _ready() -> void:
	%CheckButton.pressed.connect(_check)
	%GrownupsButton.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/settings/grownups.tscn"))
	_show(GameState.access_decision())


func _show(d: Dictionary) -> void:
	var t: Array = TEXTS.get(d.status, TEXTS.sleeping)
	%Title.text = t[0]
	%Text.text = t[1]
	%Icon.texture = Icons.tex(t[2])
	var night: bool = d.status in ["sleeping", "weekend_lock"]
	%Bg.material.set_shader_parameter("paper", Color("2f3a5c") if night else Palette.PAPER)
	%Title.add_theme_color_override("font_color", Palette.CARD if night else Palette.INK)
	%Text.add_theme_color_override("font_color", Palette.pale(Palette.BAY, 0.6) if night else Palette.INK_SOFT)
	%Raccoon.set_mood("sleepy" if night or d.status == "daily_limit" else "encourage")
	Speech.say(t[1])


func _check() -> void:
	var d := GameState.access_decision()
	if AccessPolicy.is_open(d):
		get_tree().change_scene_to_file("res://scenes/path/learning_path.tscn")
	else:
		_show(d)
		%Raccoon.set_mood("thinking")
