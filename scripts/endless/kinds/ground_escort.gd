extends Node3D
## Kind `ground_escort`: a herd that grazes on open ground and answers the
## plane (docs/design/endless-flight/spec-wild-kit-elk.md). The kind has no
## skin of its own: the site's skin picks the body (`elk`: the elk). Not an
## enemy: no attacks, no damage, nothing to take.
##
## The herd is this node, placed at the site's foot by the placed sites
## (scripts/endless/placed_sites.gd), -Z its heading (down the meadow); the
## animals are its children, each a body behind the contract's API
## (scripts/endless/kinds/escort_standin.gd, the stand-in), standing in the
## world's frame (top_level) on the land under them.
##
## The plane flown over high or slow: the near ones lift their heads and
## track it, then graze again. Skimmed low and fast past them: they bolt and
## run alongside it (sprinting at its speed, up to its cruise), each held at
## a station beside and a little ahead of the plane, on the land and off
## water, steep ground and trees, apart; after a stretch, or when the plane
## pulls away or the land won't do, they peel off, slow, halt and look back.
##
## --elk=off: the site's marker instead.

const Marker = preload("res://scripts/endless/kinds/marker.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const SELF := "res://scripts/endless/kinds/ground_escort.gd"
## The bodies by skin; the stand-in until the real elk is in.
const BODIES := {"elk": "res://scripts/endless/kinds/escort_standin.gd"}
const STANDIN := "res://scripts/endless/kinds/escort_standin.gd"

## The herd's knobs. Lengths in metres unless named in body lengths (BL).
const KNOBS := {
	# How many, and how many of them bulls.
	"count_min": 5, "count_max": 9,
	"bulls_min": 1, "bulls_max": 2,
	# Where they graze round the site's foot: along its heading (either
	# way), across it toward its right (+X; the treeline at the herd's site)
	# and its left.
	"spread_along": 22.0, "spread_right": 8.0, "spread_left": 16.0,
	# How far each faces off the herd's heading, either way (degrees).
	"face_spread": 70.0,
	# Kept apart by this many body lengths at least.
	"apart_bl": 1.6,
	# Graze clip rates, so the herd falls out of step.
	"graze_rate_min": 0.82, "graze_rate_max": 1.18,
	# Asleep (no clip, no senses) with the eye farther than this.
	"sleep": 900.0,
	# Senses. Inside `notice` m of the plane (straight-line, times each
	# animal's nerve) a grazing one lifts its head after a reaction and
	# tracks the plane; past `lose` times that it calms for a while, then
	# grazes again.
	"notice": 150.0, "nerve_min": 0.7, "nerve_max": 1.15,
	"react_min": 0.1, "react_max": 0.7,
	"lose": 1.3, "calm_min": 2.0, "calm_max": 4.5,
	# The look: its weight ramped in (after alert.up) and out per second,
	# eased at both ends, so the head turns to the plane in one quick sweep;
	# then the gaze follows it at `look_turn` / `look_pitch` (rad/s), at most
	# `look_reach` off the body's heading (held over the shoulder past that)
	# and `look_up` over level (degrees); it looks `look_lead` s ahead on the
	# plane's path.
	"look_in": 2.5, "look_out": 1.6, "look_turn": 3.2, "look_pitch": 2.0,
	"look_reach": 110.0, "look_up": 55.0, "look_lead": 0.15,
	# Alert to grazing, the blend (s).
	"settle_blend": 0.8,
	# The run beside. A plane skimmed low (under `low` m over the ground
	# under it) and fast (over `fast` x its cruise), its line within
	# `side_max` m of an animal ahead of it (or at most `behind` m behind),
	# sets that one running alongside: it bolts when the plane is close
	# enough behind that, speeding up, it is caught at its station just as it
	# reaches the plane's speed.
	"low": 24.0, "fast": 0.65, "side_max": 60.0, "behind": 8.0,
	# Out to at least `side_min` m off the plane's line; its station `lead` m
	# ahead of the plane, plus `lead_side` x its distance out (so the chase
	# camera sees it), plus `formation` x its place in the herd along the line.
	"side_min": 9.0, "lead": 4.0, "lead_side": 0.55, "formation": 0.5,
	# The top run, times the plane's cruise (read off the flight code): it
	# holds beside a plane at cruise; Boost pulls away.
	"top_run": 1.0,
	# Speeding up and braking (m/s2); the gap curve's (under the speeding up,
	# so it arrives a touch ahead and eases back); the station's stiffness
	# near it (1/s); the slowest run once off.
	"accel": 14.0, "brake": 10.0, "curve_accel": 10.5, "station": 1.2, "run_min": 12.0,
	# The reaction once the plane is in reach (s, at most); the sideways
	# steer (1/s, at most m/s); turn rates (rad/s) on the bolt, the run, the
	# peel.
	"flee_react": 0.25, "side_steer": 1.0, "side_most": 8.0,
	"turn_bolt": 5.0, "turn_run": 2.2, "turn_peel": 1.3,
	# The stretch beside the plane (s), then the peel; sooner when the plane
	# has pulled `drop` m past its station, climbed past `low` x `gone_low`,
	# slowed under `fast` x `gone_slow` of cruise, or drawn off past
	# `side_max` x `gone_side`, when the land ahead won't do, or past `leash`
	# m from home.
	"stretch_min": 6.0, "stretch_max": 9.0, "drop": 30.0,
	"gone_low": 1.8, "gone_side": 1.5, "gone_slow": 0.6, "leash": 500.0,
	# The peel: turned out from the plane's line by `peel_turn` degrees,
	# braking at `peel_brake` to the halt's speed (the stop_look's slide).
	"peel_turn": 70.0, "peel_brake": 9.0,
	# The land, probed `probe` s ahead (at least `probe_min` m; the peel its
	# stopping distance): no water, nothing steeper than `steep` (rise over
	# run) there or `climb` on the way, no trees along it (stepped round by
	# `dodge` m when a side is clear).
	"probe": 1.6, "probe_min": 12.0, "steep": 0.45, "climb": 0.3, "dodge": 8.0,
	# The trees' solid asked every this many m along a way.
	"tree_step": 3.0,
	# Gaits by speed (m/s), switched `gait_hyst` past each.
	"sprint_at": 25.0, "gallop_at": 10.5, "gait_hyst": 1.0,
	# The look while running: a glance at the plane, at this weight.
	"run_look": 0.35,
}

## The contract's ground per cycle (body lengths), so a clip plays at the
## rate its feet keep to the ground.
const GROUND_BL := {"bolt_start":1.2,"trot":2.0,"gallop":4.0,"sprint":7.0,"leap":12.6,"stop_look":0.5}
## How the one-shots that travel spread their ground over time: [time (s),
## fraction covered] (the real elk's assets/models/elk/elk_clips.json,
## `ground_curve`, lane elk-body 44b863a5); the root moves by it so planted
## feet hold still.
const GROUND_CURVE := {
	"bolt_start": [[0.0,0.0],[0.125,0.0],[0.1667,0.0064],[0.2083,0.0371],[0.25,0.1042],[0.2917,0.215],
		[0.3333,0.355],[0.375,0.5043],[0.4167,0.6586],[0.4583,0.824],[0.5,1.0]],
	"stop_look": [[0.0,0.0],[0.1,0.4898],[0.2,0.8163],[0.3,0.9796],[0.4,1.0],[1.2,1.0]],
}
const SEA_Y := -40.0

## The body length, in the plane's span (the spec's Size).
const BODY_SPANS := 0.9

var site := {}
var field: RefCounted
## One body length (m).
var bl: float = BODY_SPANS*WorldScale.span
## Each animal: {body, pos (world), heading (rad, yaw), variant, rate,
## state, nerve, wait, calm, look (weight), gaze (yaw off the heading and
## pitch, rad), speed (m/s), side (its lateral station off the plane's
## line, m, + right), lead (its station ahead of the plane, m), stretch (s
## left beside), peel (the peel's heading)}. States: `graze`; `alert` (head
## up, tracking the plane); `settle` (the look easing out, then grazing);
## `bolt` (the bolt_start clip, turning to run); `run` (beside the plane);
## `peel` (turned out, slowing); `halt` (stop_look, then `alert`).
var herd: Array = []
var asleep := false
## The sense range of the herd's widest-nerved animal, beyond which (from
## the herd's middle, plus its reach) no animal is asked (one distance a
## frame).
var _reach := 0.0
var _rng := RandomNumberGenerator.new()
var _study: Node = null
var stats := {"count":0,"bulls":0,"awake_frames":0,"sensing_frames":0,"alerts":0,"settles":0,
	"bolts":0,"peels":0,"halts":0,"beside_s":0.0,"top_speed":0.0,"probes":0,"dodges":0,"peel_why":{}}
## The herd's middle and how far its farthest animal is from it, kept as
## they move: the senses and the sleep reckon from it.
var center := Vector3.ZERO
var radius := 0.0
## The plane this frame: low and fast (`_threat`), its way over the ground
## and right of it, its ground speed, its cruise, its height over the ground.
var _threat := false
var _f := Vector3.FORWARD
var _r := Vector3.RIGHT
var _v := 0.0
var _cruise := 36.75
var _low := INF
## The next runner whose land ahead is probed (one a frame).
var _probe_next := 0

static func build(s: Dictionary) -> Node3D:
	if LaunchArgs.user_args().has("--elk=off"): return Marker.build(s)
	var node: Node3D = (load(SELF) as GDScript).new()
	node.call("_spawn",s)
	return node

## Lays the herd out round the site, deterministically from its handle.
func _spawn(s: Dictionary) -> void:
	site = s
	field = s.get("field")
	var xform: Transform3D = s.get("xform",Transform3D.IDENTITY)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(s.get("handle","herd")))
	var count := rng.randi_range(int(KNOBS.count_min),int(KNOBS.count_max))
	var bulls := rng.randi_range(int(KNOBS.bulls_min),int(KNOBS.bulls_max))
	var skin := str(s.get("skin",""))
	if not BODIES.has(skin): push_warning("ground_escort %s: no body for skin '%s', the stand-in" % [s.get("handle","?"),skin])
	var body_script: GDScript = load(BODIES.get(skin,STANDIN))
	var spots: Array[Vector3] = []
	var apart := float(KNOBS.apart_bl)*bl
	var tries := 0
	while spots.size() < count and tries < 400:
		tries += 1
		var local := Vector3(rng.randf_range(-float(KNOBS.spread_left),float(KNOBS.spread_right)),0.0,
			rng.randf_range(-float(KNOBS.spread_along),float(KNOBS.spread_along)))
		var ok := true
		for o in spots:
			if Vector2(o.x-local.x,o.z-local.z).length() < apart: ok = false
		if ok: spots.append(local)
	var herd_yaw := xform.basis.get_euler().y
	for i in range(spots.size()):
		var world := xform*spots[i]
		if field != null: world.y = float(field.height(world.x,world.z))
		var yaw := herd_yaw+deg_to_rad(rng.randf_range(-float(KNOBS.face_spread),float(KNOBS.face_spread)))
		var body: Node3D = body_script.new()
		body.name = "Elk%d" % i
		body.top_level = true
		var variant := "bull" if i < bulls else "cow"
		body.call("set_variant",variant)
		body.transform = Transform3D(Basis(Vector3.UP,yaw),world)
		add_child(body)
		var rate := rng.randf_range(float(KNOBS.graze_rate_min),float(KNOBS.graze_rate_max))
		body.call("play","graze",rate,0.0)
		var nerve := rng.randf_range(float(KNOBS.nerve_min),float(KNOBS.nerve_max))
		herd.append({"body":body,"pos":world,"heading":yaw,"variant":variant,"rate":rate,"state":"graze",
			"nerve":nerve,"wait":-1.0,"calm":0.0,"look":0.0,"gaze":Vector2.ZERO,"clip":"graze","t":0.0,
			"flee":-1.0,"speed":0.0,"side":0.0,"lead":0.0,"stretch":0.0,"peel":0.0,
			"bad":false,"hard":false,"dodge":0.0,"dodge_t":0.0,"why":""})
	stats.count = herd.size()
	stats.bulls = mini(bulls,herd.size())
	_rng.seed = rng.seed+1
	var spread := maxf(float(KNOBS.spread_along),maxf(float(KNOBS.spread_left),float(KNOBS.spread_right)))
	_reach = float(KNOBS.notice)*float(KNOBS.nerve_max)*float(KNOBS.lose)
	_recenter()
	radius = maxf(radius,spread)

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec() if FrameLog.on else 0
	var cam := get_viewport().get_camera_3d()
	if cam == null: return
	var far := Vector2(cam.global_position.x-center.x,cam.global_position.z-center.z).length() > float(KNOBS.sleep)+radius
	if far != asleep: _sleep(far)
	if not asleep:
		stats.awake_frames += 1
		_sense(delta)
	if FrameLog.on: FrameLog.add(&"herd",float(Time.get_ticks_usec()-t0)/1000.0)

