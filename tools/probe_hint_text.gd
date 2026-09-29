extends SceneTree
## Headless probe of the hand scheme's on-screen text:
##   - the plain's old "Drag across the plain" notice does not show;
##   - the top-left badge fades in on a change, holds and fades away, and
##     follows the season;
##   - the sky's hint shows until it has been read HOVER_UNTIL times, or at
##     once goes quiet after a snap.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_hint_text.gd -- --no-title
var scene: Node3D
var reach: Node
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func point(at: Vector2) -> void:
	scene._chunk_editor.pointer_override = at
	reach.pointer_override = at

func frames(count: int) -> void:
	for i in range(count): await process_frame

func run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("hint text probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-hint-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	reach = scene.hand_reach
	var badge: Label = scene.places.badge
	check("the game is the hand scheme",scene.hand_only == true)
	check("no plain how-to notice",not scene._notice.text.contains("Drag across"),scene._notice.text)
	check("the badge names the place",not badge.text.is_empty(),badge.text)
	check("the badge shows on arrival",badge.modulate.a > 0.5,badge.modulate.a)
	await create_timer(scene.places.BADGE_HOLD+2.5).timeout
	check("then fades away",badge.modulate.a < 0.01,badge.modulate.a)
	check("and takes no pointer",not scene.places.blocks(badge.get_global_rect().get_center()))
	var before := badge.text
	var clock: WorldClock = scene.world_clock
	clock.season_override = fposmod(clock.season+0.5,1.0)
	await create_timer(0.8).timeout
	check("a season change updates the badge",badge.text != before,[before,badge.text])
	check("and shows it again",badge.modulate.a > 0.5,badge.modulate.a)

	# The sky's hint.
	var sky := Vector2.INF
	for candidate in [Vector2(40,20),Vector2(1400,20),Vector2(720,10),Vector2(40,200),Vector2(1400,200)]:
		if reach.void_at(candidate) and reach._cloud_at(candidate) == null:
			sky = candidate
			break
	check("found empty sky",sky != Vector2.INF)
	var land := Vector2(720,600)
	for i in range(reach.HOVER_UNTIL):
		point(sky)
		await frames(3)
		check("sky hover %d names the snap" % (i+1),reach._hint == reach.VOID_HINT,reach._hint)
		await create_timer(reach.HOVER_READ+0.2).timeout
		point(land+Vector2(i,0))
		await frames(3)
	point(sky+Vector2(1,1))
	await frames(3)
	check("read %d times, the sky goes quiet" % reach.HOVER_UNTIL,reach._hint == "",reach._hint)
	reach.hint_reads = {}
	point(land)
	await frames(3)
	point(sky)
	await frames(3)
	check("with the reads forgotten it names the snap again",reach._hint == reach.VOID_HINT,reach._hint)
	reach.fire_snap()
	point(land)
	await frames(3)
	point(sky+Vector2(2,0))
	await frames(3)
	check("after one snap the sky goes quiet",reach._hint == "",reach._hint)
	print("hint text probe: %s" % ("PASS" if failures.is_empty() else "FAIL "+str(failures)))
	quit(0 if failures.is_empty() else 1)
