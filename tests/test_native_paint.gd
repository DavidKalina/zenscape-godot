extends SceneTree
## The paintable tint layer: a dab colours only the ground it covers, its amount
## scales the coat, snow still caps the peaks, and undo, save and legacy saves
## all land back on byte-identical vertex colours.
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var failures := 0

func check(label: String, condition: bool) -> void:
	if not condition:
		failures += 1
	print("%s: %s" % [label,"ok" if condition else "FAIL"])

func _initialize() -> void:
	var mesh: ArrayMesh = PlateFixture.mesh()
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var centers := PackedVector2Array()
	for i in range(0,vertices.size(),3):
		centers.append(Vector2((vertices[i].x+vertices[i+1].x+vertices[i+2].x)/3.0,(vertices[i].z+vertices[i+1].z+vertices[i+2].z)/3.0))
	var data := _world(mesh)
	var base: PackedColorArray = data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check("empty layer leaves the unpainted build untouched",NativeTerrainTint.empty(data.tint) and data.tint.size() == data.meadow.size()*NativeTerrainTint.STRIDE)

	var red := Color(0.8,0.1,0.05)
	var center := Vector2(-6.0,4.0)
	data.begin_stroke()
	data.paint_tint(center,2.0,red,1.0)
	data.end_stroke()
	var dabbed: PackedColorArray = data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var inside := 0
	var leaked := 0
	var far := 0
	for face in range(centers.size()):
		var distance := centers[face].distance_to(center)
		var changed: bool = dabbed[face*3] != base[face*3]
		if changed and distance < 2.0:
			inside += 1
		if distance > 2.0+data.meadow_step()*2.0:
			far += 1
			if changed:
				leaked += 1
	check("one dab recolours the faces under the brush",inside > 20)
	check("one dab leaves every face clear of the brush alone",leaked == 0 and far > 1000)
	check("painted colour pulls the palette toward the brush",dabbed[_nearest(centers,center)*3].r > base[_nearest(centers,center)*3].r+0.05)

	var soft := _world(mesh)
	soft.paint_tint(center,2.0,red,0.15)
	var light: PackedColorArray = soft.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var near := _nearest(centers,center)*3
	check("amount scales the coat",light[near].r > base[near].r and light[near].r < dabbed[near].r)

	# A plateau half the chunk wide, raised clear of the snowline and flat enough
	# for the cap to settle, with the other half left at ground level.
	var alpine := NativeTerrainData.new()
	alpine.setup(mesh)
	alpine.reset_flat()
	for i in range(alpine.points.size()):
		alpine.heights[i] = 10.0 if alpine.points[i].x > 0.0 else 0.0
	alpine.grass.fill(1.0)
	var capped: PackedColorArray = alpine.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	alpine.paint_tint(Vector2.ZERO,40.0,red,1.0)
	var flooded: PackedColorArray = alpine.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var snow_faces := 0
	var snow_kept := 0
	var recoloured := 0
	for face in range(centers.size()):
		if _snowy(capped[face*3],alpine._face_snow[face]):
			snow_faces += 1
			if flooded[face*3] == capped[face*3]:
				snow_kept += 1
		elif flooded[face*3] != capped[face*3]:
			recoloured += 1
	check("snow still covers painted ground",snow_faces > 50 and snow_kept == snow_faces and recoloured > 1000)
	var coat := NativeTerrainTint.make(1)
	NativeTerrainTint.paint(coat,1,1.0,Vector2.ZERO,1.0,red,1.0)
	var lit := NativeTerrainTint.blend(Color(0.2,0.3,0.4),coat,0,0.03)
	var dark := NativeTerrainTint.blend(Color(0.2,0.3,0.4),coat,0,-0.03)
	check("a full coat still carries the face shimmer",NativeTerrainTint.weight_at(coat,0) == 1.0 and absf(lit.r-dark.r) > 0.05)

	# A stroke rebuilds only the faces the dabs reached, and must land on exactly
	# what rebuilding the whole chunk from the same records produces.
	var stroked := _world(mesh)
	stroked.build_mesh()
	for i in range(1,6):
		stroked.paint_tint(Vector2(-4,-4).lerp(Vector2(1,3),float(i)/5.0),1.6,red,0.4)
		stroked.build_mesh()
	var incremental: PackedColorArray = stroked.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check("a paint stroke matches a full rebuild",incremental == stroked.build_mesh(true).surface_get_arrays(0)[Mesh.ARRAY_COLOR] and incremental != base)

	data.undo()
	check("undo restores byte-identical colours",data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR] == base)
	data.redo()
	check("redo repaints byte-identical colours",data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR] == dabbed)

	var document: Variant = JSON.parse_string(JSON.stringify(data.to_document(),"",true,true))
	var reopened := _world(mesh)
	var roundtrip: bool = reopened.load_document(document)
	check("painted garden round trips through JSON",roundtrip and reopened.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR] == dabbed)

	var clean := _world(mesh)
	var empty_doc: Variant = JSON.parse_string(JSON.stringify(clean.to_document(),"",true,true))
	var blank_data := _world(mesh)
	check("empty layer round trips",blank_data.load_document(empty_doc) and NativeTerrainTint.empty(blank_data.tint) and blank_data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR] == base)

	var legacy: Dictionary = document.duplicate(true)
	legacy.version = 8
	legacy.erase("tint")
	var old := _world(mesh)
	check("gardens saved before the Paint tool load unpainted",old.load_document(legacy) and NativeTerrainTint.empty(old.tint) and old.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR] == base)

	var bad: Dictionary = document.duplicate(true)
	bad.tint[3] = 2.0
	var before: Dictionary = reopened.to_document()
	check("out-of-range tint rejects atomically",not reopened.load_document(bad) and reopened.to_document() == before)

	print("Native paint: %d failures" % failures)
	quit(1 if failures else 0)

## A sculpted range with full ground cover, so rock, grass and snow all appear.
func _world(mesh: ArrayMesh) -> NativeTerrainData:
	var data := NativeTerrainData.new()
	data.setup(mesh)
	data.reset_flat()
	data.form_range()
	data.grass.fill(1.0)
	return data

## Mesh colours are stored as bytes, so a snow cap matches its palette entry only
## to within a quantisation step.
func _snowy(color: Color, snow: Color) -> bool:
	return absf(color.r-snow.r) < 0.01 and absf(color.g-snow.g) < 0.01 and absf(color.b-snow.b) < 0.01

func _nearest(centers: PackedVector2Array, point: Vector2) -> int:
	var best := 0
	for face in range(centers.size()):
		if centers[face].distance_squared_to(point) < centers[best].distance_squared_to(point):
			best = face
	return best
