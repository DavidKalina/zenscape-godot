extends SceneTree
## The lower world under the cloud sea (scripts/sky_below.gd, `--below`).
## Without the flag nothing changes: the plane's cushion is at FLOOR over no
## water, the painted sea parts under a fall, the ranges are cut at CUT and
## their heights and skylines are as they were. With it, a dive crosses
## into the lower world deep in a whole white-out with the sea never
## parting, the floor lies just over the ocean and the water is never sunk
## under, climbing back crosses back up, a flutter at the line never flips
## it, and the ocean follows the plane and the islands' swaps. In the live
## scene, flown down under the cloud the plane claims no island, no island
## surfaces from the sea, and the sky turns overcast and back. Headless, so
## the shaders are compiled, not drawn: the look is unverified here.
##   godot --headless --path . --script tests/test_sky_below.gd
const SkyBelow = preload("res://scripts/sky_below.gd")
const SkyFlight = preload("res://scripts/sky_flight.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyHaze = preload("res://scripts/sky_haze.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func air(_p: Vector3) -> Variant:
	return null

func run() -> void:
	_shaders()
	SkyBelow._on = 0
	_off()
	SkyBelow._on = 1
	_line()
	await _dive()
	await _follows()
	_ranges()
	_haze()
	await _live()
	SkyBelow._on = -1
	print("PASS: sky below" if failures == 0 else "FAIL: sky below")
	quit(1 if failures else 0)

func _uniforms(path: String) -> Array:
	return (load(path) as Shader).get_shader_uniform_list().map(func(e: Dictionary) -> String: return e.name)

func _shaders() -> void:
	check(_uniforms("res://shaders/sky_below_ocean.gdshader").has("home"),"The ocean compiles")
	check(_uniforms("res://shaders/sky_below_ceiling.gdshader").has("home"),"The cloud's underside compiles")
	check(_uniforms("res://shaders/reference_sky.gdshader").has("below_world"),"The sky compiles with its overcast")
	var rock := _uniforms("res://shaders/reference_surface.gdshader")
	check(rock.has("sea_open") and rock.has("below_sink"),"The ranges' rock compiles with the lower world")
	check(_uniforms("res://shaders/reference_air_blend.gdshader").has("glide_below"),"The display haze compiles with the overcast's")
	check(_uniforms("res://shaders/glide_vapour.gdshader").has("whole"),"The vapour compiles with its whole white-out")

## Without --below: the plane's cushion at FLOOR over no water, a long fall
## caught well over the sea, the sea parting, the ranges as they were.
func _off() -> void:
	check(not SkyBelow.on(),"Without --below there is no lower world")
	var plane := SkyPlane.new()
	check(plane.floor_y == SkyGlide.FLOOR and plane.water == -INF,"The floor is FLOOR (%.0f m) over no water" % plane.floor_y)
	plane.launch(Vector3(0,0,0),0.0,14.0,false)
	var lowest := INF
	for i in range(int(4.0/DT)):
		plane.step(DT,{"pitch":-1.0,"boost":1.0},air)
		lowest = minf(lowest,plane.position.y)
	for i in range(int(20.0/DT)):
		plane.step(DT,{},air)
		lowest = minf(lowest,plane.position.y)
	check(lowest > SkyFlight.SEA_Y,"A dive let go is caught over the sea (lowest %.1f m)" % lowest)
	var scene := Node3D.new()
	root.add_child(scene)
	var flight := SkyFlight.new()
	scene.add_child(flight)
	flight.setup(scene)
	flight.start(Vector3(0,0,0))
	for i in range(60): flight.advance(DT,Vector3(0,-95,0),0.0)
	check(flight.lower == null and flight.flight.w > 0.9,"Down in it the painted sea parts (%.2f)" % flight.flight.w)
	scene.free()
	check(SkyPeak.face_floor() == SkyPeak.CUT,"The ranges' faces are cut at CUT")
	check(SkyPeaks.sunk(-200.0,-105.0,-280.0) == -200.0,"Their heights are their own")

## The line: below under SEA-CROSS, back over SEA+CROSS, never between.
func _line() -> void:
	var lower := SkyBelow.new()
	check(not lower.below and not lower.ocean.visible and not lower.ceiling.visible,"It starts above, the ocean and the cloud's underside hidden")
	check(SkyBelow.band(SkyBelow.SEA) == 1.0 and SkyBelow.band(-40.0) == 0.0 and SkyBelow.band(-200.0) == 0.0,"The vapour is whole at the line and clear well over and under it")
	check(not lower.cross(SkyBelow.SEA-1.0) and not lower.below,"Just under the line it stays above")
	check(lower.cross(SkyBelow.SEA-SkyBelow.CROSS-0.1) and lower.below,"Deeper it crosses below")
	check(lower.ocean.visible and lower.ceiling.visible,"Below, the ocean and the cloud's underside show")
	var flips := 0
	for i in range(600):
		if lower.cross(SkyBelow.SEA+sin(i*0.37)*(SkyBelow.CROSS-0.2)): flips += 1
	check(flips == 0 and lower.below,"Fluttering at the line it never flips (%d)" % flips)
	check(lower.cross(SkyBelow.SEA+SkyBelow.CROSS+0.1) and not lower.below,"Over the line it crosses back above")
	lower.free()

## A plane and the sky under --below: dived, it crosses below under a
## white-out, the sea never parting; it skims the ocean and settles at the
## floor; climbed, it crosses back up.
func _dive() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var flight := SkyFlight.new()
	scene.add_child(flight)
	flight.setup(scene)
	var lower := SkyBelow.new()
	scene.add_child(lower)
	flight.lower = lower
	var plane := SkyPlane.new()
	plane.floor_y = SkyBelow.FLOOR
	plane.water = SkyBelow.OCEAN
	plane.launch(Vector3(0,0,0),0.0,14.0,false)
	flight.start(plane.position)
	var crossed_at := INF
	var veil_at_cross := 0.0
	var parted := 0.0
	var lowest := INF
	for i in range(int(40.0/DT)):
		plane.step(DT,{"pitch":-1.0,"boost":1.0},air)
		var was: bool = lower.below
		flight.advance(DT,plane.position,0.0)
		parted = maxf(parted,flight.flight.w)
		lowest = minf(lowest,plane.position.y)
		if lower.below and not was:
			crossed_at = plane.position.y
			veil_at_cross = flight.vapour
	check(lower.below,"Dived, it crosses into the lower world")
	check(crossed_at < SkyBelow.SEA and crossed_at > SkyBelow.SEA-40.0,"It crosses deep in the sea's vapour (%.1f m)" % crossed_at)
	check(veil_at_cross >= SkyBelow.SNAP,"Under a whole white-out (%.2f)" % veil_at_cross)
	check(parted == 0.0,"The painted sea never parts")
	check(lowest >= SkyBelow.OCEAN+SkyGlide.SKIM-0.001,"Held down, it skims the ocean and never sinks in (lowest %.2f m)" % lowest)
	for i in range(int(25.0/DT)):
		plane.step(DT,{},air)
		flight.advance(DT,plane.position,0.0)
	var y := plane.position.y
	check(y > SkyBelow.OCEAN and y < SkyBelow.FLOOR+4.0,"Let go, it flies on low over the water at the floor (%.1f m, the ocean %.0f)" % [y,SkyBelow.OCEAN])
	check(lower.ocean.position.y == SkyBelow.OCEAN and Vector2(lower.ocean.position.x,lower.ocean.position.z).distance_to(Vector2(plane.position.x,plane.position.z)) < 0.001,"The ocean lies under it")
	var climbed := false
	for i in range(int(60.0/DT)):
		plane.step(DT,{"pitch":1.0,"boost":1.0},air)
		flight.advance(DT,plane.position,0.0)
		if not lower.below:
			climbed = true
			break
	check(climbed and plane.position.y > SkyBelow.SEA,"Climbed, it crosses back above (%.1f m)" % plane.position.y)
	check(not lower.ocean.visible and flight.vapour > 0.5,"Back above under the vapour, the ocean hidden")
	scene.queue_free()
	await process_frame

## The ocean and the cloud's underside follow the eye, and the islands'
## swaps through the sky's flight: their patterns lie in home coordinates.
func _follows() -> void:
	var holder := GDScript.new()
	holder.source_code = "extends Node\nvar islands: Node3D\n"
	holder.reload()
	var keeper := GDScript.new()
	keeper.source_code = "extends Node3D\nvar origin := Vector3.ZERO\n"
	keeper.reload()
	var scene := Node3D.new()
	root.add_child(scene)
	var eye: Node = holder.new()
	scene.add_child(eye)
	var islands: Node3D = keeper.new()
	eye.add_child(islands)
	eye.islands = islands
	var flight := SkyFlight.new()
	eye.add_child(flight)
	flight.setup(scene)
	var lower := SkyBelow.new()
	eye.add_child(lower)
	flight.lower = lower
	flight.start(Vector3(0,0,0))
	var at := Vector3(830.0,-250.0,-415.0)
	flight.advance(DT,at,0.0)
	check(lower.ocean.position.is_equal_approx(Vector3(at.x,SkyBelow.OCEAN,at.z)) and lower.ceiling.position.is_equal_approx(Vector3(at.x,SkyBelow.SEA,at.z)),"The ocean and the cloud's underside are under and over the plane")
	# A swap: the world and the plane move by `shift`.
	var shift := Vector3(-450.0,0.0,300.0)
	islands.origin += shift
	flight.move(shift)
	flight.advance(DT,at+shift,0.0)
	var water: ShaderMaterial = (lower.ocean.mesh as PlaneMesh).material
	var home: Vector2 = water.get_shader_parameter("home")
	check(lower.ocean.position.is_equal_approx(Vector3(at.x+shift.x,SkyBelow.OCEAN,at.z+shift.z)),"After a swap it is still under the plane")
	check(home.is_equal_approx(Vector2(shift.x,shift.z)),"Its pattern moved with the world, so the water did not jump")
	scene.queue_free()
	await process_frame

## The ranges under --below: built down to just over their foot, drawn
## down so it lies under the water, solid under the ocean, and opened to
## the lower world only from below.
func _ranges() -> void:
	check(SkyPeak.face_floor() == SkyPeak.BELOW_CUT,"The ranges' faces are built on down to their foot")
	check(is_equal_approx(SkyPeaks.sunk(SkyPeak.BASE,SkyPeak.SEA,SkyPeak.BASE),SkyBelow.FOOT),"A range's foot is drawn down under the ocean")
	check(SkyPeaks.sunk(-50.0,SkyPeak.SEA,SkyPeak.BASE) == -50.0,"Over the sea it is as it was")
	var low := SkyPeaks.lift(0.15)
	var foot := SkyPeak.BASE*0.15+low
	check(foot > SkyBelow.OCEAN and SkyPeaks.sunk(foot,SkyPeak.SEA*0.15+low,foot) < SkyBelow.OCEAN,"A low ridge's foot (%.0f m) reaches the water too" % foot)
	check(SkyPeaks.sunk(-450.0,SkyPeak.SEA,-500.0) == -450.0,"One already reaching under the water is left alone")
	var peaks := SkyPeaks.new()
	var rock: ShaderMaterial = peaks._ground()
	check(rock.get_shader_parameter("below_sink") == Vector4(1.0,SkyPeak.SEA,SkyPeak.BASE,SkyBelow.FOOT),"The rock is drawn down in the shader the same way")
	check(rock.get_shader_parameter("sea_open") == false,"Above, the rock is cut at the sea as before")
	peaks.open_sea(true)
	check(rock.get_shader_parameter("sea_open") == true,"Below, it runs on down")
	peaks.free()

func _haze() -> void:
	check(SkyHaze.thickest(1.0) == SkyBelow.OCEAN and SkyHaze.thickest(0.0) == SkyHaze.SEA,"The haze is thickest by the ocean below and by the sea above")

## The live scene under --below, through the wanderer (scripts/
## wanderer_eye.gd): off the edge, then down under the cloud and back.
func _live() -> void:
	create_timer(420.0).timeout.connect(func() -> void: push_error("sky below test timed out"); quit(2))
	var scene: Node3D = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/sky-below-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not (scene.places_ready and scene.shell_ready): await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	for i in range(20): await process_frame
	var eye: Node = scene.wanderer
	check(eye.lower != null and eye.sky.lower == eye.lower,"With --below the wanderer has the lower world")
	check(eye.glide.floor_y == SkyBelow.FLOOR and eye.glide.water == SkyBelow.OCEAN,"Its plane's floor is just over the ocean")
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	eye._yaw = atan2(-1.0,0.0)+eye._turn()
	eye._polar = PI*0.5
	eye._launch(1.0)
	for i in range(2): await process_frame
	check(eye.flying and not eye.below(),"Off the edge it flies above the cloud")
	var copies: int = eye.islands.offsets.size()
	var origin: Vector3 = eye.islands.origin
	eye.glide.position.y = -200.0
	eye.glide.pitch = 0.0
	for i in range(30): await process_frame
	var sky: ShaderMaterial = scene._environment.sky.sky_material if scene.get("_environment") != null and scene._environment.sky != null else null
	check(eye.below() and eye.lower.ocean.visible,"Under the cloud it is in the lower world")
	check(sky == null or sky.get_shader_parameter("below_world") == 1.0,"And the sky is the overcast")
	check(eye.sky.flight.w == 0.0,"The painted sea never parted")
	for i in range(120): await process_frame
	check(eye.glide.position.y < SkyBelow.SEA,"It flies on under the cloud, not lifted back to the band (%.1f m)" % eye.glide.position.y)
	check(eye.islands.offsets.size() <= copies and eye.islands.origin == origin and not eye.islands.claiming,"No island surfaced or was claimed from below")
	eye.glide.position.y = -80.0
	for i in range(30): await process_frame
	check(not eye.below() and not eye.lower.ocean.visible,"Back over the cloud it is above again")
	check(sky == null or sky.get_shader_parameter("below_world") == 0.0,"And the sky is as it was")
	eye.leave()
	for i in range(5): await process_frame
	scene.queue_free()
	await process_frame
