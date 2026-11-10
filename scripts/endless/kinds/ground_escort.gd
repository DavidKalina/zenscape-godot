extends Node3D
## Kind `ground_escort`: a herd that grazes on open ground and answers the
## plane (docs/design/endless-flight/spec-wild-kit-elk.md). The kind has no
## skin of its own: the site's skin picks the body (`elk`: the elk). Not an
## enemy: no attacks, no damage, nothing to take.
##
## The herd is this node, placed at the site's foot by the placed sites
## (scripts/endless/placed_sites.gd), -Z its heading (down the meadow); the
## animals are its children, each a body behind the contract's API
## (scripts/endless/world/wilderness/elk_body.gd, the elk; its stand-in
## scripts/endless/kinds/escort_standin.gd), standing in the
## world's frame (top_level) on the land under them.
##
## The plane flown over high or slow: the near ones lift their heads and
## track it, then graze again. Skimmed low and fast past them: they bolt and
## run alongside it (sprinting at its speed, up to its cruise), each held at
## a station beside and a little ahead of the plane, on the land and off
## water, steep ground and trees, apart; after a stretch, or when the plane
## pulls away or the land won't do, they peel off, slow, halt and look back.
## Flown low and fast straight at them (the plane's line through the herd):
## they bolt, scatter out from its line, each to its own side, and once it
## has passed break back for the trees, into the wood's edge, halt and look
## back. Once all are calm and the plane is beyond the herd's reach, they
## drift home at a trot, each to its own spot, and graze there; a herd put
## to sleep away from home is set back on its spots (no one sees it).
##
## --elk=off: the site's marker instead.

const Marker = preload("res://scripts/endless/kinds/marker.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const SELF := "res://scripts/endless/kinds/ground_escort.gd"
## The bodies by skin. --elk-body=standin: the stand-in for every skin.
const BODIES := {"elk": "res://scripts/endless/world/wilderness/elk_body.gd"}
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
	# The placed pieces' solids (the stone ring's uprights, the wreck's ribs:
	# scripts/endless/placed_sites.gd `inside`) kept `piece_pad` m off, asked
	# at `piece_lo` and `piece_hi` m over the land (legs and back: a lintel
	# over a gap is no stone in the way). Asked where a way ends and every
	# `tree_step` m along it; a step that would still go in is not taken.
	"piece_pad": 1.0, "piece_lo": 0.5, "piece_hi": 1.8,
	# The trees' solid asked every this many m along a way.
	"tree_step": 3.0,
	# Gaits by speed (m/s), switched `gait_hyst` past each.
	"sprint_at": 25.0, "gallop_at": 10.5, "gait_hyst": 1.0,
	# The look while running: a glance at the plane, at this weight.
	"run_look": 0.35,
	# The leap, a flourish in the run beside (nothing to clear): now and then
	# one runner holding its station (within `leap_station` m of it, at the
	# plane's speed, sprinting, `leap_left` s of its stretch left, at most
	# `leap_max` leaps a run) bounds high, from the sprint's hang and back into
	# it. The first `leap_first_min`-`leap_first_max` s after the first bolt,
	# then every `leap_every_min`-`leap_every_max` s; the land ahead must hold
	# for the leap and `leap_clear` m past it (its ground asked every
	# `leap_ground_step` m), else asked again in `leap_retry` s.
	"leap_first_min": 1.0, "leap_first_max": 2.0, "leap_every_min": 1.0, "leap_every_max": 2.2,
	"leap_station": 8.0, "leap_left": 1.5, "leap_max": 1, "leap_clear": 6.0, "leap_retry": 0.4,
	"leap_ground_step": 8.0,
	# Straight at them: the plane's line within `straight` m of the herd's
	# middle when the first one goes. Each bolts `scatter_at` s before the
	# plane reaches it, then scatters out from the line on its own side,
	# `scatter_wide` degrees off the plane's way when on the line to
	# `scatter_narrow` at `side_max` out (give or take `scatter_jitter`), at
	# up to `scatter_speed`, for `scatter_min` s at least and until the plane
	# has passed it (at most `scatter_max`); then it breaks for the trees.
	# Once `scatter_out` m out it bends along the plane's way, `scatter_bend`
	# degrees out from it.
	"straight": 15.0, "scatter_at": 1.9, "scatter_wide": 80.0, "scatter_narrow": 45.0,
	"scatter_jitter": 12.0, "scatter_speed": 22.0, "scatter_min": 1.0, "scatter_max": 4.0,
	"scatter_out": 20.0, "scatter_bend": 15.0,
	# The trees: the wood's edge looked for from the herd's middle in
	# `cover_ways` ways out to `cover_reach` m; each runs its own way to it
	# (the nearest of `cover_tries` ways whose land holds), to the first
	# crown's solid (or `cover_back` m short of it), under no bough (clear of
	# each tree's seen crown by `body_half` BL, and `trunk_clear` m at
	# least), at up to `cover_speed`, turning at `turn_cover` (rad/s). No
	# wood in reach: a peel in the open.
	"cover_ways": 24, "cover_reach": 160.0, "cover_tries": 24, "cover_back": 1.5, "trunk_clear": 1.5,
	# One cover search a frame across the herd: a slice of a sweep
	# (`cover_slice` ways) or one animal's goal; the rest wait a frame.
	"cover_slice": 6,
	"body_half": 0.2,
	"cover_speed": 20.0, "turn_cover": 3.0, "stuck": 2.0,
	# Home: all calm, the plane beyond the herd's reach for `home_wait_min`
	# to `home_wait_max` s, each farther than `home_off` m from its spot sets
	# off within `home_stagger` s: it turns round stepping (the trot at
	# `home_pivot` rate, turning at `turn_pivot` rad/s, until within
	# `home_face` degrees), then trots home at `home_rate` x the trot's pace,
	# turning at `turn_home`, slowing in, and grazes on its spot. The land
	# `home_probe` m ahead (water, a climb, a steep face, trees) that won't
	# do: a detour held `home_detour` s. No nearer home in `home_give_up` s:
	# it grazes where it stands. The plane must be `home_far` m off the
	# herd's middle (and beyond its reach) all the while.
	"home_far": 300.0,
	"home_off": 4.0, "home_wait_min": 2.0, "home_wait_max": 5.0, "home_stagger": 1.5,
	"home_pivot": 0.45, "turn_pivot": 1.6, "home_face": 45.0,
	"home_rate": 0.75, "turn_home": 2.0, "home_accel": 2.5,
	"home_probe": 6.0, "home_detour": 1.5, "home_give_up": 6.0,
}

