@tool
class_name RacoonPuppet
extends Node2D
## Racoon as a Godot scene: scenes/companion/racoon_puppet.tscn. One node per part of the drawing
## (tools/racoon-art/parts/racoon_C_inkscape.svg), each showing its rectangle of one sheet,
## assets/racoon/racoon_atlas.svg, plus an AnimationPlayer with one animation per move.
##
## The animations key the pose properties below (turn, hop, raise_right, eyes, ...). This script
## turns a pose into where each part goes, as if he were 3D: face parts slide round his head,
## an ear turning toward you comes in front of it, arms swing round the shoulder and stay joined,
## the tail curls, and parts swap in front of or behind each other as he turns.
## It also adds what isn't keyframed: breathing, blinking, ear springs, eyes following your pointer,
## and his mouth moving while he talks.
##
## The rig's measurements (shoulders, arm lengths, head size, tail line, colours) come from
## assets/racoon/racoon_rig.json, written by tools/racoon-art/motion-demo/build_racoon.py.
## Drawing units: the drawing's 400 x 400 page, feet near y = 386.

const RIG_PATH := "res://assets/racoon/racoon_rig.json"
const ATLAS_DIR := "res://assets/racoon/"
const FACE_SHADER := "res://scenes/companion/racoon_face_clip.gdshader"
const ITEM_SHADER := "res://scenes/companion/closet_item.gdshader"
const BELLY_SHADER := "res://scenes/companion/racoon_belly_clip.gdshader"
const CLOTHES_SHADER := "res://scenes/companion/racoon_clothes.gdshader"
const FUR_SHADER := "res://scenes/companion/racoon_cheek_fur.gdshader"
const DEPTH := 0.886      # his body's depth as a share of its width
const ARM_Z := 6.0
const HALO_BACK := 132.0     # how far behind his head's middle a halo floats (his head is 108 to the side)
const FOOT_Z := 12.0

static var _rig := {}
static var _tex := {}
static var _body_in := PackedVector2Array()
# The rig's fixed measurements, read once (the rig asks for them thousands of times a frame).
static var _c_art := {}
static var _c_ax := 200.0
static var _c_gy := 386.0
static var _c_hc := Vector2(200, 165)
static var _c_hr := Vector2(108, 92)
static var _unit_circles := {}       # n -> n points round a unit circle
static var _sleeves := {}            # arm -> its sleeve's outline, every third point (for the rim)
static var _grids := {}              # head, head_line -> their fine meshes round the cheek fur

# --- the pose: what the animations key ------------------------------------------------------------

@export_group("Body")
## Turns his whole body, in degrees: 90 faces your right, 180 shows his back.
@export var turn := 0.0:
	set(v):
		turn = v
		_setp("yaw", deg_to_rad(v))
## How high he hops, in drawing pixels.
@export var hop := 0.0:
	set(v):
		hop = v
		_setp("hop", -v)
## Squash and stretch: below 1 squashes him down, above 1 stretches him up.
@export var squash := 1.0:
	set(v):
		squash = v
		_setp("sq", v)
## Leans his body, in degrees.
@export var lean := 0.0:
	set(v):
		lean = v
		_setp("lean", v)
## A quick happy wiggle (0 to 1).
@export var wiggle := 0.0:
	set(v):
		wiggle = v
		_setp("wiggle", v)
## Walking (0 to 1): how much his feet step, arms swing and body bobs. Key `steps` to move
## through the walk cycle and `stroll` to move him along.
@export var walk := 0.0:
	set(v):
		walk = v
		_setp("walk", v)
## Steps taken (each step is half a walk cycle); keyed going up while he walks.
@export var steps := 0.0:
	set(v):
		steps = v
		_setp("steps", v)
## Moves him sideways, in drawing pixels (positive: to your right), shadow and all.
@export var stroll := 0.0:
	set(v):
		stroll = v
		_setp("strollX", v)
## How much of `stroll` he really moves (roam) and of `hop` he really rises (rise), 0 to 1.
## Raccoon sets them so a move stays inside his box; not keyed.
@export_range(0.0, 1.0) var roam := 1.0
@export_range(0.0, 1.0) var rise := 1.0
## Swings the tail behind a turn, in degrees.
@export var tail_swing := 0.0:
	set(v):
		tail_swing = v
		_setp("tailLag", deg_to_rad(v))

@export_group("Head")
## Turns his head, in degrees (on top of the body's turn).
@export var head_turn := 0.0:
	set(v):
		head_turn = v
		_setp("headYaw", deg_to_rad(v))
## Tips his head up (or down, below 0), in degrees.
@export var head_up := 0.0:
	set(v):
		head_up = v
		_setp("pitch", deg_to_rad(v))
## Tilts his head to the side, in degrees.
@export var head_tilt := 0.0:
	set(v):
		head_tilt = v
		_setp("roll", v)
## Where his eyes look, left (-1) to right (1).
@export var look_x := 0.0:
	set(v):
		look_x = v
		_setp("lookX", v)
## Where his eyes look, up (-1) to down (1).
@export var look_y := 0.0:
	set(v):
		look_y = v
		_setp("lookY", v)
## Tilts the left ear, in degrees.
@export var ear_left := 0.0:
	set(v):
		ear_left = v
		_setp("earL", v)
## Tilts the right ear, in degrees.
@export var ear_right := 0.0:
	set(v):
		ear_right = v
		_setp("earR", v)
## His eyes: open, closed or happy.
@export_enum("open", "closed", "happy") var eyes := "open":
	set(v):
		eyes = v
		_queue_update()
## His mouth: w (his smile), happy, open or o.
@export_enum("w", "happy", "open", "o") var mouth := "w":
	set(v):
		mouth = v
		_queue_update()

@export_group("Arms")
## Raises the left arm from where it hangs in the drawing, in degrees.
@export var raise_left := 0.0:
	set(v):
		raise_left = v
		_setp("liftL", deg_to_rad(v))
## Raises the right arm from where it hangs in the drawing, in degrees.
@export var raise_right := 0.0:
	set(v):
		raise_right = v
		_setp("liftR", deg_to_rad(v))
## How far the left paw reaches toward reach_left_to (0 to 1).
@export var reach_left := 0.0:
	set(v):
		reach_left = v
		_setp("armL", v)
## How far the right paw reaches toward reach_right_to (0 to 1).
@export var reach_right := 0.0:
	set(v):
		reach_right = v
		_setp("armR", v)
## Where the left paw reaches, in drawing pixels.
@export var reach_left_to := Vector2(150, 345):
	set(v):
		reach_left_to = v
		_setp("tLx", v.x)
		_setp("tLy", v.y)
## Where the right paw reaches, in drawing pixels.
@export var reach_right_to := Vector2(250, 345):
	set(v):
		reach_right_to = v
		_setp("tRx", v.x)
		_setp("tRy", v.y)
## Lets go of the book with the right paw (0 to 1).
@export var right_paw_free := 0.0:
	set(v):
		right_paw_free = v
		_setp("freeR", v)
## The paws' size (1 as drawn).
@export var paw_size := 1.0:
	set(v):
		paw_size = v
		_setp("pawS", v)
## A knock with the right paw (0 to 1).
@export var knock := 0.0:
	set(v):
		knock = v
		_setp("knock", v)

@export_group("Spot on screen")
## How much he looks at the spot the game gives him (a question, a picture) (0 to 1).
@export var look_at_spot := 0.0:
	set(v):
		look_at_spot = v
		_setp("lookBlend", v)
## Moves his gaze along a line of text, from its start (0) to its end (1).
@export var read_along := 0.0:
	set(v):
		read_along = v
		_setp("lookSweep", v)
## How much the right paw points at the spot instead of reach_right_to (0 to 1).
@export var point_at_spot := 0.0:
	set(v):
		point_at_spot = v
		_setp("pointBlend", v)

@export_group("Closet")
## The open book in his paws (0 to 1).
@export var book_shown := 0.0:
	set(v):
		book_shown = v
		_setp("bookS", v)
## How firmly his paws hold the book's edges (0 to 1).
@export var hold_book := 0.0:
	set(v):
		hold_book = v
		_setp("hold", v)
## The scarf round his neck (0 to 1).
@export var scarf_shown := 0.0:
	set(v):
		scarf_shown = v
		_setp("scarfS", v)
## Which scarf he wears (an item id in content/closet.json): its band and knot textures.
@export var scarf_item := "scarf_teal":
	set(v):
		scarf_item = v
		_wear.scarf = v
		_queue_update()
## Rina, the girl buddy: the same raccoon with eyelashes, rosier cheeks, pink inner ears and a
## bow on her head (hidden under a hat), so every Closet item still fits her.
@export var girl := false:
	set(v):
		girl = v
		_queue_update()

# --- set by the game (not keyframed) ---------------------------------------------------------------

## What he wears, {slot: item id} (scripts/core/wardrobe.gd): hat, eyes (glasses), neck, top, paws.
## A pet belongs to the Raccoon node: it floats beside his head, inside this puppet.
## Each item is its texture on its slot's Closet sheet (assets/racoon/closet/hats.svg...).
var outfit := {}:
	set(v):
		outfit = v
		_queue_update()
## Drawn once and then left still (the Closet's small cards).
var still := false
## True while an animation plays: his eyes stop following your pointer.
var acting := false
## The spot to look at or point at (drawing units), and the line to read along.
var look_from := Vector2.INF
var look_to := Vector2.INF
var point_spot := Vector2.INF
## Your pointer (drawing units), which his eyes follow between moves; INF when it's away.
var follow_point := Vector2.INF

var pose := {}              # the keyed pose, in the rig's own units
var p := {}                 # the pose this frame: keyed, plus the spot, the pointer and the springs
var _f := {}                # where every part goes this frame
var _queued := false
var _now := 0.0
var _last_draw := -1000.0
var _talk_until := 0.0
var _blink_at := 0.0
var _blink_until := 0.0
var _twitch_at := 0.0
var _twitch2 := {}
var _ear_s := [{"ang": 0.0, "vel": 0.0}, {"ang": 0.0, "vel": 0.0}]
var _ear_lag := {"ang": 0.0, "vel": 0.0}
var _fur := [{"ang": 0.0, "vel": 0.0}, {"ang": 0.0, "vel": 0.0}]   # the cheek tufts' springs, left, right
var _fur_mat: ShaderMaterial
var _prev_th := 0.0
var _prev_hop := 0.0
var _follow := {"lookX": 0.0, "lookY": 0.0, "headYaw": 0.0, "pitch": 0.0}
var _wear := {"scarf": "scarf_teal"}

# the nodes
var _shadow: Polygon2D
var _body: Node2D
var _tail_n: Polygon2D
var _book: Polygon2D
var _arms: Array = []       # [{node, fill, rim, outline}] left, right
var _feet: Array = []
var _torso: Polygon2D
var _belly: Polygon2D
var _chest_items: Node2D
var _top: Polygon2D
var _scarf_band: Polygon2D
var _scarf_knot: Polygon2D
var _neck_items: Node2D
var _neck_item: Polygon2D
var _head: Node2D
var _ears: Array = []       # [{node, inner}] left, right
var _muzzle_side: Node2D
var _skull: Polygon2D
var _face: Node2D
var _decals := {}
var _eyes_n: Node2D
var _blush_n: Node2D
var _head_line: Polygon2D
var _ear_fronts: Node2D
var _muzzle_n: Polygon2D
var _nose_n: Node2D
var _mouth_n: Node2D
var _head_items: Node2D
var _glasses: Polygon2D
var _hat: Polygon2D
var _wind: WindScarf          # a diamond scarf's long ends, in the wind
var _halo: Halo               # the Star halo behind his head
var _bow_n: Node2D            # Rina's bow

