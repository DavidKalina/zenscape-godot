extends SceneTree
## Worlds saved on the 28 m plate (document versions 3-11, the authored
## mesh's template) load into the middle of the 48 m plate unchanged in
## shape and content (scripts/plate_migration.gd), and a migrated world saves
## and loads again as it is.

const Plate = preload("res://scripts/plate.gd")
const Migration = preload("res://scripts/plate_migration.gd")

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print(("OK   " if ok else "FAIL ")+message)
	if not ok:
		failures += 1
		push_error(message)

func plate() -> NativeTerrainData:
	var data := NativeTerrainData.new()
	data.setup(preload("res://scripts/plate_mesh.gd").build())
	return data

## The 28 m plate as old worlds were saved against it.
func legacy() -> NativeTerrainData:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh,[],false)
	source.free()
	return data

func run() -> void:
	var old := legacy()
	check(Migration.legacy_template() == old._template_id(),"The legacy template is the authored mesh's")
	check(plate()._template_id() != old._template_id(),"The made plate is not the authored one")
	for version in [3,4,5,8,9,10,11]:
		land(old,version,false)
	land(old,11,true)
	recipe(old)
	state()
	refused(old)
	quit(1 if failures > 0 else 0)

func area(data: NativeTerrainData, mask: PackedByteArray) -> float:
	var total := 0.0
	for f in range(mask.size()):
		if mask[f] != 0: continue
		var a := data.points[data.vertex_ids[f*3]]
		var b := data.points[data.vertex_ids[f*3+1]]
		var c := data.points[data.vertex_ids[f*3+2]]
		total += absf((b-a).cross(c-a))*0.5
	return total

## A world as the old loader read version `version`: a hill, painted cover,
## objects, a pond, a fence, live water, a forest wish and (version 11) an
## outline.
func document(old: NativeTerrainData, version: int, outlined: bool) -> Dictionary:
	var cells := Migration.LEGACY_COVER*Migration.LEGACY_COVER
	var heights := []
	for i in range(old.points.size()):
		heights.append(0.4+3.0*maxf(0.0,1.0-old.points[i].distance_to(Vector2(3.0,-2.0))/6.0))
	var meadow := []
	var grass := []
	var blades := []
	var tint := []
	var provenance := PackedByteArray()
	for k in range(cells):
		meadow.append(float(k%7)/7.0)
		grass.append(float(k%5)/5.0)
		blades.append(float(k%3)/3.0)
		tint.append_array([0.2,0.3,0.4,float(k%4)/4.0])
		provenance.append(k%3)
	var wish := PackedFloat32Array()
	wish.resize(cells)
	for k in range(cells): wish[k] = float(k%11)/11.0-0.5
	var depth := PackedFloat32Array()
	depth.resize(112*112)
	depth[60*112+50] = 0.5
	var made := {"version":version,"template":old._template_id(),"blank":true,"heights":heights,"meadow":meadow,"grass":grass,"blades":blades,"next_id":4,
		"objects":[{"id":1,"asset":"tree","x":3.0,"z":-2.0,"angle":0.5,"scale":1.0},{"id":2,"asset":"rock","x":-12.5,"z":12.0,"angle":0.0,"scale":1.2}],
		"ponds":[{"x":-6.0,"z":5.0,"level":0.9}],"tunnels":[],"source_replacements":[]}
	if version >= 6: made.terrain_recipe = {}
	if version >= 7:
		made.streams = []
		made.fences = [{"id":3,"posts":[-4.0,-4.0,-4.0,4.0],"closed":false}]
	if version >= 8: made.landscape_waterfall = false
	if version >= 9: made.tint = tint
	if version >= 10:
		made.provenance = provenance.hex_encode()
		made.intent_forest = preload("res://scripts/land_intent.gd").encode(wish)
		made.water_flow = {"cell":0.25,"width":112,"height":112,"springs":[{"x":1.0,"z":2.0,"rate":0.5,"radius":0.5}],"depth":Marshalls.raw_to_base64(depth.to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE))}
	if outlined:
		var mask := PackedByteArray()
		mask.resize(old.vertex_ids.size()/3)
		for f in range(mask.size()): mask[f] = 0 if old._face_center[f].distance_to(Vector2(1.0,0.5)) < 10.0 else 1
		made.outline = Marshalls.raw_to_base64(mask.compress(FileAccess.COMPRESSION_DEFLATE))
	return made

