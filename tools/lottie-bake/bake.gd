extends SceneTree
## Bakes a Lottie .json into a LottieBake (every half-frame's draw commands), so
## the game plays it without reading, preparing or building it (D-022). The bake
## is saved next to the .json (star.json -> star_bake.res). Run from the repo
## root, on a copy of the project if the Godot editor is open on reading-racoon/:
##   Godot.exe --headless --path reading-racoon -s ../tools/lottie-bake/bake.gd -- res://assets/anim/lottie/star.json

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var failed := 0
	for path in args:
		failed += _bake(path)
	quit(failed)


func _bake(path: String) -> int:
	LottiePlayer._cache.clear()
	LottiePlayer._built.clear()
	var p := LottiePlayer.new()
	p.load_lottie(path, {}, false)
	if p._data.is_empty():
		printerr("can't read ", path)
		p.free()
		return 1
	var frames := {}
	var f := p._ip
	while f < p._op:
		frames[f] = p._build(f)
		f += 0.5
	var bake := LottieBake.new()
	bake.source = path
	bake.source_sha256 = FileAccess.get_sha256(path)
	bake.fr = p._fr
	bake.ip = p._ip
	bake.op = p._op
	bake.w = p._w
	bake.h = p._h
	bake.frames = frames
	p.free()
	var out := LottieBake.path_for(path)
	var err := ResourceSaver.save(bake, out, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		printerr("can't save ", out, ": ", err)
		return 1
	print("baked %s: %d half-frames -> %s (%d bytes)" % [path, frames.size(), out,
			FileAccess.get_file_as_bytes(out).size()])
	return 0
