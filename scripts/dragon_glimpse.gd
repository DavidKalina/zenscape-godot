extends Node3D
## The dragon as a sighting shows it (scripts/dragon_sightings.gd, part 4 of
## docs/design/sky-weather/spec-storm-dragon.md): the rim dragon
## (assets/models/rim_dragon_c.glb) at SIZE, posed each frame as a glide
## after scripts/sky_dragon.gd `_pose` (its beat off: wings spread and a
## little gull-bent at the wrist, trimming against the air on their own,
## the hands twisting with the swell; hind legs tucked; the neck in its slow
## S, the head held level; the tail a whip swinging a slow wave down its
## length), the body riding the air (a slow swell, roll and pitch). Placed by
## the sighting (`show_at`: where, its glide, how lit) and drawn only while
## lit. Its skin is one dark hide (the flash is behind it from the eye, so
## it reads as a shape cut out of the lit cloud), with a rim of the flash's
## light round its edge.
##
## Self-contained: no rope, no springs, no sight; what sky_dragon does with
## them it does here with slow sines, enough for a shape seen for a fraction
## of a second.

const MODEL := "res://assets/models/rim_dragon_c.glb"
const SIZE := 1.5
## sky_dragon.gd's glide (rad): the wing's raise, its fold at the wrist.
const RAISE_GLIDE := 0.17
const FOLD := 0.05
## The hide (dark violet-black) and its rim's tint in the flash.
const HIDE := Color("17131c")
const MEMBRANE := Color("120e16")

var model: Node3D
var skeleton: Skeleton3D
var _bone := {}
var _rest_local := {}
var _rest_global := {}
var _tail_n := 0
var _neck_n := 0
var _clock := 0.0
var _yaw := 0.0
var _hide: StandardMaterial3D
var _skin: StandardMaterial3D

