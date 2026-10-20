class_name SaveStore
extends RefCounted
## Offline-first local storage (FR-11, docs/knowledge/03-architecture.md "Offline and sync").
## - profile JSON: BKT states, path progress, wallet, flags, outfit, tests.
## - event queue (JSON Lines): every gameplay event with a client UUID and device
##   time, kept until the Laravel `/api/sync` endpoint acknowledges it (D-008).
## The Sync autoload reads and trims the queue on a worker thread while the game
## keeps appending, so every queue operation holds `_lock`. Reading the head and
## trimming never JSON-parse the whole file (cheap on 2 GB phones, NFR-01).

var profile_path := "user://profile.json"
var queue_path := "user://event_queue.jsonl"

var _lock := Mutex.new()


func _init(profile_name: String = "") -> void:
	if profile_name != "":
		profile_path = "user://profile_%s.json" % profile_name
		queue_path = "user://event_queue_%s.jsonl" % profile_name


func load_profile() -> Dictionary:
	if not FileAccess.file_exists(profile_path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


## Writes to a temp file first so a crash mid-write can't corrupt the profile.
func save_profile(data: Dictionary) -> bool:
	return write_json(profile_path, data)


## Appends one event and returns its UUID.
func queue_event(type: String, payload: Dictionary) -> String:
	var id := uuid_v4()
	# Keys are sorted, so every line starts {"device_time":..,"id":"<uuid>",...
	var line := JSON.stringify({
		"id": id,
		"type": type,
		"payload": payload,
		"device_time": Time.get_datetime_string_from_system(true) + "Z",
	})
	_lock.lock()
	var f := FileAccess.open(queue_path,
			FileAccess.READ_WRITE if FileAccess.file_exists(queue_path) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
		f.close()
	_lock.unlock()
	return id if f else ""


## The whole queue, parsed. Only for tests and small queues; sync uses read_head().
func read_queue() -> Array:
	return read_head(1 << 30)


## The oldest `n` events, parsed, without reading the rest of the file.
func read_head(n: int) -> Array:
	var out := []
	_lock.lock()
	var f := FileAccess.open(queue_path, FileAccess.READ) if FileAccess.file_exists(queue_path) else null
	while f and out.size() < n and not f.eof_reached():
		var line := f.get_line()
		if line.is_empty():
			continue
		var ev = JSON.parse_string(line)
		if typeof(ev) == TYPE_DICTIONARY:
			out.append(ev)
	_lock.unlock()
	return out


## Number of queued events (counts lines; no JSON parsing).
func queue_size() -> int:
	_lock.lock()
	var n := 0
	if FileAccess.file_exists(queue_path):
		n = FileAccess.get_file_as_string(queue_path).count("\n")
	_lock.unlock()
	return n


## Removes events the server acknowledged or rejected (D-008). Rejected ones are
## kept in a side file for debugging. Everything else stays queued, in order.
func remove_events(ids: Array, rejected: Array = []) -> void:
	if ids.is_empty() and rejected.is_empty():
		return
	var drop := {}
	for id in ids:
		drop[str(id)] = true
	for r in rejected:
		drop[str(r.get("id", ""))] = true
	_lock.lock()
	if FileAccess.file_exists(queue_path):
		var kept := PackedStringArray()
		for line in FileAccess.get_file_as_string(queue_path).split("\n", false):
			if not drop.has(_line_id(line)):
				kept.append(line)
		var f := FileAccess.open(queue_path, FileAccess.WRITE)
		if f:
			for line in kept:
				f.store_line(line)
			f.close()
	if not rejected.is_empty():
		var rp := queue_path.get_basename() + "_rejected.jsonl"
		var r := FileAccess.open(rp, FileAccess.READ_WRITE if FileAccess.file_exists(rp) else FileAccess.WRITE)
		if r:
			r.seek_end()
			for item in rejected:
				r.store_line(JSON.stringify(item))
			r.close()
	_lock.unlock()


## The event UUID of a queue line, read from its fixed place (keys are sorted).
static func _line_id(line: String) -> String:
	var at := line.find("\"id\":\"")
	return line.substr(at + 6, 36) if at >= 0 else ""


func wipe() -> void:
	_lock.lock()
	for p in [profile_path, queue_path, queue_path.get_basename() + "_rejected.jsonl"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_lock.unlock()


## Atomic JSON write (temp file, then rename).
static func write_json(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveStore: cannot write %s" % tmp)
		return false
	f.store_string(JSON.stringify(data, "", true, true))
	f.close()
	if DirAccess.rename_absolute(tmp, path) == OK:
		return true
	# Some platforms refuse to rename over an existing file.
	DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


## Random (version 4) UUID, used as the idempotency key for sync.
static func uuid_v4() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4),
			h.substr(16, 4), h.substr(20, 12)]
