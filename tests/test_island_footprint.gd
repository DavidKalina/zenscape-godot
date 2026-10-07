extends SceneTree
## Irregular islands, phase 2: what asks whether a point is on the island
## follows its outline (NativeTerrainData `has_land`, `nearest_land`). The
## wanderer walks off the shore, not the square's edge, and is never clamped
## or landed onto air; a glider claims an island only over its land (or just
## above its shore); a square island answers as the square always did.
const Genesis = preload("res://scripts/genesis_canvas.gd")
const WandererEye = preload("res://scripts/wanderer_eye.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const Plate = preload("res://scripts/plate.gd")
## Whole metres inside the rim, each way, for grid walks over the plate.
const INSIDE := int(Plate.HALF)-1

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	print(("OK   " if ok else "FAIL ")+message)

func plate() -> NativeTerrainData:
	var data := NativeTerrainData.new()
	data.setup(preload("res://scripts/plate_mesh.gd").build())
	return data

func eye_on(data: NativeTerrainData) -> Node:
	var editor := NativeChunkEditor.new()
	editor.data = data
	var eye: Node = WandererEye.new()
	eye.editor = editor
	return eye

## A bare editor's pond preview is parented only by `setup`: free it too.
func drop(editor: NativeChunkEditor) -> void:
	editor.pond_preview.free()
	editor.free()

## A seed's island whose bays reach into the square: a bay point inside
## +-13 m, and the walk's direction from the middle to it.
func bay_of(data: NativeTerrainData) -> Vector2:
	for k in range(72):
		var way := Vector2.from_angle(TAU*k/72.0)
		var run := 0.0
		while run < Plate.HALF-1.0 and data.has_land(way*run): run += 0.05
		if run < Plate.HALF-2.0: return way
	return Vector2.INF

func run() -> void:
	var data := plate()
	Genesis.shape(data,77)
	check(not data.outline.is_empty(),"The seed's island is outlined")
	var eye := eye_on(data)
	var way := bay_of(data)
	check(way != Vector2.INF,"The island has a bay inside the square")
	helper(data)
	walking(data,eye,way)
	placing(data,eye)
	claiming(data,way)
	square()
	drop(eye.editor)
	eye.free()
	await process_frame
	print("ISLAND FOOTPRINT failures=",failures)
	quit(1 if failures else 0)

func helper(data: NativeTerrainData) -> void:
	check(data.has_land(Vector2.ZERO),"The middle is land")
	check(not data.has_land(Vector2(50.0,0.0)),"Off the plate is no land")
	var out := Vector2.INF
	for x in range(-INSIDE,INSIDE+1):
		for z in range(-INSIDE,INSIDE+1):
			if not data.has_land(Vector2(x,z)): out = Vector2(x,z)
	var near := data.nearest_land(out,0.3)
	check(near != Vector2.INF and data.has_land(near),"The nearest land to a bay point is land")
	check(data.nearest_land(near,0.0) == near,"Land is its own nearest")
	var depth: Variant = data.sample(near,data.shore_distance)
	check(depth != null and float(depth) >= 0.3-0.001,"The nearest land keeps its inset")

func walking(data: NativeTerrainData, eye: Node, way: Vector2) -> void:
	var at := Vector2.ZERO
	var launched := Vector2.INF
	var steps := 0
	while steps < 600:
		var next := at+way*0.05
		if eye._off_plate(next):
			launched = next
			break
		at = next
		steps += 1
	check(launched != Vector2.INF and absf(launched.x) < Plate.HALF-0.5 and absf(launched.y) < Plate.HALF-0.5,"Walking into the bay goes off the island at the shore, inside the square (%s)" % launched)
	check(data.has_land(at) and not eye._off_plate(at),"The step before is land, and the walker is still on the plate")
	var held: Vector3 = eye._clamped(Vector3(launched.x,0.0,launched.y))
	check(data.has_land(Vector2(held.x,held.z)),"The no-glide clamp puts the walker on land")
	var far: Vector3 = eye._clamped(Vector3(40.0,0.0,40.0))
	check(data.has_land(Vector2(far.x,far.z)),"A point far off is clamped onto land")

func placing(data: NativeTerrainData, eye: Node) -> void:
	var bad := 0
	var checked := 0
	for x in range(-INSIDE,INSIDE+1,2):
		for z in range(-INSIDE,INSIDE+1,2):
			var p := Vector3(x,0.0,z)
			var down: Vector3 = eye._clamped(eye._free_spot(eye._clamped(p)))
			checked += 1
			if not data.has_land(Vector2(down.x,down.z)): bad += 1
	check(bad == 0,"Landing anywhere over the plate puts the feet on land (%d of %d on air)" % [bad,checked])
	var free_ok := true
	for x in range(-INSIDE-1,INSIDE+2):
		for z in range(-INSIDE-1,INSIDE+2):
			if eye._free(Vector2(x,z)) and not data.has_land(Vector2(x,z)): free_ok = false
	check(free_ok,"No free spot is over air")

func claiming(data: NativeTerrainData, way: Vector2) -> void:
	var islands: Node3D = SkyIslands.new()
	var editor := NativeChunkEditor.new()
	editor.terrain = MeshInstance3D.new()
	root.add_child(editor.terrain)
	islands.editor = editor
	islands.offsets.append(Vector3(100.0,5.0,0.0))
	islands._rise.append(Vector3.ZERO)
	islands.lands.append(data)
	# A bay point inside the square, further than the claim margin from land.
	var bay := Vector2.INF
	for x in range(-INSIDE,INSIDE+1):
		for z in range(-INSIDE,INSIDE+1):
			if data.nearest_land(Vector2(x,z),0.0,SkyIslands.CLAIM_MARGIN+0.5) == Vector2.INF: bay = Vector2(x,z)
	var shore := Vector2.ZERO
	var run := 0.0
	while data.has_land(way*run): run += 0.05
	shore = way*(run-0.5)
	var over := func(p: Vector2) -> int: return islands.copy_under(Vector3(100.0+p.x,20.0,p.y))
	check(over.call(Vector2.ZERO) == 0,"A glider over the land claims the island")
	check(bay != Vector2.INF and over.call(bay) == -1,"Over a bay, inside the square, it does not")
	check(over.call(shore) == 0,"Over the land by the shore it does")
	check(not data.has_land(way*(run+0.4)) and over.call(way*(run+0.4)) == 0,"Just past the shore, within the margin, it still does")
	check(over.call(Vector2(Plate.HALF+1.0,0.0)) == -1,"Past the square it does not")
	islands.free()
	editor.terrain.free()
	drop(editor)

func square() -> void:
	# A plate without an outline of its own is the 28 m square island.
	var data := plate()
	const EDGE := Plate.LEGACY_HALF
	check(data.outline == data.square_outline() and data.has_land(Vector2(EDGE-0.1,-(EDGE-0.1))),"A square island is land to its corners")
	check(data.nearest_land(Vector2(10.0,2.0),0.5) == Vector2(10.0,2.0),"A square island's nearest land inside it is the point itself")
	var outside := data.nearest_land(Vector2(30.0,2.0),0.5)
	check(data.has_land(outside) and absf(outside.x-(EDGE-0.5)) < 0.25,"From outside, the nearest land is at its side (%s)" % outside)
	var eye := eye_on(data)
	check(not eye._off_plate(Vector2(EDGE-0.2,-(EDGE-0.2))) and eye._off_plate(Vector2(EDGE+0.1,0.0)) and eye._off_plate(Vector2(0.0,-(EDGE+0.1))),"A square walk goes off at its sides, +-14")
	var held: Vector3 = eye._clamped(Vector3(Plate.HALF+6.0,0.0,-(Plate.HALF+6.0)))
	check(absf(held.x-EDGE) < 0.4 and absf(held.z+EDGE) < 0.4 and data.has_land(Vector2(held.x,held.z)),"A square clamp is the square, at its corner (%s)" % held)
	var islands: Node3D = SkyIslands.new()
	var editor := NativeChunkEditor.new()
	editor.terrain = MeshInstance3D.new()
	root.add_child(editor.terrain)
	islands.editor = editor
	islands.offsets.append(Vector3.ZERO)
	islands._rise.append(Vector3.ZERO)
	islands.lands.append(data)
	check(islands.copy_under(Vector3(EDGE-0.1,0.0,-(EDGE-0.1))) == 0 and islands.copy_under(Vector3(EDGE+SkyIslands.CLAIM_MARGIN+0.3,0.0,0.0)) == -1,"A square island claims anywhere inside +-14 m, and not past its margin")
	islands.free()
	editor.terrain.free()
	drop(editor)
	drop(eye.editor)
	eye.free()