# --- Senses ----------------------------------------------------------------

## The plane the herd answers: the study's (`plane`: position, velocity), found
## up the tree once. Null with no study round it (nothing to sense).
func _plane() -> RefCounted:
	if _study == null:
		var n := get_parent()
		while n != null and not (n.get("plane") is RefCounted): n = n.get_parent()
		_study = n
		if _study == null: return null
	return _study.get("plane")

## Each animal's senses and state for this frame. While the plane is beyond
## the herd's reach and everyone is grazing, one distance.
func _sense(delta: float) -> void:
	var plane := _plane()
	var at := Vector3.INF
	var vel := Vector3.ZERO
	if plane != null:
		at = plane.get("position")
		vel = plane.get("velocity")
	var near := at != Vector3.INF and at.distance_to(center) < _reach+radius
	var busy := near
	if not busy:
		for a: Dictionary in herd:
			if a.state != "graze":
				busy = true
				break
	if not busy: return
	stats.sensing_frames += 1
	_read_plane(plane,at,vel)
	var moving := false
	for a: Dictionary in herd:
		var d := INF if at == Vector3.INF else at.distance_to(a.pos)
		var reach := float(KNOBS.notice)*float(a.nerve)
		a.t = float(a.t)+delta
		match str(a.state):
			"graze":
				if _flee_step(a,at,delta): pass
				elif d < reach:
					if float(a.wait) < 0.0: a.wait = _rng.randf_range(float(KNOBS.react_min),float(KNOBS.react_max))
					a.wait = float(a.wait)-delta
					if float(a.wait) <= 0.0: _alert(a)
				else:
					a.wait = -1.0
			"alert":
				if not _flee_step(a,at,delta):
					_calm_step(a,d,reach,delta)
					if a.state == "alert" and float(a.t) >= 0.2:
						a.look = minf(float(a.look)+float(KNOBS.look_in)*delta,1.0)
			"settle":
				if _flee_step(a,at,delta): pass
				elif d < reach:
					a.state = "alert"
					a.t = 1.0
					a.calm = 0.0
				else:
					a.look = maxf(float(a.look)-float(KNOBS.look_out)*delta,0.0)
					if float(a.look) <= 0.0: _graze(a)
			"bolt":
				if at == Vector3.INF: _peel(a,"lost")
				else: _bolt_step(a,at,delta)
			"run":
				if at == Vector3.INF: _peel(a,"lost")
				else: _run_step(a,at,delta)
			"peel":
				_peel_step(a,delta)
			"halt":
				_halt_step(a,delta)
		if a.state in ["bolt","run","peel","halt"]: moving = true
		if a.state != "graze" and at != Vector3.INF: _track(a,at+vel*float(KNOBS.look_lead),delta)
	if moving:
		_probe()
		_apart(delta)
		for a: Dictionary in herd:
			if a.state in ["bolt","run","peel","halt"]: _place(a)
		_recenter()

