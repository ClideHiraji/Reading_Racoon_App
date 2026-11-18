extends SceneTree
## Builds Racoon's Godot scene, scenes/companion/racoon_puppet.tscn (D-024): a RacoonPuppet with one
## node per part of the drawing and an AnimationPlayer whose animations are in
## assets/racoon/racoon_moves.tres. Open the scene in the editor to see his parts and to play or edit
## his moves in the Animation panel.
##
## Run it on a scratch copy of the game, never on the project while its editor is open. This folder
## is hidden from Godot (.gdignore), so copy this file into the copy (say as
## res://make_racoon_puppet.gd), import the copy (--import), then run
##   Godot --headless --path <copy> -s res://make_racoon_puppet.gd -- [--animations | --add-new]
## and copy back scenes/companion/racoon_puppet.tscn and assets/racoon/racoon_moves.tres.
## --add-new records only the moves the library doesn't have yet (and refreshes RESET), so
## keyframes edited in the editor stay as they are.
## Without --animations it keeps assets/racoon/racoon_moves.tres as it is (with any keyframes edited
## in the editor). With it, the moves are recorded again from the choreography below, which replaces
## those edits.
##
## Recording: each move below is the motion demo's script (D-024), run on a pretend clock. Every
## change it makes to his pose becomes keyframes, with the move's easing as the keys' transition.
## Moves aimed at a spot on screen key how much he looks or points at it (look_at_spot,
## point_at_spot, read_along); the game gives him the spot when it plays them.

const SCENE := "res://scenes/companion/racoon_puppet.tscn"
const MOVES := "res://assets/racoon/racoon_moves.tres"

## The rig's pose values (as the motion demo names them) and the puppet property each one keys,
## with the scale from the rig's units to the property's (degrees for angles, hop upward).
const PROPS := {
	"yaw": ["turn", "deg"], "headYaw": ["head_turn", "deg"], "pitch": ["head_up", "deg"], "roll": ["head_tilt", 1.0],
	"lean": ["lean", 1.0], "hop": ["hop", -1.0], "sq": ["squash", 1.0], "lookX": ["look_x", 1.0], "lookY": ["look_y", 1.0],
	"liftL": ["raise_left", "deg"], "liftR": ["raise_right", "deg"], "armL": ["reach_left", 1.0], "armR": ["reach_right", 1.0],
	"freeR": ["right_paw_free", 1.0], "pawS": ["paw_size", 1.0], "knock": ["knock", 1.0], "earL": ["ear_left", 1.0],
	"earR": ["ear_right", 1.0], "tailLag": ["tail_swing", "deg"], "wiggle": ["wiggle", 1.0], "walk": ["walk", 1.0],
	"lookBlend": ["look_at_spot", 1.0], "lookSweep": ["read_along", 1.0], "pointBlend": ["point_at_spot", 1.0],
	"steps": ["steps", 1.0], "strollX": ["stroll", 1.0],
}
const PAIRS := {"reach_left_to": ["tLx", "tLy"], "reach_right_to": ["tRx", "tRy"]}
## Easing to Godot's key transition (ease() curves): cubic out, cubic in, square in/out, cubic in-out.
const TRANS := {"out": 1.0 / 3.0, "inc": 3.0, "in2": 2.0, "out2": 0.5, "inout": -3.0, "lin": 1.0}


class Job:
	extends RefCounted
	signal finished
	var left := 0

	func one() -> void:
		left -= 1
		if left == 0:
			finished.emit()


var pp: RacoonPuppet
var rest := {}
var t := 0.0                # the pretend clock, ms
var segs := {}              # pose key -> [{t0, t1, a, b, e, full_t1, full_b, cut}]
var marks := {}             # "eyes"/"mouth" -> [[ms, value]]
var events: Array = []
var running := {}
var n_ev := 0
var end_t := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var redo := "--animations" in OS.get_cmdline_user_args()
	var add_new := "--add-new" in OS.get_cmdline_user_args()
	pp = RacoonPuppet.new()
	pp.name = "Racoon"
	root.add_child(pp)
	await process_frame
	rest = pp._rest()
	var lib: AnimationLibrary
	if redo or not ResourceLoader.exists(MOVES):
		lib = _record_all()
		var err := ResourceSaver.save(lib, MOVES)
		print("moves: ", lib.get_animation_list(), " saved ", err)
	elif add_new:
		lib = load(MOVES)
		lib.remove_animation("RESET")
		lib.add_animation("RESET", _reset())
		var moves := _moves()
		for name in moves:
			if not lib.has_animation(name):
				lib.add_animation(name, _finish_recording(name, _record(moves[name])))
				print("added ", name, " (%.1f s)" % lib.get_animation(name).length)
		print("moves saved ", ResourceSaver.save(lib, MOVES))
	lib = load(MOVES)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	pp.add_child(ap)
	ap.add_animation_library("", lib)
	ap.deterministic = true
	ap.playback_default_blend_time = 0.18
	_own(pp, pp)
	pp._update()
	# the head's fine mesh round the cheek fur is rebuilt when the scene loads: save plain quads, so
	# the scene file keeps short lines (the editor stalls on very long ones)
	for pair in [["Body/Head/Skull", "head"], ["Body/Head/HeadLine", "head_line"]]:
		var part: Polygon2D = pp.get_node(pair[0])
		part.set_meta("tex", "")
		pp._set_quad_tex(part, pair[1])
	var scene := PackedScene.new()
	scene.pack(pp)
	print("scene saved ", ResourceSaver.save(scene, SCENE))
	quit()