## Rina's colours: her cheeks, the tint on her inner ears, and her bow.
const GIRL_BLUSH := "#ff6f93"
const GIRL_EAR := Color(1.0, 0.72, 0.84)
const BOW := "#ff5c8f"
const BOW_DARK := "#e0336f"
const BOW_SHINE := "#ffd1e0"


func _init() -> void:
	_load_rig()
	pose = _rest()
	pose.merge({"hold": 0.0, "bookS": 0.0, "scarfS": 0.0})
	if not _art().is_empty():
		reach_left_to = _rest_tip(0)
		reach_right_to = _rest_tip(1)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _ready() -> void:
	if _art().is_empty():
		return
	_ensure_nodes()
	var now := Time.get_ticks_msec()
	_blink_at = now + 1200 + randf() * 2400
	_twitch_at = now + 2500 + randf() * 2500
	_queue_update()   # once, at the end of the frame, after the game has set his size and outfit


func _setp(key: String, v: float) -> void:
	pose[key] = v
	_queue_update()


func _queue_update() -> void:
	if _queued:
		return
	_queued = true
	_update.call_deferred()


## His mouth moves for a while, as if saying a line.
func talk(seconds: float) -> void:
	_talk_until = Time.get_ticks_msec() + seconds * 1000.0
	_queue_update()


static func _load_rig() -> void:
	if not _rig.is_empty():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(RIG_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("RacoonPuppet: can't read %s" % RIG_PATH)
		return
	_rig = data
	_c_art = _rig.get("art", {})
	_c_ax = float(_c_art.get("ax", 200.0))
	_c_gy = float(_c_art.get("ground", 386.0))
	var c: Array = _c_art.get("head", {}).get("c", [200, 165])
	var r: Array = _c_art.get("head", {}).get("r", [108, 92])
	_c_hc = Vector2(c[0], c[1])
	_c_hr = Vector2(r[0], r[1])


## The sheet a part is on, imported at twice the drawing's size: Racoon himself on
## assets/racoon/racoon_atlas.svg, his Closet items on one sheet per slot in assets/racoon/closet/
## (hats.svg, neck.svg...). Null for a part the rig doesn't have.
static func _t(tex_name: String) -> Texture2D:
	var t: Dictionary = _rig.get("textures", {}).get(tex_name, {})
	if t.is_empty():
		return null
	var sheet: String = t.get("sheet", "body")
	if not _tex.has(sheet):
		_tex[sheet] = load(ATLAS_DIR + str(_rig.sheets[sheet].file))
	return _tex[sheet]


## Where a part is on its sheet, in the texture's pixels.
static func _region(tex_name: String) -> Rect2:
	var t: Dictionary = _rig.textures[tex_name]
	var a: Array = t.atlas
	var units: Array = _rig.sheets[t.get("sheet", "body")].size
	var tx := _t(tex_name)
	var k := tx.get_size() / Vector2(units[0], units[1])
	return Rect2(Vector2(a[0], a[1]) * k, Vector2(a[2], a[3]) * k)


# --- the nodes -------------------------------------------------------------------------------------

## Finds the scene's nodes, or makes any that are missing (RacoonPuppet.new(), or the scene builder).
func _ensure_nodes() -> void:
	_shadow = _child(self, "Shadow", Polygon2D)
	_body = _child(self, "Body", Node2D)
	_tail_n = _child(_body, "Tail", Polygon2D)
	_book = _child(_body, "Book", Polygon2D)
	_arms = []
	for side in ["Left", "Right"]:
		var arm := _child(_body, "Arm" + side, Node2D)
		_arms.append({"node": arm, "fill": _child(arm, "Fill", Polygon2D), "rim": _child(arm, "Rim", Node2D),
			"outline": _child(arm, "Outline", Polygon2D)})
	_feet = [_child(_body, "FootLeft", Polygon2D), _child(_body, "FootRight", Polygon2D)]
	_torso = _child(_body, "Torso", Polygon2D)
	_belly = _child(_body, "Belly", Polygon2D)
	_chest_items = _child(_body, "ChestItems", Node2D)
	_top = _child(_chest_items, "Top", Polygon2D)
	_scarf_band = _child(_body, "ScarfBand", Polygon2D)
	_scarf_knot = _child(_body, "ScarfKnot", Polygon2D)
	_neck_items = _child(_body, "NeckItems", Node2D)
	_neck_item = _child(_neck_items, "Item", Polygon2D)
	_wind = _child(_body, "WindScarf", WindScarf)
	_halo = _child(_body, "Halo", Halo)
	_head = _child(_body, "Head", Node2D)
	_ears = []
	for side in ["Left", "Right"]:
		var ear := _child(_head, "Ear" + side, Polygon2D)
		_ears.append({"node": ear, "inner": _child(ear, "Inner", Polygon2D)})
	_muzzle_side = _child(_head, "MuzzleSide", Node2D)
	_skull = _child(_head, "Skull", Polygon2D)
	_face = _child(_head, "Face", Node2D)
	_decals = {"brow_l": _child(_face, "BrowLeft", Polygon2D), "brow_r": _child(_face, "BrowRight", Polygon2D),
		"mask": _child(_face, "Mask", Polygon2D)}
	_eyes_n = _child(_face, "Eyes", Node2D)
	_blush_n = _child(_face, "Blush", Node2D)
	_head_line = _child(_head, "HeadLine", Polygon2D)
	_ear_fronts = _child(_head, "EarFronts", Node2D)
	_muzzle_n = _child(_head, "Muzzle", Polygon2D)
	_nose_n = _child(_head, "Nose", Node2D)
	_mouth_n = _child(_head, "Mouth", Node2D)
	_head_items = _child(_head, "HeadItems", Node2D)
	_glasses = _child(_head_items, "Glasses", Polygon2D)
	_hat = _child(_head_items, "Hat", Polygon2D)
	_bow_n = _child(_head_items, "Bow", Node2D)
	for n: CanvasItem in _face.get_children():
		n.use_parent_material = true
	if _face.material == null:
		var mat := ShaderMaterial.new()
		mat.shader = load(FACE_SHADER)
		_face.material = mat
	var head: Dictionary = _rig.textures.head
	var head_uv := _region("head")
	head_uv = Rect2(head_uv.position / _t("head").get_size(), head_uv.size / _t("head").get_size())
	(_face.material as ShaderMaterial).set_shader_parameter("head_mask", _t("head"))
	(_face.material as ShaderMaterial).set_shader_parameter("head_rect", Vector4(head.box[0], head.box[1], head.box[2], head.box[3]))
	(_face.material as ShaderMaterial).set_shader_parameter("head_uv", Vector4(head_uv.position.x, head_uv.position.y, head_uv.size.x, head_uv.size.y))
	# the belly is clipped to his body's fill, so its white never covers his outline
	if _belly.material == null or (_belly.material as ShaderMaterial).shader == null:
		var bm := ShaderMaterial.new()
		bm.shader = load(BELLY_SHADER)
		_belly.material = bm
	var body: Dictionary = _rig.textures.body
	var body_uv := _region("body")
	body_uv = Rect2(body_uv.position / _t("body").get_size(), body_uv.size / _t("body").get_size())
	var bmat := _belly.material as ShaderMaterial
	bmat.set_shader_parameter("body_tex", _t("body"))
	bmat.set_shader_parameter("body_rect", Vector4(body.box[0], body.box[1], body.box[2], body.box[3]))
	bmat.set_shader_parameter("body_uv", Vector4(body_uv.position.x, body_uv.position.y, body_uv.size.x, body_uv.size.y))
	var ink := _col(_rig.colors.ink)
	bmat.set_shader_parameter("ink", Vector3(ink.r, ink.g, ink.b))
	# the parts that only move: their textures, laid on their boxes (always once here, so a scene
	# saved before the sheets were rebuilt gets their new places)
	for pair in [[_feet[0], "foot_l"], [_feet[1], "foot_r"], [_torso, "body"], [_belly, "belly"],
			[_muzzle_n, "muzzle"], [_ears[0].node, "earL"], [_ears[0].inner, "earL_in"],
			[_ears[1].node, "earR"], [_ears[1].inner, "earR_in"], [_book, "open_book"], [_scarf_band, "scarf_teal.band"],
			[_scarf_knot, "scarf_teal.knot"]]:
		pair[0].set_meta("tex", "")
		_set_quad_tex(pair[0], pair[1])
	# his head and its outline: a fine mesh round the little tufts of fur on his cheeks, which sway
	# (racoon_cheek_fur.gdshader bends them; their springs are in _process)
	_set_grid(_skull, "head")
	_set_grid(_head_line, "head_line")
	if _fur_mat == null:
		_fur_mat = ShaderMaterial.new()
		_fur_mat.shader = load(FUR_SHADER)
	for f in _art().get("cheekFur", []):
		var key := "_l" if float(f.side) < 0.0 else "_r"
		_fur_mat.set_shader_parameter("tip" + key, Vector2(f.tip[0], f.tip[1]))
		_fur_mat.set_shader_parameter("root" + key, Vector2(f.root[0], f.root[1]))
	_skull.material = _fur_mat
	_head_line.material = _fur_mat
	# the parts drawn in code
	var drawers := [[_arms[0].rim, _draw_rim.bind(0)], [_arms[1].rim, _draw_rim.bind(1)],
		[_muzzle_side, _draw_muzzle_side], [_eyes_n, _draw_eyes], [_blush_n, _draw_blush],
		[_ear_fronts, _draw_ear_fronts], [_nose_n, _draw_nose], [_mouth_n, _draw_mouth_node], [_bow_n, _draw_bow]]
	for d in drawers:
		var n: Node2D = d[0]
		if not n.draw.is_connected(d[1]):
			n.draw.connect(d[1])


## The middle of his head now, in drawing units: a pet floats beside it.
func head_point() -> Vector2:
	if _body == null or _head == null:
		return _hc()
	return _body.transform * (_head.transform * _hc())


func _child(parent: Node, node_name: String, type) -> Node:
	var n := parent.get_node_or_null(node_name)
	if n == null:
		n = type.new()
		n.name = node_name
		parent.add_child(n)
	return n


## A part that only moves: its texture on a quad over its box (drawing units), at most once per texture.
func _set_quad_tex(node: Polygon2D, tex_name: String) -> void:
	if node.get_meta("tex", "") == tex_name and node.texture != null:
		return
	var tx := _t(tex_name)
	if tx == null:
		return
	var b := _box(tex_name)
	var r := _region(tex_name)
	node.texture = tx
	node.polygon = PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)])
	node.uv = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	node.polygons = []
	node.vertex_colors = PackedColorArray()
	node.set_meta("tex", tex_name)
	node.remove_meta("tris")


## His head or its outline on a mesh that's fine round the little tufts of fur on his cheeks (so the
## cheek fur shader can bend them) and coarse elsewhere. The same for every Racoon: built once.
func _set_grid(node: Polygon2D, tex_name: String) -> void:
	if not _grids.has(tex_name):
		var box := _box(tex_name)
		var fur: Array = _art().get("cheekFur", [])
		var xs := _grid_steps(box.position.x, box.end.x, fur.map(func(f): return float(f.tip[0])))
		var ys := _grid_steps(box.position.y, box.end.y, fur.map(func(f): return float(f.tip[1])))
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for x in xs:
			for y in ys:
				pts.append(Vector2(x, y))
				uvs.append(Vector2((x - box.position.x) / box.size.x, (y - box.position.y) / box.size.y))
		_grids[tex_name] = {"pts": pts, "uvs": uvs, "idx": _grid_idx(xs.size(), ys.size())}
	_set_mesh(node, tex_name, _grids[tex_name])


