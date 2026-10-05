extends SceneTree
## Chunk atlas seams (scripts/chunk_atlas.gd): a land stroke across a pinned
## border leaves no seam, the pin only touches the band, corners where two
## neighbours meet agree, and the atlas survives a save and load.
const Atlas = preload("res://scripts/chunk_atlas.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")
const SEAM := 1e-3
var failures := 0
var source_mesh: ArrayMesh

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: run.call_deferred()

func chunk(atlas, slot: Vector2i) -> NativeTerrainData:
	var data := NativeTerrainData.new()
	data.setup(source_mesh)
	Genesis.shape(data,atlas.seed_value,Atlas.world_origin(slot),false)
	return data

## A few seconds of land brush dragged along a line, pinned after every step as
## the editor's refresh does.
func stroke(data: NativeTerrainData, pin, from: Vector2, to: Vector2, lower := false) -> float:
	var brush = preload("res://scripts/land_brush.gd").new()
	brush.prepare(data,7)
	brush.begin()
	var worst := 0.0
	for step in range(90):
		var point := from.lerp(to,step/89.0)
		brush.dab(data,point,4.5,1.0/30.0,lower,10.0)
		if pin != null: worst = maxf(worst,pin.apply(data))
	return worst

func run() -> void:
	var reference = load("res://assets/zen_reference/geometry.scn").instantiate()
	source_mesh = reference.get_node("terrain").mesh
	reference.free()
	var atlas = Atlas.new()
	atlas.seed_value = 4242
	var points: PackedVector2Array
	# The first chunk: a hill raised hard against its east border.
	var first := chunk(atlas,Vector2i.ZERO)
	points = first.points
	var edges := Atlas.edge_ids(points)
	for side in edges: check(not (-1 in edges[side]),"side %s has all %d samples" % [side,Atlas.SAMPLES])
	stroke(first,null,Vector2(9,-10),Vector2(12,10))
	Atlas.quantize_edges(first)
	atlas.store(Vector2i.ZERO,first.to_document())
	# East of it: a fresh plain, pinned, then a stroke dragged across the seam.
	atlas.live = Vector2i(1,0)
	var second := chunk(atlas,atlas.live)
	var raw_seam: float = atlas.seam_delta(atlas.live,second.heights,points)
	var pin = atlas.pin_for(atlas.live,points)
	check(pin.strips.keys() == ["w"],"the east chunk is pinned on its west side only, got %s" % [pin.strips.keys()])
	var before := second.heights.duplicate()
	pin.apply(second)
	var band: float = Atlas.BAND_FRAC*Atlas.SIZE
	var outside_moved := 0.0
	for i in range(points.size()):
		if points[i].x+Atlas.HALF > band: outside_moved = maxf(outside_moved,absf(second.heights[i]-before[i]))
	check(outside_moved == 0.0,"the pin moved ground outside its band by %f" % outside_moved)
	var again := second.heights.duplicate()
	check(pin.apply(second) == 0.0 and second.heights == again,"applying the pin twice changes nothing")
	var closed: float = stroke(second,pin,Vector2(-10,-12),Vector2(-(Atlas.HALF-0.5),12))
	stroke(second,pin,Vector2(-6,4),Vector2(-Atlas.HALF,4),true)
	var seam: float = atlas.seam_delta(atlas.live,second.heights,points)
	print("seam: raw plain %.5f, largest offset closed during strokes %.4f, after strokes %.6f" % [raw_seam,closed,seam])
	check(seam < SEAM,"seam after a stroke across the border is %f" % seam)
	check(closed > 0.05,"the stroke really pushed the border (closed %f)" % closed)
	Atlas.quantize_edges(second)
	atlas.store(atlas.live,second.to_document())
	# North of the first chunk, then the square touching all three: its south
	# and west strips meet at one corner shared by (0,0), (1,0) and (0,1).
	atlas.live = Vector2i(0,1)
	var third := chunk(atlas,atlas.live)
	var third_pin = atlas.pin_for(atlas.live,points)
	third_pin.apply(third)
	stroke(third,third_pin,Vector2(10,13),Vector2(13,-13))
	Atlas.quantize_edges(third)
	atlas.store(atlas.live,third.to_document())
	check(atlas.seam_delta(Vector2i(0,1),third.heights,points) < SEAM,"north chunk seam")
	atlas.live = Vector2i(1,1)
	var corner_strips: Dictionary = atlas.strips_for(atlas.live,points)
	check(corner_strips.has("s") and corner_strips.has("w"),"the corner chunk honours south and west")
	check(absf(corner_strips.s[0]-corner_strips.w[Atlas.SAMPLES-1]) < SEAM,"south and west strips agree at their shared corner")
	var fourth := chunk(atlas,atlas.live)
	var fourth_pin = atlas.pin_for(atlas.live,points)
	fourth_pin.apply(fourth)
	stroke(fourth,fourth_pin,Vector2(-Atlas.HALF,Atlas.HALF),Vector2(0,0))
	var corner_seam: float = atlas.seam_delta(atlas.live,fourth.heights,points)
	print("corner chunk seam %.6f" % corner_seam)
	check(corner_seam < SEAM,"corner chunk seam is %f" % corner_seam)
	atlas.store(atlas.live,fourth.to_document())
	# Frontier: orthogonal squares only, never the diagonal-only ones.
	var frontier: Array = atlas.frontier()
	check(frontier.size() == 8 and not atlas.has(Vector2i(2,2)) and Vector2i(2,2) not in frontier,"frontier of a 2x2 block has 8 squares, got %s" % [frontier])
	# Save and load.
	var path := "user://test-chunk-atlas/atlas.json"
	check(atlas.save(path),"atlas saves")
	var loaded = Atlas.new()
	check(loaded.load(path),"atlas loads")
	check(loaded.live == atlas.live and loaded.seed_value == atlas.seed_value and loaded.slots.size() == 4,"live slot, seed and slot count survive")
	for slot: Vector2i in atlas.slots:
		var data := NativeTerrainData.new()
		data.setup(source_mesh)
		check(data.load_document(loaded.slots[slot].document),"slot %s document loads into terrain data" % slot)
		var reference_data := NativeTerrainData.new()
		reference_data.setup(source_mesh)
		reference_data.load_document(atlas.slots[slot].document)
		var worst := 0.0
		for i in range(data.heights.size()): worst = maxf(worst,absf(data.heights[i]-reference_data.heights[i]))
		check(worst < 1e-6,"slot %s heights round-trip (worst %f)" % [slot,worst])
	check(loaded.seam_delta(Vector2i(1,0),PackedFloat32Array(loaded.slots[Vector2i(1,0)].document.heights),points) < SEAM,"a loaded chunk still meets its neighbours")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check_carry_and_cover(atlas)
	check_genes()
	print("test_chunk_atlas: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)

## A fresh chunk beside a hill carries it further in than the 5 m pin would,
## and its cover reaches the neighbour's at the seam.
func check_carry_and_cover(atlas) -> void:
	var west := chunk(atlas,Vector2i(5,0))
	stroke(west,null,Vector2(9,-10),Vector2(Atlas.HALF-0.5,10))
	var grass := west.grass
	for z in range(west.MEADOW_CELLS): grass[z*west.MEADOW_CELLS+west.MEADOW_CELLS-1] = 0.25
	west.grass = grass
	Atlas.quantize_edges(west)
	atlas.live = Vector2i(6,0)
	atlas.store(Vector2i(5,0),west.to_document())
	var fresh := chunk(atlas,Vector2i(6,0))
	var plain_heights := fresh.heights.duplicate()
	var widest: float = atlas.carry_in(Vector2i(6,0),fresh)
	check(widest > Atlas.BAND_FRAC*Atlas.SIZE,"a hill widens the carried band (%.1f m)" % widest)
	var raised := 0.0
	for id in range(fresh.points.size()):
		if absf(fresh.points[id].x-(-Atlas.HALF+7.0)) < 0.7: raised = maxf(raised,fresh.heights[id]-plain_heights[id])
	print("carry band %.1f m, raised 7 m in by %.2f m" % [widest,raised])
	check(raised > 0.15,"the hill runs 7 m into the new chunk, past the 5 m pin band (%.2f m)" % raised)
	check(atlas.seam_delta(Vector2i(6,0),fresh.heights,fresh.points) < SEAM,"carry-in leaves the seam shut")
	var cells: int = fresh.MEADOW_CELLS
	var edge_grass: float = fresh.grass[10*cells]
	var inner_grass: float = fresh.grass[10*cells+cells-1]
	check(absf(edge_grass-0.25) < 0.05,"cover at the seam takes the neighbour's (%.3f)" % edge_grass)
	check(absf(inner_grass-0.25) > 0.05,"cover past the blend band is the chunk's own (%.3f)" % inner_grass)

## Neighbour votes: ringed by mountains, a regenerated chunk is mostly mountain.
func check_genes() -> void:
	var Genes = preload("res://scripts/chunk_atlas_genes.gd")
	var mountain := {"kind":"inland","version":7,"seed":11,"composition":"mountain","archetype":"range","landform":"original","biome":"alpine","relief":1.2,"breadth":1.0}
	var near: Array = [{"slot":Vector2i(1,0),"weight":1.0,"recipe":mountain},{"slot":Vector2i(0,1),"weight":1.0,"recipe":mountain}]
	var mountains := 0
	for seed_value in range(8):
		var world: Dictionary = Genes.sample_near(seed_value*37+5,near)
		if world.terrain.composition == "mountain": mountains += 1
		check(NativeTerrainRecipe.valid(world.terrain),"seed %d gives a valid recipe" % seed_value)
	print("mountain neighbours -> %d of 8 regenerated chunks are mountain" % mountains)
	check(mountains >= 5,"mountain country carries on (%d of 8)" % mountains)
