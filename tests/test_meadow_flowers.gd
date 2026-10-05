extends SceneTree
## The meadow flower kit (scripts/meadow_flower_mesh.gd, docs/scenic/flowers.md):
## every kind builds a valid, indexed, upright mesh of its own height with
## stem, leaves and a petalled head; every kind is a catalog piece that
## places, saves, reopens and draws on its own batch; the old forms still
## draw as before unless `--meadow-flowers` is asked for; and the surface
## shader carries the flower look without spending a varying. Headless: no
## shader is compiled here.

const Kit := preload("res://scripts/meadow_flower_mesh.gd")
const Catalog := preload("res://scripts/native_asset_catalog.gd")
const Samples := preload("res://scripts/garden_instance_samples.gd")
## Expected height bands (m, at scale 1): the plant's tallest point.
const HEIGHTS := {"oxeye_daisy":Vector2(0.5,0.62),"buttercup":Vector2(0.3,0.4),"dandelion":Vector2(0.2,0.3),"dandelion_clock":Vector2(0.34,0.5),"cosmos":Vector2(0.85,1.0),"sunflower":Vector2(1.6,2.0),"poppy":Vector2(0.55,0.7),"lupine":Vector2(0.72,0.9),"wheat":Vector2(0.6,0.72)}
## The painterly grass tuft's tallest blade (scripts/grass_tuft_mesh.gd HEIGHT.y).
const TUFT := 0.44
const PlateFixture := preload("res://tests/fixtures/plate.gd")

var failures := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		print("FAIL: ", message)
		push_error("FAIL: " + message)

func _run() -> void:
	_meshes()
	_registration()
	_placement()
	_remap()
	_shader()
	print("Meadow flowers: ", failures, " failures")
	quit(1 if failures else 0)

func _meshes() -> void:
	check(Kit.KINDS == ["oxeye_daisy","buttercup","dandelion","dandelion_clock","cosmos","sunflower","poppy","lupine","wheat"], "The kit has the eight agreed kinds and wheat, by their catalog keys")
	for kind: String in Kit.KINDS:
		var mesh: ArrayMesh = Kit.mesh(kind)
		check(mesh.get_surface_count() == 1, kind + " is one surface")
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		check(indices.size() > 0 and indices.size() % 3 == 0, kind + " is indexed triangles")
		check(indices.size() / 3 <= 600, kind + " stays under 600 triangles (%d)" % (indices.size() / 3))
		var in_range := true
		for i in indices: in_range = in_range and i >= 0 and i < vertices.size()
		check(in_range, kind + " indices are in range")
		var box := mesh.get_aabb()
		var band: Vector2 = HEIGHTS[kind]
		check(box.end.y >= band.x and box.end.y <= band.y, kind + " stands %.2f m, in %.2f-%.2f m" % [box.end.y, band.x, band.y])
		check(box.position.y > -0.01, kind + " does not sink below its root")
		check(maxf(box.size.x, box.size.z) < box.end.y * 1.3 + 0.1, kind + " is a plant, not a mat")
		for array: int in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_CUSTOM0]:
			check(arrays[array] != null and arrays[array].size() > 0, kind + " carries vertex array %d" % array)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var unit := true
		for n in normals: unit = unit and absf(n.length() - 1.0) < 0.01
		check(unit, kind + " mass normals are unit length")
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var parts := {}
		var nods := 0
		var along_ok := true
		for i in range(vertices.size()):
			parts[int(round(uv2[i].x))] = true
			if uv2[i].y > 0.5: nods += 1
			along_ok = along_ok and uv[i].y >= 0.0 and uv[i].y <= 1.0
		check(along_ok, kind + " bend fractions lie in 0-1")
		check(parts.has(int(Kit.STEM)) and parts.has(int(Kit.LEAF)), kind + " has a stem and leaves")
		check(parts.has(int(Kit.PETAL)) or parts.has(int(Kit.PUFF)), kind + " has petals or a seed puff")
		check(nods > 0 and nods < vertices.size(), kind + " has a nodding head on a fixed stem")
		# The stem's root vertices do not move with the wind.
		var low_still := true
		for i in range(vertices.size()):
			if vertices[i].y < 0.02 and uv[i].y > 0.1: low_still = false
		check(low_still, kind + " is rooted: nothing at the ground bends")
	var tall: float = Kit.mesh("sunflower").get_aabb().end.y
	check(tall > TUFT * 3.0, "Sunflowers stand far above the grass tufts")
	check(Kit.mesh("buttercup").get_aabb().end.y < TUFT and Kit.mesh("dandelion").get_aabb().end.y < TUFT, "Buttercups and dandelions stand low, among the tufts")
	check(Kit.mesh("oxeye_daisy").get_aabb().end.y > TUFT and Kit.mesh("cosmos").get_aabb().end.y > Kit.mesh("oxeye_daisy").get_aabb().end.y, "Daisies top the tufts; cosmos tops the daisies")
	# Cosmos petals come in several colours, picked per plant by the material.
	var cosmos := Kit.material("cosmos")
	check(int(cosmos.get_shader_parameter("flower_variant_count")) >= 3, "Cosmos blooms in at least three colours")
	check(cosmos.get_shader_parameter("flower_heads") == true and cosmos.get_shader_parameter("sway_enabled") == true and cosmos.get_shader_parameter("flat_faces") == false, "The flower material sways and shades by mass, not per facet")
	check(Kit.material("buttercup").get_shader_parameter("flower_roughness") < 0.5, "Buttercup petals are glossy")