func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)


# --- the pretend clock ----------------------------------------------------------------------------

func value(key: String, at: float) -> float:
	var v: float = rest[key]
	for s in segs.get(key, []):
		if at >= s.t1:
			v = s.b
		elif at >= s.t0:
			return lerpf(s.a, s.full_b, ease_val(s.e, (at - s.t0) / (s.full_t1 - s.t0)))
		else:
			break
	return v


## The motion demo's easing curves.
static func ease_val(e: String, x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	if e == "out":
		return 1.0 - pow(1.0 - x, 3)
	if e == "inc":
		return x * x * x
	if e == "in2":
		return x * x
	if e == "out2":
		return 1.0 - (1.0 - x) * (1.0 - x)
	if e == "lin":
		return x
	if e == "back":
		var u := x - 1.0
		return 1.0 + 2.6 * u * u * u + 1.6 * u * u
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3) / 2.0


func _event(at: float, job: Job, seg) -> void:
	n_ev += 1
	events.append({"at": at, "job": job, "seg": seg, "n": n_ev})


## Tween some pose values from where they are now. A newer tween of the same value takes over.
func tw(props: Dictionary, ms: float, e := "inout") -> Job:
	var job := Job.new()
	job.left = props.size()
	if job.left == 0:
		job.left = 1
		_event(t, job, null)
		return job
	var old_jobs := []
	for key in props:
		var cur := value(key, t)
		var old = running.get(key)
		if old != null and old.seg.t1 > t:
			old.seg.t1 = t
			old.seg.b = cur
			old.seg.cut = true
			old_jobs.append(old.job)
		var seg := {"key": key, "t0": t, "t1": t + maxf(16.0, ms), "a": cur, "b": float(props[key]), "e": e, "cut": false}
		seg.full_t1 = seg.t1
		seg.full_b = seg.b
		if not segs.has(key):
			segs[key] = []
		segs[key].append(seg)
		running[key] = {"seg": seg, "job": job}
		_event(seg.t1, job, seg)
	for j in old_jobs:
		j.one()
	return job


## Set a pose value at once.
func now(key: String, v: float) -> void:
	tw({key: v}, 1.0, "lin")


func wait(ms: float) -> Job:
	var job := Job.new()
	job.left = 1
	_event(t + ms, job, null)
	return job


func chain(steps: Array) -> void:
	for s in steps:
		await tw(s[0], s[1], s[2] if s.size() > 2 else "inout").finished


func face(e: String, m := "") -> void:
	if e != "":
		marks.eyes.append([t, e])
	if m != "":
		marks.mouth.append([t, m])


func _record(fn: Callable) -> Animation:
	t = 0.0
	segs = {}
	marks = {"eyes": [], "mouth": []}
	events = []
	running = {}
	end_t = -1.0
	_main(fn)
	while not events.is_empty():
		events.sort_custom(func(a, b): return a.at < b.at or (a.at == b.at and a.n < b.n))
		var ev: Dictionary = events.pop_front()
		if ev.at > 30000.0:
			break
		t = ev.at
		if ev.seg != null:
			if ev.seg.cut:
				continue
			if running.has(ev.seg.key) and running[ev.seg.key].seg == ev.seg:
				running.erase(ev.seg.key)
		ev.job.one()
	var last := end_t
	for key in segs:
		for s in segs[key]:
			last = maxf(last, s.t1)
	return _animation(last)


func _main(fn: Callable) -> void:
	await fn.call()
	end_t = t


# --- from the recording to keyframes ----------------------------------------------------------------