## The plane's way over the ground, speed, height over the ground under it
## and cruise, once a frame: `_threat` when low and fast.
func _read_plane(plane: RefCounted, at: Vector3, vel: Vector3) -> void:
	_threat = false
	if plane == null or at == Vector3.INF: return
	if plane.has_method("cruise"): _cruise = float(plane.call("cruise"))
	var flat := Vector2(vel.x,vel.z)
	_v = flat.length()
	if _v > 1.0:
		_f = Vector3(flat.x/_v,0.0,flat.y/_v)
		_r = Vector3(-_f.z,0.0,_f.x)
	_low = at.y-(float(field.height(at.x,at.z)) if field != null else 0.0)
	_threat = _v >= float(KNOBS.fast)*_cruise and _low <= float(KNOBS.low)

## The top run (m/s): the plane's cruise times `top_run`.
func _top() -> float:
	return _cruise*float(KNOBS.top_run)

## Where `a` stands off the plane at `at`: (along its way, + ahead; across,
## + right).
func _off(a: Dictionary, at: Vector3) -> Vector2:
	var rel: Vector3 = a.pos-at
	return Vector2(rel.x*_f.x+rel.z*_f.z,rel.x*_r.x+rel.z*_r.z)

## Its side station: out to `side_min` off the line, on its own side (on
## the herd's, when it stands on the line).
func _side_of(lat: float, at: Vector3) -> float:
	var s := signf(lat)
	if absf(lat) < 0.5:
		var c := (center-at).dot(_r)
		s = signf(c) if absf(c) > 0.5 else 1.0
	return s*maxf(absf(lat),float(KNOBS.side_min))

