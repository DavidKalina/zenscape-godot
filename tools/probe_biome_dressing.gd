extends SceneTree
## Headless probe: dress generated worlds on the real terrain data and count
## what each habitat planted. `single` strips the blend, which must dress
## exactly as the one-habitat code always did (compare the digest on main).
## godot --headless --path . -s res://tools/probe_biome_dressing.gd -- [single] seed...
const PlateFixture := preload("res://tests/fixtures/plate.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var single := "single" in args
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	for arg in args:
		if not arg.is_valid_int(): continue
		var recipe: Dictionary = preload("res://scripts/cozy_world_generator.gd").sample(int(arg)).terrain
		if single: recipe.erase("blend")
		var t := Time.get_ticks_usec()
		await preload("res://scripts/inland_landscape.gd").new().form(data,recipe)
		var ms := (Time.get_ticks_usec()-t)/1000.0
		var kinds := {}
		for item in data.objects: kinds[item.asset] = kinds.get(item.asset,0)+1
		var grass := 0.0
		for value in data.grass: grass += value
		var digest := var_to_bytes([data.objects,data.grass,data.meadow,data.blades]).hex_encode().sha256_text().substr(0,12)
		var copy := NativeTerrainData.new()
		copy.setup(data.source_mesh)
		var reloaded := copy.load_document(JSON.parse_string(JSON.stringify(data.to_document())))
		print("seed %d %s  %.0f ms  grass %.2f  digest %s  reload %s\n   %s" % [int(arg),preload("res://scripts/biome_blend.gd").title(recipe),ms,grass/data.grass.size(),digest,reloaded,kinds])
	quit()
