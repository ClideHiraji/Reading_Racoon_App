class_name SyncProtocol
extends RefCounted
## The client side of the offline sync contract (FR-11, D-008, backend/README.md):
## queue order, batches of at most max_batch, drop acknowledged and rejected ids,
## keep everything else for a retry, never drop anything on a 422.
## Pure functions so they're unit-tested; the HTTP lives in the Sync autoload.

const DEFAULT_MAX_BATCH := 500


## The next request body: the oldest `max_batch` queued events.
static func batch(queue: Array, max_batch: int = DEFAULT_MAX_BATCH) -> Dictionary:
	var events := []
	for ev in queue.slice(0, maxi(max_batch, 1)):
		events.append({"id": ev.id, "type": ev.type, "payload": ev.payload,
				"device_time": ev.device_time})
	return {"events": events}


## What to remove from the queue after a reply: {"ack": [...ids], "rejected": [...]}.
## Anything else (network error, 401, 422, 5xx) removes nothing.
static func handle_reply(code: int, body: Variant) -> Dictionary:
	if code != 200 or typeof(body) != TYPE_DICTIONARY:
		return {"ack": [], "rejected": []}
	return {"ack": body.get("acknowledged", []), "rejected": body.get("rejected", [])}


## Seconds the server clock is ahead of this device (for the play-time limits).
static func clock_offset(server_time: String, device_unix: float) -> int:
	if server_time.is_empty():
		return 0
	var s := server_time.replace("Z", "")
	var dot := s.find(".")
	if dot >= 0:
		s = s.substr(0, dot)
	var plus := s.rfind("+")
	if plus > 10:
		s = s.substr(0, plus)
	return int(Time.get_unix_time_from_datetime_string(s) - device_unix)


## BKT parameters from GET /api/config (FR-19 remote config), in the shape of
## SkillCatalog.PARAMS. Unknown or incomplete skills keep the built-in values.
static func params_from_config(cfg: Dictionary) -> Dictionary:
	var out := SkillCatalog.PARAMS.duplicate(true)
	var skills: Dictionary = cfg.get("bkt", {}).get("skills", {})
	for skill in skills:
		if not out.has(skill):
			continue
		var s: Dictionary = skills[skill]
		if s.has_all(["l0", "t", "g", "s"]) and 1.0 - float(s.s) > float(s.g):
			out[skill] = {"l0": float(s.l0), "t": float(s.t), "g": float(s.g), "s": float(s.s)}
	return out
