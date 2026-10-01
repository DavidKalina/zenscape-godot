extends SceneTree
## Writes a one-chunk atlas for trying Continue (scripts/chunk_atlas_continue.gd)
## in the game: a ridged range climbs to the east border of chunk (0, 0), and
## a spur leaves through its north border at a slant. Then press the right or
## up arrow to grow the next chunk and watch it carry the land on.
## Also grows east and north here and writes a shaded height map of the three
## chunks, so the continuation can be judged without the GPU.
## Run: godot --headless --path . --script tools/make_atlas_continue_demo.gd -- [--out=PATH] [--map=PNG]
## Then: ./run-cozy-flow.command --atlas --atlas-file=PATH
const Atlas = preload("res://scripts/chunk_atlas.gd")
const Continue = preload("res://scripts/chunk_atlas_continue.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")

func _initialize() -> void: run.call_deferred()

func arg(name: String, fallback: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(name+"="): return value.trim_prefix(name+"=")
	return fallback

## The demo landform, metres above the plain at a chunk-local point.
static func landform(p: Vector2) -> float:
	var crests := FastNoiseLite.new()
	crests.seed = 9
	crests.frequency = 0.16
	var rough := FastNoiseLite.new()
	rough.seed = 23
	rough.frequency = 0.35
	# The range: its crest wanders a metre either side of x = 15, just past
	# the east border, and rises and dips along its length.
	var crest_x := 15.0+1.2*crests.get_noise_2d(0.0,p.y)
	var crest_h := 9.0+2.5*crests.get_noise_2d(40.0,p.y)
	var across := (p.x-crest_x)/4.2
	var range_height := crest_h*exp(-across*across)*(1.0+0.12*rough.get_noise_2d(p.x,p.y))
	# The spur: a ridge leaving through the north border heading north-west,
	# from the range's foot.
	var along := Vector2(-0.45,-1.0).normalized()
	var start := Vector2(6.0,2.0)
	var t := (p-start).dot(along)
	var off := (p-start).dot(Vector2(along.y,-along.x))
	var spur := 0.0
	if t > -4.0: spur = 5.5*smoothstep(-4.0,6.0,t)*exp(-pow(off/2.2,2.0))
	return maxf(range_height,spur)

func run() -> void:
	var reference = load("res://assets/zen_reference/geometry.scn").instantiate()
	var source_mesh: ArrayMesh = reference.get_node("terrain").mesh
	reference.free()
	var out := arg("--out","user://cozy-worlds/atlas-continue-demo.json")
	var map := arg("--map","")
	var atlas = Atlas.new()
	atlas.seed_value = 4242
	var first := NativeTerrainData.new()
	first.setup(source_mesh)
	Genesis.shape(first,atlas.seed_value,Vector2.ZERO)
	var heights := first.heights
	for i in range(first.points.size()): heights[i] += landform(first.points[i])
	first.heights = heights
	Atlas.quantize_edges(first)
	atlas.store(Vector2i.ZERO,first.to_document())
	atlas.live = Vector2i.ZERO
	if not atlas.save(out):
		push_error("could not write %s" % out)
		quit(1)
		return
	print("demo atlas: %s" % ProjectSettings.globalize_path(out))
	if map != "":
		var grown := {Vector2i.ZERO:first}
		for slot in [Vector2i(1,0),Vector2i(0,1)]:
			atlas.live = slot
			var data := NativeTerrainData.new()
			data.setup(source_mesh)
			Genesis.shape(data,atlas.seed_value,Atlas.world_origin(slot))
			var plain := data.heights.duplicate()
			atlas.carry_in(slot,data)
			var pin = atlas.pin_for(slot,data.points)
			pin.apply(data)
			if not "--carry-only" in OS.get_cmdline_user_args():
				print("%s continued: %s" % [slot,Continue.apply(atlas,slot,data,plain)])
				pin.apply(data)
			print("%s seam %.5f" % [slot,atlas.seam_delta(slot,data.heights,data.points)])
			Atlas.quantize_edges(data)
			atlas.store(slot,data.to_document())
			grown[slot] = data
		shade(grown,map)
	quit()

## A hillshade of the chunks on a 2 x 2 sheet, 8 px a metre, light from the
## north-west, with faint seam lines.
func shade(grown: Dictionary, path: String) -> void:
	const PX := 8
	var size := int(Atlas.SIZE)*PX
	var image := Image.create(size*2,size*2,false,Image.FORMAT_RGB8)
	image.fill(Color(0.1,0.1,0.12))
	var light := Vector3(-1.0,1.4,-1.0).normalized()
	for slot: Vector2i in grown:
		var grid := Continue.raster(grown[slot].points,grown[slot].heights)
		var left := slot.x*size
		var top := (1-slot.y)*size
		for y in range(size):
			for x in range(size):
				var p := Vector2((x+0.5)/PX-Atlas.HALF,(y+0.5)/PX-Atlas.HALF)
				var h := Continue.height_at(grid,p)
				var dx := Continue.height_at(grid,p+Vector2(0.25,0))-Continue.height_at(grid,p-Vector2(0.25,0))
				var dz := Continue.height_at(grid,p+Vector2(0,0.25))-Continue.height_at(grid,p-Vector2(0,0.25))
				var normal := Vector3(-dx/0.5,1.0,-dz/0.5).normalized()
				var lit := clampf(normal.dot(light),0.0,1.0)
				var tone := clampf(h/12.0,0.0,1.0)
				var base := Color(0.32,0.5,0.26).lerp(Color(0.62,0.58,0.52),tone)
				var colour := base*(0.35+0.85*lit)
				if x == 0 or y == 0: colour = colour.lerp(Color.WHITE,0.25)
				image.set_pixel(left+x,top+y,colour)
	image.save_png(path)
	print("map: %s" % path)