func _registration() -> void:
	for kind: String in Kit.KINDS:
		check(Catalog.PARTS.has(kind) and Catalog.PARTS[kind] == [Kit.node_name(kind)], kind + " is a catalog piece")
		check(kind in NativeTerrainData.ASSETS, kind + " can be placed")
		check(NativeDropReactions.REACTIONS.get(kind) == "sprout", kind + " sprouts when placed")
		check(kind in preload("res://scripts/fire_field.gd").FAST_ASSETS, kind + " burns fast")
		# Wheat is wind-pollinated: a crop, not a butterfly flower (docs/scenic/wheat.md).
		if not kind in Kit.RIPEN_KINDS: check(kind in preload("res://scripts/life_survey.gd").FLOWERS, kind + " draws butterflies")
		check(kind in preload("res://scripts/native_build_palette.gd").FOLIAGE, kind + " sits with the flora in the palette")
	# Old forms keep their parts, so existing worlds dress as before.
	for old: String in ["button_flower","spike_flower","umbel_flower","daisy_flower"]:
		check(Catalog.PARTS[old][0] == "flower-stems" and old in NativeTerrainData.ASSETS, old + " is unchanged")
	check(preload("res://scripts/native_flora.gd").FLOWER_KINDS == {"button":"button_flower","spike":"spike_flower","umbel":"umbel_flower","daisy":"daisy_flower"}, "Generated worlds still dress with the old forms")
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	for kind: String in Kit.KINDS:
		var node: Node3D = Catalog.source_node(source, Kit.node_name(kind))
		check(node is MeshInstance3D and (node as MeshInstance3D).mesh == Kit.mesh(kind), kind + " resolves to its kit mesh")
		check(Catalog.part_pose(kind + ":" + Kit.node_name(kind), node, Kit.mesh(kind)) == Transform3D.IDENTITY, kind + " stands on its root")
		var material: Material = Kit.mesh(kind).surface_get_material(0)
		check(material is ShaderMaterial and (material as ShaderMaterial).shader == preload("res://shaders/reference_surface.gdshader"), kind + " draws with the shared surface shader")
	source.free()
	check(Catalog.pivots().has("cosmos:" + Kit.node_name("cosmos")), "Pivots include the kit")
	var look := preload("res://scripts/scene_look.gd")
	check(look.part_role("sunflower:" + Kit.node_name("sunflower")) == 0, "Petals keep their own hue (no palette role)")
	check(look.leaf_season("poppy:" + Kit.node_name("poppy")).w > 0.0, "Winter takes the flowers")

func _flat_data() -> NativeTerrainData:
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	data.reset_flat()
	return data

func _parts() -> Array:
	var parts := {}
	var poses: Dictionary = Catalog.pivots()
	for kind in Catalog.PARTS:
		parts[kind] = []
		for node_name in Catalog.PARTS[kind]: parts[kind].append(kind + ":" + node_name)
	return [parts, poses]

