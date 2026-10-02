extends SceneTree
## The walker's tread parts the low foliage: `scripts/foliage_tread.gd` keeps
## an exact ring round him and a fading wake behind him in `zs_tread_0..7`,
## the dress's ground cover really is drawn by `reference_surface.gdshader`, and
## that shader, with a tread published, leans a stem away from the tread and
## presses the one under it flat.

const Tread := preload("res://scripts/foliage_tread.gd")
const PARTS := ["flower-stems", "flowers-daisy", "flowers-spike", "flowers-umbel", "flowers-button", "mesh-15", "mesh-14", "fungus-stems", "fungus-caps"]

var failures := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		print("FAIL: ", message)
		push_error("FAIL: "+message)

func _run() -> void:
	_ring()
	_tree_envelopes()
	_clearance()
	_dress_shader()
	await _render()
	await _render_tree()
	print("PASS: foliage tread" if failures == 0 else "FAIL: foliage tread")
	quit(1 if failures else 0)

# --- the ring ---------------------------------------------------------------
func _tree_envelopes() -> void:
	var tread: Node = Tread.new()
	root.add_child(tread)
	tread.tick(Vector3.ZERO,1.0/30.0)
	check(tread.tree_weights()[1] == 0.0,"A new tree wake sample starts without an impulse")
	tread.tick(Vector3.ZERO,0.25)
	check(tread.tree_weights()[1]>0.0 and tread.tree_weights()[1]<1.0,"Tree samples ease into the bend")
	var held: Array = tread.tree_weights()
	tread.tick(Vector3.ZERO,1.0,true)
	check(tread.tree_weights() == held,"Pause holds tree envelopes")
	for i in range(1,10): tread.tick(Vector3(float(i)*0.61,0,0),0.2)
	check(tread.tree_weights()[7] == 0.0,"The oldest tree sample fades before ring eviction")
	tread.clear()
	check(tread.tree_weights().all(func(w: float) -> bool: return w == 0.0),"Clearing the wake clears tree forces")
	tread.free()

func _clearance() -> void:
	var source = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	data.reset_flat()
	var habitat = load("res://scripts/fidelity_habitat.gd").new()
	var box := AABB(Vector3(-0.2,0,-0.2),Vector3(0.4,4,0.4))
	habitat._prop_bounds = {"tree":box,"rock":box}
	for x in [-0.65,0.65]: data.place("tree",Vector2(x,0),0.0,1.0)
	habitat.setup(source,data)
	var nav := CreatureNavigation.new()
	nav.rebuild(habitat,habitat.clear_at,0.35,0.3)
	check(nav.segment_safe(Vector3(0,0,-3),Vector3(0,0,3)),"Restored trunk cores open a route through the stand")
	check(not nav.is_safe(Vector3(0.65,0,0)),"The trunk core stays solid")
	check(habitat.interests[0].bounds.size.is_equal_approx(box.size),"Tree contact keeps the original visual bounds")
	check(habitat.navigation_snapshot().clear_at(Vector3.ZERO),"Background navigation retains core clearance")
	for item in data.objects: item.asset = "rock"
	habitat.setup(source,data)
	check(not habitat.clear_at(Vector3.ZERO),"Rocks retain full clearance")
	source.free()

