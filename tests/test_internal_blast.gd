extends SceneTree
const Internal = preload("res://scripts/internal_blast.gd")
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: "+message)
func run() -> void:
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	data.reset_flat()
	for i in range(data.points.size()): data.heights[i] = 2.0+maxf(0.0,12.0-data.points[i].length()*1.4)
	var before := data.heights.duplicate()
	var colors: PackedColorArray = data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check(Internal.rupture(data,Vector3(0,14,0),4,colors).is_empty(),"Surface blast retains the existing crater/landslide behavior")
	data.begin_stroke()
	var origin := Vector3(0,5,0)
	var result := Internal.rupture(data,origin,4,colors)
	check(not result.is_empty(),"A charge inside the mountain fractures its surrounding cap")
	if result.is_empty(): quit(1); return
	check(result.before==before,"Ejected chunks include the initial blast material instead of only later slide debris")
	var sectors := {}
	var outward := true
	var lifted := 0
	for chunk: Dictionary in result.chunks:
		var offset: Vector3 = chunk.center-origin
		if Vector2(offset.x,offset.z).length()>0.2:
			sectors[Vector2i(1 if offset.x>0 else -1,1 if offset.z>0 else -1)] = true
			outward = outward and Vector2(offset.x,offset.z).dot(Vector2(chunk.velocity.x,chunk.velocity.z))>0
		outward = outward and chunk.delay==0.0
		if chunk.velocity.y>2: lifted += 1
	check(sectors.size()==4,"The center charge ejects rock on every side, not a single chosen face")
	check(outward and lifted>result.chunks.size()/2,"Rock launches immediately outward and upward before falling")
	check(result.chunks.size()<=32,"Inside-out fracture stays within the existing chunk budget")
	check(data.ground_height(Vector2.ZERO)>11,"A medium charge preserves most of the mountain summit")
	var areas := preload("res://scripts/mountain_collapse.gd").control_areas(data)
	var medium_volume := 0.0
	for i in range(before.size()): medium_volume += (before[i]-data.heights[i])*areas[i]
	check(medium_volume<=pow(4,3)*1.5+0.001,"Fractured rock stays within the charge volume budget")
	check(result.chunks.all(func(chunk: Dictionary) -> bool: return chunk.mesh.get_aabb().size.y<5.0),"Moderate charges eject smaller rock sections")
	data.end_stroke()
	check(data.undo() and data.heights==before,"Undo restores the exact unbroken cap")
	check(Internal.rupture(data,origin,1,colors).is_empty() and data.heights==before,"A tiny deeply buried charge cannot remove the entire mountain")
	var large := Internal.rupture(data,origin,6,colors)
	var large_volume := 0.0
	for i in range(before.size()): large_volume += (before[i]-data.heights[i])*areas[i]
	check(not large.is_empty() and large_volume>medium_volume*2,"Large charges retain substantially stronger destruction")
	print("Internal blasts: ",failures," failures")
	quit(1 if failures else 0)
