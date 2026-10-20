class_name SaveStore
extends RefCounted
## Offline-first local storage (FR-11, docs/knowledge/03-architecture.md "Offline and sync").
## - profile JSON: BKT states, path progress, wallet, flags.
## - event queue (JSON Lines): every gameplay event with a client UUID and device
##   time, kept until the Laravel `/api/sync` endpoint acknowledges it (later slice).

var profile_path := "user://profile.json"
var queue_path := "user://event_queue.jsonl"


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
	var tmp := profile_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveStore: cannot write %s" % tmp)
		return false
	f.store_string(JSON.stringify(data, "", true, true))
	f.close()
	if DirAccess.rename_absolute(tmp, profile_path) == OK:
		return true
	# Some platforms refuse to rename over an existing file.
	DirAccess.remove_absolute(profile_path)
	return DirAccess.rename_absolute(tmp, profile_path) == OK


## Appends one event and returns its UUID.
func queue_event(type: String, payload: Dictionary) -> String:
	var id := uuid_v4()
	var line := JSON.stringify({
		"id": id,
		"type": type,
		"payload": payload,
		"device_time": Time.get_datetime_string_from_system(true) + "Z",
	})
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(queue_path) else FileAccess.WRITE
	var f := FileAccess.open(queue_path, mode)
	if f == null:
		push_error("SaveStore: cannot open %s" % queue_path)
		return ""
	f.seek_end()
	f.store_line(line)
	f.close()
	return id


func read_queue() -> Array:
	var out := []
	if not FileAccess.file_exists(queue_path):
		return out
	for line in FileAccess.get_file_as_string(queue_path).split("\n", false):
		var ev = JSON.parse_string(line)
		if typeof(ev) == TYPE_DICTIONARY:
			out.append(ev)
	return out


func queue_size() -> int:
	return read_queue().size()


## Removes events the server acknowledged or rejected (D-008). Rejected ones are
## kept in a side file for debugging. Everything else stays queued for a retry.
func remove_events(ids: Array, rejected: Array = []) -> void:
	if ids.is_empty() and rejected.is_empty():
		return
	var drop := {}
	for id in ids:
		drop[str(id)] = true
	for r in rejected:
		drop[str(r.get("id", ""))] = true
	var keep := read_queue().filter(func(ev): return not drop.has(str(ev.id)))
	var f := FileAccess.open(queue_path, FileAccess.WRITE)
	if f == null:
		return
	for ev in keep:
		f.store_line(JSON.stringify(ev))
	f.close()
	if not rejected.is_empty():
		var rp := queue_path.get_basename() + "_rejected.jsonl"
		var r := FileAccess.open(rp, FileAccess.READ_WRITE if FileAccess.file_exists(rp) else FileAccess.WRITE)
		if r:
			r.seek_end()
			for item in rejected:
				r.store_line(JSON.stringify(item))
			r.close()


func wipe() -> void:
	for p in [profile_path, queue_path, queue_path.get_basename() + "_rejected.jsonl"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Random (version 4) UUID, used as the idempotency key for sync.
static func uuid_v4() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4),
			h.substr(16, 4), h.substr(20, 12)]
