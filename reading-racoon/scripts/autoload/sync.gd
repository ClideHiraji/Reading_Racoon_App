extends Node
## Talks to the Laravel API (autoload "Sync"), FR-11 and FR-19:
## - POST /api/auth/login once, with the student's code (temporary until open issue 9)
## - POST /api/sync: uploads the event queue in order (SyncProtocol, D-008)
## - GET /api/config: remote BKT parameters and flags such as post_test_open
## - GET /api/access/student/status: the section's schedule and server time (FR-12)
## Runs at start-up, after every lesson and every few minutes; offline it simply
## waits, and the game keeps working from the local queue.

signal status_changed(text: String)

const INTERVAL := 180.0

var busy := false
var last_status := "Not connected"

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = INTERVAL
	_timer.autostart = true
	_timer.timeout.connect(sync_now)
	add_child(_timer)
	get_tree().create_timer(3.0).timeout.connect(sync_now)


func connected() -> bool:
	return GameState.device.get("token", "") != "" and server() != ""


func server() -> String:
	return str(GameState.settings.get("server_url", "")).strip_edges().trim_suffix("/")


## Signs this device in as a student with their login code.
func login(code: String) -> String:
	if server() == "":
		return "Type the server address first."
	var res := await _request("/api/auth/login", HTTPClient.METHOD_POST,
			{"login_code": code.strip_edges(), "device_name": OS.get_model_name()}, false)
	if res.code == 200 and typeof(res.body) == TYPE_DICTIONARY and res.body.has("token"):
		GameState.device = {"token": res.body.token,
				"student_name": res.body.get("user", {}).get("name", "")}
		GameState.save_profile()
		sync_now()
		return ""
	if res.code == 422:
		return "That code didn't work. Check it with the teacher."
	return "Can't reach the server (%s)." % ("offline" if res.code == 0 else str(res.code))


func logout() -> void:
	GameState.device = {}
	GameState.save_profile()
	_set_status("Not connected")


## One full round: config, schedule, then the queue in batches.
func sync_now() -> void:
	if busy or server() == "":
		return
	busy = true
	var cfg := await _request("/api/config", HTTPClient.METHOD_GET, null, false)
	if cfg.code == 200 and typeof(cfg.body) == TYPE_DICTIONARY:
		GameState.apply_server_config(cfg.body)
	if connected():
		var acc := await _request("/api/access/student/status", HTTPClient.METHOD_GET, null, true)
		if acc.code == 200 and typeof(acc.body) == TYPE_DICTIONARY:
			GameState.apply_access(acc.body)
		await _upload(int(cfg.body.get("sync", {}).get("max_batch", SyncProtocol.DEFAULT_MAX_BATCH)) \
				if typeof(cfg.body) == TYPE_DICTIONARY else SyncProtocol.DEFAULT_MAX_BATCH)
	else:
		_set_status("Not connected" if cfg.code == 200 else "Offline")
	busy = false


func _upload(max_batch: int) -> void:
	for _attempt in 20:
		var queue := GameState.store.read_queue()
		if queue.is_empty():
			_set_status("All saved to the server")
			return
		var res := await _request("/api/sync", HTTPClient.METHOD_POST,
				SyncProtocol.batch(queue, max_batch), true)
		if res.code == 401:
			_set_status("Signed out. Connect again.")
			return
		var done := SyncProtocol.handle_reply(res.code, res.body)
		if done.ack.is_empty() and done.rejected.is_empty():
			_set_status("Offline: %d waiting" % queue.size())
			return
		GameState.store.remove_events(done.ack, done.rejected)
		if typeof(res.body) == TYPE_DICTIONARY:
			GameState.set_server_time(str(res.body.get("server_time", "")))


func _set_status(text: String) -> void:
	last_status = text
	status_changed.emit(text)


## Returns {code, body}; code 0 = no connection.
func _request(path: String, method: int, body: Variant, auth: bool) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json", "Content-Type: application/json"])
	if auth:
		headers.append("Authorization: Bearer %s" % GameState.device.get("token", ""))
	var data := JSON.stringify(body) if body != null else ""
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