func land(old: NativeTerrainData, version: int, outlined: bool) -> void:
	var name := "v%d%s" % [version," with an outline" if outlined else ""]
	var saved: Dictionary = JSON.parse_string(JSON.stringify(document(old,version,outlined)))
	var data := plate()
	check(Migration.needs(saved),name+" is a 28 m document")
	check(data.load_document(saved),name+" loads into the 48 m plate")
	if failures > 0 and not data.load_document(saved): return
	# Shape: the same land in the same place.
	var was := PackedByteArray()
	was.resize(old.vertex_ids.size()/3)
	if outlined: was = old._decode_outline(saved.outline)
	var before := area(old,was)
	var after := data.land_area()
	check(absf(after-before) < before*0.03,"%s keeps its land's area (%.1f m² then, %.1f now)" % [name,before,after])
	if not outlined: check(data.land_rect().is_equal_approx(Rect2(-14,-14,28,28)),name+" is the old 28 m square, edges straight")
	var worst := 0.0
	var olds := PackedFloat32Array(saved.heights)
	for p: Vector2 in [Vector2(3,-2),Vector2(0,0),Vector2(-10.3,7.7),Vector2(13.5,-13.5),Vector2(5.2,4.4)]:
		if not data.has_land(p): continue
		worst = maxf(worst,absf(float(data.height_at(p.x,p.y))-float(old.sample(p,olds))))
	check(worst < 0.25,"%s keeps its heights (worst %.3f m between the meshes' facets)" % [name,worst])
	var exact := 0.0
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		if maxf(absf(p.x),absf(p.y)) < 14.0: exact = maxf(exact,absf(data.heights[i]-float(old.sample(p,olds))))
	check(exact < 0.0001,name+" puts each new point at the old ground's height there")
	# Content, cell by cell at the same metres.
	var cover_ok := true
	for k: int in [0,57,1000,3135]:
		var x := k%56
		var z := k/56
		var middle := Vector2(x,z)*0.5-Vector2.ONE*14.0+Vector2.ONE*0.25
		var cell := data.meadow_cell(middle)
		cover_ok = cover_ok and is_equal_approx(data.meadow[cell],float(saved.meadow[k])) and is_equal_approx(data.grass[cell],float(saved.grass[k]) if version != 3 else 0.0)
		if version >= 9: cover_ok = cover_ok and is_equal_approx(NativeTerrainTint.weight_at(data.tint,cell),float(k%4)/4.0)
		if version >= 10: cover_ok = cover_ok and data.provenance[cell] == k%3
	check(cover_ok,name+" keeps meadow, grass, tint and provenance at the same metres")
	check(data.meadow[0] == 0.0 and data.meadow[data.meadow.size()-1] == 0.0,name+" has no cover off the old square")
	check(data.objects.size() == 2 and data.objects[1].x == -12.5 and data.objects[1].z == 12.0,name+" keeps its objects where they stood")
	check(data.ponds.size() == 1 and data.ponds[0].x == -6.0,name+" keeps its pond")
	if version >= 7: check(data.fences.size() == 1,name+" keeps its fence")
	if version >= 10:
		var migrated: Dictionary = Migration.migrate(saved,data)
		var flow: Variant = preload("res://scripts/water_flow.gd").decode(migrated.water_flow)
		check(flow != null and flow.width == 192 and flow.depth[(60+40)*192+50+40] == 0.5 and flow.springs[0].x == 1.0,name+" keeps its water at the same metres")
		var wish: Variant = preload("res://scripts/land_intent.gd").decode(migrated.intent_forest,Plate.COVER_CELLS*Plate.COVER_CELLS)
		check(wish != null and is_equal_approx(wish[(1+20)*96+(1+20)],float(57%11)/11.0-0.5),name+" keeps its forest wish at the same metres")
	# Saved again: a version-12 document of this plate, which reads back as is.
	var again: Dictionary = JSON.parse_string(JSON.stringify(data.to_document()))
	check(again.version == 12 and again.has("outline") and not Migration.needs(again),name+" saves as version 12 with its outline")
	var reread := plate()
	check(reread.load_document(again) and reread.heights == data.heights and reread.outline == data.outline and reread.meadow == data.meadow,name+" reads back after saving")

