class_name FindMarks
extends RefCounted
## What a find looks like (lane `finds`): `Mark`, the pooled node for a relic
## (a ring of dark hewn blocks, some with old gilding, hanging in the air and
## slowly turning) or a landing (a cairn with a gilt cap and a loose circle of
## flat stones); and `Beat`, the reward when one is taken: the ring's blocks
## burst to chips and flakes, a short warm light, a bell over cracking stone.
##
## The meshes are built here, once, and shared: hewn facets from a seeded rng,
## flat shaded, about 330 triangles a ring. What reads from far off is the glint: a
## fixed-size star that flares now and then, as old gold catches the sun, not a
## glow. It is depth tested, so land hides it.
##
## Sounds are stand-ins from what is on disk (see BELLS, CRACKS): the burrower's
## bells and gongs over foley rock breaks, pitched up the scale as the count grows.

const WorldScale = preload("res://scripts/world_scale.gd")
const NORMAL := "res://assets/textures/ruin_stone_normal.png"

const BLOCKS := 11
const STONE := Color(0.27,0.255,0.235)
const GILT := Color(0.74,0.54,0.21)
## The ring's turn (rad/s), and how fast its face comes round to the plane.
const SPIN := 0.3
const FACE := 0.8
## The glint's size (a share of the view's height, about).
const GLINT_SIZE := 0.05

static var _hoop: ArrayMesh
static var _cairn: ArrayMesh
static var _flat: ArrayMesh
static var _chip: ArrayMesh
static var _flare: Texture2D

