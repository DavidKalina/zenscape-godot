extends SceneTree
## Headless probe of life answering the land (scripts/land_life.gd,
## docs/scenic/life.md). Opens the product scene on the Genesis plain, digs a
## basin and fills it with a pond, stands a small wood beside it, and watches
## what arrives, with the life clock run `--pace` times faster. Then it drains
## the pond and checks the water life leaves. Frame gaps are main-loop
## intervals under the dummy renderer: CPU only, never GPU work.
##   godot --headless --path . -s res://tools/probe_land_life.gd -- --pace=6 --watch=25
var scene: Node3D
var life: Node3D
var pace := 6.0
var watch := 25.0
## --world-seed=N regrows generated world N instead and watches a settled
## world come alive (its sites start SETTLED_HEAD through their delays).
var world_seed := -1
var phase := "arrivals"
## Frames over 12 ms: [phase, ms, LandLife ms, editor refresh stage].
var slow := []

func _initialize() -> void: run.call_deferred()

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	var over := 0
	for value in values:
		if value > 16.667: over += 1
	return {"n":sorted.size(),"median":snappedf(sorted[sorted.size()/2],0.01),"p95":snappedf(sorted[mini(sorted.size()-1,int(sorted.size()*0.95))],0.01),"max":snappedf(sorted.back(),0.01),"over_16_67":over}

func present() -> Dictionary:
	var counts := {}
	for kind in life.sites: counts[kind] = life.present(kind).size()
	return counts

## Frame gaps and LandLife's own time per frame over `seconds`.
func watch_frames(seconds: float, frames: Array[float], own: Array[float]) -> void:
	var previous := Time.get_ticks_usec()
	var until := previous+int(seconds*1000000.0)
	while Time.get_ticks_usec() < until:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		own.append(life.last_usec/1000.0)
		if frames.back() > 12.0: slow.append([phase,snappedf(frames.back(),0.1),snappedf(own.back(),0.01),scene._chunk_editor.refresh_stage])
		previous = now