## Its station ahead of the plane (m): `lead`, more the farther out, and its
## place in the herd along the line (compressed).
func _lead_of(side: float, along: float, at: Vector3) -> float:
	var mid := (center-at).dot(_f)
	return float(KNOBS.lead)+float(KNOBS.lead_side)*absf(side)+float(KNOBS.formation)*(along-mid)

## How far ahead of its station it must be when it bolts, at the plane's
## speed `v`: speeding up from a stand it is caught just as it matches the
## plane (v^2 / 2a), and the bolt's half second and the reaction.
func _trigger(v: float) -> float:
	return v*v/(2.0*float(KNOBS.curve_accel))+v*(0.45+float(KNOBS.flee_react))

## A calm animal and a low fast plane: inside its reach beside the line, a
## quick reaction, then the bolt. True while it is reacting (or off).
func _flee_step(a: Dictionary, at: Vector3, delta: float) -> bool:
	if not _threat:
		a.flee = -1.0
		return false
	var o := _off(a,at)
	if absf(o.y) > float(KNOBS.side_max) or o.x < -float(KNOBS.behind):
		a.flee = -1.0
		return false
	var side := _side_of(o.y,at)
	var v := minf(_v,_top())
	if float(a.flee) < 0.0:
		if o.x-_lead_of(side,o.x,at) > _trigger(v): return false
		a.flee = _rng.randf_range(0.0,float(KNOBS.flee_react))
	a.flee = float(a.flee)-delta
	if float(a.flee) <= 0.0: _bolt(a,side,_lead_of(side,o.x,at))
	return true

