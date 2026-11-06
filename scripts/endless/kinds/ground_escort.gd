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
}

## The body length, in the plane's span (the spec's Size).
const BODY_SPANS := 0.9

var site := {}
var field: RefCounted
## One body length (m).
var bl: float = BODY_SPANS*WorldScale.span
## Each animal: {body, pos (world), heading (rad, yaw), variant, rate}.
var herd: Array = []
var asleep := false
var stats := {"count":0,"bulls":0,"awake_frames":0}

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
		herd.append({"body":body,"pos":world,"heading":yaw,"variant":variant,"rate":rate,"state":"graze"})
	stats.count = herd.size()
	stats.bulls = mini(bulls,herd.size())

func _process(_delta: float) -> void:
	var t0 := Time.get_ticks_usec() if FrameLog.on else 0
	var cam := get_viewport().get_camera_3d()
	if cam == null: return
	var home: Vector3 = (site.get("xform",Transform3D.IDENTITY) as Transform3D).origin
	var far := Vector2(cam.global_position.x-home.x,cam.global_position.z-home.z).length() > float(KNOBS.sleep)
	if far != asleep: _sleep(far)
	if not asleep: stats.awake_frames += 1
	if FrameLog.on: FrameLog.add(&"herd",float(Time.get_ticks_usec()-t0)/1000.0)

## Stops (or starts) every body's clip: a sleeping herd costs one distance
## a frame.
func _sleep(on: bool) -> void:
	asleep = on
	for a: Dictionary in herd:
		(a.body as Node).process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
