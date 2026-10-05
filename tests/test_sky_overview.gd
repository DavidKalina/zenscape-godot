extends SceneTree
## The sky world's mountains in the build view (scripts/sky_islands.gd
## `_process`, scripts/sky_peaks.gd `overview`, scripts/sky_ring.gd): the
## live shell, no one stepping out. As the world starts the layout is worked
## out on a worker (scripts/sky_world.gd `prepare`) and the skyline warmed
## from it, before any wander; the ranges stand round the plate in the build
## view and when inspecting the chunk, every one as its skyline (the range
## in sight of the plate's finer), none made in full; the camera's view
## reaches the band; the glide's other sky (currents, clouds, islets,
## cumulus, isles) stays away; the sea's summits stand with the skyline
## (scripts/sky_world.gd `_summits`); the plate's water mirror and the diorama's
## flip leave them out; and the build view's haze lets them stand pale in
## the distance (shaders/reference_surface_haze.gdshaderinc overview_far).
## Back from a glide the ranges made in full near it are let go.
## Headless: nodes and numbers only, nothing drawn.
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyHaze = preload("res://scripts/sky_haze.gd")
const SkyRing = preload("res://scripts/sky_ring.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print(("OK   " if ok else "FAIL ")+message)
	if not ok: failures += 1

func run() -> void:
	create_timer(900).timeout.connect(func() -> void: print("FAIL: sky overview timed out"); quit(2))
	var scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/sky-overview-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	var waited := 0
	while not (scene.places_ready and scene.shell_ready) and waited < 3000:
		await process_frame
		waited += 1
	var eye: Node = scene.wanderer
	var islands: Node3D = eye.islands if eye != null else null
	check(islands != null and not eye.active and not eye.flying,"The shell stands in the build view, no one stepped out")
	if islands == null:
		_end()
		return
	var peaks: Node3D = islands.peaks
	# Before any wander: the layout and the skyline worked out on workers.
	var began := Time.get_ticks_msec()
	var expected: int = SkyWorld.layout().ranges.size()+1 if SkyWorld.ready() else -1
	while (not SkyWorld.ready() or peaks.ring.line_count() < SkyWorld.layout().ranges.size()+1 or peaks.ring.summit_count() < SkyWorld.layout().summits.size()) and Time.get_ticks_msec()-began < 240000:
		await process_frame
	expected = SkyWorld.layout().ranges.size()+1
	print("     the skyline stood whole %.1f s after the shell (%d ranges); the layout took %.1f ms of the main thread" % [(Time.get_ticks_msec()-began)/1000.0,expected,SkyWorld.main_ms])
	check(not eye.active and not eye.flying and SkyWorld.ready() and peaks.ring.line_count() == expected,"Before any wander the layout is worked out and every range's skyline stands, the one in sight of the plate's among them (%d of %d)" % [peaks.ring.line_count(),expected])
	check(SkyWorld.main_ms < 50.0,"The layout cost the main thread %.1f ms (worked out on a worker)" % SkyWorld.main_ms)
	await _frames(3)
	_seen(scene,islands,peaks,"build view")
	# Inspecting the chunk: the build toggle off.
	scene.set_building(false)
	await _frames(3)
	_seen(scene,islands,peaks,"chunk inspected")
	scene.set_building(true)
	await _frames(2)
	# Out of the plate's water's mirror and the diorama's flip.
	var mirrored := 0
	for key in peaks.ring.lines:
		var node: Node3D = peaks.ring.lines[key].node
		if node != null and not (node.get_node("Body") as Node).has_meta("skip_reflection"): mirrored += 1
	check(mirrored == 0,"No skyline is copied into the plate's water's mirror")
	check("sky_islands.gd" in preload("res://scripts/diorama_flip.gd").LEAVE_OUT,"The diorama's flip leaves the sky world's mountains where they stand")
	# The haze: the plate's own near, the ring's curve past OVERVIEW_TO.
	var view: Variant = scene.get("_display_fog")
	var far: Variant = view.blend.get_shader_parameter("overview_far") if view != null else null
	check(far is Vector4 and (far as Vector4).w == SkyHaze.OVERVIEW_TO and SkyHaze.OVERVIEW_TO < 1000.0,"The build view's haze gives way to the ring's curve past %.0f m, short of the nearest range (%s)" % [SkyHaze.OVERVIEW_TO,str(far)])
	# Back from a glide: the ranges made in full let go.
	islands.show_air(true)
	peaks.reset(islands.cells if islands.cells != null else preload("res://scripts/sky_cells.gd").new([Vector3.ZERO]),islands.currents)
	peaks.advance(1.0,Vector3.ZERO)
	peaks.flush()
	var made: int = peaks.range_count()
	islands.show_air(false)
	await _frames(2)
	check(made > 0 and peaks.range_count() == 0 and peaks.ring.line_count() == expected and _shown(peaks) == expected,"Back from a glide the %d ranges made in full near the plate are let go, every skyline back (%d shown)" % [made,_shown(peaks)])
	_end()

func _seen(scene: Node, islands: Node3D, peaks: Node3D, label: String) -> void:
	var expected: int = peaks.ring.line_count()
	var far_band := 0.0
	for r: Dictionary in SkyWorld.layout().ranges:
		if r.kind != "far": far_band = maxf(far_band,Vector2(r.at.x,r.at.z).length()+SkyWorld.SEA_HALF*float(r.scale.x))
	check(peaks.is_visible_in_tree() and _shown(peaks) == expected and peaks.range_count() == 0,"%s: the ranges stand round the plate, every one as its skyline (%d), none made in full" % [label.capitalize(),_shown(peaks)])
	# The sea's summits with them (scripts/sky_ring.gd).
	var summits := 0
	for i in peaks.ring.summits:
		var node: Node3D = peaks.ring.summits[i].node
		if node != null and node.is_visible_in_tree() and (node.get_node("Body") as Node).has_meta("skip_reflection"): summits += 1
	var laid: int = SkyWorld.layout().summits.size()
	check(laid > 0 and summits == laid,"%s: the sea's summits stand with them (%d of %d), out of the plate's water's mirror" % [label.capitalize(),summits,laid])
	var camera: Camera3D = scene.camera
	check(camera.far >= far_band,"%s: the view reaches the band (far %.0f m, the band out to %.0f m)" % [label.capitalize(),camera.far,far_band])
	var others := [islands.currents,islands.clouds,islands.islets,islands.towers,islands.isles].filter(func(n: Node3D) -> bool: return n.visible)
	check(others.is_empty(),"%s: the glide's other sky stays away (currents, clouds, islets, cumulus, isles)" % label.capitalize())

func _shown(peaks: Node3D) -> int:
	var n := 0
	for key in peaks.ring.lines:
		if peaks.ring.showing(key): n += 1
	return n

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _end() -> void:
	print("PASS: sky overview" if failures == 0 else "FAIL: sky overview (%d)" % failures)
	current_scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