## Off: the bolt_start clip (crouch, launch), turning to run with the plane.
func _bolt(a: Dictionary, side: float, lead: float) -> void:
	# Straight from grazing: the gaze starts on the plane.
	if a.state == "graze" or a.look <= 0.0: a.gaze = Vector2.INF
	a.state = "bolt"
	a.t = 0.0
	a.flee = -1.0
	a.wait = -1.0
	a.side = side
	a.lead = lead
	a.speed = 0.0
	a.stretch = _rng.randf_range(float(KNOBS.stretch_min),float(KNOBS.stretch_max))
	a.bad = false
	a.dodge = 0.0
	a.dodge_t = 0.0
	var body: Node = a.body
	body.call("play","bolt_start",1.0,0.1)
	body.call("set_effect","dust",true)
	a.clip = "bolt_start"
	stats.bolts += 1

## The bolt: the clip's own launch (its root covers 1.2 BL on its ground
## curve: still through the crouch, then gathering speed to the gallop's at
## rate 0.7), turning to the plane's way.
func _bolt_step(a: Dictionary, at: Vector3, delta: float) -> void:
	var length := float((a.body as Node).call("clip_length","bolt_start"))
	a.speed = _clip_speed("bolt_start",minf(float(a.t),length),delta)
	a.look = minf(float(a.look)+float(KNOBS.look_in)*delta,float(KNOBS.run_look))
	_turn(a,_run_way(a,at),float(KNOBS.turn_bolt),delta)
	_step(a,delta)
	if float(a.t) >= length:
		# Handed over at the clip's last speed (the gallop's at rate 0.7).
		var c: Array = GROUND_CURVE.bolt_start
		a.speed = float(GROUND_BL.bolt_start)*bl*(float(c[-1][1])-float(c[-2][1]))/(float(c[-1][0])-float(c[-2][0]))
		a.state = "run"
		a.t = 0.0

## Beside the plane: matched to its speed (up to the top run) so it holds
## its station, steered to its side, until the stretch is up or the plane
## or the land ends it.
func _run_step(a: Dictionary, at: Vector3, delta: float) -> void:
	var o := _off(a,at)
	var g := o.x-float(a.lead)
	var v_p := _v
	var top := _top()
	# The gap curve: as fast as it should go now to meet its station just as
	# it matches the plane; straight-line near the station.
	var ease := minf(sqrt(2.0*float(KNOBS.curve_accel)*absf(g)),float(KNOBS.station)*absf(g))
	var want := clampf(v_p-signf(g)*ease,float(KNOBS.run_min),top)
	a.speed = move_toward(float(a.speed),want,(float(KNOBS.accel) if want > float(a.speed) else float(KNOBS.brake))*delta)
	stats.top_speed = maxf(float(stats.top_speed),float(a.speed))
	if absf(g) < 12.0 and float(a.speed) > 0.8*v_p: stats.beside_s = float(stats.beside_s)+delta
	a.look = move_toward(float(a.look),float(KNOBS.run_look),float(KNOBS.look_in)*delta)
	_turn(a,_run_way(a,at),float(KNOBS.turn_run),delta)
	_step(a,delta)
	_gait(a)
	a.stretch = float(a.stretch)-delta
	var why := ""
	if float(a.stretch) <= 0.0: why = "stretch"
	elif g < -float(KNOBS.drop): why = "dropped"
	elif _low > float(KNOBS.low)*float(KNOBS.gone_low): why = "climbed"
	elif _v < float(KNOBS.fast)*float(KNOBS.gone_slow)*_cruise: why = "slowed"
	elif absf(o.y) > float(KNOBS.side_max)*float(KNOBS.gone_side): why = "drawn off"
	elif bool(a.bad): why = str(a.why)
	elif Vector2(a.pos.x-site_home().x,a.pos.z-site_home().z).length() > float(KNOBS.leash): why = "leash"
	if why != "": _peel(a,why)

## The way it wants to run: the plane's way, steered toward its side
## station (and round a tree it is stepping round).
func _run_way(a: Dictionary, at: Vector3) -> Vector3:
	var o := _off(a,at)
	var side := float(a.side)+float(a.dodge)
	var across := clampf(float(KNOBS.side_steer)*(side-o.y),-float(KNOBS.side_most),float(KNOBS.side_most))
	return (_f*maxf(float(a.speed),4.0)+_r*across).normalized()

## Peeled off: turned out from the plane's line, braking to the halt; the
## first way whose land holds to a stop: out, half out, on, half in, in.
func _peel(a: Dictionary, why: String) -> void:
	a.state = "peel"
	a.t = 0.0
	a.why = why
	a.bad = false
	a.hard = false
	a.dodge = 0.0
	_peel_way(a)
	stats.peels += 1
	var tally: Dictionary = stats.peel_why
	tally[why] = int(tally.get(why,0))+1

## The peel's heading: out from the plane's line (a turn to the right when
## it runs on the plane's right: yaw down), else the next way round whose
## land holds for its stopping distance; none: out, braking hard.
func _peel_way(a: Dictionary) -> void:
	var turn := deg_to_rad(float(KNOBS.peel_turn))*signf(float(a.side)+0.001)
	var h := float(a.heading)
	var stop := _peel_stop(a)
	for k: float in [1.0,0.5,0.0,-0.5,-1.0]:
		if _arc_ok(a,h-turn*k,stop):
			a.peel = h-turn*k
			return
	a.peel = h-turn
	a.hard = true

