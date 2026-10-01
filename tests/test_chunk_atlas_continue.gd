extends SceneTree
## Continue (scripts/chunk_atlas_continue.gd): a chunk grown beside a range
## completes it. Each case shapes the west neighbour with a known landform,
## grows the chunk east of it as the atlas does (plain, carry-in, continue,
## pin) and reads the new chunk's heights along lines across it.
## Run: godot --headless --path . --script tests/test_chunk_atlas_continue.gd
const Atlas = preload("res://scripts/chunk_atlas.gd")
const Continue = preload("res://scripts/chunk_atlas_continue.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")
const SEAM := 1e-3
var failures := 0
var source_mesh: ArrayMesh

func check(ok: bool, message: String) -> void:
	print(("ok   " if ok else "FAIL ")+message)
	if not ok: failures += 1

func _initialize() -> void: run.call_deferred()

func chunk(atlas, slot: Vector2i) -> NativeTerrainData:
	var data := NativeTerrainData.new()
	data.setup(source_mesh)
	Genesis.shape(data,atlas.seed_value,Atlas.world_origin(slot))
	return data

## A fresh atlas whose chunk (0, 0) is a plain plus `landform(p)`, stored;
## then the chunk at (1, 0) grown beside it. Returns [atlas, grown data, plain
## heights, carried heights, summary].
func grow_beside(landform: Callable, seed_value := 4242) -> Array:
	var atlas = Atlas.new()
	atlas.seed_value = seed_value
	var west := chunk(atlas,Vector2i.ZERO)
	var heights := west.heights
	for i in range(west.points.size()): heights[i] += landform.call(west.points[i])
	west.heights = heights
	Atlas.quantize_edges(west)
	atlas.store(Vector2i.ZERO,west.to_document())
	atlas.live = Vector2i(1,0)
	var data := chunk(atlas,atlas.live)
	var plain := data.heights.duplicate()
	atlas.carry_in(atlas.live,data)
	var pin = atlas.pin_for(atlas.live,data.points)
	pin.apply(data)
	var carried := data.heights.duplicate()
	data.begin_stroke()
	var summary: Dictionary = Continue.apply(atlas,atlas.live,data,plain)
	pin.apply(data)
	data.end_stroke()
	return [atlas,data,plain,carried,summary]

## Heights of the grown chunk above its plain, on a 0.5 m raster.
func relief(data: NativeTerrainData, plain: PackedFloat32Array) -> PackedFloat32Array:
	var lifted := PackedFloat32Array()
	for i in range(plain.size()): lifted.append(data.heights[i]-plain[i])
	return Continue.raster(data.points,lifted)

## Relief at u metres in from the west seam, t along it.
func at(grid: PackedFloat32Array, u: float, t: float) -> float:
	return Continue.height_at(grid,Vector2(u-Atlas.HALF,t))

## Highest relief across the chunk's width (all t) at depth u.
func ridge_line(grid: PackedFloat32Array, u: float) -> Vector2:
	var best := Vector2(-INF,0.0)
	for k in range(-26,27):
		var value := at(grid,u,k*0.5)
		if value > best.x: best = Vector2(value,k*0.5)
	return best

