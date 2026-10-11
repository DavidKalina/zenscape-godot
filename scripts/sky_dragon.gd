extends Node3D
## The sky dragon (docs/design/rim-dragon.md, round 2): an experiment. A
## full-bodied dragon (assets/models/rim_dragon_<a|b|c>.glb, built by
## art/blender/rim_dragon/dragon_body_build.py) rises out of the cloud sea
## and roams the archipelago round the isle: big circuits, threading
## between isles, climbs, dives and now and then a low pass over the isle
## you stand on. Everything is posed procedurally on its rig each frame:
##   - wingbeats with weight: a fast, powerful downstroke with the tips
##     lagging, the wings folding at the wrist on the upstroke, the body
##     bobbing against each beat; bouts of beats between long glides on
##     spread, still wings with small trims;
##   - turns banked, the neck and head leading into them, the tail a
##     dragged rope (verlet points) so it trails the curve and swings late;
##   - climbs on heavy, quicker beats; dives with the wings half tucked;
##   - the head turning to look at the camera when it passes close.
## No combat, no gusts (the rim grip is parked: scripts/rim_dragon.gd,
## --dragon-rim).
##
## Self-contained: the host (studies/aqueduct_isle.gd) makes one, calls
## `setup` and then `advance` every frame after its own camera is placed.
## V cycles a watch camera on it (chase, orbit, look from where you stand,
## off), which takes the host's camera over while on.
##
## Flags: --dragon-look=a|b|c (b) the dress; --dragon-delay=<s> (3) before
## it rises; --dragon-skip=<s> runs it on that far at the start;
## --dragon-watch[=chase|orbit|look] starts watching; --dragon-seed=<n> its
## route's dice.

const MODELS := {
	"a": "res://assets/models/rim_dragon_a.glb",
	"b": "res://assets/models/rim_dragon_b.glb",
	"c": "res://assets/models/rim_dragon_c.glb",
}
const LOOK_NAMES := {"a":"angular","b":"carved","c":"stone and glow"}

## Flight (m, s, rad). Cruise between FLAP_BELOW and GLIDE_ABOVE: beats
## when slower, glides when faster.
const MAX_TURN := 0.30
const MAX_BANK := 0.85
const MAX_CLIMB := 0.42
const MAX_DIVE := 0.6
const FLAP_BELOW := 21.0
const GLIDE_ABOVE := 25.0
const MIN_SPEED := 15.0
const MAX_SPEED := 40.0
const THRUST := 2.2
const DRAG := 0.0006
const ARRIVE := 95.0
## Beats a second, cruising and climbing; the downstroke's share of a beat.
const BEAT := 0.27
const BEAT_CLIMB := 0.36
const DOWN := 0.5
## The wing's raise at the top and bottom of a beat, and gliding (rad).
const RAISE_UP := 1.1
const RAISE_DOWN := -0.78
const RAISE_GLIDE := 0.1
## The body's bob against a beat (m).
const BOB := 2.0

var camera: Camera3D
var sea_y := -120.0
var home := Vector3.ZERO
var home_top := 30.0
var isles: Array = []
var look := "b"
var delay := 3.0
var _skip := 0.0
var _rng := RandomNumberGenerator.new()

var model: Node3D
var skeleton: Skeleton3D
var _bone := {}
var _rest_local := {}
var _rest_global := {}

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
var speed := 18.0
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
## The neck's lead into a turn (a spring), the head's look (yaw, pitch
## springs), the jaw.
var _lead := 0.0
var _lead_v := 0.0
var _look := Vector2.ZERO
var _look_v := Vector2.ZERO
var _jaw := 0.0
var _jaw_next := 8.0
var _jaw_left := 0.0
var _trim := Vector2.ZERO
## The tail's rope (world points from the hips to the tip), last frame's,
## each segment's length and rest direction (model space).
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
## --dragon-pose=glide|dive; --dragon-orbit=<deg> fixes the orbit's angle
## from its nose (90 its right side).
var _hold := false
var _hold_phase := -1.0
var _hold_pose := ""
var _orbit_fixed := INF
var _watch_fresh := true
var _toast: Label
var _fov := -1.0
## --dragon-log: a line every 2 s (where, what it is doing).
var _log := false
var _log_t := 0.0

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
		elif arg == "--dragon-log": _log = true
		elif arg == "--dragon-hold": _hold = true
		elif arg.begins_with("--dragon-phase="): _hold_phase = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-pose="): _hold_pose = arg.get_slice("=",1)
		elif arg.begins_with("--dragon-orbit="): _orbit_fixed = deg_to_rad(float(arg.get_slice("=",1)))
		elif arg == "--dragon-watch": watch = "chase"
		elif arg.begins_with("--dragon-watch="): watch = arg.get_slice("=",1)
	if not MODELS.has(look):
		push_warning("sky dragon: no look '%s' (a, b, c); b instead" % look)
		look = "b"
	_build()
	_start()
	print("sky dragon: look %s (%s), rises in %.1f s" % [look,LOOK_NAMES[look],delay])

