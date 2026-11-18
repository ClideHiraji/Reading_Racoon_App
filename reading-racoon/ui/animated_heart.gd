class_name AnimatedHeart
extends LottiePlayer
## A lesson heart (FR-13, D-021), drawn from the team's Lottie animations by
## LottiePlayer (sharp at any size, no frames) in the lesson hearts' colors
## (coral, and the pale empty heart; D-016):
## - "regain": the empty heart fills red, squishes, bounces and gives off
##   sparks after a right answer ("Regain Heart", 3.25 s, timed like the team's
##   Regain Heart.mp4: the file's time stretch set to 1, and its black outline
##   made the same grey heart Broken Heart ends on).
## - "break": a full heart cracks and its halves fall away, leaving the empty
##   heart, after a wrong try ("Broken Heart").
## The still hearts in the row are these animations' end frames (still()), so
## a full or empty heart looks the same before, during and after a change.
## Plays once and holds the last frame.

## Per kind: the animation, its colors swapped to the hearts', and where its
## final heart sits in the box (width as a share of the box, middle point).
const KINDS := {
	"regain": {
		"file": "res://assets/anim/lottie/regain_heart.json",
		"colors": {Color(1, 0.24, 0.24): Palette.CORAL, Color(0.73, 0.64, 0.64): Color("d9cfa2"),
				Color(1, 0.48, 0.48): Color("f0a662")},
		"width": 0.494, "center": Vector2(0.497, 0.471),
	},
	"break": {
		"file": "res://assets/anim/lottie/broken_heart.json",
		"colors": {Color(1, 0, 0): Palette.CORAL, Color(0.73, 0.64, 0.64): Color("d9cfa2")},
		"width": 0.545, "center": Vector2(0.497, 0.503),
	},
}

var kind := "regain"
var _still := false


## A heart drawn `heart_px` wide (the flat heart icon's visible width).
static func make(heart_px: float, wait: float = 0.0, p_kind: String = "regain") -> AnimatedHeart:
	var h := AnimatedHeart.new()
	h.kind = p_kind
	var box: float = heart_px / float(KINDS[p_kind].width)
	h.custom_minimum_size = Vector2(box, box)
	h.size = h.custom_minimum_size
	h.delay = wait
	return h


## A heart that doesn't move: full (Regain Heart's last frame) or empty (Broken
## Heart's last frame), the same shape and size as the animated ones.
static func still(heart_px: float, full: bool) -> AnimatedHeart:
	var h := make(heart_px, 0.0, "regain" if full else "break")
	h._still = true
	return h


## Works both hearts out ahead of time, so they play smoothly the first time.
static func warm() -> void:
	for k in KINDS:
		LottiePlayer.warm_up(KINDS[k].file, KINDS[k].colors)


## Puts the drawn heart's middle on `point` (in the parent's space).
func center_on(point: Vector2) -> void:
	var middle: Vector2 = KINDS[kind].center
	position = point - middle * size


func _ready() -> void:
	load_lottie(KINDS[kind].file, KINDS[kind].colors)
	if _still:
		seek(_op)
