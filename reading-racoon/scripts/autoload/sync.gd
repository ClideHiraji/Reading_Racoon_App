extends Node
## Automatic sync with the Laravel API (autoload "Sync"), FR-11 and FR-19, D-010.
## Nobody configures or starts it: the server address is built into the app
## (project setting reading_racoon/server_url) and sync runs on its own:
## - soon after start-up, after every lesson or test, when the app comes back to
##   the front, and every couple of minutes;
## - when there is no internet it waits longer each time (30 s, 1, 2, 4... up to
##   10 min) and tries again, so it costs nothing while offline;
## - never while a lesson is on screen, and the queue reading, JSON building and
##   queue trimming run on a worker thread, with HTTP on its own thread, so play
##   never stutters (NFR-01, 2 GB phones).
## Calls: POST /api/auth/login (the login screen), GET /api/config, GET
## /api/access/student/status, POST /api/sync (SyncProtocol, D-008), and for
## teacher-picked books and videos GET /api/content/manifest and
## /api/content/files/{id} (D-020, server D-019): only on Wi-Fi, never during a
## lesson, every file checked against its SHA-256 before it's used.

signal status_changed(text: String)
signal synced(remaining: int)

const SERVER_SETTING := "reading_racoon/server_url"
const INTERVAL := 120.0
const FIRST_DELAY := 4.0
const MIN_BACKOFF := 30.0
const MAX_BACKOFF := 600.0
const BATCH := 100           # small batches: short requests on slow school Wi-Fi
## Teacher content (D-020): look for changes every 15 minutes, first after 20 s.
const CONTENT_INTERVAL := 900.0
const CONTENT_FIRST := 20.0
## A download stuck this long (s) is dropped and tried again later.
const DOWNLOAD_TIMEOUT := 900.0

var busy := false
var online := false
var last_status := "Waiting"

var _wait := FIRST_DELAY
var _failures := 0
var _content_wait := CONTENT_FIRST
var _content_busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	# Phone woke up or the app came back to the front: try soon.
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		request_soon()


func _process(delta: float) -> void:
	_content_wait -= delta
	if _content_wait <= 0.0 and online and not busy and not _content_busy:
		_content_wait = CONTENT_INTERVAL
		if GameState.signed_in() and not GameState.in_lesson() and unmetered():
			sync_content()
	if busy:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	if GameState.in_lesson():
		_wait = 10.0   # check again after the lesson
		return
	sync_now()


## Ask for a sync within a couple of seconds (after a lesson, on resume).
func request_soon() -> void:
	_wait = minf(_wait, 2.0)


func server() -> String:
	var url: String = ProjectSettings.get_setting(SERVER_SETTING, "")
	if OS.is_debug_build() and GameState._args.has("server"):
		url = GameState._args.server
	return url.strip_edges().trim_suffix("/")


func connected() -> bool:
	return GameState.signed_in() and server() != ""


## Signs this device in with the student's login code (login screen).
## Returns "" on success, otherwise a short message for the child or teacher.
func login(code: String) -> String:
	if server() == "":
		return "The app has no school server set. Tell your teacher."
	if not LoginCode.is_valid(code):
		return "That code is too short. Check your card."
	var res := await _request("/api/auth/login", HTTPClient.METHOD_POST,
			JSON.stringify({"login_code": LoginCode.format(code), "device_name": OS.get_model_name()}),
			false)
	if res.code == 200 and typeof(res.body) == TYPE_DICTIONARY and res.body.has("token"):
		GameState.sign_in(str(res.body.token), str(res.body.get("user", {}).get("name", "")),
				int(res.body.get("student", {}).get("id", 0)))
		request_soon()
		return ""
	if res.code == 422:
		return "That code didn't work. Ask your teacher to check it."
	if res.code == 429:
		return "Too many tries. Wait a minute, then try again."
	return "No internet right now. Connect to Wi-Fi and try again."


