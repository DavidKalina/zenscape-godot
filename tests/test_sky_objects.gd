extends SceneTree
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var lighting: LandscapeLighting = scene._lighting
	var objects = lighting.sky_objects
	check(objects != null, "The lighting builds the sky's real objects")
	if objects == null:
		finish(scene)
		return
	var sky: ShaderMaterial = lighting.environment.sky.sky_material
	check(sky.get_shader_parameter("real_stars") == true, "The dome leaves out its painted stars")
	check(_uniforms(sky.shader).has("real_stars"), "The sky shader compiles and takes real_stars")
	var shaders := {
		"res://shaders/sky_stars.gdshader": ["horizon_ridges", "sky_distance"],
		"res://shaders/sky_planet_body.gdshader": ["planet_direction", "planet_frame"],
		"res://shaders/sky_planet_glow.gdshader": ["planet_radius"],
		"res://shaders/sky_planet_rings.gdshader": ["planet_frame", "horizon_seed"],
	}
	for path: String in shaders:
		var names := _uniforms(load(path))
		for wanted: String in shaders[path]:
			check(names.has(wanted), "%s compiles and takes %s" % [path.get_file(), wanted])

	var multimesh: MultiMesh = objects.stars.multimesh
	var expected: int = objects.HEROES.size()
	for tier: Array in objects.TIERS: expected += int(tier[0])
	check(multimesh.instance_count == expected, "One quad per field and hero star")
	# The entries, not the MultiMesh: headless keeps no instance storage.
	var entries: Array = objects.star_entries()
	check(entries.size() == expected, "The stars are the same set each run")
	var heroes := 0
	var unit := true
	var above_void := true
	for entry: Array in entries:
		var dir: Vector3 = entry[0]
		unit = unit and absf(dir.length() - 1.0) < 0.001
		above_void = above_void and dir.y >= -0.6
		if (entry[1] as Color).a > 0.5: heroes += 1
	check(unit, "Every star carries a unit room direction")
	check(above_void, "No stars are spent on the void under the slab")
	check(heroes == objects.HEROES.size(), "The placed brilliant stars are heroes")
	var stars_material: ShaderMaterial = objects.stars.material_override
	check(stars_material.render_priority < 0, "Stars draw ahead of the world's transparent pass")

	for name in ["Body", "Glow", "Rings"]:
		check(objects.planet.get_node_or_null(name) is MeshInstance3D, "The planet has its " + name)
	var body: ShaderMaterial = objects.planet.get_node("Body").material_override
	var frame: Basis = body.get_shader_parameter("planet_frame")
	check(absf(frame.determinant() - 1.0) < 0.001 and frame.is_equal_approx(frame.orthonormalized()), "The planet's frame is a rotation, so its facets face out")
	var rings: ShaderMaterial = objects.planet.get_node("Rings").material_override
	check(rings.render_priority > body.render_priority, "The rings draw over the body's near side")

	sky.set_shader_parameter("horizon_ridges", 0.75)
	sky.set_shader_parameter("horizon_seed", 3.0)
	objects._sync_ridges()
	check(stars_material.get_shader_parameter("horizon_ridges") == 0.75 and rings.get_shader_parameter("horizon_seed") == 3.0, "The look pass's ridges reach the sky objects")
	finish(scene)

func _uniforms(shader: Shader) -> Array:
	return shader.get_shader_uniform_list().map(func(entry: Dictionary) -> String: return entry.name)

func finish(scene: Node) -> void:
	scene.queue_free()
	await process_frame
	print("PASS: the sky's stars and planet are real objects" if failures == 0 else "FAIL: sky objects")
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