## The states in which an animal moves (placed, kept apart, its land probed).
const MOVING := ["bolt","run","leap","peel","halt","scatter","cover","home"]

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
	"leap": [[0.0,0.0],[0.9,1.0]],
}
## The contract's `sprint.air` beat (s): the sprint's hang begins. The leap
## starts and ends at the sprint's time 0 (the hang's end), so it is played
## the rest of that cycle after this beat.
const SPRINT_AIR := 0.25
const SEA_Y := -40.0
const TreePlan = preload("res://scripts/endless/tree_plan.gd")

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
## left beside), peel (the peel's or the scatter's heading), goal (its spot
## in the wood), best and since (its nearest to it yet, and how long ago)}. States: `graze`; `alert` (head
## up, tracking the plane); `settle` (the look easing out, then grazing);
## `bolt` (the bolt_start clip, turning to run; `mode` beside or scatter);
## `run` (beside the plane; `leap` "wait" for the sprint's hang, then "hang"
## and `leap_in` s to its end); `leap` (the leap, a flourish mid-run, at
## `leap_rate`); `peel` (turned out, slowing); `scatter` (out
## from the plane's line, `peel` its way); `cover` (to `goal` in the wood's
## edge); `halt` (stop_look, then `alert`).
var herd: Array = []
var asleep := false
## The sense range of the herd's widest-nerved animal, beyond which (from
## the herd's middle, plus its reach) no animal is asked (one distance a
## frame).
var _reach := 0.0
var _rng := RandomNumberGenerator.new()
var _study: Node = null
## The study's placed sites (scripts/endless/placed_sites.gd), found once;
## null with none (--no-placed).
var _placed: Node = null
var _placed_looked := false
var stats := {"count":0,"bulls":0,"awake_frames":0,"sensing_frames":0,"alerts":0,"settles":0,
	"bolts":0,"peels":0,"halts":0,"beside_s":0.0,"top_speed":0.0,"probes":0,"dodges":0,"peel_why":{},
	"scatters":0,"covers":0,"cover_sweeps":0,"cover_top_at":0,"cover_ground":0,"cover_fail":{},
	"leaps":0,"leap_land_no":0,"leap_missed":0,"tucked":0,
	"cover_retries":0,"homes":0,"home_arrived":0,"home_gave_up":0,"home_detours":0,"home_snaps":0,
	"piece_blocks":0,"piece_block_in":{}}
## The herd's answer to this pass, set when the first one goes: "beside" or
## "straight" (the plane's line through the herd); "" once all are calm.
var _verdict := ""
## The wood's edge round the herd for this pass (swept once, when the first
## one breaks for the trees): [way, metres to the first crown] per way.
var _cover: Array = []
## Where that sweep was made from.
var _cover_from := Vector3.ZERO
## A sweep under way, a slice a frame: {from, k (the next way), edges, owner
## (the body of the animal sweeping for itself; null: the herd's)}; {} none.
var _sweep := {}
## No cover search yet this frame.
var _cover_free := true
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
## The plane's position this frame (INF: none).
var _at := Vector3.INF
## The next runner whose land ahead is probed (one a frame).
var _probe_next := 0
## Seconds until the herd's next leap is asked for (the run beside).
var _leap_wait := 0.0
## Some of the herd may be off their spots (set at a bolt); the countdown to
## the drift home (-1: not started).
var _home_check := false
## Why the last cover goal search passed each over (for drivers).
var _last_fail := {}
var _home_wait := -1.0
## This frame's work, counted (no clock; for drivers and the lane handoff):
## land heights, river asks, tree solids (top_at), tree plan cells read,
## pair distances, bodies placed, per-frame calls on a body (play, look).
## Zeroed at the top of each frame.
var w_height := 0
var w_river := 0
var w_top_at := 0
var w_cells := 0
var w_pairs := 0
var w_placed := 0
var w_pieces := 0
var w_calls := 0

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
	var body_path: String = BODIES.get(skin,STANDIN)
	if LaunchArgs.user_args().has("--elk-body=standin"): body_path = STANDIN
	var body_script: GDScript = load(body_path)
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
		if field != null: world.y = _height(world.x,world.z)
		var yaw := herd_yaw+deg_to_rad(rng.randf_range(-float(KNOBS.face_spread),float(KNOBS.face_spread)))
		var body: Node3D = body_script.new()
		body.name = "Elk%d" % i
		body.top_level = true
		var variant := "bull" if i < bulls else "cow"
		body.call("set_variant",variant)
		# A body that stands its feet on the land asks it (the real elk).
		if field != null and body.has_method("set_ground"): body.call("set_ground",field)
		body.transform = Transform3D(Basis(Vector3.UP,yaw),world)
		add_child(body)
		var rate := rng.randf_range(float(KNOBS.graze_rate_min),float(KNOBS.graze_rate_max))
		body.call("play","graze",rate,0.0)
		var nerve := rng.randf_range(float(KNOBS.nerve_min),float(KNOBS.nerve_max))
		var a := {"body":body,"pos":world,"heading":yaw,"variant":variant,"rate":rate,"state":"graze",
			"nerve":nerve,"wait":-1.0,"calm":0.0,"look":0.0,"gaze":Vector2.ZERO,"clip":"graze","t":0.0,
			"flee":-1.0,"speed":0.0,"side":0.0,"lead":0.0,"stretch":0.0,"peel":0.0,
			"bad":false,"hard":false,"dodge":0.0,"dodge_t":0.0,"why":"","mode":"","out":1.0,"goal":Vector3.ZERO,"best":INF,"since":0.0,
			"clip_rate":1.0,"gap":0.0,"leap":"","leap_in":0.0,"leap_rate":1.0,"leaps":0,
			"retried":false,"home":world,"home_yaw":yaw,"detour":NAN,"detour_t":0.0,"gave_up":false}
		herd.append(a)
		body.connect("beat_reached",_on_beat.bind(a))
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
	w_height = 0; w_river = 0; w_top_at = 0; w_cells = 0; w_pairs = 0; w_placed = 0; w_pieces = 0; w_calls = 0
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
	if not busy:
		_verdict = ""
		_cover = []
		_sweep = {}
		if _home_check:
			if at == Vector3.INF or Vector2(at.x-center.x,at.z-center.z).length() > float(KNOBS.home_far): _home_due(delta)
			else: _home_wait = -1.0
		return
	_home_wait = -1.0
	stats.sensing_frames += 1
	_cover_free = true
	if not _sweep.is_empty() and _sweep.owner != null:
		# One sweeping for itself that has stopped looking (alerted, halted):
		# its sweep dropped.
		var still := false
		for a: Dictionary in herd: if a.body == _sweep.owner and a.state in ["scatter","peel"]: still = true
		if not still: _sweep = {}
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
				# Tucked in the wood (no way out holds), it watches too.
				if not _flee_step(a,at,delta): _calm_step(a,d,reach,delta)
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
			"leap":
				_leap_step(a,at,delta)
			"peel":
				_peel_step(a,delta)
			"scatter":
				_scatter_step(a,at,delta)
			"cover":
				_cover_step(a,delta)
			"halt":
				_halt_step(a,delta)
			"home":
				if d < reach: _alert(a)
				else: _home_step(a,delta)
		if a.state in MOVING: moving = true
		if a.state != "graze" and at != Vector3.INF: _track(a,at+vel*float(KNOBS.look_lead),delta)
	if moving:
		_probe()
		_leap_pick(delta)
		_apart(delta)
		for a: Dictionary in herd:
			if a.state in MOVING: _place(a)
		_recenter()
	elif _verdict != "" and not _threat:
		# All calm again: the next pass is answered afresh.
		var waiting := false
		for a: Dictionary in herd: if float(a.flee) >= 0.0: waiting = true
		if not waiting:
			_verdict = ""
			_cover = []
			_sweep = {}

