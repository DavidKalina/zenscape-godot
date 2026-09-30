extends SceneTree
## The night sky as reveals (docs/scenic/surprises.md, "Night sky"). One shot
## per run, chosen with --shot=aurora|moon|moonbow:
##   aurora   a clear winter night; the aurora fades in (5x time lapse).
##   moon     a lunar month: the disc at each moonrise-to-meridian (close up),
##            then the plate at midnight night by night (time lapse).
##   moonbow  night rain under a full moon stops and a moonbow rises.
## Rendered (needs a window):
##   Godot --windowed --resolution 1280x720 --path . --write-movie /tmp/zs-film/night.avi \
##     -s res://tools/film_night_sky.gd -- --no-title --shot=aurora
## Headless it prints the numbers, for a dry run.

var scene: Node3D
var sky: RefCounted
var clock: WorldClock
var camera: Camera3D
var label := Label.new()
## Extra celestial steps a frame: aurora fades run LAPSE+1 times as fast.
var lapse := 0
## The hand and the sky's cloud, kept out of shot.
var hidden: Array[Node3D] = []
var base_fov := 50.0

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		for k in range(lapse): sky.advance(1.0/60.0,false)
		for node in hidden:
			if is_instance_valid(node):
				node.process_mode = Node.PROCESS_MODE_DISABLED
				node.visible = false

func seconds(value: float) -> void:
	await frames(int(value*60.0))

func option(name: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name): return argument.split("=")[1]
	return fallback

## World days as the clock's day and hour, and the rig redrawn there.
func set_days(t: float) -> void:
	clock.set_time(floori(t),fposmod(t,1.0)*WorldClock.HOURS_PER_DAY)
	sky.update_rig()

func moon() -> Vector3:
	return sky.state.zs_moon_direction

## Look along `direction` from `from`, through the scene's own orbit rig.
func aim(from: Vector3, direction: Vector3, fov: float) -> void:
	var look := direction.normalized()
	camera.fov = fov
	scene.distance = 40.0
	scene.target = from+look*scene.distance
	scene.yaw = atan2(-look.x,-look.z)
	scene.polar = acos(clampf(-look.y,-0.999,0.999))
	scene._update_camera()

func caption(text: String) -> void:
	label.text = text
	print("NIGHT ",text)

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("night sky film timed out"); quit(2))
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-night-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	var hand: Node3D = scene.get("god_hand") as Node3D
	if hand != null: hidden.append(hand)
	var cloud: Variant = scene.hand_reach.get("cloud")
	if cloud is Node3D: hidden.append(cloud)
	var layer := CanvasLayer.new()
	layer.layer = 120
	root.add_child(layer)
	# The 1280x720 viewport overhangs a 3:2 window at the sides.
	label.position = Vector2(170,24)
	label.add_theme_font_size_override("font_size",22)
	label.add_theme_color_override("font_color",Color(1,1,1,0.85))
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	layer.add_child(label)
	sky = scene._celestial
	clock = scene.world_clock
	camera = scene.camera
	base_fov = camera.fov
	scene._auto_orbit = false
	if scene.weather_scheduler != null: scene.weather_scheduler.enabled = false
	clock.running = false
	scene._precipitation.set_weather(0,true)
	scene._precipitation.cloud_override = 0.03
	await seconds(0.5)
	match option("shot","aurora"):
		"aurora": await aurora()
		"moon": await moon_month()
		"moonbow": await moonbow()
	print("NIGHT done")
	quit(0)

func aurora() -> void:
	clock.season_override = 0.85
	# A snowbound plate, so the night reads as winter.
	var surface: RefCounted = scene._precipitation.surface_weather
	scene._precipitation.cold_override = 1.0
	surface.cold = 1.0
	surface.snow_cover = 0.85
	set_days(3.0+22.0/24.0)
	# Tonight rolls an aurora: 21:00 to 04:00, strength 0.95.
	sky._aurora_night = clock.day+1
	sky._aurora_plan = Vector3(9.0,16.0,0.95)
	sky._aurora = 0.0
	var h: float = sky.state.zs_aurora.w
	var ahead := Vector3(sin(h),0.0,cos(h))
	aim(-ahead*46.0+Vector3.UP*14.0,ahead+Vector3.DOWN*0.26,62.0)
	caption("Clear winter night, 22:00 · aurora rolled for tonight · 5x time lapse")
	await seconds(3.0)
	lapse = 4
	for k in range(9):
		await seconds(3.0)
		print("NIGHT aurora %.2f" % float(sky.state.zs_aurora.x))
	lapse = 0
	await seconds(2.0)

## Days when the moon stands highest, across a month and a night more.
func meridians() -> Array[float]:
	var found: Array[float] = []
	var last := -2.0
	var rising := false
	var t := 0.2
	while t < 9.4:
		set_days(t)
		var y := moon().y
		if rising and y < last and t > 0.3: found.append(t-0.005)
		rising = y > last
		last = y
		t += 0.005
	return found

func moon_month() -> void:
	var times := meridians()
	var eye := Vector3(0.0,12.0,40.0)
	for t in times:
		set_days(t)
		var m := moon()
		aim(eye,m,5.0)
		caption("Close up: moon at its highest, day %.1f · %d%% lit · time lapse" % [t,roundi(sky.moon_lit*100.0)])
		for i in range(84):
			set_days(t-0.01+0.02*i/84.0)
			aim(eye,moon(),5.0)
			await frames(1)
	camera.fov = base_fov
	scene._overview()
	scene.polar = 1.28
	scene._update_camera()
	for d in range(10):
		set_days(float(d)+1.0)
		caption("Midnight, night %d · moon %d%% lit, %s · moonlight %.3f · time lapse" % [d+1,roundi(sky.moon_lit*100.0),"up" if moon().y > 0.02 else "down",float(scene._celestial._sun.light_energy)])
		await seconds(2.0)

func moonbow() -> void:
	clock.season_override = 0.35
	# An evening near full moon, the moon low in the east.
	var best := 1.0
	var best_gap := INF
	var t := 0.8
	while t < 2.6:
		set_days(t)
		var gap := absf(moon().y-0.3)
		if float(sky.state.zs_night) > 0.95 and sky.moon_lit > 0.95 and gap < best_gap:
			best_gap = gap
			best = t
		t += 0.002
	set_days(best)
	var m := moon()
	print("NIGHT moonbow at day %.3f, moon %s, lit %.2f" % [best,m,sky.moon_lit])
	var away := Vector3(-m.x,0.0,-m.z).normalized()
	aim(-away*40.0+Vector3.UP*9.0,away+Vector3.DOWN*0.12,78.0)
	scene._precipitation.cloud_override = -1.0
	scene._precipitation.set_weather(1,true)
	caption("Night rain under a full moon (%d%% lit)" % roundi(sky.moon_lit*100.0))
	await seconds(5.0)
	scene._precipitation.set_weather(0)
	scene._precipitation.cloud_override = 0.05
	caption("The rain stops · moonbow forced (legendary) · looking away from the moon")
	while float(scene._precipitation.state.x) > 0.06: await frames(1)
	var moments: Node3D = scene.land_life.moments
	moments._moonbow = {"age":0.0}
	moments._record("moonbow",Vector3.ZERO)
	for k in range(8):
		await seconds(3.0)
		print("NIGHT moonbow %.3f" % float(sky.state.zs_moonbow))
