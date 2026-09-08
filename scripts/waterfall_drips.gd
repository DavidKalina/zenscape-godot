extends Node3D
## Sparse analytic droplets: one fall, a tiny splash, and one fading pool ring.
const CAPACITY := 12
var emitters: Array[Dictionary] = []
var clock := 0.0
var drops: MultiMeshInstance3D
var splashes: MultiMeshInstance3D
var rings: MultiMeshInstance3D

func _init() -> void:
	name = "WaterfallDrips"
	var bead := SphereMesh.new()
	bead.radial_segments = 5
	bead.rings = 2
	bead.radius = 1.0
	bead.height = 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.58,0.79,0.83)
	material.roughness = 0.2
	bead.material = material
	drops = _batch(bead,CAPACITY)
	splashes = _batch(bead,CAPACITY*3)
	var plane := PlaneMesh.new()
	plane.size = Vector2(2,2)
	var ring_material := ShaderMaterial.new()
	ring_material.shader = preload("res://shaders/drip_ring.gdshader")
	# Water is transparent too; draw surface rings after its reflection pass.
	ring_material.render_priority = 10
	plane.material = ring_material
	rings = _batch(plane,CAPACITY)

func _batch(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_colors = true
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = count
	node.multimesh.visible_instance_count = 0
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-20,-5,-20),Vector3(40,40,40))
	add_child(node)
	return node

func seed_from(falls: Array, data: RefCounted) -> void:
	emitters.clear()
	clock = 0.0
	var pools: Array = []
	if not falls.is_empty():
		for pond in data.ponds:
			pools.append({"pond":pond,"surface":data.pond_surface(pond)})
	for fall in falls:
		var material: ShaderMaterial = fall.mesh.surface_get_material(0)
		var centers: PackedVector4Array = material.get_shader_parameter("centers_tau")
		var axes: PackedVector4Array = material.get_shader_parameter("axis_a_width")
		var count: int = material.get_shader_parameter("ring_count")
		if count<2: continue
		var station := clampi(int(count*0.55),0,count-1)
		var center := centers[station]
		var across := axes[station]
		for side in [-1.0,1.0]:
			var origin: Vector3 = fall.transform * (Vector3(center.x,center.y,center.z)+Vector3(across.x,across.y,across.z)*(across.w+0.10)*side)
			var before := emitters.size()
			for pool in pools:
				var pond: Dictionary = pool.pond
				var outward: Vector3 = fall.basis * Vector3(across.x,0,across.z) * side * 0.55
				var target := Vector3(origin.x+outward.x,float(pond.level)+0.035,origin.z+outward.z)
				var toward := Vector3(pond.x-target.x,0,pond.z-target.z).normalized()
				for step in range(5):
					var landing := target+toward*float(step)*0.25
					if not GardenWater.covers(pool.surface,Vector2(landing.x,landing.z)): continue
					var h: Variant = data.ground_height(Vector2(landing.x,landing.z))
					if h == null or float(h)>float(pond.level)-0.1: continue
					var basin: Array = pond.get("basin",[4.0,4.0])
					if Vector2(landing.x-pond.x,landing.z-pond.z).length()>maxf(basin[0],basin[1]): continue
					if origin.y-landing.y<0.25 or origin.y-landing.y>3.0: continue
					# Avoid paths through a sculpted ledge and rings straddling land.
					var clear := true
					for t in [0.25,0.5,0.75]:
						var p := origin.lerp(landing,t)
						p.y = lerpf(origin.y,landing.y,t*t)
						var ground: Variant = data.ground_height(Vector2(p.x,p.z))
						if ground != null and float(ground)>p.y: clear = false
					for offset in [Vector2(0.4,0),Vector2(-0.4,0),Vector2(0,0.4),Vector2(0,-0.4)]:
						if not GardenWater.covers(pool.surface,Vector2(landing.x,landing.z)+offset): clear = false
						var ground: Variant = data.ground_height(Vector2(landing.x,landing.z)+offset)
						if ground == null or float(ground)>float(pond.level)-0.02: clear = false
					if clear: add_emitter(origin,landing)
					if clear: break
				if emitters.size()>before or emitters.size()>=CAPACITY: break
	_draw()

func add_emitter(origin: Vector3, landing: Vector3) -> void:
	if emitters.size()>=CAPACITY or origin.y<=landing.y: return
	var i := emitters.size()
	emitters.append({"origin":origin,"landing":landing,"flight":sqrt(2.0*(origin.y-landing.y)/5.0),"period":3.1+fmod(i*0.73,1.8),"phase":fmod(i*1.17,3.0)})

func advance(delta: float, paused: bool) -> void:
	if paused or delta<=0.0 or not is_finite(delta): return
	clock += delta
	_draw()

func _draw() -> void:
	var nd := 0
	var ns := 0
	var nr := 0
	for emitter in emitters:
		var age := fposmod(clock+emitter.phase,emitter.period)
		var flight: float = emitter.flight
		if age<flight:
			var p: Vector3 = emitter.origin.lerp(emitter.landing,age/flight)
			p.y = emitter.origin.y-2.5*age*age
			_place(drops,nd,p,Vector3(0.025,0.045+age*0.022,0.025))
			nd += 1
		else:
			var impact := age-flight
			if impact<1.35:
				var radius := 0.055+impact*0.24
				_place(rings,nr,emitter.landing,Vector3(radius,1,radius))
				rings.multimesh.set_instance_color(nr,Color(1,1,1,pow(1.0-impact/1.35,1.5)))
				nr += 1
			if impact<0.32:
				for j in range(3):
					var angle: float = float(j)*TAU/3.0+emitter.phase
					var p: Vector3 = emitter.landing+Vector3(cos(angle)*impact*0.38,impact*1.0-3.0*impact*impact,sin(angle)*impact*0.38)
					_place(splashes,ns,p,Vector3.ONE*0.017*(1.0-impact/0.4))
					ns += 1
	drops.multimesh.visible_instance_count = nd
	splashes.multimesh.visible_instance_count = ns
	rings.multimesh.visible_instance_count = nr

func _place(batch: MultiMeshInstance3D, index: int, point: Vector3, size: Vector3) -> void:
	batch.multimesh.set_instance_transform(index,Transform3D(Basis.from_scale(size),point))
