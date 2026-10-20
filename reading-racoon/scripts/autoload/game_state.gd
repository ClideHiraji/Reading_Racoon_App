extends Node
## Global game state (autoload "GameState"): the learner's model, path, wallet and
## content, loaded from and saved to the device after every answer (FR-11).
## A student signs in once per device with their login code (D-010); each student
## has their own profile and event queue, so a shared tablet never mixes data.

signal wallet_changed
signal outfit_changed

const LINES_PATH := "res://content/companion_lines.json"

var model := StudentModel.new()
var path := PathProgress.new()
var bank := QuestionBank.new()
var store: SaveStore
var wallet := {"xp": 0, "coins": 0}
var flags: Array = []
var lines := {}
## Racoon's outfit and the items bought in the shop (FR-07).
var wardrobe := Wardrobe.new()
## Pre/post-test records: {"pre": {date, correct, total, scores, placed_level}, "post": ...}
var assessments := {}
## Flags the teacher controls on the server (GET /api/config), e.g. post_test_open.
var settings := {"post_test_open": false}
## Play-time limits (FR-12): the section schedule cached from the server, the
## server-minus-device clock offset (seconds), and the last time the device saw.
var access := {"schedule": {}, "server_offset": 0, "last_seen": 0}
## Minutes played today that count against the after-school cap.
var usage := {"date": "", "minutes": 0.0}
## This device's sign-in with the Laravel API: {"token", "student_name", "student_id"}
## (FR-01, D-010). Kept in its own file, outside any student's profile.
var device := {}

const PLAY_SCENES := ["LearningPath", "Lesson", "LessonComplete", "Shop"]
var _usage_tick := 0.0
var _decision := {}
var _decision_age := 99.0
var _debug_now := {}

## Set by the path before opening a lesson.
var lesson_world := 1
var lesson_node := 0
var lesson_as_bonus := false
## "lesson", or "pre" / "post" for the Reading Adventure tests (FR-02, FR-10).
var lesson_mode := "lesson"
## Tests set this to make item picks repeatable; -1 = random.
var lesson_seed := -1
## Set by the lesson for the lesson-complete screen.
var last_summary := {}

var _args := {}


func _ready() -> void:
	_args = _parse_args()
	device = SaveStore.read_json(_device_path())
	store = SaveStore.new(_args.get("profile", _profile_name()))
	bank.load_file()
	var data = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
	lines = data if typeof(data) == TYPE_DICTIONARY else {}
	load_profile()
	if _args.has("fresh"):
		reset_progress()
	_debug_hooks()


func load_profile() -> void:
	var data := store.load_profile()
	model.from_dict(data.get("model", {}))
	path.from_dict(data.get("path", {}))
	var w: Dictionary = data.get("wallet", {})
	wallet = {"xp": int(w.get("xp", 0)), "coins": int(w.get("coins", 0))}
	flags = data.get("flags", [])
	assessments = data.get("assessments", {})
	settings.merge(data.get("settings", {}), true)
	wardrobe.from_dict(data.get("wardrobe", {}))
	access.merge(data.get("access", {}), true)
	usage = {"date": "", "minutes": 0.0}
	usage.merge(data.get("usage", {}), true)
	if data.has("bkt_params"):
		model.params = SyncProtocol.params_from_config({"bkt": {"skills": data.bkt_params}})
	_check_clock()


func save_profile() -> void:
	store.save_profile({
		"version": 1,
		"model": model.to_dict(),
		"path": path.to_dict(),
		"wallet": wallet,
		"flags": flags,
		"assessments": assessments,
		"settings": settings,
		"wardrobe": wardrobe.to_dict(),
		"access": access,
		"usage": usage,
		"bkt_params": model.params,
	})


# --- Sign-in (FR-01, D-010) -----------------------------------------------------------

func signed_in() -> bool:
	return str(device.get("token", "")) != ""


func student_name() -> String:
	return str(device.get("student_name", ""))


## Called by Sync after a successful login: remember the device's student and
## switch to that student's own profile and event queue.
func sign_in(token: String, child_name: String, student_id: int) -> void:
	device = {"token": token, "student_name": child_name, "student_id": student_id}
	SaveStore.write_json(_device_path(), device)
	if not _args.has("profile"):
		store = SaveStore.new(_profile_name())
		load_profile()
	outfit_changed.emit()
	wallet_changed.emit()


## "Switch student": only when everything is saved to the server, so nothing
## is lost. Returns false (and changes nothing) while answers are still waiting.
func sign_out() -> bool:
	if store.queue_size() > 0:
		return false
	device = {}
	DirAccess.remove_absolute(_device_path())
	if not _args.has("profile"):
		store = SaveStore.new(_profile_name())
		load_profile()
	return true


## The server no longer accepts the token (401): ask for the code again, but keep
## the same student's profile and unsent answers; they upload after signing in.
func forget_token() -> void:
	device.token = ""
	SaveStore.write_json(_device_path(), device)


## user://device.json (tests and debug profiles get their own file).
func _device_path() -> String:
	return "user://device_%s.json" % _args.profile if _args.has("profile") else "user://device.json"


