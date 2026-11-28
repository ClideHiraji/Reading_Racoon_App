class_name SyncProtocol
extends RefCounted
## The game's side of offline sync (see backend/README.md).
## Sends the oldest events in batches of up to max_batch, removes the ones the
## server accepted or rejected, and keeps the rest for a retry (never drops on a 422).
## Only logic here so it can be tested; the HTTP lives in the Sync autoload.

const DEFAULT_MAX_BATCH := 500


## The next request body: the oldest `max_batch` events in the queue.
static func batch(queue: Array, max_batch: int = DEFAULT_MAX_BATCH) -> Dictionary:
	var events := []
	for ev in queue.slice(0, maxi(max_batch, 1)):
		events.append({"id": ev.id, "type": ev.type, "payload": ev.payload,
				"device_time": ev.device_time})
	return {"events": events}


## What to remove from the queue after a reply: {"ack": [...ids], "rejected": [...]}.
## Anything else (no network, 401, 422, 5xx) removes nothing.
static func handle_reply(code: int, body: Variant) -> Dictionary:
	if code != 200 or typeof(body) != TYPE_DICTIONARY:
		return {"ack": [], "rejected": []}
	return {"ack": body.get("acknowledged", []), "rejected": body.get("rejected", [])}


## Seconds to wait after `failures` failed tries in a row: doubles from `base` up to `cap`.
## Half of it is random, so a whole class of tablets doesn't retry at the same moment.
## If the server asked for longer (Retry-After on 429/503), wait that long, up to an hour.
## `r` is a random number in [0, 1).
static func backoff(failures: int, server_wait: float, r: float,
		base := 30.0, cap := 600.0) -> float:
	var ceiling := minf(base * pow(2.0, maxi(failures, 1) - 1), cap)
	var wait := ceiling * (0.5 + 0.5 * clampf(r, 0.0, 1.0))
	return minf(maxf(wait, server_wait), 3600.0)


## Seconds from the Retry-After header (0 if missing or a date; then backoff decides).
static func retry_after(headers: PackedStringArray) -> float:
	for h in headers:
		if h.to_lower().begins_with("retry-after:"):
			var value := h.substr(12).strip_edges()
			return maxf(float(value), 0.0) if value.is_valid_float() else 0.0
	return 0.0


## Release builds only talk to the server over https: the token and the kids' answers
## travel over school Wi-Fi, and Android blocks plain http anyway.
## Localhost is still allowed for a server on the same machine.
static func is_allowed_server(url: String, debug_build: bool) -> bool:
	if url.is_empty():
		return false
	if debug_build or url.begins_with("https://"):
		return true
	var host := url.trim_prefix("http://").get_slice("/", 0).get_slice(":", 0)
	return url.begins_with("http://") and host in ["127.0.0.1", "localhost"]


## A 206 reply's Content-Range must start right where our downloaded part ends,
## or adding it would break the file.
static func range_starts_at(headers: PackedStringArray, offset: int) -> bool:
	for h in headers:
		if h.to_lower().begins_with("content-range:"):
			return h.substr(14).strip_edges().begins_with("bytes %d-" % offset)
	return false


## At sign-in: take the server's copy of the child's save file instead of this laptop's?
## Yes when the server's copy is newer than the last copy this laptop sent or took, and
## no answers are still waiting here (those would be newer). Both times are the server's
## "2026-12-01T00:30:12.123456Z" text, which sorts like time. "" = none.
static func take_server_profile(server_saved_at: String, local_saved_at: String, waiting: int) -> bool:
	return server_saved_at != "" and waiting == 0 and server_saved_at > local_saved_at


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


## BKT numbers from GET /api/config, shaped like SkillCatalog.PARAMS.
## Unknown or incomplete skills keep the built-in numbers.
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
