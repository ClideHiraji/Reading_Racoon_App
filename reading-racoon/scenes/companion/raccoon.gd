@tool
class_name Raccoon
extends Control
## Racoon, the companion (FR-14), on any screen. He's the Godot scene
## scenes/companion/racoon_puppet.tscn (D-024): one node per part of the user's drawing, and an
## AnimationPlayer with one animation per move (open it in the editor to see or edit them). This
## Control fits him into its box and plays his moves.
## Moods (the old API, kept): idle, happy, thinking, encourage, celebrate, sleepy. The lesson also
## plays his moments: moment(), point_at(), look_at_point(), read_along(), talk().
## Outfit (FR-07, Wardrobe): the scarves and the open book are drawn parts; the other Closet items
## are drawn by the puppet in code, fitted to his head, neck and chest.
## He stays calm while a child reads, and acts on Home, at results, or when a hint helps
## (06-game-design, companion guardrails).

const PUPPET := preload("res://scenes/companion/racoon_puppet.tscn")
const MOODS := {"happy": "happy", "celebrate": "celebrate", "thinking": "thinking", "encourage": "encourage",
	"sleepy": "sleepy", "idle": "idle"}
## The lesson's moments (the canvas board "Racoon in the game") and the animation each one plays.
const MOMENTS := {"greet": "greet", "right": "happy", "hint": "hint", "answer": "answer", "rescue": "rescue",
	"rescue_won": "rescue_won", "level_up": "level_up", "complete": "celebrate", "nudge": "nudge", "rest": "sleepy"}
## A tap he took: not while he's still reacting or speaking, nor right after the last one.
signal tapped

## Taps on him play these in turn.
const TAPS := ["giggle", "spin", "peek", "jump", "dance", "hop_around", "big_jump", "tail_wag"]
## What he does on his own when he's lively (look_around and tail_wag the most often).
const AMBIENT := ["look_around", "tail_wag", "stretch", "look_around", "walk_around", "hop_around", "dance",
	"tail_wag"]
const BLEND := 0.18         # seconds to blend from one move into the next
## His pet (D-029) circles his head when he makes one of these moves.
const PET_ORBIT := ["dance", "celebrate", "big_jump", "level_up", "rescue_won", "hop_around", "spin", "jump"]
## A tap is taken only this long after the last one, and once he has finished reacting and speaking:
## rapid tapping can't pile up moves and lines.
const TAP_REST_MS := 700
const REACH_L := 190.0      # how far his drawing reaches left of where he stands, in any move,
const REACH_R := 210.0      # right (his tail),
const REACH_UP := 400.0     # and up from his feet (paws raised): drawing units, measured 2026-11-17

@export var mood := "idle"
## What Racoon wears, {slot: item id} (FR-07, Wardrobe). By default it follows the
## child's saved outfit; the shop sets it directly to try things on.
var _pet: Pet
var outfit := {}:
	set(v):
		outfit = v
		_apply_outfit()
@export var follow_saved_outfit := true
## Which buddy this is (D-033): "" follows the student's pick, Roco or Rina; the buddy chooser's cards
## set "roco" or "rina".
@export var buddy := "":
	set(v):
		buddy = v
		_apply_buddy()
## Taps on Racoon make him react (giggle, spin, peekaboo, jump, a dance, hops, a big jump, a tail
## wag). Home turns it on (FR-14).
@export var react_to_taps := false
## His own little life: when nobody has touched the screen for 6-11 seconds he looks around, wags
## his tail, stretches, walks about, hops or dances (the animations in
## racoon_puppet.tscn). Home, the start screen and the Closet turn it on; never where a child
## reads or answers (his guardrails: calm while a child reads).
@export var lively := false
## Drawn once at rest and not animated (the Closet's small item cards), so a screen of
## previews costs nothing per frame.
@export var still := false:
	set(v):
		still = v
		if puppet:
			puppet.still = v
		if _pet:
			_pet.still = v