## One round: config, schedule, then the queue in small batches.
func sync_now() -> void:
	if busy or server() == "":
		_wait = INTERVAL
		return
	busy = true
	var cfg := await _request("/api/config", HTTPClient.METHOD_GET, "", false)
	online = cfg.code == 200
	if not online:
		_offline()
		return
	if typeof(cfg.body) == TYPE_DICTIONARY:
		GameState.apply_server_config(cfg.body)
	if not GameState.signed_in():
		_done("Online", 0)
		return
	var acc := await _request("/api/access/student/status", HTTPClient.METHOD_GET, "", true)
	if acc.code == 200 and typeof(acc.body) == TYPE_DICTIONARY:
		GameState.apply_access(acc.body)
	var max_batch := BATCH
	if typeof(cfg.body) == TYPE_DICTIONARY:
		max_batch = mini(BATCH, int(cfg.body.get("sync", {}).get("max_batch", BATCH)))
	await _upload(max_batch)


func _upload(max_batch: int) -> void:
	var store: SaveStore = GameState.store
	for _round in 50:
		if GameState.in_lesson():
			_done("Paused for the lesson", -1)   # finish after the lesson
			_wait = 10.0
			return
		# Read the head of the queue and build the JSON off the main thread.
		var prepared: Dictionary = await _on_worker(func():
			var events := store.read_head(max_batch)
			return {"count": events.size(), "body": JSON.stringify(SyncProtocol.batch(events, max_batch))})
		if prepared.count == 0:
			_done("All saved", 0)
			return
		var res := await _request("/api/sync", HTTPClient.METHOD_POST, prepared.body, true)
		if res.code == 401:
			GameState.forget_token()   # keeps the child's progress and queue
			_done("Please sign in again", -1)
			return
		var reply := SyncProtocol.handle_reply(res.code, res.body)
		if reply.ack.is_empty() and reply.rejected.is_empty():
			_offline()
			return
		await _on_worker(func():
			store.remove_events(reply.ack, reply.rejected)
			return {})
		if typeof(res.body) == TYPE_DICTIONARY:
			GameState.set_server_time(str(res.body.get("server_time", "")))
		await get_tree().process_frame   # breathe between batches
	_done("Saving", -1)
	_wait = 5.0


# --- Teacher-picked books and videos (D-020, server D-019) --------------------------

## Fetches the manifest only when it changed (ETag), saves the books and videos as
## user://content/library.json and watch.json, deletes the files of removed items,
## then downloads what's missing one file at a time. Each file lands as
## <name>.part, is checked against its SHA-256 on a worker thread and only then
## moved into place, so the Library and Watch never see half a file.
func sync_content() -> void:
	if _content_busy or server() == "" or not GameState.signed_in():
		return
	_content_busy = true
	var state := SaveStore.read_json(ContentPlan.STATE)
	var student := int(GameState.device.get("student_id", 0))
	var headers := PackedStringArray()
	if int(state.get("student", -1)) == student and str(state.get("version", "")) != "":
		headers.append('If-None-Match: "%s"' % state.version)
	var res := await _request("/api/content/manifest", HTTPClient.METHOD_GET, "", true, headers)
	var have: Dictionary = state.get("files", {})
	var needed: Array = state.get("needed", [])
	if res.code == 200 and typeof(res.body) == TYPE_DICTIONARY:
		var cleaned := ContentPlan.clean(res.body)
		needed = ContentPlan.files(cleaned)
		var gone := ContentPlan.to_delete(needed, have)
		await _on_worker(func():
			DirAccess.make_dir_recursive_absolute(ContentPlan.DIR)
			SaveStore.write_json(ContentPlan.DIR + "library.json", {"books": cleaned.books})
			SaveStore.write_json(ContentPlan.DIR + "watch.json", {"items": cleaned.watch})
			for path in gone:
				DirAccess.remove_absolute(path)
			return {})
		for path in gone:
			have.erase(path)
		state = {"student": student, "version": str(res.body.get("version", "")), "files": have,
				"needed": needed}
		SaveStore.write_json(ContentPlan.STATE, state)
		GameState.media.load_all()
	elif res.code != 304:
		_content_busy = false
		return
	for f in ContentPlan.to_download(needed, have):
		if GameState.in_lesson() or not unmetered():
			break
		if await _download(f):
			have[f.local] = f.sha256
			state["files"] = have
			SaveStore.write_json(ContentPlan.STATE, state)
	_content_busy = false


