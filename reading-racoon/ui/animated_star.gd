class_name AnimatedStar
extends TextureRect
## The gold star that pops in, flips and settles, for stars a child earns
## (lesson stars, today's goals, a good day). It is the animated SVG in
## assets/icons, sampled into frames in assets/anim/star and rendered by Godot's
## own SVG renderer, since Godot can't play SVG animation (D-022). Plays once
## and holds the last frame. The star settles at about half its box, so make
## the box twice the size the star should end up. Flat icon stars stay for
## small UI marks (tabs, empty slots, map nodes). The frames are 256 px, which
## is fine while it moves; once it settles it swaps to a sharp 768 px copy of the
## last frame, since that is what the child looks at.

const FRAMES := 46
const FPS := 30.0

static var _frames: Array[Texture2D] = []
static var _settled: Texture2D

## Seconds to wait before it pops in (to stagger a row of stars).
@export var delay := 0.0
@export var loop := false

var _t := 0.0


static func make(px: float, wait: float = 0.0) -> AnimatedStar:
	var s := AnimatedStar.new()
	s.custom_minimum_size = Vector2(px, px)
	s.delay = wait
	return s


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _ready() -> void:
	if _frames.is_empty():
		for i in FRAMES:
			_frames.append(load("res://assets/anim/star/star_%02d.png" % i))
		_settled = load("res://assets/anim/star/star_settled.png")
	texture = _frames[0]


## Starts again from the pop-in.
func replay() -> void:
	_t = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	var f := int(maxf(_t - delay, 0.0) * FPS)
	if loop:
		f %= FRAMES
	elif f >= FRAMES - 1:
		set_process(false)
		texture = _settled
		return
	texture = _frames[f]
