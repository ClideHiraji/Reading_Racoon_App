extends SceneTree
## End-to-end check of the teacher content download (D-020) against a running
## Laravel server with published content for the learner's section. Not part of
## the headless suite (it needs the server):
##   "C:\Program Files\Godot\Godot.exe" --headless --path reading-racoon -s res://tests/content_e2e.gd
##       -- --profile=content_e2e --server=http://127.0.0.1:8010 --code=<login code> --step=wifi
## Steps: metered (manifest only, no files), wifi (files downloaded and verified,
## then a 304 round that changes nothing), removed (pass --gone=<id>: its file is deleted).

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL content_e2e: " + msg)
	else:
		print("ok   ", msg)


func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.trim_prefix("--%s=" % key)
	return ""


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	var sync := root.get_node("Sync")
	if not gs.signed_in():
		var err: String = await sync.login(_arg("code"))
		check(err == "", "signed in with the login code (%s)" % err)
	var step := _arg("step")
	if step == "metered":
		gs._args["metered"] = ""
	await sync.sync_content()
	var library := SaveStore.read_json("user://content/library.json")
	var watch := SaveStore.read_json("user://content/watch.json")
	var state := SaveStore.read_json(ContentPlan.STATE)
	var books: Array = library.get("books", [])
	var videos: Array = watch.get("items", [])
	check(state.get("version", "") != "", "manifest version saved (%s)" % state.get("version", ""))
	var needed: Array = state.get("needed", [])
	match step:
		"metered":
			check(not books.is_empty() and not videos.is_empty(), "books and videos listed on mobile data")
			check(not needed.is_empty() and needed.all(func(f): return not FileAccess.file_exists(f.local)),
					"no files downloaded on mobile data")
			gs.media.load_all()
			var v: Dictionary = gs.media.media(videos[0].id)
			check(not v.is_empty() and v.get("teacher", false) and not MediaLibrary.video_ready(v),
					"the video shows as 'downloads next time there's Wi-Fi'")
		"wifi":
			for f in needed:
				check(FileAccess.file_exists(f.local), "downloaded %s" % f.local)
				check(ContentPlan.file_sha256(f.local) == f.sha256, "SHA-256 matches for %s" % f.local)
				check(not FileAccess.file_exists(f.local + ".part"), "no part file left for %s" % f.local)
			gs.media.load_all()
			var v: Dictionary = gs.media.media(videos[0].id)
			check(MediaLibrary.video_ready(v), "the video is ready to play")
			var b: Dictionary = gs.media.book(books[0].id)
			check(MediaLibrary.page_texture(b.pages[0]) != null, "the page picture loads as a texture")
			var before := str(state.version)
			await sync.sync_content()
			var again := SaveStore.read_json(ContentPlan.STATE)
			check(str(again.version) == before and again.files.size() == needed.size(),
					"an unchanged manifest (304) keeps everything")
		"removed":
			var gone := _arg("gone")
			check(not videos.any(func(w): return w.id == gone), "the removed video left the list")
			check(not FileAccess.file_exists("user://content/%s.ogv" % gone), "its file was deleted")
			check(not state.files.has("user://content/%s.ogv" % gone), "and forgotten")
	print("content_e2e %s: %s" % [step, "OK" if _failures == 0 else "%d failed" % _failures])
	quit(_failures)
