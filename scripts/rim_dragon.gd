extends Node3D
## The rim dragon (docs/design/rim-dragon.md): an experiment. A giant dragon
## (assets/models/rim_dragon.glb, art/blender/rim_dragon/rim_dragon_build.py)
## rises out of the cloud sea far off, makes one big swooping pass over the
## isle, comes round under one side, grips the rim with its claws and rears
## its head over the edge. From there it blows gales across the isle: each
## one told by an inhale (the head pulling up and back, the air streaming
## into its mouth), then a cone of wind swept across from the mouth that
## knocks the pilot into a tumble if he is caught in the open (the motor's
## `knock`, from the henge guardian). Behind stone he is sheltered. Between
## gusts it pants, jaw open on the ground, a treasure glinting on its
## tongue; touch the treasure and it is taken: the dragon roars, lets go
## and sinks back into the clouds. No combat, no fire, no harm: position and
## time only.
##
## Self-contained: the host (studies/aqueduct_isle.gd) makes one, calls
## `setup` with its pilot's motor, the motor's slide (for the push), the rim
## and the cloud sea's height, and calls `advance` every frame (on_foot says
## whether the pilot is walking, so the wind acts on him). It shows `gust`
## (the wind's way, x z) as each blow starts and `yielded` once the treasure
## is taken.
##
## Flags: --dragon-perched starts it on the rim (no flight); --dragon-delay=<s>
## (5) before it rises; --dragon-fly=<s> (24) the flight; --dragon-calm makes
## its gusts harmless (look only); --dragon-skip=<s> runs it on that far at
## the start (captures: with --dragon-perched, 6.8 is mid-gust).

signal gust(way: Vector2)
signal yielded

const PilotMotor = preload("res://scripts/pilot_motor.gd")
const MODEL = preload("res://assets/models/rim_dragon.glb")

## The pose's bones (names in the model).
const BONES := ["neck.0","neck.1","neck.2","head","jaw","upper_arm.L","forearm.L","hand.L",
	"upper_arm.R","forearm.R","hand.R","wing.L","wing_tip.L","wing.R","wing_tip.R"]
## In the model's rest frame (Godot axes: the island ahead at -z): the
## treasure on the tongue, the throat the wind comes from.
const TREASURE_REST := Vector3(0.0,4.4,-7.6)
const THROAT_REST := Vector3(0.0,5.4,-2.5)
## The gust: how far it reaches (m), the cone's half angle (rad) and the
## wider band where it only pushes, how hard it pushes there (m/s), and the
## knock (m out, m up).
const REACH := 55.0
const CONE := 0.34
const PUSH_CONE := 0.6
const PUSH := 4.5
const KNOCK_OUT := Vector2(11.0,5.0)
const KNOCK_UP := 1.4
## The yaw the blow sweeps through (rad, either side).
const SWEEP := 0.42
## The perched cycle's phases (s).
const PANT := 4.6
const INHALE := 1.5
const BLOW := 2.4
const RECOVER := 0.9
## Touch the treasure from this near (m, from the pilot's middle).
const TAKE_R := 2.8
## The take: the roar, the letting go, the sink (s).
const ROAR := 2.6
const RELEASE := 1.0
const SINK := 7.0
## The wind's streaks.
const STREAKS := 140

var motor: PilotMotor
var slide := Callable()
var perch := Transform3D.IDENTITY
var sea_y := -120.0
## "waiting", "flying", "landing", "perched", "roaring", "releasing",
## "sinking", "gone".
var state := "waiting"
## Within "perched": "pant", "inhale", "blow", "recover".
var phase := "pant"
var taken := false
var calm := false
var delay := 5.0
var fly_time := 24.0
var _skip := 0.0

var model: Node3D
var skeleton: Skeleton3D
var _bone := {}
var _rest_local := {}
var _rest_global := {}
var _t := 0.0
var _phase_t := 0.0
var _clock := 0.0
var _path: PackedVector3Array = []
var _lengths: PackedFloat32Array = []
var _pose := {}
var _from_pose := {}
var _from_xf := Transform3D.IDENTITY
var _blow_yaw := 0.0
var _knocked := false
var treasure: Node3D
var _treasure_light: OmniLight3D
var _bodies: Array = []
var _streaks: MultiMeshInstance3D
var _streak_state: Array = []
var _streak_next := 0
var _spawn_acc := 0.0

