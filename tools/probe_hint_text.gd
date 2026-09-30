extends SceneTree
## Headless probe of the hand scheme's on-screen text:
##   - the plain's old "Drag across the plain" notice does not show;
##   - the sky's hint: it names the cloud's summon (a click in the sky no
##     longer snaps: day and night are the almanac's Time pocket) until it has
##     been read SUMMON_READS times; with --void-snap it names the snap until
##     it has been read HOVER_UNTIL times or a snap is made, then the summon;
##   - the top-left badge fades in on a change, holds and fades away, and
##     follows the season.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_hint_text.gd -- --no-title
## Add --void-snap for the sky's snap hint.
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

	# The sky's hint (before the badge's waits, which read stale fields).
	if reach.sky_snap: await snap_hint()
	else: await summon_hint()

	await create_timer(scene.places.BADGE_HOLD+2.5).timeout
	check("then fades away",badge.modulate.a < 0.01,badge.modulate.a)
	check("and takes no pointer",not scene.places.blocks(badge.get_global_rect().get_center()))
	var before := badge.text
	var clock: WorldClock = scene.world_clock
	clock.season_override = fposmod(clock.season+0.5,1.0)
	await create_timer(0.8).timeout
	check("a season change updates the badge",badge.text != before,[before,badge.text])
	check("and shows it again",badge.modulate.a > 0.5,badge.modulate.a)
	print("hint text probe: %s" % ("PASS" if failures.is_empty() else "FAIL "+str(failures)))
	quit(0 if failures.is_empty() else 1)

## Empty sky on screen, or Vector2.INF.
func find_sky() -> Vector2:
	for candidate in [Vector2(40,20),Vector2(1400,20),Vector2(720,10),Vector2(40,200),Vector2(1400,200)]:
		if reach.void_at(candidate) and reach._cloud_at(candidate) == null: return candidate
	return Vector2.INF

func click(at: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = pressed
		reach.handle(event)
		await frames(2)

## The default: no snap in the sky; its hint names the summon.
func summon_hint() -> void:
	var sky := find_sky()
	check("found empty sky",sky != Vector2.INF)
	var land := Vector2(720,600)
	var cloud: Node = reach.cloud
	var summon: String = reach.SUMMON_HINT if cloud != null and cloud.summoned else ""
	point(sky)
	await frames(3)
	check("sky hover names the summon, not the snap",reach._hint == summon and reach._hint != reach.VOID_HINT,reach._hint)
	var phase := float(scene._celestial.phase)
	var snaps: int = reach.snaps
	await click(sky)
	# The day turns on its own a little meanwhile; a snap would jump it.
	check("a click in the sky does not snap",reach.snaps == snaps and absf(angle_difference(phase*TAU,float(scene._celestial.phase)*TAU)) < 0.01,[reach.snaps-snaps,phase,scene._celestial.phase])
	check("and makes no snap sound",reach.snap_sound == null)
	if summon.is_empty(): return
	reach.hint_reads = {}
	for i in range(reach.SUMMON_READS):
		point(sky+Vector2(i+1,0))
		await frames(3)
		check("sky hover %d names the summon" % (i+1),reach._hint == summon,reach._hint)
		await create_timer(reach.HOVER_READ+0.2).timeout
		point(land+Vector2(i,0))
		await frames(3)
	point(sky+Vector2(1,1))
	await frames(3)
	check("read %d times, the sky goes quiet" % reach.SUMMON_READS,reach._hint == "",reach._hint)

## --void-snap: the sky's hint names the snap.
func snap_hint() -> void:
	var sky := find_sky()
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
	# Once the snap's hint is done, the summoned cloud's takes the sky.
	var after: String = reach.SUMMON_HINT if reach.cloud != null and reach.cloud.summoned else ""
	check("read %d times, the snap's hint goes (the summon's follows)" % reach.HOVER_UNTIL,reach._hint == after,reach._hint)
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
	check("after one snap the snap's hint goes",reach._hint == after,reach._hint)
