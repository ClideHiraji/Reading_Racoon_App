extends Node
## The device's shape, its safe area and the Back key (autoload "Screen", D-023).
## - Shape: a landscape window (the school laptops) draws the game on a 1280×720
##   canvas instead of 720×1280, so it is bigger on a wide screen, and each
##   screen lays itself out side by side when `landscape` is true. Phones stay
##   portrait. Laptop builds open full screen unless Settings turned it off (D-042).
## - Safe area: insets() gives the notch, rounded corners and home indicator in
##   canvas units, so top and bottom bars stay clear of them (iPhone, Android).
## - Back: Android's Back button or gesture and Escape on a laptop do what the
##   screen's own ✕ or Home button does, closing an open card first. Only Home
##   and the start screens let Back leave the game, as Android expects.
## - Mouse: every button shows the pointing hand, so a child on a laptop can
##   tell what can be clicked.

signal shape_changed

const PORTRAIT := Vector2i(720, 1280)
const LANDSCAPE := Vector2i(1280, 720)

var landscape := false
var _debug_insets := {}   # --safe-insets=top,bottom for screenshots


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--safe-insets="):
			var parts := a.trim_prefix("--safe-insets=").split(",")
			_debug_insets = {"top": float(parts[0]), "bottom": float(parts[1]) if parts.size() > 1 else 0.0}
	SettingsCard.apply_saved(get_tree())   # volumes; full screen on a laptop unless turned off (D-042)
	get_tree().root.size_changed.connect(_fit)
	get_tree().node_added.connect(_on_node_added)
	_fit()
	if DevMenu.allowed():   # issue 30: DELETE BEFORE THE FINAL RELEASE
		print("Developer menu is on (debug build): F12, or 5 quick taps in the top-right corner. "
				+ "Delete it before the final release (issue 30).")


## The developer menu's way in (issue 30, debug builds only). DELETE BEFORE THE FINAL RELEASE.
func _input(event: InputEvent) -> void:
	DevMenu.handle_input(event, get_tree())


func _fit() -> void:
	var px := get_tree().root.size
	var wide := px.x > px.y
	get_tree().root.content_scale_size = LANDSCAPE if wide else PORTRAIT
	if wide != landscape:
		landscape = wide
		shape_changed.emit()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var list := _scroll_of(node)
		if list:
			# A drag that starts on a card must still scroll its list: the card lets the touch
			# through to the list, which cancels the card's press once the finger moves (NFR-02).
			var b := node as BaseButton
			b.mouse_filter = Control.MOUSE_FILTER_PASS
			# A tap the card takes never reaches the list, which then thinks a finger is still down
			# and would scroll with the next mouse move; setting its scroll ends that drag.
			b.pressed.connect(func(): if is_instance_valid(list): list.scroll_vertical = list.scroll_vertical)


static func _scroll_of(node: Node) -> ScrollContainer:
	var p := node.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


## How much of each edge the notch, rounded corners and home indicator cover,
## in canvas units (all zero on a laptop).
func insets() -> Dictionary:
	if not _debug_insets.is_empty():
		return {"top": _debug_insets.top, "bottom": _debug_insets.bottom, "left": 0.0, "right": 0.0}
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if screen.x <= 0.0 or safe.size.x <= 0.0 or not (OS.has_feature("mobile")):
		return {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	var base := Vector2(get_tree().root.content_scale_size)
	var scale := minf(screen.x / base.x, screen.y / base.y)
	return {
		"top": safe.position.y / scale,
		"bottom": (screen.y - safe.end.y) / scale,
		"left": safe.position.x / scale,
		"right": (screen.x - safe.end.x) / scale,
	}


const BACK_REST_MS := 450
var _last_back := -100000


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


## Back, on any screen: an open card's own way out first (group "back_cancel"),
## then the screen's go_back() or its ✕ / Home button (group "back_button").
## With neither (Home, the start screen), Back leaves the game. A second Back within
## BACK_REST_MS does nothing, so a quick double press can't go back twice.
func back() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_back < BACK_REST_MS:
		return
	_last_back = now
	var scene := get_tree().current_scene
	if scene == null:
		return
	var cancel := _top_visible("back_cancel", scene)
	if cancel:
		cancel.pressed.emit()
		return
	if scene.has_method("go_back"):
		scene.go_back()
		return
	var button := _top_visible("back_button", scene)
	if button:
		button.pressed.emit()
		return
	if OS.has_feature("android"):
		get_tree().quit()


func _top_visible(group: String, scene: Node) -> BaseButton:
	var found: BaseButton = null
	for n in get_tree().get_nodes_in_group(group):
		if n is BaseButton and n.is_visible_in_tree() and not n.disabled and scene.is_ancestor_of(n):
			found = n   # the last one added is the one on top
	return found