func generated(seed_value: int) -> void:
	var began := Time.get_ticks_usec()
	scene.places.regrow(seed_value)
	await process_frame
	while scene.places.busy: await process_frame
	var data: NativeTerrainData = scene._chunk_editor.data
	print("LIFE generated seed=%d blank=%s ponds=%d streams=%d objects=%d regrow_s=%.1f" % [seed_value,data.blank,data.ponds.size(),data.streams.size(),data.objects.size(),(Time.get_ticks_usec()-began)/1000000.0])
	var frames: Array[float] = []
	var own: Array[float] = []
	for second in range(int(watch)):
		await watch_frames(1.0,frames,own)
		print("LIFE t ",JSON.stringify([second+1,snappedf(life.clock,0.1),present()]))
	var survey: RefCounted = life.survey
	if survey != null:
		var bodies := []
		for record: Dictionary in survey.bodies: bodies.append([record.area,record.deep.size(),record.shallow.size()])
		print("LIFE survey ",JSON.stringify({"surveys":life.surveys,"bodies":bodies,"streams":survey.stream_cells,"shore":survey.shore.size(),"edges":survey.forest_edges.size(),"damp":survey.damp.size(),"trees":survey.tree_count,"richness":snappedf(survey.richness(),0.01),"spent_ms":snappedf(survey.spent_usec/1000.0,0.01),"worst_step_ms":snappedf(survey.worst_step_usec/1000.0,0.01)}))
	print("LIFE frames ",JSON.stringify({"all":stats(frames),"life_ms":stats(own),"survey_worst_ms":snappedf(life.survey_worst_usec/1000.0,0.01),"slow":slow}))
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pace="): pace = float(arg.trim_prefix("--pace="))
		if arg.begins_with("--watch="): watch = float(arg.trim_prefix("--watch="))
		if arg.begins_with("--world-seed="): world_seed = int(arg.trim_prefix("--world-seed="))
	create_timer(170).timeout.connect(func() -> void: push_error("Life probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-life-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	life = scene.land_life
	var editor: NativeChunkEditor = scene._chunk_editor
	var data := editor.data
	editor.set_process_input(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	life.pace = pace
	print("LIFE plain blank=%s active=%s terrain=%s" % [data.blank,life.active,editor.terrain.global_transform.origin])
	# Dawn, so deer may come; the clock holds as it does on the plain.
	scene._celestial.set_phase(0.28)
	await create_timer(1.5).timeout
	if world_seed >= 0:
		await generated(world_seed)
		return
	# A basin with a pond, and a small wood on its east bank.
	var basin := Vector2(-3.0,2.0)
	data.begin_stroke()
	for _pass in range(6): data.brush(basin,4.2,0.3,"lower",0.0)
	var bottom: float = data.ground_height(basin)
	var added := data.add_pond(basin,bottom+0.75)
	for i in range(14):
		var angle := -1.2+float(i)*0.19
		var p := basin+Vector2.from_angle(angle)*(6.0+0.8*sin(float(i)*2.3))
		var id := data.place("broadleaf" if i%3 else "tree",p,float(i),0.9)
		if id >= 0: data.objects.back()["source"] = "emerged"
	data.end_stroke()
	var began := Time.get_ticks_usec()
	await editor.refresh(self)
	print("LIFE world pond=%s level=%.2f bottom=%.2f objects=%d refresh_ms=%.1f" % [added,bottom+0.75,bottom,data.objects.size(),(Time.get_ticks_usec()-began)/1000.0])
	var frames: Array[float] = []
	var own: Array[float] = []
	var timeline := []
	for second in range(int(watch)):
		await watch_frames(1.0,frames,own)
		timeline.append([second+1,snappedf(life.clock,0.1),present(),life.moments.showing()])
	var survey: RefCounted = life.survey
	var bodies := []
	if survey != null:
		for record: Dictionary in survey.bodies: bodies.append({"area":record.area,"deep":record.deep.size(),"shallow":record.shallow.size(),"wade":record.wade.size(),"shore":record.shore.size()})
	print("LIFE survey ",JSON.stringify({"surveys":life.surveys,"spent_ms":snappedf(survey.spent_usec/1000.0,0.01) if survey else -1,"worst_step_ms":snappedf(survey.worst_step_usec/1000.0,0.01) if survey else -1,"bodies":bodies,"shore":survey.shore.size() if survey else 0,"forest_edges":survey.forest_edges.size() if survey else 0,"damp":survey.damp.size() if survey else 0,"trees":survey.tree_count if survey else 0,"richness":snappedf(survey.richness(),0.01) if survey else 0}))
	for row in timeline: print("LIFE t ",JSON.stringify(row))
	print("LIFE arrivals ",JSON.stringify(life.arrivals))
	print("LIFE moments ",JSON.stringify(life.moments.history.map(func(m: Dictionary) -> Array: return [m.kind,snappedf(m.at,0.1)])))
	# Each moment on demand, so the probe covers them whatever the dice said.
	var forced := {}
	for kind in ["heron","deer","bigfoot","rainbow"]: forced[kind] = life.moments.force(kind)
	phase = "forced"
	await watch_frames(3.0,frames,own)
	print("LIFE forced ",JSON.stringify(forced)," showing ",JSON.stringify(life.moments.showing()))
	# Drain the pond: the fish, frogspawn and frogs leave.
	data.begin_stroke()
	data.ponds.clear()
	data.end_stroke()
	await editor.refresh(self)
	phase = "drained"
	await watch_frames(6.0,frames,own)
	print("LIFE drained ",JSON.stringify(present()))
	# Undo brings the water back; life returns after its delays.
	phase = "undone"
	editor.undo()
	await watch_frames(6.0,frames,own)
	print("LIFE undone ",JSON.stringify(present()))
	print("LIFE frames ",JSON.stringify({"all":stats(frames),"life_ms":stats(own),"life_worst_ms":snappedf(life.worst_usec/1000.0,0.01),"survey_worst_ms":snappedf(life.survey_worst_usec/1000.0,0.01),"slow":slow}))
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit()
