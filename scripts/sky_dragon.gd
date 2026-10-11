extends Node3D
## The sky dragon (docs/design/rim-dragon.md, round 3): an experiment. A
## wyvern after Smaug (assets/models/rim_dragon_<a|b|c>.glb, built by
## art/blender/rim_dragon/dragon_body_build.py): the wings are its arms,
## two hind legs, a long serpentine neck, a long whip tail. It rises out of
## the cloud sea and roams the archipelago round the isle: big circuits,
## threading between isles, climbs, dives and now and then a low pass over
## the isle you stand on, its shadow aimed across the turf. Everything is
## posed procedurally on its rig each frame:
##   - wingbeats with weight: a fast, powerful downstroke with the tips
##     lagging, the wings folding at the wrist on the upstroke, the body
##     bobbing against each beat; bouts of beats between glides on spread,
##     gull-bent wings;
##   - riding the air: it swells and dips, rolls and pitches a little as if
##     meeting gusts and thermals (stronger with the isle's breeze), the
##     wings trimming and twisting against it, now and then a bump it
##     shrugs off; it crabs a little into the wind;
##   - turns banked, the neck and head leading into them, the tail a
##     dragged rope (verlet points) so it trails the curve and swings late;
##   - the mouth on springs: it breathes and chews, and now and then it
##     roars: the head lifts and the neck draws back as the jaw opens (eased
##     in, overshooting and settling), the cheek skin stretching and the
##     lower lip following through;
##   - the head turning to look at the camera when it passes close.
##   - round 4, the attack: every minute or two it banks in to a far isle
##     (one of `targets`, seen from the aqueduct isle's turf), flares hard
##     with its wings cupped and back-beating and its legs reaching, and
##     slams onto the rim: hind claws and wrist thumbs hooked over the edge
##     (a little reaching IK each frame), the tail hanging and swinging
##     under the keel, the neck reared up over the turf. The isle shudders,
##     dust and stone come off the rim, its birds burst out. Then it pants
##     and looks round, breathes in (the tell: streaks drawn in, the trees
##     leaning toward it) and blows a sweeping gale across the isle
##     (scripts/dragon_gale.gd: streaks, thrashing trees, leaves torn off,
##     the cloud sea beyond thrown into a wake). After 45 to 60 s it lets
##     go, drops off the rim on a heavy beat and roams again. A pilot on
##     that isle is knocked by the blast as in round 1, and can take the
##     treasure off its tongue (`yielded`).
## Round 1's rim grip on the aqueduct isle itself is parked:
## scripts/rim_dragon.gd, --dragon-rim.
##
## Self-contained: the host (studies/aqueduct_isle.gd) makes one, calls
## `setup` and then `advance` every frame after its own camera is placed,
## and may set `air` (the breeze, about 0..1.5) and `air_angle` (its way,
## radians in x-z) each frame. V cycles a watch camera on it (chase,
## orbit, look from where you stand, off), which takes the host's camera
## over while on.
##
## Flags: --dragon-look=a|b|c (c) the dress; --dragon-delay=<s> (3) before
## it rises; --dragon-skip=<s> runs it on that far at the start;
## --dragon-watch[=chase|orbit|look] starts watching; --dragon-seed=<n> its
## route's dice; --dragon-size=<x> (0.85) its scale; --dragon-attack starts
## it on its way in to an attack (the grab about 8 s on);
## --dragon-target=<isle name> its first (or only) target;
## --dragon-attack-every=<s> (70) between attacks.

signal yielded

const MODELS := {
	"a": "res://assets/models/rim_dragon_a.glb",
	"b": "res://assets/models/rim_dragon_b.glb",
	"c": "res://assets/models/rim_dragon_c.glb",
}
const LOOK_NAMES := {"a":"angular","b":"carved","c":"stone and glow"}

## Flight (m, s, rad). Cruise between FLAP_BELOW and GLIDE_ABOVE: beats
## when slower, glides when faster.
const MAX_TURN := 0.36
const MAX_BANK := 0.9
const MAX_CLIMB := 0.42
const MAX_DIVE := 0.62
const FLAP_BELOW := 28.0
const GLIDE_ABOVE := 34.0
const MIN_SPEED := 22.0
const MAX_SPEED := 54.0
const THRUST := 3.4
const DRAG := 0.00055
const ARRIVE := 105.0
## Beats a second, cruising and climbing; the downstroke's share of a beat.
const BEAT := 0.3
const BEAT_CLIMB := 0.4
const DOWN := 0.5
## The wing's raise at the top and bottom of a beat, and gliding (rad).
const RAISE_UP := 1.1
const RAISE_DOWN := -0.78
const RAISE_GLIDE := 0.17
## The body's bob against a beat (m).
const BOB := 2.2
## The roar's length (s).
const ROAR := 3.6
## The attack (m, s, rad, before `size`). The grab's length; the cling's
## body pitch (nose up, belly to the cliff) and where its root hangs from
## the rim (out from it, down). How long it holds on.
const GRAB := 3.4
const CLING_PITCH := 1.12
const CLING_OUT := 7.5
const CLING_DOWN := 7.0
const CLING_HOLD := Vector2(45.0,60.0)
## The breath's beats: pant, inhale (the tell), blow, recover.
const PANT := Vector2(4.5,7.0)
const INHALE := 2.1
const BLOW := 3.8
const RECOVER := 1.3
## The blow's sweep either side of straight across the isle.
const SWEEP := 0.42
## The blow on a pilot on the isle (round 1's): in the cone's core he is
## knocked into a tumble, in the band pushed along; the treasure is taken
## within TAKE_R of it.
const REACH := 70.0
const CONE := 0.34
const PUSH_CONE := 0.6
const PUSH := 5.0
const KNOCK_OUT := Vector2(12.0,6.0)
const KNOCK_UP := 1.6
const TAKE_R := 3.2
## The spring launch (round 5): standing on the isle as it snaps back, the
## pilot leaves it the moment it comes up faster than he can fall (it
## slows harder than gravity), at its speed where he stands (LAUNCH_GAIN,
## at most LAUNCH_MOST m/s up), nudged in over the isle (LAUNCH_IN of that,
## so he comes down on it).
const LAUNCH_GAIN := 1.0
const LAUNCH_MOST := 32.0
const LAUNCH_IN := 0.1
## --dragon-ride: the first swoop in starts RIDE_OUT m out and RIDE_UP m
## up; it holds on RIDE_HOLD s (one blast) and pants RIDE_PANT s; let go,
## it swoops back for another grab.
const RIDE_OUT := 85.0
const RIDE_UP := 18.0
const RIDE_HOLD := 6.0
const RIDE_PANT := Vector2(2.5,3.5)
const DragonGale = preload("res://scripts/dragon_gale.gd")

var camera: Camera3D
var sea_y := -120.0
var home := Vector3.ZERO
var home_top := 30.0
var isles: Array = []
var look := "c"
var size := 0.85
var delay := 3.0
var _skip := 0.0
var _rng := RandomNumberGenerator.new()
## The isle's breeze (the host sets these each frame).
var air := 0.4
var air_angle := 0.0
## Where a low pass's shadow should cross (the turf's middle; the host may
## set it before `setup`, else the isle's middle at its top).
var shadow_at := Vector3.INF
## The attack's isles: each {name, home (world; y the rim), radius}; the
## host's lookup for an isle's built record ({node, shape, ...}) by name;
## its call to flush the isle's birds (home). The pilot (PilotMotor) and
## his ground's slide, and whether he is on foot (the host sets it).
var targets: Array = []
var find_isle: Callable
var flush_birds: Callable
var walker: Object
var slide: Callable
var on_foot := true
var taken := false

var model: Node3D
var skeleton: Skeleton3D
var _bone := {}
var _rest_local := {}
var _rest_global := {}
var _tail_n := 0
var _neck_n := 0

## "waiting", "rising", "roaming".
var state := "waiting"
var _t := 0.0
var _clock := 0.0
## The flight: where, heading (yaw; 0 faces -z), path angle (gamma), speed,
## the turn's rate, the bank (positive rolls the right side up: a left
## turn).
var pos := Vector3.ZERO
var yaw := 0.0
var gamma := 0.0
var speed := 24.0
var yaw_rate := 0.0
var roll := 0.0
var route: Array = []
var _leg_kinds: Array = []
var leg_kind := "rise"
var _legs_since_pass := 0
## Beats: the beat's phase (0 the top), the flapping's weight, whether a
## bout is on and its beats left, the raise last frame (for the tips' lag).
var phase := 0.0
var flap_w := 1.0
var _bout := true
var _bout_left := 3
var _last_raise := RAISE_UP
var _tip_lag := 0.0
var mode := "climb"
## Riding the air: the swell's vertical speed now, the roll and pitch it
## gives, a bump (a spring kicked now and then) and when the next comes.
var _swell := 0.0
var _swell_y := 0.0
var _air_roll := 0.0
var _air_pitch := 0.0
var _bump := Vector2.ZERO
var _bump_v := Vector2.ZERO
var _bump_next := 5.0
## The neck's lead into a turn (a spring), the head's look (yaw, pitch
## springs).
var _lead := 0.0
var _lead_v := 0.0
var _look := Vector2.ZERO
var _look_v := Vector2.ZERO
var _trim := Vector2.ZERO
## The mouth: the jaw on a spring toward its goal, the lower lip's follow,
## the roar's clock (counting up while one runs, -1 between), a chew's.
var _jaw := 0.0
var _jaw_v := 0.0
var _lip := 0.0
var _lip_v := 0.0
var _roar_t := -1.0
var _roar_next := 9.0
var _chew_t := -1.0
var _chew_next := 4.0
var _chew_size := 0.1
var _rear := 0.0
var _rear_v := 0.0
## The tail's rope (world points from the hips to the tip), last frame's,
## each segment's length and rest direction (skeleton space).
var _rope: PackedVector3Array = []
var _rope_prev: PackedVector3Array = []
var _seg_len: PackedFloat32Array = []
var _seg_dir: Array = []
var _tail_start := Vector3.ZERO
var _rope_ready := false
## The watch camera: "", "chase", "orbit", "look".
var watch := ""
var _watch_eye := Vector3.ZERO
var _watch_look := Vector3.ZERO
var _watch_from := Vector3.ZERO
var _orbit := 0.0
## Pose checks (captures): --dragon-hold keeps it in place at 120 m over the
## isle's east; --dragon-phase=<0..1> holds a beat there (flapping), or
## --dragon-pose=glide|dive|roar; --dragon-orbit=<deg> fixes the orbit's
## angle from its nose (90 its right side, 0 head on, 180 behind);
## --dragon-orbit-up=<m> its height (38), --dragon-orbit-far=<m> (130).
var _hold := false
var _hold_phase := -1.0
var _hold_pose := ""
var _orbit_fixed := INF
var _orbit_up := 38.0
var _orbit_far := 130.0
var _watch_fresh := true
var _toast: Label
var _fov := -1.0
## --dragon-log: a line every 2 s (where, what it is doing).
var _log := false
var _log_t := 0.0
## --dragon-pass: starts on the low pass's way in (its shadow over the isle
## about 12 s on).
var _pass_now := false
## How free in the air it is (1 flying; the swell and bumps fade out as it
## grabs) and how far into the grab's flare.
var _free := 1.0
var _flare := 0.0
## The attack: the next target's index, the seconds till the next attack,
## the grip ({rim, out, tangent, root, yaw, wrists, feet}), the grab's
## start (pos, velocity, yaw, pitch, roll), the cling's clock and what the
## breath is doing ("settle", "pant", "inhale", "blow", "recover") and for
## how long; the effects.
var _attack_now := false
var _target_i := 0
var _attack_in := 40.0
var _attack_every := 70.0
var grip := {}
var _grab := {}
var _cling_t := 0.0
var _cling_left := 50.0
var breath := ""
var _breath_t := 0.0
var _breath_len := 0.0
var _sweep_from := 0.0
## The head's look turned to the world's way round (1 or -1: the neck's
## turn about its root runs one way or the other with the pose).
var _sweep_sign := 1.0
var _knocked := false
var gale: Node3D
var treasure: Node3D
var _treasure_light: OmniLight3D
var _glint: MeshInstance3D
## The cling's springs: the head's look round (yaw, pitch), the rear back
## (inhale) and thrust (blow), the body's settle from the slam.
var _c_look := Vector2.ZERO
var _c_look_v := Vector2.ZERO
var _c_look_goal := Vector2.ZERO
var _c_look_next := 0.0
var _c_rear := 0.0
var _c_rear_v := 0.0
var _c_settle := 0.0
var _c_settle_v := 0.0
var _jaw_goal := -1.0
## A blend from a pose snapshot (bone -> rotation) over `_blend_len` s.
var _blend_from := {}
var _blend_t := 0.0
var _blend_len := 0.0
## --dragon-ride (round 5): the pilot on foot on the target isle, the
## dragon swooping in to grip it over and over.
var ride := false
var _ride_vy := 0.0
var launched := 0
## On the rim (round 6): the head, jaw, neck and thumbs kept on or over the
## isle's turf as it is posed now (rays on its colliders), the chin laid flush
## on the turf between blasts, Odyssey-style: the lower jaw lies on the
## ground and the head lifts off it to pant, inhale and blow.
## Probes are [bone, point in the bone's rest frame] on the mesh's underside
## (scripts measured off rim_dragon_c.glb: the jaw's floor, its sides, the
## snout, the neck's underside, the thumb claws' tips).
const TURF_LAYER := 1 << 11
const SOLID_LAYER := 1
## Each neck bone's share of the lift that lowers the head onto the turf.
const LIFT_SHARE := [0.4,0.3,0.2,0.1]
## The chin's gap over the turf when it lies there (m).
const CHIN_GAP := 0.04
## The thumbs' claws sit this far inside the lip (m).
const THUMB_IN := 0.9
## A neck probe further under the turf than this is under the lip's
## overhang beside the cliff, not in it.
const NECK_DEEP := 3.0
## The pilot surfs down the tipped isle on his own past this (degrees; the
## motor's own SLIDE_AUTO, 44, elsewhere), once it tips past TILT_SLIDE.
const RIDE_SLIDE_AUTO := 15.0
const TILT_SLIDE := 0.12
var _probes_head: Array = []
var _probes_neck: Array = []
var _chin_back: Array = []
var _chin_front: Array = []
var _gem_on: Array = []
var _chin_box: Array = []
var _thumb: Dictionary = {}
var _rest_w := 0.0
var _rest_lift := 0.0
var _rest_nod := 0.0
var _neck_look := Vector2.ZERO
var _neck_base: Array = []
## Logged: the chin's miss from flush (back, front; m) when last laid down.
var chin_miss := Vector2.ZERO
var _ray := PhysicsRayQueryParameters3D.new()
var chin: StaticBody3D
var _auto_was := -1.0
## Logged: the deepest any probe sat in the turf this hold (m, before the
## lift), and after it.
var sunk_before := 0.0
var sunk_after := 0.0

