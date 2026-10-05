extends SceneTree
## A world is shown only once its sky is ready (scripts/sky_reveal.gd,
## studies/cozy_worlds.gd `hold_for_sky`): under the loading veil (scripts/
## title_loading.gd) the layout is worked out, every range's skyline made,
## the ranges within reach of the plate made in full and the islands round
## it baked (scripts/sky_islands.gd `make_ahead`, `sky_ready`), the sky's
## pipelines warmed, and only then the veil fades, once.
##
## First with a stand-in sky that is ready only when told: never revealed
## before, its making ahead asked every frame, the veil's line following
## its progress; its stand-ins drawn; then the veil fades and goes. Then
## the live shell started with the veil asked for ("sky_veil"): watched
## frame by frame, the veil never fades while the sky is not ready, and
## when it does, every condition holds; the islands made ahead stay out of
## the build view till a glide, the ring needs no fade of its own.
## Headless: nodes and numbers only, nothing drawn.
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyReveal = preload("res://scripts/sky_reveal.gd")
const SkyCache = preload("res://scripts/sky_cache.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print(("OK   " if ok else "FAIL ")+message)
	if not ok: failures += 1

func run() -> void:
	create_timer(900).timeout.connect(func() -> void: print("FAIL: sky reveal timed out"); quit(2))
	await _stand_in()
	await _live()
	print("PASS: sky reveal" if failures == 0 else "FAIL: sky reveal (%d)" % failures)
	quit(1 if failures else 0)

func _stand_in() -> void:
	var script := GDScript.new()
	script.source_code = """extends Node
var ready_now := false
var made := 0
var drawn := 0
func sky_ready() -> bool: return ready_now
func sky_progress() -> float: return 0.4
func make_ahead(_delta: float) -> void: made += 1
func standins() -> Array[GeometryInstance3D]:
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	drawn += 1
	var out: Array[GeometryInstance3D] = [box]
	return out
"""
	script.reload()
	var sky: Node = script.new()
	root.add_child(sky)
	var camera := Camera3D.new()
	root.add_child(camera)
	var veil: CanvasLayer = preload("res://scripts/title_loading.gd").new()
	root.add_child(veil)
	var reveal: Node = SkyReveal.new()
	root.add_child(reveal)
	reveal.hold(sky,camera,veil)
	for i in range(30): await process_frame
	check(not reveal.revealed and sky.made >= 25 and sky.drawn == 0,"Not ready: the world stays veiled, its sky made ahead every frame (%d), nothing warmed yet" % sky.made)
	check(is_equal_approx(veil._progress,0.4) and veil._label.text == "Raising the mountains","The veil says so, its line at what is made (%.2f)" % veil._progress)
	sky.ready_now = true
	var frames := 0
	while not reveal.revealed and frames < 30:
		await process_frame
		frames += 1
	check(reveal.revealed and sky.drawn == 1 and frames >= SkyReveal.FRAMES,"Ready: its pipelines warmed over %d frames, then revealed" % frames)
	check(is_instance_valid(veil) and not veil.fading,"The veil stays till it is told to go")
	veil.fade_out(0.3)
	await create_timer(0.6).timeout
	check(not is_instance_valid(veil),"Told, it fades and goes")
	for node: Node in [sky,camera,reveal]: node.queue_free()
	await process_frame

func _live() -> void:
	var scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.set_meta("sky_veil",true)
	scene.places_path = "/private/tmp/sky-reveal-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	var began := Time.get_ticks_msec()
	var hits := SkyCache.hits
	var early := 0
	var veiled := 0
	var waited := 0
	while not scene.shell_ready and waited < 60*600:
		await process_frame
		waited += 1
		var veil: Node = _veil(scene)
		var islands: Node = scene.wanderer.islands if scene.wanderer != null else null
		if veil != null and not veil.fading: veiled += 1
		# Shown (fading, or gone) while the sky is not ready.
		if islands != null and (veil == null or veil.fading) and not islands.sky_ready():
			early += 1
			print("     shown at frame %d while waiting on %s (veil %s, revealed %s)" % [waited,islands.sky_waiting(),"gone" if veil == null else "fading",str(scene.sky_reveal.revealed) if scene.sky_reveal != null else "-"])
	var islands: Node3D = scene.wanderer.islands
	var peaks: Node3D = islands.peaks
	var veil: Node = _veil(scene)
	print("     shown %.1f s after the scene started (%d skylines read back from disk)" % [(Time.get_ticks_msec()-began)/1000.0,SkyCache.hits-hits])
	check(scene.shell_ready and early == 0 and veiled > 0,"The world was veiled (%d frames) and never shown before its sky was ready" % veiled)
	var home: Vector3 = -islands.origin
	check(SkyWorld.ready() and peaks.ring.whole and peaks.ring.line_count() == SkyWorld.layout().ranges.size()+1,"Shown with the layout worked out and every skyline standing (%d)" % peaks.ring.line_count())
	var summits: int = SkyWorld.layout().get("summits",[]).size()
	check(summits > 0 and peaks.ring.summit_count() == summits,"... and every one of the sea's summits (%d of %d)" % [peaks.ring.summit_count(),summits])
	check(peaks.premade_whole(home) and peaks.premade.size() > 0 and peaks.range_count() == 0,"... the %d ranges within reach of the plate made in full ahead, none standing in the build view" % peaks.premade.size())
	check(islands.built() and not islands.lands.has(null) and islands._copies.all(func(c: Node3D) -> bool: return not c.visible),"... the islands round it baked (%d), out of the build view till a glide" % islands.copy_count())
	check(veil != null and veil.fading and peaks.ring._whole_at < 0 and scene.sky_reveal != null and scene.sky_reveal.revealed,"... its pipelines warmed, the veil fading in one gentle fade, the ring with no fade of its own")
	# The first glide starts among them: every range near made at once.
	islands.show_air(true)
	peaks.advance(0.6,Vector3(0.0,50.0,0.0))
	var started: int = peaks._making.size()+peaks.range_count()
	var all_ahead: bool = peaks._making.values().all(func(m: Dictionary) -> bool: return int(m.task) < 0)
	for i in range(started+2): peaks.advance(1.0/60.0,Vector3(0.0,50.0,0.0))
	print("     glide start: %d started (made ahead: %s), %d standing, islands shown: %s" % [started,all_ahead,peaks.range_count(),islands._copies.all(func(c: Node3D) -> bool: return c.visible)])
	check(started > 0 and all_ahead and peaks.range_count() == started and islands._copies.all(func(c: Node3D) -> bool: return c.visible),"A glide from the plate starts among them: the %d ranges near stood from those made ahead, one a frame, the islands shown" % started)
	islands.show_air(false)
	current_scene.queue_free()
	await process_frame

func _veil(scene: Node) -> Node:
	for child in scene.get_children():
		if child.get_script() == preload("res://scripts/title_loading.gd"): return child
	return null
