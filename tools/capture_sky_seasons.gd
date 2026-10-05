extends SceneTree
## The plate's seasons in the sky layer, rendered (shaders/sky_season.gdshaderinc):
## the same views in each of the four seasons E steps to (living_weather
## SEASONS), the weather held clear and the ground settled into the season
## (its gold, cold and a winter's frost) so only the season differs:
##   plate: the plate overview in the build camera, the cloud sea behind;
##   range: a range of the band from a kilometre in, at glide height (and
##     at golden hour);
##   valley: from the plate at glide height down its valley to a pass,
##     the islets on the way;
##   sea: the cloud sea out to the horizon from over the plate, in each of
##     the three styles (Opal, Storybook, Mystic).
## Stills are named <view>-<season>[-<style>]-<hour>.png.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sky_seasons.gd \
##     -- --no-title --still-weather --out=/private/tmp/zs-seasons
## Options: --out=DIR, --only=plate,range,valley,sea, --seasons=spring,winter.
const SkyWorld = preload("res://scripts/sky_world.gd")
const LivingWeather = preload("res://scripts/living_weather.gd")
const GOLDEN_SUN := 0.1
const SEASON_NAMES := ["spring","summer","autumn","winter"]
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-seasons"
var noon := WorldClock.hour_for_phase(0.5)
var golden := WorldClock.hour_for_phase(0.75-asin(clampf(GOLDEN_SUN/WorldClock.elevation_for_phase(0.5),-1.0,1.0))/TAU)
var only: Array = []
var seasons: Array = SEASON_NAMES.duplicate()

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func still(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	var path := out.path_join(label+".png")
	image.save_png(path)
	print("SEASONS still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
		elif argument.begins_with("--seasons="): seasons = Array(argument.trim_prefix("--seasons=").split(","))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(1800).timeout.connect(func() -> void: push_error("sky seasons capture timed out"); quit(2))
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
	scene.world_clock.running = false
	# The plate overview, in the build camera, before the glide.
	if only.is_empty() or "plate" in only:
		for season: String in seasons:
			await _season(season)
			for i in range(40):
				scene.world_clock.set_time(scene.world_clock.day,noon)
				await process_frame
			await still("plate-%s-noon" % season)
	eye = scene.wanderer
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	await frames(5)
	eye._launch(6.0,false)
	eye.set_process(false)
	eye._layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var islands: Node3D = eye.islands
	for i in range(900):
		if not islands.lands.has(null): break
		await frames(1)
	var peaks: Node3D = islands.peaks
	peaks.advance(0.6,Vector3.ZERO)
	peaks.flush()
	var look: Object = scene.look_pass
	for season: String in seasons:
		await _season(season)
		for shot: Dictionary in _shots():
			if not only.is_empty() and shot.view not in only: continue
			for style: String in shot.get("styles",[""]):
				if style != "": look.set_cloud_style(style,false)
				for hour: float in ([noon,golden] if shot.get("golden",false) else [noon]):
					await _hold(shot,hour,50)
					var tag := "noon" if hour == noon else "golden"
					await still("%s-%s%s-%s" % [shot.view,season,"" if style == "" else "-"+style,tag])
		look.set_cloud_style("opal",false)
	print("SEASONS done")
	quit(0)

## The season pinned and the scene settled into it: clear weather, the
## season shown at once (no glide), the ground's gold and cold where the
## season leaves them, and a winter's frost as a long cold spell lays it.
func _season(season: String) -> void:
	var at: float = LivingWeather.SEASONS[SEASON_NAMES.find(season)]
	scene.world_clock.season_override = at
	scene._season_shown = -1.0
	scene._precipitation.set_weather(WeatherScheduler.preset_index("clear"),true)
	for i in range(3): await process_frame
	var surface: RefCounted = scene._precipitation.surface_weather
	surface.autumn = surface.target_autumn
	surface.cold = surface.target_cold
	surface.snow_cover = surface.frost_limit if season == "winter" else 0.0
	surface.ice = smoothstep(0.35,0.7,surface.cold)
	await frames(3)
	print("SEASONS %s: season %.3f sky %s plants %s autumn %.2f cold %.2f snow %.2f" % [season,at,str(WeatherScheduler.season_sky(at)),str(WeatherScheduler.season_plants(at)),surface.autumn,surface.cold,surface.snow_cover])

func _shots() -> Array:
	var shots := []
	var layout := SkyWorld.layout()
	var r: Dictionary = layout.ranges[layout.ranges.size()/2]
	var rw := Vector3(r.at.x,0.0,r.at.z).normalized()
	shots.append({"view":"range","eye":r.at-rw*1100.0+Vector3.UP*70.0,"look":r.at+Vector3.UP*150.0,"golden":true})
	if not layout.passes.is_empty():
		var p0: Dictionary = layout.passes[0]
		var to0: Vector3 = (p0.at as Vector3).normalized()
		shots.append({"view":"valley","eye":to0*60.0+Vector3.UP*50.0,"look":p0.at+Vector3.UP*35.0,"fov":62.0})
	shots.append({"view":"sea","eye":Vector3.UP*60.0,"look":Vector3(0,0,-1)*1200.0+Vector3.DOWN*260.0,"fov":75.0,"styles":["opal","storybook","mystic"]})
	return shots

## Holds the eye at a shot for `count` frames at `hour`, advancing the sky,
## the haze and the islands as the glide would (tools/capture_sky_ring.gd).
func _hold(shot: Dictionary, hour: float, count: int) -> void:
	var at: Vector3 = shot.eye
	var look: Vector3 = shot.look
	var way := (look-at).normalized()
	var glide: RefCounted = eye.glide
	glide.position = at
	glide.heading = atan2(-way.x,-way.z)
	glide.pitch = asin(clampf(way.y,-1.0,1.0))
	glide.bank = 0.0
	glide.speed = 8.0
	glide.velocity = glide.forward()*8.0
	eye.glider.visible = false
	for i in range(count):
		scene.world_clock.running = false
		scene.world_clock.set_time(scene.world_clock.day,hour)
		var delta := 1.0/60.0
		eye.sky.haze = 1.0
		eye.sky.advance(delta,at,0.0)
		eye.islands.advance(delta,at,glide.heading,0.0)
		if i == 1: eye.islands.peaks.flush()
		var o := at-look
		scene.target = look
		scene.distance = maxf(o.length(),0.01)
		var dir: Vector3 = o/maxf(o.length(),0.01)
		scene.yaw = atan2(dir.x,dir.z)
		scene.polar = clampf(acos(clampf(dir.y,-1.0,1.0)),0.0005,PI-0.05)
		scene.camera_roll = 0.0
		scene._auto_orbit = false
		scene._update_camera()
		eye.camera.fov = shot.get("fov",64.0)
		await process_frame
