extends SceneTree
## Headless probe for seeded rock, tree and prop variety. Per seed: the rock
## character, how many stones use each shape, layered tree forms, the kinds
## dressed, dressing time and a save round trip. `old` also dresses the recipe
## without its `variety` mark and prints that digest, which must match the
## digest of tools/probe_biome_dressing.gd on main.
## godot --headless --path . -s res://tools/probe_seeded_variants.gd -- [old] [meshes] seed...
const Stones = preload("res://scripts/rock_variants.gd")
const Variety = preload("res://scripts/seeded_variety.gd")
const LayeredTree = preload("res://scripts/layered_tree.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if "meshes" in args: _meshes()
	var reference = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(reference.get_node("terrain").mesh)
	reference.free()
	var names := []
	for entry in Stones.VARIANTS: names.append(entry[0])
	for arg in args:
		if not arg.is_valid_int(): continue
		var recipe: Dictionary = preload("res://scripts/cozy_world_generator.gd").sample(int(arg)).terrain
		if "old" in args:
			var plain := recipe.duplicate(true)
			plain.erase("variety")
			await preload("res://scripts/inland_landscape.gd").new().form(data,plain)
			print("seed %d  without variety  digest %s" % [int(arg),_digest(data)])
		var t := Time.get_ticks_usec()
		await preload("res://scripts/inland_landscape.gd").new().form(data,recipe)
		var ms := (Time.get_ticks_usec()-t)/1000.0
		var world := Variety.world(data._recipe_settings)
		var stones := {}
		var layered := [0,0,0]
		var kinds := {}
		for item: Dictionary in data.objects:
			kinds[item.asset] = kinds.get(item.asset,0)+1
			if Stones.is_stone(item.asset):
				var shape: String = names[Stones.index(item,world)]
				stones[shape] = stones.get(shape,0)+1
			elif item.asset == "layered_tree":
				layered[Variety.layered_index(item,world)] += 1
		var copy := NativeTerrainData.new()
		copy.setup(data.source_mesh)
		var reloaded := copy.load_document(JSON.parse_string(JSON.stringify(data.to_document())))
		# JSON turns integers into floats, so compare what the renderer picks.
		var same := reloaded and Variety.world(copy._recipe_settings) == world and _picks(copy,world) == _picks(data,world)
		var batches := ""
		if "view" in args: batches = await _view(data)
		print("seed %d %s  %.0f ms  digest %s  reload %s\n   rocks: %s %s\n   layered forms: %s\n   %s%s" % [int(arg),preload("res://scripts/biome_blend.gd").title(recipe),ms,_digest(data),same,world.rock_style,stones,layered,kinds,batches])
	quit()

## Build the real instance batches and count the stone and tree ones.
func _view(data: NativeTerrainData) -> String:
	var view := GardenView.new()
	root.add_child(view)
	view.data = data
	var t := Time.get_ticks_usec()
	await view.rebuild(true)
	var ms := (Time.get_ticks_usec()-t)/1000.0
	var total := 0
	var stones := {}
	var layered := {}
	for batch in view._batches:
		total += 1
		var key: String = batch.get_meta("part")
		if key.begins_with("boulder") or key == "rock": stones[key.get_slice(":",1) if ":" in key else key] = batch.multimesh.instance_count
		elif key.begins_with("layered_tree:"): layered[key.get_slice(":",1)] = batch.multimesh.instance_count
	view.free()
	return "\n   view: %d batches, rebuild %.0f ms, stone batches %s, layered batches %s" % [total,ms,stones,layered]

func _picks(data: NativeTerrainData, world: Dictionary) -> Array:
	var out := []
	for item: Dictionary in data.objects:
		if Stones.is_stone(item.asset): out.append([item.asset,Stones.index(item,world),Stones.pose(item,world),Stones.color(item,null,world)])
		elif item.asset == "layered_tree": out.append([Variety.layered_index(item,world),Variety.layered_shape(item,world)])
	return out

func _digest(data: NativeTerrainData) -> String:
	return var_to_bytes([data.objects,data.grass,data.meadow,data.blades]).hex_encode().sha256_text().substr(0,12)

## Build cost and size of the shared variant meshes.
func _meshes() -> void:
	var t := Time.get_ticks_usec()
	var triangles := []
	for i in range(Stones.VARIANTS.size()):
		triangles.append(Stones.mesh(i,null).get_faces().size()/3)
	print("rock family: %d shapes in %.1f ms, triangles %s" % [Stones.VARIANTS.size(),(Time.get_ticks_usec()-t)/1000.0,triangles])
	for i in range(Stones.VARIANTS.size()):
		print("   %s %s" % [Stones.VARIANTS[i][0],Stones.mesh(i,null).get_aabb()])
	t = Time.get_ticks_usec()
	var sizes := []
	for seed_value in LayeredTree.VARIANT_SEEDS:
		var parts: Array = LayeredTree.variant_meshes(seed_value)
		sizes.append([parts[0].get_aabb().end.y,parts[1].get_aabb()])
	print("layered forms %s in %.1f ms: %s" % [LayeredTree.VARIANT_SEEDS,(Time.get_ticks_usec()-t)/1000.0,sizes])
