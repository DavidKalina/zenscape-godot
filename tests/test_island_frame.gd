extends SceneTree
## The cameras frame the island's land, not the plate (scripts/island_frame.gd):
## the old 28 m square keeps the reaches it always had; a small island off
## the plate's middle is centred and filled by the overview, and the shell's
## camera pans over it and a little past its shore, no further; a crescent's
## landing middle is on its land; and the biggest island still fits.
## Headless: geometry and poses only.
const IslandFrame = preload("res://scripts/island_frame.gd")
const Rig = preload("res://scripts/camera_rig.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print(("OK   " if ok else "FAIL ")+message)
	if not ok: failures += 1

## Faces whose middle lies within `radius` of `at` (and not within `hole`
## of `hole_at`) are land.
static func disc(data: NativeTerrainData, at: Vector2, radius: float, hole := 0.0, hole_at := Vector2.ZERO) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(data._face_center.size())
	for f in range(mask.size()):
		var c: Vector2 = data._face_center[f]
		mask[f] = 0 if c.distance_to(at) <= radius and (hole <= 0.0 or c.distance_to(hole_at) > hole) else 1
	return mask

static func near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a-b) <= eps

func run() -> void:
	var data := NativeTerrainData.new()
	data.setup(preload("res://scripts/plate_mesh.gd").build())
	data.set_outline(PackedByteArray())
	var square := IslandFrame.rect(data)
	check(square.position.is_equal_approx(Vector2(-14,-14)) and square.size.is_equal_approx(Vector2(28,28)),"The old square's land is ±14 m (%s)" % str(square))
	check(near(IslandFrame.scale(data),1.0) and IslandFrame.centre(data).is_zero_approx(),"It is the scale and middle every camera was tuned on")
	var pan := IslandFrame.reach(data,Rig.PAN_INSET,Rig.PAN_STRETCH,Rig.PAN_ROOM)
	check(near(pan.position.x,-18.9) and near(pan.end.y,18.9),"The shell's pan keeps its old 18.9 m reach on it (%s)" % str(pan))
	var watch := IslandFrame.reach(data,0.5)
	check(near(watch.end.x,13.5) and near(watch.position.y,-13.5),"The watch's reach is the old 13.5 m (%s)" % str(watch))

	data.set_outline(disc(data,Vector2(8,-6),5.0))
	var small := IslandFrame.rect(data)
	check(small.get_center().distance_to(Vector2(8,-6)) < 0.5 and small.size.x < 11.5,"A 10 m island off the middle is read where it stands (%s)" % str(small))
	check(IslandFrame.scale(data) < 0.4,"Its scale is a third of the old square's (%.2f)" % IslandFrame.scale(data))
	pan = IslandFrame.reach(data,Rig.PAN_INSET,Rig.PAN_STRETCH,Rig.PAN_ROOM)
	check(pan.encloses(small.grow(Rig.PAN_ROOM-0.01)) and not pan.has_point(Vector2(-14,14)),"The pan reaches PAN_ROOM past its shore, and not the plate's far side (%s)" % str(pan))
	var held := IslandFrame.clamp_local(Vector3(24,3,24),pan)
	check(pan.grow(0.001).has_point(Vector2(held.x,held.z)) and held.y == 3.0,"A pivot far off is put back over it, at its own height")

	data.set_outline(disc(data,Vector2(0,0),12.0,8.0,Vector2(-6,0)))
	var middle := IslandFrame.middle(data)
	check(not data.has_land(IslandFrame.centre(data)) and data.has_land(middle),"A crescent's landing middle is on its land (%s)" % str(middle))

	data.set_outline(disc(data,Vector2.ZERO,22.5))
	var big := IslandFrame.rect(data)
	check(big.size.x > 43.0 and IslandFrame.scale(data) > 1.5,"A 44 m island scales the framing up (%.2f)" % IslandFrame.scale(data))

	await _scene()
	print("PASS: island frame" if failures == 0 else "FAIL: island frame (%d)" % failures)
	quit(1 if failures else 0)

## The live shell: the overview frames a small island off the middle, and
## the shell's camera keeps its pivot over it.
func _scene() -> void:
	var scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/island-frame-%d/places.json" % Time.get_ticks_usec()
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	var waited := 0
	while not (scene.places_ready and scene.shell_ready) and waited < 3000:
		await process_frame
		waited += 1
	var editor: NativeChunkEditor = scene._chunk_editor
	var data := editor.data
	data.set_outline(PackedByteArray())
	editor.refresh()
	await process_frame
	scene._frame_diorama()
	var square_distance: float = scene.distance
	check(Vector2(scene.target.x,scene.target.z).is_zero_approx(),"On the old square the overview looks at the middle")
	data.set_outline(disc(data,Vector2(8,-6),5.0))
	editor.refresh()
	await process_frame
	scene._frame_diorama()
	var aim := editor.terrain.to_local(scene.to_global(scene.target))
	check(Vector2(aim.x,aim.z).distance_to(IslandFrame.centre(data)) < 0.01,"The overview looks at the small island's middle (%.1f, %.1f)" % [aim.x,aim.z])
	check(scene.distance < square_distance*0.6,"And comes in close (%.1f m, the square's %.1f m)" % [scene.distance,square_distance])
	# The land and the rock hung under it, as the overview fits them: on
	# screen, and filling it one way or the other.
	var screen := Vector2(root.size)
	var outside := 0
	var spread := Rect2()
	var first := true
	var island: Array[Vector3] = []
	for i in range(data.points.size()):
		if data.shore_distance[i] < 0.0: continue
		var p: Vector2 = data.points[i]
		var h: Variant = data.ground_height(p)
		island.append(editor.terrain.to_global(Vector3(p.x,float(h) if h != null else 0.0,p.y)))
	for vertex: Vector3 in editor._skirt.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: island.append(editor._skirt.to_global(vertex))
	for point: Vector3 in island:
		var at: Vector2 = scene.camera.unproject_position(point)
		if not Rect2(Vector2.ZERO,screen).has_point(at): outside += 1
		spread = Rect2(at,Vector2.ZERO) if first else spread.expand(at)
		first = false
	var share := maxf(spread.size.x/screen.x,spread.size.y/screen.y)
	check(not first and outside == 0 and share > 0.5,"The island and its rock are all on screen and fill %.0f %% of it one way" % (share*100.0))
	var rig: Node = scene.camera_rig
	if rig != null:
		var far: Vector3 = rig._on_plate(editor.terrain.to_global(Vector3(-24,0,24)))
		var local := editor.terrain.to_local(far)
		var reach := IslandFrame.reach(data,Rig.PAN_INSET,Rig.PAN_STRETCH,Rig.PAN_ROOM)
		check(reach.grow(0.001).has_point(Vector2(local.x,local.z)) and Vector2(local.x,local.z).distance_to(Vector2(-24,24)) > 20.0,"The shell's camera pans no further than just past its shore (%.1f, %.1f)" % [local.x,local.z])
	else: check(false,"The shell has its camera rig")
	scene.queue_free()
	await process_frame
