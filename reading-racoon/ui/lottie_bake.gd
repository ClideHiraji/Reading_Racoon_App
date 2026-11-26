class_name LottieBake
extends Resource
## Every half-frame of a Lottie animation, worked out ahead of time by tools/lottie-bake.
## LottiePlayer uses it instead of the .json when it sits next to it, so it skips reading
## and building the animation at runtime (for the star that was about 0.5 s on a laptop).
## The draw commands are the same ones the player builds itself.

## The .json it was baked from, and that file's SHA-256: a test fails when the
## .json changes and the bake is stale.
@export var source := ""
@export var source_sha256 := ""
@export var fr := 30.0
@export var ip := 0.0
@export var op := 1.0
@export var w := 1.0
@export var h := 1.0
## Half-frame -> draw commands, as LottiePlayer._build returns them.
@export var frames := {}


## Where the bake of a .json lives: star.json -> star_bake.res.
static func path_for(json_path: String) -> String:
	return json_path.get_basename() + "_bake.res"
