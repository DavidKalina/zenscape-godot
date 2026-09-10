extends SceneTree
const Collapse = preload("res://scripts/mountain_collapse.gd")
const Blast = preload("res://scripts/terrain_blast.gd")
const Presets = preload("res://scripts/native_landscape_presets.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: "+message)

func summit(data: NativeTerrainData) -> Vector3:
	var peak := 0
	for i in range(data.heights.size()):
		if data.heights[i]>data.heights[peak]: peak = i
	return Vector3(data.points[peak].x,data.heights[peak],data.points[peak].y)

func run() -> void:
	root.size = Vector2i(1440,960)
	create_timer(150).timeout.connect(func() -> void: quit(2))
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.reset_flat()
	data.heights.fill(2)
	var original := data.heights.duplicate()
	Blast.carve_native(data,Vector3(0,2,0),3.5)
	var crater := data.heights.duplicate()
	check(Collapse.collapse(data,original,Vector3(0,2,0),3.5).is_empty() and data.heights == crater,"Flat terrain receives a crater without a mountain collapse")
	for family in ["cone","horn","plateau","ridgeback"]:
		await Presets.form(data,family)
		var top := summit(data)
		original = data.heights.duplicate()
		check(Collapse.collapse(data,original,top,3.5).is_empty(),family+": intact mountain does not collapse spontaneously")
		data.begin_stroke()
		var before := data._snapshot()
		Blast.carve_native(data,top,3.5)
		var result := Collapse.collapse(data,original,top,3.5)
		check(not result.is_empty(),family+": summit explosion triggers a slide")
		if result.is_empty(): continue
		check(absf(result.removed_volume-result.deposited_volume)<0.001,family+": displaced rock volume is deposited downhill")
		var beyond := 0
		var raised := 0
		var removed_y := 0.0
		var deposited_y := 0.0
		var areas := Collapse.control_areas(data)
		for i in range(data.heights.size()):
			var change: float = result.before[i]-result.after[i]
			if change>0.15 and data.points[i].distance_to(Vector2(top.x,top.z))>3.5: beyond += 1
			if change < -0.1: raised += 1
			removed_y += maxf(0,change)*areas[i]*result.before[i]
			deposited_y += maxf(0,-change)*areas[i]*result.after[i]
		check(beyond>5,family+": failure spreads past the crater into connected mountainside")
		check(raised>5 and removed_y>deposited_y,family+": gravity lowers the displaced mass and builds a rubble toe")
		check(result.chunks.size()>3 and result.chunks.size()<=Collapse.MAX_CHUNKS,family+": detached terrain produces bounded solid chunks")
		data.end_stroke()
		check(data.undo() and data._snapshot() == before,family+": blast and landslide undo as one exact transaction")
		var shoulder := Vector2(top.x+1.0,top.z+0.5)
		var shoulder_origin := Vector3(shoulder.x,data.ground_height(shoulder),shoulder.y)
		original = data.heights.duplicate()
		Blast.carve_native(data,shoulder_origin,3.5)
		check(not Collapse.collapse(data,original,shoulder_origin,3.5).is_empty(),family+": a blast beside the summit also triggers collapse")
	await _main_game()
	print("Mountain collapse: ",failures," failures")
	quit(1 if failures else 0)

func _main_game() -> void:
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/mountain-collapse-test-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	var editor: NativeChunkEditor = scene._chunk_editor
	await editor.form_landscape("horn","alpine",false,37)
	var top := summit(editor.data)
	# Find a supporting patch affected by gravity but outside the initial blast,
	# then put a real scene prop on it before detonating through the UI controller.
	var pristine := editor.data._snapshot()
	var original := editor.data.heights.duplicate()
	Blast.carve_native(editor.data,top,3.5)
	var preview := Collapse.collapse(editor.data,original,top,3.5)
	var victim_point: Variant = null
	for i in range(editor.data.points.size()):
		var p := editor.data.points[i]
		if absf(preview.before[i]-preview.after[i]) < 0.2: continue
		if Blast.impulse(top,Vector3(p.x,original[i],p.y),3.5) == Vector3.ZERO:
			victim_point = p
			break
	editor.data._restore(pristine)
	check(victim_point != null,"Slide reaches scenery beyond the direct explosion")
	var victim := editor.data.place("rock",victim_point,0,0.5) if victim_point != null else -1
	var id := editor.data.place("explosive",Vector2(top.x,top.z))
	editor.data.update_object(id,{"blast_radius":3.5})
	editor.refresh()
	var before := editor.data.to_document()
	scene.set_building(false)
	var remote = editor.explosives
	remote.target_id = id
	remote.request_detonation()
	while remote.requested or remote.firing: await process_frame
	check(remote.collapse_count == 1,"Main-game remote triggers a summit collapse")
	check(victim>0 and editor.data.object_by_id(victim).is_empty(),"Downhill scenery joins the collapse outside the direct blast radius")
	var chunks: Array = remote.bodies.filter(func(body: RigidBody3D) -> bool: return body.has_meta("mountain_chunk"))
	check(chunks.size()>3,"Real mountain chunks enter the main-game physics world")
	var starts: Array[Vector3] = []
	for body: RigidBody3D in chunks: starts.append(body.global_position)
	check(chunks.any(func(body: RigidBody3D) -> bool: return body.has_meta("collapse_velocity") and body.freeze),"Rock separates in a staggered collapse after the initial flash")
	# Pausing must not release the hanging slabs or advance their collapse clock.
	scene._paused = true
	var clock_before: float = remote._elapsed
	for i in range(15): await physics_frame
	check(remote._elapsed == clock_before and chunks.all(func(body: RigidBody3D) -> bool: return body.freeze),"Pause holds the whole collapse in place")
	scene._paused = false
	for i in range(120): await physics_frame
	var fallen := 0
	for i in range(chunks.size()):
		if chunks[i].global_position.y < starts[i].y-0.3: fallen += 1
	check(fallen>chunks.size()/3,"Detached mountain sections actually fall downhill under gravity")
	check(remote.bodies.size()<=remote.MAX_BODIES,"Collapse shares the existing debris budget")
	check(scene.save_current(),"Collapsed mountain saves in the ordinary world format")
	# Saving flushes props knocked loose by debris; redo restores that saved state.
	var damaged := editor.data.to_document()
	remote.restore_button.pressed.emit()
	await process_frame
	check(editor.data.to_document() == before and remote.bodies.is_empty(),"Undo restores the exact original peak and clears all falling rock")
	editor.redo()
	check(editor.data.to_document() == damaged,"Redo restores the landslide and deposited rubble")
	check(editor.data.load_document(damaged),"Collapsed terrain reloads with its permanent rubble deposits")
	scene.free()
	await create_timer(0.25).timeout