func _put(out: Array, ms: float, v: float, tr: float) -> void:
	if not out.is_empty() and absf(out.back()[0] - ms) < 0.01:
		out[out.size() - 1] = [ms, v, tr]
	else:
		out.append([ms, v, tr])


func _keys_for(key: String) -> Array:
	var out := []
	var last_v: float = rest[key]
	var last_t := 0.0
	_put(out, 0.0, last_v, 1.0)
	for s in segs.get(key, []):
		if s.t1 - s.t0 < 0.5:
			continue
		var t0: float = s.t0
		if absf(s.a - last_v) > 1e-5:
			# a jump (a value set at once): hold the old value, then the new one a moment later
			if t0 - last_t > 1.0:
				_put(out, t0 - 1.0, last_v, 1.0)
			else:
				t0 = last_t + 1.0
		elif t0 - last_t > 1.0:
			_put(out, last_t, last_v, 1.0)
		if s.e == "back":
			# an overshoot: up past the target, then settle back (the demo's back easing peaks at 59%, +9%)
			var mid: float = s.t0 + 0.59 * (s.full_t1 - s.t0)
			_put(out, t0, s.a, 0.4)
			if mid < s.t1 - 1.0:
				_put(out, mid, s.a + 1.09 * (s.full_b - s.a), -1.6)
			_put(out, s.t1, s.b, 1.0)
		else:
			_put(out, t0, s.a, TRANS.get(s.e, -3.0))
			_put(out, s.t1, s.b, 1.0)
		last_v = s.b
		last_t = s.t1
	return out


func _conv(key: String, v: float) -> float:
	var sc = PROPS[key][1]
	if sc is String:
		return rad_to_deg(v)
	return v * float(sc)


func _animation(length_ms: float) -> Animation:
	var anim := Animation.new()
	anim.length = maxf(0.05, (length_ms + 40.0) / 1000.0)
	for key in segs:
		if not PROPS.has(key):
			continue
		var tr := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(tr, NodePath(".:" + PROPS[key][0]))
		anim.value_track_set_update_mode(tr, Animation.UPDATE_CONTINUOUS)
		for k in _keys_for(key):
			anim.track_insert_key(tr, k[0] / 1000.0, _conv(key, k[1]), k[2])
	for prop in PAIRS:
		var kx: String = PAIRS[prop][0]
		var ky: String = PAIRS[prop][1]
		if not segs.has(kx) and not segs.has(ky):
			continue
		var tr := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(tr, NodePath(".:" + prop))
		var times := {}
		var trans := {}
		for k in _keys_for(kx) + _keys_for(ky):
			times[snappedf(k[0], 0.01)] = true
			trans[snappedf(k[0], 0.01)] = k[2]
		var ts := times.keys()
		ts.sort()
		for ms in ts:
			anim.track_insert_key(tr, ms / 1000.0, Vector2(value(kx, ms), value(ky, ms)), trans[ms])
	for which in ["eyes", "mouth"]:
		if marks[which].is_empty():
			continue
		var tr := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(tr, NodePath(".:" + which))
		anim.value_track_set_update_mode(tr, Animation.UPDATE_DISCRETE)
		if marks[which][0][0] > 0.0:
			anim.track_insert_key(tr, 0.0, "open" if which == "eyes" else "w")
		for m in marks[which]:
			anim.track_insert_key(tr, m[0] / 1000.0, m[1])
	return anim


## RESET: his rest pose, which every move starts from and settles back to.
func _reset() -> Animation:
	var anim := Animation.new()
	anim.length = 0.001
	for key in PROPS:
		var tr := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(tr, NodePath(".:" + PROPS[key][0]))
		anim.track_insert_key(tr, 0.0, _conv(key, rest[key]))
	for prop in PAIRS:
		var tr := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(tr, NodePath(".:" + prop))
		anim.track_insert_key(tr, 0.0, Vector2(rest[PAIRS[prop][0]], rest[PAIRS[prop][1]]))
	for which in [["eyes", "open"], ["mouth", "w"]]:
		var tr := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(tr, NodePath(".:" + which[0]))
		anim.value_track_set_update_mode(tr, Animation.UPDATE_DISCRETE)
		anim.track_insert_key(tr, 0.0, which[1])
	return anim