## The plane's way over the ground, speed, height over the ground under it
## and cruise, once a frame: `_threat` when low and fast.
func _read_plane(plane: RefCounted, at: Vector3, vel: Vector3) -> void:
	_threat = false
	_at = at
	if plane == null or at == Vector3.INF: return
	if plane.has_method("cruise"): _cruise = float(plane.call("cruise"))
	var flat := Vector2(vel.x,vel.z)
	_v = flat.length()
	if _v > 1.0:
		_f = Vector3(flat.x/_v,0.0,flat.y/_v)
		_r = Vector3(-_f.z,0.0,_f.x)
	_low = at.y-(_height(at.x,at.z) if field != null else 0.0)
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
	var straight := _verdict == "straight" or (_verdict == "" and absf((center-at).dot(_r)) < float(KNOBS.straight))
	if float(a.flee) < 0.0:
		if straight:
			if o.x > _v*float(KNOBS.scatter_at): return false
		elif o.x-_lead_of(side,o.x,at) > _trigger(v): return false
		a.flee = _rng.randf_range(0.0,float(KNOBS.flee_react))
		if _verdict == "":
			_verdict = "straight" if straight else "beside"
			if not straight: _leap_wait = _rng.randf_range(float(KNOBS.leap_first_min),float(KNOBS.leap_first_max))
	a.flee = float(a.flee)-delta
	if float(a.flee) <= 0.0:
		var yaw := _scatter_way(a,o) if straight else _run_out(a,o,side)
		if is_nan(yaw):
			# Tucked in the wood's edge, no way out that holds: head up, it
			# stays and watches until the plane has gone.
			if a.state != "alert": _alert(a)
			a.flee = INF
			stats.tucked += 1
			return true
		_bolt(a,side,_lead_of(side,o.x,at))
		if straight: _scatter_from(a,o,yaw)
	return true

## The bolt's ground and a probe's on: how far the land must hold for it to
## go (m).
func _bolt_reach() -> float:
	return float(GROUND_BL.bolt_start)*bl+float(KNOBS.probe_min)

## The way the run beside starts (yaw): the plane's way, toward its side
## station; NAN when the land won't hold for the bolt (no water, climb,
## steep face or trees on it).
func _run_out(a: Dictionary, o: Vector2, side: float) -> float:
	var across := clampf(float(KNOBS.side_steer)*(side-o.y),-float(KNOBS.side_most),float(KNOBS.side_most))
	var way := (_f*4.0+_r*across).normalized()
	if _land_why(a.pos,way,_bolt_reach()) != "": return NAN
	return atan2(-way.x,-way.z)

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
	a.mode = "beside"
	a.leap = ""
	a.leaps = 0
	a.gave_up = false
	a.retried = false
	_home_check = true
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
	var way := _dir(float(a.peel)) if a.mode == "scatter" else _run_way(a,at)
	_turn(a,way,float(KNOBS.turn_bolt),delta)
	_step(a,delta)
	if float(a.t) >= length:
		# Handed over at the clip's last speed (the gallop's at rate 0.7).
		var c: Array = GROUND_CURVE.bolt_start
		a.speed = float(GROUND_BL.bolt_start)*bl*(float(c[-1][1])-float(c[-2][1]))/(float(c[-1][0])-float(c[-2][0]))
		a.state = "scatter" if a.mode == "scatter" else "run"
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
	a.gap = g
	if why != "":
		_peel(a,why)
		return
	_leap_wait_step(a,delta)

## The way it wants to run: the plane's way, steered toward its side
## station (and round a tree it is stepping round).
func _run_way(a: Dictionary, at: Vector3) -> Vector3:
	var o := _off(a,at)
	var side := float(a.side)+float(a.dodge)
	var across := clampf(float(KNOBS.side_steer)*(side-o.y),-float(KNOBS.side_most),float(KNOBS.side_most))
	return (_f*maxf(float(a.speed),4.0)+_r*across).normalized()

# --- The leap, a flourish in the run beside ---------------------------------

## Now and then in the run beside, when the herd's wait is up: one runner
## holding its station (at random) is asked to leap, if the land ahead holds
## (the ground every `leap_ground_step` m, trees along it) for up to a sprint
## cycle and a half (the wait for the hang's end), the leap's ground and
## `leap_clear` m. It leaps at the end of the sprint's next hang. One land
## check a pick.
func _leap_pick(delta: float) -> void:
	if _verdict != "beside": return
	_leap_wait -= delta
	if _leap_wait > 0.0: return
	var ready: Array = []
	var v := minf(_v,_top())
	for a: Dictionary in herd:
		if a.state == "run" and a.clip == "sprint" and str(a.leap) == "" and int(a.leaps) < int(KNOBS.leap_max) \
				and absf(float(a.gap)) < float(KNOBS.leap_station) and float(a.speed) > 0.9*v \
				and float(a.stretch) > float(KNOBS.leap_left) and not bool(a.bad) and float(a.dodge_t) <= 0.0:
			ready.append(a)
	if ready.is_empty(): return
	var a: Dictionary = ready[_rng.randi()%ready.size()]
	var body: Node = a.body
	var cycle := float(body.call("clip_length","sprint"))/float(a.clip_rate)
	var reach := float(a.speed)*cycle*1.5+float(GROUND_BL.leap)*bl+float(KNOBS.leap_clear)
	var way := _dir(float(a.heading))
	var why := _land_why(a.pos,way,reach)
	var step := float(KNOBS.leap_ground_step)
	var d := step
	while why == "" and d < reach:
		why = _ground_why(a.pos,a.pos+way*d)
		d += step
	if why != "":
		stats.leap_land_no += 1
		_leap_wait = float(KNOBS.leap_retry)
		return
	a.leap = "wait"
	a.leap_in = 2.0*cycle
	_leap_wait = _rng.randf_range(float(KNOBS.leap_every_min),float(KNOBS.leap_every_max))

