extends SceneTree
## The bridge is a way across, not scenery. Three things are checked, in order:
## a crossing route exists and stays on the boards; a camper walks it to chunk
## one and is standing on chunk one's ground when they arrive; Bigfoot walks it
## the other way, is a resident of the island while he is there, and comes back.
##
## Instantiates the study, so it needs a real window and the native kernels.
## Never --headless: the fidelity scene hangs there.
##
## Physics-timed and long (each crossing is about fifty metres at a metre a
## second). Run it alone.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tests/test_bridge_crossing.gd
const DT := 1.0 / 60.0
## A crossing is roughly 50 m of deck plus two shore walks, at about 1 m/s.
const CROSS_FRAMES := 9000
var failures := 0
var scene: Node3D

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
		push_error(message)

## A world point in the study's own space, as `ground_y_at` asks.
func study_xz(at: Vector3) -> Vector2:
	var local: Vector3 = scene.global_transform.affine_inverse() * at
	return Vector2(local.x, local.z)

func run() -> void:
	create_timer(900).timeout.connect(func() -> void:
		print("FAIL: the study never finished")
		print("Failures: 1")
		quit(1))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(960, 600)
	scene = load("res://studies/prototype_twin_chunks.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	var editor: Node = scene._chunk_editor
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	await scene.rebuild_second_chunk()
	# The study now opens with the bridge unbuilt; these want the finished deck.
	scene.set_bridge_built(true)
	scene.set_process(false)
	var island: Node3D = scene.second_chunk
	var camps: Node = scene.island_camps
	check(camps != null, "The far island has a camp to cross to")
	if camps == null:
		finish()
		return
	scene._process(DT)

	# ------------------------------------------------------------ the route
	var crossing: CrossingRoute = scene.crossing
	check(crossing != null, "A crossing route joins the two grounds")
	if crossing == null:
		finish()
		return
	check(crossing.other(scene.chunk_world) == scene.island_world, "Its two ends are the two camps' own worlds")
	var entry: Dictionary = camps.camps[scene.camp_id]
	var plan: Array[Dictionary] = crossing.plan(scene.chunk_world, scene.creature.global_position, scene.island_world, scene.island_world.to_world(entry.home))
	check(not plan.is_empty(), "A route runs from Bigfoot on chunk one to the island tent")
	if plan.is_empty():
		finish()
		return
	var near_gap := INF
	var far_gap := INF
	var below := 0.0
	var deck_steps := 0
	for step in plan:
		near_gap = minf(near_gap, Vector3(step.point).distance_to(crossing.anchor_near))
		far_gap = minf(far_gap, Vector3(step.point).distance_to(crossing.anchor_far))
		if step.space != "deck":
			continue
		deck_steps += 1
		below = maxf(below, scene.deck_surface(float(step.t)).y - Vector3(step.point).y)
	check(near_gap <= 1.0, "It passes within a metre of the near bridgehead (%.2f m)" % near_gap)
	check(far_gap <= 1.0, "and within a metre of the far one (%.2f m)" % far_gap)
	check(deck_steps >= 8, "It walks the deck rather than the chord: %d deck waypoints" % deck_steps)
	check(below <= 0.01, "Every deck waypoint sits at or above the boards (worst %.3f m under)" % below)
	check(plan[0].world == scene.chunk_world and plan[-1].world == scene.island_world, "It starts on chunk one and ends on the island")
	print("CROSSING plan: %d steps, %.1f m, %.1f m of span" % [plan.size(), CrossingRoute.length_of(plan), crossing.span()])

	# ----------------------------------------------------------- the camper
	check(scene.send_camper_across(), "A camper can be sent over the bridge")
	var landed := false
	var frames := 0
	for frame in range(CROSS_FRAMES):
		scene._process(DT)
		frames = frame + 1
		if frame % 120 == 0:
			await process_frame
		if entry.walk == null and entry.shore == scene.chunk_world:
			landed = true
			break
	check(landed, "and reaches chunk one, in %d frames" % frames)
	var feet: Vector2 = study_xz(entry.actor.global_position)
	check(scene.ground_y_at(feet, false) != null, "The camper stands on chunk one's ground")
	check(entry.actor.global_position.y > scene.deck_surface(0.5).y, "and not under the deck")
	check(camps.camper_crossings >= 1, "The camp counts the crossing")

	# ---------------------------------------------------------- the bigfoot
	check(camps.world.resident == null, "Nobody lives on the island before he comes")
	check(scene.send_bigfoot_across(), "Bigfoot can be sent over the bridge")
	var arrived := false
	var on_deck := false
	frames = 0
	for frame in range(CROSS_FRAMES):
		scene._process(DT)
		frames = frame + 1
		if frame % 120 == 0:
			await process_frame
		if camps.bigfoot_walk != null and camps.bigfoot_walk.on_deck():
			on_deck = true
		if camps.bigfoot_walk == null and camps.world.resident != null:
			arrived = true
			break
	check(on_deck, "He walks the boards, not the air")
	check(arrived, "and steps off onto the island, in %d frames" % frames)
	var him: Vector2 = study_xz(scene.creature.global_position)
	check(scene.ground_y_at(him, true) != null, "Bigfoot stands over the far island's ground")
	check(camps.world.resident_active(), "The island has a resident while he is on it, so encounters work")
	check(camps.crossings >= 1, "The camp counts his crossing")

	# He came for the tent. Let him finish and go home again.
	var stole := false
	var home := false
	frames = 0
	for frame in range(CROSS_FRAMES * 2):
		scene._process(DT)
		frames = frame + 1
		if frame % 120 == 0:
			await process_frame
		if camps.stolen_food > 0:
			stole = true
		if stole and camps.bigfoot_home == null and camps.bigfoot_walk == null:
			home = true
			break
	check(stole, "He raids the unattended tent")
	check(home, "and walks back across, in %d frames" % frames)
	if home:
		him = study_xz(scene.creature.global_position)
		check(scene.ground_y_at(him, false) != null, "Bigfoot is home on chunk one")
		check(camps.world.resident == null, "and the island has no resident again")
	print("CROSSING events: ", camps.events)
	finish()

func finish() -> void:
	print("Failures: %d" % failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
