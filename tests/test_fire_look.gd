extends SceneTree
## FireLook: per-instance char/burn on the real flora batches, the snag swap
## keeping its soot, and the ground picking up the field's scorch. Renders the
## fidelity scene, so run it with --rendering-method forward_plus, not headless.

var failures := 0
var scene: Node3D = null
var editor: NativeChunkEditor = null
var field: FireField = null
var look: FireLook = null
var viewport: SubViewport = null

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
		print("FAIL: ",message)
	else:
		print("PASS: ",message)

func rendered() -> Image:
	for i in range(5):
		RenderingServer.force_draw(false)
		await process_frame
	return viewport.get_texture().get_image()

## Mean linear luminance of a box around a world point, which is how a charred
## canopy is compared with the green one it replaced.
func brightness(image: Image, point: Vector3, reach := 0.5) -> float:
	# The box is sized from the world, not from pixels: `reach` metres either
	# side of the point along the camera's own right vector, so the sample stays
	# inside the crown whatever the viewport ends up being.
	var center: Vector2 = scene.camera.unproject_position(point)
	var span: float = absf(scene.camera.unproject_position(point+scene.camera.global_basis.x*reach).x-center.x)
	var half := Vector2i(int(maxf(4.0,span)),int(maxf(4.0,span*1.6)))
	var sum := 0.0
	var count := 0
	for y in range(int(center.y)-half.y,int(center.y)+half.y):
		for x in range(int(center.x)-half.x,int(center.x)+half.x):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var pixel := image.get_pixel(x,y)
			sum += 0.30*pixel.r+0.55*pixel.g+0.15*pixel.b
			count += 1
	return sum/maxf(1.0,float(count))

## Every part instance of one record, as (batch part key, custom data).
func custom_of(id: int) -> Array:
	var result := []
	for batch: MultiMeshInstance3D in editor.content._batches:
		var key: String = batch.get_meta("part")
		var sources: Array = editor.content._sources.get(key,[])
		for i in range(sources.size()):
			var item: Variant = sources[i].item
			if item != null and int(item.id) == id:
				result.append([key,batch.multimesh.get_instance_custom_data(i)])
	return result

## Has the terrain mesh stopped reading green where the fire burnt?
func ash_reads_grey() -> bool:
	var arrays: Array = editor.terrain.mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		if Vector2(vertices[i].x,vertices[i].z).length() < 0.4 and colors[i].g <= colors[i].r:
			return true
	return false

func tick(seconds: float, paused := false) -> void:
	for frame in range(roundi(seconds*60.0)):
		field.advance(1.0/60.0,paused)
		look.advance(1.0/60.0,paused)