func _placement() -> void:
	var data := _flat_data()
	var i := 0
	for kind: String in Kit.KINDS:
		check(data.place(kind, Vector2(-6.0 + i * 1.5, 2.0), 0.3, 1.0) >= 0, kind + " places on the plain")
		i += 1
	var document := data.to_document()
	var reopened := _flat_data()
	check(reopened.load_document(JSON.parse_string(JSON.stringify(document))), "A world with every kind saves and reopens")
	check(reopened.objects.map(func(o: Dictionary) -> String: return o.asset) == Kit.KINDS, "Every kind survives reopening")
	var pair := _parts()
	Kit.remap_override = 0
	var built: Dictionary = Samples.build(reopened, pair[0], pair[1], {})
	for kind: String in Kit.KINDS:
		var key: String = kind + ":" + Kit.node_name(kind)
		check((built.transforms[key] as Array).size() == 1, kind + " draws once on its own batch")
	Kit.remap_override = -1

func _remap() -> void:
	var data := _flat_data()
	for old: String in Kit.REMAP:
		data.place(old, Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)), 0.0, 1.0)
	# A painted meadow patch, in full bloom, on the island's north edge.
	for x in range(6): data.meadow[data.meadow_cell(Vector2(6.25 + x * 0.5, -13.75))] = 1.0
	var pair := _parts()
	Kit.remap_override = 0
	var plain: Dictionary = Samples.build(data, pair[0], pair[1], {})
	var kit_count := 0
	for kind: String in Kit.KINDS: kit_count += (plain.transforms[kind + ":" + Kit.node_name(kind)] as Array).size()
	check(kit_count == 0 and (plain.transforms["daisy_flower:flowers-daisy"] as Array).size() == 1 and (plain.transforms.petal as Array).size() > 0, "Without --meadow-flowers the old forms and meadow flowers draw as before")
	Kit.remap_override = 1
	var mapped: Dictionary = Samples.build(data, pair[0], pair[1], {})
	for old: String in Kit.REMAP:
		var kind: String = Kit.REMAP[old]
		check((mapped.transforms[kind + ":" + Kit.node_name(kind)] as Array).size() >= 1, old + " draws as " + kind + " under --meadow-flowers")
		check((mapped.transforms[old + ":" + Catalog.PARTS[old][1]] as Array).is_empty(), old + "'s old head is not drawn under --meadow-flowers")
	check((mapped.transforms.petal as Array).is_empty(), "Painted meadow flowers bloom as kit kinds under --meadow-flowers")
	Kit.remap_override = -1
	check(Kit.drift_kind(0, 0) == Kit.drift_kind(Kit.DRIFT_CELLS - 1, Kit.DRIFT_CELLS - 1), "A drift is one kind across its cells")
	var kinds := {}
	for x in range(0, 120, Kit.DRIFT_CELLS):
		for z in range(0, 120, Kit.DRIFT_CELLS): kinds[Kit.drift_kind(x, z)] = true
	check(kinds.size() >= 5 and not kinds.has("sunflower"), "Drifts vary across the meadow, without sunflowers")

func _shader() -> void:
	var text := FileAccess.get_file_as_string("res://shaders/reference_surface.gdshader")
	var varyings := 0
	for line in text.split("\n"): if line.begins_with("varying "): varyings += 1
	check(varyings <= 14, "The surface shader spends no new varying (Metal's limit; %d declared)" % varyings)
	for needle: String in ["uniform bool flower_heads", "meadow_flower.gdshaderinc", "#define ZS_FLOWER_TRANSLUCENCY", "zs_breeze_lean_at(root, flower_motion.y", "zs_breeze_offset(sway_at"]:
		check(needle in text, "The surface shader has " + needle)
	var include := FileAccess.get_file_as_string("res://shaders/meadow_flower.gdshaderinc")
	check(not "varying" in include.replace("no varyings", ""), "The flower include declares no varyings")
	check("ZS_FLOWER_TRANSLUCENCY" in FileAccess.get_file_as_string("res://shaders/reference_direct_light.gdshaderinc"), "Light adds the petal glow")
	check(not "ZS_GRASS_WAVE_STRENGTH =" in include and not "zs_wind_strength =" in include, "Flowers call the shared wind, never retune it")
