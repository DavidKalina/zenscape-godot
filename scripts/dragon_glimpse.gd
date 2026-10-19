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
## Close (`show_at` with an eye): lit a little from the flash too (a faint
## cold sheen on the hide, the membrane glowing through with the flash
## behind it), and kept CLEAR m off the eye: points sampled off its skinned
## mesh (`_samples`), posed each frame, and the whole body pushed off the
## eye by what the nearest one lacks (`show_at` returns the push, so the
## sighting's `place` follows it). It skims past, never round the camera.
##
## In a whiteout's murk (`murk`, set by the sighting each frame): the murk's
## sheet greys it out with all else past a few tens of m, so a second pass
## (shaders/dragon_loom.gdshader, `_loom`, drawn after the sheet) gives its
## shape back as a darker shade in the murk, deep and soft-edged near,
## fainter and greyer with distance: it looms out of the murk, never crisp.
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
## Close: the hide's sheen and the membrane's glow at full lit, the least
## gap (m) between the eye and any of its sampled points, how many points.
const SHEEN := Color(0.05,0.05,0.07)
const GLOW := Color(0.55,0.42,0.6)
const CLEAR := 14.0
const SAMPLES := 600
## The loom pass: after the murk's sheet (storm_whiteout.gd RENDER_PRIORITY
## 20), with the near rain's drops.
const LOOM_PRIORITY := 21

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
## The scaled, wet hide and the veined membrane (shaders/dragon_hide.gdshader,
## dragon_membrane.gdshader); the old flat ones above stay one switch away
## (`old_hide`: --hide=old, H in the sky weather field).
var _scales := ShaderMaterial.new()
var _veined := ShaderMaterial.new()
var old_hide := false
var _surfaces: Array = []
var _loom := ShaderMaterial.new()
## The whiteout's murk round the eye now (0 to 1).
var murk := 0.0
## [bone index, point in that bone's bind frame] off the mesh (`_sample`).
var _samples: Array = []
## The least gap to the eye this sighting (m; INF none yet).
var nearest := INF

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
	_loom.shader = preload("res://shaders/dragon_loom.gdshader")
	_loom.render_priority = LOOM_PRIORITY
	_hide.next_pass = _loom
	_skin.next_pass = _loom
	_scales.shader = preload("res://shaders/dragon_hide.gdshader")
	_veined.shader = preload("res://shaders/dragon_membrane.gdshader")
	_scales.next_pass = _loom
	_veined.next_pass = _loom
	for a in preload("res://scripts/launch_args.gd").user_args():
		if a == "--hide=old": old_hide = true
	_smooth(model)
	_dress(model)
	set_old_hide(old_hide)
	_sample(model)
	visible = false

## The old hide (true) or the scaled one (false).
func set_old_hide(old: bool) -> void:
	old_hide = old
	for e: Array in _surfaces:
		(e[0] as MeshInstance3D).set_surface_override_material(e[1],(_skin if e[2] else _hide) if old else (_veined if e[2] else _scales))

