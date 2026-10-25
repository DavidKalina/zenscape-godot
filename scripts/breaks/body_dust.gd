extends RefCounted
## The headless body's tells that read from across a gulf: soft dust puffs and
## plumes and
## stones falling off the face, each a one-shot CPUParticles3D that frees
## itself. Greybox-plus: billboards of one painted blob (a soft round broken
## by noise, so a cloud of them reads as brushed dust, not discs) and
## plain stone boxes.
##   puff(parent, at, size, out)        a hand or foot's puff on a face
##   plume(parent, at, size)            a billowing cloud off the ground
##   rocks(parent, at, out, n, size)    stones knocked off, falling away

const DUST := Color(0.8,0.74,0.64)
const STONE := Color(0.44,0.42,0.39)

static var _blob: Texture2D = null
static var _dust_mat: StandardMaterial3D = null
static var _rock_mat: StandardMaterial3D = null
static var _ramp: Gradient = null
static var _grow: Curve = null

## A puff of dust off a face where a hand or a foot bit (`out` the face's
## outward way): it spills out and down, `size` m across.
static func puff(parent: Node, at: Vector3, size: float, out := Vector3.ZERO) -> void:
	var p := _dust(parent,at,10,1.6,size)
	p.direction = (out*0.8+Vector3.DOWN*0.6).normalized() if out != Vector3.ZERO else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = size*0.4
	p.initial_velocity_max = size*1.0
	p.gravity = Vector3(0.0,-size*0.6,0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size*0.25
	_go(p)

## A cloud thrown up off the ground (a landing, the haul over the lip),
## `size` m across at first, billowing up and out to about twice that.
static func plume(parent: Node, at: Vector3, size: float) -> void:
	var p := _dust(parent,at,22,2.8,size)
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = size*0.5
	p.initial_velocity_max = size*1.3
	p.gravity = Vector3(0.0,size*0.12,0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = size*0.45
	p.emission_ring_inner_radius = size*0.15
	p.emission_ring_height = size*0.1
	_go(p)

## `n` stones of about `size` m knocked off at `at`, out along `out` and
## falling away (they fall on into the void; they don't collide).
static func rocks(parent: Node, at: Vector3, out: Vector3, n: int, size: float) -> void:
	var p := CPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE*size
	p.mesh = box
	p.material_override = _rock()
	p.amount = maxi(n,1)
	p.lifetime = 3.2
	p.one_shot = true
	p.explosiveness = 0.7
	p.local_coords = false
	p.direction = (out+Vector3.UP*0.3).normalized()
	p.spread = 35.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0.0,-16.0,0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size*1.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.particle_flag_rotate_y = true
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	_go(p)

static func _dust(parent: Node, at: Vector3, n: int, life: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*size
	p.mesh = quad
	p.material_override = _dust_material()
	p.amount = n
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.damping_min = size*0.5
	p.damping_max = size*0.9
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	p.scale_amount_curve = _grow_curve()
	p.color_ramp = _fade()
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -20.0
	p.angular_velocity_max = 20.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	return p

static func _go(p: CPUParticles3D) -> void:
	p.emitting = true
	p.finished.connect(p.queue_free)

static func _dust_material() -> StandardMaterial3D:
	if _dust_mat != null: return _dust_mat
	var m := StandardMaterial3D.new()
	m.albedo_texture = _blob_texture()
	m.albedo_color = DUST
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	_dust_mat = m
	return m

static func _rock() -> StandardMaterial3D:
	if _rock_mat != null: return _rock_mat
	var m := StandardMaterial3D.new()
	m.albedo_color = STONE
	m.roughness = 1.0
	_rock_mat = m
	return m

## Fades in fast, holds, thins out.
static func _fade() -> Gradient:
	if _ramp != null: return _ramp
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0,0.08,0.55,1.0])
	g.colors = PackedColorArray([Color(1,1,1,0.0),Color(1,1,1,0.85),Color(0.95,0.93,0.9,0.5),Color(0.9,0.88,0.85,0.0)])
	_ramp = g
	return g

## Grows from a sixth to whole over its life, quickly at first.
static func _grow_curve() -> Curve:
	if _grow != null: return _grow
	var c := Curve.new()
	c.add_point(Vector2(0.0,0.17))
	c.add_point(Vector2(0.3,0.6))
	c.add_point(Vector2(1.0,1.0))
	_grow = c
	return c

## The painted blob: a soft round, its edge broken and its body mottled
## by noise.
static func _blob_texture() -> Texture2D:
	if _blob != null: return _blob
	var size := 64
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var img := Image.create(size,size,false,Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var u := (Vector2(x,y)+Vector2(0.5,0.5))/float(size)*2.0-Vector2.ONE
			var n := noise.get_noise_2d(x,y)
			var r := u.length()+n*0.25
			var a := 1.0-smoothstep(0.1,0.95,r)
			var tone := 0.92+n*0.15
			img.set_pixel(x,y,Color(tone,tone,tone,clampf(a*a*(0.85+n*0.4),0.0,1.0)))
	_blob = ImageTexture.create_from_image(img)
	return _blob
