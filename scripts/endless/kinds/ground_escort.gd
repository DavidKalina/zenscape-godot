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
}

## The body length, in the plane's span (the spec's Size).
const BODY_SPANS := 0.9

var site := {}
var field: RefCounted
## One body length (m).
var bl: float = BODY_SPANS*WorldScale.span
## Each animal: {body, pos (world), heading (rad, yaw), variant, rate,
## state, nerve, wait, calm, look (weight), gaze (yaw off the heading and
## pitch, rad)}. States: `graze`; `alert` (head up, tracking the plane);
## `settle` (the look easing out, then grazing).
var herd: Array = []
var asleep := false
## The sense range of the herd's widest-nerved animal from its home, beyond
## which no animal is asked (one distance a frame).
var _reach := 0.0
var _rng := RandomNumberGenerator.new()
var _study: Node = null
var stats := {"count":0,"bulls":0,"awake_frames":0,"sensing_frames":0,"alerts":0,"settles":0}

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
			"nerve":nerve,"wait":-1.0,"calm":0.0,"look":0.0,"gaze":Vector2.ZERO,"clip":"graze","t":0.0})
	stats.count = herd.size()
	stats.bulls = mini(bulls,herd.size())
	_rng.seed = rng.seed+1
	var spread := maxf(float(KNOBS.spread_along),maxf(float(KNOBS.spread_left),float(KNOBS.spread_right)))
	_reach = float(KNOBS.notice)*float(KNOBS.nerve_max)*float(KNOBS.lose)+spread

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec() if FrameLog.on else 0
	var cam := get_viewport().get_camera_3d()
	if cam == null: return
	var home: Vector3 = (site.get("xform",Transform3D.IDENTITY) as Transform3D).origin
	var far := Vector2(cam.global_position.x-home.x,cam.global_position.z-home.z).length() > float(KNOBS.sleep)
	if far != asleep: _sleep(far)
	if not asleep:
		stats.awake_frames += 1
		_sense(delta,home)
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
## the herd's reach and nobody is up, one distance.
func _sense(delta: float, home: Vector3) -> void:
	var plane := _plane()
	var at := Vector3.INF
	var vel := Vector3.ZERO
	if plane != null:
		at = plane.get("position")
		vel = plane.get("velocity")
	var near := at != Vector3.INF and at.distance_to(home) < _reach
	var busy := near
	if not busy:
		for a: Dictionary in herd:
			if a.state != "graze":
				busy = true
				break
	if not busy: return
	stats.sensing_frames += 1
	for a: Dictionary in herd:
		var d := INF if at == Vector3.INF else at.distance_to(a.pos)
		var reach := float(KNOBS.notice)*float(a.nerve)
		a.t = float(a.t)+delta
		match str(a.state):
			"graze":
				if d < reach:
					if float(a.wait) < 0.0: a.wait = _rng.randf_range(float(KNOBS.react_min),float(KNOBS.react_max))
					a.wait = float(a.wait)-delta
					if float(a.wait) <= 0.0: _alert(a)
				else:
					a.wait = -1.0
			"alert":
				_calm_step(a,d,reach,delta)
				if a.state == "alert" and float(a.t) >= 0.2:
					a.look = minf(float(a.look)+float(KNOBS.look_in)*delta,1.0)
			"settle":
				if d < reach:
					a.state = "alert"
					a.t = 1.0
					a.calm = 0.0
				else:
					a.look = maxf(float(a.look)-float(KNOBS.look_out)*delta,0.0)
					if float(a.look) <= 0.0: _graze(a)
		if a.state != "graze" and at != Vector3.INF: _track(a,at+vel*float(KNOBS.look_lead),delta)

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
