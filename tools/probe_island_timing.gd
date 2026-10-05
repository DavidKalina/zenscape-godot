extends SceneTree
## Timing for irregular islands (scripts/island_outline.gd): what an outline
## costs per pointer frame (`ray_hit`) and per light refresh (`play_mesh`),
## against the way a void mask was handled before (every face tried per
## ray, and native_chasm_mesh's SurfaceTool rebuild per refresh), plus the
## one-off costs of making an outline and its shore wall. Headless, CPU only.
##   godot --headless --path . --script tools/probe_island_timing.gd
const Genesis = preload("res://scripts/genesis_canvas.gd")
const Outline = preload("res://scripts/island_outline.gd")
const RAYS := 400
const REFRESHES := 20

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	var t := Time.get_ticks_usec()
	var mask := Outline.mask(data.points,data.vertex_ids,77)
	var mask_ms := (Time.get_ticks_usec()-t)/1000.0
	t = Time.get_ticks_usec()
	Outline.shore_distance(data.points,data.vertex_ids,mask)
	var distance_ms := (Time.get_ticks_usec()-t)/1000.0
	print("outline mask %.1f ms, shore distance %.1f ms" % [mask_ms,distance_ms])
	# Rays as a pointer sweeping the island from a diorama camera.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var rays: Array = []
	for k in RAYS:
		var eye := Vector3(rng.randf_range(-6,6),22.0,32.0)
		var aim := Vector3(rng.randf_range(-16,16),0.0,rng.randf_range(-16,16))
		rays.append([eye,(aim-eye).normalized()])
	Genesis.shape(data,77,Vector2.ZERO,false)
	data.play_mesh(data.build_mesh())
	print("square plate: ray_hit %.3f ms per ray" % _rays(data,rays))
	Genesis.shape(data,77)
	var built := data.build_mesh()
	data.play_mesh(built)
	var island_ms := _rays(data,rays)
	# Before: the void path tried every face of the cut mesh per ray.
	var old_faces := preload("res://scripts/native_chasm_mesh.gd").build(built,data.void_faces,data.vertex_ids).get_faces()
	t = Time.get_ticks_usec()
	for ray: Array in rays: _brute(ray,old_faces)
	var brute_ms := (Time.get_ticks_usec()-t)/1000.0/RAYS
	# The same answer as trying every face left standing (the before path
	# also hit its brown walls, which an island no longer has in its mesh).
	var standing := data.play_collision_faces()
	var agree := 0
	for ray: Array in rays:
		var every: Variant = _brute(ray,standing)
		var now: Variant = data.ray_hit(ray[0],ray[1])
		if (every == null) == (now == null) and (every == null or (every as Vector3).distance_to(now) < 0.001): agree += 1
	print("island: ray_hit %.3f ms per ray (before: every face, %.3f ms); %d of %d rays match every standing face" % [island_ms,brute_ms,agree,RAYS])
	# Light refreshes: a dab moves a few heights, the build reshades, then the
	# play mesh is made from it.
	var play_usec := 0
	var old_usec := 0
	var build_usec := 0
	var shore_usec := 0
	var placing := Transform3D(Basis(),Vector3(0,-2,0))
	for k in REFRESHES:
		var heights := data.heights
		for i in range(data.points.size()):
			if data.points[i].distance_to(Vector2(1,1)) < 2.0 and not data.off_island(i): heights[i] += 0.02
		data.heights = heights
		t = Time.get_ticks_usec()
		built = data.build_mesh()
		build_usec += Time.get_ticks_usec()-t
		t = Time.get_ticks_usec()
		data.play_mesh(built)
		play_usec += Time.get_ticks_usec()-t
		t = Time.get_ticks_usec()
		preload("res://scripts/native_chasm_mesh.gd").build(built,data.void_faces,data.vertex_ids)
		old_usec += Time.get_ticks_usec()-t
		t = Time.get_ticks_usec()
		preload("res://scripts/island_shore.gd").build(data,placing,null)
		shore_usec += Time.get_ticks_usec()-t
	print("light refresh: build_mesh %.2f ms, play_mesh %.2f ms (before: SurfaceTool cut %.2f ms), shore wall %.2f ms" % [build_usec/1000.0/REFRESHES,play_usec/1000.0/REFRESHES,old_usec/1000.0/REFRESHES,shore_usec/1000.0/REFRESHES])
	var flow: RefCounted = preload("res://scripts/water_flow.gd").new(data)
	t = Time.get_ticks_usec()
	await flow.setup()
	print("water grid setup %.1f ms" % ((Time.get_ticks_usec()-t)/1000.0))
	t = Time.get_ticks_usec()
	Genesis.shape(data,78)
	print("a fresh island (shape, outline, water set up again) %.1f ms" % ((Time.get_ticks_usec()-t)/1000.0))
	data.release_listeners()
	quit()

func _brute(ray: Array, faces: PackedVector3Array) -> Variant:
	var best := INF
	var closest: Variant = null
	for i in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(ray[0],ray[1],faces[i],faces[i+1],faces[i+2])
		if hit != null and (ray[0] as Vector3).distance_squared_to(hit) < best:
			best = (ray[0] as Vector3).distance_squared_to(hit)
			closest = hit
	return closest

func _rays(data: NativeTerrainData, rays: Array) -> float:
	var t := Time.get_ticks_usec()
	for ray: Array in rays: data.ray_hit(ray[0],ray[1])
	return (Time.get_ticks_usec()-t)/1000.0/rays.size()
