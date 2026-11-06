extends RefCounted
## The wilderness's skin of the curtain kind (scripts/endless/kinds/
## curtain.gd): a waterfall. White water off the lip in the falls' sheet (the
## flow_fall shader on the shared ring mesh, the sky islets' curtain shape:
## scripts/sky_islets.gd `curtain`), churning foam where it lands in the pool
## and mist rising off it (the islets' plunge pieces: cluster_falls_dress.gd),
## readable from the valley.

const SkyIslets = preload("res://scripts/sky_islets.gd")
const FlowFalls = preload("res://scripts/flow_falls.gd")

## The sheet: STRANDS falls side by side across the lip, overlapping (each
## STRAND_HALF of the sheet's half-width; the shader's streaks are drawn
## across one fall, so a wide sheet in one reads as a slab), each its own
## whiteness, veil (0 whole, 1 torn to streaks), air (strength) and throw.
## TAIL: how far it runs on under the pool's water (m).
const STRANDS := [
	# [across (share of the half-width), half (share), white, veil, strength, throw x, seed]
	[-0.62,0.42,0.18,0.42,0.35,0.92,11],
	[0.0,0.48,0.3,0.22,0.45,1.06,23],
	[0.6,0.44,0.14,0.5,0.3,0.97,37],
]
const TAIL := 1.5
## The mist off the plunge: sprites, their radius (m), rise (m) and life (s),
## and how far it is drawn.
const MIST := 22
const MIST_SIZE := Vector2(5.0,11.0)
const MIST_RISE := Vector2(6.0,18.0)
const MIST_LIFE := Vector2(4.0,7.0)
const MIST_RANGE := 2600.0

static var _fall_mesh: Mesh = null
static var _quad: QuadMesh = null

## Dresses curtain `root` for `sheet` (curtain.gd `sheet_of`).
static func dress(root: Node3D, sheet: Dictionary, site: Dictionary) -> void:
	var seed_value := absi(hash(str(site.get("handle",""))))
	var lip: Vector3 = sheet.lip
	var out: Vector3 = sheet.out
	var drop := float(sheet.drop)
	var half := float(sheet.half)
	var across := out.cross(Vector3.UP).normalized()
	var bottom := lip
	if _fall_mesh == null: _fall_mesh = FlowFalls._build_ring_mesh(SkyIslets.FALL_RINGS)
	for k in STRANDS.size():
		var st: Array = STRANDS[k]
		var at := lip+across*half*float(st[0])
		var rings: Dictionary = SkyIslets.curtain(at,out,drop,TAIL,half*float(st[1]),0.3,float(st[4]),float(sheet.throw)*float(st[5]))
		var fall := MeshInstance3D.new()
		fall.name = "Sheet%d" % k
		fall.mesh = _fall_mesh
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/flow_fall.gdshader")
		m.render_priority = FlowFalls.CURTAIN_PRIORITY
		var sv := seed_value+int(st[6])
		m.set_shader_parameter("fall_seed",float(sv%997)*0.37+3.0)
		var white := PackedFloat32Array()
		for s in range(12): white.append(fposmod(sin(float(s*23+sv%1000)*12.9898)*43758.5453,1.0))
		m.set_shader_parameter("section_white",white)
		m.set_shader_parameter("ring_count",SkyIslets.FALL_RINGS)
		m.set_shader_parameter("centers_tau",rings.centers)
		m.set_shader_parameter("axis_a_width",rings.across)
		m.set_shader_parameter("axis_b_thick",rings.outward)
		m.set_shader_parameter("aer_steep",rings.aer_steep)
		m.set_shader_parameter("ring_travel",rings.travel)
		m.set_shader_parameter("body_white",float(st[2]))
		m.set_shader_parameter("veil",float(st[3]))
		m.set_shader_parameter("streak_speed",clampf(0.6*sqrt(2.0*9.81*drop),2.5,9.0))
		fall.material_override = m
		fall.custom_aabb = rings.bounds
		fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fall)
		if k == 1: bottom = rings.bottom_point
	var pool: Vector3 = sheet.pool
	_plunge(root,Vector3(bottom.x,pool.y,bottom.z),half,seed_value)

## Where the sheet lands on the pool at `at`: the churning foam on the water
## and the mist rising off it, `half` m either side.
static func _plunge(root: Node3D, at: Vector3, half: float, seed_value: int) -> void:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var foam_m := ShaderMaterial.new()
	foam_m.shader = preload("res://shaders/fall_pool_foam.gdshader")
	foam_m.render_priority = 2
	var foam := MeshInstance3D.new()
	foam.name = "PlungeFoam"
	foam.mesh = _quad
	foam.material_override = foam_m
	foam.transform = Transform3D(Basis(Vector3.RIGHT,-PI*0.5).scaled(Vector3(half*2.4,half*1.2,1.0)),at+Vector3(0.0,0.05,-2.0))
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(foam)
	var mist_m := ShaderMaterial.new()
	mist_m.shader = preload("res://shaders/sky_tepui_mist.gdshader")
	mist_m.render_priority = 3
	mist_m.set_shader_parameter("soft_depth",4.0)
	mist_m.set_shader_parameter("strength",0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _quad
	mm.instance_count = MIST
	for k in MIST:
		var across := rng.randf_range(-half,half)
		var spot := at+Vector3(across,0.0,rng.randf_range(-4.0,-1.0))
		var r := rng.randf_range(MIST_SIZE.x,MIST_SIZE.y)
		var rise := Vector3.UP*rng.randf_range(MIST_RISE.x,MIST_RISE.y)+Vector3(rng.randf_range(-1.0,1.0),0.0,-rng.randf_range(1.0,4.0))
		mm.set_instance_transform(k,Transform3D(Basis(Vector3.RIGHT*r,rise,Vector3.BACK),spot+Vector3.UP*0.5))
		mm.set_instance_custom_data(k,Color(rng.randf(),rng.randf(),rng.randf_range(MIST_LIFE.x,MIST_LIFE.y),0.8))
	var mist := MultiMeshInstance3D.new()
	mist.name = "PlungeMist"
	mist.multimesh = mm
	mist.material_override = mist_m
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.custom_aabb = AABB(at-Vector3(half+MIST_SIZE.y,1.0,MIST_SIZE.y+6.0),Vector3((half+MIST_SIZE.y)*2.0,MIST_RISE.y+MIST_SIZE.y+4.0,(MIST_SIZE.y+6.0)*2.0))
	mist.visibility_range_end = MIST_RANGE
	root.add_child(mist)