## A Closet item wrapped round an upright axis: each point of its drawing sits on a round
## cross-section as wide as the item is at that height (its profile, from the build), turned by `yaw`
## and tipped with his head (`cp`, `sp`). `depth` < 1 makes the cross-section an oval (his body).
## The front faces you at rest; `back_tex` (or the front mirrored, if it's the same texture) is the
## far side. Darker toward the edges; what's behind him fades out.
## With `views` (hats): a flat drawing can't show a hat's side, so the front turns half as far as he
## does, and between 84 and 96 degrees it crossfades to the back drawing, which turns the same way.
func _wrap_mesh(front_tex: String, back_tex: String, axis: float, pivot_y: float, yaw: float, cp: float,
		sp: float, depth: float, cols: int, rows: int, views := false) -> Dictionary:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	var w := _wrap_pi(yaw)
	var to_back := _sstep(1.466, 1.676, absf(w)) if views else 0.0
	for side: int in ([0, 1] if back_tex != "" else [0]):
		var tex := front_tex if side == 0 else back_tex
		var mirrored: bool = side == 1 and back_tex == front_tex
		var fade := 1.0
		var spin := yaw
		var behind := PI if side == 1 else 0.0
		if views:
			fade = (1.0 - to_back) if side == 0 else to_back
			spin = (w if side == 0 else _wrap_pi(w - PI)) * 0.5
			behind = 0.0
			if fade < 0.01:
				continue
		var cy := cos(spin)
		var sy := sin(spin)
		var box := _box(tex)
		var reg := _region(tex)
		var prof: Dictionary = _rig.textures[tex].get("profile", {})
		var base := pts.size()
		for i in cols:
			for j in rows:
				var u := float(i) / (cols - 1)
				var v := float(j) / (rows - 1)
				var q := box.position + Vector2(u * box.size.x, v * box.size.y)
				var r := _profile_r(prof, q.y, box)
				var lam := asin(clampf((q.x - axis) / r, -1.0, 1.0)) + behind
				var x := r * sin(lam) * cy + r * depth * cos(lam) * sy
				var z := -r * sin(lam) * sy + r * depth * cos(lam) * cy
				var facing := z / maxf(r * depth, 0.001)
				pts.append(Vector2(axis + x, pivot_y + (q.y - pivot_y) * cp - z * sp))
				uvs.append(reg.position + Vector2((1.0 - u) if mirrored else u, v) * reg.size)
				var shade := 0.78 + 0.22 * clampf(facing, 0.0, 1.0)
				colors.append(Color(shade, shade, shade, _sstep(-0.22, 0.0, facing) * fade))
		for k in _grid_idx(cols, rows):
			idx.append(base + k)
	return {"pts": pts, "uv": uvs, "cols": colors, "idx": idx}


## How wide an item is at height y (its profile from the build; half its box without one).
func _profile_r(prof: Dictionary, y: float, box: Rect2) -> float:
	var rs: Array = prof.get("r", [])
	if rs.is_empty():
		return maxf(box.size.x / 2.0, 6.0)
	var t := clampf((y - float(prof.y0)) / float(prof.step), 0.0, rs.size() - 1.0)
	var i := mini(int(t), rs.size() - 2) if rs.size() > 1 else 0
	if rs.size() == 1:
		return float(rs[0])
	return lerpf(float(rs[i]), float(rs[i + 1]), t - i)


## A wrapped item's mesh on its node (uvs already in the sheet's pixels).
func _set_wrap(node: Polygon2D, tex_name: String, m: Dictionary) -> void:
	var tx := _t(tex_name)
	if node.texture != tx:
		node.texture = tx
	node.polygon = m.pts
	node.uv = m.uv
	node.vertex_colors = m.cols
	var idx: PackedInt32Array = m.idx
	if node.polygons.size() * 3 != idx.size():
		var polys := []
		for i in range(0, idx.size(), 3):
			polys.append(PackedInt32Array([idx[i], idx[i + 1], idx[i + 2]]))
		node.polygons = polys
	node.set_meta("tex", "")


