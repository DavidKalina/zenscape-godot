extends Node3D
## Cached pond picking, checked shore approaches, and a bounded splash pool.
## No terrain rebuilds, particle allocation, or navigation rebuilds on a dunk.
var scene: Node
var ponds: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var drop_cursor := 0
var ring_cursor := 0
var splash_count := 0

func setup(playground: Node) -> void:
	scene = playground
	for pond in scene._chunk_editor.data.ponds:
		ponds.append({"level":float(pond.level),"vertices":scene._chunk_editor.data.pond_surface(pond)})
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b2efee")
	material.roughness = 0.22
	var droplet := SphereMesh.new()
	droplet.radius = 0.06
	droplet.height = 0.17
	droplet.radial_segments = 6
	droplet.rings = 3
	for i in range(64):
		var mesh := MeshInstance3D.new()
		mesh.mesh = droplet
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		mesh.visible = false
		drops.append({"mesh":mesh,"velocity":Vector3.ZERO,"age":2.0})
	var ripple := TorusMesh.new()
	ripple.inner_radius = 0.94
	ripple.outer_radius = 1.0
	ripple.rings = 32
	ripple.ring_segments = 6
	for i in range(8):
		var mesh := MeshInstance3D.new()
		mesh.mesh = ripple
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		mesh.visible = false
		rings.append({"mesh":mesh,"age":2.0})

func surface_at(point: Vector3) -> Variant:
	for pond in ponds:
		if GardenWater.covers(pond.vertices,Vector2(point.x,point.z)):
			return Vector3(point.x,pond.level,point.z)
	return null

func pick(mouse: Vector2) -> Variant:
	if scene._over_controls(mouse) or not get_viewport().get_visible_rect().has_point(mouse): return null
	var origin: Vector3 = scene.camera.project_ray_origin(mouse)
	var direction: Vector3 = scene.camera.project_ray_normal(mouse)
	var ground: Variant = scene._ground_at(mouse)
	for pond in ponds:
		var point: Variant = Plane(Vector3.UP,pond.level).intersects_ray(origin,direction)
		if point == null or (ground != null and origin.distance_to(ground)+0.05 < origin.distance_to(point)): continue
		if GardenWater.covers(pond.vertices,Vector2(point.x,point.z)): return point
	return null

func shore_from(point: Vector3) -> Variant:
	# Search outward for the shortest clear approach, sampling props and ground
	# throughout. Reject steep banks rather than sliding through rocks or trees.
	var toward_viewer: Vector3 = scene.camera.global_position-point
	var preferred_angle := atan2(toward_viewer.z,toward_viewer.x)
	for radius in [1.0,2.0,3.0,4.0,5.0,6.0,8.0]:
		for i in range(24):
			var angle := preferred_angle+TAU*i/24.0
			var candidate: Variant = scene._probe_ground(point+Vector3(cos(angle),0,sin(angle))*radius)
			if candidate == null or not scene.valid_landing(candidate): continue
			var clear := true
			var previous: Variant = scene._probe_ground(point)
			for j in range(1,int(radius/0.2)+2):
				var sample: Vector3 = point.lerp(candidate,float(j)/(int(radius/0.2)+1))
				var floor_point: Variant = scene._probe_ground(sample)
				if floor_point == null or previous == null or absf(floor_point.y-previous.y)>0.3 or not scene.play_collisions.can_stand(floor_point):
					clear = false
					break
				previous = floor_point
			if clear: return candidate
	return null

func splash(point: Vector3, strength: float) -> void:
	splash_count += 1
	for i in range(16 if strength>0.5 else 5):
		var drop: Dictionary = drops[drop_cursor]
		drop_cursor = (drop_cursor+1)%drops.size()
		var angle := i*2.399+splash_count*0.8
		drop.mesh.position = point+Vector3(cos(angle)*0.3,0.05,sin(angle)*0.3)
		drop.velocity = Vector3(cos(angle)*2.0,2.4+float(i%4)*0.5,sin(angle)*2.0)*sqrt(strength)
		drop.age = 0.0
		drop.mesh.visible = true
	var surface: Variant = surface_at(point)
	if surface == null or absf(surface.y-point.y)>0.1: return
	var ring: Dictionary = rings[ring_cursor]
	ring_cursor = (ring_cursor+1)%rings.size()
	ring.mesh.position = point+Vector3.UP*0.03
	ring.age = 0.0
	ring.mesh.scale = Vector3.ONE*0.35
	ring.mesh.visible = true

func advance(delta: float) -> void:
	for drop in drops:
		drop.age += delta
		drop.mesh.visible = drop.age<0.8
		if not drop.mesh.visible: continue
		drop.velocity.y -= 8.0*delta
		drop.mesh.position += drop.velocity*delta
		drop.mesh.scale = Vector3.ONE*(1.0-drop.age/0.8)
	for ring in rings:
		ring.age += delta
		ring.mesh.visible = ring.age<1.0
		if ring.mesh.visible: ring.mesh.scale = Vector3(1.0+ring.age*1.8,0.4*(1.0-ring.age),1.0+ring.age*1.8)

func clear() -> void:
	for drop in drops:
		drop.age = 2.0
		drop.mesh.visible = false
	for ring in rings:
		ring.age = 2.0
		ring.mesh.visible = false