## The body's beats: on the sprint's hang (`sprint.air`), a runner asked to
## leap counts down the rest of the cycle, so the leap starts where the
## sprint's cycle ends (its time 0, the leap's first pose).
func _on_beat(name: String, a: Dictionary) -> void:
	if name == "sprint.air" and str(a.leap) == "wait":
		a.leap = "hang"
		var body: Node = a.body
		a.leap_in = (float(body.call("clip_length","sprint"))-SPRINT_AIR)/maxf(float(a.clip_rate),0.1)

## A runner asked to leap: waiting for the sprint's hang (given up after two
## cycles, or once off the sprint), then the rest of the cycle, then the leap.
func _leap_wait_step(a: Dictionary, delta: float) -> void:
	if str(a.leap) == "": return
	if a.clip != "sprint":
		a.leap = ""
		stats.leap_missed += 1
		return
	a.leap_in = float(a.leap_in)-delta
	if float(a.leap_in) > 0.0: return
	if a.leap == "hang": _leap(a)
	else:
		a.leap = ""
		stats.leap_missed += 1

## Off the ground: the leap, played at the rate that keeps the sprint's pace
## (its ground is 12.6 BL whatever the rate; the rate sets its time).
func _leap(a: Dictionary) -> void:
	var body: Node = a.body
	var length := float(body.call("clip_length","leap"))
	a.leap_rate = clampf(float(a.speed)/(float(GROUND_BL.leap)*bl/length),0.7,1.3)
	a.state = "leap"
	a.t = 0.0
	a.leap = ""
	a.leaps = int(a.leaps)+1
	body.call("play","leap",float(a.leap_rate),0.05)
	a.clip = "leap"
	stats.leaps += 1

## The leap: the root carried on by the clip's ground curve (straight on, at
## the sprint's pace), its heading held (no turning in the air), its stretch
## running down; at the clip's end, back into the sprint (its time 0, the
## leap's last pose). The run's ends wait until it lands.
func _leap_step(a: Dictionary, at: Vector3, delta: float) -> void:
	var body: Node = a.body
	var r := float(a.leap_rate)
	var length := float(body.call("clip_length","leap"))
	var ct := minf(float(a.t)*r,length)
	a.speed = _clip_speed("leap",ct,delta*r)*r
	a.stretch = float(a.stretch)-delta
	if at != Vector3.INF:
		a.gap = _off(a,at).x-float(a.lead)
		if absf(float(a.gap)) < 12.0 and float(a.speed) > 0.8*_v: stats.beside_s = float(stats.beside_s)+delta
	_step(a,delta)
	if float(a.t)*r >= length:
		a.state = "run"
		a.t = 0.0
		var pace := float(GROUND_BL.sprint)*bl/float(body.call("clip_length","sprint"))
		a.clip_rate = clampf(float(a.speed)/pace,0.4,2.0)
		body.call("play","sprint",float(a.clip_rate),0.05)
		a.clip = "sprint"

## Straight at them: the bolt turns out from the plane's line on its own side
## (one on the line takes a side at random), wide off the plane's way when on
## the line, narrower the farther out it stands; its way held in `peel`.
func _scatter_from(a: Dictionary, o: Vector2, yaw: float) -> void:
	a.mode = "scatter"
	a.side = float(a.out)*maxf(absf(o.y),1.0)
	a.peel = yaw
	stats.scatters += 1

## The scatter's way (yaw) and side (a.out): out from the line on its own
## side; when the land won't hold for the bolt that way, wider (back from
## the plane's way) in steps, or a little narrower. NAN: none holds.
func _scatter_way(a: Dictionary, o: Vector2) -> float:
	var s := signf(o.y) if absf(o.y) > 1.5 else (1.0 if _rng.randf() < 0.5 else -1.0)
	var off := lerpf(float(KNOBS.scatter_wide),float(KNOBS.scatter_narrow),clampf(absf(o.y)/float(KNOBS.side_max),0.0,1.0))
	off += _rng.randf_range(-1.0,1.0)*float(KNOBS.scatter_jitter)
	a.out = s
	for k: float in [0.0,25.0,50.0,75.0,100.0,-25.0]:
		var t := deg_to_rad(clampf(off+k,20.0,170.0))
		var way := _f*cos(t)+_r*s*sin(t)
		if _land_why(a.pos,way,_bolt_reach()) == "": return atan2(-way.x,-way.z)
	return NAN

## Scattering: out from the line at speed (once `scatter_out` m out, bent
## along the plane's way, still drawing off), until the plane has passed it
## (or gone, or the land ahead won't do), then for the trees.
func _scatter_step(a: Dictionary, at: Vector3, delta: float) -> void:
	a.speed = move_toward(float(a.speed),float(KNOBS.scatter_speed),float(KNOBS.accel)*delta)
	a.look = move_toward(float(a.look),float(KNOBS.run_look),float(KNOBS.look_in)*delta)
	var way := _dir(float(a.peel))
	if at != Vector3.INF and absf(_off(a,at).y) > float(KNOBS.scatter_out):
		var bend := deg_to_rad(float(KNOBS.scatter_bend))
		way = _f*cos(bend)+_r*signf(float(a.side))*sin(bend)
	_turn(a,way,float(KNOBS.turn_run),delta)
	_step(a,delta)
	_gait(a)
	var passed := at == Vector3.INF or not _threat or _off(a,at).x < -float(KNOBS.behind)
	if _cover_free and ((passed and float(a.t) >= float(KNOBS.scatter_min)) or float(a.t) >= float(KNOBS.scatter_max) or bool(a.bad)):
		_to_cover(a)

## For the trees: its goal in the wood's edge, or a peel in the open when no
## wood in reach will do. While the search is under way it scatters on.
func _to_cover(a: Dictionary) -> void:
	var goal: Variant = _cover_find(a)
	if goal == null: return
	a.bad = false
	if goal == Vector3.INF:
		_peel(a,"no cover")
		return
	_cover_go(a,goal)

## This frame's cover search for `a`: its goal, Vector3.INF for none, or null
## while a sweep is under way (a slice a frame). The herd's sweep (from its
## middle, once a pass) first; none from there (its rays stopped by a bank,
## or its edges taken): the wood's edge swept from where it stands.
func _cover_find(a: Dictionary) -> Variant:
	_cover_free = false
	if _cover.is_empty():
		if _sweep.is_empty(): _sweep_begin(center,null)
		if _sweep.owner != null: return null
		if not _sweep_step(): return null
		_cover = _sweep.edges
		_cover_from = _sweep.from
		_sweep = {}
	if _sweep.is_empty():
		var goal := _cover_goal(a,_cover,_cover_from)
		if goal != Vector3.INF: return goal
		_sweep_begin(a.pos,a.body)
		return null
	if _sweep.owner != a.body: return null
	if not _sweep_step(): return null
	var edges: Array = _sweep.edges
	var from: Vector3 = _sweep.from
	_sweep = {}
	return _cover_goal(a,edges,from)

