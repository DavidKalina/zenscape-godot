extends SceneTree
## Headless probe of a place's continuity (docs/scenic/PLAN.md, Phase 3):
## the forest wish and life survive a save and load, old saves still load and
## settle, the plain's day turns and eases through the night, and emerged trees
## get an arrival puff. Uses a temporary places folder, never the player's.
##   godot --headless --path . -s res://tools/probe_world_continuity.gd -- --native-kernels
var scene: Node3D
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	print("CONTINUITY %s %s %s" % ["PASS" if ok else "FAIL",label,JSON.stringify(detail)])
	if not ok: failures += 1

func wait(seconds: float) -> void:
	var until := Time.get_ticks_usec()+int(seconds*1000000.0)
	while Time.get_ticks_usec() < until: await process_frame

func present(life: Node3D) -> Dictionary:
	var counts := {}
	for kind in life.sites: counts[kind] = life.present(kind).size()
	return counts

func run() -> void:
	create_timer(110).timeout.connect(func() -> void: push_error("Continuity probe timed out"); quit(2))
	root.size = Vector2i(1280,800)
	var folder := "/private/tmp/zs-continuity-probe-%d" % Time.get_ticks_usec()
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = folder.path_join("places.json")
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	var places: Node = scene.places
	var editor: NativeChunkEditor = scene._chunk_editor
	var data := editor.data
	var life: Node3D = scene.land_life
	var clock: WorldClock = scene.world_clock
	editor.set_process_input(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	life.pace = 8.0

	# 3. The plain's day turns, gently, and eases through the night.
	check("plain day turns",places.plain and clock.running and is_equal_approx(clock.day_length,places.PLAIN_DAY_LENGTH),{"plain":places.plain,"running":clock.running,"day_length":clock.day_length})
	var before := clock.hour
	await wait(2.0)
	var rate := fposmod(clock.hour-before,24.0)/2.0*3600.0
	check("plain hour rate",rate > 40.0 and rate < 100.0,{"world_seconds_per_second":snappedf(rate,0.1)})
	scene._celestial.set_phase(0.805)
	var began := Time.get_ticks_usec()
	var darkest := 1.0
	while clock.phase > 0.5 or clock.phase < 0.195:
		darkest = minf(darkest,clock.daylight)
		await process_frame
		if Time.get_ticks_usec()-began > 12000000: break
	var night_s := (Time.get_ticks_usec()-began)/1000000.0
	check("night passes to dawn",clock.phase >= 0.19 and clock.phase < 0.36 and night_s < 8.0,{"phase":snappedf(clock.phase,0.001),"seconds":snappedf(night_s,0.1),"day":clock.day})
	await wait(1.0)
	check("dawn holds",clock.phase >= 0.2 and clock.phase < 0.36 and clock.target_hour < 0.0,{"phase":snappedf(clock.phase,0.001)})
	scene._celestial.set_phase(0.3)

	# A pond with a wood beside it, for life.
	var basin := Vector2(-3.0,2.0)
	data.begin_stroke()
	for _pass in range(6): data.brush(basin,4.2,0.3,"lower",0.0)
	var bottom: float = data.ground_height(basin)
	data.add_pond(basin,bottom+0.75)
	for i in range(14):
		var p := basin+Vector2.from_angle(-1.2+float(i)*0.19)*(6.0+0.8*sin(float(i)*2.3))
		if data.place("broadleaf" if i%3 else "tree",p,float(i),0.9) >= 0: data.objects.back()["source"] = "emerged"
	data.end_stroke()
	await editor.refresh(self)

	# 1 and 4. A forest wish on the far side, answered by emergence.
	var intent: RefCounted = editor.emergence.intent
	var wish: PackedFloat32Array = intent.forest
	var side := data.MEADOW_CELLS
	for z in range(side):
		for x in range(side):
			var p := data.meadow_position(x,z)
			var d := p.distance_to(Vector2(6.0,-6.0))
			if d < 4.0: wish[z*side+x] = clampf(1.2-d/4.0,0.0,1.0)
			elif p.distance_to(Vector2(-8.0,-8.0)) < 2.0: wish[z*side+x] = -1.0
	intent.forest = wish
	intent.revision += 1
	var trees := [0]
	editor.emergence.tree_arrived.connect(func(_p: Vector2, _born: float) -> void: trees[0] += 1)
	editor.emergence.on_region_changed(Rect2(2.0,-10.0,8.0,8.0),"forest")
	await wait(14.0)
	var feedback: Node = scene._stroke_feedback
	var puffs := 0
	for parcel in scene._atmosphere.puffs.parcels: if parcel.w > 0.0: puffs += 1
	# Trees born in the last ARRIVAL_GAP, or not born yet, may still wait.
	var now: float = preload("res://scripts/emergence.gd").time
	var overdue := 0
	for tree in feedback._arriving: if tree.z < now-feedback.ARRIVAL_GAP-0.1: overdue += 1
	check("forest trees arrive with a puff",trees[0] > 0 and overdue == 0 and puffs > 0,{"trees":trees[0],"pending":feedback._arriving.size(),"overdue":overdue,"live_puffs":puffs})
	var life_before := present(life)
	var arrived_total := 0
	for kind in life_before: arrived_total += life_before[kind]
	check("life arrived before save",arrived_total > 0,life_before)

	# Save, then open a fresh plain, then return to the saved place.
	var wish_saved: PackedFloat32Array = intent.forest.duplicate()
	var sites_saved := {}
	for kind in life.sites: sites_saved[kind] = life.present(kind).map(func(site: Dictionary) -> int: return int(site.cell))
	check("save",places.save_places(),"")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.places_path))
	var slot: Dictionary = saved.slots[saved.active]
	check("save carries the wish and life",slot.document.has("intent_forest") and slot.state.has("land_life"),{"wish":slot.document.get("intent_forest",{}).get("deflate","").length(),"life":slot.state.get("land_life",{}).get("sites",{}).keys()})
	DirAccess.copy_absolute(scene.places_path,places.previous_path())
	await places.new_plain(4242)
	await wait(1.0)
	check("new plain has no wish or life",intent.forest.count(0.0) == intent.forest.size() and present(life).values().max() == 0,present(life))
	var arrivals_before: Dictionary = life.arrivals.duplicate()
	var resumed_before: Dictionary = life.resumed.duplicate()
	check("resume",await places.resume_previous(),"")
	var diff := 0.0
	for i in range(wish_saved.size()): diff = maxf(diff,absf(wish_saved[i]-intent.forest[i]))
	check("wish round trip",diff == 0.0,{"max_difference":diff,"cells":intent.forest.size()-intent.forest.count(0.0)})
	await wait(4.0)
	var back := present(life)
	var matched := 0
	var total := 0
	for kind in sites_saved:
		for cell in sites_saved[kind]:
			total += 1
			if life.sites[kind].has(cell) and life.sites[kind][cell].here: matched += 1
	var new_arrivals := 0
	for kind in life.arrivals: new_arrivals += int(life.arrivals[kind])-int(arrivals_before.get(kind,0))
	var brought := 0
	for kind in life.resumed: brought += int(life.resumed[kind])-int(resumed_before.get(kind,0))
	check("life resumes in place",total > 0 and matched >= total*0.8 and brought >= matched,{"saved":total,"back_in_place":matched,"resumed":brought,"new_arrivals":new_arrivals,"present":back})
	check("plain clock kept",places.plain and is_equal_approx(clock.day_length,places.PLAIN_DAY_LENGTH) and clock.running,{"day_length":clock.day_length,"running":clock.running})

	# 2. An old save: no wish, no life, a held clock on the old day length.
	slot.document.erase("intent_forest")
	slot.state.erase("land_life")
	slot.state.world_clock.day_length = WorldClock.DEFAULT_DAY_LENGTH
	slot.state.world_clock.running = false
	var file := FileAccess.open(places.previous_path(),FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	await places.new_plain(4243)
	var fresh_arrivals := 0
	for kind in life.arrivals: fresh_arrivals += int(life.arrivals[kind])
	check("old save resumes",await places.resume_previous(),"")
	check("old save has no wish",intent.forest.count(0.0) == intent.forest.size(),"")
	check("old plain starts turning",clock.running and is_equal_approx(clock.day_length,places.PLAIN_DAY_LENGTH),{"day_length":clock.day_length,"running":clock.running})
	await wait(5.0)
	var settled := 0
	for kind in life.arrivals: settled += int(life.arrivals[kind])
	check("old save settles its life",settled > fresh_arrivals,{"arrivals":settled-fresh_arrivals,"present":present(life)})
	print("CONTINUITY %s failures=%d" % ["OK" if failures == 0 else "FAILED",failures])
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit(1 if failures else 0)