## True while he's in the middle of a move (not while idle or asleep).
var busy: bool:
	get:
		return _anim != null and _anim.is_playing() and not _anim.current_animation in ["idle", "asleep"]

## The old animated offsets, kept for any caller.
var hop := 0.0:
	set(v):
		hop = v
		puppet.hop = -v * 2.0
var tilt := 0.0:
	set(v):
		tilt = v
		puppet.lean = rad_to_deg(v)
var squash := 1.0:
	set(v):
		squash = v
		puppet.squash = v
var wag := 0.0

var puppet: RacoonPuppet
var _anim: AnimationPlayer
var _tap_n := 0
var _outfit_tween: Tween
var _mouse_t := 0.0
var _quiet_since := 0
var _wait_next := 7000.0
var _last_ambient := ""
var _own_move := ""            # the move he's doing on his own (a tap may cut into it)
var _last_tap := -100000
var _reach := {}            # each move's furthest stroll and highest hop, read from its keys
var _room_tween: Tween


func _init() -> void:
	puppet = PUPPET.instantiate()
	add_child(puppet, false, INTERNAL_MODE_FRONT)
	_anim = puppet.get_node("AnimationPlayer")
	_anim.animation_finished.connect(_on_finished)
	resized.connect(_fit)


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(180, 180)
	puppet.still = still
	var gs := get_node_or_null("/root/GameState")
	if follow_saved_outfit and gs and not Engine.is_editor_hint():
		outfit = gs.wardrobe.equipped.duplicate()
		gs.outfit_changed.connect(func(): outfit = gs.wardrobe.equipped.duplicate())
	else:
		_apply_outfit()
	if gs and not Engine.is_editor_hint():
		gs.buddy_changed.connect(_apply_buddy)
	_apply_buddy()
	_fit()


## Roco or Rina (D-033): Rina is the same raccoon with her girl details (eyelashes, rosy cheeks, a bow).
func _apply_buddy() -> void:
	if puppet == null:
		return
	var who := buddy
	var gs := get_node_or_null("/root/GameState") if is_inside_tree() else null
	if who == "" and gs and not Engine.is_editor_hint():
		who = gs.buddy_id()
	puppet.girl = who == "rina"


## He stands at the bottom middle of the box, as big as it lets him (the drawing is 400 x 400).
func _fit() -> void:
	var k := maxf(minf(size.x, size.y), 1.0) / 400.0
	puppet.scale = Vector2(k, k)
	puppet.position = Vector2(size.x / 2.0 - RacoonPuppet._ax() * k, size.y - 4.0 - RacoonPuppet._gy() * k)


func _process(_delta: float) -> void:
	if puppet:
		puppet.acting = busy
		if Time.get_ticks_msec() - _mouse_t > 2500:
			puppet.follow_point = Vector2.INF
	if lively and not still and not Engine.is_editor_hint() and is_visible_in_tree():
		var now := Time.get_ticks_msec()
		if busy or mood == "sleepy" or _anim.current_animation == "asleep":
			_quiet_since = now
		elif now - _quiet_since > _wait_next:
			_quiet_since = now
			_wait_next = randf_range(6000.0, 11000.0)
			_own_move = _pick_ambient()
			play(_own_move)


## How far his walk has carried him sideways from his place, in canvas pixels (his speech
## bubble follows it).
func walk_offset() -> float:
	if puppet == null:
		return 0.0
	return puppet.stroll * puppet.roam * puppet.get_global_transform().get_scale().x


## Where his head is, in the viewport's pixels: his speech bubble's tail points at it.
func speak_point() -> Vector2:
	if puppet == null:
		return get_global_transform_with_canvas() * (size / 2.0)
	var head := Vector2(RacoonPuppet._ax() + puppet.stroll * puppet.roam, RacoonPuppet._hc().y)
	return puppet.get_global_transform_with_canvas() * head


## One of his own moves, not the same as last time.
func _pick_ambient() -> String:
	var pick: String = AMBIENT.pick_random()
	while pick == _last_ambient:
		pick = AMBIENT.pick_random()
	_last_ambient = pick
	return pick