static func stone_material(col: Color, gilt := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.42 if gilt else 0.95
	m.metallic = 0.75 if gilt else 0.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE*0.35
	if ResourceLoader.exists(NORMAL):
		m.normal_enabled = true
		m.normal_texture = load(NORMAL)
		m.normal_scale = 1.2
	if gilt:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.12
	return m

## A hewn lump between the two rims at u = 0..1, with caps.
static func _block(st: SurfaceTool, rng: RandomNumberGenerator, a0: float, a1: float, r: float, thick: float) -> void:
	const SIDES := 5
	const ARCS := 2
	var rims: Array = []
	for k in ARCS+1:
		var a := lerpf(a0,a1,float(k)/ARCS)
		var c := Vector3(cos(a),sin(a),0.0)*(r+rng.randf_range(-0.12,0.12))
		var out := Vector3(cos(a),sin(a),0.0)
		var rim := []
		for s in SIDES:
			var b := TAU*(float(s)+rng.randf_range(-0.14,0.14))/SIDES+0.4
			var w := thick*rng.randf_range(0.82,1.12)
			rim.append(c+(out*cos(b)+Vector3.BACK*sin(b)*0.85)*w)
		rims.append(rim)
	for k in ARCS:
		for s in SIDES:
			var p0: Vector3 = rims[k][s]
			var p1: Vector3 = rims[k][(s+1)%SIDES]
			var p2: Vector3 = rims[k+1][(s+1)%SIDES]
			var p3: Vector3 = rims[k+1][s]
			_tri(st,p0,p2,p1)
			_tri(st,p0,p3,p2)
	for s in range(1,SIDES-1):
		_tri(st,rims[0][0],rims[0][s],rims[0][s+1])
		_tri(st,rims[ARCS][0],rims[ARCS][s+1],rims[ARCS][s])

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

## The ring, in the XY plane about the origin: surface 0 stone, 1 gilt. Its
## opening is `Finds.ring_opening()`.
static func hoop() -> ArrayMesh:
	if _hoop != null: return _hoop
	var opening := WorldScale.opening(5.0)
	var thick := opening*0.13
	var r := opening*0.5+thick
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var stone := SurfaceTool.new()
	var gilt := SurfaceTool.new()
	for st: SurfaceTool in [stone,gilt]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
	for i in BLOCKS:
		# One block fell out long ago: the ring is not whole.
		if i == 7: continue
		var a0 := TAU*i/BLOCKS+0.035
		var a1 := TAU*(i+1)/BLOCKS-0.035
		_block(gilt if i%3 == 1 else stone,rng,a0,a1,r+rng.randf_range(-0.15,0.15),thick*(1.25 if i%3 == 1 else 1.0))
	var mesh := ArrayMesh.new()
	stone.generate_normals()
	stone.commit(mesh)
	gilt.generate_normals()
	gilt.commit(mesh)
	mesh.surface_set_material(0,stone_material(STONE))
	mesh.surface_set_material(1,stone_material(GILT,true))
	_hoop = mesh
	return mesh

## A rough stone of about radius 1 flattened by `squash`, added at `at`.
static func _stone(st: SurfaceTool, rng: RandomNumberGenerator, at: Vector3, r: float, squash: float) -> void:
	const N := 6
	const M := 3
	var pts := [at+Vector3.UP*r*squash]
	for j in M:
		var y := cos(PI*(j+1)/(M+1.0))
		var w := sin(PI*(j+1)/(M+1.0))
		for i in N:
			var a := TAU*(i+rng.randf_range(-0.2,0.2))/N
			pts.append(at+Vector3(cos(a)*w,y*squash,sin(a)*w)*r*rng.randf_range(0.85,1.15))
	pts.append(at-Vector3.UP*r*squash)
	var row := func(j: int, i: int) -> Vector3: return pts[1+j*N+posmod(i,N)]
	for i in N:
		_tri(st,pts[0],row.call(0,i+1),row.call(0,i))
		_tri(st,pts[pts.size()-1],row.call(M-1,i),row.call(M-1,i+1))
		for j in M-1:
			_tri(st,row.call(j,i),row.call(j,i+1),row.call(j+1,i+1))
			_tri(st,row.call(j,i),row.call(j+1,i+1),row.call(j+1,i))

## The cairn, standing on the origin: surface 0 stone, 1 the gilt cap.
static func cairn() -> ArrayMesh:
	if _cairn != null: return _cairn
	var rng := RandomNumberGenerator.new()
	rng.seed = 2093
	var stone := SurfaceTool.new()
	var gilt := SurfaceTool.new()
	for st: SurfaceTool in [stone,gilt]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
	_stone(stone,rng,Vector3(0.1,0.8,0.0),2.2,0.55)
	_stone(stone,rng,Vector3(-1.8,0.5,0.9),1.1,0.6)
	_stone(stone,rng,Vector3(1.5,0.4,-1.2),1.0,0.6)
	_stone(stone,rng,Vector3(-0.2,2.2,0.1),1.6,0.55)
	_stone(stone,rng,Vector3(0.15,3.3,-0.1),1.15,0.6)
	_stone(gilt,rng,Vector3(0.0,4.3,0.0),0.8,0.7)
	var mesh := ArrayMesh.new()
	stone.generate_normals()
	stone.commit(mesh)
	gilt.generate_normals()
	gilt.commit(mesh)
	mesh.surface_set_material(0,stone_material(STONE))
	mesh.surface_set_material(1,stone_material(GILT,true))
	_cairn = mesh
	return mesh

static func flat_stone() -> ArrayMesh:
	if _flat != null: return _flat
	var rng := RandomNumberGenerator.new()
	rng.seed = 311
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	_stone(st,rng,Vector3.ZERO,1.3,0.32)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0,stone_material(STONE))
	_flat = mesh
	return mesh

## A chip: a small hewn stone, for the burst.
static func chip() -> ArrayMesh:
	if _chip != null: return _chip
	var rng := RandomNumberGenerator.new()
	rng.seed = 90
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	_stone(st,rng,Vector3.ZERO,0.5,0.8)
	st.generate_normals()
	_chip = st.commit()
	return _chip

## A thin four-point star on black, for additive drawing.
static func flare() -> Texture2D:
	if _flare != null: return _flare
	const S := 96
	var img := Image.create(S,S,false,Image.FORMAT_RGBA8)
	var c := (S-1)*0.5
	for y in S:
		for x in S:
			var dx := absf(x-c)/c
			var dy := absf(y-c)/c
			var d := sqrt(dx*dx+dy*dy)
			var core := pow(maxf(1.0-d*3.2,0.0),2.0)
			var arm := pow(maxf(1.0-dx,0.0),3.0)*pow(maxf(1.0-dy*16.0,0.0),2.0)+pow(maxf(1.0-dy,0.0),3.0)*pow(maxf(1.0-dx*16.0,0.0),2.0)
			var v := clampf(core+arm,0.0,1.0)
			img.set_pixel(x,y,Color(1.0,0.93,0.76,v))
	_flare = ImageTexture.create_from_image(img)
	return _flare