func _ring() -> void:
	var tread: Node = Tread.new()
	root.add_child(tread)
	# Nobody on the map: nothing published.
	tread.tick(null, 0.1)
	check(tread.records()[0].w == 0.0, "no walker, no live tread")
	# Five metres east at 0.7 m/s in thirtieths.
	var dt := 1.0/30.0
	var x := 0.0
	var steps := 0
	while x < 5.0:
		tread.tick(Vector3(x, 3.0, 1.0), dt)
		x += 0.7*dt
		steps += 1
	var ring: Array = tread.records()
	check(ring.size() == Tread.CAPACITY, "ring is %d wide" % Tread.CAPACITY)
	var live: Vector4 = ring[0]
	check(is_equal_approx(live.z, Tread.LIVE_RADIUS) and live.w == 1.0 and absf(live.y-1.0) < 0.001 and absf(live.x-(x-0.7*dt)) < 0.001, "slot 0 is the walker himself: "+str(live))
	var wake := 0
	var ordered := true
	var spaced := true
	for i in range(1, ring.size()):
		var r: Vector4 = ring[i]
		if r.w <= 0.0: break
		wake += 1
		if i > 1:
			var previous: Vector4 = ring[i-1]
			if r.x > previous.x: ordered = false
			if previous.x-r.x < Tread.SPACING-0.001: spaced = false
		check(is_equal_approx(r.z, Tread.WAKE_RADIUS), "wake record %d has the wake radius" % i)
	# A 5 m walk at 0.7 m/s is seven seconds; only the last WAKE_SECONDS of it
	# are still pressed, and the ring has room for all of those.
	var expected := int(floor(Tread.WAKE_SECONDS*0.7/Tread.SPACING))
	check(wake >= expected-1 and wake <= Tread.CAPACITY-1, "the wake holds the last %.0f s of walk: %d records (about %d)" % [Tread.WAKE_SECONDS, wake, expected])
	check(ordered, "wake is newest first")
	check(spaced, "wake records are at least %.1f m apart" % Tread.SPACING)
	check(float(ring[1].w) > float(ring[7].w), "the oldest record has faded further than the newest: %.2f vs %.2f" % [ring[1].w, ring[7].w])
	# Standing still and held: nothing ages.
	var before: Vector4 = tread.records()[3]
	tread.tick(Vector3(x, 3.0, 1.0), 1.0, true)
	check(tread.records()[3] == before, "a paused world holds the wake")
	# Standing still for the whole wake life: the wake is gone, the ring stays.
	for i in int(Tread.WAKE_SECONDS/dt)+2: tread.tick(Vector3(x, 3.0, 1.0), dt)
	ring = tread.records()
	check(ring[0].w == 1.0, "he is still standing there")
	check(ring[1].w == 0.0 and ring[7].w == 0.0, "the wake has faded after %.0f s" % Tread.WAKE_SECONDS)
	# (`global_shader_parameter_get` is editor-only; that the globals reach the
	# GPU is what the render below shows.)
	tread.tick(null, dt)
	check(tread.records()[0] == Vector4.ZERO and tread.records()[1] == Vector4.ZERO, "he left: the ring is cleared")
	tread.free()

# --- which shader the dress really draws with ------------------------------
func _dress_shader() -> void:
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	for part: String in PARTS:
		var node := source.get_node_or_null(NodePath(part))
		if node == null:
			check(false, "geometry.scn has "+part)
			continue
		var mesh: Mesh = node.multimesh.mesh if node is MultiMeshInstance3D else node.mesh
		var material: Material = node.material_override
		if material == null and mesh != null: material = mesh.surface_get_material(0)
		var shader_path := ""
		var sway := false
		if material is ShaderMaterial:
			shader_path = material.shader.resource_path
			sway = bool(material.get_shader_parameter("sway_enabled"))
		# The mushrooms ship without sway, so they stand through a tread; the
		# hook lives in the sway branch and that is reported rather than failed.
		check(shader_path.ends_with("reference_surface.gdshader"), "%s draws with %s (sway_enabled %s%s)" % [part, shader_path, sway, "" if sway else ": will not part"])
	source.free()

