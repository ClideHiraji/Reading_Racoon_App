class_name AccessPolicy
extends RefCounted
## Time-restricted access (FR-12, 06-game-design.md "Time-restricted access"):
## - class session (teacher-set window): everything allowed
## - other school hours: locked ("Come back during Reading time")
## - after school (configurable window): play up to `daily_minutes` (30) per day
## - weekends: off unless the teacher opens them, then the same daily cap
## - any other time (night, early morning): the game is sleeping
## The server decides when online (GET /api/access/student/status); offline the
## device uses the cached schedule and its clock, corrected by the last known
## server time offset (03-architecture.md "Offline and sync", open issue 10).
## No schedule yet (never synced) = open, so the app works before setup.

const DEFAULTS := {
	"class_start": "07:30", "class_end": "08:30",
	"school_start": "07:00", "school_end": "15:00",
	"after_school_start": "15:00", "after_school_end": "17:00",
	"daily_minutes": 30, "weekends_open": false,
}


## `now`: Time.get_datetime_dict_from_system()-style dict (weekday 0 = Sunday).
## Returns {status, minutes_left, message_key}. Status is one of:
## allowed, after_school, class_lock, daily_limit, weekend_lock, sleeping.
static func decide(schedule: Dictionary, now: Dictionary, minutes_used: float) -> Dictionary:
	if schedule.is_empty():
		return {"status": "allowed", "minutes_left": -1, "message_key": ""}
	var s := DEFAULTS.duplicate()
	s.merge(schedule, true)
	var t := int(now.hour) * 60 + int(now.minute)
	var cap := float(s.daily_minutes)
	var left := maxf(0.0, cap - minutes_used)
	var weekend: bool = int(now.weekday) == 0 or int(now.weekday) == 6
	if weekend:
		if not bool(s.weekends_open):
			return {"status": "weekend_lock", "minutes_left": 0, "message_key": "locked_sleep"}
		return _capped(left)
	if t >= _min(s.class_start) and t < _min(s.class_end):
		return {"status": "allowed", "minutes_left": -1, "message_key": ""}
	if t >= _min(s.school_start) and t < _min(s.school_end):
		return {"status": "class_lock", "minutes_left": 0, "message_key": "locked_class"}
	if t >= _min(s.after_school_start) and t < _min(s.after_school_end):
		return _capped(left)
	return {"status": "sleeping", "minutes_left": 0, "message_key": "locked_sleep"}


static func _capped(left: float) -> Dictionary:
	if left <= 0.0:
		return {"status": "daily_limit", "minutes_left": 0, "message_key": "locked_done"}
	return {"status": "after_school", "minutes_left": ceili(left), "message_key": ""}


static func is_open(decision: Dictionary) -> bool:
	return decision.status in ["allowed", "after_school"]


## Does playing time count against the daily cap right now?
static func counts_minutes(decision: Dictionary) -> bool:
	return decision.status == "after_school"


## "07:30" -> 450
static func _min(hhmm) -> int:
	var parts := str(hhmm).split(":")
	return int(parts[0]) * 60 + (int(parts[1]) if parts.size() > 1 else 0)
