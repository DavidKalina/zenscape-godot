extends SceneTree
const Plate = preload("res://scripts/plate.gd")
## The calm grass ground and the soft tuft (docs/scenic/grass-look.md,
## "Round three"). Headless: the shader side is checked as source and by a
## GDScript copy of its grass test run over the real terrain palette; how the
## field looks is GPU work (captures/grass/).
const Palette = preload("res://scripts/native_terrain_palette.gd")
const GrassTuft = preload("res://scripts/grass_tuft_mesh.gd")
var failures := 0

func _initialize() -> void:
	var include := FileAccess.get_file_as_string("res://shaders/ground_look.gdshaderinc")
	var surface := FileAccess.get_file_as_string("res://shaders/reference_surface.gdshader")
	_palette_in_step(include)
	_grassness(include)
	_hooks(include, surface)
	_tuft()
	print("PASS: calm ground and soft tuft" if failures == 0 else "FAIL: ground look")
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	print(("ok   " if ok else "FAIL ") + message)

## The shader's three greens are the palette's, so the calm field sits on the
## colour the mesh paints and the grass test centres on it.
func _palette_in_step(include: String) -> void:
	var palette := Palette.new()
	var names := ["ZS_GROUND_GREEN","ZS_GROUND_SUNLIT","ZS_GROUND_DEEP"]
	for i in range(3):
		var value := _const(include, names[i])
		var c: Color = palette.grass[i]
		check(value.distance_to(Vector3(c.r,c.g,c.b)) < 0.001, "%s is NativeTerrainPalette.grass[%d] (%s vs %s)" % [names[i], i, value, c])

## A GDScript copy of zs_ground_grassness, held to the shader's thresholds.
func _grassness(include: String) -> void:
	check(include.contains("1.0 - smoothstep(0.08, 0.16, distance(g_chroma, g_green))"), "The grass test's thresholds are the ones checked here")
	var palette := Palette.new()
	var green := _const(include, "ZS_GROUND_GREEN")
	var worst := 1.0
	for x in range(-int(Plate.HALF), int(Plate.HALF)+1):
		for z in range(-int(Plate.HALF), int(Plate.HALF)+1):
			var c: Color = palette.grass_at_coordinates(float(x)+0.37, float(z)-0.21)
			worst = minf(worst, _grassness_of(Vector3(c.r,c.g,c.b), green))
	check(worst > 0.95, "Every palette grass face with its shimmer counts as grass: least %.3f" % worst)
	var earth := Color("b49d78").srgb_to_linear()
	var others := {"rock":palette.rock[0], "dark rock":palette.rock[1], "sand":palette.sand, "gravel":palette.gravel, "snow":palette.snow, "bare earth":earth, "painted rose":Color(0.7,0.1,0.3)}
	for key in others:
		var c: Color = others[key]
		check(_grassness_of(Vector3(c.r,c.g,c.b), green) < 0.01, "%s keeps its own colour" % key)
	var half: Color = earth.lerp(palette.grass[0], 0.5)
	check(_grassness_of(Vector3(half.r,half.g,half.b), green) < 0.2, "A face half bare earth keeps its cover edge")

func _grassness_of(face: Vector3, green: Vector3) -> float:
	var chroma := face / maxf(face.x+face.y+face.z, 0.001)
	var centre := green / (green.x+green.y+green.z)
	return 1.0 - smoothstep(0.08, 0.16, chroma.distance_to(centre))

## One place makes the ground's colour, with a hook for later tints, and the
## ground adds no varyings (Metal's 31, 4b6508e).
func _hooks(include: String, surface: String) -> void:
	check(include.contains("vec3 zs_ground_meadow_tint(vec3 g_ground, vec3 g_p)"), "The meadow tint hook is declared")
	check(include.contains("return zs_ground_meadow_tint(g_tint, g_p);"), "zs_ground_color ends in the meadow tint hook")
	check(surface.contains("#include \"res://shaders/ground_look.gdshaderinc\""), "reference_surface includes the ground look")
	check(surface.contains("vec3 tint = ground ? zs_ground_color("), "The ground's tint comes from zs_ground_color")
	var varyings := 0
	for line in surface.split("\n"):
		if line.strip_edges().begins_with("varying "): varyings += 1
	check(varyings <= 14, "reference_surface adds no varyings: %d declarations" % varyings)
	check(not include.contains("varying "), "ground_look declares no varyings")
	# Round five: the land's own colour rides the ground's spare earth_side
	# lanes (y the bowl, z the trees' shade), no new varyings.
	check(surface.contains("earth_side = vec4(zs_ground_lush_at(VERTEX), zs_ground_form_at(VERTEX), 0.0);"), "The ground's form and shade ride earth_side")
	check(surface.contains("if (ground) tint = zs_ground_form(tint, world_position, earth_side.xyz"), "The ground's tint takes the land's form")
	check(surface.contains("global uniform sampler2D zs_ground_shade;"), "reference_surface reads the trees' shade")

## The soft tuft is the default: fuller and lower than the source's six
## shards, dressed for the mass light.
func _tuft() -> void:
	check(GrassTuft.enabled(), "The soft tuft is on without flags")
	var mesh := GrassTuft.build(Color("38663a").srgb_to_linear(), Color("93c05f").srgb_to_linear())
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var box := mesh.get_aabb()
	check(indices.size()/3 == GrassTuft.blade_count()*5 and GrassTuft.blade_count() == 16, "Ten blades and two small satellite clumps of three, five flat facets each: %d triangles" % (indices.size()/3))
	check(maxf(box.size.x, box.size.z) <= 0.95, "The clump stays under a metre across: %.2f x %.2f m" % [box.size.x, box.size.z])
	check(box.size.y <= 0.4 and box.size.y >= 0.3, "No taller than the source's 0.42 m: %.2f m" % box.size.y)
	check(minf(box.size.x, box.size.z) >= 0.35, "A rounded mound at least 0.35 m across: %.2f x %.2f m" % [box.size.x, box.size.z])
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("flat_faces", true)
	var source := ArrayMesh.new()
	var source_arrays := []
	source_arrays.resize(Mesh.ARRAY_MAX)
	source_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(0.1,0.4,0.0), Vector3(0.05,0.0,0.05)])
	source_arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color("38663a"), Color("93c05f"), Color("38663a")])
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source_arrays)
	source.surface_set_material(0, material)
	var swapped := GrassTuft.swap("mesh-10", source)
	check(swapped != source and swapped.has_meta("grass_root"), "mesh-10 swaps to the soft tuft")
	GrassTuft.dress(material, swapped)
	check(material.get_shader_parameter("grass_blades") == true and material.get_shader_parameter("flat_faces") == false, "The tuft is dressed for soft mass light")
	check(GrassTuft.swap("mesh-9", source) == source, "Other meshes are left alone")
	check(vertices.size() > 0, "The tuft has vertices")

func _const(text: String, name: String) -> Vector3:
	var at := text.find("const vec3 %s = vec3(" % name)
	if at < 0:
		check(false, "%s is declared" % name)
		return Vector3.ZERO
	var start := text.find("(", at) + 1
	var parts := text.substr(start, text.find(")", start) - start).split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