# --- moods and moments -----------------------------------------------------------------------------

## Plays one of his moves (an animation in racoon_puppet.tscn), blending from wherever he is.
func play(anim_name: String, spot := Vector2.INF) -> void:
	if Engine.is_editor_hint() or not _anim.has_animation(anim_name):
		return
	puppet.look_from = spot
	puppet.look_to = spot
	puppet.point_spot = spot
	_fit_room(anim_name)
	_anim.play(anim_name, BLEND)
	if _pet and PET_ORBIT.has(anim_name):
		_pet.orbit()


## A move's walks and jumps shrink to fit the box he stands in (the nearest parent that clips,
## else the screen), so he's never cut off at its edge: the Closet's stage is narrow on a
## laptop and short on a phone.
func _fit_room(anim_name: String) -> void:
	var far := _move_reach(anim_name)
	if far == Vector2.ZERO:
		return   # nothing to fit (a move blending out of a walk keeps the walk's room)
	var box := get_viewport_rect()
	var n := get_parent()
	while n is CanvasItem:
		var box_node := n as Control
		if box_node and (box_node.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED or box_node.clip_contents):
			box = box_node.get_global_rect()
			break
		n = n.get_parent()
	var k := absf(puppet.get_global_transform().get_scale().x)
	if k <= 0.0:
		return
	var feet := get_global_transform() * Vector2(size.x / 2.0, size.y - 4.0)
	var roam := puppet.roam
	var rise := puppet.rise
	if far.x > 0.0:
		var side := minf((box.end.x - feet.x) / k - REACH_R, (feet.x - box.position.x) / k - REACH_L)
		roam = clampf(side / far.x, 0.0, 1.0)
	if far.y > 0.0:
		rise = clampf(((feet.y - box.position.y) / k - REACH_UP) / far.y, 0.0, 1.0)
	# eased over the blend, so cutting into a walk never makes him jump sideways
	if _room_tween:
		_room_tween.kill()
	_room_tween = create_tween().set_parallel()
	_room_tween.tween_property(puppet, "roam", roam, BLEND)
	_room_tween.tween_property(puppet, "rise", rise, BLEND)


## How far a move carries him: its furthest stroll and its highest hop, in drawing units.
func _move_reach(anim_name: String) -> Vector2:
	if not _reach.has(anim_name):
		var far := Vector2.ZERO
		var a := _anim.get_animation(anim_name)
		for t in a.get_track_count():
			var prop := String(a.track_get_path(t).get_concatenated_subnames())
			if prop == "stroll" or prop == "hop":
				for i in a.track_get_key_count(t):
					var v: float = a.track_get_key_value(t, i)
					if prop == "stroll":
						far.x = maxf(far.x, absf(v))
					else:
						far.y = maxf(far.y, v)
		_reach[anim_name] = far
	return _reach[anim_name]


func set_mood(m: String) -> void:
	mood = m
	play(MOODS.get(m, "idle"))
	if _pet:
		_pet.set_asleep(MOODS.get(m, "") == "sleepy")


## A lesson moment (D-024 board "Racoon in the game"): greet, right, hint, answer, rescue, rescue_won,
## level_up, complete, nudge, rest. Some point at or look at a spot on screen (a global position).
func moment(what: String, target := Vector2.INF) -> void:
	if MOMENTS.has(what):
		play(MOMENTS[what], _to_puppet(target))


## Look at a spot on screen (a global position) for a while, then back at you.
func look_at_point(target: Vector2, _seconds := 1.2) -> void:
	play("look", _to_puppet(target))


## Point at a spot on screen (a global position), then let the arm down.
func point_at(target: Vector2, _seconds := 1.6) -> void:
	play("point", _to_puppet(target))


## Read along a line of text (its start and end, global): his eyes follow the words with a small
## nod each, then a look back at you. Calm: no words of his own.
func read_along(from: Vector2, to: Vector2, _words := 5) -> void:
	play("read")
	puppet.look_from = _to_puppet(from)
	puppet.look_to = _to_puppet(to)


