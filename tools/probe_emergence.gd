extends SceneTree
## Headless probe: raise a hill, hand it to emergence and print what arrives
## over simulated time. Also checks hand work stays untouched, that the salt
## varies the result, and that provenance survives a save round trip.
## godot --headless --path . -s res://tools/probe_emergence.gd -- [seed]
const Emergence = preload("res://scripts/emergence.gd")
const PlateFixture := preload("res://tests/fixtures/plate.gd")
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var world_seed := int(args[0]) if not args.is_empty() and args[0].is_valid_int() else 184
	var mesh: ArrayMesh = PlateFixture.mesh()
	print("-- blank plain, salt 7")
	var blank := await _world(mesh,-1)
	var a := _run(blank,7,true)
	print("-- blank plain, salt 7 again / salt 8")
	var b := _run(await _world(mesh,-1),7,false)
	var c := _run(await _world(mesh,-1),8,false)
	print("same salt same world: %s   other salt differs: %s" % [a==b,a!=c])
	print("-- generated world seed %d" % world_seed)
	var data := await _world(mesh,world_seed)
	_run(data,-1,true)
	var copy := NativeTerrainData.new()
	copy.setup(mesh)
	var loaded := copy.load_document(JSON.parse_string(JSON.stringify(data.to_document())))
	var sources := func(d: NativeTerrainData) -> Array: return d.objects.map(func(o: Dictionary) -> String: return NativeTerrainData.object_source(o))
	print("save round trip: loaded %s  provenance %s  sources %s" % [loaded,copy.provenance==data.provenance,sources.call(copy)==sources.call(data)])
	var old := data.to_document()
	old.erase("provenance")
	for item in old.objects: item.erase("source")
	print("old save without provenance loads: %s" % copy.load_document(JSON.parse_string(JSON.stringify(old))))
	quit()

func _world(mesh: ArrayMesh, world_seed: int) -> NativeTerrainData:
	var data := NativeTerrainData.new()
	data.setup(mesh)
	if world_seed < 0:
		data.reset_flat()
	else:
		var recipe: Dictionary = preload("res://scripts/cozy_world_generator.gd").sample(world_seed).terrain
		await preload("res://scripts/inland_landscape.gd").new().form(data,recipe)
	return data

## Returns a digest of what emerged.
func _run(data: NativeTerrainData, salt: int, verbose: bool) -> String:
	var emergence = Emergence.new(data,salt)
	var center := Vector2(-3.0,2.0)
	# A hand-painted patch and a hand-placed rock inside the hill's footprint.
	data.begin_stroke()
	for n in range(20): data.brush(center,4.5,0.12,"raise",0.0)
	data.paint_grass(center+Vector2(2.5,0),1.0,0.2)
	data.mark_hand(center+Vector2(2.5,0),1.0)
	var first := data.next_id
	var rock := data.place("rock",center+Vector2(-2.0,1.0))
	data.mark_objects_hand(first)
	data.end_stroke()
	var hand_cells := {}
	for i in range(data.provenance.size()):
		if data.provenance[i] == NativeTerrainData.SOURCE_HAND: hand_cells[i] = data.grass[i]
	var hand_rock := data.object_by_id(rock)
	var before := data.objects.size()
	var rect := Rect2(center-Vector2.ONE*4.5,Vector2.ONE*9.0)
	emergence.on_region_changed(rect)
	var clock := 0.0
	var steps := 0
	var slowest := 0.0
	for mark in [2.0,5.0,10.0,15.0,20.0,30.0,40.0,45.0]:
		while clock < mark:
			var s := Time.get_ticks_usec()
			if emergence.advance(0.25): steps += 1
			slowest = maxf(slowest,(Time.get_ticks_usec()-s)/1000.0)
			clock += 0.25
		if verbose: print("  t=%4.1fs  %s" % [clock,_census(data,rect,before)])
	var intact := data.object_by_id(rock) == hand_rock
	for i in hand_cells:
		if data.provenance[i] != NativeTerrainData.SOURCE_HAND or data.grass[i] != hand_cells[i]: intact = false
	if verbose: print("  habitat at centre %s, height %.1f m, refusals %s" % [emergence._blend.pick(center),float(data.ground_height(center)),emergence.refusals])
	if verbose: print("  refresh steps %d  slowest step (first plans the region) %.1f ms  busy %s  hand work intact %s" % [steps,slowest,emergence.busy(),intact])
	var emerged := data.objects.filter(func(o: Dictionary) -> bool: return o.get("source") == "emerged")
	return var_to_bytes([emerged.map(func(o: Dictionary) -> Array: return [o.asset,snappedf(o.x,0.01),snappedf(o.z,0.01)]),data.grass]).hex_encode().sha256_text().substr(0,12)

func _census(data: NativeTerrainData, rect: Rect2, before: int) -> String:
	var grass := 0.0
	var blades := 0.0
	var cells := 0
	var emerged_cells := 0
	for z in range(data.MEADOW_CELLS):
		for x in range(data.MEADOW_CELLS):
			if not rect.has_point(data.meadow_position(x,z)+Vector2.ONE*0.25): continue
			var i := z*data.MEADOW_CELLS+x
			cells += 1
			grass += data.grass[i]
			blades += data.blades[i]
			if data.provenance[i] == NativeTerrainData.SOURCE_EMERGED: emerged_cells += 1
	var kinds := {}
	for item in data.objects:
		if item.get("source") == "emerged": kinds[item.asset] = kinds.get(item.asset,0)+1
	return "grass %.2f blades %.2f emerged cells %d/%d  objects %d->%d  %s" % [grass/cells,blades/cells,emerged_cells,cells,before,data.objects.size(),kinds]
