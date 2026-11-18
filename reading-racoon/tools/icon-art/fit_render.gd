extends SceneTree
## For fit.py: rasterises every SVG in a folder with Godot's own renderer.
##   Godot --headless --path <scratch project> -s fit_render.gd -- <svg_dir> <png_dir> <scale>
## Copy this file into a scratch Godot project; never run it in the game's folder.


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var n := 0
	for f in DirAccess.get_files_at(a[0]):
		if not f.ends_with(".svg"):
			continue
		var img := Image.new()
		if img.load_svg_from_string(FileAccess.get_file_as_string(a[0] + "/" + f), float(a[2])) == OK:
			img.save_png(a[1] + "/" + f.get_basename() + ".png")
			n += 1
		else:
			print("fit_render FAIL ", f)
	print("fit_render rendered ", n)
	quit()
