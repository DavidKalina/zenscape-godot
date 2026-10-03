extends SceneTree
## Headless probe of the Bigfoot sighting (scripts/life_bigfoot.gd,
## docs/scenic/life.md "Bigfoot"). Opens the product scene on the Genesis plain
## at dusk, plants a mature wood on its west half with undergrowth, waits for
## the survey, prints the sighting conditions, then forces each sighting with
## the camera framed on him and held still, and reports where he stands
## (ground contact of each foot, distance outside the edge and from the
## camera, on screen), which clips play, how long he stays and the frame cost.
## Then patience: a camera that creeps in slowly (plus one wheel notch) keeps
## him and his linger beat; one that zooms in fast, or a stroke beside him,
## sends him off. Exits 1 if a check fails. The opening world varies run to
## run: grass is painted under the wood so the survey finds its edges, and a
## sighting that will not stage walks the camera round the plate. Frame gaps are CPU only
## under the dummy renderer.
##   godot --headless --path . -s res://tools/probe_bigfoot_sighting.gd
##   ... -- --natural=60 --pace=30   (no forcing: wait for the dice at dusk)
##   godot --path . -s res://tools/probe_bigfoot_sighting.gd -- --stills=/tmp/zs-bigfoot-sighting
## `--stills` renders (not headless) and saves framed stills of each sighting
## and one at night.
var scene: Node3D
var life: Node3D
var moments: Node3D
var bigfoot: Node3D
var pace := 1.0
var natural := 0.0
var stills := ""
var frames: Array[float] = []
var costs: Array[float] = []
var failures: Array[String] = []
## The still and patient cameras: he should stay at least this long.
const PATIENT_MIN := 20.0
## Where the camera frames him from (metres to his head), the slow approach's
## speed and end, and the fast zoom's end and duration (real seconds).
const FRAME_AT := 26.0
const CREEP_SPEED := 1.5
const CREEP_TO := 12.5
const RUSH_TO := 12.0
const RUSH_TIME := 0.6

func _initialize() -> void: run.call_deferred()

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	return {"n":sorted.size(),"median":snappedf(sorted[sorted.size()/2],0.001),"p95":snappedf(sorted[mini(sorted.size()-1,int(sorted.size()*0.95))],0.001),"max":snappedf(sorted.back(),0.001)}