# --- Building ---------------------------------------------------------------------

func _build() -> void:
	model = (load(MODELS[look]) as PackedScene).instantiate()
	add_child(model)
	skeleton = _find_skeleton(model)
	for i in range(skeleton.get_bone_count()):
		var b := skeleton.get_bone_name(i)
		_bone[b] = i
		_rest_local[b] = skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		_rest_global[b] = skeleton.get_bone_global_rest(i).basis.orthonormalized()
	_dress(model)
	model.visible = false
	# The tail's rest: the hips' end to the tip, in the model's frame.
	var pts: Array = []
	for i in range(6): pts.append(skeleton.get_bone_global_rest(_bone["tail.%d" % i]).origin)
	pts.append(pts[5]+(pts[5]-pts[4])*0.9)
	_tail_start = pts[0]
	for i in range(6):
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
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# The wings reach far from the rest pose's bounds.
		mi.extra_cull_margin = 40.0
	for c in n.get_children(): _dress(c)

## The game's materials, by the model's names: a dark basalt-violet hide
## (satin in a and b, matte stone in c), ivory teeth, pale horn and claws,
## violet membranes (c: soft and glowing toward the trailing edge).
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
		"dragon_gum":
			m.albedo_color = Color("8a2833")
		"dragon_tongue":
			m.albedo_color = Color("a6404a")
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
uniform vec3 edge : source_color = vec3(0.5, 0.33, 0.64);
uniform vec3 glow : source_color = vec3(1.0, 0.62, 0.78);
uniform float glow_energy = 0.7;
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
	speed = 19.0
	state = "waiting"
	route = [Vector3(pos.x-out.x*25.0,sea_y+125.0,pos.z-out.z*25.0)]
	_leg_kinds = ["rise"]
	leg_kind = "rise"
	# Then straight into a low pass, so it is seen soon.
	_add_low_pass()

func _isle_pos(i: int) -> Vector3:
	return isles[i][0]

## A low pass over the home isle: in from far off and high, down over its
## middle at a clear height, and out the far side.
func _add_low_pass() -> void:
	var a := _rng.randf()*TAU
	var way := Vector3(cos(a),0.0,sin(a))
	var over := home_top+44.0
	route.append(home-way*320.0+Vector3.UP*(over+40.0-home.y))
	route.append(home-way*120.0+Vector3.UP*(over+8.0-home.y))
	route.append(Vector3(home.x,over,home.z))
	route.append(home+way*200.0+Vector3.UP*(over+20.0-home.y))
	for i in range(4): _leg_kinds.append("low pass")
	_legs_since_pass = 0

## A big circuit round the archipelago, high.
func _add_circuit() -> void:
	var r := _rng.randf_range(300.0,460.0)
	var h := _rng.randf_range(115.0,160.0)
	var a0 := atan2(pos.z-home.z,pos.x-home.x)
	var turn := 1.0 if _rng.randf() < 0.5 else -1.0
	for k in range(1,5):
		var a := a0+turn*k*TAU/5.0
		route.append(home+Vector3(cos(a)*r,h-home.y+_rng.randf_range(-15.0,15.0),sin(a)*r))
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
			if gap > 85.0 and gap < 420.0: best.append([i,j])
	if best.is_empty():
		_add_circuit()
		return
	var pick: Array = best[_rng.randi()%best.size()]
	var a := _isle_pos(pick[0])
	var b := _isle_pos(pick[1])
	var mid := (a+b)*0.5
	var across := Vector3(-(b.z-a.z),0.0,b.x-a.x).normalized()
	if across.dot(mid-pos) < 0.0: across = -across
	var y := minf(a.y,b.y)+6.0
	route.append(mid-across*230.0+Vector3.UP*(y+35.0-mid.y))
	route.append(Vector3(mid.x,y,mid.z))
	route.append(mid+across*220.0+Vector3.UP*(y+25.0-mid.y))
	for i in range(3): _leg_kinds.append("thread")