## Grid lines from a to b: every 4 units within 26 of any of `near`, every 36 elsewhere.
static func _grid_steps(a: float, b: float, near: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array([a])
	var x := a
	while x < b - 0.01:
		var close := false
		for n in near:
			if absf(x - float(n)) < 26.0:
				close = true
		x = minf(b, x + (4.0 if close else 36.0))
		out.append(x)
	return out


## A part that bends (the tail, the arms, the face parts): its texture on a mesh the rig moves.
func _set_mesh(node: Polygon2D, tex_name: String, m: Dictionary) -> void:
	if m.is_empty():
		node.visible = false
		return
	node.visible = true
	var tx := _t(tex_name)
	if node.texture != tx:
		node.texture = tx
	var r := _region(tex_name)
	var uvs: PackedVector2Array = m.uvs
	# the mesh's uvs run 0-1 over the part; on the sheet they're its rectangle
	var uv: PackedVector2Array = Transform2D(Vector2(r.size.x, 0), Vector2(0, r.size.y), r.position) * uvs
	node.polygon = m.pts
	node.uv = uv
	var idx: PackedInt32Array = m.idx
	# rebuild the triangles when the count is wrong (a scene saved with this part as a plain quad
	# keeps no triangles, whatever it was marked)
	if node.get_meta("tris", -1) != idx.size() or node.polygons.size() * 3 != idx.size():
		var polys := []
		for i in range(0, idx.size(), 3):
			polys.append(PackedInt32Array([idx[i], idx[i + 1], idx[i + 2]]))
		node.polygons = polys
		node.set_meta("tris", idx.size())
	var cols: PackedColorArray = m.get("cols", PackedColorArray())
	node.vertex_colors = cols


# --- every frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _art().is_empty() or not is_visible_in_tree() or still:
		return
	_now = Time.get_ticks_msec()
	var dt := minf(delta, 0.05)
	var active := acting
	# between moves his eyes follow your pointer, quickly, and his head more slowly
	var tgt := {"lookX": 0.0, "lookY": 0.0, "headYaw": 0.0, "pitch": 0.0}
	if not acting and follow_point != Vector2.INF:
		var d := follow_point - Vector2(_ax() + p.strollX * roam, _hc().y)
		tgt = {"lookX": clampf(d.x / 340.0, -1, 1), "lookY": clampf(d.y / 340.0, -1, 1),
			"headYaw": clampf(d.x / 1400.0, -0.45, 0.45), "pitch": clampf(-d.y / 2600.0, -0.17, 0.17)}
	for key in tgt:
		var tau: float = {"lookX": 0.06, "lookY": 0.06, "headYaw": 0.2, "pitch": 0.24}[key]
		var before: float = _follow[key]
		_follow[key] = before + (tgt[key] - before) * (1.0 - exp(-dt / tau))
		if absf(_follow[key] - before) > 0.0005:
			active = true
	# ears trail behind quick turns and hops, bounce back, and twitch now and then
	if not p.is_empty():
		var th_now: float = p.yaw + p.headYaw
		var hop_now: float = _lifted(p.hop) - absf(sin(p.steps * PI)) * 7.0 * p.walk
		var yaw_rate := _wrap_pi(th_now - _prev_th) / maxf(dt, 0.001)
		var hop_rate := (hop_now - _prev_hop) / maxf(dt, 0.001)
		_prev_th = th_now
		_prev_hop = hop_now
		var ears: Array = _art().ears
		if not acting and _now > _twitch_at:
			var j := 0 if randf() < 0.5 else 1
			_ear_s[j].vel += ears[j].side * (480.0 + randf() * 140.0)
			if randf() < 0.4:
				_twitch2 = {"j": j, "at": _now + 150}
			_twitch_at = _now + 3500 + randf() * 5000
		if not _twitch2.is_empty() and _now > _twitch2.at:
			_ear_s[_twitch2.j].vel += ears[_twitch2.j].side * 420.0
			_twitch2 = {}
		for j in 2:
			var e: Dictionary = _ear_s[j]
			var side: float = ears[j].side
			var target := clampf(-side * hop_rate * 0.03 + side * (1.0 - p.sq) * 60.0, -24, 24)
			e.vel += (576.0 * (target - e.ang) - 18.0 * e.vel) * dt
			e.ang += e.vel * dt
			if absf(e.vel) > 0.5 or absf(e.ang) > 0.05:
				active = true
		var lg := _ear_lag
		lg.vel += (110.0 * (clampf(-yaw_rate * 0.1, -0.3, 0.3) - lg.ang) - 12.0 * lg.vel) * dt
		lg.ang += lg.vel * dt
		# the little tufts of fur on his cheeks flick behind quick turns and hops, droop as he lands,
		# and stir a little on their own. Only a shader setting changes, so they don't keep the rig busy.
		for j in 2:
			var fs: Dictionary = _fur[j]
			var side := -1.0 if j == 0 else 1.0
			var stir := sin(_now * 0.0017 + j * 2.1) * 0.05 + sin(_now * 0.0043 + j) * 0.025
			var droop := -hop_rate * 0.0016 + (1.0 - float(p.sq)) * 1.6
			var target := clampf(side * droop - yaw_rate * 0.05, -0.55, 0.55) + stir
			fs.vel += (260.0 * (target - fs.ang) - 9.0 * fs.vel) * dt
			fs.ang += fs.vel * dt
		if _fur_mat:
			_fur_mat.set_shader_parameter("ang_l", clampf(_fur[0].ang, -0.6, 0.6))
			_fur_mat.set_shader_parameter("ang_r", clampf(_fur[1].ang, -0.6, 0.6))
	if _now > _blink_at:
		_blink_until = _now + 120
		_blink_at = _now + (280.0 if randf() < 0.18 else 2400.0 + randf() * 3200.0)
	if _now < _blink_until + 40 or _now < _talk_until + 100:
		active = true
	# idle, only breathing and the tail's sway: a lighter update, 20 times a second
	if active or _now - _last_draw >= 50.0:
		_queue_update()


## The pose this frame: the keyed pose, plus the spot on screen, your pointer and the springs.
func _effective() -> Dictionary:
	var e := pose.duplicate()
	if look_from != Vector2.INF and float(e.lookBlend) > 0.001:
		var lv := _look_vals(look_from.lerp(look_to if look_to != Vector2.INF else look_from, e.lookSweep))
		for k in lv:
			e[k] += lv[k] * e.lookBlend
	for k in _follow:
		e[k] += _follow[k]
	if point_spot != Vector2.INF and float(e.pointBlend) > 0.001:
		var aim := _aim_at(1, point_spot, e.yaw)
		e.tRx = lerpf(e.tRx, aim.x, e.pointBlend)
		e.tRy = lerpf(e.tRy, aim.y, e.pointBlend)
	return e


## Where a paw goes to point at a spot: toward it, as far as the arm can stretch.
func _aim_at(j: int, t: Vector2, yaw: float) -> Vector2:
	var A: Dictionary = _art().arms[j]
	var s := _shoulder(j, yaw)
	var d := t - s
	var dl := maxf(d.length(), 0.001)
	return s + d / dl * minf(A.len * 1.45, dl)


## Works out the frame and moves every node.
func _update() -> void:
	_queued = false
	if _art().is_empty() or not is_node_ready() or _body == null:
		return
	if Engine.is_editor_hint():
		_now = 0.0
	_last_draw = _now
	p = _effective()
	_f = _rig_frame()
	_apply()


func _apply() -> void:
	var f := _f
	_body.transform = f.bodyT
	_head.transform = f.headT
	var s: Dictionary = f.shadow
	_shadow.polygon = _ellipse(s.c, s.rx, s.ry, 32)
	_shadow.color = Color(0.23, 0.16, 0.12, s.a)
	_set_mesh(_tail_n, "tail", f.tail)
	for i in 2:
		_feet[i].transform = f.feet[i].xf
	_torso.transform = f.bodyXf
	_belly.visible = f.belly.on
	_belly.transform = f.belly.xf
	if f.belly.on:
		# where a belly point lands on the body's texture: the body as drawn (bodyXf) undone
		var to_body: Transform2D = f.bodyXf.affine_inverse() * f.belly.xf
		var bmat := _belly.material as ShaderMaterial
		bmat.set_shader_parameter("to_body_x", to_body.x)
		bmat.set_shader_parameter("to_body_y", to_body.y)
		bmat.set_shader_parameter("to_body_o", to_body.origin)
	var sc: Dictionary = f.scarf
	_scarf_band.visible = not sc.is_empty()
	_scarf_knot.visible = not sc.is_empty() and sc.knotOn
	if not sc.is_empty():
		var scarf: String = str(sc.item) if _has_tex(str(sc.item) + ".band") else "scarf_teal"
		_wear_tex(_scarf_band, scarf, scarf + ".band")
		_wear_tex(_scarf_knot, scarf, scarf + ".knot")
		_scarf_band.transform = sc.band
		_scarf_knot.transform = sc.knot
	var bk: Dictionary = f.book
	_book.visible = not bk.is_empty()
	if not bk.is_empty():
		# whatever he holds in his paws (the open book, a parol...), from behind when he turns
		var paws: String = outfit.get("paws", "open_book")
		if not _has_tex(paws):
			paws = "open_book"
		var back := paws + ".back"
		_wear_tex(_book, paws, back if bk.slot == "bb" and _has_tex(back) else paws)
		_book.transform = bk.xf
	for j in 2:
		var arm: Dictionary = f.arms[j]
		var key := "armL" if j == 0 else "armR"
		_set_mesh(_arms[j].fill, key + "_fill", arm.fill)
		_set_mesh(_arms[j].outline, key + "_band", arm.get("band", {}))
	# head: the ears (the nearer one drawn last), the muzzle, the face parts
	for e in f.ears:
		var ear: Dictionary = _ears[0] if e.name == "earL" else _ears[1]
		ear.node.transform = e.xf
		ear.inner.transform = e.inner
		ear.inner.color = _ear_tint(e.innerA)
	for i in f.ears.size():
		var en: Node = (_ears[0] if f.ears[i].name == "earL" else _ears[1]).node
		if en.get_index() != i:
			_head.move_child(en, i)
	var M: Dictionary = _art().muzzle
	_muzzle_n.visible = f.muz.on
	if f.muz.on:
		var c0 := _hc() + Vector2(M.c[0], M.c[1])
		_muzzle_n.transform = Transform2D(0, f.muz.c) * Transform2D(Vector2(f.muz.rx / M.rx, 0), Vector2(0, 1), Vector2.ZERO) * Transform2D(0, -c0)
	for decal in _decals:
		_set_mesh(_decals[decal], decal, f.decals[decal])
	_apply_items(f)
	_order_body()
	for n: CanvasItem in [_arms[0].rim, _arms[1].rim, _muzzle_side, _eyes_n, _blush_n, _ear_fronts,
			_nose_n, _mouth_n, _bow_n]:
		n.queue_redraw()


## Back to front, as he turns: what's behind the body, the body, what's in front of it, his head, and
## an arm or the book raised in front of his head.
func _order_body() -> void:
	var f := _f
	var order: Array = []
	# a halo and a windblown scarf are behind everything, unless he is turned away
	var wind_front: bool = _wind.visible and f.get("wind", {}).get("front", false)
	var halo_front: bool = _halo.visible and f.halo.front
	if not halo_front:
		order.append(_halo)
	if not wind_front:
		order.append(_wind)
	var arms_in := func(slot: String) -> Array:
		var out := []
		for j in 2:
			if f.arms[j].slot == slot:
				out.append(_arms[j].node)
		return out
	var bk: Dictionary = f.book
	var book_slot: String = bk.get("slot", "")
	if bk.is_empty():
		order.append(_book)
	if not f.tail.front:
		order.append(_tail_n)
	if book_slot == "bb":
		order.append(_book)
	order.append_array(arms_in.call("b"))
	order.append_array([_feet[0], _feet[1]] if f.feet[0].z <= f.feet[1].z else [_feet[1], _feet[0]])
	order.append_array([_torso, _belly, _chest_items])
	# the scarf and neck items sit on his neck, under both arms: an arm that goes behind a tail
	# sticking toward you ("mb", while he walks to the left) still stays in front of the scarf
	order.append_array([_scarf_band, _scarf_knot, _neck_items])
	if wind_front:
		order.append(_wind)
	order.append_array(arms_in.call("mb"))
	if f.tail.front:
		order.append(_tail_n)
	if book_slot == "bm":
		order.append(_book)
	order.append_array(arms_in.call("m"))
	order.append(_head)
	if halo_front:
		order.append(_halo)
	if book_slot == "bf":
		order.append(_book)
	order.append_array(arms_in.call("f"))
	for i in order.size():
		var n: Node = order[i]
		if n.get_index() != i:
			_body.move_child(n, i)


# --- the parts drawn in code -----------------------------------------------------------------------

func _draw_rim(j: int) -> void:
	if _f.is_empty():
		return
	var arm: Dictionary = _f.arms[j]
	for piece: PackedVector2Array in arm.get("rim", []):
		_arms[j].rim.draw_polyline(piece, _col(_rig.colors.ink), arm.rimW / 2.0, true)


func _draw_mouth_node() -> void:
	if not _f.is_empty():
		_draw_mouth(_mouth_n)


## In profile, the muzzle's outline shows where it stands out from his head.
func _draw_muzzle_side() -> void:
	if _f.is_empty() or not _f.muz.on:
		return
	var ring := _ellipse(_f.muz.c, _f.muz.rx, float(_art().muzzle.ry), 36)
	ring.append(ring[0])
	_muzzle_side.draw_polyline(ring, _col(_rig.colors.ink), float(_rig.colors.headLine) * 2.0, true)


func _draw_eyes() -> void:
	if _f.is_empty():
		return
	var ci := _eyes_n
	var colors: Dictionary = _rig.colors
	for i in 2:
		var e: Dictionary = _f.eyes[i]
		if e.a <= 0.01:
			continue
		var E: Dictionary = _art().eyes[i]
		var ec: Dictionary = colors.eyes[i]
		if e.mode == "open":
			Smooth.polygon(ci, _ellipse(e.c, maxf(0.3, E.r * e.fs), E.r, 32), _col(ec.white, e.a))
			Smooth.polygon(ci, _ellipse(e.pupil, maxf(0.2, E.pupil[2] * e.fs), E.pupil[2], 28), _col(ec.pupil, e.a))
			for g in E.glints.size():
				var gl: Array = E.glints[g]
				var gc: Array = ec.glints[g] if g < ec.glints.size() else ["#ffffff", 1.0]
				Smooth.polygon(ci, _ellipse(e.pupil + Vector2(gl[0] * e.fs, gl[1]), maxf(0.1, gl[2] * e.fs), gl[2], 16), _col(gc[0], gc[1] * e.a))
			if girl:
				_draw_lashes(ci, e, E.r, -1.0 if i == 0 else 1.0, _col(ec.white, e.a))
		else:
			var arc := [[-11.0, -0.92], [0.0, 9.2], [11.0, -0.92]] if e.mode == "closed" else [[-11.0, 4.6], [0.0, -11.96], [11.0, 4.6]]
			var pts := _quad(e.c + Vector2(arc[0][0] * e.ks * e.fs, arc[0][1] * e.ks), e.c + Vector2(arc[1][0] * e.ks * e.fs, arc[1][1] * e.ks),
					e.c + Vector2(arc[2][0] * e.ks * e.fs, arc[2][1] * e.ks))
			ci.draw_polyline(pts, _col(ec.white, e.a), (5.0 if e.mode == "closed" else 5.5) * e.ks, true)
			if girl:
				# two lashes at the outer end of a closed eye
				var s := -1.0 if i == 0 else 1.0
				var end: Vector2 = pts[0] if s < 0.0 else pts[pts.size() - 1]
				for k in 2:
					var dir := Vector2(s * (0.95 - 0.5 * k), -0.35 - 0.75 * k).normalized()
					_lash(ci, end, Vector2(dir.x * e.fs, dir.y), 6.5 * e.ks, 2.6 * e.ks, _col(ec.white, e.a))


func _draw_blush() -> void:
	if _f.is_empty():
		return
	for b in _f.blush:
		if b.a > 0.01:
			if girl:
				Smooth.polygon(_blush_n, _ellipse(b.c, b.rx * 1.12, b.ry * 1.12, 24), _col(GIRL_BLUSH, minf(1.0, b.a * 1.5)))
			else:
				Smooth.polygon(_blush_n, _ellipse(b.c, b.rx, b.ry, 24), _col(_rig.colors.blush, b.a))


## Her inner ears' colour: pink for Rina, white (the drawing's own) for Roco.
func _ear_tint(a: float) -> Color:
	return Color(GIRL_EAR.r, GIRL_EAR.g, GIRL_EAR.b, a) if girl else Color(1, 1, 1, a)


## Rina's lashes on an open eye: three short strokes from the top of the eye toward its outer side,
## in the eye's light colour so they show on her dark mask. `s` is -1 for the eye on your left.
func _draw_lashes(ci: CanvasItem, e: Dictionary, r: float, s: float, color: Color) -> void:
	for k in 3:
		var a := deg_to_rad(28.0 + 26.0 * k)
		var on_rim := Vector2(s * cos(a), -sin(a))
		var base: Vector2 = e.c + Vector2(on_rim.x * r * e.fs, on_rim.y * r)
		var dir := (on_rim + Vector2(s * 0.55, -0.1)).normalized()
		_lash(ci, base, Vector2(dir.x * e.fs, dir.y), (7.5 - 1.2 * k) * e.ks, 3.0 * e.ks, color)


## One lash: a tapered stroke from `base` along `dir`, `length` long and `width` wide at its root.
func _lash(ci: CanvasItem, base: Vector2, dir: Vector2, length: float, width: float, color: Color) -> void:
	if dir.length() < 0.05:
		return
	var n := Vector2(-dir.y, dir.x).normalized() * width * 0.5
	var bend := n * 0.35 * signf(dir.x)
	var pts := PackedVector2Array([base - n - dir * 1.5, base + dir * length * 0.55 + bend - n * 0.45,
		base + dir * length + bend * 1.6, base + dir * length * 0.55 + bend + n * 0.45, base + n - dir * 1.5])
	Smooth.polygon(ci, pts, color)


## Rina's bow: on top of her head by her left ear, turning with her head.
## Hidden under a hat (not a halo), and as it goes behind her head.
func _draw_bow() -> void:
	var hat := str(outfit.get("hat", ""))
	if not girl or _f.is_empty() or (hat != "" and not Halo.has_kind(hat)):
		return   # a hat covers it; a halo floats behind her head, so the bow stays
	var it: Dictionary = _f.items
	var d := _head_decal(-44.0, -82.0, _f.th, it.cp, it.sp)
	var v: float = d.v
	if v < 0.05:
		return
	var a := _sstep(0.05, 0.3, v)
	var c := Vector2(d.x, d.y)
	var sx := clampf(d.fs, 0.25, 1.0)
	var rot := deg_to_rad(-18.0) * signf(sx)
	var xf := Transform2D(rot, c) * Transform2D(Vector2(sx * 1.45, 0), Vector2(0, 1.45), Vector2.ZERO)
	var ink := _col(_rig.colors.ink, a)
	var line := float(_rig.colors.headLine) * 0.62
	for side in [-1.0, 1.0]:
		var loop := PackedVector2Array()
		for q in 14:
			var t := float(q) / 13.0 * TAU
			# a rounded loop, wider at its outer end
			var px: float = side * (13.0 + 12.0 * cos(t))
			var py := (8.5 + 3.0 * cos(t)) * sin(t)
			loop.append(Vector2(px, py))
		var pts := xf * loop
		Smooth.polygon(_bow_n, pts, _col(BOW, a))
		var ring := pts.duplicate()
		ring.append(pts[0])
		_bow_n.draw_polyline(ring, ink, line, true)
		# a fold line and a shine on each loop
		_bow_n.draw_polyline(xf * PackedVector2Array([Vector2(side * 6.0, -1.5), Vector2(side * 16.0, 1.5)]),
			_col(BOW_DARK, a), line * 0.7, true)
		Smooth.polygon(_bow_n, xf * _ellipse(Vector2(side * 17.0, -4.5), 3.6, 2.0, 12), _col(BOW_SHINE, a * 0.9))
	var knot := xf * _ellipse(Vector2.ZERO, 6.0, 7.0, 16)
	Smooth.polygon(_bow_n, knot, _col(BOW_DARK, a))
	var kr := knot.duplicate()
	kr.append(knot[0])
	_bow_n.draw_polyline(kr, ink, line, true)


## The part of an ear in front of his head, as it turns toward you.
func _draw_ear_fronts() -> void:
	if _f.is_empty():
		return
	for e in _f.ears:
		for piece in e.front:
			var tx := _t(piece.name)
			if tx:
				var r := _region(piece.name)
				var ts := tx.get_size()
				var to_sheet := Transform2D(Vector2(r.size.x / ts.x, 0), Vector2(0, r.size.y / ts.y), r.position / ts)
				_ear_fronts.draw_polygon(piece.pts, piece.cols, to_sheet * (piece.uvs as PackedVector2Array), tx)


func _draw_nose() -> void:
	if _f.is_empty() or not _f.nose.on:
		return
	var colors: Dictionary = _rig.colors
	var N: Dictionary = _art().nose
	Smooth.polygon(_nose_n, _ellipse(_f.nose.c, _f.nose.rx, float(N.get("ry", N.rx * 0.7)), 24), _col(colors.nose))
	var sh: Array = N.shine
	var ch: float = _f.mouth.ch
	var sry: float = sh[3] if sh.size() > 3 else sh[2] * 0.6
	Smooth.polygon(_nose_n, _ellipse(_f.nose.c + Vector2(sh[0] * ch, sh[1]), maxf(1.2, sh[2] * absf(ch)), sry, 16), _col(colors.noseShine, colors.noseShineOp))


# --- the rig (ported from the canvas motion demo) ----------------------------------------------------

static func _art() -> Dictionary:
	return _c_art


## A hop (the pose's, negative is up) with only its rise scaled by `rise`.
func _lifted(hop_pose: float) -> float:
	return hop_pose * rise if hop_pose < 0.0 else hop_pose


static func _ax() -> float:
	return _c_ax


static func _gy() -> float:
	return _c_gy


static func _hc() -> Vector2:
	return _c_hc


static func _hr() -> Vector2:
	return _c_hr


static func _rest_tip(j: int) -> Vector2:
	var A: Dictionary = _art().arms[j]
	var e := float(A.elev)
	return Vector2(_ax() + A.S[0] + A.side * A.len * cos(e), A.S[1] + A.len * sin(e))


static func _rest() -> Dictionary:
	if _art().is_empty():
		return {}
	var tip_l := _rest_tip(0)
	var tip_r := _rest_tip(1)
	return {"near": 0.0, "yaw": 0.0, "headYaw": 0.0, "pitch": 0.0, "roll": 0.0, "hop": 0.0, "sq": 1.0, "lean": 0.0,
		"lookX": 0.0, "lookY": 0.0, "armL": 0.0, "armR": 0.0, "tLx": tip_l.x, "tLy": tip_l.y, "tRx": tip_r.x, "tRy": tip_r.y,
		"liftL": 0.0, "liftR": 0.0, "freeR": 0.0, "pawS": 1.0, "knock": 0.0, "earL": 0.0, "earR": 0.0, "tailLag": 0.0,
		"walk": 0.0, "wiggle": 0.0, "lookBlend": 0.0, "lookSweep": 0.0, "pointBlend": 0.0, "steps": 0.0, "strollX": 0.0}


func _box(tex_name: String) -> Rect2:
	var b: Array = _rig.textures[tex_name].box
	return Rect2(b[0], b[1], b[2], b[3])


static func _grid_idx(cols: int, rows: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for i in cols - 1:
		for j in rows - 1:
			var a := i * rows + j
			idx.append_array(PackedInt32Array([a, a + rows, a + 1, a + 1, a + rows, a + rows + 1]))
	return idx


static func _ellipse(c: Vector2, rx: float, ry: float, n := 28) -> PackedVector2Array:
	var unit: PackedVector2Array = _unit_circles.get(n, PackedVector2Array())
	if unit.is_empty():
		for i in n:
			var a := TAU * i / n
			unit.append(Vector2(cos(a), sin(a)))
		_unit_circles[n] = unit
	return Transform2D(Vector2(rx, 0), Vector2(0, ry), c) * unit


static func _quad(a: Vector2, m: Vector2, c: Vector2, n := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(m, t).lerp(m.lerp(c, t), t))
	return pts


static func _col(hex: String, alpha := 1.0) -> Color:
	var c := Color(hex) if hex != "" else Color.BLACK
	c.a *= alpha
	return c


static func _sstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _wrap_pi(a: float) -> float:
	return wrapf(a + PI, 0.0, TAU) - PI


func _look_vals(t: Vector2) -> Dictionary:
	var d := t - Vector2(_ax(), _hc().y)
	return {"lookX": clampf(d.x / 340.0, -1, 1), "lookY": clampf(d.y / 340.0, -1, 1),
		"headYaw": clampf(d.x / 1800.0, -0.42, 0.42), "pitch": clampf(-d.y / 3000.0, -0.16, 0.16)}


static func _head_decal(x: float, y: float, th: float, cp: float, sp: float, lam_c = null) -> Dictionary:
	var hr := _hr()
	var hc := _hc()
	var q := clampf(y / hr.y, -0.995, 0.995)
	var ring := hr.x * sqrt(1.0 - q * q)
	var lam := asin(clampf(x / ring, -1, 1))
	var l2: float = _wrap_pi(lam + th) if lam_c == null else _wrap_pi(lam_c + th) + lam - lam_c
	var v := cos(l2)
	var lc := clampf(l2, -PI / 2, PI / 2)
	var zz := ring * cos(lc)
	return {"x": hc.x + ring * sin(lc), "y": hc.y + y * cp - zz * sp, "v": v, "fs": maxf(0.0, v) / maxf(0.05, cos(lam))}


func _on_muzzle(x: float, y: float, ch: float, shh: float, cp: float, sp: float) -> Vector2:
	var M: Dictionary = _art().muzzle
	var hc := _hc()
	var u: float = (x - M.c[0]) / M.rx
	var w: float = (y - M.c[1]) / M.ry
	var zz := _hr().y + 30.0 * sqrt(maxf(0.0, 1.0 - u * u - w * w))
	var z1 := -x * shh + zz * ch
	return Vector2(hc.x + x * ch + zz * shh, hc.y + y * cp - z1 * sp)


## A textured mesh for a shape painted on his head: a grid over its texture, each point slid round
## the head (face parts squeeze near the edge and fold behind it).
func _decal_mesh(tex_name: String, lam_c: float, th: float, cp: float, sp: float, cols := 9, rows := 4) -> Dictionary:
	var box := _box(tex_name)
	var hc := _hc()
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var seen := false
	for i in cols:
		for j in rows:
			var u := float(i) / (cols - 1)
			var v := float(j) / (rows - 1)
			var q := box.position + Vector2(u * box.size.x, v * box.size.y)
			var d := _head_decal(q.x - hc.x, q.y - hc.y, th, cp, sp, lam_c)
			if d.v > 0.02:
				seen = true
			pts.append(Vector2(d.x, d.y))
			uvs.append(Vector2(u, v))
	if not seen:
		return {}
	return {"pts": pts, "uvs": uvs, "idx": _grid_idx(cols, rows)}


func _lift(i: int, own: float, breathe: float, hop_y: float, ph: float, wk: float) -> float:
	return own + 0.035 * breathe + 0.5 * clampf(-hop_y / 80.0, 0, 1) - (1.0 - p.sq) * 0.9 \
			+ wk * 0.12 * sin(ph + (PI if i > 0 else 0.0)) + p.wiggle * 0.14 * sin(_now * 0.05 + i)


## Where an arm's paw tip goes so that the middle of the paw lands on E (a book edge).
func _hold_tip(A: Dictionary, S: Vector2, E: Vector2) -> Vector2:
	var d := E - S
	var dl := maxf(d.length(), 0.001)
	var back: float = A.len - A.uPc
	var length := dl + back
	if length * 1.6 < A.len:
		length = dl / (1.0 - 1.6 * back / A.len)
		if length * 1.6 / A.len < 0.6:
			length = dl + 0.6 * back
	return S + d / dl * length


func _shoulder(j: int, yaw: float) -> Vector2:
	var A: Dictionary = _art().arms[j]
	return Vector2(_ax() + A.S[0] * cos(yaw) + ARM_Z * sin(yaw), A.S[1])


func _tip_for(j: int, e: Vector2) -> Vector2:
	return _hold_tip(_art().arms[j], _shoulder(j, 0.0), e)


func _reach(j: int, deg: float, stretch: float) -> Vector2:
	var A: Dictionary = _art().arms[j]
	var s := _shoulder(j, 0.0)
	var a := deg_to_rad(deg)
	return Vector2(s.x + A.side * cos(a) * A.len * stretch, s.y + sin(a) * A.len * stretch)


func raise_to(j: int, deg: float) -> float:
	return maxf(0.0, float(_art().arms[j].elev) - deg_to_rad(deg))


func drop_to(j: int, deg: float) -> float:
	return minf(0.0, float(_art().arms[j].elev) - deg_to_rad(deg))


## One arm: its textures laid along the line from his shoulder to where the paw should be (a strip
## mesh, bent and stretched). a = 0 leaves it as drawn (raised by lift); a = 1 points the tip at T.
func _arm(j: int, a: float, T: Vector2, lift: float, cb: float, sb: float, ps: float, h: float, E: Vector3) -> Dictionary:
	var A: Dictionary = _art().arms[j]
	var info: Dictionary = _rig.arms[j]
	var side: float = A.side
	var flip := 1.0 if cb >= 0 else -1.0
	var e := clampf(A.elev - lift, -1.3, maxf(A.elev, 1.5))
	var S := Vector2(_ax() + A.S[0] * cb + ARM_Z * sb, A.S[1])
	var tx: float = A.S[0] + side * A.len * cos(e)
	var R := Vector2(_ax() + tx * cb + ARM_Z * sb, A.S[1] + A.len * sin(e))
	var z := -tx * sb + ARM_Z * cb
	if h > 0.001:
		R = R.lerp(_hold_tip(A, S, Vector2(E.x, E.y)), h)
		z = lerpf(z, E.z, h)
	var ang := atan2(R.y - S.y, R.x - S.x)
	var length := R.distance_to(S)
	if a > 0.001:
		ang += _wrap_pi(atan2(T.y - S.y, T.x - S.x) - ang) * a
		length = lerpf(length, T.distance_to(S), a)
	var u_paw: float = A.uPaw
	var paw_len: float = A.len - u_paw
	var kp := clampf(length / A.len * 1.6, 0.6, 1.0)
	var ks := maxf(0.02, (length - paw_len * kp) / u_paw)
	var big_l: float = u_paw * ks + paw_len * kp
	var upc: float = u_paw * ks + (A.uPc - u_paw) * kp
	var dir := Vector2(cos(ang), sin(ang))
	var P := S + dir * big_l
	var C := (S + P) / 2.0 + Vector2(-dir.y, dir.x) * flip * 10.0 * a * side
	var t0 := C - S
	var t1 := P - C
	var l0 := maxf(t0.length(), 0.001)
	var l1 := maxf(t1.length(), 0.001)
	var place := func(u: float, v: float) -> Vector2:
		var uu: float = u if u <= 0 else (u * ks if u <= u_paw else u_paw * ks + (u - u_paw) * kp)
		var vv := v
		if ps != 1.0:
			var sc := 1.0 + (ps - 1.0) * _sstep(u_paw - 10.0, u_paw + 6.0, u)
			uu = upc + (uu - upc) * sc
			vv *= sc
		var t := uu / big_l
		var b: Vector2
		var tg: Vector2
		if t <= 0:
			tg = t0 / l0
			b = S + tg * uu
		elif t >= 1:
			tg = t1 / l1
			b = P + tg * (uu - big_l)
		else:
			var w := 1.0 - t
			b = S * w * w + C * 2.0 * w * t + P * t * t
			tg = (t0 * w + t1 * t).normalized()
		return b + Vector2(-tg.y, tg.x) * flip * vv
	# the strips: where each vertex sat in the drawing (for the texture), and where it is now
	var e0 := Vector2(side * cos(float(A.elev)), sin(float(A.elev)))
	var n0 := Vector2(-e0.y, e0.x)
	var s0 := Vector2(_ax() + A.S[0], A.S[1])
	# Where it's drawn: an arm reaching for something counts as in front of him (he faces what he
	# points at). Over his head (pointing up, a paw pump, a paw at his chin) it stays in front of
	# the head until the paw has cleared it, so a paw never slips behind his face.
	var zf := lerpf(z, maxf(z, ARM_Z + 12.0), minf(1.0, a * 2.0)) if a > 0.001 else z
	var raised := a > 0.02 and S.y - P.y > 14.0
	var over_head := false
	var hc := _hc()
	var hr := _hr()
	# (the paw end of the arm, as wide as the arm: the root by his shoulder stays under his jaw)
	var margin: float = A.half
	for u: float in [u_paw * 0.8, u_paw, float(A.uPc)]:
		var q: Vector2 = place.call(u, 0.0)
		if pow((q.x - hc.x) / (hr.x + margin), 2) + pow((q.y - hc.y) / (hr.y + margin), 2) < 1.0:
			over_head = true
	var slot := "b" if zf < -18.0 else ("f" if raised or over_head else "m")
	var tx0: float = A.S[0] + side * A.len * cos(float(A.elev))
	var ang0 := atan2(A.S[1] + A.len * sin(float(A.elev)) - S.y, _ax() + tx0 * cb + ARM_Z * sb - S.x)
	var swung := _sstep(0.08, 0.45, absf(_wrap_pi(ang - ang0)))
	var key := "armL" if j == 0 else "armR"
	var out := {"slot": slot, "z": zf, "tip": P, "pc": place.call(u_paw + (A.uPc - u_paw), 0.0)}
	out.pc = place.call(float(A.uPc), 0.0)
	out.fill = _arm_strip(key + "_fill", place, s0, e0, n0, float(info.uMin), float(info.uMax), float(info.vMax))
	var sleeve := PackedVector2Array()
	var outline: Array = _sleeves.get(j, [])
	if outline.is_empty():
		var all: Array = A.parts[int(A.get("sleeve", 0))]
		for i in range(0, all.size(), 3):
			outline.append(all[i])
		_sleeves[j] = outline
	for q in outline:
		sleeve.append(place.call(float(q[0]), float(q[1])))
	out.sleeve = sleeve
	out.rimW = float(A.get("rim", 0.0))
	if info.band:
		# the drawn outline fades out near the shoulder once the arm swings, so the arm grows out
		# of the body without a seam
		out.band = _arm_strip(key + "_band", place, s0, e0, n0, float(info.uMin) + (float(A.half) * 1.6 + 6.0) * swung,
				float(info.uMax), float(info.vMax))
	return out


func _arm_strip(tex_name: String, place: Callable, s0: Vector2, e0: Vector2, n0: Vector2, u_from: float, u_to: float, v_max: float) -> Dictionary:
	var box := _box(tex_name)
	var cols := 14
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in cols:
		var u := lerpf(u_from, u_to, float(i) / (cols - 1))
		for v in [-v_max, v_max]:
			pts.append(place.call(u, v))
			uvs.append((s0 + e0 * u + n0 * v - box.position) / box.size)
	return {"pts": pts, "uvs": uvs, "idx": _grid_idx(cols, 2)}


## His body's outline as points, pulled in to the inner edge of its drawn line (cached).
static func _body_inner() -> PackedVector2Array:
	if not _body_in.is_empty():
		return _body_in
	var B: Dictionary = _art().body
	var cur := Vector2(B.m[0], B.m[1])
	var pts := PackedVector2Array([cur])
	for c in B.c:
		var c1 := Vector2(c[0], c[1])
		var c2 := Vector2(c[2], c[3])
		var e := Vector2(c[4], c[5])
		for i in range(1, 11):
			var t := i / 10.0
			var u := 1.0 - t
			pts.append(cur * (u * u * u) + c1 * (3.0 * u * u * t) + c2 * (3.0 * u * t * t) + e * (t * t * t))
		cur = e
	var inner := Geometry2D.offset_polygon(pts, -float(_art().get("bodyLine", 4.8)) / 2.0, Geometry2D.JOIN_ROUND)
	_body_in = inner[0] if not inner.is_empty() else pts
	return _body_in


## The line round an arm wherever it pokes out of his body: along the sleeve's edge, just inside
## it like the drawn outline, and cut where it goes into the body, so it runs on into the body's
## own outline. The arm always looks joined at the shoulder, however it swings.
static func _rim(sleeve: PackedVector2Array, w: float, body: PackedVector2Array) -> Array:
	if sleeve.size() < 3 or w <= 0.0:
		return []
	var inner := Geometry2D.offset_polygon(sleeve, -w / 4.0, Geometry2D.JOIN_ROUND)
	if inner.is_empty():
		return []
	var line: PackedVector2Array = inner[0]
	for poly: PackedVector2Array in inner:
		if poly.size() > line.size():
			line = poly
	line.append(line[0])
	return Geometry2D.clip_polyline_with_polygon(line, body)


static func _qbez(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t


## The tail: a strip along its centre line, which turns with him (a little behind when he spins).
func _tail(tt: float) -> Dictionary:
	var T: Dictionary = _art().tail
	var ax := _ax()
	var ct := cos(tt)
	var st := sin(tt)
	var rest: Array = []
	var now: Array = []
	var tz := 0.0
	for k in 3:
		var q: Array = T.spine[k]
		rest.append(Vector2(q[0], q[1]))
		now.append(Vector2(ax + (q[0] - ax) * ct + T.z[k] * st, q[1]))
		tz += -(q[0] - ax) * st + T.z[k] * ct
	var radii: Array = T.radii
	var box := _box("tail")
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var ts: Array = [-0.08]
	for i in 19:
		ts.append(i / 18.0)
	ts.append(1.0 + (float(radii[2]) + 10.0) / 120.0)
	for t in ts:
		var tc := clampf(t, 0.0, 1.0)
		var r: float = radii[0] + (radii[1] - radii[0]) * pow(sin(PI * minf(tc, 0.75) / 1.5), 1.2)
		if tc > 0.75:
			r = r * (1.0 - tc) + radii[2] * tc
		var w := r + 9.0
		for which in 2:
			var cp: Array = rest if which == 0 else now
			var b := _qbez(cp[0], cp[1], cp[2], tc)
			var tg := (_qbez(cp[0], cp[1], cp[2], minf(1.0, tc + 0.01)) - _qbez(cp[0], cp[1], cp[2], maxf(0.0, tc - 0.01))).normalized()
			b += tg * (t - tc) * 120.0
			var nv := Vector2(-tg.y, tg.x)
			if which == 0:
				uvs.append((b + nv * w - box.position) / box.size)
				uvs.append((b - nv * w - box.position) / box.size)
			else:
				pts.append(b + nv * w)
				pts.append(b - nv * w)
	return {"pts": pts, "uvs": uvs, "idx": _grid_idx(ts.size(), 2), "front": tz > 0, "tz": tz}


## The part of an ear in front of his head: the ear's quad clipped to above its base line (which
## slides from the dome's edge down to the base as the ear comes forward), with a soft edge.
func _ear_front(tex_name: String, xf: Transform2D, inner_xf: Transform2D, E: Dictionary, off: float, inner_a: float) -> Array:
	var line: Array = E.cutLine
	var cut: Array = E.cut
	var nv := Vector2(cut[0], cut[1])
	var base := Vector2(line[0], line[1]) + nv * off
	var out := []
	for part in [[tex_name, Transform2D.IDENTITY, 1.0], [tex_name + "_in", inner_xf, inner_a]]:
		var box := _box(part[0])
		var own: Transform2D = part[1]
		var quad := [box.position, box.position + Vector2(box.size.x, 0), box.end, box.position + Vector2(0, box.size.y)]
		for band in [[0.0, 9.0], [9.0, 4000.0]]:
			var in_ear: Array = []
			for q in quad:
				in_ear.append(own * q)
			in_ear = _clip(in_ear, nv, base, band[0])
			in_ear = _clip(in_ear, -nv, base + nv * band[1], 0.0)
			if in_ear.size() < 3:
				continue
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			var cols := PackedColorArray()
			var inv := own.affine_inverse()
			for q in in_ear:
				pts.append(xf * q)
				uvs.append((inv * q - box.position) / box.size)
				var d: float = (q - base).dot(nv)
				var a: float = part[2] * (clampf(d / 9.0, 0.0, 1.0) if band[1] < 100.0 else 1.0)
				cols.append(_ear_tint(a) if part[0].ends_with("_in") else Color(1, 1, 1, a))
			out.append({"name": part[0], "pts": pts, "uvs": uvs, "cols": cols})
	return out


## Sutherland-Hodgman: keeps the side of the line where (q - base).n >= d.
static func _clip(poly: Array, n: Vector2, base: Vector2, d: float) -> Array:
	var out := []
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var da := (a - base).dot(n) - d
		var db := (b - base).dot(n) - d
		if da >= 0:
			out.append(a)
		if (da >= 0) != (db >= 0):
			out.append(a + (b - a) * (da / (da - db)))
	return out


static func _scale_x(about_x: float, k: float) -> Transform2D:
	return Transform2D(0, Vector2(about_x, 0)) * Transform2D(Vector2(k, 0), Vector2(0, 1), Vector2.ZERO) * Transform2D(0, Vector2(-about_x, 0))


func _rig_frame() -> Dictionary:
	var art := _art()
	var ax := _ax()
	var gy := _gy()
	var hc := _hc()
	var f := {}
	var ph: float = p.steps * PI    # the walk cycle, keyed by the animation (steps)
	var wk: float = p.walk
	var stroll_x: float = p.strollX * roam
	var breathe := sin(_now / 1000.0 * TAU / 3.4)
	var hop_y: float = _lifted(p.hop) - absf(sin(ph)) * 7.0 * wk
	var wig: float = p.wiggle * sin(_now * 0.05) * 6.0
	var sqx: float = 1.0 + (1.0 - p.sq) * 0.7
	var sqy: float = p.sq * (1.0 + 0.012 * breathe)
	f.bodyT = Transform2D(0, Vector2(ax + stroll_x, gy + hop_y)) * Transform2D(deg_to_rad(p.lean + sin(ph) * 3.0 * wk + wig * 0.4), Vector2.ZERO) \
			* Transform2D(Vector2(sqx, 0), Vector2(0, sqy), Vector2.ZERO) * Transform2D(0, Vector2(-ax, -gy))
	var hs := clampf(1.0 + hop_y / 220.0, 0.55, 1.0)
	f.shadow = {"c": Vector2(ax + stroll_x, gy + 2), "rx": float(art.shadowRx) * hs, "ry": 12.0 * hs, "a": 0.14 * hs}
	var yb: float = p.yaw
	var cb := cos(yb)
	var sb := sin(yb)
	f.tail = _tail(yb + p.tailLag + 0.06 * sin(_now / 1000.0 * TAU / 2.6) * (1.0 - wk) + sin(ph) * 0.12 * wk)
	# feet
	var feet := []
	for i in 2:
		var F: Dictionary = art.feet[i]
		var lift := -maxf(0.0, sin(ph + (0.0 if i > 0 else PI))) * 9.0 * wk
		var c := Vector2(ax + F.x * cb + FOOT_Z * sb, F.y + lift)
		var rx := Vector2(F.rx * cb, F.rx * 1.28 * sb).length()
		feet.append({"z": -F.x * sb + FOOT_Z * cb, "xf": Transform2D(0, c) * Transform2D(Vector2(rx / F.rx, 0), Vector2(0, 1), Vector2.ZERO)
			* Transform2D(0, -Vector2(ax + F.x, F.y))})
	f.feet = feet
	# body, and the belly as a patch sliding round it
	var bsx := Vector2(cb, DEPTH * sb).length()
	f.bodyXf = _scale_x(ax, bsx)
	var rb: float = art.bodyHalf
	var B: Dictionary = art.belly
	var sil := rb * bsx
	var l_l := asin(clampf((B.cx - B.hw) / rb, -1, 1))
	var l_r := asin(clampf((B.cx + B.hw) / rb, -1, 1))
	var a0 := _wrap_pi(l_l + yb)
	var a1 := a0 + l_r - l_l
	if minf(a1, PI / 2) <= maxf(a0, -PI / 2):
		a0 -= TAU
		a1 -= TAU
	var lo := maxf(a0, -PI / 2)
	var hi := minf(a1, PI / 2)
	var xs := []
	for an in [lo, hi]:
		if an <= -PI / 2 + 1e-6:
			xs.append(-sil)
		elif an >= PI / 2 - 1e-6:
			xs.append(sil)
		else:
			xs.append(rb * sin(an - yb) * cb + rb * DEPTH * cos(an - yb) * sb)
	var nc: float = ax + (xs[0] + xs[1]) / 2.0
	var nh := maxf(0.5, (xs[1] - xs[0]) / 2.0)
	f.belly = {"on": hi > lo + 0.02, "nc": nc, "k": nh / B.hw,
		"xf": Transform2D(0, Vector2(nc, 0)) * Transform2D(Vector2(nh / B.hw, 0), Vector2(0, 1), Vector2.ZERO) * Transform2D(0, Vector2(-(ax + B.cx), 0))}
	# scarf (Closet): the band narrows with his neck; the knot travels round it
	f.scarf = {}
	var SC = art.get("scarf")
	if SC != null and p.scarfS > 0.01:
		var s: float = p.scarfS
		var pv := Vector2(SC.pivot[0], SC.pivot[1])
		var l := asin(clampf(SC.knot[0] / SC.neckR, -1, 1))
		var kx: float = SC.neckR * (sin(l) * cb + DEPTH * cos(l) * sb)
		var kz: float = SC.neckR * (-sin(l) * sb + DEPTH * cos(l) * cb)
		var kz0: float = SC.neckR * DEPTH * cos(l)
		f.scarf = {"band": Transform2D(0, pv) * Transform2D(Vector2(bsx * s, 0), Vector2(0, s), Vector2.ZERO) * Transform2D(0, -pv),
			"knot": Transform2D(0, Vector2(ax + kx, SC.knot[1] + 10.0 * (kz - kz0) / SC.neckR))
				* Transform2D(Vector2(clampf(kz / kz0, 0.3, 1.1) * s, 0), Vector2(0, s), Vector2.ZERO) * Transform2D(0, -Vector2(ax + SC.knot[0], SC.knot[1])),
			"knotOn": kz > -2.0, "item": _wear.scarf}
	# arms (and the book, held by its edges)
	var lift_l := _lift(-1, p.liftL, breathe, hop_y, ph, wk)
	var lift_r := _lift(1, p.liftR, breathe, hop_y, ph, wk)
	var BK = art.get("book")
	var hold: float = p.hold if BK != null else 0.0
	var el := Vector3.ZERO
	var er := Vector3.ZERO
	if BK != null:
		for i in 2:
			var x: float = BK.x0 if i == 0 else BK.x1
			var l: float = lift_l if i == 0 else lift_r
			var pnt := Vector3(ax + (x - ax) * cb + BK.z * sb, BK.y - clampf(l, -1, 0.6) * (90.0 if l > 0 else 30.0), -(x - ax) * sb + BK.z * cb)
			if i == 0:
				el = pnt
			else:
				er = pnt
	var arm_l := _arm(0, p.armL, Vector2(p.tLx, p.tLy), lift_l, cb, sb, p.pawS, hold, el)
	var arm_r := _arm(1, p.armR, Vector2(p.tRx, p.tRy), lift_r, cb, sb, p.pawS * (1.0 + 0.32 * p.knock), hold * (1.0 - p.freeR), er)
	# each arm's rim, wherever it pokes out of the body
	var body_in: PackedVector2Array = f.bodyXf * _body_inner()
	for arm in [arm_l, arm_r]:
		arm.rim = _rim(arm.sleeve, arm.rimW, body_in)
	# facing away, his tail sticks out toward you: an arm further back than the tail goes behind it
	if f.tail.front:
		for arm in [arm_l, arm_r]:
			if arm.slot == "m" and arm.z < f.tail.tz / 3.0:
				arm.slot = "mb"
	f.book = {}
	if BK != null and p.bookS > 0.01:
		var k := _sstep(0.6, 1.0, p.hold)
		var fr := _sstep(0.0, 1.0, p.freeR)
		var s: float = p.bookS
		var bw: float = BK.x1 - BK.x0
		var L := Vector2(el.x, el.y).lerp(arm_l.pc, k)
		var Rt := Vector2(er.x, er.y).lerp(arm_r.pc, k)
		# The item is stiff: it never stretches between his paws.
		#   - Held in both paws, it keeps its width, round the middle between them.
		#   - When his paws move apart or together, or one goes much higher than the other (an arm
		#     waves, points, lifts, a paw at his chin), it rides in one paw instead, by its near edge:
		#     the left paw, unless the left is the busy one.
		#   - right_paw_free hands it to the left paw on purpose.
		var w: float = bw * cb          # its width as you see it (narrower as he turns)
		var d := Rt - L
		var dl := d.length()
		var u := d / dl if dl > 0.5 else Vector2(1.0 if cb >= 0 else -1.0, 0.0)
		var mid := (L + Rt) / 2.0
		var both_l := mid - u * absf(w) / 2.0
		var both_r := mid + u * absf(w) / 2.0
		var cbk := cb if absf(cb) >= 0.06 else (0.06 if cb >= 0 else -0.06)
		var tilt := absf(atan2(d.y, absf(d.x / cbk))) if dl > 0.5 else 0.0
		var grip := maxf(maxf(_sstep(6.0, 20.0, absf(dl - absf(w))), _sstep(0.35, 0.6, tilt)), fr)
		var home_l := Vector2(ax + (BK.x0 - ax) * cb + BK.z * sb, BK.y)
		var home_r := Vector2(ax + (BK.x1 - ax) * cb + BK.z * sb, BK.y)
		var busy: float = arm_l.pc.distance_to(home_l) - arm_r.pc.distance_to(home_r)
		var by_right := _sstep(12.0, 32.0, busy) * (1.0 - fr)
		var one_l := L.lerp(Rt + Vector2(-w, 12), by_right)
		var one_r := (L + Vector2(w, 12)).lerp(Rt, by_right)
		L = both_l.lerp(one_l, grip)
		Rt = both_r.lerp(one_r, grip)
		# (halfway between the two holds the ends can come closer: keep its width there too)
		var span := Rt - L
		var want := sqrt(w * w + 144.0 * grip * grip)
		if span.length() > 0.5:
			var c2 := (L + Rt) / 2.0
			L = c2 - span.normalized() * want / 2.0
			Rt = c2 + span.normalized() * want / 2.0
		# a stiff card turned with him: tipped in its own plane by phi, then narrowed as he turns
		var phi := atan2(Rt.y - L.y, (Rt.x - L.x) / cbk)
		var X := Vector2(cos(phi) * cbk, sin(phi)) * s
		var Y := Vector2(-sin(phi) * cbk, cos(phi)) * s
		var C := (L + Rt) / 2.0
		var c0: float = (BK.x0 + BK.x1) / 2.0
		var facing := cb > 0
		var front: bool = facing and C.y - BK.h / 2.0 < hc.y + 80.0
		f.book = {"xf": Transform2D(X, Y, C - X * c0 - Y * float(BK.y)),
			"slot": "bb" if not facing else ("bf" if front else "bm"), "grip": grip, "byRight": by_right}
		if front and p.hold > 0.5:
			var holders := [arm_l, arm_r]
			if grip > 0.5:
				holders = [arm_r] if by_right > 0.5 else [arm_l]
			for arm in holders:
				arm.slot = "f"
	f.arms = [arm_l, arm_r]
	# head
	var th: float = yb + p.headYaw
	var ch := cos(th)
	var shh := sin(th)
	var cp := cos(p.pitch)
	var sp := sin(p.pitch)
	var piv := Vector2(art.head.pivot[0], art.head.pivot[1])
	f.headT = Transform2D(deg_to_rad(p.roll + wig), piv) * Transform2D(0, -piv) * Transform2D(0, Vector2(0, -absf(cos(ph)) * 2.5 * wk))
	var perk := 5.0 if eyes == "happy" else 0.0
	var ears := []
	for j in 2:
		var E: Dictionary = art.ears[j]
		var lam: float = E.lam0 + th + _ear_lag.ang
		var x: float = E.R * sin(lam)
		var z0: float = E.R * cos(lam)
		var tilt_deg: float = E.tilt * sin(lam) / sin(E.lam0) - 5.0 * shh + _ear_s[j].ang + (p.earL if E.side < 0 else p.earR) - perk * E.side
		var sx := sqrt(ch * ch + 0.49 * shh * shh)
		var xf := Transform2D(0, Vector2(hc.x + x, hc.y + E.off[1] * cp - z0 * sp)) * Transform2D(deg_to_rad(tilt_deg), Vector2.ZERO) \
				* Transform2D(Vector2(sx, 0), Vector2(0, 1.05 if perk > 0 else 1.0), Vector2.ZERO)
		var inner_xf := Transform2D(0, Vector2(7.0 * shh, 0)) * Transform2D(Vector2(clampf(ch / sx, 0.2, 1.0), 0), Vector2(0, 1), Vector2.ZERO)
		var inner_a := _sstep(0.05, 0.35, ch)
		var zr: float = E.R * cos(E.lam0)
		var k := _sstep(zr + 2.0, zr + 20.0, z0 * cp) * _sstep(-0.1, 0.35, ch)
		var ear_name := "earL" if j == 0 else "earR"
		ears.append({"name": ear_name, "z": E.off[1] * sp + z0 * cp, "xf": xf, "inner": inner_xf, "innerA": inner_a,
			"front": _ear_front(ear_name, xf, inner_xf, E, (1.0 - k) * float(E.cut[2]), inner_a) if k > 0.01 else []})
	if ears[0].z > ears[1].z:
		ears.reverse()
	f.ears = ears
	var M: Dictionary = art.muzzle
	var N: Dictionary = art.nose
	var nz: float = _hr().y + 26.3
	f.muz = {"c": Vector2(hc.x + M.c[0] * ch + _hr().y * shh, hc.y + M.c[1] * cp - _hr().y * ch * sp), "rx": Vector2(M.rx * ch, 30.0 * shh).length(), "on": ch > -0.3}
	f.nose = {"c": Vector2(hc.x + N.c[0] * ch + nz * shh, hc.y + N.c[1] * cp - nz * ch * sp), "rx": Vector2(N.rx * ch, 8.0 * shh).length(), "on": ch > -0.15}
	f.decals = {"brow_l": _decal_mesh("brow_l", art.brows[0].lam, th, cp, sp, 6, 3), "brow_r": _decal_mesh("brow_r", art.brows[1].lam, th, cp, sp, 6, 3),
		"mask": _decal_mesh("mask", art.mask.lam, th, cp, sp, 12, 4)}
	var blush := []
	for bl in art.blush:
		var d := _head_decal(bl.c[0], bl.c[1], th, cp, sp)
		blush.append({"c": Vector2(d.x, d.y), "rx": maxf(0.3, bl.rx * d.fs), "ry": float(bl.get("ry", bl.rx * 0.65)), "a": float(bl.op) * _sstep(0.02, 0.3, d.v)})
	f.blush = blush
	var eye_mode := eyes
	if eye_mode == "open" and _now < _blink_until:
		eye_mode = "closed"
	var eye_list := []
	for E in art.eyes:
		var d := _head_decal(E.c[0], E.c[1], th, cp, sp)
		var fs: float = d.fs
		var ks: float = E.r / 15.64
		var pc := Vector2(d.x + E.pupil[0] * fs + p.lookX * 4.6 * ks * fs, d.y + E.pupil[1] + p.lookY * 4.2 * ks)
		eye_list.append({"c": Vector2(d.x, d.y), "fs": fs, "ks": ks, "a": _sstep(0.02, 0.3, d.v), "pupil": pc, "mode": eye_mode})
	f.eyes = eye_list
	var mo := mouth
	if _now < _talk_until:
		mo = "open" if sin(_now * 0.05) + sin(_now * 0.021) > 0.1 else "w"
	f.mouth = {"mode": mo, "a": _sstep(0.12, 0.4, ch), "ch": ch, "shh": shh, "cp": cp, "sp": sp}
	f.th = th
	f.items = {"cb": cb, "sb": sb, "bsx": bsx, "ch": ch, "shh": shh, "cp": cp, "sp": sp}
	# Where a windblown scarf leaves his neck (behind it, on your left) and where a halo floats:
	# behind his head, far enough back that side-on it stands clear of the back of his head.
	# Each comes in front of him when he's turned away.
	var NK = art.get("scarf")
	if NK != null:
		var wl := -2.3
		var wr: float = NK.neckR
		var wx: float = wr * (sin(wl) * cb + DEPTH * cos(wl) * sb)
		var wz: float = wr * (-sin(wl) * sb + DEPTH * cos(wl) * cb)
		f.wind = {"at": Vector2(ax + wx, float(NK.pivot[1]) + 6.0), "front": wz > 0.0}
	f.halo = {"at": f.headT * (hc + Vector2(-sin(th) * HALO_BACK, -20.0)), "turn": cos(th), "front": cos(th) < -0.05}
	return f


func _draw_mouth(ci: CanvasItem) -> void:
	var m: Dictionary = _f.mouth
	if m.a <= 0.01:
		return
	var colors: Dictionary = _rig.colors
	var M: Dictionary = _art().muzzle
	var mx: float = M.c[0]
	var my: float = M.c[1]
	var aw := absf(m.ch)
	var dark := Color("6b2f36", m.a)
	var line := Color("2d2430", m.a)
	match m.mode:
		"w":
			var pts := PackedVector2Array()
			for q in _art().mouth:
				pts.append(_on_muzzle(q[0], q[1], m.ch, m.shh, m.cp, m.sp))
			ci.draw_polyline(pts, _col(colors.mouth, m.a), float(colors.mouthW), true)
		"happy", "open":
			var big: bool = m.mode == "happy"
			var dx := 13.8 if big else 9.5
			var dy0 := 0.0 if big else 2.7
			var a := _on_muzzle(mx - dx, my + dy0, m.ch, m.shh, m.cp, m.sp)
			var mid := _on_muzzle(mx, my + (20.24 if big else 17.2), m.ch, m.shh, m.cp, m.sp)
			var c := _on_muzzle(mx + dx, my + dy0, m.ch, m.shh, m.cp, m.sp)
			var pts := _quad(a, mid, c, 14)
			Smooth.polygon(ci, pts, dark)
			var loop := pts.duplicate()
			loop.append(pts[0])
			ci.draw_polyline(loop, line, 2.8, true)
			var tc := _on_muzzle(mx, my + (10.12 if big else 8.8), m.ch, m.shh, m.cp, m.sp)
			Smooth.polygon(ci, _ellipse(tc, maxf(0.5, (6.44 if big else 4.5) * aw), 3.7 if big else 2.6, 16), Color("e9801f", m.a))
		"o":
			Smooth.polygon(ci, _ellipse(_on_muzzle(mx, my + 6.44, m.ch, m.shh, m.cp, m.sp), maxf(0.5, 4.6 * aw), 5.5, 18), dark)


# --- the other Closet items: textures from the Closet's sheet, fitted to his head,
# neck and chest, each with its tier's shine (closet_item.gdshader) ------------------------------

func _has_tex(tex_name: String) -> bool:
	return _rig.get("textures", {}).has(tex_name)


## An item's texture on its node, and its tier's material when the item changes.
func _wear_tex(node: Polygon2D, item_id: String, tex_name: String) -> void:
	_set_quad_tex(node, tex_name)
	_item_material(node, item_id, tex_name)


## Copper items are drawn plain; silver and up get closet_item.gdshader with their tier.
func _item_material(node: CanvasItem, item_id: String, tex_name: String) -> void:
	var key := item_id + "/" + tex_name
	if node.get_meta("item", "") == key:
		return
	node.set_meta("item", key)
	var tier: int = int(Wardrobe.tier_of(item_id).rank) - 1
	if tier <= 0:
		node.material = null
		return
	var mat := node.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = load(ITEM_SHADER)
		node.material = mat
	var b := _box(tex_name)
	mat.set_shader_parameter("tier", tier)
	mat.set_shader_parameter("box", Vector4(b.position.x, b.position.y, b.size.x, b.size.y))
	mat.set_shader_parameter("seed", float(absi(hash(item_id)) % 997) / 31.0)


func _apply_items(f: Dictionary) -> void:
	var it: Dictionary = f.items
	# a hat sits on his head and turns with it in 3D: wrapped round his head, as wide as the hat is at
	# each height, so its front slides round and away and its back (drawn, or the front mirrored)
	# comes round; shaded toward its edges. It bobs behind his quick moves (the ears' spring), and
	# violet and finer hats sway gently on their own.
	var hat: String = outfit.get("hat", "")
	_hat.visible = hat != "" and _has_tex(hat)
	if _hat.visible:
		var hc := _hc()
		var back := hat + ".back" if _has_tex(hat + ".back") else hat
		_set_wrap(_hat, hat, _wrap_mesh(hat, back, hc.x, hc.y, f.th, it.cp, it.sp, 1.0, 11, 9, true))
		_item_material(_hat, hat, hat)
		var sway: float = _ear_lag.ang * 0.3
		if int(Wardrobe.tier_of(hat).rank) >= 3:
			sway += sin(_now * 0.0021) * 0.022
		var pivot := hc + Vector2(0, -50)
		_hat.transform = Transform2D(sway, pivot) * Transform2D(0, -pivot)
	# glasses are painted on his face: they slide round his head as he turns, hidden from behind
	var glasses: String = outfit.get("eyes", "")
	var gm := {}
	if glasses != "" and it.ch > 0.15 and _has_tex(glasses):
		gm = _decal_mesh(glasses, 0.0, f.th, it.cp, it.sp, 9, 4)
	_set_mesh(_glasses, glasses, gm)
	if not gm.is_empty():
		_item_material(_glasses, glasses, glasses)
	# a bow tie, a lei or a medal goes round his neck in 3D: as he turns, it slides round with his
	# body and goes behind, shaded toward its edges
	var neck: String = outfit.get("neck", "")
	_neck_item.visible = neck != "" and not Wardrobe.is_scarf(neck) and it.cb >= -0.25 and _has_tex(neck)
	if _neck_item.visible:
		_set_wrap(_neck_item, neck, _wrap_mesh(neck, "", _ax(), 0.0, atan2(it.sb, it.cb), 1.0, 0.0, DEPTH, 11, 7))
		_item_material(_neck_item, neck, neck)
	# a top or a dress is cut to his body: its drawing lies on his body and moves with it,
	# clipped to the body's fill like his belly, so its sides follow his outline however he moves
	var top: String = outfit.get("top", "")
	_top.visible = top != "" and _has_tex(top)
	if _top.visible:
		_set_quad_tex(_top, top)
		_clothes_material(top)
		_top.transform = f.bodyXf
	# a diamond scarf's long ends blowing in the wind, and a halo: both drawn in code
	var wind_style := Wardrobe.wind_of(neck) if not f.scarf.is_empty() and f.has("wind") else ""
	_wind.visible = WindScarf.has_style(wind_style)
	if _wind.visible:
		_wind.show_style(wind_style, still)
		_wind.place(f.wind.at, float(p.scarfS))
	_halo.visible = Halo.has_kind(hat)
	if _halo.visible:
		_halo.show_kind(hat, still)
		_halo.place(f.halo.at, f.halo.turn)


## A top's material: clipped to his body's fill (racoon_clothes.gdshader), with its tier's shine.
func _clothes_material(item_id: String) -> void:
	var mat := _top.material as ShaderMaterial
	if mat == null or mat.shader == null or mat.shader.resource_path != CLOTHES_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = load(CLOTHES_SHADER)
		var body: Dictionary = _rig.textures.body
		var body_uv := _region("body")
		body_uv = Rect2(body_uv.position / _t("body").get_size(), body_uv.size / _t("body").get_size())
		mat.set_shader_parameter("body_tex", _t("body"))
		mat.set_shader_parameter("body_rect", Vector4(body.box[0], body.box[1], body.box[2], body.box[3]))
		mat.set_shader_parameter("body_uv", Vector4(body_uv.position.x, body_uv.position.y, body_uv.size.x, body_uv.size.y))
		var ink := _col(_rig.colors.ink)
		mat.set_shader_parameter("ink", Vector3(ink.r, ink.g, ink.b))
		_top.material = mat
		_top.set_meta("item", "")
	if _top.get_meta("item", "") == item_id:
		return
	_top.set_meta("item", item_id)
	var b := _box(item_id)
	mat.set_shader_parameter("tier", int(Wardrobe.tier_of(item_id).rank) - 1)
	mat.set_shader_parameter("box", Vector4(b.position.x, b.position.y, b.size.x, b.size.y))
	mat.set_shader_parameter("seed", float(absi(hash(item_id)) % 997) / 31.0)