# --- the shader, with a tread under it --------------------------------------
## Two 2 m stems, unlit, on black: the left one has a tread a little west of
## it and must lean east; the right one stands in the middle of a tread and
## must be pressed down. Same rig as tests/test_local_wind_foliage.gd.
func _render() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: tread render needs a GPU")
		return
	RenderingServer.global_shader_parameter_set("zs_wind_strength", 0.0)
	RenderingServer.global_shader_parameter_set("zs_breeze", 0.0)
	RenderingServer.global_shader_parameter_set("zs_motion_time", 0.0)
	RenderingServer.global_shader_parameter_set("zs_exposure", 1.0)
	RenderingServer.global_shader_parameter_set("zs_surface_post", false)
	RenderingServer.global_shader_parameter_set("zs_foliage_wet", 0.0)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 200)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.BLACK
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10
	camera.position = Vector3(0, 1, 10)
	viewport.add_child(camera)
	camera.current = true
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://shaders/reference_surface.gdshader").replace("render_mode ", "render_mode unshaded, ")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("sway_enabled", true)
	material.set_shader_parameter("sway_shape", Vector4(0.0, 1.0, 0.4, 0.1))
	material.set_shader_parameter("base_color", Color.WHITE)
	for i in 2:
		var instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 2, 0.3)
		instance.mesh = box
		instance.material_override = material
		# The box mesh is centred; lift it so its foot is at y 0, the pivot the
		# sway shape bends from.
		instance.position = Vector3(-2 if i == 0 else 2, 1, 0)
		viewport.add_child(instance)
	await process_frame
	await RenderingServer.frame_post_draw
	var before := viewport.get_texture().get_image()
	check(_top(before, 0, 200) < before.get_height(), "the shader compiled and drew the stems (top row %d)" % _top(before, 0, 200))
	var tread: Node = Tread.new()
	root.add_child(tread)
	# Slot 0 west of the left stem, then a step onto the right stem: the walk
	# lays the first as a wake record and stands slot 0 on the second.
	tread.tick(Vector3(-2.5, 0.0, 0.0), 1.0/30.0)
	tread.tick(Vector3(2.0, 0.0, 0.0), 1.0/30.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var after := viewport.get_texture().get_image()
	var leaned := _centre(after, 0, 200)-_centre(before, 0, 200)
	check(leaned > 4.0, "a stem beside a tread leans away from it: %.1f px east" % leaned)
	var top_before := _top(before, 200, 400)
	var top_after := _top(after, 200, 400)
	check(top_after-top_before > 6, "a stem under the walker is pressed down: top row %d -> %d" % [top_before, top_after])
	tread.free()
	viewport.queue_free()
	await process_frame

## Mean lit column of the upper half of a band of the image.
func _centre(image: Image, start: int, end: int) -> float:
	var sum := 0.0
	var count := 0
	for y in range(30, 100):
		for x in range(start, end):
			var c := image.get_pixel(x, y)
			if c.r+c.g+c.b > 0.15:
				sum += x
				count += 1
	return sum/maxf(count, 1)

## First lit row of a band of the image, top down.
func _top(image: Image, start: int, end: int) -> int:
	for y in image.get_height():
		for x in range(start, end):
			var c := image.get_pixel(x, y)
			if c.r+c.g+c.b > 0.15: return y
	return image.get_height()

# --- a tree, with a tread beside it -----------------------------------------
## One 4 m trunk, `tree_tread` on, with a tread 1.2 m west of its root: the
## crown must lean east and the base must not move.
func _render_tree() -> void:
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 200)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.BLACK
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10
	camera.position = Vector3(0, 1, 10)
	viewport.add_child(camera)
	camera.current = true
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://shaders/reference_surface.gdshader").replace("render_mode ", "render_mode unshaded, ")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tree_tread", true)
	material.set_shader_parameter("tree_tread_height", 4.0)
	material.set_shader_parameter("base_color", Color.WHITE)
	var trunk := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 4, 0.3)
	box.subdivide_height = 16
	# The foot at the instance origin, as a tree's is: the bend rises from
	# local y 0, so a centred box would only bend its top half.
	var arrays: Array = box.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size(): vertices[i].y += 2.0
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var lifted := ArrayMesh.new()
	lifted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	trunk.mesh = lifted
	trunk.material_override = material
	trunk.position = Vector3(-2, 0, 0)
	viewport.add_child(trunk)
	await process_frame
	await RenderingServer.frame_post_draw
	var before := viewport.get_texture().get_image()
	var tread: Node = Tread.new()
	root.add_child(tread)
	tread.tick(Vector3(-3.2, 0.0, 0.0), 1.0/30.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var after := viewport.get_texture().get_image()
	# Twenty pixels a metre: the crown's top half-metre is rows 40..50, the base
	# is rows 112..119.
	var crown := _band_centre(after, 42, 52)-_band_centre(before, 42, 52)
	var base := _band_centre(after, 112, 119)-_band_centre(before, 112, 119)
	check(crown > 8.0, "a crown beside a tread leans away from it: %.1f px east" % crown)
	check(absf(base) < 1.0, "the trunk base stays planted: %.2f px" % base)
	tread.clear()
	var previous := 0.0
	var biggest_step := 0.0
	for frame in range(150):
		tread.tick(Vector3(-4.5+float(frame)/30.0,0,0.65),1.0/30.0)
		await process_frame
		RenderingServer.force_draw()
		var center := _band_centre(viewport.get_texture().get_image(),42,52)
		if frame>0: biggest_step = maxf(biggest_step,absf(center-previous))
		previous = center
	check(biggest_step<1.5,"Walking past a tree has no footprint-sized crown jumps: %.2f px/frame" % biggest_step)
	tread.free()
	viewport.queue_free()
	await process_frame

func _band_centre(image: Image, top: int, bottom: int) -> float:
	var sum := 0.0
	var count := 0
	for y in range(top, bottom):
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.r+c.g+c.b > 0.15:
				sum += x
				count += 1
	return sum/maxf(count, 1)