## The land holds along the arc it would run turning to `yaw` (at the
## peel's turn rate, at its speed) for `dist` m: the ground at three points,
## no trees every `tree_step` m, a metre either side in turn.
func _arc_ok(a: Dictionary, yaw: float, dist: float) -> bool:
	var trees: Node = _study.get("trees") if _study != null else null
	var step := float(KNOBS.tree_step)
	var turn := float(KNOBS.turn_peel)*step/maxf(float(a.speed),4.0)
	var h := float(a.heading)
	var p: Vector3 = a.pos
	var n := maxi(int(dist/step),3)
	for k in range(1,n+1):
		h += clampf(wrapf(yaw-h,-PI,PI),-turn,turn)
		var way := _dir(h)
		p += way*step
		if trees != null and float(trees.call("top_at",p+Vector3(-way.z,0.0,way.x)*(float(k%3)-1.0))) > -INF: return false
		if k == n or k == n/3 or k == 2*n/3:
			if _ground_why(a.pos,p) != "": return false
	return true

## How far it runs braking to the halt (m), at least `probe_min`.
func _peel_stop(a: Dictionary) -> float:
	var v := float(a.speed)
	var halt := _halt_speed()
	return maxf((v*v-halt*halt)/(2.0*float(KNOBS.peel_brake)),float(KNOBS.probe_min))

## The peel: braking to the stop_look's slide speed, turning out, then the
## halt. Land ahead that won't do: a new way round (or braking hard).
func _peel_step(a: Dictionary, delta: float) -> void:
	var halt := _halt_speed()
	var brake := float(KNOBS.peel_brake)*(2.5 if bool(a.hard) else 1.0)
	a.speed = move_toward(float(a.speed),halt,brake*delta)
	a.look = move_toward(float(a.look),0.0,float(KNOBS.look_out)*delta)
	if bool(a.bad):
		a.bad = false
		_peel_way(a)
	_turn(a,_dir(float(a.peel)),float(KNOBS.turn_peel),delta)
	_step(a,delta)
	_gait(a)
	if float(a.speed) <= halt+0.05:
		a.state = "halt"
		a.t = 0.0
		(a.body as Node).call("play","stop_look",1.0,0.2)
		a.clip = "stop_look"

## The speed the stop_look's slide starts at (its curve's first step):
## the peel brakes to it.
func _halt_speed() -> float:
	var c: Array = GROUND_CURVE.stop_look
	return float(GROUND_BL.stop_look)*bl*float(c[1][1])/float(c[1][0])

## The halt: the slide to a stand on the clip's ground curve, the look back
## over the shoulder held, then head up at the plane (alert) to calm and
## graze again.
func _halt_step(a: Dictionary, delta: float) -> void:
	a.speed = _clip_speed("stop_look",float(a.t),delta)
	a.look = 0.0
	_step(a,delta)
	if float(a.t) >= float((a.body as Node).call("clip_length","stop_look")):
		a.state = "alert"
		a.t = 0.25
		a.speed = 0.0
		a.calm = 0.0
		a.gaze = Vector2.INF
		(a.body as Node).call("set_effect","dust",false)
		stats.halts += 1

## The speed (m/s) that moves the root by clip `name`'s ground curve over
## the frame ending at `t`.
func _clip_speed(name: String, t: float, delta: float) -> float:
	var ground := float(GROUND_BL[name])*bl
	return ground*(_curve(name,t)-_curve(name,maxf(t-delta,0.0)))/maxf(delta,1e-5)

## The fraction of clip `name`'s ground covered by time `t`.
static func _curve(name: String, t: float) -> float:
	var c: Array = GROUND_CURVE[name]
	if t <= float(c[0][0]): return float(c[0][1])
	for k in range(1,c.size()):
		if t <= float(c[k][0]):
			var p: Array = c[k-1]
			var q: Array = c[k]
			return lerpf(float(p[1]),float(q[1]),(t-float(p[0]))/maxf(float(q[0])-float(p[0]),1e-5))
	return float(c[-1][1])

## The gait for its speed (sprint, gallop, trot; each held `gait_hyst` past
## its switch), played at the rate that keeps its feet to the ground.
func _gait(a: Dictionary) -> void:
	var v := float(a.speed)
	var h := float(KNOBS.gait_hyst)
	var hi := float(KNOBS.sprint_at)
	var lo := float(KNOBS.gallop_at)
	var clip := str(a.clip)
	match clip:
		"sprint": if v < hi-h: clip = "gallop" if v >= lo else "trot"
		"gallop":
			if v >= hi+h: clip = "sprint"
			elif v < lo-h: clip = "trot"
		"trot": if v >= lo+h: clip = "sprint" if v >= hi else "gallop"
		_: clip = "sprint" if v >= hi else ("gallop" if v >= lo else "trot")
	var body: Node = a.body
	var rate := v/(float(GROUND_BL[clip])*bl/float(body.call("clip_length",clip)))
	body.call("play",clip,clampf(rate,0.4,2.0),0.2)
	a.clip = clip