func _profile_name() -> String:
	return "s%d" % int(device.student_id) if device.has("student_id") else ""


func reset_progress() -> void:
	model.reset()
	path = PathProgress.new()
	wallet = {"xp": 0, "coins": 0}
	flags = []
	assessments = {}
	wardrobe = Wardrobe.new()
	save_profile()
	outfit_changed.emit()


## Highest map level with content; worlds above it show "coming soon".
func content_max_level() -> int:
	return bank.max_level()


func world_cleared(level: int) -> bool:
	return model.is_level_complete(level)


func world_unlocked(level: int) -> bool:
	return level <= model.highest_unlocked and level <= content_max_level()


func start_lesson(world: int, node: int, as_bonus: bool) -> void:
	if not guard():
		return
	lesson_mode = "lesson"
	lesson_world = world
	lesson_node = node
	lesson_as_bonus = as_bonus
	get_tree().change_scene_to_file("res://scenes/lesson/lesson.tscn")


## The Reading Adventure: "pre" before the first lesson, "post" when the teacher
## opens it at the end of the study (FR-02, FR-10).
func start_assessment(kind: String) -> void:
	if not guard():
		return
	lesson_mode = kind
	lesson_world = 1
	get_tree().change_scene_to_file("res://scenes/lesson/lesson.tscn")


func needs_pretest() -> bool:
	return not assessments.has("pre")


func post_test_ready() -> bool:
	return bool(settings.get("post_test_open", false)) and assessments.has("pre") \
			and not assessments.has("post")


## A LessonSession, or an AssessmentSession for the pre/post-test (same interface).
func new_session() -> RefCounted:
	if lesson_mode in ["pre", "post"]:
		return AssessmentSession.new(model, lesson_mode)
	return LessonSession.new(model, bank, lesson_world, lesson_seed)


## Called after every answer: queue the events for sync and save (FR-11).
func record(session: RefCounted) -> void:
	for ev in session.drain_events():
		store.queue_event(ev.type, ev.payload)
	save_profile()


func finish_lesson(session: RefCounted) -> void:
	if session is AssessmentSession:
		_finish_assessment(session)
		return
	record(session)
	last_summary = session.summary()
	if not session.ended_early:
		path.complete_lesson(lesson_world, lesson_node, lesson_as_bonus)
	wallet.xp += last_summary.xp
	wallet.coins += last_summary.coins
	for f in session.flags:
		flags.append(f)
	store.queue_event("lesson_end", {"level": lesson_world, "node": lesson_node,
			"correct": last_summary.correct, "total": last_summary.total,
			"stars": last_summary.stars})
	save_profile()
	wallet_changed.emit()
	_sync_soon()


## Upload right after a lesson or test while the Wi-Fi is likely still on (FR-11).
func _sync_soon() -> void:
	var sync := get_node_or_null("/root/Sync")
	if sync:
		sync.request_soon()


## A lesson or test is on screen: Sync waits so nothing can stutter (NFR-01).
func in_lesson() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.name == "Lesson"


func _finish_assessment(session: AssessmentSession) -> void:
	record(session)   # also stores the placement (pre) made by the session
	last_summary = session.summary()
	assessments[session.kind] = {"date": last_summary.date, "correct": last_summary.correct,
			"total": last_summary.total, "scores": last_summary.scores,
			"placed_level": last_summary.placed_level}
	if session.kind == "pre":
		path = PathProgress.new()
	wallet.xp += last_summary.xp
	wallet.coins += last_summary.coins
	lesson_mode = "lesson"
	save_profile()
	wallet_changed.emit()
	_sync_soon()


# --- Play-time limits (FR-12) --------------------------------------------------------

## Local wall-clock time, corrected by the last known server offset so a wrong
## device clock can't open the game early (open issue 10).
func now_dict() -> Dictionary:
	if not _debug_now.is_empty():
		return _debug_now
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var unix := Time.get_unix_time_from_system() + float(access.server_offset) + bias * 60.0
	return Time.get_datetime_dict_from_unix_time(int(unix))


func today() -> String:
	var n := now_dict()
	return "%04d-%02d-%02d" % [n.year, n.month, n.day]


func minutes_used_today() -> float:
	if usage.date != today():
		usage = {"date": today(), "minutes": 0.0}
	return float(usage.minutes)


func access_decision() -> Dictionary:
	return AccessPolicy.decide(access.schedule, now_dict(), minutes_used_today())


## Call at screen transitions: true if play is allowed now; otherwise opens the
## friendly lock screen (never closes the app) and returns false.
func guard() -> bool:
	var d := access_decision()
	if AccessPolicy.is_open(d):
		return true
	store.queue_event("access", {"status": d.status, "time": Time.get_datetime_string_from_system()})
	get_tree().change_scene_to_file("res://scenes/lock/lock_screen.tscn")
	return false