func _ready() -> void:
	name = "DragonGlimpse"
	top_level = true
	model = (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	model.scale = Vector3.ONE*SIZE
	skeleton = _find_skeleton(model)
	for i in range(skeleton.get_bone_count()):
		var b := skeleton.get_bone_name(i)
		_bone[b] = i
		_rest_local[b] = skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		_rest_global[b] = skeleton.get_bone_global_rest(i).basis.orthonormalized()
	while _bone.has("tail.%d" % _tail_n): _tail_n += 1
	while _bone.has("neck.%d" % _neck_n): _neck_n += 1
	_hide = _dark(HIDE,false)
	_skin = _dark(MEMBRANE,true)
	_dress(model)
	visible = false

static func _dark(c: Color, two_sided: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	m.metallic_specular = 0.2
	m.rim_enabled = true
	m.rim = 0.0
	m.rim_tint = 0.2
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.backlight_enabled = true
		m.backlight = Color(0.0,0.0,0.0)
	return m

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
			var key := m.resource_name if m != null else ""
			mi.set_surface_override_material(i,_skin if key.begins_with("dragon_membrane") else _hide)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The wings reach far from the rest pose's bounds.
		mi.extra_cull_margin = 60.0
	for c in n.get_children(): _dress(c)

## Each frame from the sighting: where it is, its glide, how lit it is
## (0: not drawn), the flash's light (its rim), the time step.
func show_at(at: Vector3, velocity: Vector3, lit: float, delta: float) -> void:
	_clock += delta
	if velocity.length() > 0.5: _yaw = atan2(-velocity.x,-velocity.z)
	visible = lit > 0.0
	if not visible: return
	_hide.rim = 0.35+0.65*lit
	_skin.backlight = Color(0.22,0.17,0.24)*lit
	_pose(at,velocity)

## A glide after sky_dragon.gd `_pose` with flap_w 0.
func _pose(at: Vector3, velocity: Vector3) -> void:
	var t := _clock
	# Riding the air: a slow swell and a roll and pitch off it.
	var air_roll := 0.07*sin(t*0.53)+0.03*sin(t*1.37+0.4)
	var air_pitch := 0.03*sin(t*0.41+1.1)
	var swell_y := 1.2*sin(t*0.47)
	var gamma := atan2(velocity.y,Vector2(velocity.x,velocity.z).length()) if velocity.length() > 0.5 else 0.0
	var pitch := gamma*0.75+0.05+air_pitch
	var basis := Basis(Vector3.UP,_yaw)*Basis(Vector3.RIGHT,pitch)*Basis(Vector3.BACK,air_roll)
	global_transform = Transform3D(basis,at+Vector3.UP*swell_y)
	# The wings trim each on its own, the hands twist with the swell.
	var trim := Vector2(0.05*sin(t*0.71)+0.03*sin(t*1.9),0.05*sin(t*0.63+1.7)+0.03*sin(t*2.3))
	var twist := 0.02*sin(t*0.47)+0.06*sin(t*0.9)
	for side in [-1.0,1.0]:
		var n := "L" if side < 0.0 else "R"
		var r: float = RAISE_GLIDE+(trim.x if side < 0.0 else trim.y)+side*air_roll*0.9
		var flex: float = 0.04*sin(t*1.6+side)*side
		_turn("wing_arm."+n,[[Vector3.BACK,side*r],[Vector3.UP,-side*0.15*FOLD],[Vector3.RIGHT,twist*0.4*side]])
		# The gull's bend at the wrist: the hand a little down.
		_turn("wing_fore."+n,[[Vector3.UP,side*FOLD*0.85],[Vector3.BACK,side*(0.2*r-0.22)]])
		_turn("wing_hand."+n,[[Vector3.UP,-side*FOLD*1.75],[Vector3.BACK,side*flex],[Vector3.RIGHT,twist*side]])
		_turn("wing_f1."+n,[[Vector3.BACK,side*0.06]])
		_turn("wing_f1b."+n,[[Vector3.BACK,side*(0.08+flex*1.5)]])
		_turn("wing_f2."+n,[[Vector3.UP,side*FOLD*0.15],[Vector3.BACK,side*flex]])
		_turn("wing_f3."+n,[[Vector3.UP,side*FOLD*0.3]])
		_turn("wing_f4."+n,[[Vector3.UP,side*FOLD*0.45]])
		# The hind legs tucked back under the tail's root, swinging a little.
		var hang := 0.06*sin(t*0.8+side)
		_turn("hind_upper."+n,[[Vector3.RIGHT,-1.5+hang]])
		_turn("hind_lower."+n,[[Vector3.RIGHT,0.9+hang*0.5]])
		_turn("hind_foot."+n,[[Vector3.RIGHT,-0.7-hang*0.25]])
	# Breathing in the chest.
	_turn("chest",[[Vector3.RIGHT,0.02*sin(t*0.9)]])
	_turn("hips",[[Vector3.RIGHT,-0.02*sin(t*0.9)]])
	# The neck: its S (root up, head end down), a slow sway passing up it;
	# the head held level against the pitch and roll.
	var neck_sway := 0.04*sin(t*0.37)
	var slither := 0.05*sin(t*0.29+0.8)
	_turn("spine.2",[[Vector3.RIGHT,-0.06]])
	for i in range(_neck_n):
		var u := float(i)/maxf(_neck_n-1,1)
		var bend := lerpf(0.04,-0.08,u)
		var wave := neck_sway*sin(PI*u+0.3)+slither*cos(PI*u)
		_turn("neck.%d" % i,[[Vector3.RIGHT,bend+wave],[Vector3.UP,slither*0.6*(u-0.5)]])
	_turn("head",[[Vector3.RIGHT,0.08-(gamma*0.75+0.05)*0.7-air_pitch-neck_sway*0.6],[Vector3.BACK,-air_roll*0.5]])
	# The tail: a whip, a slow wave travelling down it, growing to the tip,
	# drooping a little.
	for i in range(_tail_n):
		var u := float(i+1)/float(_tail_n)
		_turn("tail.%d" % i,[[Vector3.UP,0.07*u*sin(t*0.8-float(i)*0.7)],[Vector3.RIGHT,0.015]])

func _turn(b: String, turns: Array) -> void:
	if not _bone.has(b): return
	var g: Basis = _rest_global[b]
	var q: Quaternion = _rest_local[b]
	for turn: Array in turns:
		var angle: float = turn[1]
		if absf(angle) < 0.00001: continue
		q = q*Quaternion((g.inverse()*(turn[0] as Vector3)).normalized(),angle)
	skeleton.set_bone_pose_rotation(_bone[b],q)
