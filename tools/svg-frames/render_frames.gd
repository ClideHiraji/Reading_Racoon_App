extends SceneTree
## Renders every SVG in a folder to PNG with Godot's own SVG renderer, so the
## frames look the same as the game's icons (D-022). `scale` is relative to the
## SVG's size (1.28 turns a 200 px viewBox into 256 px frames). Run it with the
## game's project, e.g.:
##   Godot.exe --headless --path reading-racoon -s tools/svg-frames/render_frames.gd -- <svg dir> <png dir> 1.28

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0]
	var dst: String = args[1]
	var scale := float(args[2]) if args.size() > 2 else 1.28
	DirAccess.make_dir_recursive_absolute(dst)
	var names := Array(DirAccess.open(src).get_files()).filter(func(n): return n.ends_with(".svg"))
	names.sort()
	for n in names:
		var img := Image.new()
		var err := img.load_svg_from_string(FileAccess.get_file_as_string(src + "/" + n), scale)
		if err != OK:
			print("fail ", n, " ", err)
			continue
		img.save_png(dst + "/" + n.get_basename() + ".png")
	print("rendered ", names.size())
	quit()