func _moves() -> Dictionary:
	return {"idle": m_idle, "look": m_look, "point": m_point, "greet": m_greet, "read": m_read, "happy": m_happy,
		"thinking": m_thinking, "hint": m_hint, "encourage": m_encourage, "answer": m_answer, "rescue": m_rescue,
		"rescue_won": m_rescue_won, "level_up": m_level_up, "celebrate": m_celebrate, "nudge": m_nudge,
		"sleepy": m_sleepy, "asleep": m_asleep, "giggle": m_giggle, "spin": m_spin, "peek": m_peek, "jump": m_jump,
		# lively moves (2026-11-17): his own little life on Home, the start screen and the Closet
		"walk_around": m_walk_around, "hop_around": m_hop_around, "big_jump": m_big_jump,
		"look_around": m_look_around, "stretch": m_stretch, "dance": m_dance, "tail_wag": m_tail_wag}


func _finish_recording(name: String, anim: Animation) -> Animation:
	if name == "asleep":
		anim.loop_mode = Animation.LOOP_LINEAR
		anim.length = 2.8
	return anim


func _record_all() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	lib.add_animation("RESET", _reset())
	var moves := _moves()
	for name in moves:
		lib.add_animation(name, _finish_recording(name, _record(moves[name])))
	return lib


# --- the moves (the canvas boards' choreography, D-024) -------------------------------------------

func look_spot(ms: float, e := "out") -> Job:
	return tw({"lookBlend": 1.0}, ms, e)


func look_home(ms := 380.0) -> Job:
	return tw({"lookX": 0.0, "lookY": 0.0, "headYaw": 0.0, "pitch": 0.0, "lookBlend": 0.0}, ms)


## Point the right paw at the game's spot, looking at it.
func point() -> void:
	now("pointBlend", 1.0)
	tw({"freeR": 1.0}, 200, "out")
	look_spot(300)
	await tw({"armR": 1.0}, 380, "back").finished


func jump(h: float) -> void:
	await tw({"sq": 0.86}, 130, "out").finished
	chain([[{"sq": 1.08}, 130, "out"], [{"sq": 1.0}, 240]])
	tw({"liftL": pp.raise_to(0, -35), "liftR": pp.raise_to(1, -35)}, 200, "back")
	await tw({"hop": h}, 280, "out").finished
	await tw({"hop": 0.0}, 260, "inc").finished
	tw({"liftL": 0.0, "liftR": 0.0}, 320)
	await tw({"sq": 0.88}, 80, "out").finished
	await tw({"sq": 1.0}, 260, "back").finished


func paw_on_chin() -> void:
	var M: Dictionary = pp._art().muzzle
	var tip := pp._tip_for(0, Vector2(RacoonPuppet._ax() + M.c[0] - 2.0, RacoonPuppet._hc().y + M.c[1] + M.ry + 2.0))
	now("tLx", tip.x)
	now("tLy", tip.y)
	tw({"lookX": 0.35, "lookY": -1.0, "roll": -6.0, "headYaw": -0.1}, 260, "out")
	await tw({"armL": 1.0}, 340, "out").finished


func m_idle() -> void:
	for key in PROPS:
		now(key, rest[key])
	await wait(300).finished


func m_look() -> void:
	await look_spot(300).finished
	await wait(1200).finished
	await look_home(400).finished


func m_point() -> void:
	await point()
	await wait(1600).finished
	await tw({"armR": 0.0, "freeR": 0.0}, 360).finished
	await look_home(320).finished


func m_greet() -> void:
	face("happy", "happy")
	var w1 := pp._reach(1, -44, 1.04)
	var w2 := pp._reach(1, -72, 1.04)
	now("tRx", w1.x)
	now("tRy", w1.y)
	tw({"freeR": 1.0}, 200, "out")
	chain([[{"hop": -12.0}, 200, "out"], [{"hop": 0.0}, 220, "inc"]])
	await tw({"armR": 1.0}, 320, "back").finished
	for i in 3:
		await tw({"tRx": w2.x, "tRy": w2.y}, 210).finished
		await tw({"tRx": w1.x, "tRy": w1.y}, 210).finished
	await tw({"armR": 0.0, "freeR": 0.0}, 320).finished
	face("open", "w")


## Reading the question along with the child: his eyes go along the line, a small nod per word.
func m_read() -> void:
	await tw({"lookBlend": 1.0}, 320, "inout").finished
	var words := 5
	for i in words:
		tw({"lookSweep": (i + 0.5) / words}, 200)
		chain([[{"pitch": -0.04}, 130, "out"], [{"pitch": 0.0}, 170]])
		await wait(420).finished
	await wait(250).finished
	await tw({"lookBlend": 0.0, "lookSweep": 0.0, "lookY": 0.1}, 400).finished