## Up high on heavy beats, then a long dive down at a far point.
func _add_climb_dive() -> void:
	var a := _rng.randf()*TAU
	var near := home+Vector3(cos(a),0.0,sin(a))*_rng.randf_range(180.0,320.0)
	route.append(Vector3(near.x,_rng.randf_range(200.0,240.0),near.z))
	var b := a+_rng.randf_range(1.2,2.2)
	var far := home+Vector3(cos(b),0.0,sin(b))*_rng.randf_range(260.0,420.0)
	route.append(Vector3(far.x,_rng.randf_range(60.0,80.0),far.z))
	_leg_kinds.append("climb")
	_leg_kinds.append("dive")

func _next_legs() -> void:
	_legs_since_pass += 1
	if _legs_since_pass >= 3 and _rng.randf() < 0.7:
		_add_low_pass()
		return
	var r := _rng.randf()
	if r < 0.36: _add_circuit()
	elif r < 0.7: _add_thread()
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
		state = "rising"
		model.visible = true
		_t = 0.0
	if _hold: _held(delta)
	else: _fly(delta)
	_pose(delta)
	if _log:
		_log_t += delta
		if _log_t >= 2.0:
			_log_t = 0.0
			print("sky dragon: t %.0f %s %s leg %s at (%.0f, %.0f, %.0f) %.1f m/s gamma %.2f roll %.2f flap %.2f" % [_clock,state,mode,leg_kind,pos.x,pos.y,pos.z,speed,gamma,roll,flap_w])

func _fly(delta: float) -> void:
	if route.is_empty(): _next_legs()
	var target: Vector3 = route[0]
	leg_kind = _leg_kinds[0]
	var to := target-pos
	var flat := Vector2(to.x,to.z)
	var dist := flat.length()
	var arrive := 30.0 if state == "rising" else ARRIVE
	var behind := Vector2(-sin(yaw),-cos(yaw)).dot(flat.normalized()) < -0.2
	var reached := pos.y > target.y-10.0 if state == "rising" else (dist < arrive or (behind and dist < 200.0))
	if reached:
		route.pop_front()
		_leg_kinds.pop_front()
		if state == "rising": state = "roaming"
		if route.is_empty(): _next_legs()
		target = route[0]
		to = target-pos
		flat = Vector2(to.x,to.z)
		dist = flat.length()
	# Turn toward it, the turn's rate eased; bank to suit.
	var want_yaw := atan2(-to.x,-to.z)
	var dyaw := wrapf(want_yaw-yaw,-PI,PI)
	var max_turn := MAX_TURN*(0.6 if state == "rising" else 1.0)
	var want_rate := clampf(dyaw*0.55,-max_turn,max_turn)
	yaw_rate = move_toward(yaw_rate,want_rate,0.22*delta)
	yaw += yaw_rate*delta
	var want_roll := clampf(atan(speed*yaw_rate/9.8),-MAX_BANK,MAX_BANK)
	roll = lerpf(roll,want_roll,1.0-exp(-delta*1.6))
	# Climb or dive toward its height.
	var want_gamma := clampf(atan2(to.y,maxf(dist,1.0))*1.4,-MAX_DIVE,MAX_CLIMB)
	if state == "rising": want_gamma = clampf(atan2(to.y,maxf(dist,1.0))*2.0,0.2,1.15)
	gamma = move_toward(gamma,want_gamma,(0.5 if state == "rising" else 0.32)*delta)
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
				_bout_left = _rng.randi_range(1,2)
			elif _bout and speed > GLIDE_ABOVE and _bout_left <= 0: _bout = false
	flap_w = move_toward(flap_w,1.0 if _bout else 0.0,delta*(1.2 if _bout else 0.6))
	# The push comes on the downstroke, so each beat surges.
	var power := (1.4 if mode == "climb" else 1.0)*(1.8 if phase < DOWN else 0.2)
	var accel := flap_w*THRUST*power-DRAG*speed*speed-9.8*sin(gamma)*0.5
	if mode == "dive": accel -= DRAG*speed*speed*0.4
	speed = clampf(speed+accel*delta,19.0 if state == "rising" else MIN_SPEED,MAX_SPEED)
	var fwd := Vector3(-sin(yaw)*cos(gamma),sin(gamma),-cos(yaw)*cos(gamma))
	pos += fwd*speed*delta
	# The beat keeps turning while the flapping fades, so wings settle.
	var hz := lerpf(BEAT,BEAT_CLIMB,clampf(gamma/MAX_CLIMB,0.0,1.0)) if state != "rising" else BEAT_CLIMB
	var before := phase
	if flap_w > 0.01 or fposmod(phase,1.0) > 0.02: phase = fposmod(phase+delta*hz,1.0)
	if phase < before and _bout_left > 0: _bout_left -= 1