func _init() -> void:
	name = "RimDragon"

func setup(walker: PilotMotor, slide_with: Callable, rim: Vector3, into: Vector2, sea: float, args: PackedStringArray) -> void:
	motor = walker
	slide = slide_with
	sea_y = sea
	var face := Vector3(into.x,0.0,into.y).normalized()
	perch = Transform3D(Basis.looking_at(face,Vector3.UP),rim)
	var start_perched := false
	for arg in args:
		if arg == "--dragon-perched": start_perched = true
		elif arg == "--dragon-calm": calm = true
		elif arg.begins_with("--dragon-delay="): delay = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-fly="): fly_time = maxf(float(arg.get_slice("=",1)),4.0)
		elif arg.begins_with("--dragon-skip="): _skip = float(arg.get_slice("=",1))
	_build()
	_build_path()
	if start_perched:
		state = "perched"
		phase = "pant"
		global_transform = perch
		_pose = _perch_pose(0.0)
		model.visible = true
	else:
		model.visible = false
	_apply_pose()

# --- Building ---------------------------------------------------------------------

func _build() -> void:
	model = MODEL.instantiate()
	add_child(model)
	skeleton = _find_skeleton(model)
	for b: String in BONES:
		var i := skeleton.find_bone(b)
		_bone[b] = i
		_rest_local[b] = skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		_rest_global[b] = skeleton.get_bone_global_rest(i).basis.orthonormalized()
	_dress(model)
	_build_treasure()
	_build_bodies()
	_build_streaks()

static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null: return s
	return null