## The heading's way on the ground.
func _dir(yaw: float) -> Vector3:
	return Vector3(-sin(yaw),0.0,-cos(yaw))

## Turned toward `way` at `rate` rad/s.
func _turn(a: Dictionary, way: Vector3, rate: float, delta: float) -> void:
	var want := atan2(-way.x,-way.z)
	var h := float(a.heading)
	a.heading = h+clampf(wrapf(want-h,-PI,PI),-rate*delta,rate*delta)

## Along its heading at its speed, on the land.
func _step(a: Dictionary, delta: float) -> void:
	var p: Vector3 = a.pos+_dir(float(a.heading))*float(a.speed)*delta
	if field != null: p.y = float(field.height(p.x,p.z))
	a.pos = p
	if float(a.dodge_t) > 0.0:
		a.dodge_t = float(a.dodge_t)-delta
		if float(a.dodge_t) <= 0.0: a.dodge = 0.0

func _place(a: Dictionary) -> void:
	(a.body as Node3D).transform = Transform3D(Basis(Vector3.UP,float(a.heading)),a.pos)

## The land ahead of one runner a frame (in turn): no water or steep ground
## `probe` s ahead, no trees on the way there. A tree with a clear side:
## stepped round until past it.
func _probe() -> void:
	var n := herd.size()
	for k in range(n):
		var a: Dictionary = herd[(_probe_next+k)%n]
		if not (a.state in ["run","peel"]): continue
		_probe_next = (_probe_next+k+1)%n
		stats.probes += 1
		var way := _dir(float(a.heading))
		var dist := maxf(float(a.speed)*float(KNOBS.probe),float(KNOBS.probe_min))
		if a.state == "peel": dist = minf(_peel_stop(a),dist)
		if a.state == "peel":
			a.bad = not _arc_ok(a,float(a.peel),dist)
			return
		var why := _land_why(a.pos,way,dist)
		if why == "":
			a.bad = why != ""
			a.why = why if why != "" else str(a.why)
			return
		if why == "trees" and float(a.dodge_t) <= 0.0:
			var across := Vector3(-way.z,0.0,way.x)
			for s: float in [signf(float(a.side)),-signf(float(a.side))]:
				var step: Vector3 = a.pos+across*s*float(KNOBS.dodge)
				if _land_why(step,way,dist) == "" and not _trees_on(a.pos,(step+way*dist*0.3-a.pos).normalized(),dist*0.3):
					# The step is across the plane's right (_r), not its own.
					a.dodge = s*float(KNOBS.dodge)*signf(across.dot(_r)+0.001)
					a.dodge_t = dist/maxf(float(a.speed),1.0)+0.4
					stats.dodges += 1
					return
		a.bad = true
		a.why = why
		return

## Why the way `dist` m along `way` from `from` won't do ("" when it will):
## water, a climb or a steep face where it ends, trees along it.
func _land_why(from: Vector3, way: Vector3, dist: float) -> String:
	var why := _ground_why(from,from+way*dist)
	if why != "": return why
	return "trees" if _trees_on(from,way,dist) else ""

## Why the ground at `p` won't do, come to from `from`: water, a climb or a
## steep face ("" when it will).
func _ground_why(from: Vector3, p: Vector3) -> String:
	if field == null: return ""
	var h := float(field.height(p.x,p.z))
	if h < SEA_Y+0.5 or not is_nan(float(field.river_y(p.x,p.z))): return "water"
	var run := maxf(Vector2(p.x-from.x,p.z-from.z).length(),1.0)
	if absf(h-from.y)/run > float(KNOBS.climb): return "climb"
	var hx := float(field.height(p.x+3.0,p.z))
	var hz := float(field.height(p.x,p.z+3.0))
	if maxf(absf(hx-h),absf(hz-h))/3.0 > float(KNOBS.steep): return "steep"
	return ""

## A tree on the way `dist` m along `way` from `from`: the trees' solid
## (top_at) every `tree_step` m, a metre either side in turn (the body's
## width).
func _trees_on(from: Vector3, way: Vector3, dist: float) -> bool:
	var trees: Node = _study.get("trees") if _study != null else null
	if trees == null: return false
	var across := Vector3(-way.z,0.0,way.x)
	var step := float(KNOBS.tree_step)
	var n := int(dist/step)
	for k in range(1,n+1):
		var p := from+way*(step*float(k))+across*(float(k%3)-1.0)
		if float(trees.call("top_at",p)) > -INF: return true
	return false