## Held in place for a pose check.
func _held(delta: float) -> void:
	state = "roaming"
	pos = home+Vector3(150.0,120.0-home.y,0.0)
	yaw = 0.0
	yaw_rate = 0.0
	roll = 0.0
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
	# Gliding: small trims, each wing on its own, the inside wing a touch
	# down in a turn.
	var still := 1.0-flap_w
	_trim = Vector2(0.05*sin(_clock*0.71)+0.03*sin(_clock*1.9),0.05*sin(_clock*0.63+1.7)+0.03*sin(_clock*2.3))*still
	# The body: bobbing against each beat, nodding with it.
	var bob := -BOB*cos(TAU*phase)*flap_w*(1.3 if mode == "climb" else 1.0)
	var nod := 0.04*sin(TAU*phase)*flap_w
	var pitch := gamma*0.75+0.05+nod
	var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)*Basis(Vector3.BACK,roll)
	global_transform = Transform3D(basis,pos+basis.y*bob)
	for side in [-1.0,1.0]:
		var n := "L" if side < 0.0 else "R"
		var r: float = raise+(_trim.x if side < 0.0 else _trim.y)-side*roll*0.08
		_turn("wing_arm."+n,[[Vector3.BACK,side*r],[Vector3.UP,-side*(sweep+0.15*fold)],[Vector3.RIGHT,0.06*flap_w*sin(TAU*phase)]])
		_turn("wing_fore."+n,[[Vector3.UP,side*fold*0.85],[Vector3.BACK,side*(0.2*r+_tip_lag*0.3)]])
		_turn("wing_hand."+n,[[Vector3.UP,-side*fold*1.75],[Vector3.BACK,side*_tip_lag*0.6]])
		_turn("wing_f1."+n,[[Vector3.BACK,side*_tip_lag*0.5]])
		_turn("wing_f1b."+n,[[Vector3.BACK,side*_tip_lag*0.7]])
		_turn("wing_f2."+n,[[Vector3.UP,side*fold*0.15],[Vector3.BACK,side*_tip_lag*0.5]])
		_turn("wing_f3."+n,[[Vector3.UP,side*fold*0.3],[Vector3.BACK,side*_tip_lag*0.4]])
		_turn("wing_f4."+n,[[Vector3.UP,side*fold*0.45],[Vector3.BACK,side*_tip_lag*0.3]])
		# The legs tucked: forelegs folded up under the chest, the hind legs
		# trailing; a little swing with the beat.
		var swing := 0.06*sin(TAU*phase-0.8)*flap_w
		_turn("fore_upper."+n,[[Vector3.RIGHT,-1.2+swing]])
		_turn("fore_lower."+n,[[Vector3.RIGHT,2.2]])
		_turn("fore_foot."+n,[[Vector3.RIGHT,0.6]])
		_turn("hind_upper."+n,[[Vector3.RIGHT,-1.9-swing]])
		_turn("hind_lower."+n,[[Vector3.RIGHT,0.6]])
		_turn("hind_foot."+n,[[Vector3.RIGHT,-0.5]])
	# The body arching a little with the beat.
	_turn("chest",[[Vector3.RIGHT,0.03*sin(TAU*phase+0.6)*flap_w]])
	_turn("hips",[[Vector3.RIGHT,-0.03*sin(TAU*phase+0.6)*flap_w]])
	# The neck leads into the turn (a spring, so it overshoots a little) and
	# holds the head level against the pitch, bank and bob.
	var want_lead := clampf(yaw_rate*2.2,-0.75,0.75)
	_lead_v += ((want_lead-_lead)*6.0-_lead_v*3.2)*delta
	_lead += _lead_v*delta
	var look_goal := Vector2.ZERO
	if camera != null and watch != "chase":
		var eye := camera.global_position
		var off := global_transform.affine_inverse()*eye
		var d := off.length()
		if d < 220.0 and off.z < 10.0:
			var w := 1.0-smoothstep(120.0,220.0,d)
			look_goal = Vector2(clampf(atan2(-off.x,-off.z),-0.7,0.7),clampf(atan2(off.y,Vector2(off.x,off.z).length()),-0.5,0.3))*w
	_look_v += ((look_goal-_look)*3.0-_look_v*2.6)*delta
	_look += _look_v*delta
	var head_yaw := _lead+_look.x
	var level := -pitch*0.7+_look.y
	var neck_sway := 0.05*sin(TAU*phase-1.2)*flap_w
	_turn("spine.2",[[Vector3.RIGHT,-0.12]])
	_turn("neck.0",[[Vector3.RIGHT,-0.25+neck_sway*0.5],[Vector3.UP,head_yaw*0.25]])
	_turn("neck.1",[[Vector3.RIGHT,-0.05+neck_sway],[Vector3.UP,head_yaw*0.3]])
	_turn("neck.2",[[Vector3.RIGHT,0.12-neck_sway*0.5],[Vector3.UP,head_yaw*0.25]])
	_turn("head",[[Vector3.RIGHT,0.22+level-neck_sway*0.8],[Vector3.UP,head_yaw*0.2],[Vector3.BACK,-roll*0.5]])
	# Now and then the jaw drops, a slow silent roar.
	_jaw_next -= delta
	if _jaw_next <= 0.0:
		_jaw_left = 2.2
		_jaw_next = _rng.randf_range(10.0,20.0)
	_jaw_left = maxf(_jaw_left-delta,0.0)
	var jaw_goal := 0.42*sin(PI*clampf(1.0-_jaw_left/2.2,0.0,1.0)) if _jaw_left > 0.0 else 0.04
	_jaw = lerpf(_jaw,jaw_goal,1.0-exp(-delta*6.0))
	_turn("jaw",[[Vector3.RIGHT,-_jaw]])
	_tail(delta)

