class_name AccessPolicy
extends RefCounted
## Time-restricted access (FR-12, 06-game-design.md "Time-restricted access").
## Only Adventure (lessons and the pre/post-test) follows the school schedule (D-015):
## - class session (teacher-set window): everything allowed
## - other school hours: locked ("Come back during Reading time")
## - after school (configurable window): play up to `daily_minutes` (30) per day
## - weekends: off unless the teacher opens them, then the same daily cap
## - any other time (night, early morning): the game is sleeping
## The hub and its free sections stay open from `day_start` to `day_end` (hub()).
## Practice, Library and Watch & Listen share a daily free-play timer outside the
## class window (free_play()).
## The server decides when online (GET /api/access/student/status); offline the
## device uses the cached schedule and its clock, corrected by the last known
## server time offset (03-architecture.md "Offline and sync", open issue 10).
## No schedule yet (never synced) = open, so the app works before setup.

const DEFAULTS := {
	"class_start": "07:30", "class_end": "08:30",
	"school_start": "07:00", "school_end": "15:00",
	"after_school_start": "15:00", "after_school_end": "17:00",
	"daily_minutes": 30, "weekends_open": false,
	"day_start": "06:00", "day_end": "21:00", "free_play_minutes": 45,
}


## Adventure (lessons, tests).
## `now`: Time.get_datetime_dict_from_system()-style dict (weekday 0 = Sunday).
## Returns {status, minutes_left, message_key}. Status is one of:
## allowed, after_school, class_lock, daily_limit, weekend_lock, sleeping.
static func decide(schedule: Dictionary, now: Dictionary, minutes_used: float) -> Dictionary:
	if schedule.is_empty():
		return {"status": "allowed", "minutes_left": -1, "message_key": ""}
	var s := _merged(schedule)
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


## The hub, Closet, Stickers and Word Book: open all day, asleep at night (D-015).
## Status: allowed or sleeping.
static func hub(schedule: Dictionary, now: Dictionary) -> Dictionary:
	if schedule.is_empty() or not _night(_merged(schedule), now):
		return {"status": "allowed", "minutes_left": -1, "message_key": ""}
	return {"status": "sleeping", "minutes_left": 0, "message_key": "locked_sleep"}


## Practice, Library and Watch & Listen (D-015): open whenever the hub is. Free
## during the class window; at other times they share `free_play_minutes` a day.
## Status: allowed, free_play (timer running), free_limit or sleeping.
static func free_play(schedule: Dictionary, now: Dictionary, minutes_used: float) -> Dictionary:
	if schedule.is_empty():
		return {"status": "allowed", "minutes_left": -1, "message_key": ""}
	var s := _merged(schedule)
	if _night(s, now):
		return {"status": "sleeping", "minutes_left": 0, "message_key": "locked_sleep"}
	var t := int(now.hour) * 60 + int(now.minute)
	var weekend: bool = int(now.weekday) == 0 or int(now.weekday) == 6
	if not weekend and t >= _min(s.class_start) and t < _min(s.class_end):
		return {"status": "allowed", "minutes_left": -1, "message_key": ""}
	var left := maxf(0.0, float(s.free_play_minutes) - minutes_used)
	if left <= 0.0:
		return {"status": "free_limit", "minutes_left": 0, "message_key": "locked_done"}
	return {"status": "free_play", "minutes_left": ceili(left), "message_key": ""}


## When Adventure opens next, as "07:30" (today's class or after-school window,
## else tomorrow's class), for "Adventure opens at 7:30 AM". "" = no schedule.
static func adventure_opens(schedule: Dictionary, now: Dictionary, minutes_used: float) -> String:
	if schedule.is_empty():
		return ""
	var s := _merged(schedule)
	var t := int(now.hour) * 60 + int(now.minute)
	var weekend: bool = int(now.weekday) == 0 or int(now.weekday) == 6
	if not weekend:
		if t < _min(s.class_start):
			return str(s.class_start)
		var cap_left := float(s.daily_minutes) - minutes_used > 0.0
		if t < _min(s.after_school_start) and cap_left:
			return str(s.after_school_start)
	return str(s.class_start)


## "15:00" -> "3:00 PM"
static func clock_text(hhmm: String) -> String:
	var m := _min(hhmm)
	var h := floori(m / 60.0) % 12
	return "%d:%02d %s" % [12 if h == 0 else h, m % 60, "AM" if m < 720 else "PM"]


static func is_open(decision: Dictionary) -> bool:
	return decision.status in ["allowed", "after_school", "free_play"]


## Does playing time count against the daily cap right now?
static func counts_minutes(decision: Dictionary) -> bool:
	return decision.status in ["after_school", "free_play"]


static func _merged(schedule: Dictionary) -> Dictionary:
	var s := DEFAULTS.duplicate()
	s.merge(schedule, true)
	return s


static func _night(s: Dictionary, now: Dictionary) -> bool:
	var t := int(now.hour) * 60 + int(now.minute)
	return t < _min(s.day_start) or t >= _min(s.day_end)


## "07:30" -> 450
static func _min(hhmm) -> int:
	var parts := str(hhmm).split(":")
	return int(parts[0]) * 60 + (int(parts[1]) if parts.size() > 1 else 0)