func frame() -> void:
	var before := Time.get_ticks_usec()
	await process_frame
	frames.append((Time.get_ticks_usec()-before)/1000.0)
	if bigfoot.showing() or bigfoot.last_usec > 0: costs.append(bigfoot.last_usec/1000.0)
	bigfoot.last_usec = 0

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pace="): pace = float(arg.trim_prefix("--pace="))
		if arg.begins_with("--natural="): natural = float(arg.trim_prefix("--natural="))
		if arg.begins_with("--stills="): stills = arg.trim_prefix("--stills=")
	create_timer(420).timeout.connect(func() -> void: push_error("Bigfoot probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-bigfoot-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	life = scene.land_life
	moments = life.moments
	bigfoot = moments.bigfoot
	if bigfoot == null:
		push_error("No Bigfoot on LifeMoments")
		quit(1)
		return
	var editor: NativeChunkEditor = scene._chunk_editor
	var data := editor.data
	editor.set_process_input(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	life.pace = pace
	# Dusk, held there.
	scene._celestial.set_phase(0.7)
	scene._celestial.cycling = false
	await create_timer(1.0).timeout
	print("BIGFOOT model_ready_after_1s=%s build_ms=%.2f" % [bigfoot.actor != null,bigfoot.build_usec/1000.0])
	# A mature wood on the west half: trees on a jittered grid, undergrowth
	# among and before them. The open east half faces the camera.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	data.begin_stroke()
	# Grass under and before the wood: the survey's edges need cover, and the
	# opening world's grass varies from run to run.
	data.paint_grass(Vector2(-3.0,0.0),11.0,0.8)
	var trees := 0
	for gx in range(5):
		for gz in range(8):
			var p := Vector2(-10.5+gx*1.9+rng.randf_range(-0.5,0.5),-7.5+gz*2.0+rng.randf_range(-0.5,0.5))
			if data.place(["tree","broadleaf","broadleaf"][(gx+gz)%3],p,rng.randf()*TAU,rng.randf_range(0.85,1.15)) >= 0:
				data.objects.back()["source"] = "emerged"
				trees += 1
	for i in range(24):
		var p := Vector2(rng.randf_range(-11.0,-2.5),rng.randf_range(-8.0,8.0))
		if data.place(["shrub","fern"][i%2],p,rng.randf()*TAU,1.0) >= 0: data.objects.back()["source"] = "emerged"
	data.end_stroke()
	await editor.refresh(self)
	var surveys: int = life.surveys
	# A survey already under way when the wood went in can land first and find
	# no edges: wait for one that saw the wood.
	var waiting := Time.get_ticks_msec()
	while life.surveys == surveys or (life.survey.forest_edges.is_empty() and Time.get_ticks_msec()-waiting < 20000):
		await process_frame
	await frame()
	print("BIGFOOT world trees=%d objects=%d edges=%d" % [trees,data.objects.size(),life.survey.forest_edges.size()])
	print("BIGFOOT conditions ",JSON.stringify(moments.bigfoot_conditions()))
	if natural > 0.0:
		await watch_natural()
		return
	if stills != "":
		await film()
		return
	scene._auto_orbit = false
	for kind in ["watch","stride","listen"]:
		await sighting(kind)
	await patient()
	await shy("camera")
	await shy("paint")
	print("BIGFOOT frames ",JSON.stringify({"frame_ms":stats(frames),"bigfoot_ms":stats(costs),"model_build_ms":snappedf(bigfoot.build_usec/1000.0,0.01)}))
	print("BIGFOOT checks ",JSON.stringify({"failures":failures}))
	await finish(1 if not failures.is_empty() else 0)

func finish(code := 0) -> void:
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit(code)

func check(ok: bool, what: String) -> void:
	print("BIGFOOT check ",("PASS " if ok else "FAIL "),what)
	if not ok: failures.append(what)

## Force a sighting of `kind`. Every edge must face the camera from its open
## side, so where the last test left the camera can rule them all out: walk
## the orbit round the plate until one stages (and, for the film, until an
## edge runs side-on to the camera).
func force(kind: String, why: String) -> bool:
	var ok: bool = moments.force("bigfoot_"+kind)
	var turns := 0
	while (not ok or bigfoot.state.kind != kind) and turns < 12:
		bigfoot.hide_now()
		turns += 1
		scene.target = Vector3.ZERO
		scene.distance = 34.0
		scene.yaw = turns*TAU/12.0
		scene._update_camera()
		await frame()
		ok = moments.force("bigfoot_"+kind)
	if not ok: check(false,"%s: force bigfoot_%s (edges=%d)" % [why,kind,life.survey.forest_edges.size() if life.survey != null else -1])
	elif turns > 0: print("BIGFOOT ",why," staged ",bigfoot.state.kind," after ",turns," camera turns")
	return ok

## Point the orbit at his head from `distance` along the current view, as if
## the camera had been there when he came out: his camera memory starts here.
func frame_on_him(distance: float) -> void:
	scene._auto_orbit = false
	scene.target = bigfoot.global_position+Vector3.UP*bigfoot.HEAD
	scene.distance = distance
	scene._update_camera()
	bigfoot._camera_distance = -1.0
	bigfoot._rush = 0.0
	bigfoot._rush_for = 0.0

## Move the camera's distance to `to` at `speed` m/s of real time.
func dolly(to: float, speed: float) -> void:
	var from: float = scene.distance
	var began := Time.get_ticks_msec()
	while bigfoot.showing():
		var t := minf(1.0,(Time.get_ticks_msec()-began)/1000.0*speed/absf(from-to))
		scene.distance = lerpf(from,to,t)
		await frame()
		if t >= 1.0: return

func home() -> void:
	scene.target = Vector3.ZERO
	scene.distance = 43.0
	for _i in range(5): await frame()

## Force one sighting and follow it to the end.
func sighting(kind: String) -> void:
	var began := Time.get_ticks_usec()
	var ok: bool = await force(kind,kind)
	var force_ms := (Time.get_ticks_usec()-began)/1000.0
	if not ok: return
	var staged: String = bigfoot.state.kind
	if kind == "stride": print("BIGFOOT stride staged as ",staged)
	var clips := []
	var feet_low := INF
	var feet_high := -INF
	var stance := []
	var worst_slope := 0.0
	var wet := false
	var samples := []
	var next := 0.0
	var start: float = life.clock
	frame_on_him(FRAME_AT)
	var left := ""
	var lingered := []
	while bigfoot.showing():
		var r: Dictionary = bigfoot.report()
		if not r.is_empty():
			if clips.is_empty() or clips.back() != r.clip: clips.append(r.clip)
			var low := minf(float(r.feet.L),float(r.feet.R))
			if float(r.size) > 0.99:
				feet_low = minf(feet_low,low)
				feet_high = maxf(feet_high,low)
				stance.append(low)
			worst_slope = maxf(worst_slope,float(r.slope))
			wet = wet or bool(r.wet)
			if life.clock-start >= next:
				next += 2.0
				samples.append([r.age,r.clip,r.clip_t,r.p,r.outside_m,r.camera_m,r.on_screen,r.feet,r.size])
			left = r.left
			lingered = r.lingered
		await frame()
	for s in samples: print("BIGFOOT ",kind," t ",JSON.stringify(s))
	var sorted := stance.duplicate()
	sorted.sort()
	var lasted: float = life.clock-start
	check(left == "" and not lingered.is_empty() and lasted >= PATIENT_MIN,"%s, still camera: stays %.1f s, lingers %s, left %s" % [kind if staged == kind else kind+" (staged as "+staged+")",lasted,JSON.stringify(lingered),JSON.stringify(left)])
	print("BIGFOOT ",kind," summary ",JSON.stringify({"force_ms":snappedf(force_ms,0.01),"lasted_s":snappedf(lasted,0.1),"clips":clips,"lingered":lingered,"left":left,
		"lower_foot_above_ground_m":{"min":snappedf(feet_low,0.001),"median":snappedf(sorted[sorted.size()/2],0.001) if not sorted.is_empty() else null,"max":snappedf(feet_high,0.001)},
		"worst_slope":snappedf(worst_slope,0.01),"ever_wet":wet}))
	for _i in range(5): await frame()

## A patient camera: framed on him, one wheel notch in (12%) early, then a
## slow creep to CREEP_TO. He should stay, linger and walk back on his own.
func patient() -> void:
	if not await force("watch","patient"): return
	var start: float = life.clock
	frame_on_him(FRAME_AT)
	while bigfoot.showing() and life.clock-start < 3.0: await frame()
	await dolly(FRAME_AT/1.12,FRAME_AT*0.12/0.3)
	while bigfoot.showing() and life.clock-start < 5.0: await frame()
	await dolly(CREEP_TO,CREEP_SPEED)
	var r: Dictionary = bigfoot.report()
	print("BIGFOOT patient after creep ",JSON.stringify({"age":r.get("age"),"clip":r.get("clip"),"camera_m":r.get("camera_m"),"rush_m":r.get("rush_m"),"left":r.get("left")}))
	var left := ""
	var lingered := []
	while bigfoot.showing():
		r = bigfoot.report()
		left = r.left
		lingered = r.lingered
		await frame()
	var lasted: float = life.clock-start
	check(left == "" and not lingered.is_empty() and lasted >= PATIENT_MIN,"patient camera (notch + creep at %.1f m/s to %.1f m): stays %.1f s, lingers %s, left %s" % [CREEP_SPEED,CREEP_TO,lasted,JSON.stringify(lingered),JSON.stringify(left)])
	await home()

## Rush him with the camera (FRAME_AT to RUSH_TO in RUSH_TIME s), or paint
## beside him: he should leave.
func shy(how: String) -> void:
	if not await force("watch","shy "+how): return
	var start: float = life.clock
	frame_on_him(FRAME_AT)
	while bigfoot.showing() and life.clock-start < 3.0: await frame()
	var at: Vector3 = bigfoot.global_position
	var rushed: float = life.clock
	if how == "camera":
		await dolly(RUSH_TO,(FRAME_AT-RUSH_TO)/RUSH_TIME)
		# The tolerance: a rush counts only once it has lasted a moment.
		while bigfoot.showing() and str(bigfoot.state.left) == "" and life.clock-rushed < 2.0: await frame()
	else:
		scene._chunk_editor.stroke_started.emit(at+Vector3(3.0,0,0),1.5,"land")
		await frame()
	var left := str(bigfoot.state.get("left",""))
	var after: float = life.clock-rushed
	var expect := "camera closing" if how == "camera" else "painting near"
	print("BIGFOOT shy ",how," left=",JSON.stringify(left)," after_s=",snappedf(after,0.01))
	while bigfoot.showing(): await frame()
	var lasted: float = life.clock-start
	check(left == expect and lasted < 10.0,"%s: leaves (%s) %.2f s after it starts, glimpse %.1f s" % [how,JSON.stringify(left),after,lasted])
	await home()

## No forcing: let the dice decide, with the life clock at `pace`.
func watch_natural() -> void:
	var until: float = life.clock+natural*pace
	var last := -1
	while life.clock < until:
		await frame()
		var minute := int(life.clock/30.0)
		if minute != last:
			last = minute
			var c: Dictionary = moments.bigfoot_conditions()
			print("BIGFOOT natural t=%.0f rich_for=%s settled=%s quiet=%s chance=%s about=%s showing=%s" % [life.clock,c.rich_for,c.settled,c.quiet,c.chance,c.about,bigfoot.showing()])
	print("BIGFOOT natural history ",JSON.stringify(moments.history.filter(func(m: Dictionary) -> bool: return m.kind == "bigfoot").map(func(m: Dictionary) -> float: return snappedf(m.at,0.1))))
	await finish()

## Rendered stills: frame the wood's east edge from the open side, force each
## sighting and capture its best moment, then one at night.
func film() -> void:
	DirAccess.make_dir_recursive_absolute(stills)
	bigfoot.shy = false
	var frame_edge := func(distance: float) -> void:
		scene._auto_orbit = false
		scene.target = life.to_global(Vector3(-2.0,moments._ground(Vector2(-2.0,0.0))+1.0,0.0))
		scene.distance = distance
		scene.yaw = PI/2.0-0.25
		scene.polar = 1.38
		scene._update_camera()
	frame_edge.call(22.0)
	for _i in range(10): await frame()
	await capture("wide_empty")
	for shot in [["watch",11.5,0.7],["stride",-1.0,0.7],["watch",11.5,0.03]]:
		scene._celestial.set_phase(shot[2])
		# Hold the air clear enough to see him; weather may roll mist in.
		scene._atmosphere.set_fog(0.2)
		for _i in range(10): await frame()
		if not moments.force("bigfoot_"+shot[0]):
			print("BIGFOOT still ",shot[0]," force failed")
			continue
		var when: float = shot[1]
		if when < 0.0:
			# The stride: the look peaks about 3.5 s into the look clip.
			var lead: float = bigfoot.state.beats[0].length
			when = lead+3.4
		while bigfoot.showing() and float(bigfoot.state.age) < when: await frame()
		var r: Dictionary = bigfoot.report()
		# Frame him closer for the look, from where the camera already is.
		scene.target = bigfoot.global_position+Vector3.UP*1.2
		scene.distance = 16.0
		scene._update_camera()
		await RenderingServer.frame_post_draw
		await capture("%s_phase%.2f" % [shot[0],shot[2]])
		print("BIGFOOT still ",shot[0]," ",JSON.stringify(r))
		bigfoot.hide_now()
		moments._bigfoot_gone()
		frame_edge.call(22.0)
		for _i in range(5): await frame()
	await finish()

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [stills,label]
	image.save_png(path)
	print("BIGFOOT still saved ",path)