func m_happy() -> void:
	face("happy", "happy")
	look_spot(200)
	await tw({"sq": 0.88}, 100, "out").finished
	chain([[{"sq": 1.05}, 140, "out"], [{"sq": 1.0}, 220]])
	tw({"liftR": pp.raise_to(1, -65)}, 160, "out")
	await tw({"hop": -26.0}, 220, "out").finished
	await tw({"hop": 0.0}, 220, "inc").finished
	chain([[{"sq": 0.92}, 80, "out"], [{"sq": 1.0}, 220, "back"]])
	await tw({"liftR": pp.raise_to(1, -20)}, 140).finished
	await tw({"liftR": pp.raise_to(1, -65)}, 140, "out").finished
	look_home(320)
	await tw({"liftR": 0.0}, 300, "back").finished
	await wait(500).finished
	face("open", "w")


func m_thinking() -> void:
	await paw_on_chin()
	await wait(1600).finished
	tw({"armL": 0.0, "roll": 0.0}, 320)
	await look_home(360).finished


func m_hint() -> void:
	await paw_on_chin()
	await wait(900).finished
	tw({"armL": 0.0, "roll": 0.0}, 320)
	await point()
	await wait(1800).finished
	await tw({"armR": 0.0, "freeR": 0.0}, 360).finished
	await look_home(360).finished


func m_encourage() -> void:
	for i in 2:
		await tw({"pitch": -0.1}, 180).finished
		await tw({"pitch": 0.02}, 200).finished
	face("happy")
	await tw({"pitch": 0.0, "sq": 0.95}, 300).finished
	await tw({"sq": 1.0}, 260, "back").finished
	await wait(600).finished
	face("open")


func m_answer() -> void:
	for i in 2:
		await tw({"pitch": -0.1}, 180).finished
		await tw({"pitch": 0.02 if i == 0 else 0.0}, 200).finished
	await point()
	await wait(1500).finished
	await tw({"armR": 0.0, "freeR": 0.0}, 360).finished
	face("happy")
	await tw({"lookX": 0.0, "lookY": 0.0, "headYaw": 0.0, "pitch": 0.0, "lookBlend": 0.0, "sq": 0.95}, 300).finished
	await tw({"sq": 1.0}, 260, "back").finished
	await wait(500).finished
	face("open")


func m_rescue() -> void:
	face("", "o")
	await tw({"sq": 1.06, "hop": -8.0}, 140, "out").finished
	await tw({"sq": 1.0, "hop": 0.0}, 200, "inc").finished
	face("happy", "happy")
	await tw({"sq": 0.88}, 120, "out").finished
	tw({"liftL": pp.raise_to(0, -30), "liftR": pp.raise_to(1, -30)}, 260, "back")
	await tw({"hop": -34.0, "sq": 1.05}, 240, "out").finished
	await tw({"hop": 0.0, "sq": 1.0}, 240, "inc").finished
	await tw({"sq": 0.92}, 80, "out").finished
	await tw({"sq": 1.0}, 220, "back").finished
	await wait(900).finished
	await tw({"liftL": 0.0, "liftR": 0.0}, 360).finished
	face("open", "w")


func m_rescue_won() -> void:
	for k in 3:
		await wait(560 if k else 400).finished
		face("happy", "happy")
		chain([[{"liftR": pp.raise_to(1, -60)}, 140, "out"], [{"liftR": 0.0}, 300, "back"]])
		await tw({"hop": -18.0, "sq": 1.04}, 120, "out").finished
		await tw({"hop": 0.0, "sq": 1.0}, 120, "inc").finished
	await jump(-56)
	await wait(500).finished
	face("open", "w")


func m_level_up() -> void:
	face("happy", "happy")
	await tw({"sq": 0.84}, 160, "out").finished
	chain([[{"sq": 1.1}, 140, "out"], [{"sq": 1.0}, 260]])
	tw({"liftL": pp.raise_to(0, -40), "liftR": pp.raise_to(1, -40)}, 220, "back")
	var spin := tw({"yaw": TAU}, 720)
	await tw({"hop": -72.0}, 340, "out").finished
	await tw({"hop": 0.0}, 320, "inc").finished
	if spin.left > 0:
		await spin.finished
	now("yaw", 0.0)
	await tw({"sq": 0.86}, 80, "out").finished
	await tw({"sq": 1.0}, 300, "back").finished
	await wait(700).finished
	await tw({"liftL": 0.0, "liftR": 0.0}, 360).finished
	face("open", "w")