## Kept apart by the body length: each pair closer than `apart_bl` BL pushed
## apart (a standing one holds; a moving one gives way), a runner's side
## station shifted with it.
func _apart(delta: float) -> void:
	var apart := float(KNOBS.apart_bl)*bl
	var k := minf(12.0*delta,1.0)
	for i in range(herd.size()):
		var a: Dictionary = herd[i]
		var am: bool = a.state in ["bolt","run","peel","halt"]
		for j in range(i+1,herd.size()):
			var b: Dictionary = herd[j]
			var bm: bool = b.state in ["bolt","run","peel","halt"]
			if not am and not bm: continue
			var d := Vector3(b.pos.x-a.pos.x,0.0,b.pos.z-a.pos.z)
			var l := d.length()
			if l >= apart: continue
			var away := d/l if l > 1e-3 else _r
			var push := (apart-l)*k
			var share := 0.5 if am and bm else 1.0
			if am:
				a.pos = a.pos-away*push*share
				a.side = float(a.side)-away.dot(_r)*push*share
			if bm:
				b.pos = b.pos+away*push*share
				b.side = float(b.side)+away.dot(_r)*push*share

## The herd's middle and reach.
func _recenter() -> void:
	if herd.is_empty():
		center = site_home()
		return
	var c := Vector3.ZERO
	for a: Dictionary in herd: c += a.pos
	c /= float(herd.size())
	var r := 0.0
	for a: Dictionary in herd: r = maxf(r,Vector2(a.pos.x-c.x,a.pos.z-c.z).length())
	center = c
	radius = r

## The site's foot (world).
func site_home() -> Vector3:
	return (site.get("xform",Transform3D.IDENTITY) as Transform3D).origin

## Head up: the alert clip (its snap and hold), the look to come in after.
func _alert(a: Dictionary) -> void:
	a.state = "alert"
	a.t = 0.0
	a.wait = -1.0
	a.calm = 0.0
	a.gaze = Vector2.INF
	if a.clip != "alert":
		(a.body as Node).call("play","alert",1.0,0.12)
		a.clip = "alert"
	stats.alerts += 1

## The plane gone past `lose` x its reach: a calm countdown, then settle.
## Back within reach: the countdown starts again.
func _calm_step(a: Dictionary, d: float, reach: float, delta: float) -> void:
	if d < reach*float(KNOBS.lose):
		a.calm = 0.0
		return
	if float(a.calm) <= 0.0: a.calm = _rng.randf_range(float(KNOBS.calm_min),float(KNOBS.calm_max))
	a.calm = float(a.calm)-delta
	if float(a.calm) <= 0.0:
		a.calm = 0.0
		a.state = "settle"
		a.t = 0.0
		stats.settles += 1

## Back to grazing: the head down into the graze over settle_blend.
func _graze(a: Dictionary) -> void:
	a.state = "graze"
	a.t = 0.0
	a.look = 0.0
	(a.body as Node).call("look_at_world",Vector3.ZERO,0.0)
	(a.body as Node).call("play","graze",float(a.rate),float(KNOBS.settle_blend))
	a.clip = "graze"

## The head's look toward `target`: the gaze (yaw off the body's heading,
## pitch) turned toward it at the look's rates, held at the neck's reach
## over the shoulder it is on when the target goes behind (so a plane passing
## overhead swings the head round, never snaps it across), then handed to
## the body as a point along the gaze.
func _track(a: Dictionary, target: Vector3, delta: float) -> void:
	var body: Node3D = a.body
	var eye: Vector3 = (body.call("socket","head") as Node3D).global_position
	var d := target-eye
	var heading := float(a.heading)
	var want_yaw := wrapf(atan2(-d.x,-d.z)-heading,-PI,PI)
	var want_pitch := clampf(atan2(d.y,maxf(Vector2(d.x,d.z).length(),0.01)),-0.3,deg_to_rad(float(KNOBS.look_up)))
	var gaze: Vector2 = a.gaze
	var reach := deg_to_rad(float(KNOBS.look_reach))
	if gaze == Vector2.INF:
		# Fresh from the alert: the gaze on the plane at once, the weight's
		# ramp turns the head to it.
		gaze = Vector2(clampf(want_yaw,-reach,reach),want_pitch)
	if absf(want_yaw) > reach: want_yaw = reach*(signf(gaze.x) if gaze.x != 0.0 else signf(want_yaw))
	gaze.x = move_toward(gaze.x,want_yaw,float(KNOBS.look_turn)*delta)
	gaze.y = move_toward(gaze.y,want_pitch,float(KNOBS.look_pitch)*delta)
	a.gaze = gaze
	var yaw := heading+gaze.x
	var dir := Vector3(-sin(yaw)*cos(gaze.y),sin(gaze.y),-cos(yaw)*cos(gaze.y))
	body.call("look_at_world",eye+dir*60.0,smoothstep(0.0,1.0,float(a.look)))

## Stops (or starts) every body's clip: a sleeping herd costs one distance
## a frame.
func _sleep(on: bool) -> void:
	asleep = on
	for a: Dictionary in herd:
		(a.body as Node).process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
