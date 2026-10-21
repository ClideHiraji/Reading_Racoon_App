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
	%SwitchButton.visible = GameState.signed_in()
	if GameState.signed_in():
		%SwitchButton.text = "Not %s? Switch student" % child
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
	# First time: the Reading Adventure (pre-test) places the child on the path
	# (FR-02). Outside Adventure's hours this lands on the hub instead.
	if GameState.needs_pretest():
		GameState.start_assessment("pre")
		return
	get_tree().change_scene_to_file(GameState.HUB_SCENE)


## Two taps to switch, and never while answers are still waiting to upload.
func _on_switch() -> void:
	if not _confirm_switch:
		_confirm_switch = true
		%SwitchButton.text = "Tap again to switch student"
		return
	if GameState.sign_out():
		get_tree().change_scene_to_file("res://scenes/login/login.tscn")
		return
	_confirm_switch = false
	%SwitchButton.text = "Not %s? Switch student" % GameState.student_name()
	%Raccoon.set_mood("thinking")
	%Bubble.say("Wait! I'm still saving your stars. Let's connect to Wi-Fi first.")
	Sync.request_soon()
