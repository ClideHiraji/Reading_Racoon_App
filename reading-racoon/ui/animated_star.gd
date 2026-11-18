class_name AnimatedStar
extends LottiePlayer
## The gold star that pops in, bursts into sparkles and settles, for stars a
## child earns (lesson stars, today's goals, a good day): the team's Star.lottie
## played live by LottiePlayer, so it is sharp at any size and needs no frames
## (D-022). Plays once and holds the star. The star settles at about half its
## box (47%), so make the box twice the size the star should end up. Flat icon
## stars stay for small UI marks (tabs, empty slots, map nodes).

const FILE := "res://assets/anim/lottie/star.json"


static func make(px: float, wait: float = 0.0) -> AnimatedStar:
	var s := AnimatedStar.new()
	s.custom_minimum_size = Vector2(px, px)
	s.delay = wait
	return s


## Works the star out ahead of time, so its first pop is smooth on slow phones.
static func warm() -> void:
	LottiePlayer.warm_up(FILE)


func _ready() -> void:
	load_lottie(FILE)
