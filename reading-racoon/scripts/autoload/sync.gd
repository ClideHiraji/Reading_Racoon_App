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
## lesson, in resumable 4 MB Range requests, every file checked against its
## SHA-256 before it's used. Release builds talk https only, and failures back
## off with jitter and honour Retry-After (D-036).

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
## Teacher videos come in 4 MB Range requests, so a dropped connection costs one
## chunk, never the whole file (D-036). A chunk stuck this long (s) is retried later.
const CHUNK := 4 * 1024 * 1024
const CHUNK_TIMEOUT := 120.0

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


## The server's base URL, or "" when there is none or it isn't allowed: release
## builds only talk https (SyncProtocol.is_allowed_server, D-036).
func server() -> String:
	var url: String = ProjectSettings.get_setting(SERVER_SETTING, "")
	if OS.is_debug_build() and GameState._args.has("server"):
		url = GameState._args.server
	url = url.strip_edges().trim_suffix("/")
	return url if SyncProtocol.is_allowed_server(url, OS.is_debug_build()) else ""


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
		_offline(SyncProtocol.retry_after(cfg.headers))
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
			# No answer, a busy server (429/503 with Retry-After) or an error:
			# nothing leaves the queue; wait and try again (D-036).
			_offline(SyncProtocol.retry_after(res.headers))
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


## One file to <local>.part in CHUNK-sized Range requests, checked against its
## SHA-256, then moved into place (D-036). A dropped connection, a lesson
## starting or the app closing costs at most one chunk: the part stays and the
## next round carries on from its size. True once the file is saved.
func _download(f: Dictionary) -> bool:
	var part: String = f.local + ".part"
	var size := int(f.get("size", 0))
	var have := _file_size(part)
	if size > 0 and have > size:
		DirAccess.remove_absolute(part)   # not this file: start again
		have = 0
	var auth := "Authorization: Bearer %s" % GameState.device.get("token", "")
	while size <= 0 or have < size:
		if GameState.in_lesson() or not unmetered():
			return false   # keep the part for later
		var last := have + CHUNK - 1
		if size > 0:
			last = mini(last, size - 1)
		var res := await _http(str(f.url), HTTPClient.METHOD_GET, "",
				PackedStringArray([auth, "Range: bytes=%d-%d" % [have, last]]), CHUNK_TIMEOUT, CHUNK + 65536)
		var body: PackedByteArray = res.body
		var whole: bool = res.code == 200 and have == 0   # a server that ignores Range
		if res.code == 416 and size <= 0 and have > 0:
			break   # size unknown (page pictures) and the part already ends where the file does
		if res.code == 206 and not SyncProtocol.range_starts_at(res.headers, have):
			DirAccess.remove_absolute(part)   # not the bytes we asked for
			return false
		if res.code != 206 and not whole:
			return false   # offline or an error: the part waits for the next round
		if not await _on_worker(func(): return _append(part, body, whole)):
			return false
		have += body.size()
		if whole or (size <= 0 and body.size() < CHUNK):
			break
	var ok: bool = await _on_worker(func(): return ContentPlan.file_sha256(part) == str(f.sha256))
	if not ok:
		DirAccess.remove_absolute(part)
		return false
	# Over a file the teacher replaced; on the worker, as it may wait out a file lock.
	return await _on_worker(func(): return SaveStore.replace_file(part, f.local))


static func _file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else 0


## Appends one downloaded chunk (or writes the whole file when `fresh`).
static func _append(path: String, bytes: PackedByteArray, fresh: bool) -> bool:
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) and not fresh else FileAccess.WRITE
	var f := FileAccess.open(path, mode)
	for _attempt in 2:   # a file lock (antivirus, indexer) usually clears in a moment
		if f != null:
			break
		OS.delay_msec(150)
		f = FileAccess.open(path, mode)
	if f == null:
		return false
	f.seek_end()
	f.store_buffer(bytes)
	var ok := f.get_error() == OK
	f.close()
	return ok




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


func _offline(retry_after := 0.0) -> void:
	online = false
	_failures += 1
	_wait = SyncProtocol.backoff(_failures, retry_after, randf(), MIN_BACKOFF, MAX_BACKOFF)
	busy = false
	_set_status("Offline, will try again")


func _done(text: String, remaining: int) -> void:
	_failures = 0
	_wait = INTERVAL * randf_range(0.8, 1.2)   # spread a classroom's syncs (D-036)
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


## Returns {code, body, headers}; code 0 = no connection. HTTP runs on its own thread.
func _request(path: String, method: int, data: String, auth: bool,
		extra := PackedStringArray()) -> Dictionary:
	var headers := PackedStringArray(["Accept: application/json", "Content-Type: application/json"])
	if auth:
		headers.append("Authorization: Bearer %s" % GameState.device.get("token", ""))
	headers.append_array(extra)
	var res := await _http(path, method, data, headers, 20.0, 0)
	# Wi-Fi that drops a connection mid-reply: a read is safe to repeat at once
	# (D-036). Uploads aren't repeated here; the sync loop's backoff handles them.
	if method == HTTPClient.METHOD_GET and res.result in [HTTPRequest.RESULT_CONNECTION_ERROR,
			HTTPRequest.RESULT_NO_RESPONSE]:
		await get_tree().create_timer(1.5, true).timeout
		res = await _http(path, method, data, headers, 20.0, 0)
	var text: String = (res.body as PackedByteArray).get_string_from_utf8()
	res.body = JSON.parse_string(text) if text != "" else null
	return res


## One HTTP exchange: {code, result, headers, body: PackedByteArray}; code 0 =
## no connection or timed out (`result` says which, HTTPRequest.Result). TLS
## certificates are checked (HTTPRequest's default).
func _http(path: String, method: int, data: String, headers: PackedStringArray,
		timeout: float, body_limit: int) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout
	http.use_threads = true
	if body_limit > 0:
		http.body_size_limit = body_limit
	add_child(http)
	var err := http.request(server() + path, headers, method, data)
	if err != OK:
		http.queue_free()
		return {"code": 0, "result": HTTPRequest.RESULT_CANT_CONNECT, "headers": PackedStringArray(),
				"body": PackedByteArray()}
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "result": result[0], "headers": PackedStringArray(), "body": PackedByteArray()}
	return {"code": int(result[1]), "result": result[0], "headers": result[2], "body": result[3]}
