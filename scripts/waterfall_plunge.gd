extends Node3D
## Where an authored fall lands: a droplet burst, bobbing foam blobs, and
## ripple rings rolling out across the receiving pond. Foam follows the source
## waterfall.js foamCluster: count 4+3·flow, ring radius (0.35..1.25)·spread,
## blob size (0.12..0.30)·scale, sitting 0.04 above the water and bobbing.
const FOAM := Color("f2f7f8")
const RINGS := 4
const RING_PERIOD := 1.15
var spray := GPUParticles3D.new()
var foam := MultiMeshInstance3D.new()
var rings: MultiMeshInstance3D
var base := Vector3.ZERO
var flow := 0.5
var in_pool := false
var clock := 0.0
var _foam_rest := PackedFloat32Array()
var _ring_radius := 0.0

func setup(landing: Vector3, scale: float, pool: bool) -> void:
	name = "Plunge"
	base = landing
	in_pool = pool
	flow = clampf(scale*0.5,0.2,1.0)
	_ring_radius = 1.3*maxf(scale,0.6)
	_build_spray(scale)
	_build_foam(scale)
	if in_pool: _build_rings()

func _build_spray(scale: float) -> void:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 55.0
	material.initial_velocity_min = 1.4*(0.8+0.4*scale)
	material.initial_velocity_max = 3.0*(0.8+0.4*scale)
	material.gravity = Vector3(0,-9.8,0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.22*scale
	material.scale_min = 0.5
	material.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0,Color(FOAM,0.95))
	fade.set_color(1,Color(FOAM,0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	material.color_ramp = ramp
	spray.process_material = material
	spray.amount = int(24+40*flow)
	spray.lifetime = 0.8
	spray.randomness = 0.6
	spray.visibility_aabb = AABB(Vector3(-4,-1,-4),Vector3(8,6,8))
	var bead := SphereMesh.new()
	bead.radius = 0.035
	bead.height = 0.07
	bead.radial_segments = 6
	bead.rings = 3
	var look := StandardMaterial3D.new()
	look.albedo_color = FOAM
	look.roughness = 0.25
	look.vertex_color_use_as_albedo = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bead.material = look
	spray.draw_pass_1 = bead
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spray.position = base+Vector3.UP*0.05
	add_child(spray)

func _build_foam(scale: float) -> void:
	var count := roundi(4+flow*3)
	var spread := 0.5+flow*0.5
	var size := 0.7+flow*0.25
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 6
	blob.rings = 3
	var look := StandardMaterial3D.new()
	look.albedo_color = FOAM
	look.roughness = 0.9
	blob.material = look
	foam.multimesh = MultiMesh.new()
	foam.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	foam.multimesh.mesh = blob
	foam.multimesh.instance_count = count
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(count):
		var angle := float(i)/count*TAU+scale*5.1
		var radius := (0.35+_hash(i,1)*0.9)*spread
		var extent := (0.12+_hash(i,2)*0.18)*size
		var point := base+Vector3(cos(angle)*radius,0.04,sin(angle)*radius*0.75)
		_foam_rest.append(point.y)
		foam.multimesh.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(i,i*2,i*3)).scaled(Vector3.ONE*extent),point))
	add_child(foam)

func _build_rings() -> void:
	rings = MultiMeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2,2)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/drip_ring.gdshader")
	material.render_priority = 10
	plane.material = material
	rings.multimesh = MultiMesh.new()
	rings.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	rings.multimesh.use_colors = true
	rings.multimesh.mesh = plane
	rings.multimesh.instance_count = RINGS
	rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rings)
	_draw_rings()

func _hash(i: int, salt: int) -> float:
	return fposmod(sin(float(i)*12.9898+float(salt)*78.233)*43758.5453,1.0)

func set_paused(value: bool) -> void:
	spray.speed_scale = 0.0 if value else 1.0

func advance(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta): return
	clock += delta
	for i in range(foam.multimesh.instance_count):
		var pose := foam.multimesh.get_instance_transform(i)
		pose.origin.y = _foam_rest[i]+absf(sin(clock*2.0+i*1.7))*0.08
		foam.multimesh.set_instance_transform(i,pose)
	if in_pool: _draw_rings()

func _draw_rings() -> void:
	for i in range(RINGS):
		var age := fposmod(clock+float(i)*RING_PERIOD/RINGS,RING_PERIOD)/RING_PERIOD
		var radius := 0.2+age*_ring_radius
		rings.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(radius,1,radius)),base+Vector3.UP*0.03))
		rings.multimesh.set_instance_color(i,Color(1,1,1,pow(1.0-age,1.6)))