## The tail: a rope of points dragged from the hips, each held a segment's
## length from the one before and pulled softly toward its rest line, so
## it trails the flight's curve, swings late out of turns and ripples with
## the bob. The bones are then turned to lie along it.
func _tail(delta: float) -> void:
	for i in range(6): _turn("tail.%d" % i,[])
	var xf := global_transform
	var start := xf*(skeleton.get_bone_global_pose(_bone["hips"])*(skeleton.get_bone_global_rest(_bone["hips"]).affine_inverse()*_tail_start))
	if not _rope_ready:
		_rope = [start]
		for i in range(6): _rope.append(_rope[i]+xf.basis*(_seg_dir[i] as Vector3)*_seg_len[i])
		_rope_prev = _rope.duplicate()
		_rope_ready = true
	_rope[0] = start
	for i in range(1,7):
		var p := _rope[i]
		var v := (p-_rope_prev[i])*0.94
		_rope_prev[i] = p
		p += v
		# Its rest line from the point before, firmer near the hips.
		var rest := _rope[i-1]+xf.basis*(_seg_dir[i-1] as Vector3)*_seg_len[i-1]
		p = p.lerp(rest,clampf((7.0-float(i))*0.9*delta,0.0,1.0))
		var d := p-_rope[i-1]
		_rope[i] = _rope[i-1]+d.normalized()*_seg_len[i-1]
	# The bones along the rope: each turned by its bend from the one before.
	var inv := xf.basis.inverse()
	var prev_yaw := 0.0
	var prev_pitch := 0.0
	for i in range(6):
		var d: Vector3 = inv*(_rope[i+1]-_rope[i])
		var r: Vector3 = _seg_dir[i]
		var yaw_t := atan2(d.x,d.z)-atan2(r.x,r.z)
		var pitch_t := atan2(-d.y,Vector2(d.x,d.z).length())-atan2(-r.y,Vector2(r.x,r.z).length())
		var by := clampf(wrapf(yaw_t-prev_yaw,-PI,PI),-0.5,0.5)
		var bp := clampf(pitch_t-prev_pitch,-0.4,0.4)
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
			eye = at-fwd*78.0+Vector3.UP*24.0
			aim = at+fwd*25.0+Vector3.UP*2.0
		"orbit":
			_orbit += delta*0.18
			var a := _orbit
			if _orbit_fixed != INF: a = -yaw-PI*0.5+_orbit_fixed
			eye = at+Vector3(cos(a),0.0,sin(a))*100.0+Vector3.UP*38.0
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
	if watch == "look": _watch_eye = eye
	camera.global_position = _watch_eye
	camera.look_at(_watch_look,Vector3.UP)
	camera.fov = 55.0 if watch != "look" else 40.0