## The mesh's hard edges softened: each vertex of the hide and belly takes
## the average normal of every vertex at its spot, so the low-poly facets
## stop reading (the scales carry the small form).
func _smooth(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var out := ArrayMesh.new()
		for i in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(i)
			var m := mi.mesh.surface_get_material(i)
			var key := m.resource_name if m != null else ""
			if key == "dragon_hide" or key == "dragon_belly":
				var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var sum := {}
				for j in vs.size():
					var k := vs[j].snapped(Vector3.ONE*0.001)
					sum[k] = (sum[k] as Vector3 if sum.has(k) else Vector3.ZERO)+ns[j]
				var sm := PackedVector3Array()
				sm.resize(vs.size())
				for j in vs.size(): sm[j] = (sum[vs[j].snapped(Vector3.ONE*0.001)] as Vector3).normalized()
				arrays[Mesh.ARRAY_NORMAL] = sm
				arrays[Mesh.ARRAY_TANGENT] = null
			out.add_surface_from_arrays(mi.mesh.surface_get_primitive_type(i),arrays,[],{},mi.mesh.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			out.surface_set_material(i,m)
		mi.mesh = out
	for c in n.get_children(): _smooth(c)

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
			_surfaces.append([mi,i,key.begins_with("dragon_membrane")])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The wings reach far from the rest pose's bounds.
		mi.extra_cull_margin = 60.0
	for c in n.get_children(): _dress(c)

## Points off the skinned meshes, each held by its heaviest bone in that
## bone's bind frame, about SAMPLES of them spread over every vertex.
func _sample(n: Node) -> void:
	var meshes: Array[MeshInstance3D] = []
	_meshes(n,meshes)
	var total := 0
	for mi in meshes:
		for i in mi.mesh.get_surface_count(): total += mi.mesh.surface_get_array_len(i)
	var stride := maxi(total/SAMPLES,1)
	for mi in meshes:
		var skin := mi.skin
		if skin == null: continue
		for i in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null: continue
			var per: int = bones.size()/maxi(verts.size(),1)
			for v in range(0,verts.size(),stride):
				var best := 0
				for k in range(per):
					if weights[v*per+k] > weights[v*per+best]: best = k
				var bind: int = bones[v*per+best]
				var bone := skin.get_bind_bone(bind)
				if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(bind))
				if bone < 0: continue
				_samples.append([bone,skin.get_bind_pose(bind)*verts[v]])

static func _meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): _meshes(c,out)

## Each frame from the sighting: where it is, its glide, how lit it is
## (0: not drawn), the time step; for a close one the eye it keeps off and
## how close (0 far, 1 close). Returns the push off the eye (add it to
## `at`), zero far or when clear.
func show_at(at: Vector3, velocity: Vector3, lit: float, delta: float, eye := Vector3.INF, close := 0.0) -> Vector3:
	_clock += delta
	if velocity.length() > 0.5: _yaw = atan2(-velocity.x,-velocity.z)
	visible = lit > 0.0
	var keep := eye != Vector3.INF
	if not keep: nearest = INF
	if not visible and not keep: return Vector3.ZERO
	_hide.rim = 0.35+0.65*lit
	_hide.emission_enabled = close > 0.0
	_hide.emission = SHEEN*lit*close
	_skin.backlight = Color(0.22,0.17,0.24).lerp(GLOW,close)*lit
	for sm: ShaderMaterial in [_scales,_veined]:
		sm.set_shader_parameter("lit",lit)
		sm.set_shader_parameter("close",close)
	_loom.set_shader_parameter("murk",murk)
	_loom.set_shader_parameter("lit",lit)
	_pose(at,velocity)
	if not keep: return Vector3.ZERO
	var push := Vector3.ZERO
	for i in range(3):
		var near := _nearest(eye)
		var gap := eye.distance_to(near)
		if gap >= CLEAR-0.01:
			nearest = minf(nearest,gap)
			break
		var away := (near-eye).normalized() if gap > 0.01 else (global_position-eye).normalized()
		var step := away*(CLEAR-gap)
		push += step
		global_position += step
		skeleton.force_update_transform()
		if i == 2: nearest = minf(nearest,eye.distance_to(_nearest(eye)))
	return push

## The sampled point nearest the eye, as posed (world).
func _nearest(eye: Vector3) -> Vector3:
	var xf := skeleton.global_transform
	var poses := {}
	var best := Vector3.INF
	var best_d := INF
	for s: Array in _samples:
		var b: int = s[0]
		if not poses.has(b): poses[b] = xf*skeleton.get_bone_global_pose(b)
		var p: Vector3 = (poses[b] as Transform3D)*(s[1] as Vector3)
		var d := p.distance_squared_to(eye)
		if d < best_d:
			best_d = d
			best = p
	return best

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