## The game's own glossy materials, by the model's surface names: dark
## basalt-violet hide with a wet clearcoat sheen, ivory teeth, red gums.
func _dress(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var key := m.resource_name if m != null else ""
			mi.set_surface_override_material(i,_material(key))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children(): _dress(c)

static func _material(key: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.roughness = 0.3
	m.metallic_specular = 0.6
	match key:
		"dragon_hide":
			m.albedo_color = Color("4b3b5e")
			m.roughness = 0.26
			m.metallic = 0.15
			m.clearcoat_enabled = true
			m.clearcoat = 0.9
			m.clearcoat_roughness = 0.1
			m.rim_enabled = true
			m.rim = 0.35
			m.rim_tint = 0.7
		"dragon_horn":
			m.albedo_color = Color("524860")
			m.roughness = 0.42
			m.clearcoat_enabled = true
			m.clearcoat = 0.4
		"dragon_tooth":
			m.albedo_color = Color("ebdfc4")
			m.roughness = 0.32
		"dragon_gum":
			m.albedo_color = Color("a8262f")
			m.roughness = 0.18
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.05
		"dragon_tongue":
			m.albedo_color = Color("80222f")
			m.roughness = 0.2
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
		"dragon_eye":
			m.albedo_color = Color("e0a640")
			m.emission_enabled = true
			m.emission = Color("e09a30")
			m.emission_energy_multiplier = 1.4
		"dragon_membrane":
			m.albedo_color = Color("3e3049")
			m.roughness = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.backlight_enabled = true
			m.backlight = Color("4a1f36")
		"dragon_claw":
			m.albedo_color = Color("1d1922")
			m.roughness = 0.22
			m.clearcoat_enabled = true
			m.clearcoat = 0.8
		_:
			m.albedo_color = Color("30263b")
	return m

## A faceted gold gem with a glint, riding the tongue.
func _build_treasure() -> void:
	treasure = Node3D.new()
	treasure.name = "Treasure"
	add_child(treasure)
	var gem := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.55
	mesh.height = 1.25
	mesh.radial_segments = 6
	mesh.rings = 3
	gem.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffd56a")
	m.metallic = 0.8
	m.roughness = 0.15
	m.emission_enabled = true
	m.emission = Color("ffb84a")
	m.emission_energy_multiplier = 2.2
	gem.material_override = m
	gem.name = "Gem"
	treasure.add_child(gem)
	_treasure_light = OmniLight3D.new()
	_treasure_light.light_color = Color("ffcf70")
	_treasure_light.light_energy = 1.0
	_treasure_light.omni_range = 3.0
	_treasure_light.shadow_enabled = false
	treasure.add_child(_treasure_light)

## Invisible collision riding the bones while perched (the skull, the snout,
## the lower jaw to stand on, the hands): [bone, shape, its centre in the
## rest frame, and for a capsule its far end].
func _build_bodies() -> void:
	var specs := [
		["head",_sphere(3.4),Vector3(0.0,7.6,-0.8),null],
		["head",_capsule(1.7,4.0),Vector3(0.0,6.55,-5.5),Vector3(1,0,0)],
		["jaw",_box(Vector3(4.6,1.8,8.0)),Vector3(0.0,3.2,-5.2),null],
		["hand.L",_box(Vector3(4.5,1.8,5.5)),Vector3(-9.0,0.8,-2.8),null],
		["hand.R",_box(Vector3(4.5,1.8,5.5)),Vector3(9.0,0.8,-2.8),null],
	]
	for spec: Array in specs:
		var body := StaticBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = spec[1]
		body.add_child(shape)
		add_child(body)
		var rest := Transform3D(Basis.IDENTITY,spec[2])
		# A capsule lies along z (the snout), turned from Godot's y.
		if spec[3] != null: rest.basis = Basis(Vector3(1,0,0),PI*0.5)
		var bone: String = spec[0]
		var local: Transform3D = skeleton.get_bone_global_rest(_bone[bone]).affine_inverse()*rest
		_bodies.append([body,bone,local])

static func _sphere(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s

static func _capsule(r: float, h: float) -> CapsuleShape3D:
	var s := CapsuleShape3D.new()
	s.radius = r
	s.height = h+2.0*r
	return s

static func _box(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s

## The wind made visible: long pale streaks, one multimesh (fade in the
## instance's custom data).
func _build_streaks() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0,1.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
varying float fade;
void vertex() { fade = INSTANCE_CUSTOM.r; }
void fragment() {
	float along = sin(UV.x * 3.14159);
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = vec3(0.94, 0.96, 1.0);
	ALPHA = clamp(fade * along * along * across * across * 0.55, 0.0, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = STREAKS
	_streaks = MultiMeshInstance3D.new()
	_streaks.name = "WindStreaks"
	_streaks.multimesh = mm
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streaks.top_level = true
	add_child(_streaks)
	for i in range(STREAKS):
		_streak_state.append({"life":0.0})
		mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*0.001),Vector3.ZERO))
		mm.set_instance_custom_data(i,Color(0,0,0,0))

## The flight's path, in the perch's frame (island ahead at -z): up out of
## the cloud sea far out behind, high over the rim and the isle, banking
## round out past the side, down under the rim and up onto it.
func _build_path() -> void:
	var low := sea_y-perch.origin.y-20.0
	var keys := [Vector3(-90.0,low,320.0),Vector3(-60.0,-40.0,200.0),Vector3(-20.0,28.0,95.0),Vector3(0.0,42.0,5.0),
		Vector3(8.0,40.0,-55.0),Vector3(55.0,32.0,-75.0),Vector3(100.0,16.0,-15.0),Vector3(75.0,-8.0,55.0),
		Vector3(25.0,-28.0,48.0),Vector3(0.0,-24.0,16.0),Vector3(0.0,-4.0,3.0),Vector3(0.0,0.0,0.0)]
	_path = []
	for i in range(keys.size()-1):
		var p0: Vector3 = keys[maxi(i-1,0)]
		var p1: Vector3 = keys[i]
		var p2: Vector3 = keys[i+1]
		var p3: Vector3 = keys[mini(i+2,keys.size()-1)]
		var n := maxi(4,int(p1.distance_to(p2)/3.0))
		for k in range(n):
			var t := float(k)/n
			_path.append(perch*(0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(-p0+3.0*p1-3.0*p2+p3)*t*t*t)))
	_path.append(perch*keys[-1])
	_lengths = [0.0]
	for i in range(1,_path.size()): _lengths.append(_lengths[i-1]+_path[i].distance_to(_path[i-1]))

func _path_at(s: float) -> Array:
	var total: float = _lengths[_lengths.size()-1]
	s = clampf(s,0.0,total)
	var i := _lengths.bsearch(s)
	i = clampi(i,1,_path.size()-1)
	var a: float = _lengths[i-1]
	var b: float = _lengths[i]
	var u := 0.0 if b <= a else (s-a)/(b-a)
	return [_path[i-1].lerp(_path[i],u),(_path[i]-_path[i-1]).normalized()]

# --- Poses --------------------------------------------------------------------------
# A pose: lean (the neck's forward lean, rad, split down it), head (its
# pitch on the neck), yaw (the head turned, split over the upper neck and
# the head), jaw (open, rad), wings (raised), flap (down beat), fold (swept
# back), arms (reached up, 0 gripping), grip (the hands pressed), lift
# (the hands raised off the rim).

const KEYS := ["lean","head","yaw","jaw","wings","flap","fold","arms","grip","lift"]

static func _p(lean := 0.0, head := 0.0, yaw := 0.0, jaw := 0.0, wings := 0.0, flap := 0.0, fold := 0.0, arms := 0.0, grip := 0.0, lift := 0.0) -> Dictionary:
	return {"lean":lean,"head":head,"yaw":yaw,"jaw":jaw,"wings":wings,"flap":flap,"fold":fold,"arms":arms,"grip":grip,"lift":lift}

static func _mix(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var out := {}
	for k: String in KEYS: out[k] = lerpf(float(a.get(k,0.0)),float(b.get(k,0.0)),u)
	return out

## Panting: the head down over the rim, chin on the turf, the jaw dropped.
func _pant_pose(t: float) -> Dictionary:
	var breath := sin(t*TAU/1.3)
	return _p(-0.22+0.012*breath,0.45,0.06*sin(t*0.37),-0.45+0.04*breath,0.05*sin(t*0.5),0.0,0.0,0.0,0.3)

## The inhale's height: reared up and back, jaw part shut, wings lifting.
func _inhale_pose() -> Dictionary:
	return _p(0.12,0.22,0.0,-0.18,0.25,-0.1,0.0,0.0,1.0)

## Blowing: thrust forward and a little down, jaw wide.
func _blow_pose(yaw: float) -> Dictionary:
	return _p(-0.05,0.45,yaw,-0.6,0.15,0.08,0.0,0.0,1.0)

func _perch_pose(t: float) -> Dictionary:
	return _pant_pose(t)

func _roar_pose(t: float) -> Dictionary:
	var shake := 0.04*sin(t*31.0)
	return _p(0.15,0.6,shake,-0.75,0.5,0.25*sin(t*4.5),0.0,0.0,1.0)

func _fly_pose(t: float) -> Dictionary:
	return _p(-1.15,1.05,0.0,-0.08,0.1,0.55*sin(t*TAU/1.6),0.25,1.0,0.0)

# --- Each frame ---------------------------------------------------------------------

func advance(delta: float, on_foot: bool) -> void:
	if delta <= 0.0: return
	if _skip > 0.0:
		var ahead := _skip
		_skip = 0.0
		while ahead > 0.0:
			advance(minf(ahead,1.0/60.0),false)
			ahead -= 1.0/60.0
	_clock += delta
	_t += delta
	match state:
		"waiting":
			if _t >= delay:
				state = "flying"
				_t = 0.0
				model.visible = true
		"flying": _fly(delta)
		"landing":
			var u := smoothstep(0.0,1.0,_t/2.2)
			_pose = _mix(_from_pose,_inhale_pose(),u)
			_pose["grip"] = u
			global_transform = _from_xf.interpolate_with(perch,u)
			if _t >= 2.2:
				state = "perched"
				_set_phase("pant")
		"perched": _perched(delta,on_foot)
		"roaring":
			_pose = _mix(_from_pose,_roar_pose(_t),smoothstep(0.0,1.0,_t/0.5))
			if _t >= ROAR:
				state = "releasing"
				_t = 0.0
				_from_pose = _pose.duplicate()
		"releasing":
			var u := smoothstep(0.0,1.0,_t/RELEASE)
			var to := _p(0.25,-0.1,0.0,-0.2,0.6,0.0,0.0,0.4,0.0,1.0)
			_pose = _mix(_from_pose,to,u)
			if _t >= RELEASE:
				state = "sinking"
				_t = 0.0
				_set_bodies(false)
		"sinking":
			var u := _t/SINK
			# Back off the rim and down into the cloud, falling away faster.
			var drop := (sea_y-perch.origin.y-40.0)*u*u
			global_transform = Transform3D(perch.basis*Basis(Vector3.RIGHT,0.5*smoothstep(0.0,1.0,u)),perch*Vector3(0.0,0.0,14.0*u)+Vector3.UP*drop)
			_pose = _mix(_pose,_p(-0.2,0.5,0.0,-0.1,0.9,0.3*sin(_t*3.0),0.0,1.0,0.0,1.0),1.0-exp(-delta*1.5))
			if _t >= SINK:
				state = "gone"
				model.visible = false
		"gone": pass
	if state != "gone" and state != "waiting": _apply_pose()
	_place_treasure(delta)
	_step_streaks(delta)
	if state == "perched" and on_foot: _touch()

func _fly(delta: float) -> void:
	var total: float = _lengths[_lengths.size()-1]
	var u := clampf(_t/fly_time,0.0,1.0)
	var s := total*(1.0-pow(1.0-u,1.7))
	var at: Array = _path_at(s)
	var ahead: Vector3 = at[1]
	ahead.y = clampf(ahead.y,-0.55,0.55)
	var basis := Basis.looking_at(ahead.normalized(),Vector3.UP)
	# Pitched over so the neck leads.
	var xf := Transform3D(basis*Basis(Vector3.RIGHT,-0.35),at[0])
	var end := smoothstep(0.82,1.0,u)
	xf = xf.interpolate_with(Transform3D(perch.basis,at[0]),end)
	global_transform = xf
	var reach := _p(-0.1,0.25,0.0,-0.1,0.3,0.0,0.0,-0.6,0.0)
	_pose = _mix(_fly_pose(_t),reach,end)
	if u >= 1.0:
		state = "landing"
		_t = 0.0
		_from_pose = _pose.duplicate()
		_from_xf = global_transform

func _set_phase(to: String) -> void:
	phase = to
	_phase_t = 0.0
	_from_pose = _pose.duplicate()
	_knocked = false
	if to == "pant": _set_bodies(true)
	if to == "blow":
		var way := _flat(-perch.basis.z)
		gust.emit(way)

func _perched(delta: float, on_foot: bool) -> void:
	_phase_t += delta
	match phase:
		"pant":
			_pose = _mix(_from_pose,_pant_pose(_clock),smoothstep(0.0,1.0,_phase_t/1.0))
			if _phase_t >= PANT: _set_phase("inhale")
		"inhale":
			var u := smoothstep(0.0,1.0,_phase_t/INHALE)
			_pose = _mix(_from_pose,_inhale_pose(),u)
			_spawn(delta,true)
			if _phase_t >= INHALE:
				_blow_yaw = -SWEEP if randf() < 0.5 else SWEEP
				_set_phase("blow")
		"blow":
			var u := clampf(_phase_t/BLOW,0.0,1.0)
			var yaw := lerpf(_blow_yaw,-_blow_yaw,smoothstep(0.0,1.0,u))
			_pose = _mix(_from_pose,_blow_pose(yaw),smoothstep(0.0,1.0,_phase_t/0.25))
			_spawn(delta,false)
			if on_foot: _wind(delta)
			if _phase_t >= BLOW: _set_phase("recover")
		"recover":
			_pose = _mix(_from_pose,_pant_pose(_clock),smoothstep(0.0,1.0,_phase_t/RECOVER))
			if _phase_t >= RECOVER: _set_phase("pant")

## The bones posed from `_pose`, each turn about an axis in the model's
## frame (the island ahead at -z, up y): a pitch about x, a yaw about y.
func _apply_pose() -> void:
	var p := _pose
	if p.is_empty(): p = _p()
	var lean: float = p.lean
	_set_bone("neck.0",[[Vector3.RIGHT,lean*0.3]])
	_set_bone("neck.1",[[Vector3.RIGHT,lean*0.4],[Vector3.UP,p.yaw*0.3]])
	_set_bone("neck.2",[[Vector3.RIGHT,lean*0.3],[Vector3.UP,p.yaw*0.3]])
	_set_bone("head",[[Vector3.RIGHT,p.head],[Vector3.UP,p.yaw*0.4]])
	_set_bone("jaw",[[Vector3.RIGHT,p.jaw]])
	for side in [-1.0,1.0]:
		var n := "L" if side < 0.0 else "R"
		var arms: float = p.arms
		var lift: float = p.lift
		# Reached up (flying, climbing on): the arm swung forward and up off
		# the rim; lifted, the hands raised off it; gripping, pressed down.
		_set_bone("upper_arm."+n,[[Vector3.RIGHT,0.5*arms+0.25*lift]])
		_set_bone("forearm."+n,[[Vector3.RIGHT,-0.3*arms-0.1*float(p.grip)+0.2*lift]])
		_set_bone("hand."+n,[[Vector3.RIGHT,0.6*arms+0.6*lift-0.12*float(p.grip)]])
		# The wing: raised (about forward, at the shoulder), beating down,
		# swept back (about up).
		var raise: float = float(p.wings)-float(p.flap)
		_set_bone("wing."+n,[[Vector3.BACK,side*raise*0.6],[Vector3.UP,-side*float(p.fold)*0.6]])
		_set_bone("wing_tip."+n,[[Vector3.BACK,side*(raise*0.4-float(p.flap)*0.5)]])

func _set_bone(b: String, turns: Array) -> void:
	var g: Basis = _rest_global[b]
	var q: Quaternion = _rest_local[b]
	for turn: Array in turns:
		var angle: float = turn[1]
		if absf(angle) < 0.00001: continue
		q = q*Quaternion((g.inverse()*(turn[0] as Vector3)).normalized(),angle)
	skeleton.set_bone_pose_rotation(_bone[b],q)

func _bone_xf(b: String) -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(_bone[b])

## A rest-frame point riding a bone, in the world.
func _riding(b: String, rest_point: Vector3) -> Vector3:
	var i: int = _bone[b]
	return skeleton.global_transform*(skeleton.get_bone_global_pose(i)*(skeleton.get_bone_global_rest(i).affine_inverse()*rest_point))

func treasure_at() -> Vector3:
	return _riding("jaw",TREASURE_REST)

func throat_at() -> Vector3:
	return _riding("head",THROAT_REST)

## The way the head faces, flat (x, z).
func facing() -> Vector2:
	var xf := _bone_xf("head")
	# The head bone points forward along its y.
	return _flat(xf.basis.y)

static func _flat(v: Vector3) -> Vector2:
	var f := Vector2(v.x,v.z)
	return f.normalized() if f.length() > 0.0001 else Vector2(0,-1)

func _place_treasure(delta: float) -> void:
	if treasure == null: return
	if taken or state == "waiting" or state == "gone":
		treasure.visible = false
		return
	treasure.visible = model.visible
	treasure.global_position = treasure_at()+Vector3.UP*(0.45+0.08*sin(_clock*2.0))
	treasure.rotate_y(delta*1.4)
	_treasure_light.light_energy = 0.8+0.4*sin(_clock*5.0)

func _set_bodies(on: bool) -> void:
	for entry: Array in _bodies:
		var body: StaticBody3D = entry[0]
		body.collision_layer = 1 if on else 0

func _place_bodies() -> void:
	for entry: Array in _bodies:
		var body: StaticBody3D = entry[0]
		body.global_transform = _bone_xf(entry[1])*(entry[2] as Transform3D)

func _process(_delta: float) -> void:
	if state == "perched" or state == "roaring" or state == "releasing": _place_bodies()

# --- The wind -----------------------------------------------------------------------

## The blow on the pilot: in the cone's core and in the open, knocked into a
## tumble; in the wider band, pushed along; behind stone, nothing.
func _wind(delta: float) -> void:
	if motor == null or calm: return
	if motor.has_method("recovering") and motor.recovering(): return
	var mid := motor.feet+Vector3.UP*0.6
	var from := throat_at()
	var off := mid-from
	var flat := Vector2(off.x,off.z)
	var dist := flat.length()
	if dist > REACH or dist < 0.5 or absf(off.y) > 14.0: return
	var way := facing()
	var angle := absf(way.angle_to(flat))
	if angle > PUSH_CONE: return
	if _sheltered(from,mid): return
	var envelope := smoothstep(0.0,0.3,_phase_t)*(1.0-smoothstep(BLOW-0.4,BLOW,_phase_t))
	var away := (flat.normalized()*0.5+way*0.5).normalized()
	if angle <= CONE and envelope > 0.5 and not _knocked:
		var out := lerpf(KNOCK_OUT.x,KNOCK_OUT.y,dist/REACH)
		motor.knock(motor.knock_velocity(away,out,KNOCK_UP))
		_knocked = true
		print("rim dragon: gust knocks the pilot, %.1f m from the throat" % dist)
		return
	if slide.is_valid() and motor.grounded:
		var push := away*PUSH*envelope*(1.0-dist/REACH*0.5)*delta
		var moved: Vector3 = slide.call(motor.feet,push)
		motor.feet = Vector3(moved.x,motor.feet.y,moved.z)

## Whether stone stands between the throat and the pilot (anything on the
## world's layer but the dragon's own collision).
func _sheltered(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from,to,1)
	var skip: Array[RID] = []
	for entry: Array in _bodies: skip.append((entry[0] as StaticBody3D).get_rid())
	q.exclude = skip
	var hit := space.intersect_ray(q)
	return not hit.is_empty()

## Streaks: flowing into the mouth (the inhale) or blown out of it across
## the cone (the gust).
func _spawn(delta: float, inhale: bool) -> void:
	_spawn_acc += delta*(55.0 if inhale else 70.0)
	var from := throat_at()
	var way2 := facing()
	var way := Vector3(way2.x,0.0,way2.y)
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		var spread := randf_range(-CONE*1.3,CONE*1.3)
		var dir := way.rotated(Vector3.UP,spread)
		dir.y = randf_range(-0.12,0.05)
		dir = dir.normalized()
		var s := {}
		if inhale:
			var start := from+dir*randf_range(14.0,30.0)+Vector3.UP*randf_range(-3.0,2.0)
			s = {"p":start,"v":(from-start).normalized()*randf_range(14.0,20.0),"life":1.2,"age":0.0,"len":randf_range(2.0,4.0)}
		else:
			s = {"p":from+dir*randf_range(2.0,5.0)+Vector3.UP*randf_range(-2.5,1.0),"v":dir*randf_range(24.0,34.0),"life":randf_range(1.3,1.9),"age":0.0,"len":randf_range(4.0,8.0)}
		_streak_state[_streak_next] = s
		_streak_next = (_streak_next+1)%STREAKS

func _step_streaks(delta: float) -> void:
	var mm := _streaks.multimesh
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else Vector3.ZERO
	for i in range(STREAKS):
		var s: Dictionary = _streak_state[i]
		if float(s.life) <= 0.0: continue
		s.age = float(s.age)+delta
		if float(s.age) >= float(s.life):
			s.life = 0.0
			mm.set_instance_custom_data(i,Color(0,0,0,0))
			mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*0.001),Vector3.ZERO))
			continue
		s.p = (s.p as Vector3)+(s.v as Vector3)*delta
		var u := float(s.age)/float(s.life)
		var fade := smoothstep(0.0,0.15,u)*(1.0-smoothstep(0.6,1.0,u))
		var along := (s.v as Vector3).normalized()
		var to_eye := (eye-(s.p as Vector3)).normalized()
		var across := along.cross(to_eye).normalized()
		if across.length() < 0.01: across = Vector3.UP
		var normal := along.cross(across).normalized()
		var basis := Basis(along*float(s.len),across*0.22,normal)
		mm.set_instance_transform(i,Transform3D(basis,s.p))
		mm.set_instance_custom_data(i,Color(fade,0,0,0))

# --- The treasure -------------------------------------------------------------------

func _touch() -> void:
	if taken or motor == null: return
	var mid := motor.feet+Vector3.UP*0.6
	if mid.distance_to(treasure_at()+Vector3.UP*0.45) <= TAKE_R: take()

## The treasure taken: a roar, it lets go and sinks into the clouds.
func take() -> void:
	if taken: return
	taken = true
	state = "roaring"
	_t = 0.0
	_from_pose = _pose.duplicate()
	print("rim dragon: the treasure is taken; it roars and lets go")
	yielded.emit()