## A landscape made from a recipe keeps the recipe's own heights at the new
## points, and what was sculpted into it.
func recipe(old: NativeTerrainData) -> void:
	var settings := {"kind":"foundation","elevation":1.0,"relief":1.0}
	var samples := preload("res://scripts/native_recipe_samples.gd")
	var heights: PackedFloat32Array = samples.build(settings,old.points,PackedFloat64Array(),PackedFloat64Array(),false).heights
	for i in range(heights.size()):
		if maxf(absf(old.points[i].x),absf(old.points[i].y)) > 13.9999: heights[i] = 0.6
		if old.points[i].distance_to(Vector2(-4,4)) < 3.0: heights[i] += 2.0
	var saved := document(old,10,false)
	saved.heights = Array(heights)
	saved.terrain_recipe = preload("res://scripts/native_terrain_recipe.gd").encode(settings)
	saved = JSON.parse_string(JSON.stringify(saved))
	var data := plate()
	check(data.load_document(saved),"A recipe landscape loads")
	var fresh: PackedFloat32Array = samples.build(settings,data.points,PackedFloat64Array(),PackedFloat64Array(),false).heights
	var untouched := 0.0
	var sculpted := 0.0
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		if maxf(absf(p.x),absf(p.y)) > 12.0: continue
		var d := p.distance_to(Vector2(-4,4))
		if d > 4.0: untouched = maxf(untouched,absf(data.heights[i]-fresh[i]))
		elif d < 2.0: sculpted = maxf(sculpted,absf(data.heights[i]-fresh[i]-2.0))
	check(untouched < 0.0001,"Its untouched ground is the recipe's own (worst %.5f m)" % untouched)
	check(sculpted < 0.0001,"What was sculpted into it comes over (worst %.5f m)" % sculpted)

## Scene state kept by cover cell moves with the land; birds' slots do not.
func state() -> void:
	var cell := 22*56+33
	var saved := {"land_life":{"version":1,"clock":5.0,"sites":{"bird":[[2,0.0,1.0,true]],"firefly":[[cell,0.0,1.0,false]]},"ponds":[[cell,3.0]]},
		"fire":{"cells":PackedInt32Array([cell]).to_byte_array().hex_encode(),"memory_cells":PackedInt32Array([cell,0]).to_byte_array().hex_encode()}}
	var made := Migration.migrate_state(saved)
	var moved := (22+20)*96+33+20
	check(made.land_life.sites.firefly[0][0] == moved and made.land_life.sites.bird[0][0] == 2,"Life's sites move with the land, birds keep their slots")
	check(made.land_life.ponds[0][0] == moved,"Ponds keep their ages at the same metres")
	check(made.fire.cells.hex_decode().to_int32_array() == PackedInt32Array([moved]) and made.fire.memory_cells.hex_decode().to_int32_array() == PackedInt32Array([moved,20*96+20]),"The fire's cells move with the land")
	var data := plate()
	var at := Vector2(33,22)*0.5-Vector2.ONE*14.0+Vector2.ONE*0.25
	check(data.meadow_cell(at) == moved,"A moved cell is the cell at the same metres")

## What the old loader refused is still refused.
func refused(old: NativeTerrainData) -> void:
	var data := plate()
	var short := document(old,10,false)
	short.heights.pop_back()
	check(not data.load_document(short),"A document with the wrong number of heights is refused")
	var foreign := document(old,10,false)
	foreign.template = "0".repeat(64)
	check(not Migration.needs(foreign) and not data.load_document(foreign),"A document of another plate is refused")
	var landless := document(old,11,false)
	var none := PackedByteArray()
	none.resize(old.vertex_ids.size()/3)
	none.fill(1)
	landless.outline = Marshalls.raw_to_base64(none.compress(FileAccess.COMPRESSION_DEFLATE))
	check(not data.load_document(landless),"An outline with no land is refused")