func run() -> void:
	create_timer(110).timeout.connect(func() -> void: push_error("FAIL: fire look test timed out"); quit(2))
	root.size = Vector2i(1280,800)
	# A fixed SubViewport keeps the pixel comparison reproducible whatever size
	# the window ends up at on this display.
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = load("res://studies/fidelity.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene._paused = true
	scene._ui.hide()
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.publish()
	editor = scene._chunk_editor
	editor.start_flat()
	var data := editor.data
	data.grass.fill(0.85)
	data.meadow.fill(0.35)
	var tree_id := data.place("tree",Vector2(0.0,0.0),0.0,1.25)
	var tuft_id := data.place("grass_tuft",Vector2(1.4,0.6),0.0,1.0)
	check(tree_id > 0 and tuft_id > 0,"Scene accepts a tree and a grass tuft")
	editor.refresh()
	await process_frame

	# 1. Custom data exists everywhere and starts at the untouched look.
	var custom_batches := 0
	var dirty := 0
	for batch: MultiMeshInstance3D in editor.content._batches:
		if not batch.multimesh.use_custom_data:
			continue
		custom_batches += 1
		for i in range(batch.multimesh.instance_count):
			if batch.multimesh.get_instance_custom_data(i) != Color(0.0,0.0,0.0,0.0):
				dirty += 1
	check(custom_batches == editor.content._batches.size(),"Every flora and prop batch carries custom data")
	check(dirty == 0,"An unburnt world is custom data (0,0,0,0) everywhere")
	check(custom_of(tree_id).size() >= 2,"The tree indexes both its trunk and its canopy")

	scene.target = Vector3(0.0,2.6,0.0)
	scene.distance = 11.0
	scene.yaw = 1.8893
	scene.polar = 1.05
	scene._update_camera()
	var canopy_point := Vector3(0.0,3.4,0.0)
	var green_image: Image = await rendered()
	var green: float = brightness(green_image,canopy_point)
	if "--debug" in OS.get_cmdline_user_args():
		green_image.save_png("/private/tmp/fire-look-green.png")
		print("CANOPY SCREEN ",scene.camera.unproject_position(canopy_point)," image ",green_image.get_size())

	# 2. Ignite under the tree and let it char.
	field = FireField.new()
	field.setup(data,Callable(),Callable(),Callable(),11)
	look = FireLook.new()
	look.setup(field,editor.content)
	look.ground_refresh = false
	field.ignite(Vector3(0.0,0.0,0.0),0.8,1.0)
	tick(1.0)
	check(field.objects_state.has(tree_id),"Ignition under the trunk lights the tree")
	tick(9.0)
	var burning := custom_of(tree_id)
	var char_now := 0.0
	var burn_now := 0.0
	var trunk_charred := false
	for entry: Array in burning:
		var value: Color = entry[1]
		char_now = maxf(char_now,value.r)
		burn_now = maxf(burn_now,value.g)
		if entry[0] == "trunk":
			trunk_charred = value.r > 0.0
	check(char_now > 0.1 and char_now < 0.9,"Ten seconds in, the tree is browning but not spent: char="+str(char_now))
	check(burn_now > 0.5,"A burning tree carries live ember heat: burn="+str(burn_now))
	check(trunk_charred,"The trunk receives the same char as the canopy")
	check(editor.content.object_fire(tuft_id) == Vector2.ZERO or field.objects_state.has(tuft_id),"Untouched neighbours keep custom data at zero")

	# 3. Pause freezes the paint but keeps republishing it.
	var frozen: Vector2 = editor.content.object_fire(tree_id)
	tick(2.0,true)
	check(editor.content.object_fire(tree_id) == frozen,"Paused frames republish without advancing the burn")

	# 4. A rebuild in the middle of a burn comes back charred.
	editor.content.rebuild(true)
	var after_rebuild := custom_of(tree_id)
	var kept := 0.0
	for entry: Array in after_rebuild:
		kept = maxf(kept,entry[1].r)
	check(absf(kept-frozen.x) < 0.001,"A rebuild mid-burn restores the char it had: "+str(kept))

	# 5. The char paint darkens the crown; the ember lifts it back up. Measured
	#    at char 0.40, still a full crown: past 0.5 the canopy thins and the
	#    bright meadow behind it would be what the sample actually read.
	editor.content.set_object_fire(tree_id,0.40,0.0)
	var burnt_image: Image = await rendered()
	var burnt: float = brightness(burnt_image,canopy_point)
	check(burnt < green*0.80,"A charred canopy renders darker than the green one: %.4f -> %.4f" % [green,burnt])
	editor.content.set_object_fire(tree_id,0.40,1.0)
	var lit_image: Image = await rendered()
	var lit: float = brightness(lit_image,canopy_point)
	check(lit > burnt*1.15,"Embers read bright by albedo with bloom off under Balanced: %.4f -> %.4f" % [burnt,lit])
	if "--debug" in OS.get_cmdline_user_args():
		burnt_image.save_png("/private/tmp/fire-look-burnt.png")
		lit_image.save_png("/private/tmp/fire-look-lit.png")

	# 6. Burn out into a snag that is not freshly cut.
	tick(40.0)
	var record := data.object_by_id(tree_id)
	check(record.get("asset","") == "snag","Forty seconds of burning leaves a snag")
	check(record.has("tint"),"The snag arrives with the field's charcoal tint")
	check(editor.content.object_fire(tree_id) == Vector2(1.0,0.0),"A settled snag is custom data (1, 0), fully charred and no longer alight")

	# 7. The field writes cover and tint but bumps no revision, so the terrain
	#    keeps rendering green until somebody asks it to look again.
	var cell := field.cell_at(Vector3(0.0,0.0,0.0))
	check(data.grass[cell] < 0.85,"The field zeroed the cover under the fire")
	var k := cell*NativeTerrainTint.STRIDE
	check(data.tint[k+3] > 0.5,"The field painted ash into the tint layer")
	check(not ash_reads_grey(),"The field's ground writes alone leave the terrain mesh untouched")
	look.ground_refresh = true
	look.refresh_ground()
	check(ash_reads_grey(),"refresh_ground rebuilds the terrain, so the scorched cells stop reading green")

	var snag := custom_of(tree_id)
	var snag_char := 0.0
	for entry: Array in snag:
		snag_char = maxf(snag_char,entry[1].r)
	check(not snag.is_empty() and is_equal_approx(snag_char,1.0),"The rebuilt snag renders charred, not freshly cut")
	check(data.object_by_id(tuft_id).is_empty() and editor.content.object_fire(tuft_id) == Vector2.ZERO,"Burnt-away plants leave no stale custom data")

	print("FIRE LOOK: failures=",failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