func _sweep_begin(from: Vector3, owner: Variant) -> void:
	stats.cover_sweeps += 1
	_sweep = {"from":from,"k":0,"edges":[],"owner":owner}

## The next `cover_slice` ways of the sweep under way; true once it has all.
func _sweep_step() -> bool:
	var n := int(KNOBS.cover_ways)
	var k0 := int(_sweep.k)
	var stop := mini(k0+int(KNOBS.cover_slice),n)
	for k in range(k0,stop): (_sweep.edges as Array).append(_cover_way(_sweep.from,k))
	_sweep.k = stop
	return stop >= n

## Off for its goal in the wood.
func _cover_go(a: Dictionary, goal: Vector3) -> void:
	a.state = "cover"
	a.t = 0.0
	a.goal = goal
	a.best = INF
	a.since = 0.0
	stats.covers += 1

## The wood's edge round `from` (the herd's middle, or one animal), its way
## `k` of `cover_ways` (a sweep is `_sweep_step`'s slices of them): [the way,
## the metres to the first tree's solid], when the land on the way there and
## under it holds (INF: none in `cover_reach`, or water, a climb or a steep
## face first: a wood on a steep bank is no cover).
func _cover_way(from: Vector3, k: int) -> Array:
	var trees: Node = _study.get("trees") if _study != null else null
	var step := float(KNOBS.tree_step)
	var way := _dir(TAU*float(k)/float(int(KNOBS.cover_ways)))
	var edge := INF
	if trees != null:
		var d := step
		var last := from
		while d <= float(KNOBS.cover_reach):
			var p := from+way*d
			stats.cover_top_at += 1
			var hit := float(_top_at(trees,p)) > -INF
			if hit or int(d/step)%3 == 0:
				stats.cover_ground += 1
				if _ground_why(last,p) != "": break
				last = p
				if field != null: last.y = _height(p.x,p.z)
			if hit:
				edge = d
				break
			d += step
	return [way,edge]

## Its goal in the wood: the edge a sweep from `origin` found in each way
## (`edges`), shifted along
## the treeline by half its own place across that way (so the herd keeps
## spread), and the edge itself (a lone tree a shifted aim would miss),
## nearest the animal first (a turn back costing a little); run from where it
## stands toward it to its own first crown; the first whose land holds (no
## water, climb or steep face on the way, no trunk at the goal, none of the
## herd standing or bound within the apart distance). INF: none.
func _cover_goal(a: Dictionary, edges: Array, origin: Vector3) -> Vector3:
	_last_fail = {}
	var fwd := _dir(float(a.heading))
	var ranked: Array = []
	for c: Array in edges:
		if float(c[1]) == INF: continue
		var out: Vector3 = c[0]
		var across := Vector3(-out.z,0.0,out.x)
		# A step in past the crown's rim, so a way in from aslant meets it.
		var edge: Vector3 = origin+out*(float(c[1])+float(KNOBS.tree_step))
		for shift: float in [0.5,0.0]:
			var aim: Vector3 = edge+across*shift*(a.pos-origin).dot(across)
			var to := Vector3(aim.x-a.pos.x,0.0,aim.z-a.pos.z)
			var l := maxf(to.length(),0.01)
			ranked.append([l+(1.0-fwd.dot(to/l))*6.0+(0.0 if shift > 0.0 else 8.0),to/l,l])
	ranked.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var trees: Node = _study.get("trees") if _study != null else null
	if trees == null: return Vector3.INF
	var step := float(KNOBS.tree_step)
	var cells := {}
	var ahead := _threat and _at != Vector3.INF and _off(a,_at).x > -float(KNOBS.behind)
	for r in range(mini(ranked.size(),int(KNOBS.cover_tries))):
		var way: Vector3 = ranked[r][1]
		var reach := minf(float(ranked[r][2])+20.0,float(KNOBS.cover_reach))
		var from: Vector3 = a.pos
		var last: Vector3 = a.pos
		var d := step
		var goal := Vector3.INF
		while d <= reach:
			var p: Vector3 = from+way*d
			stats.cover_top_at += 1
			if float(_top_at(trees,p+Vector3(-way.z,0.0,way.x)*(float(int(d/step)%3)-1.0))) > -INF:
				# At the solid's rim, or a little short of it: under no bough.
				goal = p
				if _in_crown(goal): goal = p-way*float(KNOBS.cover_back)
				break
			if int(d/step)%3 == 0:
				stats.cover_ground += 1
				var bad := _ground_why(last,p)
				if bad != "":
					_tally("way "+bad)
					break
				last = p
				if field != null: last.y = _height(p.x,p.z)
			# Finer near the aim (a crown met on a short chord).
			d += step if d < float(ranked[r][2])-2.0*step else step*0.5
		if goal == Vector3.INF:
			if d > reach: _tally("missed")
			continue
		# Taken, or a trunk there: a step along the treeline either way.
		var room := float(KNOBS.apart_bl)*bl+1.0
		for k: float in [0.0,1.0,-1.0]:
			var g := goal+Vector3(-way.z,0.0,way.x)*room*k
			stats.cover_ground += 1
			if field != null: g.y = _height(g.x,g.z)
			var why := _ground_why(last,g)
			if why == "" and _in_crown(g): why = "in a crown"
			if why == "" and _taken(a,g): why = "taken"
			# Not across the plane's line before it has passed.
			if why == "" and ahead and signf((g-_at).dot(_r)) != signf(float(a.side)): why = "across the line"
			if why == "" and k != 0.0 and float(_top_at(trees,g)) == -INF and not _wood_by(g,trees): why = "off the wood"
			if why == "":
				why = _cover_run_why(a,g,cells)
				if why != "": why = "run "+why
			if why != "":
				_tally("goal "+why)
				continue
			return g
	return Vector3.INF

## Why a cover goal was passed over, counted (stats.cover_fail).
func _tally(why: String) -> void:
	var t: Dictionary = stats.cover_fail
	t[why] = int(t.get(why,0))+1
	_last_fail[why] = int(_last_fail.get(why,0))+1

## A tree's solid within a step of `p` (the wood's edge).
func _wood_by(p: Vector3, trees: Node) -> bool:
	var r := float(KNOBS.tree_step)
	for d: Vector3 in [Vector3(r,0,0),Vector3(-r,0,0),Vector3(0,0,r),Vector3(0,0,-r)]:
		if float(_top_at(trees,p+d)) > -INF: return true
	return false

## Another of the herd standing, or bound for a goal, within the apart
## distance (and a little) of `p`.
func _taken(a: Dictionary, p: Vector3) -> bool:
	var room := float(KNOBS.apart_bl)*bl+1.0
	for b: Dictionary in herd:
		if is_same(b,a): continue
		var q: Vector3 = b.goal if b.state == "cover" else b.pos
		if b.state in ["bolt","run","leap","scatter","peel"]: continue
		if Vector2(q.x-p.x,q.z-p.z).length() < room: return true
	return false

