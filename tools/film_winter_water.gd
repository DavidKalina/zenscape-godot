extends SceneTree
## Winter on the water (scripts/life_winter.gd, docs/scenic/life.md): a pond
## on the Genesis plain fills with fish, frogspawn and frogs, then (a) freezes:
## the fish go slow, deep and dim and the frogs back into the bank; (b) thaws:
## extra frogspawn, frogs crawl out of the bank, lively fish; (c) an autumn
## dawn lifts mist off the open pond. Rendered (needs a window):
##   Godot --windowed --resolution 1280x720 --path . --write-movie /tmp/zs-film/07-winter.avi \
##     -s res://tools/film_winter_water.gd -- --no-title
## It prints `SHOT <name> <first frame> <last frame>` for cutting the clips.
## Headless it prints the same numbers, for a dry run.

var scene: Node3D
var life: Node3D
var editor: NativeChunkEditor
var frame := 0
var stop := -1
## Held while a shot runs: the world's cold, and the ice's pace toward it.
var cold := 0.0
const BASIN := Vector2(-3.0,2.0)
## How fast the ice forms and goes (SurfaceWeather.pace), so a freeze reads in seconds.
const ICE_PACE := 4.0

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		var surface: RefCounted = scene._precipitation.surface_weather
		surface.target_cold = cold
		surface.cold = cold
		await process_frame
		frame += 1
		if frame == stop:
			# --stop=N: a smoke test, one still at frame N and out.
			root.get_texture().get_image().save_png("/private/tmp/zs-film/07-winter-smoke.png")
			quit(0)

func seconds(value: float) -> void:
	await frames(int(value*60.0))

func present() -> Dictionary:
	var counts := {}
	for kind in ["fish","spawn","frog"]: counts[kind] = life.present(kind).size()
	return counts

func report(label: String) -> void:
	var modes := []
	for site: Dictionary in life.sites.frog.values():
		if site.here: modes.append(site.mode)
	print("WINTER %s f%d clock %.1f %s frogs %s ice %.2f under %.2f frozen %s thaws %d lively %.2f mist %.2f" % [label,frame,life.clock,present(),modes,scene._precipitation.surface_weather.ice,life.winter.under,life.winter.frozen(),life.winter.thaws,life.winter.lively(),life.winter.mist])

func look(at: Vector2, distance: float, yaw: float, polar: float) -> void:
	var level: float = scene._chunk_editor.data.ground_height(at)
	scene.target = editor.terrain.to_global(Vector3(at.x,level,at.y))
	scene.distance = distance
	scene.yaw = yaw
	scene.polar = polar
	scene._update_camera()

func orbit(secs: float, turn: float) -> void:
	var from: float = scene.yaw
	var count := int(secs*60.0)
	for i in range(count):
		scene.yaw = from+turn*float(i+1)/count
		scene._update_camera()
		await frames(1)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stop="): stop = int(arg.trim_prefix("--stop="))
	create_timer(900).timeout.connect(func() -> void: push_error("winter film timed out"); quit(2))
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-winter-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	editor = scene._chunk_editor
	life = scene.land_life
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	var hand: Node3D = scene.get("god_hand") as Node3D
	if hand != null:
		# The hand sets its own visibility each frame; still it.
		hand.set_process(false)
		hand.set_physics_process(false)
		hand.visible = false
	editor.set_process_input(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene.world_clock.running = false
	scene.world_clock.season_override = 0.02
	scene._celestial.set_phase(0.42)
	var surface: RefCounted = scene._precipitation.surface_weather
	var data := editor.data
	data.begin_stroke()
	for _pass in range(6): data.brush(BASIN,4.2,0.3,"lower",0.0)
	var bottom: float = data.ground_height(BASIN)
	data.add_pond(BASIN,bottom+0.75)
	data.end_stroke()
	await editor.refresh(self)
	look(BASIN,11.0,scene.yaw,0.95)
	# Fill the pond: fish, frogspawn and two frogs, fast.
	life.pace = 10.0
	while (present().frog < 2 or present().fish < 4) and frame < 60*60: await frames(30)
	life.pace = 1.0
	report("filled")
	await seconds(2.0)

	if "--mist-only" in OS.get_cmdline_user_args():
		await mist_shot()
		quit(0)
		return
	# (a) The freeze.
	var first := frame
	look(BASIN,7.5,scene.yaw,0.9)
	await seconds(3.0)
	surface.pace = ICE_PACE
	cold = 1.0
	for k in range(6):
		await seconds(2.0)
		report("freeze")
	await orbit(6.0,0.6)
	report("frozen")
	print("SHOT a-freeze %d %d" % [first,frame])
	# Held frozen long enough (LifeWinter.FREEZE_HELD) for the thaw to count.
	life.pace = 4.0
	await seconds(4.0)
	life.pace = 1.0
	report("held")

	# (b) The thaw, the life clock run 3x until a frog comes out of its bank.
	await seconds(1.0)
	first = frame
	cold = 0.0
	await seconds(3.0)
	life.pace = 3.0
	var emerging := false
	while not emerging and frame-first < 60*40:
		await frames(10)
		for site: Dictionary in life.sites.frog.values():
			if site.here and site.mode == "emerge": emerging = true
	report("emerging")
	life.pace = 1.0
	for k in range(5):
		await seconds(2.0)
		report("thaw")
	print("SHOT b-thaw %d %d" % [first,frame])

	await mist_shot()
	quit(0)

## (c) A late autumn dawn, clear, low over the pond.
func mist_shot() -> void:
	scene._precipitation.surface_weather.pace = 1.0
	scene.world_clock.season_override = 0.7
	scene._celestial.set_phase(0.31)
	look(BASIN,9.5,scene.yaw+0.8,1.12)
	await seconds(1.0)
	life.winter.mist = life.winter._mist_wanted()
	var first := frame
	for k in range(4):
		await seconds(2.0)
		report("dawn")
	await orbit(10.0,0.5)
	report("mist")
	print("SHOT c-mist %d %d" % [first,frame])