func _init() -> void:
	name = "SkyDragon"

func setup(cam: Camera3D, args: PackedStringArray, sea: float, middle: Vector3, top: float, isle_list: Array) -> void:
	camera = cam
	sea_y = sea
	home = middle
	home_top = top
	isles = isle_list
	_rng.seed = 7
	for arg in args:
		if arg.begins_with("--dragon-look="): look = arg.get_slice("=",1).to_lower()
		elif arg.begins_with("--dragon-delay="): delay = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-skip="): _skip = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-seed="): _rng.seed = int(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-size="): size = float(arg.get_slice("=",1))
		elif arg == "--dragon-log": _log = true
		elif arg == "--dragon-pass": _pass_now = true
		elif arg == "--dragon-attack": _attack_now = true
		elif arg == "--dragon-ride": ride = true
		elif arg.begins_with("--dragon-attack-every="): _attack_every = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-target="):
			var want := arg.get_slice("=",1)
			for i in range(targets.size()):
				if str(targets[i].name) == want: _target_i = i
		elif arg == "--dragon-hold": _hold = true
		elif arg.begins_with("--dragon-phase="): _hold_phase = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-pose="): _hold_pose = arg.get_slice("=",1)
		elif arg.begins_with("--dragon-orbit="): _orbit_fixed = deg_to_rad(float(arg.get_slice("=",1)))
		elif arg.begins_with("--dragon-orbit-up="): _orbit_up = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-orbit-far="): _orbit_far = float(arg.get_slice("=",1))
		elif arg == "--dragon-watch": watch = "chase"
		elif arg.begins_with("--dragon-watch="): watch = arg.get_slice("=",1)
	if not MODELS.has(look):
		push_warning("sky dragon: no look '%s' (a, b, c); c instead" % look)
		look = "c"
	if _attack_now and not args_have(args,"--dragon-delay="): delay = 0.3
	_attack_in = _attack_every*0.55
	_build()
	_build_treasure()
	gale = DragonGale.new()
	gale.sea_y = sea_y
	add_child(gale)
	_start()
	if ride and not targets.is_empty():
		# The isle is small for its neck: its chin sweeps most of it, and
		# the gem would be taken by standing still. Left out for the ride.
		if not args.has("--dragon-ride-gem"):
			taken = true
			treasure.visible = false
		_ride_in()
	print("sky dragon: look %s (%s), rises in %.1f s" % [look,LOOK_NAMES[look],delay])

static func args_have(args: PackedStringArray, prefix: String) -> bool:
	for arg in args:
		if arg.begins_with(prefix): return true
	return false

# --- Building ---------------------------------------------------------------------

func _build() -> void:
	model = (load(MODELS[look]) as PackedScene).instantiate()
	add_child(model)
	model.scale = Vector3.ONE*size
	skeleton = _find_skeleton(model)
	for i in range(skeleton.get_bone_count()):
		var b := skeleton.get_bone_name(i)
		_bone[b] = i
		_rest_local[b] = skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		_rest_global[b] = skeleton.get_bone_global_rest(i).basis.orthonormalized()
	while _bone.has("tail.%d" % _tail_n): _tail_n += 1
	while _bone.has("neck.%d" % _neck_n): _neck_n += 1
	_build_probes()
	_dress(model)
	model.visible = false
	# The tail's rest: the hips' end to the tip, in the skeleton's frame.
	var pts: Array = []
	for i in range(_tail_n): pts.append(skeleton.get_bone_global_rest(_bone["tail.%d" % i]).origin)
	pts.append(pts[_tail_n-1]+(pts[_tail_n-1]-pts[_tail_n-2])*0.9)
	_tail_start = pts[0]
	for i in range(_tail_n):
		_seg_len.append((pts[i+1]-pts[i]).length())
		_seg_dir.append((pts[i+1]-pts[i]).normalized())

## The probes (see `_probes_head`), each [bone index, point in its rest
## frame], and the chin's collider.
func _build_probes() -> void:
	var at := func(b: String, p: Vector3) -> Array:
		if not _bone.has(b): return []
		var i: int = _bone[b]
		return [i,skeleton.get_bone_global_rest(i).affine_inverse()*p]
	_chin_back = at.call("jaw",Vector3(0.0,3.1,-26.0))
	_chin_front = at.call("jaw.tip",Vector3(0.0,4.25,-34.0))
	_gem_on = at.call("jaw",Vector3(0.0,5.9,-33.5))
	_chin_box = at.call("jaw",Vector3(0.0,4.4,-29.0))
	for spec: Array in [["jaw",Vector3(0,3.1,-26)],["jaw",Vector3(2.2,3.8,-26)],["jaw",Vector3(-2.2,3.8,-26)],
			["jaw",Vector3(0,3.5,-29.5)],["jaw",Vector3(1.8,3.9,-30)],["jaw",Vector3(-1.8,3.9,-30)],
			["jaw.tip",Vector3(0,3.9,-32)],["jaw.tip",Vector3(0,4.25,-34)],["jaw.tip",Vector3(0,4.68,-36)],
			["head",Vector3(1.3,4.7,-24)],["head",Vector3(-1.3,4.7,-24)],["head",Vector3(1.8,4.5,-30)],
			["head",Vector3(-1.8,4.5,-30)],["head",Vector3(0,4.5,-34.5)],["head",Vector3(0,5.0,-36.5)]]:
		var pr: Array = at.call(spec[0],spec[1])
		if not pr.is_empty(): _probes_head.append(pr)
	for spec: Array in [["neck.3",Vector3(0,4.6,-22.5)],["neck.2",Vector3(0,4.2,-19)],["neck.2",Vector3(0,4.1,-18)],
			["neck.1",Vector3(0,2.1,-16)],["neck.1",Vector3(0,3.4,-17.5)]]:
		var pr: Array = at.call(spec[0],spec[1])
		if not pr.is_empty(): _probes_neck.append(pr)
	for n in ["L","R"]:
		var k := -1.0 if n == "L" else 1.0
		_thumb[n] = [at.call("wing_hand."+n,Vector3(33.53*k,2.44,-6.82)),at.call("wing_hand."+n,Vector3(33.38*k,3.84,-5.49)),at.call("wing_hand."+n,Vector3(33.0*k,4.8,-3.2))]
	# The chin: a box on the lower jaw while it clings, so the pilot slides
	# up against it (not through it) and the gem on the tongue is in reach.
	chin = StaticBody3D.new()
	chin.name = "Chin"
	chin.top_level = true
	chin.collision_layer = 0
	chin.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(4.6,2.4,10.0)*size
	var shape := CollisionShape3D.new()
	shape.shape = box
	chin.add_child(shape)
	add_child(chin)
	_ray.collide_with_areas = false
	_ray.exclude = [chin.get_rid()]

## A probe's place now (world).
func _probe(pr: Array) -> Vector3:
	return skeleton.global_transform*(skeleton.get_bone_global_pose(int(pr[0]))*(pr[1] as Vector3))

## The isle's top under `p` (world) on `mask`'s layers, -INF over nothing.
func _turf_y(space: PhysicsDirectSpaceState3D, p: Vector3, mask: int) -> float:
	_ray.from = p+Vector3.UP*30.0
	_ray.to = p+Vector3.DOWN*40.0
	_ray.collision_mask = mask
	var hit := space.intersect_ray(_ray)
	return (hit.position as Vector3).y if not hit.is_empty() else -INF

static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null: return s
	return null

func _dress(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			mi.set_surface_override_material(i,_material(m.resource_name if m != null else ""))
		# Its shadow over the isles: the wings' too (two-sided).
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		# The wings reach far from the rest pose's bounds.
		mi.extra_cull_margin = 60.0
	for c in n.get_children(): _dress(c)

## The game's materials, by the model's names: a dark basalt-violet hide
## (satin in a and b, matte stone in c), the lips the hide, the mouth a
## deep maroon going near black, ivory teeth, pale horn and claws, violet
## membranes (c: soft and glowing toward the trailing edge).
func _material(key: String) -> Material:
	if key == "dragon_membrane_glow": return _glow_membrane()
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.roughness = 0.6
	match key:
		"dragon_hide":
			m.albedo_color = Color("40364c")
			m.roughness = 0.85 if look == "c" else 0.55
			m.metallic_specular = 0.3 if look == "c" else 0.45
			m.rim_enabled = true
			m.rim = 0.2
			m.rim_tint = 0.6
		"dragon_belly":
			m.albedo_color = Color("5c5064")
			m.roughness = 0.8
		"dragon_horn":
			m.albedo_color = Color("8a8090")
			m.roughness = 0.5
		"dragon_tooth":
			m.albedo_color = Color("ede7da")
			m.roughness = 0.5
			m.metallic_specular = 0.3
		"dragon_claw":
			m.albedo_color = Color("d8d0c2")
			m.roughness = 0.45
		"dragon_mouth":
			m.albedo_color = Color("2a1117")
			m.roughness = 0.7
			m.metallic_specular = 0.2
		"dragon_tongue":
			m.albedo_color = Color("3d1820")
			m.roughness = 0.55
			m.metallic_specular = 0.35
		"dragon_eye":
			m.albedo_color = Color("ffc040")
			m.emission_enabled = true
			m.emission = Color("ffb030")
			m.emission_energy_multiplier = 2.2
		"dragon_membrane":
			m.albedo_color = Color("3a2e46")
			m.roughness = 0.75
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.backlight_enabled = true
			m.backlight = Color("40243e")
		"dragon_glow":
			m.albedo_color = Color("ffb874")
			m.emission_enabled = true
			m.emission = Color("ff9a52")
			m.emission_energy_multiplier = 1.6
		_:
			m.albedo_color = Color("4a3d5a")
	return m

## The wildcard's membrane: smooth, a deep violet at the bones going to a
## soft rose glow at the trailing edge, lit through from behind.
static func _glow_membrane() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec3 deep : source_color = vec3(0.24, 0.17, 0.32);
uniform vec3 edge : source_color = vec3(0.45, 0.32, 0.56);
uniform vec3 glow : source_color = vec3(0.96, 0.64, 0.74);
uniform float glow_energy = 0.42;
void fragment() {
	float v = UV.y;
	float vein = smoothstep(0.92, 1.0, fract(UV.x * 3.0 + 0.5)) * (1.0 - v) * 0.25;
	vec3 base = mix(deep, edge, smoothstep(0.2, 1.0, v));
	ALBEDO = base * (1.0 - vein);
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	BACKLIGHT = edge * 0.8;
	EMISSION = glow * glow_energy * smoothstep(0.55, 1.0, v) * (0.85 + 0.15 * sin(TIME * 1.3 + UV.x * 4.0));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.resource_name = "dragon_membrane_glow"
	return m

# --- The route ----------------------------------------------------------------------

## Under the cloud sea, out east-south-east of the isle, nose up.
func _start() -> void:
	var out := Vector3(0.88,0.0,0.48).normalized()
	pos = home+out*270.0
	pos.y = sea_y-35.0
	yaw = atan2(out.x,out.z)
	gamma = 1.15
	speed = 24.0
	state = "waiting"
	route = [Vector3(pos.x-out.x*25.0,sea_y+125.0,pos.z-out.z*25.0)]
	_leg_kinds = ["rise"]
	leg_kind = "rise"
	# Then straight into a low pass, so it is seen soon.
	_add_low_pass()
	if _pass_now:
		# --dragon-pass: already on the low pass's way in, level.
		route.pop_front()
		_leg_kinds.pop_front()
		var from: Vector3 = route.pop_front()
		_leg_kinds.pop_front()
		var to: Vector3 = route[0]
		pos = from
		yaw = atan2(-(to.x-from.x),-(to.z-from.z))
		gamma = 0.0
		speed = 32.0
		flap_w = 0.0
		_bout = false
	elif _attack_now and not targets.is_empty():
		# --dragon-attack: already on its way in, level, far out.
		route.clear()
		_leg_kinds.clear()
		_add_attack()
		route.pop_front()
		_leg_kinds.pop_front()
		var to: Vector3 = route[0]
		var away: Vector3 = grip.out
		var along: Vector3 = grip.tangent
		pos = to+away*170.0+along*float(grip.side)*70.0+Vector3.UP*22.0
		yaw = atan2(-(to.x-pos.x),-(to.z-pos.z))
		gamma = 0.0
		speed = 32.0
		flap_w = 0.0
		_bout = false

## --dragon-ride: it comes in close and low on its grab at once.
func _ride_in() -> void:
	_attack_in = INF
	route.clear()
	_leg_kinds.clear()
	grip = _plan_grip(targets[_target_i%targets.size()])
	var out: Vector3 = grip.out
	pos = (grip.root as Vector3)+out*RIDE_OUT+(grip.tangent as Vector3)*float(grip.side)*25.0+Vector3.UP*RIDE_UP
	var to := (grip.root as Vector3)-pos
	yaw = atan2(-to.x,-to.z)
	gamma = -0.12
	speed = 30.0
	flap_w = 0.0
	_bout = false
	state = "roaming"
	model.visible = true
	_begin_grab()

## Where the pilot starts on --dragon-ride: on the target isle, a little
## more than halfway out to the gripped rim and off its blast's middle
## line, facing the dragon (x, y, z and the turn --place takes: degrees
## from facing -z, clockwise); INF without a grip.
func ride_spot() -> Vector4:
	if grip.is_empty(): return Vector4.INF
	var t: Dictionary = grip.target
	var home_at: Vector3 = t.home
	var rim: Vector3 = grip.rim
	var out: Vector3 = grip.out
	# Half way out, a third of the way round from the neck, clear of its
	# chin while it pants.
	var spot := home_at+(rim-home_at).rotated(Vector3.UP,-0.75*float(grip.side))*0.6
	var rec := _record(t)
	var shape: RefCounted = rec.get("shape") as RefCounted if rec.has("shape") else null
	var y := rim.y+1.0
	if shape != null:
		var flat := Vector2(spot.x-home_at.x,spot.z-home_at.z)
		if shape.on_land(flat): y = home_at.y+float(shape.ground_at(flat))+0.2
	return Vector4(spot.x,y,spot.z,rad_to_deg(atan2(out.x,-out.z)))

func _isle_pos(i: int) -> Vector3:
	return isles[i][0]

## Toward the sun (unit), from the scene's first shadowed directional
## light; straight up if there is none.
func _sun_to() -> Vector3:
	if not is_inside_tree(): return Vector3.UP
	for n in get_tree().root.find_children("*","DirectionalLight3D",true,false):
		var l := n as DirectionalLight3D
		if l.shadow_enabled and l.visible and l.get_viewport() == get_viewport():
			var to := l.global_transform.basis.z.normalized()
			if to.y > 0.05: return to
	return Vector3.UP

## A low pass over the home isle: in from far off and high, down over it at
## a clear height and out the far side. The middle point is set up-sun of
## the isle's middle, so its shadow sweeps across the turf.
func _add_low_pass() -> void:
	var a := _rng.randf()*TAU
	var way := Vector3(cos(a),0.0,sin(a))
	var over := home_top+42.0
	var sun := _sun_to()
	var shift := Vector3(sun.x,0.0,sun.z)*(44.0/sun.y)
	shift = shift.limit_length(80.0)
	var aim := shadow_at if shadow_at != Vector3.INF else Vector3(home.x,home_top,home.z)
	var mid := Vector3(aim.x,over,aim.z)+shift
	if _log: print("sky dragon: low pass over (%.0f, %.0f, %.0f), the sun toward (%.2f, %.2f, %.2f)" % [mid.x,mid.y,mid.z,sun.x,sun.y,sun.z])
	route.append(mid-way*340.0+Vector3.UP*40.0)
	route.append(mid-way*130.0+Vector3.UP*3.0)
	route.append(mid)
	route.append(mid+way*220.0+Vector3.UP*20.0)
	for i in range(4): _leg_kinds.append("low pass")
	_legs_since_pass = 0

## A big circuit round the archipelago, high.
func _add_circuit() -> void:
	var r := _rng.randf_range(260.0,400.0)
	var h := _rng.randf_range(105.0,150.0)
	var a0 := atan2(pos.z-home.z,pos.x-home.x)
	var turn := 1.0 if _rng.randf() < 0.5 else -1.0
	for k in range(1,4):
		var a := a0+turn*k*TAU/5.0
		route.append(home+Vector3(cos(a)*r,h-home.y+_rng.randf_range(-20.0,20.0),sin(a)*r))
		_leg_kinds.append("circuit")

## Threading between two neighbouring isles, low, at their rims' height.
func _add_thread() -> void:
	if isles.size() < 2:
		_add_circuit()
		return
	var best := []
	for i in range(isles.size()):
		for j in range(i+1,isles.size()):
			var a := _isle_pos(i)
			var b := _isle_pos(j)
			var gap := Vector2(a.x-b.x,a.z-b.z).length()-float(isles[i][1])-float(isles[j][1])
			if gap > 110.0 and gap < 420.0: best.append([i,j])
	if best.is_empty():
		_add_circuit()
		return
	var pick: Array = best[_rng.randi()%best.size()]
	var a := _isle_pos(pick[0])
	var b := _isle_pos(pick[1])
	var mid := (a+b)*0.5
	var across := Vector3(-(b.z-a.z),0.0,b.x-a.x).normalized()
	if across.dot(mid-pos) < 0.0: across = -across
	var y := minf(a.y,b.y)+10.0
	route.append(mid-across*230.0+Vector3.UP*(y+35.0-mid.y))
	route.append(Vector3(mid.x,y,mid.z))
	route.append(mid+across*220.0+Vector3.UP*(y+25.0-mid.y))
	for i in range(3): _leg_kinds.append("thread")

## Up high on heavy beats, then a long dive down at a far point.
func _add_climb_dive() -> void:
	var a := _rng.randf()*TAU
	var near := home+Vector3(cos(a),0.0,sin(a))*_rng.randf_range(180.0,300.0)
	route.append(Vector3(near.x,_rng.randf_range(190.0,230.0),near.z))
	var b := a+_rng.randf_range(1.2,2.2)
	var far := home+Vector3(cos(b),0.0,sin(b))*_rng.randf_range(240.0,380.0)
	route.append(Vector3(far.x,_rng.randf_range(60.0,80.0),far.z))
	_leg_kinds.append("climb")
	_leg_kinds.append("dive")

func _next_legs() -> void:
	if _attack_in <= 0.0 and not targets.is_empty():
		_add_attack()
		return
	_legs_since_pass += 1
	if _legs_since_pass >= 3 and _rng.randf() < 0.7:
		_add_low_pass()
		return
	var r := _rng.randf()
	if r < 0.34: _add_circuit()
	elif r < 0.68: _add_thread()
	else: _add_climb_dive()

# --- Each frame ---------------------------------------------------------------------

func advance(delta: float) -> void:
	if delta <= 0.0: return
	if _skip > 0.0:
		var ahead := _skip
		_skip = 0.0
		while ahead > 0.0:
			_step(minf(ahead,1.0/30.0))
			ahead -= 1.0/30.0
	_step(minf(delta,0.1))
	_watch_camera(delta)

func _step(delta: float) -> void:
	_clock += delta
	_t += delta
	if state == "waiting":
		if _t < delay: return
		state = "roaming" if _pass_now or _attack_now else "rising"
		model.visible = true
		_t = 0.0
	if state == "roaming": _attack_in -= delta
	_ride_air(delta)
	match state:
		"grabbing":
			_grabbing(delta)
			_pose(delta)
		"clinging": _clinging(delta)
		"leaving":
			_leaving(delta)
			_pose(delta)
		_:
			if _hold: _held(delta)
			else: _fly(delta)
			_pose(delta)
	_blend(delta)
	gale.advance(delta)
	# Round 6: head, jaw and neck clear of the isle as it stands after its
	# move this frame, the chin's collider and the gem on the jaw so posed.
	if state in ["grabbing","clinging","leaving"]: _clear_turf()
	_place_chin(state == "clinging")
	_place_treasure(delta)
	_ride_isle(delta)
	if _log:
		_log_t += delta
		if _log_t >= (0.5 if leg_kind == "low pass" else 2.0):
			_log_t = 0.0
			if walker != null and on_foot:
				var f: Vector3 = walker.get("feet")
				var gem := treasure.global_position if treasure != null else Vector3.ZERO
				print("sky dragon: pilot at (%.1f, %.1f, %.1f) grounded %s v.y %.1f, %s on %.0f°, %.1f m/s, the gem at (%.1f, %.1f, %.1f), the isle's rim sags %.1f m" % [f.x,f.y,f.z,str(walker.get("grounded")),(walker.get("velocity") as Vector3).y,str(walker.get("move")),walker.steepness(),walker.speed(),gem.x,gem.y,gem.z,gale.sag])
			if state in ["clinging","grabbing","leaving"]:
				print("sky dragon: t %.1f %s %s, %.0f s to let go, at (%.0f, %.0f, %.0f), %.0f m from the isle's middle; head in the turf %.2f m unlifted, %.2f m lifted, resting %.2f (chin off flush %.2f, %.2f m), isle tipped %.0f°" % [_clock,state,breath,_cling_left,pos.x,pos.y,pos.z,Vector2(pos.x-home.x,pos.z-home.z).length(),-sunk_before,-sunk_after,_rest_w,chin_miss.x,chin_miss.y,rad_to_deg(gale.tip())])
				sunk_before = 0.0
				sunk_after = 0.0
			else: print("sky dragon: t %.0f %s %s leg %s at (%.0f, %.0f, %.0f) %.1f m/s gamma %.2f roll %.2f flap %.2f, %.0f m from the isle's middle" % [_clock,state,mode,leg_kind,pos.x,pos.y,pos.z,speed,gamma,roll,flap_w,Vector2(pos.x-home.x,pos.z-home.z).length()])

func _fly(delta: float) -> void:
	if route.is_empty(): _next_legs()
	var target: Vector3 = route[0]
	leg_kind = _leg_kinds[0]
	var to := target-pos
	var flat := Vector2(to.x,to.z)
	var dist := flat.length()
	# A low pass is flown right through its points, so it really is low.
	var arrive := 30.0 if state == "rising" else (40.0 if leg_kind in ["low pass","grab"] else ARRIVE)
	var behind := Vector2(-sin(yaw),-cos(yaw)).dot(flat.normalized()) < -0.2
	var reached := pos.y > target.y-10.0 if state == "rising" else (dist < arrive or (behind and dist < (90.0 if leg_kind == "low pass" else 220.0)))
	if reached:
		route.pop_front()
		_leg_kinds.pop_front()
		if state == "rising": state = "roaming"
		if leg_kind == "grab":
			_begin_grab()
			return
		if route.is_empty(): _next_legs()
		target = route[0]
		to = target-pos
		flat = Vector2(to.x,to.z)
		dist = flat.length()
	# Turn toward it, the turn's rate eased; bank to suit. A slow weave on
	# top, so a straight never looks ruled.
	var want_yaw := atan2(-to.x,-to.z)
	var dyaw := wrapf(want_yaw-yaw,-PI,PI)
	var max_turn := MAX_TURN*(0.6 if state == "rising" else 1.0)
	var weave := 0.035*sin(_clock*0.23+1.3)+0.02*sin(_clock*0.61)
	var want_rate := clampf(dyaw*0.6+weave,-max_turn,max_turn)
	yaw_rate = move_toward(yaw_rate,want_rate,0.3*delta)
	yaw += yaw_rate*delta
	var want_roll := clampf(atan(speed*yaw_rate/9.8),-MAX_BANK,MAX_BANK)
	roll = lerpf(roll,want_roll,1.0-exp(-delta*1.8))
	# Climb or dive toward its height.
	var want_gamma := clampf(atan2(to.y,maxf(dist,1.0))*1.4,-MAX_DIVE,MAX_CLIMB)
	if state == "rising": want_gamma = clampf(atan2(to.y,maxf(dist,1.0))*2.0,0.2,1.15)
	gamma = move_toward(gamma,want_gamma,(0.5 if state == "rising" else 0.36)*delta)
	# Beats or glides: climbing always beats, diving tucks, cruising beats in
	# bouts when slow and glides when quick.
	if gamma > 0.22 or state == "rising": mode = "climb"
	elif gamma < -0.2: mode = "dive"
	else: mode = "cruise"
	match mode:
		"climb": _bout = true
		"dive": _bout = false
		"cruise":
			if not _bout and speed < FLAP_BELOW:
				_bout = true
				_bout_left = _rng.randi_range(1,3)
			elif _bout and speed > GLIDE_ABOVE and _bout_left <= 0: _bout = false
	flap_w = move_toward(flap_w,1.0 if _bout else 0.0,delta*(1.4 if _bout else 0.7))
	# The push comes on the downstroke, so each beat surges.
	var power := (1.4 if mode == "climb" else 1.0)*(1.8 if phase < DOWN else 0.2)
	var accel := flap_w*THRUST*power-DRAG*speed*speed-9.8*sin(gamma)*0.5
	if mode == "dive": accel -= DRAG*speed*speed*0.4
	# The swell's lift feeds the speed a little, as a soaring bird's does.
	accel += _swell*0.12
	speed = clampf(speed+accel*delta,24.0 if state == "rising" else MIN_SPEED,MAX_SPEED)
	var fwd := Vector3(-sin(yaw)*cos(gamma),sin(gamma),-cos(yaw)*cos(gamma))
	pos += fwd*speed*delta
	# Carried by the air: a drift down the wind (the swell is laid on in
	# `_pose`, as a bounded rise and fall).
	pos += Vector3(cos(air_angle),0.0,sin(air_angle))*(1.5+3.0*air)*delta
	# The beat keeps turning while the flapping fades, so wings settle.
	var hz := lerpf(BEAT,BEAT_CLIMB,clampf(gamma/MAX_CLIMB,0.0,1.0)) if state != "rising" else BEAT_CLIMB
	var before := phase
	if flap_w > 0.01 or fposmod(phase,1.0) > 0.02: phase = fposmod(phase+delta*hz,1.0)
	if phase < before and _bout_left > 0: _bout_left -= 1

## The air it rides: a slow swell of rising and sinking air (a few m/s,
## more in a stronger breeze, most when gliding), the roll and pitch the
## air puts on it, and now and then a bump (a kicked spring) it shrugs off.
func _ride_air(delta: float) -> void:
	var c := _clock
	var gain := (0.7+0.9*clampf(air,0.0,1.5))*(1.0-0.45*flap_w)
	# The rise and fall (m) and its vertical speed (m/s).
	_swell_y = gain*(5.0*sin(c*0.19+0.4)+2.2*sin(c*0.43+2.1)+0.6*sin(c*0.97+4.0))
	_swell = gain*(0.95*cos(c*0.19+0.4)+0.95*cos(c*0.43+2.1)+0.58*cos(c*0.97+4.0))
	_air_roll = gain*(0.07*sin(c*0.31+1.0)+0.045*sin(c*0.83+0.3)+0.02*sin(c*1.9))
	_air_pitch = gain*(0.035*sin(c*0.27+2.6)+0.02*sin(c*0.71+1.1))+_swell*0.025
	_bump_next -= delta
	if _bump_next <= 0.0:
		_bump_next = _rng.randf_range(3.5,8.0)
		_bump_v += Vector2(_rng.randf_range(-0.5,0.5),_rng.randf_range(-0.25,0.35))*gain
	# Roll and pitch bumps, under-damped: a jolt, a sway, settled.
	_bump_v += (-_bump*7.0-_bump_v*2.6)*delta
	_bump += _bump_v*delta

## Held in place for a pose check.
func _held(delta: float) -> void:
	state = "roaming"
	pos = home+Vector3(150.0,120.0-home.y,0.0)
	yaw = 0.0
	yaw_rate = 0.0
	roll = 0.0
	speed = 30.0
	gamma = -0.35 if _hold_pose == "dive" else 0.0
	mode = "dive" if _hold_pose == "dive" else "cruise"
	if _hold_phase >= 0.0:
		flap_w = 1.0
		phase = _hold_phase
	elif _hold_pose != "":
		flap_w = 0.0
	else:
		flap_w = 1.0
		phase = fposmod(phase+delta*BEAT,1.0)
	if _hold_pose == "roar" and _roar_t < 0.0 and _clock > 1.0: _roar_t = 0.0

## The wing's raise and fold through a beat (phase 0 = top).
static func _beat_raise(p: float) -> float:
	if p < DOWN:
		var u := p/DOWN
		# The power stroke: quick through its middle.
		return lerpf(RAISE_UP,RAISE_DOWN,u*u*(3.0-2.0*u))
	var u := (p-DOWN)/(1.0-DOWN)
	return lerpf(RAISE_DOWN,RAISE_UP,u*u*(3.0-2.0*u))

static func _beat_fold(p: float) -> float:
	if p < DOWN: return 0.25*pow(1.0-p/DOWN,3.0)
	return sin(PI*(p-DOWN)/(1.0-DOWN))

func _pose(delta: float) -> void:
	# The wings: a beat blended with the glide (or the dive's tuck).
	var raise := lerpf(RAISE_GLIDE,_beat_raise(phase),flap_w)
	var fold := lerpf(0.05,_beat_fold(phase)*0.95,flap_w)
	var sweep := 0.0
	if mode == "dive":
		var tuck := (1.0-flap_w)*smoothstep(0.2,0.45,-gamma)
		raise = lerpf(raise,0.32,tuck)
		fold = lerpf(fold,0.55,tuck)
		sweep = 0.3*tuck
	# The grab's flare: wings cupped forward, beating back against the air.
	sweep -= 0.55*_flare
	# The tips lag the beat: they bend against the raise's speed.
	var rv := (raise-_last_raise)/maxf(delta,0.001)
	_last_raise = raise
	_tip_lag = lerpf(_tip_lag,clampf(-rv*0.16,-0.5,0.5),1.0-exp(-delta*10.0))
	# Gliding: the wings trim against the air, each on its own: the raise
	# answers the air's roll (the low wing lifts), the hands twist with the
	# swell, the tips flex on a bump.
	var still := 1.0-flap_w
	var air_roll := (_air_roll+_bump.x)*_free
	_trim = Vector2(0.05*sin(_clock*0.71)+0.03*sin(_clock*1.9),0.05*sin(_clock*0.63+1.7)+0.03*sin(_clock*2.3))*still
	var twist := (_swell*0.02+0.06*sin(_clock*0.9))*still
	# The body: bobbing against each beat, nodding with it, rolled and
	# pitched by the air.
	var bob := -BOB*cos(TAU*phase)*flap_w*(1.3 if mode == "climb" else 1.0)
	var nod := 0.04*sin(TAU*phase)*flap_w
	var pitch := gamma*0.75+0.05+nod+(_air_pitch+_bump.y)*_free
	var body_roll := roll+air_roll
	var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)*Basis(Vector3.BACK,body_roll)
	global_transform = Transform3D(basis,pos+basis.y*bob*size+Vector3.UP*_swell_y*_free)
	for side in [-1.0,1.0]:
		var n := "L" if side < 0.0 else "R"
		# The low wing (air rolling it down) lifts against it.
		var r: float = raise+(_trim.x if side < 0.0 else _trim.y)-side*roll*0.08+side*air_roll*0.9*still
		var flex: float = _bump_v.x*side*0.12*still
		_turn("wing_arm."+n,[[Vector3.BACK,side*r],[Vector3.UP,-side*(sweep+0.15*fold)],[Vector3.RIGHT,0.06*flap_w*sin(TAU*phase)+twist*0.4*side]])
		# A gull's bend at the wrist when gliding: the hand a little down.
		_turn("wing_fore."+n,[[Vector3.UP,side*fold*0.85],[Vector3.BACK,side*(0.2*r+_tip_lag*0.3-0.22*still)]])
		_turn("wing_hand."+n,[[Vector3.UP,-side*fold*1.75],[Vector3.BACK,side*(_tip_lag*0.6+flex)],[Vector3.RIGHT,twist*side]])
		_turn("wing_f1."+n,[[Vector3.BACK,side*(_tip_lag*0.5+0.06*still)]])
		_turn("wing_f1b."+n,[[Vector3.BACK,side*(_tip_lag*0.7+flex*1.5+0.08*still)]])
		_turn("wing_f2."+n,[[Vector3.UP,side*fold*0.15],[Vector3.BACK,side*(_tip_lag*0.5+flex)]])
		_turn("wing_f3."+n,[[Vector3.UP,side*fold*0.3],[Vector3.BACK,side*_tip_lag*0.4]])
		_turn("wing_f4."+n,[[Vector3.UP,side*fold*0.45],[Vector3.BACK,side*_tip_lag*0.3]])
		# The hind legs tucked back under the tail's root; a little swing with
		# the beat.
		var swing := 0.06*sin(TAU*phase-0.8)*flap_w
		# In the flare the legs swing down and forward, claws open, reaching.
		_turn("hind_upper."+n,[[Vector3.RIGHT,lerpf(-1.5-swing,0.7,_flare)]])
		_turn("hind_lower."+n,[[Vector3.RIGHT,lerpf(0.9,-0.4,_flare)]])
		_turn("hind_foot."+n,[[Vector3.RIGHT,lerpf(-0.7,0.5,_flare)]])
	_mouth(delta)
	# The body arching a little with the beat; the chest breathing.
	var breath := sin(_clock*TAU*0.18)
	_turn("chest",[[Vector3.RIGHT,0.03*sin(TAU*phase+0.6)*flap_w]])
	if _bone.has("chest"): skeleton.set_bone_pose_scale(_bone["chest"],Vector3(1.0+0.025*breath,1.0,1.0+0.03*breath))
	_turn("hips",[[Vector3.RIGHT,-0.03*sin(TAU*phase+0.6)*flap_w]])
	# The neck leads into the turn (a spring, so it overshoots a little) and
	# holds the head level against the pitch, bank and bob; it sways in a
	# slow S of its own; in a roar it draws back and the head lifts.
	var want_lead := clampf(yaw_rate*2.2,-0.75,0.75)
	_lead_v += ((want_lead-_lead)*6.0-_lead_v*3.2)*delta
	_lead += _lead_v*delta
	var look_goal := Vector2.ZERO
	if camera != null and watch != "chase":
		var eye := camera.global_position
		var off := global_transform.affine_inverse()*eye
		var d := off.length()
		if d < 260.0 and off.z < 20.0:
			var w := 1.0-smoothstep(150.0,260.0,d)
			look_goal = Vector2(clampf(atan2(-off.x,-off.z),-0.8,0.8),clampf(atan2(off.y,Vector2(off.x,off.z).length()),-0.6,0.35))*w
	_look_v += ((look_goal-_look)*3.0-_look_v*2.6)*delta
	_look += _look_v*delta
	var head_yaw := _lead+_look.x
	var level := -pitch*0.7+_look.y
	var neck_sway := 0.05*sin(TAU*phase-1.2)*flap_w+0.04*sin(_clock*0.37)
	var slither := 0.05*sin(_clock*0.29+0.8)
	_turn("spine.2",[[Vector3.RIGHT,-0.06]])
	# Each neck bone, root to head: the S's bend (root up, head end down),
	# its share of the lead, the slow sway passing up it, and the roar's
	# draw back.
	for i in range(_neck_n):
		var u := float(i)/maxf(_neck_n-1,1)
		var bend := lerpf(0.04,-0.08,u)+_rear*lerpf(0.2,-0.14,u)
		var wave := neck_sway*sin(PI*u+0.3)+slither*cos(PI*u)
		_turn("neck.%d" % i,[[Vector3.RIGHT,bend+wave],[Vector3.UP,head_yaw*1.0/_neck_n+slither*0.6*(u-0.5)]])
	_turn("head",[[Vector3.RIGHT,0.08+level-neck_sway*0.6+_rear*0.3],[Vector3.UP,head_yaw*0.2],[Vector3.BACK,-body_roll*0.5]])
	_tail(delta)

## The mouth, all on springs: breathing (a slight part and close), chews
## now and then, and the roar: a tightening first, then the jaw eased open
## (a spring past its goal and back), held trembling, eased shut, the head
## lifting and the neck drawing back with it; the lower lip follows the
## jaw late (jaw.tip), and the cheek skin stretches (the model's weights).
func _mouth(delta: float) -> void:
	var goal := 0.03+0.015*sin(_clock*TAU*0.18+0.6)
	var rear_goal := 0.0
	if state == "clinging" and _jaw_goal >= 0.0:
		# On the rim the breath sets the jaw (no chews, no roars).
		goal = _jaw_goal
	elif _roar_t < 0.0 and _hold_pose != "roar":
		_roar_next -= delta
		if _roar_next <= 0.0:
			_roar_t = 0.0
			_roar_next = _rng.randf_range(12.0,22.0)
	if _roar_t >= 0.0:
		_roar_t += delta
		var t := _roar_t
		if t < 0.45:
			goal = 0.0
			rear_goal = -0.15*sin(PI*t/0.45)
		elif t < 1.35:
			var u := (t-0.45)/0.9
			goal = 0.62*u*u*(3.0-2.0*u)*u
			rear_goal = smoothstep(0.0,1.0,u)
		elif t < 2.5:
			goal = 0.62+0.025*sin(t*31.0)
			rear_goal = 1.0
		elif t < ROAR:
			var u := (t-2.5)/(ROAR-2.5)
			goal = lerpf(0.62,0.03,u*u*(3.0-2.0*u))
			rear_goal = 1.0-smoothstep(0.0,1.0,u)
		else:
			_roar_t = 0.0 if _hold_pose == "roar" else -1.0
	elif state != "clinging":
		_chew_next -= delta
		if _chew_next <= 0.0 and _chew_t < 0.0:
			_chew_t = 0.0
			_chew_size = _rng.randf_range(0.06,0.14)
			_chew_next = _rng.randf_range(2.5,6.5)
		if _chew_t >= 0.0:
			_chew_t += delta
			# One or two small bites, each soft in and out.
			var bites := 2.0 if _chew_size > 0.1 else 1.0
			var span := 0.55*bites
			if _chew_t >= span: _chew_t = -1.0
			else: goal += _chew_size*pow(sin(PI*fposmod(_chew_t,0.55)/0.55),2.0)
	# The jaw: an under-damped spring (overshoot, settle).
	var acc := (goal-_jaw)*55.0-_jaw_v*8.0
	_jaw_v += acc*delta
	_jaw += _jaw_v*delta
	# The lip lags the jaw's speed and springs back.
	_lip_v += ((clampf(_jaw_v*0.09,-0.2,0.2)-_lip)*70.0-_lip_v*7.0)*delta
	_lip += _lip_v*delta
	_rear_v += ((rear_goal-_rear)*14.0-_rear_v*5.5)*delta
	_rear += _rear_v*delta
	_turn("jaw",[[Vector3.RIGHT,-maxf(_jaw,-0.01)]])
	_turn("jaw.tip",[[Vector3.RIGHT,_lip]])

## The tail: a rope of points dragged from the hips, each held a segment's
## length from the one before and pulled softly toward its rest line, so
## it trails the flight's curve, swings late out of turns and ripples with
## the bob. The bones are then turned to lie along it.
func _tail(delta: float) -> void:
	for i in range(_tail_n): _turn("tail.%d" % i,[])
	var sk := skeleton.global_transform
	var start := sk*(skeleton.get_bone_global_pose(_bone["hips"])*(skeleton.get_bone_global_rest(_bone["hips"]).affine_inverse()*_tail_start))
	var basis := sk.basis
	if not _rope_ready:
		_rope = [start]
		for i in range(_tail_n): _rope.append(_rope[i]+basis*((_seg_dir[i] as Vector3)*_seg_len[i]))
		_rope_prev = _rope.duplicate()
		_rope_ready = true
	_rope[0] = start
	var n := float(_tail_n)
	for i in range(1,_tail_n+1):
		var p := _rope[i]
		var v := (p-_rope_prev[i])*0.94
		_rope_prev[i] = p
		p += v
		var len_w := (basis*((_seg_dir[i-1] as Vector3)*_seg_len[i-1]))
		# Its rest line from the point before, firmer near the hips; a slow
		# wave down it, as a whip in the air.
		var rest := _rope[i-1]+len_w
		rest += basis.x.normalized()*sin(_clock*0.8-float(i)*0.7)*0.25*float(i)/n*len_w.length()
		if state == "clinging" and not grip.is_empty():
			# Hanging: down under the keel, swinging slowly side to side.
			rest += Vector3.DOWN*len_w.length()*0.35
			rest += (grip.tangent as Vector3)*sin(_clock*0.5-float(i)*0.32)*0.22*float(i)/n*len_w.length()
		p = p.lerp(rest,clampf((n+1.0-float(i))*5.4/n*delta,0.0,1.0))
		var d := p-_rope[i-1]
		_rope[i] = _rope[i-1]+d.normalized()*len_w.length()
	# The bones along the rope: each turned by its bend from the one before.
	var inv := basis.inverse()
	var prev_yaw := 0.0
	var prev_pitch := 0.0
	for i in range(_tail_n):
		var d: Vector3 = inv*(_rope[i+1]-_rope[i])
		var r: Vector3 = _seg_dir[i]
		var yaw_t := atan2(d.x,d.z)-atan2(r.x,r.z)
		var pitch_t := atan2(-d.y,Vector2(d.x,d.z).length())-atan2(-r.y,Vector2(r.x,r.z).length())
		var by := clampf(wrapf(yaw_t-prev_yaw,-PI,PI),-0.45,0.45)
		var bp := clampf(pitch_t-prev_pitch,-0.35,0.35)
		prev_yaw += by
		prev_pitch += bp
		_turn("tail.%d" % i,[[Vector3.UP,by],[Vector3.RIGHT,bp]])

func _turn(b: String, turns: Array) -> void:
	if not _bone.has(b): return
	var g: Basis = _rest_global[b]
	var q: Quaternion = _rest_local[b]
	for turn: Array in turns:
		var angle: float = turn[1]
		if absf(angle) < 0.00001: continue
		q = q*Quaternion((g.inverse()*(turn[0] as Vector3)).normalized(),angle)
	skeleton.set_bone_pose_rotation(_bone[b],q)

# --- The attack ------------------------------------------------------------------------

## The treasure on its tongue: a gem riding the jaw, a small light and a
## glint that flares now and then, big enough to catch the eye from afar.
func _build_treasure() -> void:
	treasure = Node3D.new()
	treasure.name = "Treasure"
	treasure.top_level = true
	add_child(treasure)
	var gem := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.9
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	gem.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffd56a")
	m.metallic = 0.8
	m.roughness = 0.15
	m.emission_enabled = true
	m.emission = Color("ffb84a")
	m.emission_energy_multiplier = 3.0
	gem.material_override = m
	gem.name = "Gem"
	treasure.add_child(gem)
	_treasure_light = OmniLight3D.new()
	_treasure_light.light_color = Color("ffcf70")
	_treasure_light.light_energy = 1.4
	_treasure_light.omni_range = 7.0
	treasure.add_child(_treasure_light)
	_glint = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0,1.0)
	_glint.mesh = quad
	var g := StandardMaterial3D.new()
	g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	g.no_depth_test = false
	g.albedo_color = Color(1.0,0.85,0.5,1.0)
	g.albedo_texture = _glint_texture()
	_glint.material_override = g
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	treasure.add_child(_glint)
	treasure.visible = false

## A four-pointed star of light.
static func _glint_texture() -> Texture2D:
	var n := 64
	var img := Image.create(n,n,false,Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var p := Vector2(x+0.5-n*0.5,y+0.5-n*0.5)/(n*0.5)
			var core := exp(-p.length_squared()*18.0)
			var rays := exp(-absf(p.x)*40.0)*(1.0-absf(p.y))+exp(-absf(p.y)*40.0)*(1.0-absf(p.x))
			var a := clampf(core+rays*0.8,0.0,1.0)
			img.set_pixel(x,y,Color(1,1,1,a))
	return ImageTexture.create_from_image(img)

## The gem on the tongue, between the jaw's root and its tip; the glint
## flaring every couple of seconds.
func _place_treasure(_delta: float) -> void:
	if treasure == null: return
	treasure.visible = model.visible and not taken
	if not treasure.visible: return
	# On the tongue near the front of the jaw (round 6: riding the jaw's
	# own frame, so it lies in the mouth when the chin rests on the turf, in
	# reach of a pilot up against the chin).
	treasure.global_position = _probe(_gem_on)
	treasure.scale = Vector3.ONE*size/0.85
	var flare := pow(maxf(sin(_clock*TAU/2.3),0.0),14.0)+0.5*pow(maxf(sin(_clock*TAU/3.7+1.0),0.0),20.0)
	_glint.scale = Vector3.ONE*(1.5+7.0*flare)
	(_glint.material_override as StandardMaterial3D).albedo_color.a = 0.25+0.75*flare
	_treasure_light.light_energy = 1.0+2.0*flare

## The isle's move since the grip was planned (its shudder), as a transform
## to carry grip points along with it.
func _isle_xf() -> Transform3D:
	if gale == null or gale.isle == null or not is_instance_valid(gale.isle): return Transform3D.IDENTITY
	return gale.isle.transform*gale.isle_rest.affine_inverse()

## The isle's built record ({node, shape, ...}), or {}.
func _record(t: Dictionary) -> Dictionary:
	if not find_isle.is_valid(): return {}
	var rec: Variant = find_isle.call(str(t.name))
	return rec if rec is Dictionary else {}

## The rim's lip from the isle's middle along `dir` (flat, unit): the last
## land along it, at the ground there; else the radius at the rim's height.
func _rim_along(t: Dictionary, dir: Vector3) -> Vector3:
	var home: Vector3 = t.home
	var rec := _record(t)
	var shape: RefCounted = rec.get("shape") as RefCounted if rec.has("shape") else null
	if shape == null: return home+dir*float(t.radius)
	var reach := float(shape.get("reach")) if shape.get("reach") != null else float(t.radius)*1.5
	var last := Vector2.INF
	var r := 0.0
	while r <= reach+1.0:
		var p := Vector2(dir.x,dir.z)*r
		if shape.on_land(p): last = p
		elif last != Vector2.INF and r > 2.0: break
		r += 0.5
	if last == Vector2.INF: return home+dir*float(t.radius)
	return home+Vector3(last.x,float(shape.ground_at(last)),last.y)

## Where it will grip target `t`: the side it comes from (`turn`, or a coin
## for it), the rim there, its wrists and feet on the lip either side, where
## its root hangs and which way it faces. Seen from the aqueduct isle's
## turf, it clings on the isle's flank and a little beyond it, so the body
## shows beside the isle and the neck rears over the turf, and the blast
## crosses the view.
func _plan_grip(t: Dictionary, turn := 0.0) -> Dictionary:
	var home: Vector3 = t.home
	var eye := shadow_at if shadow_at != Vector3.INF else home
	var view := Vector3(home.x-eye.x,0.0,home.z-eye.z).normalized()
	if turn == 0.0: turn = 1.5*_clear_side(t,view,eye)
	var out := view.rotated(Vector3.UP,turn)
	var tangent := Vector3(-out.z,0.0,out.x)
	var rim := _rim_along(t,out)
	var right := (-out).cross(Vector3.UP).normalized()
	var wrists := {}
	var feet := {}
	for k in [-1.0,1.0]:
		var w := _rim_along(t,out.rotated(Vector3.UP,0.62*k))
		var f := _rim_along(t,out.rotated(Vector3.UP,0.2*k))
		var n := "R" if (w-rim).dot(right) > 0.0 else "L"
		wrists[n] = w
		feet["R" if (f-rim).dot(right) > 0.0 else "L"] = f
	var root := rim+out*CLING_OUT*size/0.85-Vector3.UP*CLING_DOWN*size/0.85
	return {"target":t,"turn":turn,"rim":rim,"out":out,"tangent":tangent,"side":signf(turn),
		"wrists":wrists,"feet":feet,"root":root,"yaw":atan2(out.x,out.z)}

## Which flank (1 or -1) shows from `eye`: the one whose rim stands
## furthest, as seen, from any nearer isle in front of it.
func _clear_side(t: Dictionary, view: Vector3, eye: Vector3) -> float:
	var home: Vector3 = t.home
	var best := 1.0
	var best_gap := -INF
	for k in [1.0,-1.0]:
		var at := home+view.rotated(Vector3.UP,1.5*k)*(float(t.radius)+10.0)-Vector3.UP*10.0
		var d := at-eye
		var gap := INF
		for isle: Array in isles:
			var p: Vector3 = isle[0]
			if p.distance_to(home) < 1.0: continue
			var to := p-eye
			if to.length() >= d.length() or to.length() < 60.0: continue
			gap = minf(gap,to.angle_to(d)-atan2(float(isle[1])*1.6,to.length()))
		if gap > best_gap:
			best_gap = gap
			best = k
	return best

## Off to attack the next target: in wide and banking round, then low
## outside its rim, where the grab begins.
func _add_attack() -> void:
	var t: Dictionary = targets[_target_i%targets.size()]
	grip = _plan_grip(t)
	var out: Vector3 = grip.out
	var tangent: Vector3 = grip.tangent
	var root: Vector3 = grip.root
	route.append(root+out*240.0+tangent*float(grip.side)*130.0+Vector3.UP*28.0)
	route.append(root+out*95.0+Vector3.UP*6.0)
	_leg_kinds.append("attack")
	_leg_kinds.append("grab")
	_attack_in = INF
	print("sky dragon: off to attack %s, %.0f m from the isle's middle" % [str(t.name),Vector2(root.x-home.x,root.z-home.z).length()])

## The grab begins: from its flight into a hard flare and onto the rim.
func _begin_grab() -> void:
	# The isle may have stood up since the plan: the rim again, same side.
	grip = _plan_grip(grip.target,float(grip.turn))
	var fwd := Vector3(-sin(yaw)*cos(gamma),sin(gamma),-cos(yaw)*cos(gamma))
	_grab = {"p0":pos,"v0":fwd*speed,"yaw0":yaw,"pitch0":gamma*0.75+0.05,"roll0":roll,"t":0.0}
	state = "grabbing"
	route.clear()
	_leg_kinds.clear()
	leg_kind = "grab"

## The grab: a curve from where it was (at its speed) to its hold on the
## rim, arriving slowed but still coming; it pitches up into a flare, the
## wings cupped and beating back hard, the legs swung forward to reach.
func _grabbing(delta: float) -> void:
	_grab.t = float(_grab.t)+delta
	var u := clampf(float(_grab.t)/GRAB,0.0,1.0)
	var p0: Vector3 = _grab.p0
	var p1: Vector3 = grip.root
	var m0: Vector3 = (_grab.v0 as Vector3)*GRAB
	m0 = m0.limit_length(p0.distance_to(p1)*1.25)
	var m1: Vector3 = (-(grip.out as Vector3)*0.5+Vector3.DOWN*0.8).normalized()*14.0
	var u2 := u*u
	var u3 := u2*u
	pos = p0*(2.0*u3-3.0*u2+1.0)+m0*(u3-2.0*u2+u)+p1*(-2.0*u3+3.0*u2)+m1*(u3-u2)
	yaw = lerp_angle(float(_grab.yaw0),float(grip.yaw),smoothstep(0.0,0.8,u))
	var pitch := lerpf(float(_grab.pitch0),CLING_PITCH*0.92,smoothstep(0.15,0.9,u))
	gamma = (pitch-0.05)/0.75
	roll = lerpf(float(_grab.roll0),0.0,smoothstep(0.0,0.6,u))
	_free = 1.0-smoothstep(0.0,0.5,u)
	_flare = smoothstep(0.3,0.75,u)
	mode = "climb"
	# Hard back-beats through the flare.
	flap_w = 1.0
	phase = fposmod(phase+delta*lerpf(BEAT,0.75,_flare),1.0)
	if u >= 1.0: _slam()

## On the rim: it holds on, the isle shudders, dust and stone come off,
## the isle's birds burst out.
func _slam() -> void:
	state = "clinging"
	_snapshot(0.3)
	_free = 0.0
	_flare = 0.0
	var t: Dictionary = grip.target
	var rec := _record(t)
	gale.hold_isle(rec.get("node") as Node3D if rec.has("node") else null,rec.get("shape") as RefCounted if rec.has("shape") else null,t.home,float(t.radius),grip.out,grip.rim)
	gale.slam(grip.rim,grip.out,grip.tangent)
	if flush_birds.is_valid(): flush_birds.call(t.home)
	_c_settle_v = -7.0
	_cling_t = 0.0
	_cling_left = RIDE_HOLD if ride else _rng.randf_range(CLING_HOLD.x,CLING_HOLD.y)
	_set_breath("settle",2.6)
	_c_look_next = 0.0
	_roar_t = -1.0
	print("sky dragon: it grips %s's rim at (%.0f, %.0f, %.0f); lets go in %.0f s" % [str(t.name),(grip.rim as Vector3).x,(grip.rim as Vector3).y,(grip.rim as Vector3).z,_cling_left])

func _set_breath(to: String, length: float) -> void:
	breath = to
	_breath_t = 0.0
	_breath_len = length
	_knocked = false
	if to == "blow":
		_sweep_from = SWEEP if _rng.randf() < 0.5 else -SWEEP
		gale.deepen()

## Holding on: the breath's beats, its pose, the gale and the pilot.
func _clinging(delta: float) -> void:
	_cling_t += delta
	_cling_left -= delta
	_breath_t += delta
	if _breath_t >= _breath_len:
		match breath:
			"settle": _set_breath("pant",_pant_length())
			"pant":
				if _cling_left <= 0.0:
					_let_go()
					return
				_set_breath("inhale",INHALE)
			"inhale": _set_breath("blow",BLOW)
			"blow": _set_breath("recover",RECOVER)
			"recover": _set_breath("pant",_pant_length())
	_cling_pose(delta)
	var mouth := mouth_at()
	var way := blast_way()
	match breath:
		"inhale":
			if _breath_t > 0.3: gale.inhale(mouth,way,delta)
		"blow":
			var env := blow_envelope()
			gale.blow(mouth,way,env,delta)
			if gale.take_crumble(): gale.crumble(grip.rim,grip.out,grip.tangent,14.0)
			_blow_on_pilot(delta,mouth,way,env)
	if breath == "settle" and _breath_t < 1.6 and _rng.randf() < delta*8.0: gale.crumble(grip.rim,grip.out,grip.tangent,12.0)
	_touch_treasure()

func _pant_length() -> float:
	var span := RIDE_PANT if ride else PANT
	return _rng.randf_range(span.x,span.y)

## The blow's strength through its beat: quick in, held, eased out.
func blow_envelope() -> float:
	return smoothstep(0.0,0.35,_breath_t)*(1.0-smoothstep(BLOW-0.7,BLOW,_breath_t))

## The mouth (world): the jaw's tip.
func mouth_at() -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(_bone["jaw.tip"]).origin

## Which way it blows, flat (unit): in across the isle, turned by the
## head's sweep.
func blast_way() -> Vector3:
	if grip.is_empty(): return Vector3.FORWARD
	return (-(grip.out as Vector3)).rotated(Vector3.UP,_c_look.x*float(_sweep_sign)).normalized()

## The pose on the rim. The body hangs nose up with its belly to the cliff,
## heaving as it breathes; the wrists' thumbs and the hind claws are reached
## to the lip (a little IK each frame); the neck rears over the turf and
## turns, looking round, drawing back on the inhale and thrusting and
## sweeping on the blow; the mouth pants open, the tail hangs under the keel.
func _cling_pose(delta: float) -> void:
	var xf := _isle_xf()
	var out: Vector3 = grip.out
	var u := _breath_t/maxf(_breath_len,0.01)
	var rear_goal := 0.0
	var jaw := 0.0
	var wing_open := 0.2
	var yaw_goal := 0.0
	var pant := 0.0
	match breath:
		"settle":
			jaw = 0.42*sin(PI*clampf(_breath_t/1.6,0.0,1.0))
			rear_goal = 0.5*sin(PI*clampf(_breath_t/2.0,0.0,1.0))
			wing_open = lerpf(0.75,0.2,smoothstep(0.0,1.0,u))
		"pant":
			pant = 1.0
			jaw = 0.26+0.07*sin(_clock*TAU*1.4)
			rear_goal = -0.15
		"inhale":
			jaw = lerpf(0.2,0.42,smoothstep(0.0,1.0,u))
			rear_goal = smoothstep(0.0,0.8,u)
			wing_open = lerpf(0.2,0.5,u)
		"blow":
			var env := blow_envelope()
			jaw = lerpf(0.42,0.66,smoothstep(0.0,0.15,_breath_t))+0.02*sin(_clock*29.0)
			rear_goal = lerpf(1.0,-0.8,smoothstep(0.0,0.3,_breath_t))
			wing_open = 0.5+0.25*env
			yaw_goal = lerpf(_sweep_from,-_sweep_from,smoothstep(0.1,0.9,u))
		"recover":
			jaw = lerpf(0.5,0.28,u)
			rear_goal = lerpf(-0.8,-0.15,smoothstep(0.0,1.0,u))
			wing_open = lerpf(0.75,0.2,u)
	# Looking round between blasts: a new glance every couple of seconds.
	if breath in ["pant","settle","recover"]:
		_c_look_next -= delta
		if _c_look_next <= 0.0:
			_c_look_next = _rng.randf_range(1.4,3.2)
			_c_look_goal = Vector2(_rng.randf_range(-0.6,0.6),_rng.randf_range(-0.2,0.25))
		yaw_goal = _c_look_goal.x
	_c_look_v += ((Vector2(yaw_goal,_c_look_goal.y*(1.0 if pant > 0.0 else 0.0))-_c_look)*(14.0 if breath == "blow" else 5.0)-_c_look_v*(5.5 if breath == "blow" else 3.4))*delta
	_c_look += _c_look_v*delta
	_c_rear_v += ((rear_goal-_c_rear)*12.0-_c_rear_v*5.0)*delta
	_c_rear += _c_rear_v*delta
	_c_settle_v += (-_c_settle*16.0-_c_settle_v*3.0)*delta
	_c_settle += _c_settle_v*delta
	_jaw_goal = jaw
	# The body.
	var heave := sin(_clock*TAU*(0.6 if pant > 0.0 else 0.22))
	var pitch := CLING_PITCH+_c_rear*0.1+0.02*heave
	var basis := Basis(Vector3.UP,float(grip.yaw))*Basis(Vector3.RIGHT,pitch)*Basis(Vector3.BACK,0.03*sin(_clock*0.37))
	pos = xf*(grip.root as Vector3)+Vector3.UP*_c_settle+out*(_c_rear*0.9)
	global_transform = Transform3D(basis,pos)
	yaw = float(grip.yaw)
	if _bone.has("chest"): skeleton.set_bone_pose_scale(_bone["chest"],Vector3(1.0+0.05*heave*(0.4+pant),1.0,1.0+0.06*heave*(0.4+pant)))
	_turn("chest",[[Vector3.RIGHT,-0.04*_c_rear]])
	_turn("hips",[[Vector3.RIGHT,0.1]])
	_turn("spine.2",[[Vector3.RIGHT,-0.1]])
	var sk_inv := skeleton.global_transform.affine_inverse()
	for side in [-1.0,1.0]:
		var n := "L" if side < 0.0 else "R"
		var fold := 1.0-wing_open
		_turn("wing_arm."+n,[[Vector3.BACK,-side*0.5],[Vector3.UP,side*0.3]])
		_turn("wing_fore."+n,[[Vector3.UP,side*fold*0.9]])
		_turn("wing_hand."+n,[[Vector3.UP,-side*fold*1.6],[Vector3.BACK,-side*0.25]])
		_turn("wing_f1."+n,[[Vector3.BACK,side*0.1]])
		_turn("wing_f1b."+n,[[Vector3.BACK,side*0.15]])
		_turn("wing_f2."+n,[[Vector3.UP,side*fold*0.2]])
		_turn("wing_f3."+n,[[Vector3.UP,side*fold*0.4]])
		_turn("wing_f4."+n,[[Vector3.UP,side*fold*0.6]])
		var wrist: Vector3 = xf*(grip.wrists[n] as Vector3)+Vector3.UP*0.8*size-out*1.2*size
		_reach(["wing_arm."+n,"wing_fore."+n],"wing_hand."+n,sk_inv*wrist)
		_seat_thumb(n,wrist,xf*(grip.wrists[n] as Vector3)-out*THUMB_IN,sk_inv)
		_turn("hind_upper."+n,[[Vector3.RIGHT,0.5]])
		_turn("hind_lower."+n,[[Vector3.RIGHT,-0.3]])
		_turn("hind_foot."+n,[[Vector3.RIGHT,0.9]])
		var foot: Vector3 = xf*(grip.feet[n] as Vector3)-Vector3.UP*1.0*size+out*0.4*size
		_reach(["hind_upper."+n,"hind_lower."+n],"hind_foot."+n,sk_inv*foot)
	# The neck: bent forward to carry the head out level over the turf
	# (the body's pitch undone), turned round its own root to look and
	# sweep, drawn back and up on the inhale, thrust on the blow. Between
	# blasts (round 6) the chin comes down to rest on the turf and the
	# glances shrink to small turns of the head where it lies.
	var rest_goal := 1.0 if breath == "pant" or (breath == "settle" and _breath_t > 1.2) or (breath == "recover" and u > 0.35) else 0.0
	_rest_w = move_toward(_rest_w,rest_goal,delta*(1.6 if rest_goal > _rest_w else 3.2))
	_neck_look = Vector2(_c_look.x*(1.0-0.75*_rest_w),_c_look.y*(1.0-_rest_w))
	# Resting, it pants with the mouth a little open: the head bobbing up
	# off the jaw that lies on the turf.
	if breath == "pant": _jaw_goal = lerpf(_jaw_goal,0.15+0.07*sin(_clock*TAU*1.4),_rest_w)
	_pose_neck()
	_mouth(delta)
	_rest_head()
	_tail(delta)

## The neck and head as `_cling_pose` sets them.
func _pose_neck() -> void:
	var look_yaw := _neck_look.x
	var look_pitch := _neck_look.y
	var bends := [0.0,-0.3,-0.34,-0.24]
	for i in range(_neck_n):
		var b: float = bends[mini(i,bends.size()-1)]
		var u_n := float(i)/maxf(_neck_n-1,1)
		var rear := _c_rear*lerpf(0.32,-0.1,u_n)
		var wave := 0.03*sin(_clock*0.9-float(i)*0.6)
		_turn("neck.%d" % i,[[Vector3.FORWARD,look_yaw*lerpf(0.4,0.1,u_n)],[Vector3.RIGHT,b+rear+wave]])
	_turn("head",[[Vector3.RIGHT,-0.12+look_pitch+_c_rear*0.25],[Vector3.UP,look_yaw*0.35]])

## The neck's and head's turns now, to bend from (`_bend_neck`).
func _keep_neck() -> void:
	_neck_base.clear()
	for i in range(_neck_n): _neck_base.append(skeleton.get_bone_pose_rotation(_bone["neck.%d" % i]))
	_neck_base.append(skeleton.get_bone_pose_rotation(_bone["head"]))

## The kept neck lowered `lift` (radians about each bone's own right, its
## LIFT_SHARE on each) and the head nodded `nod` more.
func _bend_neck(lift: float, nod: float) -> void:
	for i in range(_neck_n+1):
		var b := "neck.%d" % i if i < _neck_n else "head"
		var angle: float = nod if i == _neck_n else lift*float(LIFT_SHARE[mini(i,LIFT_SHARE.size()-1)])
		var axis := ((_rest_global[b] as Basis).inverse()*Vector3.RIGHT).normalized()
		skeleton.set_bone_pose_rotation(_bone[b],(_neck_base[i] as Quaternion)*Quaternion(axis,angle))

## The chin's two probes over the turf (m, less CHIN_GAP) bent `lift` and
## `nod`, over turf heights `back` and `front`.
func _chin_error(lift: float, nod: float, back: float, front: float) -> Vector2:
	_bend_neck(lift,nod)
	return Vector2(_probe(_chin_back).y-back-CHIN_GAP,_probe(_chin_front).y-front-CHIN_GAP)

## The chin laid on the isle while it rests (round 6, `_rest_w`): the lift
## and nod that lay the jaw's floor flush on the turf, back and front (a
## few Newton steps a frame from last frame's, so it follows the isle's
## groan), blended in by `_rest_w`. The jaw's own opening is on top, so it
## lies still and the head lifts off it to pant.
func _rest_head() -> void:
	if _chin_back.is_empty() or _chin_front.is_empty() or not is_inside_tree() or _rest_w <= 0.001: return
	var space := get_world_3d().direct_space_state
	_keep_neck()
	var lift := _rest_lift
	var nod := _rest_nod
	_bend_neck(lift,nod)
	var back := _turf_y(space,_probe(_chin_back),TURF_LAYER)
	var front := _turf_y(space,_probe(_chin_front),TURF_LAYER)
	if is_finite(back) and is_finite(front):
		for k in range(3):
			var e := _chin_error(lift,nod,back,front)
			if e.length() < 0.01: break
			var a := (_chin_error(lift+0.02,nod,back,front)-e)/0.02
			var b := (_chin_error(lift,nod+0.02,back,front)-e)/0.02
			var det := a.x*b.y-b.x*a.y
			if absf(det) < 1e-3: break
			lift = clampf(lift+clampf((-e.x*b.y+b.x*e.y)/det,-0.3,0.3),-1.8,1.4)
			nod = clampf(nod+clampf((-a.x*e.y+a.y*e.x)/det,-0.3,0.3),-1.4,1.4)
		_rest_lift = lift
		_rest_nod = nod
		chin_miss = _chin_error(lift,nod,back,front)
	_bend_neck(_rest_lift*_rest_w,_rest_nod*_rest_w)

## No probe under the isle's turf as it stands now (after the blend and the
## isle's move this frame): the deepest one lifted clear by the neck or the
## nod, whichever moves it more, a few times. On the rim, the grab and the
## let-go alike.
func _clear_turf() -> void:
	if _chin_back.is_empty() or not is_inside_tree() or gale == null or gale.isle == null: return
	var space := get_world_3d().direct_space_state
	_keep_neck()
	var probes: Array = _probes_head+_probes_neck
	var under: Array = []
	for i in range(probes.size()):
		var p := _probe(probes[i])
		var top := _turf_y(space,p,TURF_LAYER if i < _probes_head.size() else TURF_LAYER|SOLID_LAYER)
		# The neck's root hangs beside the cliff, under the lip's overhang:
		# only a neck probe near the top is in it.
		if i >= _probes_head.size() and p.y < top-NECK_DEEP: top = -INF
		under.append(top)
	var lift := 0.0
	var nod := 0.0
	for k in range(6):
		var worst := 0.0
		var worst_i := -1
		for i in range(probes.size()):
			if not is_finite(float(under[i])): continue
			var gap := _probe(probes[i]).y-float(under[i])
			if gap < worst:
				worst = gap
				worst_i = i
		if k == 0: sunk_before = minf(sunk_before,worst)
		if worst_i < 0: break
		_bend_neck(lift+0.03,nod)
		var dl := (_probe(probes[worst_i]).y-float(under[worst_i])-worst)/0.03
		_bend_neck(lift,nod+0.03)
		var dn := (_probe(probes[worst_i]).y-float(under[worst_i])-worst)/0.03
		var need := -worst+0.03
		if absf(dl) >= absf(dn) and absf(dl) > 0.05: lift += clampf(need/dl,-0.4,0.4)
		elif absf(dn) > 0.05: nod += clampf(need/dn,-0.4,0.4)
		else:
			_bend_neck(lift,nod)
			break
		_bend_neck(lift,nod)
	var left := 0.0
	for i in range(probes.size()):
		if is_finite(float(under[i])): left = minf(left,_probe(probes[i]).y-float(under[i]))
	if left < -0.02:
		# Still in it (the isle springing up under the neck as it lets go):
		# the whole body bumped up clear.
		pos += Vector3.UP*(-left+0.03)
		global_position = pos
		left = 0.0
	sunk_after = minf(sunk_after,left)

## The chin's collider on the jaw while it clings (`on`), else out of the
## world's way.
func _place_chin(on: bool) -> void:
	if chin == null: return
	if not on or _chin_box.is_empty():
		if chin.collision_layer != 0: chin.collision_layer = 0
		return
	var i: int = _chin_box[0]
	var bone := skeleton.get_bone_global_pose(i)*skeleton.get_bone_global_rest(i).affine_inverse()
	var basis := (skeleton.global_transform.basis*bone.basis).orthonormalized()
	chin.global_transform = Transform3D(basis,_probe(_chin_box))
	chin.collision_layer = SOLID_LAYER

## The thumb's claw onto the turf just inside the lip (`seat`, world): the
## wrist's reach moved by the claw's miss, twice; then the claw's tip, its
## middle and the wrist kept over the top.
func _seat_thumb(n: String, wrist: Vector3, seat: Vector3, sk_inv: Transform3D) -> void:
	if not _thumb.has(n) or (_thumb[n][0] as Array).is_empty() or not is_inside_tree(): return
	var space := get_world_3d().direct_space_state
	var top := _turf_y(space,seat,TURF_LAYER)
	if not is_finite(top): return
	seat.y = top+0.05
	var chain := ["wing_arm."+n,"wing_fore."+n]
	for k in range(2):
		wrist += seat-_probe(_thumb[n][0])
		_reach(chain,"wing_hand."+n,sk_inv*wrist)
	for k in range(2):
		var sunk := 0.0
		for pr: Array in _thumb[n]:
			var p := _probe(pr)
			var g := _turf_y(space,p,TURF_LAYER)
			if is_finite(g): sunk = minf(sunk,p.y-g)
		if sunk >= -0.02: break
		wrist += Vector3.UP*(-sunk+0.05)
		_reach(chain,"wing_hand."+n,sk_inv*wrist)

## A little reaching IK (cyclic coordinate descent): turns `chain`'s bones
## (root first) so `end`'s origin comes to `target` (skeleton space).
func _reach(chain: Array, end: String, target: Vector3) -> void:
	if not _bone.has(end): return
	for k in range(4):
		for j in range(chain.size()-1,-1,-1):
			var b: String = chain[j]
			if not _bone.has(b): continue
			var bi: int = _bone[b]
			var bg := skeleton.get_bone_global_pose(bi)
			var e := skeleton.get_bone_global_pose(_bone[end]).origin
			var to_e := e-bg.origin
			var to_t := target-bg.origin
			if to_e.length() < 0.01 or to_t.length() < 0.01: continue
			var axis := to_e.cross(to_t)
			if axis.length() < 0.00001: continue
			var angle := minf(to_e.angle_to(to_t),0.7)
			var new_g := Basis(axis.normalized(),angle)*bg.basis
			var parent := skeleton.get_bone_parent(bi)
			var pg := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
			skeleton.set_bone_pose_rotation(bi,(pg.inverse()*new_g).get_rotation_quaternion())

## Lets go: it pushes off and drops back from the rim on a heavy beat,
## turning out, and the isle springs back.
func _let_go() -> void:
	state = "leaving"
	_place_chin(false)
	_rest_w = 0.0
	_tilt_slide(false)
	_snapshot(0.6)
	gale.release_isle()
	for i in range(14): gale.crumble(grip.rim,grip.out,grip.tangent,14.0)
	_jaw_goal = -1.0
	breath = ""
	_grab = {"t":0.0,"p0":pos,"yaw0":float(grip.yaw)}
	flap_w = 1.0
	phase = 0.55
	_bout = true
	print("sky dragon: it lets go of %s" % str(grip.target.name))

const LEAVE := 3.2

func _leaving(delta: float) -> void:
	_grab.t = float(_grab.t)+delta
	var t := float(_grab.t)
	var u := clampf(t/LEAVE,0.0,1.0)
	var out: Vector3 = grip.out
	pos = (_grab.p0 as Vector3)+out*(6.0*t+2.2*t*t)+Vector3.DOWN*(2.6*t*t)
	yaw = lerp_angle(float(_grab.yaw0),float(_grab.yaw0)+PI*float(grip.side),smoothstep(0.15,0.95,u))
	var pitch := lerpf(CLING_PITCH*0.9,-0.25,smoothstep(0.0,0.85,u))
	gamma = (pitch-0.05)/0.75
	roll = 0.5*float(grip.side)*sin(PI*u)
	_free = smoothstep(0.5,1.0,u)
	# One heavy beat, then gliding off.
	flap_w = 1.0-smoothstep(0.7,1.0,u)
	phase = fposmod(phase+delta*0.42,1.0)
	mode = "cruise"
	if u >= 1.0:
		state = "roaming"
		yaw = atan2(-out.x,-out.z)
		gamma = -0.25
		speed = 26.0
		_free = 1.0
		route.clear()
		_leg_kinds.clear()
		if ride and not grip.is_empty():
			# --dragon-ride: round again and back onto the rim.
			_begin_grab()
			return
		_add_circuit()
		_target_i = (_target_i+1)%maxi(targets.size(),1)
		_attack_in = _attack_every*_rng.randf_range(0.85,1.2)
		grip = {}

## Remembers every bone's turn now, to blend from it over `length` s.
func _snapshot(length: float) -> void:
	_blend_from.clear()
	for b: String in _bone:
		var i: int = _bone[b]
		_blend_from[i] = skeleton.get_bone_pose_rotation(i)
	_blend_t = 0.0
	_blend_len = length

func _blend(delta: float) -> void:
	if _blend_from.is_empty(): return
	_blend_t += delta
	var w := smoothstep(0.0,1.0,_blend_t/maxf(_blend_len,0.01))
	if w >= 1.0:
		_blend_from.clear()
		return
	for i: int in _blend_from:
		var now := skeleton.get_bone_pose_rotation(i)
		skeleton.set_bone_pose_rotation(i,(_blend_from[i] as Quaternion).slerp(now,w))

## The blow on a pilot on the isle (round 1's): in the cone's core and in
## the open, knocked into a tumble; in the wider band, pushed along; behind
## stone, nothing.
func _blow_on_pilot(delta: float, mouth: Vector3, way: Vector3, env: float) -> void:
	if walker == null or not on_foot or env <= 0.05: return
	if walker.has_method("recovering") and walker.recovering(): return
	var mid: Vector3 = (walker.get("feet") as Vector3)+Vector3.UP*0.6
	var off := mid-mouth
	var flat := Vector2(off.x,off.z)
	var dist := flat.length()
	if dist > REACH or dist < 0.5 or absf(off.y) > 30.0: return
	var w2 := Vector2(way.x,way.z)
	var angle := absf(w2.angle_to(flat))
	if angle > PUSH_CONE: return
	var space := get_world_3d().direct_space_state
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(mouth,mid,1,[chin.get_rid()] if chin != null else [])).is_empty(): return
	var away := (flat.normalized()*0.5+w2*0.5).normalized()
	if angle <= CONE and env > 0.5 and not _knocked:
		walker.knock(walker.knock_velocity(away,lerpf(KNOCK_OUT.x,KNOCK_OUT.y,dist/REACH),KNOCK_UP))
		_knocked = true
		print("sky dragon: the gale knocks the pilot, %.1f m from the mouth" % dist)
		return
	if slide.is_valid() and bool(walker.get("grounded")):
		var push := away*PUSH*env*(1.0-dist/REACH*0.5)*delta
		var feet: Vector3 = walker.get("feet")
		var moved: Vector3 = slide.call(feet,push)
		walker.set("feet",Vector3(moved.x,feet.y,moved.z))

## The isle under the pilot (round 5): standing on it while it sags, holds
## and snaps, he is carried with it (PilotMotor.carry, as a moving body
## carries him); as it snaps back he is flung off it into a tumble the
## moment it slows harder than he falls, at its speed where he stands, so
## hardest by the gripped rim. And the snap's jolt: stone, dust and leaves
## jump loose.
func _ride_isle(delta: float) -> void:
	if gale.snapped and not grip.is_empty(): gale.jolt(_isle_xf()*(grip.rim as Vector3),grip.out,grip.tangent,-gale.sag_v)
	if walker == null or not on_foot or gale.isle == null or delta <= 0.0:
		_tilt_slide(false)
		return
	_tilt_slide(gale.phase == "held" and gale.tip() > TILT_SLIDE and bool(walker.get("grounded")) and gale.stands_on(walker.get("feet") as Vector3,1.5) and _falls_to_dragon())
	if gale.moved.is_equal_approx(Transform3D.IDENTITY):
		_ride_vy = 0.0
		return
	var feet: Vector3 = walker.get("feet")
	var vel: Vector3 = walker.get("velocity")
	if not gale.stands_on(feet) or (not bool(walker.get("grounded")) and vel.y > 0.5):
		_ride_vy = 0.0
		return
	var moved_by: Transform3D = gale.moved
	var now := moved_by*feet
	walker.carry(moved_by,0.0)
	var v := (now-feet)/delta
	var accel := (v.y-_ride_vy)/delta
	_ride_vy = v.y
	if gale.phase != "snap" or v.y < 3.0 or accel > -float(walker.get("gravity")): return
	var up := minf(v.y*LAUNCH_GAIN,LAUNCH_MOST)
	var inward := -(grip.out as Vector3)*up*LAUNCH_IN if not grip.is_empty() else Vector3.ZERO
	walker.knock(Vector3(v.x+inward.x,up,v.z+inward.z))
	_ride_vy = 0.0
	launched += 1
	var rim_at: Vector3 = grip.rim if not grip.is_empty() else feet
	print("sky dragon: the isle springs back and flings the pilot up at %.1f m/s, %.1f m from the rim it held" % [up,Vector2(feet.x-rim_at.x,feet.z-rim_at.z).length()])

## The tipped isle as a slope he can't stand on (round 6): while it is held
## tipped and he stands on it, the motor's slide_auto is lowered to
## RIDE_SLIDE_AUTO, so its steeper turf surfs him down toward the dragon on
## his own (crouched he surfs from the motor's SLIDE_FROM, 10°, as on any
## slope); off it, or let go, his own again.
func _tilt_slide(on: bool) -> void:
	if walker == null: return
	if on:
		if _auto_was < 0.0: _auto_was = float(walker.get("slide_auto"))
		walker.set("slide_auto",RIDE_SLIDE_AUTO)
	elif _auto_was >= 0.0:
		walker.set("slide_auto",_auto_was)
		_auto_was = -1.0

## Whether the slope under the pilot falls toward the gripped rim (within
## about 60°): only there does the tipped isle surf him on his own, so it
## pours him toward the dragon, not off its other flanks.
func _falls_to_dragon() -> bool:
	if grip.is_empty(): return false
	var slope: Vector2 = walker.get("slope")
	if slope.length() < 0.05: return false
	var feet: Vector3 = walker.get("feet")
	var rim := _isle_xf()*(grip.rim as Vector3)
	var to := Vector2(rim.x-feet.x,rim.z-feet.z)
	if to.length() < 0.5: return true
	return (-slope).normalized().dot(to.normalized()) > 0.5

## The treasure taken from its tongue: a roar, and it lets go.
func _touch_treasure() -> void:
	if taken or walker == null or not on_foot or treasure == null: return
	var mid: Vector3 = (walker.get("feet") as Vector3)+Vector3.UP*0.6
	if mid.distance_to(treasure.global_position) > TAKE_R: return
	taken = true
	treasure.visible = false
	print("sky dragon: the treasure is taken; it roars and lets go")
	yielded.emit()
	_let_go()
	_roar_t = 0.0

# --- The watch camera ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_G and state == "clinging":
		_say("It lets go")
		_let_go()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_V:
		var order := ["","chase","orbit","look"]
		watch = order[(order.find(watch)+1)%order.size()]
		if watch == "" and _fov > 0.0 and camera != null: camera.fov = _fov
		_watch_fresh = true
		_say("Dragon camera: %s" % (watch if watch != "" else "off"))
		get_viewport().set_input_as_handled()

func _say(text: String) -> void:
	if _toast == null:
		var layer := CanvasLayer.new()
		layer.layer = 7
		add_child(layer)
		_toast = Label.new()
		_toast.position = Vector2(24,24)
		_toast.add_theme_font_size_override("font_size",20)
		_toast.add_theme_color_override("font_shadow_color",Color(0,0,0,0.6))
		layer.add_child(_toast)
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_toast,"modulate:a",0.0,0.8)

