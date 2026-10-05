extends SceneTree
## The plate's seasons in the sky layer, rendered (shaders/sky_season.gdshaderinc):
## the same views in each of the four seasons E steps to (living_weather
## SEASONS), the weather held clear and the ground settled into the season
## (its gold, cold and a winter's frost) so only the season differs:
##   plate: the plate overview in the build camera, the cloud sea behind;
##   build: the build view tipped down to the horizon toward the range in
##     sight of the plate, the ranges standing round as skylines;
##   range: a range of the band from a kilometre in, at glide height (and
##     at golden hour);
##   valley: from the plate at glide height down its valley to a pass,
##     the islets on the way;
##   summit: the nearest of the sea's summits from the plate (and at
##     golden hour); summit-near: it from 900 m off across the open sea;
##   sea: the cloud sea out to the horizon from over the plate, in each of
##     the three styles (Opal, Storybook, Mystic).
## Stills are named <view>-<season>[-<style>]-<hour>.png.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sky_seasons.gd \
##     -- --no-title --still-weather --out=/private/tmp/zs-seasons
## Options: --out=DIR, --only=plate,build,range,valley,summit,summit-near,sea, --seasons=spring,winter.
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyHomes = preload("res://scripts/sky_homes.gd")
const SkyHomesScript = SkyHomes
const SkyPeakScript = preload("res://scripts/sky_peak.gd")
const SkyPeaksScript = preload("res://scripts/sky_peaks.gd")
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
	# Never takes the keyboard (tools/capture_sky_overview.gd).
	root.unfocusable = true
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
	# The build view, before the glide: the plate overview, and tipped down
	# to the horizon toward the range in sight of the plate, once the
	# ranges' skyline stands whole (tools/capture_sky_overview.gd).
	if only.is_empty() or "plate" in only or "build" in only:
		var ring: Node = scene.wanderer.islands.peaks.ring if scene.wanderer != null else null
		var began := Time.get_ticks_msec()
		if ring != null and ring.get("whole") != null:
			while not ring.whole and Time.get_ticks_msec()-began < 240000: await process_frame
			await create_timer(3.0).timeout
		var to_range := atan2(SkyHomes.RANGE.x,SkyHomes.RANGE.z)
		var was_building: bool = scene._ui.visible
		for season: String in seasons:
			await _season(season)
			for shot: String in ["plate","build"]:
				if not only.is_empty() and shot not in only: continue
				scene.set_building(true)
				await frames(2)
				scene._frame_diorama()
				if shot == "build":
					scene.yaw = to_range+PI
					scene.polar = 1.5
				scene._auto_orbit = false
				scene._update_camera()
				for i in range(40):
					scene.world_clock.set_time(scene.world_clock.day,noon)
					await process_frame
				await still("%s-%s-noon" % [shot,season])
		# As it was, so the build view's tools are not over the glide's stills.
		scene.set_building(was_building)
		await frames(2)
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
	# A range of the band's (tools/capture_sky_ring.gd `approach`).
	var band: Array = layout.ranges.filter(func(q: Dictionary) -> bool: return q.get("kind","") == "run" or q.get("kind","") == "massif")
	if band.is_empty(): band = layout.ranges
	var r: Dictionary = band[band.size()/2]
	var rw := Vector3(r.at.x,0.0,r.at.z).normalized()
	shots.append({"view":"range","eye":r.at-rw*1100.0+Vector3.UP*70.0,"look":r.at+Vector3.UP*150.0,"golden":true})
	# Down the plate's region to a wall's pass (capture_sky_ring `plate-valley`).
	var outer: Array = layout.passes.filter(func(p: Dictionary) -> bool: return int(p.get("chord",1)) != 0)
	if not outer.is_empty():
		var p0: Dictionary = outer[0]
		var to0: Vector3 = (p0.at as Vector3).normalized()
		shots.append({"view":"valley","eye":to0*60.0+Vector3.UP*50.0,"look":p0.at+Vector3.UP*35.0,"fov":62.0})
	# A sea's summit (SkyWorld `_summits`) from the plate, the nearest it
	# sees clear of cumulus, and from 900 m off across the open sea
	# (tools/capture_sky_ring.gd `summit-plate`, `summit-N`).
	var summits: Array = layout.get("summits",[])
	var nearest := -1
	for i in range(summits.size()):
		var t: Vector3 = summits[i].tips[0]
		if _clear_way(Vector3.ZERO,t) and (nearest < 0 or Vector2(t.x,t.z).length() < Vector2(summits[nearest].tips[0].x,summits[nearest].tips[0].z).length()): nearest = i
	if not summits.is_empty():
		var tip: Vector3 = summits[maxi(nearest,0)].tips[0]
		var w0 := Vector3(tip.x,0.0,tip.z).normalized()
		shots.append({"view":"summit","eye":w0*40.0+Vector3.UP*90.0,"look":tip+Vector3.UP*(SkyPeakScript.SEA+20.0),"fov":44.0,"golden":true})
		shots.append({"view":"summit-near","eye":_open_side(tip,900.0)+Vector3.UP*45.0,"look":tip+Vector3.UP*(SkyPeakScript.SEA+30.0),"fov":56.0})
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
		# The ranges near the eye surveyed now and made in full at once.
		if i == 1:
			var peaks: Node3D = eye.islands.peaks
			peaks._since = peaks.CHECK
			peaks.advance(0.0,at)
			peaks.flush()
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

## A point `reach` m from `tip` (home, plate plane) to see it from at glide
## height across the open sea: of sixteen ways round, the one whose spot
## and way in to the tip stand clearest of rock, islands and the bounds.
func _open_side(tip: Vector3, reach: float) -> Vector3:
	var best := Vector3.ZERO
	var best_score := -INF
	var slots: Array = [Vector3.ZERO]
	slots.append_array(preload("res://scripts/sky_islands.gd").OFFSETS)
	for k in range(16):
		var way := Vector3(cos(TAU*k/16.0),0.0,sin(TAU*k/16.0))
		var from := Vector3(tip.x,0.0,tip.z)+way*reach
		var score := 0.0
		for s in range(0,11):
			var p := from-way*reach*0.08*s
			if SkyPeaksScript.blocks(p) and _flat(p,tip) > SkyWorld.SUMMIT_KEEP*1.5: score -= 1.0
			for q: Vector3 in slots:
				if _flat(p,q) < 120.0: score -= 1.0
			if _in_cumulus(p): score -= 3.0
		if not SkyWorld.inside(from): score -= 20.0
		# Toward the world's middle a little: the islands stand behind.
		score += 0.3*way.dot(-Vector3(tip.x,0.0,tip.z).normalized())
		if score > best_score:
			best_score = score
			best = from
	return best

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

## True if a home point stands in a cumulus's keep (SkyHomes TOWER_KEEP).
static func _in_cumulus(p: Vector3) -> bool:
	var towers: Array = [SkyHomesScript.TOWER]
	towers.append_array(SkyWorld.layout().towers)
	for t: Vector3 in towers:
		if _flat(p,t) < SkyHomesScript.TOWER_KEEP+60.0: return true
	return false

## True if the way from `a` to `b` (home) runs clear of every cumulus.
static func _clear_way(a: Vector3, b: Vector3) -> bool:
	for s in range(21):
		if _in_cumulus(a.lerp(b,s/20.0)): return false
	return true
