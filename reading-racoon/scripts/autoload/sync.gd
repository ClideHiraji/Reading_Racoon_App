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
## /api/access/student/status, POST /api/sync (SyncProtocol, D-008).

signal status_changed(text: String)
signal synced(remaining: int)

const SERVER_SETTING := "reading_racoon/server_url"
const INTERVAL := 120.0
const FIRST_DELAY := 4.0
const MIN_BACKOFF := 30.0
const MAX_BACKOFF := 600.0
const BATCH := 100           # small batches: short requests on slow school Wi-Fi

var busy := false
var online := false
var last_status := "Waiting"

var _wait := FIRST_DELAY
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	# Phone woke up or the app came back to the front: try soon.
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		request_soon()


func _process(delta: float) -> void:
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
func _request(path: String, method: int, data: String, auth: bool) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	http.use_threads = true
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json", "Content-Type: application/json"])
	if auth:
		headers.append("Authorization: Bearer %s" % GameState.device.get("token", ""))
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