## Under a tree's boughs at `p` (XZ): within its seen crown (the plan's
## crown radius over the trees' CROWN_SOLID) and half the body's width of its
## trunk, or `trunk_clear` m; from the trees' plan cells.
func _in_crown(p: Vector3) -> bool:
	var trees: Node = _study.get("trees") if _study != null else null
	if trees == null or not trees.has_method("cell_trees"): return false
	var solid := float((trees.get_script() as GDScript).get_script_constant_map().get("CROWN_SOLID",0.85))
	var half := float(KNOBS.body_half)*bl
	var r := 8.0
	var seen := {}
	for d: Vector2 in [Vector2(-r,-r),Vector2(r,-r),Vector2(-r,r),Vector2(r,r)]:
		var ck: Vector2i = TreePlan.cell_of(p.x+d.x,p.z+d.y)
		if seen.has(ck): continue
		seen[ck] = true
		var t: PackedFloat32Array = _cell_trees(trees,ck)
		for q in range(0,t.size(),8):
			if t[q+3] <= 0.0: continue
			var clear := maxf(float(KNOBS.trunk_clear),t[q+6]/solid+half)
			if Vector2(p.x-t[q],p.z-t[q+1]).length() < clear: return true
	return false

## To the trees: at speed toward its goal, slowing so it comes in at the
## halt's slide speed and stops on it; then the halt (look back).
func _cover_step(a: Dictionary, delta: float) -> void:
	var to: Vector3 = a.goal-a.pos
	to.y = 0.0
	var dist := to.length()
	a.speed = _cover_speed(float(a.speed),dist,delta)
	a.look = move_toward(float(a.look),0.0,float(KNOBS.look_out)*delta)
	if dist > 0.5: _turn(a,to/dist,float(KNOBS.turn_cover),delta)
	_step(a,delta)
	_gait(a)
	var passed := dist < 4.0 and to.dot(_dir(float(a.heading))) < 0.0
	# Kept off its goal (the herd pressing in): no nearer in `stuck` s.
	if dist < float(a.best)-0.5:
		a.best = dist
		a.since = 0.0
	a.since = float(a.since)+delta
	if dist <= _cover_end() or passed or float(a.since) > float(KNOBS.stuck):
		_halt_now(a)

## The run for the trees' speed at `v`, `dist` m from its goal, after
## `delta`: at speed, braking so it comes in at the halt's slide speed.
func _cover_speed(v: float, dist: float, delta: float) -> float:
	var halt := _halt_speed()
	var slide := float(GROUND_BL.stop_look)*bl
	var cap := sqrt(halt*halt+2.0*float(KNOBS.peel_brake)*maxf(dist-slide,0.0))
	var want := minf(float(KNOBS.cover_speed),cap)
	var rate := float(KNOBS.accel) if want > v else float(KNOBS.peel_brake)*1.5
	return move_toward(v,want,rate*delta)

## How near its goal the run for the trees ends in the halt (m).
func _cover_end() -> float:
	return float(GROUND_BL.stop_look)*bl+0.3

## The halt from here: stop_look (the slide, the look back).
func _halt_now(a: Dictionary) -> void:
	a.state = "halt"
	a.t = 0.0
	(a.body as Node).call("play","stop_look",1.0,0.2)
	a.clip = "stop_look"

## Why the run for the trees from where `a` stands to `goal` won't do, as it
## will run it (its heading and speed now, turning at `turn_cover`, braking
## in, the halt's slide past the end), "" when it will: the ground every
## `tree_step` m run (water, a climb, a steep face) and no trunk within
## `trunk_clear` m every half step. A turn back from a gallop swings wide;
## the straight line from where it stands misses that.
func _cover_run_why(a: Dictionary, goal: Vector3, cells: Dictionary) -> String:
	var dt := 1.0/30.0
	var p: Vector3 = a.pos
	var h := float(a.heading)
	var v := float(a.speed)
	var last: Vector3 = a.pos
	var run := 0.0
	var best := INF
	var since := 0.0
	var step := float(KNOBS.tree_step)*0.5
	var odd := false
	for i in range(int(10.0/dt)):
		var to := Vector3(goal.x-p.x,0.0,goal.z-p.z)
		var dist := to.length()
		var end := dist <= _cover_end() or (dist < 4.0 and to.dot(_dir(h)) < 0.0) or since > float(KNOBS.stuck)
		if end:
			# The halt's slide on along its heading.
			p += _dir(h)*float(GROUND_BL.stop_look)*bl
			run = step
		else:
			v = _cover_speed(v,dist,dt)
			if dist > 0.5: h = _turned(h,to/dist,float(KNOBS.turn_cover),dt)
			p += _dir(h)*v*dt
			run += v*dt
			if dist < best-0.5:
				best = dist
				since = 0.0
			since += dt
		if run >= step:
			run = 0.0
			odd = not odd
			if _trunk_by(p,float(KNOBS.trunk_clear),cells): return "trunk"
			if not odd or end:
				if field != null: p.y = _height(p.x,p.z)
				var why := _ground_why(last,p)
				if why != "": return why
				last = p
		if end: return ""
	return ""

## A tree's trunk within `r` m of `p` (XZ), from the trees' plan cells
## (kept in `cells` for the call's run).
func _trunk_by(p: Vector3, r: float, cells: Dictionary) -> bool:
	var trees: Node = _study.get("trees") if _study != null else null
	if trees == null or not trees.has_method("cell_trees"): return false
	var seen := {}
	for d: Vector2 in [Vector2(-r,-r),Vector2(r,-r),Vector2(-r,r),Vector2(r,r)]:
		var ck: Vector2i = TreePlan.cell_of(p.x+d.x,p.z+d.y)
		if seen.has(ck): continue
		seen[ck] = true
		if not cells.has(ck): cells[ck] = _cell_trees(trees,ck)
		var t: PackedFloat32Array = cells[ck]
		for q in range(0,t.size(),8):
			if t[q+3] <= 0.0: continue
			if Vector2(p.x-t[q],p.z-t[q+1]).length() < r: return true
	return false

## Peeled off: turned out from the plane's line, braking to the halt; the
## first way whose land holds to a stop: out, half out, on, half in, in.
func _peel(a: Dictionary, why: String) -> void:
	a.state = "peel"
	a.t = 0.0
	a.why = why
	a.leap = ""
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
		if trees != null and float(_top_at(trees,p+Vector3(-way.z,0.0,way.x)*(float(k%3)-1.0))) > -INF: return false
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
	if a.why == "no cover" and not bool(a.retried) and _cover_free and (_at == Vector3.INF or not _threat or _off(a,_at).x < -float(KNOBS.behind)):
		# No cover while the plane was coming (the spots near taken, the wood
		# across its line): once it has passed, the trees again (peeling on
		# while the search is under way).
		var goal: Variant = _cover_find(a)
		if goal != null:
			a.retried = true
			if goal != Vector3.INF:
				stats.cover_retries += 1
				_cover_go(a,goal)
				return
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
	a.clip_rate = clampf(rate,0.4,2.0)
	w_calls += 1
	body.call("play",clip,float(a.clip_rate),0.2)
	a.clip = clip