## Lesson complete: three claps, a little dance, arms up.
func m_celebrate() -> void:
	face("happy", "happy")
	var ax := RacoonPuppet._ax()
	var in_l := pp._tip_for(0, Vector2(ax - 9, 292))
	var in_r := pp._tip_for(1, Vector2(ax + 9, 292))
	var out_l := pp._tip_for(0, Vector2(ax - 46, 282))
	var out_r := pp._tip_for(1, Vector2(ax + 46, 282))
	for kv in [["tLx", out_l.x], ["tLy", out_l.y], ["tRx", out_r.x], ["tRy", out_r.y]]:
		now(kv[0], kv[1])
	tw({"freeR": 1.0}, 160, "out")
	await tw({"armL": 1.0, "armR": 1.0}, 260, "out").finished
	for i in 3:
		await tw({"tLx": in_l.x, "tLy": in_l.y, "tRx": in_r.x, "tRy": in_r.y}, 110, "inc").finished
		chain([[{"sq": 0.96}, 60, "out"], [{"sq": 1.0}, 140, "out"]])
		await tw({"tLx": out_l.x, "tLy": out_l.y, "tRx": out_r.x, "tRy": out_r.y}, 160, "out").finished
	await tw({"armL": 0.0, "armR": 0.0}, 260).finished
	for i in 2:
		tw({"yaw": 0.3, "liftL": pp.raise_to(0, -35), "liftR": 0.0}, 260)
		await tw({"hop": -16.0}, 130, "out").finished
		await tw({"hop": 0.0}, 130, "inc").finished
		tw({"yaw": -0.3, "liftR": pp.raise_to(1, -35), "liftL": 0.0}, 260)
		await tw({"hop": -16.0}, 130, "out").finished
		await tw({"hop": 0.0}, 130, "inc").finished
	await tw({"yaw": 0.0, "liftL": pp.raise_to(0, -23), "liftR": pp.raise_to(1, -23)}, 280, "back").finished
	await wait(900).finished
	await tw({"liftL": 0.0, "liftR": 0.0, "freeR": 0.0}, 380).finished
	face("open", "w")


func m_nudge() -> void:
	await tw({"lookY": 0.15}, 260, "out").finished
	await point()
	for i in 2:
		await tw({"knock": 1.0}, 110, "inc").finished
		await tw({"knock": 0.0}, 170, "out").finished
	await wait(1100).finished
	await tw({"armR": 0.0, "freeR": 0.0}, 360).finished
	await look_home(320).finished


## Sleepy: a yawn and a stretch (arms up and out: straight up, they'd hide behind his head), then
## his head droops; "asleep" follows.
func m_sleepy() -> void:
	face("closed", "o")
	tw({"liftL": pp.raise_to(0, -28), "liftR": pp.raise_to(1, -28), "sq": 1.06, "pitch": 0.1}, 700)
	await wait(1100).finished
	await tw({"liftL": 0.0, "liftR": 0.0, "sq": 1.0, "pitch": 0.0}, 600).finished
	face("", "w")
	await tw({"pitch": -0.14, "roll": 7.0, "headYaw": 0.08}, 900).finished


## Asleep (loops): slow breathing, his head drooped.
func m_asleep() -> void:
	face("closed", "w")
	for kv in [["pitch", -0.14], ["roll", 7.0], ["headYaw", 0.08], ["sq", 1.01]]:
		now(kv[0], kv[1])
	await tw({"sq": 0.97}, 1400).finished
	await tw({"sq": 1.01}, 1400).finished


func m_giggle() -> void:
	face("happy", "happy")
	now("wiggle", 1.0)
	tw({"wiggle": 0.0}, 1000, "out")
	await tw({"sq": 0.9}, 90, "out").finished
	await tw({"sq": 1.05}, 140, "out").finished
	await tw({"sq": 1.0}, 220, "back").finished
	await wait(1100).finished
	face("open", "w")


func m_spin() -> void:
	await tw({"sq": 0.9}, 120, "out").finished
	chain([[{"sq": 1.06}, 160, "out"], [{"sq": 1.0}, 300]])
	chain([[{"hop": -46.0}, 380, "out"], [{"hop": 0.0}, 360, "inc"]])
	chain([[{"tailLag": -0.6}, 300, "out"], [{"tailLag": 0.0}, 500]])
	await tw({"yaw": TAU}, 760).finished
	now("yaw", 0.0)
	await tw({"sq": 0.92}, 90, "out").finished
	await tw({"sq": 1.0}, 240, "back").finished


