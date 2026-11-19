extends SceneTree
## End-to-end check of event sync (FR-11, D-008, D-036) against a running Laravel
## server. Not part of the headless suite (it needs the server). Run it on a copy
## of the project whose config/name differs, so its user:// (device token,
## downloads) never touches your own game's:
##   "C:\Program Files\Godot\Godot.exe" --headless --path <copy> -s res://tests/sync_e2e.gd
##       -- --profile=sync_e2e --server=http://127.0.0.1:8010 --code=<login code> --step=upload --n=250
## Steps:
##   upload   queue n events, sync: the queue empties, every batch acknowledged
##   offline  (server stopped) queue n events, sync: nothing is lost, a jittered backoff is set
##   resume   (server back) sync: the queue empties

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL sync_e2e: " + msg)
	else:
		print("ok   ", msg)


func _arg(key: String, fallback := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.trim_prefix("--%s=" % key)
	return fallback


func _queue(gs: Node, n: int) -> void:
	gs.store.hold()
	for i in n:
		if i % 10 == 9:
			gs.store.queue_event("usage", {"date": "2026-11-19", "minutes": float(i) / 10.0, "free_minutes": 0.0})
		else:
			gs.store.queue_event("response", {"item_id": "e2e-%d" % i, "skill": "phonics", "level": 1,
					"answer": "m", "correct": i % 3 != 0, "response_ms": 1500, "rescue": false, "num_choices": 3})
	gs.store.release()


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	var sync := root.get_node("Sync")
	var n := int(_arg("n", "250"))
	if not gs.signed_in():
		var err: String = await sync.login(_arg("code"))
		check(err == "", "signed in with the login code (%s)" % err)
	var step := _arg("step")
	match step:
		"upload":
			var before: int = gs.store.queue_size()
			_queue(gs, n)
			check(gs.store.queue_size() == before + n, "%d events queued" % n)
			await sync.sync_now()
			check(gs.store.queue_size() == 0, "every event acknowledged and removed (%d left)" % gs.store.queue_size())
			check(sync.online and sync.last_status == "All saved", "status: %s" % sync.last_status)
		"offline":
			_queue(gs, n)
			var queued: int = gs.store.queue_size()
			await sync.sync_now()
			check(not sync.online, "the server is unreachable")
			check(gs.store.queue_size() == queued, "nothing left the queue (%d of %d)" % [gs.store.queue_size(), queued])
			check(sync._wait >= 15.0 and sync._wait <= 30.0, "first retry in 15-30 s with jitter (%.1f s)" % sync._wait)
			check(sync.last_status == "Offline, will try again", "status: %s" % sync.last_status)
		"resume":
			check(gs.store.queue_size() > 0, "events from the outage are still queued (%d)" % gs.store.queue_size())
			await sync.sync_now()
			check(gs.store.queue_size() == 0, "the outage's events are delivered")
			check(sync.online, "back online")
	print("sync_e2e %s: %s" % [step, "OK" if _failures == 0 else "%d failed" % _failures])
	quit(_failures)
