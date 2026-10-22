extends Control
## Start screen: the raccoon waves from the riverbank, one big button plays.
## No reading needed: the button is read aloud too (D-007, D-009).
## First time on a device: the login screen (FR-01, D-010). After that it greets
## the child by name and opens the home hub (the pre-test first, FR-02, D-015).

var _confirm_switch := false


func _ready() -> void:
	%PlayButton.pressed.connect(_on_play)
	%SwitchButton.pressed.connect(_on_switch)
	%Raccoon.set_mood("happy")
	var child := GameState.student_name()
	# For grown-ups, in the corner and out of the child's way (D-022).
	%SwitchButton.visible = GameState.signed_in()
	if GameState.signed_in():
		%Bubble.say("Hi, %s! Let's read together!" % child)
	else:
		%Bubble.say("Hi! I'm Racoon. Let's read together!")


func _on_play() -> void:
	Speech.say("Let's read!")
	if not GameState.guard_hub():   # FR-12: the game sleeps at night
		return
	if not GameState.signed_in():
		get_tree().change_scene_to_file("res://scenes/login/login.tscn")
		return
	# Always the home hub; the Reading Adventure (pre-test, FR-02) waits on the
	# Adventure map until the child starts it (D-021).
	get_tree().change_scene_to_file(GameState.HUB_SCENE)


## Two taps to switch, and never while answers are still waiting to upload.
func _on_switch() -> void:
	if not _confirm_switch:
		_confirm_switch = true
		%SwitchButton.text = "Tap again"
		return
	if GameState.sign_out():
		get_tree().change_scene_to_file("res://scenes/login/login.tscn")
		return
	_confirm_switch = false
	%SwitchButton.text = "Switch student"
	%Raccoon.set_mood("thinking")
	%Bubble.say("Wait! I'm still saving your stars. Let's connect to Wi-Fi first.")
	Sync.request_soon()
