extends Node3D
## [linger] The colossus's breath where the wanderer is (scripts/roguelike/
## linger_colossus.gd): everything here is drawn, nothing pushes. His draw
## reaches the whole layer, so the air is shown round the wanderer, wherever
## he is:
##   wind     the world's own air (studies/atmosphere.gd: the grass, the
##            trees, the wind trails and the wind's sound) swung round to
##            blow toward him and freshened, eased back after
##   streaks  thin wind streaks (shaders/gust_trail.gdshader) running past
##            the wanderer toward him
##   motes    dust and leaves lifted off the turf round the wanderer and
##            carried off toward him, out over the rim into the void
## `step(delta, eye, toward, share)`: `eye` the wanderer's feet, `toward`
## the flat way to the colossus (unit), `share` 0 none .. 1 full draw.

const TRAIL = preload("res://shaders/gust_trail.gdshader")
const STREAKS := 26
const SEGMENTS := 14
const MOTES := 48
## The field round the wanderer the streaks and motes are laid in (m).
const FIELD := 22.0
## The world's wind at a full draw: its strength, and how much it swells.
const WIND := 2.6
const STREAK_TINT := Color(0.8,0.78,0.72)
const DUST := Color(0.78,0.73,0.62)
const LEAF := Color(0.36,0.5,0.24)
const LEAF_DRY := Color(0.62,0.52,0.28)

var study: Node3D
var look := true
var share := 0.0
var _streaks: MeshInstance3D
var _streak_mat := ShaderMaterial.new()
var _strands: Array = []
var _motes: Array = []
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
## The world's air as it was before he drew (restored after).
var _air_was := {}
var _ray := PhysicsRayQueryParameters3D.new()

func setup(scene: Node3D, drawn := true) -> void:
	study = scene
	look = drawn
	top_level = true
	_rng.seed = 77
	if not look: return
	_streaks = MeshInstance3D.new()
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streaks.extra_cull_margin = 80.0
	_streak_mat.shader = TRAIL
	_streak_mat.set_shader_parameter("width",0.11)
	_streak_mat.set_shader_parameter("flow_speed",1.4)
	_streak_mat.set_shader_parameter("tint",STREAK_TINT)
	_streaks.material_override = _streak_mat
	_streaks.visible = false
	add_child(_streaks)
	for i in range(STREAKS): _strands.append(_strand(true))
	var dust := SphereMesh.new()
	dust.radius = 0.05
	dust.height = 0.1
	dust.radial_segments = 6
	dust.rings = 3
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.16,0.015,0.1)
	for i in range(MOTES):
		var is_leaf := i%3 != 0
		var m := MeshInstance3D.new()
		m.mesh = leaf if is_leaf else dust
		var mat := StandardMaterial3D.new()
		mat.albedo_color = (LEAF if i%2 == 0 else LEAF_DRY) if is_leaf else DUST
		mat.roughness = 1.0
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_motes.append({"node":m,"pos":Vector3.ZERO,"vel":Vector3.ZERO,"live":0.0,"leaf":is_leaf,
			"spin":Vector3(_rng.randf_range(-7,7),_rng.randf_range(-5,5),_rng.randf_range(-7,7))})

func _strand(fresh := false) -> Dictionary:
	return {"x":_rng.randf_range(-1.0,1.0),"z":_rng.randf_range(-1.0,1.0),"h":_rng.randf_range(0.2,3.5),
		"age":_rng.randf_range(0.0,1.4) if fresh else 0.0,"life":_rng.randf_range(0.9,1.6),"len":_rng.randf_range(6.0,14.0),
		"swirl":_rng.randf_range(-1.0,1.0),"phase":_rng.randf()}

func step(delta: float, at: Vector3, toward: Vector3, how: float) -> void:
	share = clampf(how,0.0,1.0)
	_clock += delta
	_wind(toward)
	if not look: return
	_step_streaks(delta,at,toward)
	_step_motes(delta,at,toward)

# --- The world's air -------------------------------------------------------------------

