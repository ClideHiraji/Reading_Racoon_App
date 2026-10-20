extends Control
## Start screen: the raccoon waves from the riverbank, one big button opens the
## learning path. No reading needed: the button is read aloud too (D-007, D-009).
## Student login (FR-01) replaces this once open issue 9 is decided.


func _ready() -> void:
	%PlayButton.pressed.connect(_on_play)
	%GrownupsButton.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/settings/grownups.tscn"))
	%Raccoon.set_mood("happy")
	%Bubble.say("Hi! I'm Racoon. Let's read together!")


func _on_play() -> void:
	Speech.say("Let's read!")
	if not GameState.guard():   # FR-12: play-time limits
		return
	# First time: the Reading Adventure (pre-test) places the child on the path (FR-02).
	if GameState.needs_pretest():
		GameState.start_assessment("pre")
		return
	get_tree().change_scene_to_file("res://scenes/path/learning_path.tscn")
