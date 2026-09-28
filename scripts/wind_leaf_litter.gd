extends MultiMeshInstance3D
## A bounded, cosmetic layer of loose leaves. No saves or gameplay state.
const CAPACITY := 96
var leaves: Array[Dictionary] = []
var ground_height: Callable
var local_wind: Node
var _clock := 0.0
var _accumulator := 0.0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "WindLeafLitter"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := [Vector3(0,0,-0.6),Vector3(-0.31,0,-0.16),Vector3(-0.36,0,0.2),Vector3(0,0,0.62),Vector3(0.33,0,0.18),Vector3(0.27,0,-0.18)]
	for i in range(outline.size()):
		for point in [Vector3(0,0.07,0),outline[i],outline[(i+1)%outline.size()]]:
			surface.set_color(Color.WHITE if i<3 else Color(0.68,0.74,0.62))
			surface.add_vertex(point)
	surface.generate_normals()
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = surface.commit()
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.85
	material_override = material
	custom_aabb = AABB(Vector3(-16,-3,-16),Vector3(32,32,32))

func seed_from(anchors: Array, probe: Callable) -> void:
	ground_height = probe
	leaves.clear()
	_clock = 0.0
	_accumulator = 0.0
	_rng.seed = 7091
	for index in range(0,anchors.size(),maxi(1,ceili(anchors.size()/24.0))):
		var anchor: Vector2 = anchors[index]
		for n in range(4):
			if leaves.size() >= CAPACITY: break
			var angle := _rng.randf()*TAU
			var point := anchor + Vector2(cos(angle),sin(angle))*_rng.randf_range(0.35,1.7)
			var height: Variant = ground_height.call(point)
			if height == null or not is_finite(float(height)): continue
			var normal := _ground_normal(point,float(height))
			if normal.y < 0.65: continue
			var position := Vector3(point.x,float(height)+0.035,point.y)
			leaves.append({"position":position,"home":position,"velocity":Vector3.ZERO,"yaw":angle,"spin":0.0,"phase":_rng.randf()*TAU,"size":_rng.randf_range(0.18,0.30),"weight":_rng.randf_range(0.8,1.4),"cooldown":_rng.randf_range(0.0,0.8),"airborne":false,"normal":normal})
			var color := Color("b79545").lerp(Color("9b6139"),_rng.randf())
			multimesh.set_instance_color(leaves.size()-1,color.srgb_to_linear())
	multimesh.visible_instance_count = leaves.size()
	_draw()

func advance(delta: float, paused: bool, air: Node) -> void:
	if paused or delta<=0.0 or not is_finite(delta) or not ground_height.is_valid(): return
	_accumulator += minf(delta,0.1)
	# Fixed small steps keep contact and damping stable across refresh rates.
	while _accumulator >= 1.0/60.0:
		_accumulator -= 1.0/60.0
		_step(1.0/60.0,air)
	_draw()

func _step(dt: float, air: Node) -> void:
	_clock += dt
	var direction := Vector2(cos(air._air_angle),sin(air._air_angle))
	var ambient: float = air._air_strength * air.gust_at(air._wind_time)
	for leaf in leaves:
		var p: Vector3 = leaf.position
		# Each parcel pushes along its own heading (a wind-tool gust's is the swipe's).
		var gust: Vector2 = air.puffs.push_at(Vector2(p.x,p.z),direction,air._gust_distance)
		var local := Vector3.ZERO
		if is_instance_valid(local_wind): local = local_wind.sample_local(p)
		var wind := Vector3(direction.x,0,direction.y)*ambient*1.3+Vector3(gust.x,0,gust.y)*7.0+local
		var speed := Vector2(wind.x,wind.z).length()
		leaf.cooldown = maxf(0.0,leaf.cooldown-dt)
		if not leaf.airborne:
			# Static friction: ordinary calm air does not make the floor crawl.
			if speed < 1.25*leaf.weight: continue
			leaf.velocity = Vector3(wind.x,0,wind.z)*0.28
			if speed>2.0*leaf.weight and leaf.cooldown<=0.0:
				leaf.airborne = true
				leaf.velocity.y = minf(2.6,speed*0.48)/leaf.weight
		var velocity: Vector3 = leaf.velocity
		if leaf.airborne:
			var flutter := sin(_clock*7.0+leaf.phase)
			velocity.x = lerpf(velocity.x,wind.x*0.65,dt*1.8)
			velocity.z = lerpf(velocity.z,wind.z*0.65,dt*1.8)
			velocity += Vector3(-direction.y,0,direction.x)*flutter*dt*0.6
			velocity.y += (-2.3*leaf.weight + minf(speed*0.20,1.0))*dt
			leaf.spin += dt*(2.2+speed*0.5)
		else:
			leaf.yaw = lerp_angle(leaf.yaw,atan2(wind.x,wind.z),dt*4.0)
		p += velocity*dt
		var height: Variant = ground_height.call(Vector2(p.x,p.z))
		if height == null or not is_finite(float(height)):
			# Recycle below the original canopy rather than escaping the island.
			p = leaf.home
			velocity = Vector3.ZERO
			leaf.airborne = false
			leaf.cooldown = 2.0
		elif not leaf.airborne or p.y <= float(height)+0.035:
			p.y = float(height)+0.035
			leaf.normal = _ground_normal(Vector2(p.x,p.z),float(height))
			velocity = Vector3.ZERO
			if leaf.airborne: leaf.cooldown = maxf(leaf.cooldown,0.8)
			leaf.airborne = false
		leaf.position = p
		leaf.velocity = velocity

func _draw() -> void:
	for i in range(leaves.size()):
		var leaf := leaves[i]
		var basis := Basis(Quaternion(Vector3.UP,leaf.normal)) * Basis(Vector3.UP,leaf.yaw)
		if leaf.airborne:
			basis = basis * Basis(Vector3.RIGHT,leaf.spin) * Basis(Vector3.FORWARD,sin(_clock*5.0+leaf.phase)*0.65)
		var size: float = leaf.size
		multimesh.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*size),leaf.position))

func _ground_normal(point: Vector2, height: float) -> Vector3:
	var x: Variant = ground_height.call(point+Vector2(0.12,0))
	var z: Variant = ground_height.call(point+Vector2(0,0.12))
	if x == null or z == null: return Vector3.UP
	return Vector3(height-float(x),0.12,height-float(z)).normalized()