## The heading's way on the ground.
func _dir(yaw: float) -> Vector3:
	return Vector3(-sin(yaw),0.0,-cos(yaw))

## Turned toward `way` at `rate` rad/s.
func _turn(a: Dictionary, way: Vector3, rate: float, delta: float) -> void:
	a.heading = _turned(float(a.heading),way,rate,delta)

## Heading `h` turned toward `way` at `rate` rad/s over `delta`.
static func _turned(h: float, way: Vector3, rate: float, delta: float) -> float:
	var want := atan2(-way.x,-way.z)
	return h+clampf(wrapf(want-h,-PI,PI),-rate*delta,rate*delta)

## Along its heading at its speed, on the land.
func _step(a: Dictionary, delta: float) -> void:
	var p: Vector3 = a.pos+_dir(float(a.heading))*float(a.speed)*delta
	if field != null: p.y = _height(p.x,p.z)
	# Never into a placed piece: the step not taken, the land ahead bad (the
	# state's own answer to bad land follows: a peel, a detour, a halt).
	if _piece_at(p,0.5*float(KNOBS.piece_pad)) and not _piece_at(a.pos,0.5*float(KNOBS.piece_pad)):
		stats.piece_blocks = int(stats.piece_blocks)+1
		stats.piece_block_in[a.state] = int(stats.piece_block_in.get(a.state,0))+1
		a.bad = true
		a.why = "piece"
		a.speed = 0.0 if a.state == "halt" else minf(float(a.speed),2.0)
		return
	a.pos = p
	if float(a.dodge_t) > 0.0:
		a.dodge_t = float(a.dodge_t)-delta
		if float(a.dodge_t) <= 0.0: a.dodge = 0.0

func _place(a: Dictionary) -> void:
	w_placed += 1
	(a.body as Node3D).transform = Transform3D(Basis(Vector3.UP,float(a.heading)),a.pos)

## The land ahead of one runner a frame (in turn): no water or steep ground
## `probe` s ahead, no trees on the way there. A tree with a clear side:
## stepped round until past it.
func _probe() -> void:
	var n := herd.size()
	for k in range(n):
		var a: Dictionary = herd[(_probe_next+k)%n]
		# A leaper too: the way ahead sweeps on while it is in the air.
		if not (a.state in ["run","leap","peel","scatter","home"]): continue
		if a.state == "home" and (float(a.t) < 0.0 or float(a.speed) <= 0.0): continue
		_probe_next = (_probe_next+k+1)%n
		stats.probes += 1
		if a.state == "home":
			# The way it wants home (or its detour), up to its spot.
			var to: Vector3 = a.home-a.pos
			to.y = 0.0
			var hw: Vector3 = _dir(float(a.detour)) if not is_nan(float(a.detour)) else to.normalized()
			var look := minf(float(KNOBS.home_probe),to.length())
			a.bad = look >= 1.0 and _land_why(a.pos,hw,look) != ""
			return
		var way := _dir(float(a.heading))
		var dist := maxf(float(a.speed)*float(KNOBS.probe),float(KNOBS.probe_min))
		if a.state == "scatter":
			# Land ahead that won't do (trees too): it breaks for the trees now.
			a.bad = _land_why(a.pos,way,dist) != ""
			return
		if a.state == "peel": dist = minf(_peel_stop(a),dist)
		if a.state == "peel":
			a.bad = not _arc_ok(a,float(a.peel),dist)
			return
		var why := _land_why(a.pos,way,dist)
		if a.state == "leap":
			# Held until it lands (the way ahead may sweep past a narrow band
			# of water meanwhile); the run peels from it then.
			if why != "":
				a.bad = true
				a.why = why
			return
		if why == "":
			a.bad = why != ""
			a.why = why if why != "" else str(a.why)
			return
		if why in ["trees","piece"] and float(a.dodge_t) <= 0.0:
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
	if _pieces_on(from,way,dist): return "piece"
	return "trees" if _trees_on(from,way,dist) else ""

## Why the ground at `p` won't do, come to from `from`: water, a climb or a
## steep face ("" when it will).
func _ground_why(from: Vector3, p: Vector3) -> String:
	if field == null: return ""
	var h := _height(p.x,p.z)
	if h < SEA_Y+0.5 or not is_nan(_river(p.x,p.z)): return "water"
	var run := maxf(Vector2(p.x-from.x,p.z-from.z).length(),1.0)
	if absf(h-from.y)/run > float(KNOBS.climb): return "climb"
	var hx := _height(p.x+3.0,p.z)
	var hz := _height(p.x,p.z+3.0)
	if maxf(absf(hx-h),absf(hz-h))/3.0 > float(KNOBS.steep): return "steep"
	if _piece_at(Vector3(p.x,h,p.z),float(KNOBS.piece_pad)): return "piece"
	return ""

## The study's placed sites, found once (null: none).
func _pieces() -> Node:
	if not _placed_looked:
		_plane()
		if _study == null: return null
		_placed_looked = true
		var n: Variant = _study.get("placed")
		_placed = n if n is Node and (n as Node).has_method("inside") else null
	return _placed

## A placed piece's solid within `pad` m of an animal standing at `p` (its
## y the land's), at its legs or its back.
func _piece_at(p: Vector3, pad: float) -> bool:
	var ps := _pieces()
	if ps == null: return false
	w_pieces += 1
	if ps.inside(p+Vector3.UP*float(KNOBS.piece_lo),pad): return true
	return ps.inside(p+Vector3.UP*float(KNOBS.piece_hi),pad)

## A placed piece on the way `dist` m along `way` from `from`: asked every
## `tree_step` m (the land's height under each), the body's width either
## side in the pad.
func _pieces_on(from: Vector3, way: Vector3, dist: float) -> bool:
	if _pieces() == null or field == null: return false
	var step := float(KNOBS.tree_step)
	var n := int(dist/step)
	for k in range(1,n+1):
		var p := from+way*(step*float(k))
		p.y = _height(p.x,p.z)
		if _piece_at(p,float(KNOBS.piece_pad)): return true
	return false

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
		if float(_top_at(trees,p)) > -INF: return true
	return false