## The atmosphere's wind swung toward him while he draws, its own after.
func _wind(toward: Vector3) -> void:
	var atmo: Variant = study.get("_atmosphere") if study != null else null
	if atmo == null or not is_instance_valid(atmo): return
	if share > 0.01:
		if _air_was.is_empty(): _air_was = {"angle":atmo.direction_angle,"strength":atmo.strength,"swell":atmo.swell}
		atmo.direction_angle = rad_to_deg(atan2(toward.z,toward.x))
		atmo.strength = lerpf(float(_air_was.strength),WIND,share)
		atmo.swell = lerpf(float(_air_was.swell),1.2,share)
	elif not _air_was.is_empty():
		atmo.direction_angle = _air_was.angle
		atmo.strength = _air_was.strength
		atmo.swell = _air_was.swell
		_air_was = {}

# --- The streaks ------------------------------------------------------------------------

func _step_streaks(delta: float, at: Vector3, toward: Vector3) -> void:
	_streak_mat.set_shader_parameter("clock",_clock)
	_streak_mat.set_shader_parameter("opacity",smoothstep(0.05,0.7,share)*0.28)
	if share <= 0.02:
		_streaks.visible = false
		return
	_streaks.visible = true
	var side := Vector3(-toward.z,0.0,toward.x)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: Dictionary in _strands:
		s.age = float(s.age)+delta*lerpf(0.6,1.3,share)
		if float(s.age) > float(s.life): s.merge(_strand(),true)
		var k: float = float(s.age)/float(s.life)
		var fade := smoothstep(0.0,0.25,k)*(1.0-smoothstep(0.7,1.0,k))
		# Laid upwind of him and run along the draw, past him and on.
		var base := at+side*float(s.x)*FIELD+toward*(float(s.z)*FIELD*0.7-FIELD*0.3)+Vector3.UP*float(s.h)
		var length: float = float(s.len)*lerpf(0.6,1.0,share)
		var head := base+toward*(k*FIELD*0.9)
		var pts := PackedVector3Array()
		for j in range(SEGMENTS+1):
			var u := float(j)/SEGMENTS
			var p := head-toward*length*(1.0-u)
			p += side*sin(u*PI*1.2+float(s.phase)*TAU)*float(s.swirl)*0.6
			p.y += sin(u*PI)*0.25
			pts.append(p)
		for j in range(SEGMENTS):
			var u0 := float(j)/SEGMENTS
			var u1 := float(j+1)/SEGMENTS
			var c := Color(float(s.phase),0.0,0.0,fade)
			for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				mesh.surface_set_uv(Vector2(u0 if corner.x == 0.0 else u1,corner.y))
				mesh.surface_set_color(c)
				mesh.surface_add_vertex(pts[j] if corner.x == 0.0 else pts[j+1])
	mesh.surface_end()
	_streaks.mesh = mesh

# --- The motes --------------------------------------------------------------------------

## A point on the turf near `at` (upwind more than down), or INF.
func _turf_near(at: Vector3, toward: Vector3) -> Vector3:
	var side := Vector3(-toward.z,0.0,toward.x)
	var p := at+side*_rng.randf_range(-1.0,1.0)*FIELD*0.6-toward*_rng.randf_range(-0.2,1.0)*FIELD*0.6
	_ray.from = p+Vector3.UP*8.0
	_ray.to = p+Vector3.DOWN*12.0
	var hit := study.get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty(): return Vector3.INF
	return (hit.position as Vector3)+Vector3.UP*0.05

func _step_motes(delta: float, at: Vector3, toward: Vector3) -> void:
	for m: Dictionary in _motes:
		var node := m.node as MeshInstance3D
		if float(m.live) <= 0.0:
			if share > 0.15 and _rng.randf() < share*delta*1.6:
				var p := _turf_near(at,toward)
				if p != Vector3.INF:
					m.live = _rng.randf_range(3.0,5.0)
					m.pos = p
					m.vel = Vector3.UP*_rng.randf_range(0.5,1.5)
			node.visible = false
			continue
		m.live = float(m.live)-delta
		# Along the draw, quickening, lifting; let go, they fall.
		var want := toward*share*_rng.randf_range(9.0,15.0)+Vector3.UP*share*1.2
		if share < 0.05: want = Vector3(m.vel.x,(m.vel as Vector3).y-6.0,m.vel.z)
		m.vel = (m.vel as Vector3).lerp(want,1.0-exp(-2.0*delta))
		m.pos = (m.pos as Vector3)+(m.vel as Vector3)*delta
		node.position = m.pos
		node.rotation += (m.spin as Vector3)*delta*(1.5 if m.leaf else 0.5)
		node.visible = true

func _exit_tree() -> void:
	share = 0.0
	_wind(Vector3.FORWARD)
