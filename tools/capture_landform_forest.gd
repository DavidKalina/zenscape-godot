extends "res://tools/capture_clusters.gd"
## The forest landform (scripts/landform_forest.gd), rendered in the sky
## until the lower world stands it in its sea: a row of forested islands
## (one a width in --across, seeds from --seed) stood near the home as
## fixed islets (SkyIslets `make` and `stand`), then held round at noon
## and golden hour: from plane height coming in (plane), skimming the
## canopy (skim), down into the clearing (clearing), along the stream's
## valley (stream), from under the rim (rock) and the whole row from far
## off, where the trees are the far stand-ins (far). --play leaves the game
## running with them standing, to fly round by hand; --shots= and --hours=
## pick views.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_landform_forest.gd \
##     -- --no-title --out=captures/landform-forest/try1 [--across=30,60,90] [--seed=7] [--hours=noon,golden] [--play]
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const Forest = preload("res://scripts/landform_forest.gd")

## The row: its first island this far out from the home (m, tried round),
## the gap between islands (m), and their height.
const RING := 260.0
const GAP := 40.0
const HEIGHT := 4.0

var across_list: Array = [90.0,60.0,30.0]
var play := false

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--seed="): seed_base = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--shots="): shots_wanted = Array(argument.trim_prefix("--shots=").split(","))
		elif argument.begins_with("--hours="): hours_wanted = Array(argument.trim_prefix("--hours=").split(","))
		elif argument.begins_with("--across="): across_list = Array(argument.trim_prefix("--across=").split(",")).map(func(a: String) -> float: return float(a))
		elif argument == "--play": play = true
	if not "--hours=" in " ".join(OS.get_cmdline_user_args()): hours_wanted = ["noon","golden"]
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	if not play: create_timer(1500).timeout.connect(func() -> void: push_error("landform capture timed out"); quit(2))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = out.path_join("places-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	eye = scene.wanderer
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	await frames(5)
	eye._launch(6.0,false)
	var islands: Node3D = eye.islands
	for i in range(900):
		if not islands.lands.has(null): break
		await frames(1)
	_islets = islands.islets
	_parent = scene.camera.get_parent()
	var stood := _stand_row()
	if play:
		print("LANDFORM standing; fly round them (the row starts at %s)" % stood[0].home)
		return
	scene.world_clock.running = false
	eye.set_process(false)
	eye._layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for b: Dictionary in stood:
		var label := "forest-%d-%d" % [int(b.across),int(b.seed)]
		var shots := _forest_shots(b,stood)
		if not shots_wanted.is_empty(): shots = shots.filter(func(shot: Dictionary) -> bool: return shot.label in shots_wanted)
		for hour_name: String in hours_wanted:
			for shot: Dictionary in shots:
				await _hold_at(shot.eye,shot.look,hours[hour_name],50 if shot == shots[0] else 30)
				await still("%s-%s-%s" % [label,shot.label,hour_name])
			# The far stand-ins against the trees themselves, through a long
			# lens from past where they take over.
			if b == stood[0] and (shots_wanted.is_empty() or "tele" in shots_wanted):
				var out2 := Vector2(b.home.x,b.home.z).normalized()
				var tele_eye: Vector3 = b.home+Vector3(-out2.x,0.0,-out2.y)*220.0+Vector3.UP*35.0
				for near in [false,true]:
					_near_only(b,near)
					await _hold_at(tele_eye,b.home+Vector3.UP*3.0,hours[hour_name],20)
					eye.camera.fov = 16.0
					await frames(4)
					await still("%s-tele-%s-%s" % [label,"near" if near else "far",hour_name])
				_near_only(b,false)
	print("LANDFORM done")
	quit(0)

## Draws island `b`'s own trees at any distance, its stand-ins hidden
## (`near`), or as stood.
func _near_only(b: Dictionary, near: bool) -> void:
	for child: Node in (b.node as Node3D).get_children():
		if not child is MultiMeshInstance3D: continue
		var batch := child as MultiMeshInstance3D
		if batch.name.begins_with("Far_"): batch.visible = not near
		elif batch.visibility_range_end == float(b.shape.recipe.get("far_trees",-1.0)) or batch.has_meta("near_end"):
			if not batch.has_meta("near_end"): batch.set_meta("near_end",batch.visibility_range_end)
			batch.visibility_range_end = 0.0 if near else float(batch.get_meta("near_end"))

## The row of islands stood as fixed islets, each its built record with
## its width and seed; kept clear of the seeded islets.
func _stand_row() -> Array:
	var palette: Dictionary = _islets.prepare_authored()
	var way := _clear_way()
	var side := Vector2(-way.y,way.x)
	var stood: Array = []
	var along := 0.0
	for k in range(across_list.size()):
		var across: float = across_list[k]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_base*7919+k*104729
		var spec := Forest.recipe(rng,across)
		var at2 := way*RING+side*(along+across*0.5)
		along += across+GAP
		var home := Vector3(at2.x,HEIGHT,at2.y)
		var seed_value := seed_base*1000+k*37+int(across)
		var began := Time.get_ticks_msec()
		var made: Dictionary = SkyIslets.make(seed_value,spec,palette,home.y)
		var b: Dictionary = _islets.stand("Landform_forest_%d" % k,home,made)
		b.fixed = true
		b.age = SkyIslets.FADE_IN
		b.across = across
		b.seed = seed_value
		_islets.built["landform:forest:%d" % k] = b
		_islets.keep_clear.append(Vector3(home.x,home.z,float(b.shape.reach)+60.0))
		var trees := 0
		for o: Dictionary in b.shape.objects:
			if o.asset in ["tree","birch","redwood","juniper","broadleaf","willow","layered_tree"]: trees += 1
		print("LANDFORM forest %.0f m (seed %d) at %s: made in %d ms, %d records, %d trees, stream %s, glades %d" % [
			across,seed_value,home,Time.get_ticks_msec()-began,b.shape.objects.size(),trees,not (b.shape.stream as Dictionary).is_empty(),(b.shape.get_meta("glades",[]) as Array).size()])
		stood.append(b)
	# Seeded islets already standing in the row's way go.
	for key: String in _islets.built.keys():
		if key.begins_with("landform:"): continue
		var b: Dictionary = _islets.built[key]
		for k: Vector3 in _islets.keep_clear:
			if Vector2((b.home as Vector3).x-k.x,(b.home as Vector3).z-k.y).length() < k.z and not b.get("fixed",false):
				(b.node as Node3D).queue_free()
				_islets.built.erase(key)
				break
	return stood

## A way out from the home with no island's spot or range near the row.
func _clear_way() -> Vector2:
	var cells: RefCounted = _islets.cells
	for k in range(48):
		var way := Vector2.from_angle(TAU*k/48.0)
		var ok := true
		for t in range(0,6):
			var p := way*RING+Vector2(-way.y,way.x)*t*50.0
			var home := Vector3(p.x,HEIGHT,p.y)
			if not cells.spots_near(home,170.0).is_empty() or SkyPeaks.blocks(home): ok = false
		if ok: return way
	return Vector2.RIGHT

## The views round island `b` (islets' frame).
func _forest_shots(b: Dictionary, stood: Array) -> Array:
	var shape: RefCounted = b.shape
	var home: Vector3 = b.home
	var reach: float = shape.reach
	var tops := 0.0
	for c: Vector4 in shape.crowns: tops = maxf(tops,c.z+shape.ground_at(Vector2(c.x,c.y)))
	var canopy := minf(tops,14.0+shape.ground_at(Vector2.ZERO))
	var out := Vector2(home.x,home.z).normalized()
	var side := Vector2(-out.y,out.x)
	var at := func(p: Vector2, up: float) -> Vector3: return home+Vector3(p.x,up,p.y)
	var shots: Array = [
		{"label":"plane","eye":at.call(-out*reach*2.2+side*reach*0.6,reach*0.9+25.0),"look":at.call(Vector2.ZERO,2.0)},
		{"label":"skim","eye":at.call(-out*reach*1.05+side*reach*0.3,canopy+5.0),"look":at.call(out*reach*0.6,canopy*0.4)},
		{"label":"mid","eye":at.call(-out*230.0+side*60.0,45.0),"look":at.call(Vector2.ZERO,2.0)},
		{"label":"rock","eye":at.call(side*(reach+22.0),-4.0),"look":at.call(Vector2.ZERO,-float(shape.depth)*0.2)},
	]
	var clearing: Vector3 = shape.get_meta("clearing",Vector3.ZERO)
	if clearing.z > 0.0:
		var c := Vector2(clearing.x,clearing.y)
		var from := c-(c.normalized() if c.length() > 1.0 else out)*(clearing.z*0.6)
		shots.append({"label":"clearing","eye":at.call(from,shape.ground_at(c)+canopy+14.0),"look":at.call(c,shape.ground_at(c))})
	if not (shape.stream as Dictionary).is_empty():
		var course: PackedVector2Array = shape.stream.course
		var mouth := course[course.size()-1]
		var mid := course[course.size()/2]
		var back := (mouth-mid).normalized()
		shots.append({"label":"stream","eye":at.call(mouth+back*14.0,canopy+3.0),"look":at.call(mid,shape.ground_at(mid))})
	if b == stood[0]:
		var middle := Vector3.ZERO
		for s: Dictionary in stood: middle += s.home
		middle /= float(stood.size())
		var away := Vector2(middle.x,middle.z).normalized()
		shots.append({"label":"far","eye":middle+Vector3(away.x,0.0,away.y)*420.0+Vector3(side.x,0.0,side.y)*120.0+Vector3.UP*60.0,"look":middle})
		shots.append({"label":"row","eye":middle+Vector3(away.x,0.0,away.y)*160.0+Vector3.UP*70.0,"look":middle})
	return shots