func m_peek() -> void:
	var hc := RacoonPuppet._hc()
	var e0: Array = pp._art().eyes[0].c
	var e1: Array = pp._art().eyes[1].c
	var el := hc + Vector2(e0[0], e0[1])
	var er := hc + Vector2(e1[0], e1[1])
	for kv in [["tLx", el.x], ["tLy", el.y - 16], ["tRx", er.x], ["tRy", er.y - 16]]:
		now(kv[0], kv[1])
	tw({"pawS": 1.35, "earL": -10.0, "earR": 10.0}, 300, "out")
	await tw({"armL": 1.0, "armR": 1.0}, 360, "out").finished
	await wait(600).finished
	tw({"tLx": el.x - 24, "tRx": er.x + 24, "tLy": el.y + 6, "tRy": er.y + 6}, 260)
	await wait(260).finished
	await tw({"lookX": -1.0}, 160, "out").finished
	await wait(220).finished
	await tw({"lookX": 1.0}, 200).finished
	await wait(200).finished
	tw({"lookX": 0.0, "earL": 6.0, "earR": -6.0, "pawS": 1.0}, 160, "out")
	face("happy", "happy")
	await tw({"armL": 0.0, "armR": 0.0, "liftL": pp.raise_to(0, -20), "liftR": pp.raise_to(1, -20)}, 340, "back").finished
	await wait(900).finished
	await tw({"liftL": 0.0, "liftR": 0.0, "earL": 0.0, "earR": 0.0}, 380).finished
	face("open", "w")


func m_jump() -> void:
	await tw({"sq": 0.84}, 160, "out").finished
	face("happy", "o")
	tw({"sq": 1.1}, 140, "out")
	await tw({"hop": -80.0}, 300, "out").finished
	tw({"sq": 1.0}, 200)
	await tw({"hop": 0.0}, 280, "inc").finished
	await tw({"sq": 0.86}, 80, "out").finished
	await tw({"sq": 1.0}, 300, "back").finished
	face("open", "w")


# --- lively moves (2026-11-17) ------------------------------------------------------------------------
# Played on their own when the child hasn't touched the screen for a while (Home, the start screen,
# the Closet), and when he's tapped. Never in a lesson or while a child reads (his guardrails).

const PROFILE := 1.32         # turned to walk: about 75 degrees, so you still see his face


## Walks from where he is to x (drawing pixels), turned the way he goes, looking back at you.
func walk_to(x: float, step_ms: float) -> void:
	var from := value("strollX", t)
	var dist := x - from
	if absf(dist) < 1.0:
		return
	var dir := signf(dist)
	tw({"yaw": PROFILE * dir, "headYaw": -0.45 * dir, "lookX": -0.4 * dir}, 320)
	await tw({"walk": 1.0}, 200, "out").finished
	var n := maxi(2, roundi(absf(dist) / 14.0))     # a step every 14 drawing pixels
	tw({"strollX": x}, n * step_ms, "lin")
	await tw({"steps": value("steps", t) + n}, n * step_ms, "lin").finished
	await tw({"walk": 0.0}, 160, "out").finished


func m_walk_around() -> void:
	await walk_to(90.0, 260.0)
	await tw({"yaw": 0.0, "headYaw": 0.0, "lookX": 0.0}, 320).finished
	face("happy")
	await tw({"hop": -10.0}, 140, "out").finished
	await tw({"hop": 0.0}, 160, "inc").finished
	face("open")
	await wait(500).finished
	await walk_to(-90.0, 260.0)
	await tw({"yaw": 0.0, "headYaw": 0.0, "lookX": 0.0}, 320).finished
	tw({"lookX": 1.0}, 300, "out")
	await wait(700).finished
	await walk_to(0.0, 260.0)
	await tw({"yaw": 0.0, "headYaw": 0.0, "lookX": 0.0, "steps": 0.0}, 320).finished


## Three hops to one side and a big one back.
func m_hop_around() -> void:
	face("happy", "happy")
	for k in 3:
		await tw({"sq": 0.88}, 100, "out").finished
		tw({"yaw": 0.35, "liftL": pp.raise_to(0, -30), "liftR": pp.raise_to(1, -30)}, 200, "out")
		tw({"strollX": 40.0 * (k + 1)}, 420, "inout")
		chain([[{"sq": 1.06}, 140, "out"], [{"sq": 1.0}, 200]])
		await tw({"hop": -34.0}, 210, "out").finished
		await tw({"hop": 0.0}, 210, "inc").finished
		tw({"liftL": 0.0, "liftR": 0.0}, 200)
		await tw({"sq": 0.92}, 70, "out").finished
		await tw({"sq": 1.0}, 160, "back").finished
	await tw({"sq": 0.84}, 140, "out").finished
	tw({"yaw": -0.45, "liftL": pp.raise_to(0, -40), "liftR": pp.raise_to(1, -40)}, 220, "back")
	tw({"strollX": 0.0}, 620, "inout")
	await tw({"hop": -64.0}, 310, "out").finished
	await tw({"hop": 0.0}, 290, "inc").finished
	tw({"yaw": 0.0, "liftL": 0.0, "liftR": 0.0}, 300)
	await tw({"sq": 0.88}, 80, "out").finished
	await tw({"sq": 1.0}, 260, "back").finished
	await wait(300).finished
	face("open", "w")


