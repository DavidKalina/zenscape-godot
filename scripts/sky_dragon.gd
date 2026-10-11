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
## No combat, no gusts (the rim grip is parked: scripts/rim_dragon.gd,
## --dragon-rim).
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
## route's dice; --dragon-size=<x> (0.85) its scale.

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
	_build()
	_start()
	print("sky dragon: look %s (%s), rises in %.1f s" % [look,LOOK_NAMES[look],delay])

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
		state = "roaming" if _pass_now else "rising"
		model.visible = true
		_t = 0.0
	if _hold: _held(delta)
	else: _fly(delta)
	_ride_air(delta)
	_pose(delta)
	if _log:
		_log_t += delta
		if _log_t >= (0.5 if leg_kind == "low pass" else 2.0):
			_log_t = 0.0
			print("sky dragon: t %.0f %s %s leg %s at (%.0f, %.0f, %.0f) %.1f m/s gamma %.2f roll %.2f flap %.2f, %.0f m from the isle's middle" % [_clock,state,mode,leg_kind,pos.x,pos.y,pos.z,speed,gamma,roll,flap_w,Vector2(pos.x-home.x,pos.z-home.z).length()])

func _fly(delta: float) -> void:
	if route.is_empty(): _next_legs()
	var target: Vector3 = route[0]
	leg_kind = _leg_kinds[0]
	var to := target-pos
	var flat := Vector2(to.x,to.z)
	var dist := flat.length()
	# A low pass is flown right through its points, so it really is low.
	var arrive := 30.0 if state == "rising" else (40.0 if leg_kind == "low pass" else ARRIVE)
	var behind := Vector2(-sin(yaw),-cos(yaw)).dot(flat.normalized()) < -0.2
	var reached := pos.y > target.y-10.0 if state == "rising" else (dist < arrive or (behind and dist < (90.0 if leg_kind == "low pass" else 220.0)))
	if reached:
		route.pop_front()
		_leg_kinds.pop_front()
		if state == "rising": state = "roaming"
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
	# The tips lag the beat: they bend against the raise's speed.
	var rv := (raise-_last_raise)/maxf(delta,0.001)
	_last_raise = raise
	_tip_lag = lerpf(_tip_lag,clampf(-rv*0.16,-0.5,0.5),1.0-exp(-delta*10.0))
	# Gliding: the wings trim against the air, each on its own: the raise
	# answers the air's roll (the low wing lifts), the hands twist with the
	# swell, the tips flex on a bump.
	var still := 1.0-flap_w
	var air_roll := _air_roll+_bump.x
	_trim = Vector2(0.05*sin(_clock*0.71)+0.03*sin(_clock*1.9),0.05*sin(_clock*0.63+1.7)+0.03*sin(_clock*2.3))*still
	var twist := (_swell*0.02+0.06*sin(_clock*0.9))*still
	# The body: bobbing against each beat, nodding with it, rolled and
	# pitched by the air.
	var bob := -BOB*cos(TAU*phase)*flap_w*(1.3 if mode == "climb" else 1.0)
	var nod := 0.04*sin(TAU*phase)*flap_w
	var pitch := gamma*0.75+0.05+nod+_air_pitch+_bump.y
	var body_roll := roll+air_roll
	var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)*Basis(Vector3.BACK,body_roll)
	global_transform = Transform3D(basis,pos+basis.y*bob*size+Vector3.UP*_swell_y)
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
		_turn("hind_upper."+n,[[Vector3.RIGHT,-1.5-swing]])
		_turn("hind_lower."+n,[[Vector3.RIGHT,0.9]])
		_turn("hind_foot."+n,[[Vector3.RIGHT,-0.7]])
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
	if _roar_t < 0.0 and _hold_pose != "roar":
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
	else:
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

# --- The watch camera ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
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
