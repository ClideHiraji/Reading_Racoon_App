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
var _held := 0                  # hold() depth: events wait in _pending until release()
var _pending := PackedStringArray()


func _init(profile_name: String = "") -> void:
	if profile_name != "":
		profile_path = "user://profile_%s.json" % profile_name
		queue_path = "user://event_queue_%s.jsonl" % profile_name
	# A crash in the middle of replace_file() can leave only the .bak copy.
	recover(profile_path)
	recover(queue_path)


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
	_pending.append(line)
	var ok := true
	if _held == 0:
		ok = _write_pending()
	_lock.unlock()
	return id if ok else ""


## A burst of events (a lesson's answers, its words, a sticker and a goal) is written in one go:
## between hold() and release() they wait in memory, then release() appends them all with a single
## file write. Opening the queue file once per event cost about 9 ms each on a Windows laptop,
## a quarter of a second at the end of every lesson (NFR-01). Holds can nest.
func hold() -> void:
	_lock.lock()
	_held += 1
	_lock.unlock()


func release() -> void:
	_lock.lock()
	_held = maxi(0, _held - 1)
	if _held == 0:
		_write_pending()
	_lock.unlock()


## Appends the waiting events to the queue file (call with _lock held).
func _write_pending() -> bool:
	if _pending.is_empty():
		return true
	var f := FileAccess.open(queue_path,
			FileAccess.READ_WRITE if FileAccess.file_exists(queue_path) else FileAccess.WRITE)
	if f == null:
		return false
	f.seek_end()
	# A crash mid-append can leave the last line without its newline. Start a
	# fresh line, or the next event would be glued onto the broken one and lost
	# with it (D-036).
	var length := f.get_length()
	if length > 0:
		f.seek(length - 1)
		var last := f.get_8()
		f.seek_end()
		if last != 10:
			f.store_8(10)
	for line in _pending:
		f.store_line(line)
	f.close()
	_pending.clear()
	return true


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
## The trimmed queue is written to a temp file and then moved over the old one,
## so a crash or power cut mid-write can never empty the queue (D-036): at
## worst the old queue survives and already-acknowledged events are sent again,
## which the server acknowledges without storing twice.
func remove_events(ids: Array, rejected: Array = []) -> void:
	if ids.is_empty() and rejected.is_empty():
		return
	var drop := {}
	for id in ids:
		drop[str(id)] = true
	for r in rejected:
		drop[str(r.get("id", ""))] = true
	_lock.lock()
	var broken := PackedStringArray()
	if FileAccess.file_exists(queue_path):
		var kept := PackedStringArray()
		for raw_line in FileAccess.get_file_as_string(queue_path).split("\n", false):
			var line := raw_line.strip_edges()   # a CR from a Windows copy is not damage
			if line.is_empty():
				continue
			if not line.ends_with("}"):
				broken.append(line)   # cut off by a crash mid-append; unreadable
			elif not drop.has(_line_id(line)):
				kept.append(line)
		var tmp := queue_path + ".tmp"
		var f := FileAccess.open(tmp, FileAccess.WRITE)
		var written := false
		if f:
			for line in kept:
				f.store_line(line)
			written = f.get_error() == OK
			f.close()
		if not (written and replace_file(tmp, queue_path)):
			DirAccess.remove_absolute(tmp)   # keep the old queue; nothing is lost
			broken.clear()
	for line in broken:
		rejected = rejected + [{"id": _line_id(line), "reason": "truncated", "line": line}]
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
	_pending.clear()
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
	return replace_file(tmp, path)


## Moves `tmp` over `path` so there is never a moment with neither file (D-036).
## Where the platform won't rename over an existing file, the old one becomes
## <path>.bak until the new one is in place; recover() brings it back after a
## crash between the two moves.
static func replace_file(tmp: String, path: String) -> bool:
	# On Windows an antivirus or the search indexer can hold a file that was just
	# written for a moment; a short retry rides that out.
	for _attempt in 3:
		if DirAccess.rename_absolute(tmp, path) == OK:
			return true
		# Only wait off the main thread (a frame must never stall, NFR-01);
		# the main thread goes straight to the .bak route below.
		if FileAccess.file_exists(path) or OS.get_thread_caller_id() == OS.get_main_thread_id():
			break
		OS.delay_msec(100)   # the source was busy
	var bak := path + ".bak"
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)
	if FileAccess.file_exists(path) and DirAccess.rename_absolute(path, bak) != OK:
		return false
	if DirAccess.rename_absolute(tmp, path) != OK:
		DirAccess.rename_absolute(bak, path)
		return false
	DirAccess.remove_absolute(bak)
	return true


## After a crash inside replace_file(), only <path>.bak may be left: restore it.
static func recover(path: String) -> void:
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".bak"):
		DirAccess.rename_absolute(path + ".bak", path)


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