## The glint: a fixed-size billboard, additive. Its own material, so each can
## fade alone (at most Finds.MAX_LIVE of them).
static func glint_sprite() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*GLINT_SIZE
	var m := StandardMaterial3D.new()
	m.albedo_texture = flare()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.fixed_size = true
	var g := MeshInstance3D.new()
	g.mesh = quad
	g.material_override = m
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g

## One find standing in the world, from the pool.
class Mark extends Node3D:
	var kind := ""
	var _body: MeshInstance3D
	var _ring: MultiMeshInstance3D
	var _glint: MeshInstance3D
	var _glint_mat: StandardMaterial3D
	var _t := 0.0
	var _phase := 0.0
	var _yaw_fixed := false
	var _found := false
	var _spin: Node3D

	func _init() -> void:
		_spin = Node3D.new()
		add_child(_spin)
		_body = MeshInstance3D.new()
		_spin.add_child(_body)
		_body.visibility_range_end = 1400.0
		_ring = MultiMeshInstance3D.new()
		add_child(_ring)
		_glint = FindMarks.glint_sprite()
		_glint_mat = _glint.material_override
		add_child(_glint)

	## Set up as a find of `what` at `at` from row `e`; found: a landing's cairn
	## stays, without its glint.
	func show_as(what: String, at: Vector3, e: Dictionary, found: bool, field: RefCounted) -> void:
		kind = what
		position = at
		visible = true
		_found = found
		_phase = fmod(at.x*0.37+at.z*0.11,TAU)
		_t = 0.0
		_body.visible = true
		_glint.visible = not found
		_spin.rotation = Vector3.ZERO
		rotation = Vector3.ZERO
		_ring.visible = false
		if what == "relic":
			_body.mesh = FindMarks.hoop()
			_glint.position = Vector3.ZERO
			_yaw_fixed = e.has("yaw")
			if _yaw_fixed: rotation.y = deg_to_rad(float(e.yaw))
		else:
			_body.mesh = FindMarks.cairn()
			_glint.position = Vector3.UP*5.4
			_yaw_fixed = true
			if not bool(e.moves): _stones(at,float(e.get("radius",45.0)),field)

	## The loose circle round a landing, at most as wide as is seen as a circle.
	func _stones(at: Vector3, radius: float, field: RefCounted) -> void:
		var r := minf(radius,60.0)
		const N := 14
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = FindMarks.flat_stone()
		mm.instance_count = N
		for i in N:
			var a := TAU*i/N+sin(i*7.1)*0.08
			var p := Vector3(cos(a)*r,0.0,sin(a)*r)
			p.y = float(field.height(at.x+p.x,at.z+p.z))-at.y
			mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,a*3.0).scaled(Vector3.ONE*(1.0+0.5*sin(i*2.3)**2)),p))
		_ring.multimesh = mm
		_ring.visible = true

	## A frame: the ring turns and meets the plane; the glint flares.
	func tick(delta: float, plane_at: Vector3, eye: Vector3) -> void:
		_t += delta
		if kind == "relic":
			_spin.rotation.z = _t*SPIN
			if not _yaw_fixed:
				var to := plane_at-position
				if to.length_squared() > 900.0:
					var want := atan2(to.x,to.z)
					rotation.y = lerp_angle(rotation.y,want,1.0-exp(-FACE*delta))
		if not _glint.visible: return
		var d := eye.distance_to(position)
		# A dull point always, a flare now and then, gone close in: there the
		# stones themselves read.
		var flare_k := pow(maxf(sin(_t*1.5+_phase),0.0),14.0)
		var a := 0.3+0.7*flare_k
		a *= smoothstep(25.0,140.0,d)
		_glint_mat.albedo_color = Color(1.0,1.0,1.0,a)
		_glint.scale = Vector3.ONE*(0.55+1.1*flare_k)

	## Taken: a ring goes at once (the burst stands in for it), a cairn stays.
	func taken() -> void:
		_found = true
		_glint.visible = false
		if kind == "relic": visible = false