func run() -> void:
	var reference = load("res://assets/zen_reference/geometry.scn").instantiate()
	source_mesh = reference.get_node("terrain").mesh
	reference.free()
	var began := Time.get_ticks_msec()
	# 1. A range along the seam, still climbing at the border: its crest lies
	# a metre past it. The new chunk should round the crest over and come down
	# the far flank.
	var flank := grow_beside(func(p: Vector2) -> float: return 8.0*exp(-pow((p.x-15.0)/4.0,2.0)))
	var grid := relief(flank[1],flank[2])
	var crest := 0.0
	for k in range(0,9): crest = maxf(crest,at(grid,k*0.5,0.0))
	var down := at(grid,10.0,0.0)
	print("flank: crest %.2f m within 4 m, %.2f m at 10 m, summary %s" % [crest,down,flank[4]])
	check(crest > 6.0,"a climbing border rounds over a crest inside the new chunk (%.2f m)" % crest)
	check(down < 0.6*crest,"the range comes down its far flank (%.2f m at 10 m)" % down)
	check(flank[0].seam_delta(flank[0].live,flank[1].heights,flank[1].points) < SEAM,"the flank's seam is shut")
	var carried_far: float = Continue.height_at(relief_from(flank[1],flank[3],flank[2]),Vector2(-14.0+2.0,0.0))
	check(carried_far >= 0.0,"undo state is the carry-in ramp")
	# 2. A crest well inside the neighbour that already falls to the border:
	# no twin ridge, the slope eases down.
	var fallen := grow_beside(func(p: Vector2) -> float: return 8.0*exp(-pow((p.x-9.0)/3.5,2.0)))
	grid = relief(fallen[1],fallen[2])
	var edge := at(grid,0.0,0.0)
	var twin := 0.0
	for k in range(4,24): twin = maxf(twin,at(grid,k*0.5,0.0))
	print("fallen: %.2f m at the seam, highest past 2 m %.2f m" % [edge,twin])
	check(twin <= edge+0.05,"a fallen slope grows no twin ridge (%.2f vs %.2f)" % [twin,edge])
	check(at(grid,8.0,0.0) < 0.5*edge+0.3,"it eases down to low ground (%.2f m at 8 m)" % at(grid,8.0,0.0))
	# A hill 10 m inside the neighbour, flat by the border, is not copied over.
	var inland := grow_beside(func(p: Vector2) -> float: return 8.0*exp(-pow((p.x-4.0)/3.0,2.0)-pow(p.y/4.0,2.0)))
	grid = relief(inland[1],inland[2])
	var copied := 0.0
	for k in range(0,57):
		for j in range(-26,27): copied = maxf(copied,at(grid,k*0.5,j*0.5))
	check(copied < 0.6,"a hill inside the neighbour is not mirrored over (%.2f m)" % copied)
	# 3. A ridge crossing the seam at a slant: in the neighbour its crest runs
	# z = 0.5·(x-14) (so it meets the seam at z = 0 and heads +z going east).
	var slant := grow_beside(func(p: Vector2) -> float: return 7.0*exp(-pow((p.y-0.5*(p.x-14.0))/2.5,2.0)))
	grid = relief(slant[1],slant[2])
	var line6 := ridge_line(grid,6.0)
	var line10 := ridge_line(grid,10.0)
	print("slant: at 6 m crest %.2f m at z %.1f, at 10 m %.2f m at z %.1f, summary %s" % [line6.x,line6.y,line10.x,line10.y,slant[4]])
	check(absf(line6.y-3.0) < 1.6,"the ridge runs on along its heading (z %.1f at 6 m, want 3)" % line6.y)
	check(line6.x > 4.0,"and still stands (%.2f m at 6 m)" % line6.x)
	check(line10.y > line6.y,"it keeps heading the same way (z %.1f at 10 m)" % line10.y)
	# 4. A plain neighbour: nothing to continue.
	var flat := grow_beside(func(_p: Vector2) -> float: return 0.0)
	check(flat[4].is_empty(),"a plain neighbour continues nothing, got %s" % [flat[4]])
	# 5. Undo lets the continued range fall back to the carry-in ramp.
	var data: NativeTerrainData = flank[1]
	check(data.undo(),"the continuation is one undo step")
	var worst := 0.0
	for i in range(data.heights.size()): worst = maxf(worst,absf(data.heights[i]-flank[3][i]))
	check(worst < 1e-4,"undo restores the carried chunk (%.5f)" % worst)
	print("test_chunk_atlas_continue: %d ms" % (Time.get_ticks_msec()-began))
	print("test_chunk_atlas_continue: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)

func relief_from(data: NativeTerrainData, heights: PackedFloat32Array, plain: PackedFloat32Array) -> PackedFloat32Array:
	var lifted := PackedFloat32Array()
	for i in range(plain.size()): lifted.append(heights[i]-plain[i])
	return Continue.raster(data.points,lifted)
