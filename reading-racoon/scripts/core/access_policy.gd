class_name AccessPolicy
extends RefCounted
## When the child may play. Only Adventure (lessons, pre/post-test) follows the school schedule.
## decide() must match the server's backend/app/Support/AccessDecider.php:
## - before `day_start` or after `day_end`: the game is sleeping
## - weekends: off unless the teacher opens them, then `daily_minutes` all day
## - class session (teacher's window): everything allowed
## - after school (teacher's window): up to `daily_minutes` (30) a day
## - any other weekday time: locked ("Come back during Reading time")
## The hub and its free sections stay open from `day_start` to `day_end` (hub()).
## Practice, Library and Watch & Listen share a daily free-play timer outside class (free_play()).
## Online, the server decides (GET /api/access/student/status). Offline, the game uses
## the saved schedule and the school's clock (school_clock()), fixed by the last server time.
## No schedule yet (never synced) = open, so the app works before setup.

const DEFAULTS := {
	"class_start": "07:30", "class_end": "08:30",
	"after_school_start": "15:00", "after_school_end": "17:00",
	"daily_minutes": 30, "weekends_open": false,
	"day_start": "06:00", "day_end": "21:00", "free_play_minutes": 45,
}

## School time zones as minutes east of UTC; the server sends schedule.timezone.
## shortcut: fixed offsets only (Asia/Manila has no daylight saving); add a zone here if a school outside the Philippines joins.
const SCHOOL_TZ := {"Asia/Manila": 480}


## Adventure (lessons, tests).
## `now`: a dict like Time.get_datetime_dict_from_system() (weekday 0 = Sunday).
## Returns {status, minutes_left, message_key}. Status is one of:
## allowed, after_school, class_lock, daily_limit, weekend_lock, sleeping.
static func decide(schedule: Dictionary, now: Dictionary, minutes_used: float) -> Dictionary:
	if schedule.is_empty():
		return {"status": "allowed", "minutes_left": -1, "message_key": ""}
	var s := _merged(schedule)
	var t := int(now.hour) * 60 + int(now.minute)
	var weekend: bool = int(now.weekday) == 0 or int(now.weekday) == 6
	if weekend and not bool(s.weekends_open):
		return {"status": "weekend_lock", "minutes_left": 0, "message_key": "locked_sleep"}
	if _night(s, now):
		return {"status": "sleeping", "minutes_left": 0, "message_key": "locked_sleep"}
	var left := maxf(0.0, float(s.daily_minutes) - minutes_used)
	if weekend:
		return _capped(left, _min(s.day_end) - t)
	if t >= _min(s.class_start) and t < _min(s.class_end):
		return {"status": "allowed", "minutes_left": -1, "message_key": ""}
	if t >= _min(s.after_school_start) and t < _min(s.after_school_end):
		return _capped(left, _min(s.after_school_end) - t)
	return {"status": "class_lock", "minutes_left": 0, "message_key": "locked_class"}


## Like the server, the minutes left stop at the end of the open window.
static func _capped(left: float, until_end: int) -> Dictionary:
	if left <= 0.0:
		return {"status": "daily_limit", "minutes_left": 0, "message_key": "locked_done"}
	return {"status": "after_school", "minutes_left": ceili(minf(left, until_end)), "message_key": ""}


## The hub, Closet, Stickers and Word Book: open all day, asleep at night.
## Status: allowed or sleeping.
static func hub(schedule: Dictionary, now: Dictionary) -> Dictionary:
	if schedule.is_empty() or not _night(_merged(schedule), now):
		return {"status": "allowed", "minutes_left": -1, "message_key": ""}
	return {"status": "sleeping", "minutes_left": 0, "message_key": "locked_sleep"}


## Practice, Library and Watch & Listen: open whenever the hub is. Free during class;
## other times they share `free_play_minutes` a day.
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


## When Adventure opens next, as "07:30" (a later window today, else tomorrow's first),
## for "Adventure opens at 7:30 AM". "" = no schedule. Same as AccessDecider::nextOpening().
static func adventure_opens(schedule: Dictionary, now: Dictionary, minutes_used: float) -> String:
	if schedule.is_empty():
		return ""
	var s := _merged(schedule)
	var t := int(now.hour) * 60 + int(now.minute)
	var weekday := int(now.weekday)
	var cap_left := float(s.daily_minutes) - minutes_used > 0.0
	var starts: Array = []
	if weekday == 0 or weekday == 6:
		if bool(s.weekends_open) and cap_left:
			starts = [s.day_start]
	else:
		starts = [s.class_start]
		if cap_left:
			starts.append(s.after_school_start)
	var next := ""
	for at in starts:
		if _min(at) > t and (next == "" or _min(at) < _min(next)):
			next = str(at)
	if next != "":
		return next
	var weekend_tomorrow := weekday == 5 or weekday == 6
	return str(s.day_start if weekend_tomorrow and bool(s.weekends_open) else s.class_start)


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


## The school's clock at `unix` (UTC seconds), as a datetime dict. Uses the school's
## time zone, so a tablet set to the wrong zone can't shift the windows.
## No schedule yet = the device's own zone (`device_bias`, minutes).
static func school_clock(unix: float, schedule: Dictionary, device_bias: int) -> Dictionary:
	var bias := device_bias
	if not schedule.is_empty():
		bias = SCHOOL_TZ.get(str(schedule.get("timezone", "Asia/Manila")), device_bias)
	return Time.get_datetime_dict_from_unix_time(int(unix + bias * 60.0))


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