## A huge jump for joy, with a spin at the top.
func m_big_jump() -> void:
	await tw({"sq": 0.78}, 200, "out").finished
	face("happy", "o")
	chain([[{"sq": 1.14}, 160, "out"], [{"sq": 1.0}, 300]])
	tw({"liftL": pp.raise_to(0, -60), "liftR": pp.raise_to(1, -60)}, 240, "back")
	tw({"yaw": TAU}, 900, "inout")
	await tw({"hop": -150.0}, 450, "out").finished
	face("happy", "happy")
	await tw({"hop": 0.0}, 420, "inc").finished
	now("yaw", 0.0)
	tw({"liftL": 0.0, "liftR": 0.0}, 360)
	await tw({"sq": 0.82}, 90, "out").finished
	await tw({"sq": 1.0}, 320, "back").finished
	await tw({"hop": -14.0}, 140, "out").finished
	await tw({"hop": 0.0}, 160, "inc").finished
	await wait(300).finished
	face("open", "w")


## Curious: a look to one side, the other, then up, ears twitching.
func m_look_around() -> void:
	tw({"headYaw": -0.5, "lookX": -1.0, "earL": -8.0}, 420)
	await wait(1000).finished
	tw({"headYaw": 0.5, "lookX": 1.0, "earL": 0.0, "earR": 8.0}, 560)
	await wait(1100).finished
	tw({"headYaw": 0.1, "lookX": 0.2, "lookY": -1.0, "pitch": 0.12, "earR": 0.0, "roll": -5.0}, 420)
	await wait(900).finished
	face("happy")
	await look_home(420).finished
	await tw({"roll": 0.0}, 200).finished
	face("open")


## A big stretch, arms up and out, standing tall.
func m_stretch() -> void:
	face("closed", "o")
	tw({"liftL": pp.raise_to(0, -28), "liftR": pp.raise_to(1, -28), "sq": 1.08, "pitch": 0.08}, 650)
	await wait(1200).finished
	face("happy", "w")
	await tw({"liftL": 0.0, "liftR": 0.0, "sq": 0.96, "pitch": 0.0}, 420).finished
	await tw({"sq": 1.0}, 260, "back").finished
	await wait(300).finished
	face("open")


## A little dance: side to side, paws up in turn, tail swinging.
func m_dance() -> void:
	face("happy", "happy")
	for k in 4:
		var s := 1.0 if k % 2 == 0 else -1.0
		tw({"yaw": 0.35 * s, "lean": 7.0 * s, "tailLag": -0.5 * s,
			"liftL": pp.raise_to(0, -35) if s > 0 else 0.0, "liftR": pp.raise_to(1, -35) if s < 0 else 0.0}, 260)
		await tw({"hop": -16.0, "sq": 1.04}, 150, "out").finished
		await tw({"hop": 0.0, "sq": 1.0}, 150, "inc").finished
		await tw({"sq": 0.94}, 60, "out").finished
		await tw({"sq": 1.0}, 140, "out").finished
	await tw({"yaw": 0.0, "lean": 0.0, "tailLag": 0.0, "liftL": pp.raise_to(0, -25), "liftR": pp.raise_to(1, -25)}, 300, "back").finished
	await wait(500).finished
	await tw({"liftL": 0.0, "liftR": 0.0}, 320).finished
	face("open", "w")


## A happy tail wag.
func m_tail_wag() -> void:
	face("happy")
	tw({"yaw": 0.25, "headYaw": -0.25, "lookX": -0.6}, 300)
	for k in 6:
		await tw({"tailLag": 0.55 if k % 2 == 0 else -0.55, "lean": 2.0 if k % 2 == 0 else -2.0}, 150).finished
	await tw({"tailLag": 0.0, "lean": 0.0, "yaw": 0.0, "headYaw": 0.0, "lookX": 0.0}, 300).finished
	await wait(300).finished
	face("open")