## One file to <local>.part, checked, then moved into place. A lesson starting
## cancels it (and deletes the part). True if the file was saved.
func _download(f: Dictionary) -> bool:
	var part: String = f.local + ".part"
	var http := HTTPRequest.new()
	http.use_threads = true
	http.timeout = DOWNLOAD_TIMEOUT
	http.download_file = part
	http.download_chunk_size = 65536
	if int(f.size) > 0:
		http.body_size_limit = int(f.size) + 4096
	add_child(http)
	var done := [false, 0, 0]
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray):
		done[0] = true
		done[1] = result
		done[2] = code)
	var headers := PackedStringArray(["Authorization: Bearer %s" % GameState.device.get("token", "")])
	if http.request(server() + str(f.url), headers) != OK:
		http.queue_free()
		return false
	while not done[0]:
		if GameState.in_lesson():
			http.cancel_request()
			http.queue_free()
			DirAccess.remove_absolute(part)
			return false
		await get_tree().process_frame
	http.queue_free()
	var ok: bool = done[1] == HTTPRequest.RESULT_SUCCESS and done[2] == 200
	if ok:
		ok = await _on_worker(func(): return ContentPlan.file_sha256(part) == str(f.sha256))
	if not ok:
		DirAccess.remove_absolute(part)
		return false
	if FileAccess.file_exists(f.local):
		DirAccess.remove_absolute(f.local)   # the teacher replaced it
	return DirAccess.rename_absolute(part, f.local) == OK



## Big downloads only on Wi-Fi (D-020). On Android that means any network the
## phone doesn't count as metered (export needs ACCESS_NETWORK_STATE); if the phone
## can't tell, assume mobile data and wait. Desktop and editor: always true.
## Debug builds can pretend with --metered.
func unmetered() -> bool:
	if OS.is_debug_build() and GameState._args.has("metered"):
		return false
	if OS.get_name() != "Android":
		return true
	if not Engine.has_singleton("AndroidRuntime"):
		return false
	var activity = Engine.get_singleton("AndroidRuntime").call("getActivity")
	if activity == null:
		return false
	var cm = activity.call("getSystemService", "connectivity")
	if cm == null:
		return false
	return not bool(cm.call("isActiveNetworkMetered"))


func _offline() -> void:
	online = false
	_failures += 1
	_wait = minf(MIN_BACKOFF * pow(2.0, _failures - 1), MAX_BACKOFF)
	busy = false
	_set_status("Offline, will try again")


func _done(text: String, remaining: int) -> void:
	_failures = 0
	_wait = INTERVAL
	busy = false
	_set_status(text)
	if remaining >= 0:
		synced.emit(remaining)


func _set_status(text: String) -> void:
	last_status = text
	status_changed.emit(text)


## Runs `work` on a worker thread and returns its result without blocking frames.
func _on_worker(work: Callable) -> Variant:
	var result := [null]
	var id := WorkerThreadPool.add_task(func(): result[0] = work.call())
	while not WorkerThreadPool.is_task_completed(id):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(id)
	return result[0]


## Returns {code, body}; code 0 = no connection. HTTP runs on its own thread.
func _request(path: String, method: int, data: String, auth: bool,
		extra := PackedStringArray()) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	http.use_threads = true
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json", "Content-Type: application/json"])
	if auth:
		headers.append("Authorization: Bearer %s" % GameState.device.get("token", ""))
	headers.append_array(extra)
	var err := http.request(server() + path, headers, method, data)
	if err != OK:
		http.queue_free()
		return {"code": 0, "body": null}
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": null}
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(result[1]), "body": JSON.parse_string(text) if text != "" else null}
