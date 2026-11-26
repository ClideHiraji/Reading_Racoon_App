extends Control
## Start screen: the raccoon waves from the riverbank and one big button plays.
## The first time, the opening (Intro) plays over it and lifts away.
## No reading needed: the button is read aloud too.
## First time on a device: the login screen. After that it greets the child ("reader",
## since a recorded line can't say a name) and opens the home hub.

var _confirm_switch := false


func _ready() -> void:
	_fit_shape()
	GameState.warm_scenes()   # Home and the first screens compile while the child looks
	%PlayButton.pressed.connect(_on_play)
	%SwitchButton.pressed.connect(_on_switch)
	%Raccoon.set_mood("happy")
	%Raccoon.lively = true   # he moves on his own while the start screen waits
	%Bubble.speaker = %Raccoon   # his bubble walks with him and points at him
	# For grown-ups, in the corner and out of the child's way.
	%SwitchButton.visible = GameState.signed_in()
	# The opening plays over the start screen the first time. Racoon greets the child
	# once it has lifted, not over it.
	if Intro.should_play(GameState._args):
		var intro := Intro.new()
		intro.finished.connect(_greet)
		add_child(intro)
	else:
		_greet()


func _greet() -> void:
	if GameState.signed_in():
		%Bubble.say(GameState.talk("start_hi_name"))   # "reader", not the name (recorded voice)
	else:
		%Bubble.say(GameState.talk("start_hi"))


## Laptop layout: the name and LET'S READ! on the left, Racoon and his bubble on the
## right above the riverbank. Both layouts keep clear of a notch.
func _fit_shape() -> void:
	var margin: MarginContainer = $Margin
	if Kit.landscape():
		var col: VBoxContainer = $Margin/VBox
		var spacer: Control = col.get_node("Spacer")
		var gap: Control = col.get_node("Gap")
		var row: Control = col.get_node("RaccoonRow")
		var body := HBoxContainer.new()
		body.add_theme_constant_override("separation", 48)
		margin.add_child(body)
		col.reparent(body, false)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var right := VBoxContainer.new()
		right.custom_minimum_size = Vector2(440, 0)
		right.alignment = BoxContainer.ALIGNMENT_END
		body.add_child(right)
		for n: Control in [%Bubble, gap, row]:
			n.reparent(right, false)
		%Raccoon.custom_minimum_size = Vector2(300, 300)
		spacer.size_flags_vertical = Control.SIZE_FILL
		spacer.custom_minimum_size = Vector2(0, 56)
		col.get_node("Spacer2").queue_free()
		margin.add_theme_constant_override("margin_left", 72)
		margin.add_theme_constant_override("margin_right", 60)
		margin.add_theme_constant_override("margin_top", 60)
		margin.add_theme_constant_override("margin_bottom", 40)
		$Scenery.offset_top = -330
		$Burst.offset_bottom = 420
	Kit.fit_safe(margin)
	var safe := Kit.insets()
	%SwitchButton.offset_top += safe.top
	%SwitchButton.offset_bottom += safe.top
	%SwitchButton.offset_left -= safe.right
	%SwitchButton.offset_right -= safe.right


func _on_play() -> void:
	Speech.say(GameState.talk("start_play"))
	if not GameState.guard_hub():   # the game sleeps at night
		return
	if not GameState.signed_in():
		get_tree().change_scene_to_file("res://scenes/login/login.tscn")
		return
	# Always the home hub; the pre-test waits on the Adventure map until the child starts it.
	# A student who hasn't picked a buddy and language yet does that first.
	get_tree().change_scene_to_file(GameState.HUB_SCENE if GameState.buddy_chosen() else GameState.BUDDY_SCENE)


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
	%Bubble.say(GameState.talk("start_wait_saving"))
	Sync.request_soon()