## Kept apart by the body length: each pair closer than `apart_bl` BL pushed
## apart (a standing one holds; a moving one gives way), a runner's side
## station shifted with it.
func _apart(delta: float) -> void:
	var apart := float(KNOBS.apart_bl)*bl
	var k := minf(12.0*delta,1.0)
	for i in range(herd.size()):
		var a: Dictionary = herd[i]
		var am: bool = a.state in MOVING
		for j in range(i+1,herd.size()):
			var b: Dictionary = herd[j]
			var bm: bool = b.state in MOVING
			if not am and not bm: continue
			w_pairs += 1
			var d := Vector3(b.pos.x-a.pos.x,0.0,b.pos.z-a.pos.z)
			var l := d.length()
			if l >= apart: continue
			var away := d/l if l > 1e-3 else _r
			var push := (apart-l)*k
			var share := 0.5 if am and bm else 1.0
			if am and not _piece_at(a.pos-away*push*share,0.5*float(KNOBS.piece_pad)):
				a.pos = a.pos-away*push*share
				a.side = float(a.side)-away.dot(_r)*push*share
			if bm and not _piece_at(b.pos+away*push*share,0.5*float(KNOBS.piece_pad)):
				b.pos = b.pos+away*push*share
				b.side = float(b.side)+away.dot(_r)*push*share

## The land's height at (x, z), counted.
func _height(x: float, z: float) -> float:
	w_height += 1
	return float(field.height(x,z))

## The river's surface at (x, z) (NAN off water), counted.
func _river(x: float, z: float) -> float:
	w_river += 1
	return float(field.river_y(x,z))

## The trees' solid top at `p` (-INF where none), counted.
func _top_at(trees: Node, p: Vector3) -> float:
	w_top_at += 1
	return float(trees.call("top_at",p))

## One plan cell's trees, counted.
func _cell_trees(trees: Node, ck: Vector2i) -> PackedFloat32Array:
	w_cells += 1
	return trees.call("cell_trees",ck)

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
	w_calls += 1
	body.call("look_at_world",eye+dir*60.0,smoothstep(0.0,1.0,float(a.look)))

# --- Home -------------------------------------------------------------------

## All calm and the plane beyond the herd's reach: after the wait, each off
## its spot (and not given up) sets off home, staggered (a.t below 0: still
## grazing). None off: the herd is home.
func _home_due(delta: float) -> void:
	if _home_wait < 0.0: _home_wait = _rng.randf_range(float(KNOBS.home_wait_min),float(KNOBS.home_wait_max))
	_home_wait -= delta
	if _home_wait > 0.0: return
	_home_wait = -1.0
	var any := false
	for a: Dictionary in herd:
		if bool(a.gave_up) or _home_dist(a) <= float(KNOBS.home_off): continue
		a.state = "home"
		a.t = -_rng.randf_range(0.0,float(KNOBS.home_stagger))
		a.speed = 0.0
		a.detour = NAN
		a.detour_t = 0.0
		a.best = INF
		a.since = 0.0
		a.bad = false
		any = true
		stats.homes += 1
	if not any: _home_check = false

## How far `a` stands from its spot (m, flat).
func _home_dist(a: Dictionary) -> float:
	return Vector2(a.home.x-a.pos.x,a.home.z-a.pos.z).length()

## The trot's pace at rate 1 (m/s).
func _trot_pace(a: Dictionary) -> float:
	return float(GROUND_BL.trot)*bl/float((a.body as Node).call("clip_length","trot"))

## On the way home: turned round stepping, then the trot (slowing in), round
## land that won't do by a held detour, grazing on its spot (or where it
## stands, when it gets no nearer).
func _home_step(a: Dictionary, delta: float) -> void:
	if float(a.t) < 0.0: return
	var to: Vector3 = a.home-a.pos
	to.y = 0.0
	var dist := to.length()
	var passed := dist < 2.0 and to.dot(_dir(float(a.heading))) < 0.0
	if dist <= 0.6 or passed:
		stats.home_arrived += 1
		_home_end(a)
		return
	if bool(a.bad):
		a.bad = false
		_home_detour(a,to)
	var way: Vector3 = _dir(float(a.detour)) if not is_nan(float(a.detour)) else to/dist
	a.detour_t = float(a.detour_t)-delta
	if float(a.detour_t) <= 0.0: a.detour = NAN
	var body: Node = a.body
	var pace := _trot_pace(a)
	var off := absf(wrapf(atan2(-way.x,-way.z)-float(a.heading),-PI,PI))
	if float(a.speed) <= 0.0 and off > deg_to_rad(float(KNOBS.home_face)):
		# Facing away: it steps round where it stands first.
		_turn(a,way,float(KNOBS.turn_pivot),delta)
		body.call("play","trot",float(KNOBS.home_pivot),0.3)
		a.clip = "trot"
		return
	var want := clampf(dist*1.2,pace*0.4,pace*float(KNOBS.home_rate))
	a.speed = move_toward(maxf(float(a.speed),pace*0.4),want,float(KNOBS.home_accel)*delta)
	_turn(a,way,float(KNOBS.turn_home),delta)
	_step(a,delta)
	_gait(a)
	if dist < float(a.best)-0.5:
		a.best = dist
		a.since = 0.0
	a.since = float(a.since)+delta
	if float(a.since) > float(KNOBS.home_give_up):
		a.gave_up = true
		stats.home_gave_up += 1
		_home_end(a)

## Grazing again, where it stands.
func _home_end(a: Dictionary) -> void:
	a.speed = 0.0
	a.detour = NAN
	_graze(a)

## The land toward home won't do: the nearest way round it whose land holds
## for `home_probe` m, held a while; none: back the way it faces.
func _home_detour(a: Dictionary, to: Vector3) -> void:
	stats.home_detours += 1
	var toward := atan2(-to.x,-to.z)
	var first := signf(wrapf(float(a.heading)-toward,-PI,PI)+0.001)
	for k: float in [30.0,60.0,90.0,120.0,150.0]:
		for s: float in [first,-first]:
			var y := toward+deg_to_rad(k)*s
			if _land_why(a.pos,_dir(y),float(KNOBS.home_probe)) == "":
				a.detour = y
				a.detour_t = float(KNOBS.home_detour)
				return
	a.detour = float(a.heading)+PI
	a.detour_t = float(KNOBS.home_detour)

## Each set back on its spot, grazing (the herd asleep away from home: no
## one sees it).
func _home_snap() -> void:
	stats.home_snaps += 1
	for a: Dictionary in herd:
		a.pos = a.home
		a.heading = a.home_yaw
		a.speed = 0.0
		a.detour = NAN
		a.gave_up = false
		a.flee = -1.0
		a.wait = -1.0
		if a.state != "graze" or a.clip != "graze": _graze(a)
		(a.body as Node).call("set_effect","dust",false)
		_place(a)
	_home_check = false
	_home_wait = -1.0
	_verdict = ""
	_cover = []
	_sweep = {}
	_recenter()

## Stops (or starts) every body's clip: a sleeping herd costs one distance
## a frame.
func _sleep(on: bool) -> void:
	if on and _home_check: _home_snap()
	asleep = on
	for a: Dictionary in herd:
		(a.body as Node).process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
