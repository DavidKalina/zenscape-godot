extends SceneTree
const Plate = preload("res://scripts/plate.gd")
## The cover map's texels a side: 0.5 m ones over the plate's map.
const TEXELS := roundi(Plate.MAP_HALF*4.0)
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func reference(data: NativeTerrainData) -> PackedByteArray:
	var image := Image.create(TEXELS,TEXELS,false,Image.FORMAT_RF)
	for y in range(TEXELS):
		for x in range(TEXELS):
			var point := Vector2((x+0.5)*0.5-Plate.MAP_HALF,(y+0.5)*0.5-Plate.MAP_HALF)
			var value := 0.0
			for tree in data.objects:
				if tree.asset != "redwood" or data._recipe_settings.get("biome","") != "redwood": continue
				var radius: float = clampf(tree.scale*3.5,1.5,6.0)
				value = maxf(value,1.0-smoothstep(0.1,1.0,point.distance_to(Vector2(tree.x,tree.z))/radius))
			image.set_pixel(x,y,Color(value,0,0,1))
	return image.get_data()

func run() -> void:
	var data := NativeTerrainData.new()
	data._recipe_settings = {"biome":"redwood"}
	data.objects.assign([
		{"id":1,"asset":"redwood","x":-Plate.MAP_HALF+0.2,"z":Plate.MAP_HALF-0.1,"scale":0.2},
		{"id":2,"asset":"redwood","x":0.0,"z":0.0,"scale":1.1},
		{"id":3,"asset":"redwood","x":1.4,"z":-0.7,"scale":3.0},
		{"id":4,"asset":"redwood","x":Plate.MAP_HALF+6.0,"z":0.0,"scale":0.5}])
	var mist = preload("res://scripts/redwood_biome_mist.gd").new()
	mist._cover(data)
	check(mist.cover_image.get_data() == reference(data),"Cover matches full-grid reference")
	var texture: ImageTexture = mist.cover
	data.objects.append({"id":5,"asset":"rock","x":2.0,"z":3.0,"scale":1.0})
	mist._cover(data)
	check(mist.cover == texture,"Placing a rock preserves the redwood cover texture")
	data.objects.back().x = 4.0
	mist._cover(data)
	check(mist.cover == texture,"Dragging a rock preserves the redwood cover texture")
	data.objects[1].x = -2.3
	data.objects[1].scale = 0.6
	mist._cover(data)
	check(mist.cover_image.get_data() == reference(data),"Moving and resizing a redwood matches reference")
	data.objects.remove_at(0)
	mist._cover(data)
	check(mist.cover_image.get_data() == reference(data),"Removing a redwood clears its old footprint")
	data._recipe_settings.biome = "meadow"
	mist._cover(data)
	check(mist.redwoods == 0 and mist.cover_image.get_data() == reference(data),"Leaving the redwood biome clears cover")
	mist.free()
	print("Redwood cover cache: %d failures" % failures)
	quit(1 if failures else 0)