## The reward: chips, flakes, a light and the sound, one at a time.
class Beat extends Node3D:
	const LIGHT_FOR := 0.45
	const BELLS := ["res://assets/audio/burrower/bell-531031.mp3","res://assets/audio/burrower/bell-417300.mp3"]
	const GONGS := ["res://assets/audio/burrower/gong-711881.mp3"]
	const CRACKS := ["res://assets/audio/foley/mesa-break-3.wav","res://assets/audio/foley/mesa-break-4.wav"]
	## The next find's bell a step up this scale.
	const SCALE := [1.0,1.125,1.25,1.5,1.667,2.0]
	var _chips: CPUParticles3D
	var _flakes: CPUParticles3D
	var _light: OmniLight3D
	var _lit := 0.0
	var _bell: AudioStreamPlayer
	var _crack: AudioStreamPlayer
	var last := {}

	func _init() -> void:
		_chips = _burst(FindMarks.chip(),FindMarks.stone_material(FindMarks.STONE),26,Vector2(0.7,2.2),Vector2(10.0,32.0),1.5)
		_flakes = _burst(FindMarks.chip(),FindMarks.stone_material(FindMarks.GILT,true),18,Vector2(0.14,0.42),Vector2(14.0,44.0),1.1)
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0,0.78,0.5)
		_light.omni_range = 46.0
		_light.shadow_enabled = false
		_light.visible = false
		add_child(_light)
		_bell = _player(-5.0)
		_crack = _player(-9.0)

	func _player(db: float) -> AudioStreamPlayer:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		p.volume_db = db
		add_child(p)
		return p

	func _burst(mesh: Mesh, mat: Material, n: int, sized: Vector2, speed: Vector2, life: float) -> CPUParticles3D:
		var c := CPUParticles3D.new()
		c.mesh = mesh
		c.material_override = mat
		c.amount = n
		c.one_shot = true
		c.emitting = false
		c.explosiveness = 1.0
		c.lifetime = life
		c.local_coords = false
		c.spread = 180.0
		c.gravity = Vector3.DOWN*16.0
		c.initial_velocity_min = speed.x
		c.initial_velocity_max = speed.y
		c.damping_min = 2.0
		c.damping_max = 5.0
		c.scale_amount_min = sized.x
		c.scale_amount_max = sized.y
		c.angular_velocity_min = -400.0
		c.angular_velocity_max = 400.0
		c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		c.emission_sphere_radius = WorldScale.opening(5.0)*0.55
		add_child(c)
		return c

	## `kind`'s beat at `at`; `n` the count now, for the bell's step.
	func play(kind: String, at: Vector3, n: float) -> void:
		last = {"kind":kind,"at":at,"frame":Engine.get_process_frames()}
		global_position = at
		if kind == "relic":
			_chips.restart()
			_flakes.restart()
			_chips.emitting = true
			_flakes.emitting = true
		_light.visible = true
		_lit = LIGHT_FOR
		_sound(kind,n)

	func _sound(kind: String, n: float) -> void:
		var list: Array = GONGS if kind == "landing" else BELLS
		var step: float = SCALE[int(n)%SCALE.size()]
		_bell.stream = load(list[int(n)%list.size()])
		_bell.pitch_scale = step*(0.8 if kind == "landing" else 1.0)
		_bell.play()
		if kind == "relic":
			_crack.stream = load(CRACKS[int(n)%CRACKS.size()])
			_crack.pitch_scale = 1.35
			_crack.play()

	func tick(delta: float) -> void:
		if _lit <= 0.0: return
		_lit -= delta
		var k := clampf(_lit/LIGHT_FOR,0.0,1.0)
		_light.light_energy = 14.0*k*k
		if _lit <= 0.0: _light.visible = false
