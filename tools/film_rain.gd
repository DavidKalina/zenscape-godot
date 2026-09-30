extends SceneTree
## Films rain filling the live water (docs/scenic/water-flow.md, "Rain";
## scripts/rain_runoff.gd). The plain is shaped directly (no hand): a hill,
## a valley falling gently towards a dry basin at its foot. Shots, by
## `--shot=`:
##   fill: a steady rain (the "rain" preset) time-lapsed until the basin is a
##         pond, rills running in;
##   dry:  the pond, pre-filled off camera by the same rain, shrinking back
##         under a clear sky (time lapse);
##   melt: a snowpack (forced full) melting off the hill under a fair sky.
## Rendered (needs a window):
##   Godot --windowed --resolution 1280x720 --path . --write-movie /tmp/zs-film/rain.avi \
##     -s res://tools/film_rain.gd -- --no-title --still-weather --shot=fill
## Headless it prints the same numbers, for a dry run.

var scene: Node3D
var editor: NativeChunkEditor
## Extra water steps a frame while lapsing: the water runs lapse+1 times as fast.
var lapse := 0
var fog := 0.04
var haze := 0.06
const MOOD := "Alpine daylight"
const HILL := Vector2(-6.0,-2.0)
const BASIN := Vector2(2.5,0.5)
## Time lapse of each shot: water steps per frame, beyond the one it owns.
const LAPSE := {"fill":11,"dry":23,"melt":7}
## Film seconds each shot runs its lapse for.
const LENGTH := {"fill":26.0,"dry":24.0,"melt":26.0}

func _initialize() -> void: run.call_deferred()

static func bump(p: Vector2, center: Vector2, radius: float, rise: float) -> float:
	var t := p.distance_squared_to(center)/(radius*radius)
	return rise*(1.0-t)*(1.0-t) if t < 1.0 else 0.0

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if lapse > 0 and editor.flow != null:
			editor.flow.runoff.advance(lapse*editor.flow.dt,editor.flow)
			editor.flow.run(lapse)
		if absf(scene._atmosphere.fog_amount-fog) > 0.01:
			scene._atmosphere.set_fog(fog)
			scene._atmosphere.set_haze(haze)

func seconds(value: float) -> void:
	await frames(int(value*60.0))

func height(p: Vector2) -> float:
	var h: Variant = editor.data.ground_height(p)
	return float(h) if h != null else 0.0

## Looks at plate point `at` from `distance` m, gliding over `secs` seconds.
func frame_on(at: Vector2, distance: float, polar: float, yaw: float, secs: float) -> void:
	var from := {"target":scene.target,"distance":scene.distance,"polar":scene.polar,"yaw":scene.yaw}
	var goal := editor.terrain.to_global(Vector3(at.x,height(at),at.y))
	var count := maxi(1,int(secs*60.0))
	for i in range(count):
		var t := smoothstep(0.0,1.0,float(i+1)/count) if secs > 0.0 else 1.0
		scene.target = (from.target as Vector3).lerp(goal,t)
		scene.distance = lerpf(from.distance,distance,t)
		scene.polar = lerpf(from.polar,polar,t)
		scene.yaw = lerpf(from.yaw,yaw,t)
		await frames(1)

func weather(name: String) -> void:
	scene.weather_scheduler.enabled = false
	scene._precipitation.set_weather(scene._precipitation.PRESET_NAMES.find(name),true)

## Runs `secs` of water with the current weather at once, off camera.
func prefill(secs: int) -> void:
	var flow: RefCounted = editor.flow
	for s in range(secs):
		flow.runoff.advance(1.0,flow)
		while flow.runoff._job != null and not flow.runoff._job.completed(): OS.delay_msec(1)
		flow.runoff.advance(0.0,flow)
		flow.run(roundi(1.0/flow.dt))

func report(label: String) -> void:
	var best := {}
	for pool: Dictionary in editor.flow.pools():
		if best.is_empty() or float(pool.area) > float(best.area): best = pool
	var r: RefCounted = editor.flow.runoff
	print("FILM %s: water %.2f m³, pond %s, rain %.2f, sat %.2f, pack %.2f, drops %d, step %d µs" % [label,editor.flow.volume(),"%.1f m² %.2f m deep at (%.1f, %.1f)" % [best.area,best.depth,best.x,best.z] if not best.is_empty() else "none",r.rain,r.saturation,r.snowpack,r.drops.size()/4,editor.flow.last_step_usec])

func run() -> void:
	var shot := "fill"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot = arg.get_slice("=",1)
	create_timer(300).timeout.connect(func() -> void: push_error("rain film timed out"); quit(2))
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-rain-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size = Vector2i(1280,720)
	editor = scene._chunk_editor
	for i in range(120):
		if editor.flow != null and editor.flow.ready: break
		await process_frame
	if editor.flow == null:
		print("FILM no live water (needs --modeless or --water-flow)")
		quit(1)
		return
	scene.world_clock.running = false
	scene.apply_scene_mood(MOOD)
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	# The valley: a hill, the land falling gently towards the basin, the basin.
	var data := editor.data
	for i in range(data.points.size()):
		var p := data.points[i]
		var h := data.heights[i]+bump(p,HILL,7.5,3.2)+0.09*minf(p.distance_to(BASIN),9.0)
		if p.distance_to(BASIN) < 2.8: h = minf(h,data.heights[i]-bump(p,BASIN,2.8,1.1)+0.25)
		data.heights[i] = h
	data.begin_stroke()
	data.end_stroke()
	await editor.refresh(self)
	weather("clear")
	var mid := HILL.lerp(BASIN,0.6)
	scene._auto_orbit = false
	await frame_on(mid,20.0,0.85,0.5,0.0)
	await seconds(1.0)
	report("staged")
	if "--smoke" in OS.get_cmdline_user_args():
		if shot == "fill": weather("rain")
		await seconds(6.0)
		quit(0)
		return

	match shot:
		"fill":
			await seconds(2.0)
			weather("rain")
			await seconds(3.0)
			lapse = LAPSE.fill
			for k in range(int(LENGTH.fill/2.0)):
				await seconds(2.0)
				report("fill +%d s" % ((k+1)*2))
			lapse = 0
			await frame_on(BASIN,12.0,0.9,0.5,3.0)
			await seconds(3.0)
		"dry":
			weather("rain")
			editor.flow.runoff.rain = 0.6
			prefill(300)
			weather("clear")
			editor.flow.runoff.rain = 0.0
			editor.flow.runoff.saturation = 0.0
			report("prefilled")
			await frame_on(BASIN,12.0,0.9,0.5,0.0)
			await seconds(3.0)
			lapse = LAPSE.dry
			for k in range(int(LENGTH.dry/2.0)):
				await seconds(2.0)
				report("dry +%d s" % ((k+1)*2))
			lapse = 0
			await seconds(3.0)
		"melt":
			weather("fair")
			editor.flow.runoff.snowpack = editor.flow.runoff.SNOW_PACK
			await frame_on(HILL.lerp(BASIN,0.4),19.0,0.9,0.5,0.0)
			await seconds(2.0)
			lapse = LAPSE.melt
			for k in range(int(LENGTH.melt/2.0)):
				await seconds(2.0)
				report("melt +%d s" % ((k+1)*2))
			lapse = 0
			await seconds(3.0)
	print("FILM done")
	quit(0)