## The camera on the dragon while watching: behind and above it (chase), a
## slow orbit round it, or looking at it from where the camera was.
func _watch_camera(delta: float) -> void:
	if watch == "" or camera == null or state == "waiting": return
	var at := global_position
	var fwd := Vector3(-sin(yaw),0.0,-cos(yaw))
	var eye := Vector3.ZERO
	var aim := at
	match watch:
		"chase":
			eye = at-fwd*100.0+Vector3.UP*28.0
			aim = at+fwd*25.0+Vector3.UP*2.0
		"orbit":
			_orbit += delta*0.18
			var a := _orbit
			if _orbit_fixed != INF: a = -yaw-PI*0.5+_orbit_fixed
			eye = at+Vector3(cos(a),0.0,sin(a))*_orbit_far+Vector3.UP*_orbit_up
			aim = at
		"look":
			if _watch_fresh: _watch_from = camera.global_position
			eye = _watch_from
			aim = at
		_: return
	# On a rim: framed on the isle and the dragon on it, out to the side so
	# the neck over the turf, the hanging tail and the blast across all show.
	var on_rim := not grip.is_empty() and (state == "clinging" or (state == "grabbing" and float(_grab.get("t",0.0)) > GRAB*0.4))
	if on_rim:
		var rim: Vector3 = _isle_xf()*(grip.rim as Vector3)
		var out: Vector3 = grip.out
		var tangent: Vector3 = grip.tangent
		match watch:
			"chase":
				eye = rim+out*72.0+tangent*float(grip.side)*62.0+Vector3.UP*26.0
				aim = rim+Vector3.UP*4.0-out*6.0
			"orbit":
				var a := _orbit
				if _orbit_fixed != INF: a = atan2(out.z,out.x)+_orbit_fixed
				eye = rim+Vector3(cos(a),0.0,sin(a))*_orbit_far+Vector3.UP*_orbit_up
				aim = rim+Vector3.UP*2.0
			"look":
				aim = rim+Vector3.UP*8.0
	if _watch_fresh:
		if _fov < 0.0: _fov = camera.fov
		_watch_eye = eye
		_watch_look = aim
		_watch_fresh = false
	var k := 1.0-exp(-delta*(2.5 if watch == "chase" else 4.0))
	_watch_eye = _watch_eye.lerp(eye,k)
	_watch_look = _watch_look.lerp(aim,1.0-exp(-delta*6.0))
	if watch == "look" or _orbit_fixed != INF: _watch_eye = eye
	camera.global_position = _watch_eye
	camera.look_at(_watch_look,Vector3.UP)
	camera.fov = 55.0 if watch != "look" else 40.0