## His mouth moves for a while, as if saying a line.
func talk(seconds: float) -> void:
	puppet.talk(seconds)


func _on_finished(anim_name: StringName) -> void:
	if anim_name == &"sleepy":
		_anim.play("asleep")


## A global position (another Control's, say) in his drawing's units.
func _to_puppet(global_pos: Vector2) -> Vector2:
	if global_pos == Vector2.INF:
		return Vector2.INF
	return puppet.get_global_transform().affine_inverse() * global_pos


# --- outfit ----------------------------------------------------------------------------------------

func _apply_outfit() -> void:
	if puppet == null:
		return
	puppet.outfit = outfit
	_update_pet()
	var neck: String = outfit.get("neck", "")
	var want_scarf := Wardrobe.is_scarf(neck)
	var want_book: bool = outfit.get("paws", "") != ""   # the open book, a parol, the golden book...
	if want_scarf:
		puppet.scarf_item = neck
	if not is_inside_tree() or Engine.is_editor_hint():
		puppet.scarf_shown = 1.0 if want_scarf else 0.0
		puppet.book_shown = 1.0 if want_book else 0.0
		puppet.hold_book = 1.0 if want_book else 0.0
		return
	# putting one on pops it in with a little overshoot; taking it off is quicker
	var scarf_on := (puppet.scarf_shown > 0.5) != want_scarf
	var book_on := (puppet.book_shown > 0.5) != want_book
	if not scarf_on and not book_on:
		return
	if _outfit_tween:
		_outfit_tween.kill()
	_outfit_tween = create_tween().set_parallel()
	if scarf_on:
		_outfit_tween.tween_property(puppet, "scarf_shown", 1.0 if want_scarf else 0.0, 0.38 if want_scarf else 0.24) \
				.set_trans(Tween.TRANS_BACK if want_scarf else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if book_on:
		_outfit_tween.tween_property(puppet, "book_shown", 1.0 if want_book else 0.0, 0.38 if want_book else 0.24) \
				.set_trans(Tween.TRANS_BACK if want_book else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_outfit_tween.tween_property(puppet, "hold_book", 1.0 if want_book else 0.0, 0.32)


## His pet (D-029), from his outfit: a Pet inside his puppet, so it grows and shrinks with him.
func _update_pet() -> void:
	var id: String = outfit.get("pet", "")
	if Engine.is_editor_hint() or not Pet.has_kind(id):
		if _pet:
			_pet.queue_free()
			_pet = null
		return
	if _pet == null:
		_pet = Pet.new()
		_pet.name = "Pet"
		puppet.add_child(_pet)
	if _pet.kind != id:
		_pet.setup(id, puppet, still)


# --- input: his eyes follow your pointer, taps make him react -----------------------------------------

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or puppet == null:
		return
	if event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		puppet.follow_point = puppet.get_global_transform_with_canvas().affine_inverse() * event.position
		_mouse_t = Time.get_ticks_msec()
	# while the child is tapping about, he stays calm; his own moves wait for a quiet moment
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_quiet_since = Time.get_ticks_msec()


func _gui_input(event: InputEvent) -> void:
	if not react_to_taps:
		return
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	if tap:
		accept_event()
		if not accepts_tap():
			return
		_last_tap = Time.get_ticks_msec()
		_own_move = ""
		play(TAPS[_tap_n % TAPS.size()])
		_tap_n += 1
		tapped.emit()
		if _pet:
			_pet.cheer()   # his pet joins in, with little hearts


## Whether he'd take a tap now: he has finished his last reaction (a move of his own can be cut
## into) and what he was saying, and the last tap wasn't just now.
func accepts_tap() -> bool:
	if Time.get_ticks_msec() - _last_tap < TAP_REST_MS:
		return false
	if busy and String(_anim.current_animation) != _own_move:
		return false
	var speech := get_node_or_null("/root/Speech")
	return not (speech and speech.speaking())