## Counts after-school minutes while a play screen is open (not on lock screens).
## The schedule decision is refreshed every few seconds, not every frame.
func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not PLAY_SCENES.has(scene.name):
		return
	_decision_age += delta
	if _decision_age >= 5.0:
		_decision_age = 0.0
		_decision = access_decision()
	if not AccessPolicy.counts_minutes(_decision):
		return
	minutes_used_today()
	usage.minutes = float(usage.minutes) + delta / 60.0
	_usage_tick += delta
	if _usage_tick >= 60.0:
		_usage_tick = 0.0
		store.queue_event("usage", {"date": usage.date, "minutes": snappedf(usage.minutes, 0.1)})
		save_profile()


# --- Server data (Sync autoload) -------------------------------------------------------

## GET /api/config (FR-19): BKT parameters and teacher-controlled flags.
func apply_server_config(cfg: Dictionary) -> void:
	model.params = SyncProtocol.params_from_config(cfg)
	if cfg.has("post_test_open"):
		settings.post_test_open = bool(cfg.post_test_open)
	set_server_time(str(cfg.get("server_time", "")))
	save_profile()


## GET /api/access/student/status (FR-12): cache the schedule for offline use.
func apply_access(body: Dictionary) -> void:
	if typeof(body.get("schedule")) == TYPE_DICTIONARY:
		access.schedule = body.schedule
	set_server_time(str(body.get("server_time", "")))
	save_profile()


func set_server_time(server_time: String) -> void:
	if server_time != "":
		access.server_offset = SyncProtocol.clock_offset(server_time, Time.get_unix_time_from_system())


## A device clock that jumped backwards is logged for the admin (03-architecture.md).
func _check_clock() -> void:
	var now := int(Time.get_unix_time_from_system())
	var last := int(access.get("last_seen", 0))
	if last > 0 and now < last - 300:
		store.queue_event("flag", {"type": "clock_jump", "from": last, "to": now})
	access.last_seen = maxi(now, last)


## Shop (FR-07). Returns Wardrobe.buy's result: bought, owned, poor or unknown.
func buy_item(id: String) -> String:
	var result := wardrobe.buy(id, wallet)
	if result == "bought":
		store.queue_event("purchase", {"item": id, "price": Wardrobe.ITEMS[id].price,
				"coins_left": wallet.coins})
		_outfit_saved()
		wallet_changed.emit()
	return result


func wear_item(id: String) -> void:
	if wardrobe.wear(id):
		_outfit_saved()


func take_off(slot: String) -> void:
	wardrobe.take_off(slot)
	_outfit_saved()


func _outfit_saved() -> void:
	store.queue_event("outfit", {"equipped": wardrobe.equipped.duplicate()})
	save_profile()
	outfit_changed.emit()


func open_chest(world: int) -> int:
	if not path.open_chest(world):
		return 0
	wallet.coins += PathProgress.CHEST_COINS
	store.queue_event("chest", {"level": world, "coins": PathProgress.CHEST_COINS})
	save_profile()
	wallet_changed.emit()
	return PathProgress.CHEST_COINS


## A random raccoon line for a state, from the bundled fallback library
## (docs/knowledge/08-ai-integration.md: offline companion dialogue).
func line(state: String) -> String:
	var options: Array = lines.get(state, [])
	if options.is_empty():
		return ""
	return options[randi_range(0, options.size() - 1)]


# --- Debug hooks (desktop testing only) ---------------------------------------
# Usage: Godot.exe --path reading-racoon -- --profile=demo --fresh
#        --scene=res://scenes/lesson/lesson.tscn --shot=user://shot.png --shot-delay=1.5

func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var parts := a.trim_prefix("--").split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else ""
	return out


func _debug_hooks() -> void:
	if not OS.is_debug_build():
		return
	if _args.has("demo"):
		_seed_demo()
	# --schedule  uses the default school schedule; --now=<weekday 0-6>:<HH>:<MM> fakes the clock.
	if _args.has("schedule"):
		access.schedule = AccessPolicy.DEFAULTS.duplicate()
	if _args.has("now"):
		var p: PackedStringArray = str(_args.now).split(":")
		_debug_now = {"year": 2026, "month": 10, "day": 21, "weekday": int(p[0]),
				"hour": int(p[1]), "minute": int(p[2]), "second": 0}
	if _args.has("scene"):
		get_tree().change_scene_to_file.call_deferred(_args.scene)
	if _args.has("shot"):
		await get_tree().create_timer(float(_args.get("shot-delay", "1.5"))).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(_args.shot)
		print("Saved screenshot to ", ProjectSettings.globalize_path(_args.shot))
		get_tree().quit()


func _seed_demo() -> void:
	path.world(1).done = 2
	wallet = {"xp": 120, "coins": 25}
	for i in 3:
		model.record(SkillCatalog.PA, 1, true, 3)
	last_summary = {"level": 1, "correct": 7, "total": 8, "accuracy": 0.875, "stars": 2,
			"xp": 70, "coins": 30, "level_up": true, "ended_early": false,
			"results": [{"correct": true}, {"correct": true}, {"correct": false},
				{"correct": true}, {"correct": true}, {"correct": true},
				{"correct": true}, {"correct": true}]}
