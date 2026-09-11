extends SceneTree
## A bridge that gets built. Three things are checked, in order: the rope can
## stand with no deck on it at all and still be a rope; planks lay one at a time
## from the building end outward and the built extent only ever grows; and the
## crossing refuses to exist until the last plank is down.
##
## The first two parts are pure physics on a bare `SuspensionBridge` -- two
## anchor poses and Jolt, no terrain -- so they are quick. The third part
## instantiates the twin-chunk study, which needs a real window and the native
## kernels, and is the slow half.
##
## Never --headless: the fidelity scene hangs there.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tests/test_bridge_construction.gd
const DT := 1.0 / 60.0
## One world hour of the driver's rate, in the units `advance` takes.
const HOUR := 1.0
var failures := 0
var scene: Node3D

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
		push_error(message)

func ticks(seconds: float) -> void:
	for i in range(int(seconds * float(Engine.physics_ticks_per_second))): await physics_frame

func run() -> void:
	create_timer(900).timeout.connect(func() -> void:
		print("FAIL: the construction test never finished")
		print("Failures: 1")
		quit(1))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(960, 600)
	await _rope()
	await _planks()
	await _driver()
	await _crossing()
	print("Failures: %d" % failures)
	if scene != null:
		scene.queue_free()
		await process_frame
	quit(1 if failures > 0 else 0)

# --------------------------------------------------- the rope with no deck on it

func _rope() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var bare := _bridge(host, {"laid": 0})
	check(bare.plank_count() > 80, "An unbuilt 45 m crossing still has %d plank slots to fill" % bare.plank_count())
	check(bare.laid_count() == 0, "None of them are laid")
	check(not bare.is_complete(), "So the bridge is not complete")
	await ticks(5.0)
	check(bare.drawn_plank_count() == 0, "And not one plank is drawn: %d" % bare.drawn_plank_count())
	check(not bare.segments.is_empty(), "The ropes are strung: %d segments" % bare.segments.size())
	# The deck physics is the rope, so an unbuilt bridge still settles onto its
	# catenary and can be walked to as far as it goes.
	var drop := bare.sag_depth()
	check(drop > 0.05 * 45.0 and drop < 0.2 * 45.0, "The empty rope hangs %.2f m below the anchor line" % drop)
	check(bare.deck_motion() < 0.3, "And is at rest five seconds in: %.3f m/s" % bare.deck_motion())
	var widest := 0.0
	for i in range(bare.segments.size() - 1):
		widest = maxf(widest, bare.segments[i].global_position.distance_to(bare.segments[i + 1].global_position))
	check(widest < bare.segment_length * 1.3, "The chain is intact, widest link %.3f m" % widest)

	# A cut on a half-built bridge is the case that has no planks to take with
	# it on one side and plenty on the other. It must not crash, and it must
	# still part the rope.
	bare.set_laid(bare.plank_count() / 2)
	check(bare.cut_near_t(0.5), "A cut lands on a half-built bridge")
	await ticks(2.0)
	check(bare.is_cut(), "And parts it")
	var gap: Vector2 = bare.deck_gap()
	check(gap.y > gap.x, "The gap is a real interval: %.2f..%.2f" % [gap.x, gap.y])
	check(bare.drawn_plank_count() > 0, "And the planks that survived it are still drawn: %d" % bare.drawn_plank_count())
	host.queue_free()
	await process_frame

# ------------------------------------------------------------ laying the planks

func _planks() -> void:
	var host := Node3D.new()
	root.add_child(host)

	# Default build end is B, the island side, so the deck grows back toward A.
	var from_b := _bridge(host, {"laid": 0})
	check(from_b.built_extent() >= 0.99, "With nothing laid the built extent sits at the building end: %.3f" % from_b.built_extent())
	var last := from_b.built_extent()
	var ordered := true
	var monotonic := true
	for i in range(20):
		var laid: bool = from_b.lay_next_plank()
		if not laid: ordered = false
		var now: float = from_b.built_extent()
		if now > last + 0.0001: monotonic = false
		last = now
	check(from_b.laid_count() == 20, "Twenty calls lay twenty planks: %d" % from_b.laid_count())
	check(ordered, "Every one of them found a slot")
	check(monotonic, "And the built extent never went backwards, ending at %.3f" % last)
	check(from_b.drawn_plank_count() == 20, "Twenty planks are drawn: %d" % from_b.drawn_plank_count())
	check(last < 0.9, "Twenty planks of 45 m reaches t %.3f from the B end" % last)

	# Laying from A instead runs the other way.
	var from_a := _bridge(host, {"laid": 0, "build_from": "a"})
	check(from_a.built_extent() <= 0.01, "Building from A starts at t 0: %.3f" % from_a.built_extent())
	for i in range(20): from_a.lay_next_plank()
	check(from_a.built_extent() > 0.05 and from_a.built_extent() < 0.3, "And twenty planks reach t %.3f" % from_a.built_extent())
	check(from_a.built_extent() > 0.0, "Forward, not back")

	# Completion, and the two ways of getting there.
	var whole := _bridge(host, {"laid": 0})
	whole.set_laid(whole.plank_count())
	check(whole.is_complete(), "set_laid to the plank count completes the bridge")
	check(not whole.lay_next_plank(), "And there is nothing left to lay")
	check(absf(whole.built_extent() - 0.0) < 0.05, "The extent has reached the far end: %.3f" % whole.built_extent())
	var built := _bridge(host, {})
	check(built.is_complete(), "A bridge set up without a `laid` option is complete, as it always was")
	check(built.laid_count() == built.plank_count(), "All %d slots are laid" % built.laid_count())
	host.queue_free()
	await process_frame

# ----------------------------------------------------------------- the driver

func _driver() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var bridge := _bridge(host, {"laid": 0})
	var driver := BridgeConstruction.new()
	var seen: Array[String] = []
	driver.on_event = func(message: String) -> void: seen.append(message)
	driver.rate = 10.0
	driver.grace = 0.0
	driver.bind(bridge, 0.0)
	check(driver.progress() <= 0.0, "The driver opens at zero progress")
	# Four world hours at ten planks an hour, fed an hour at a time.
	for hour in range(4):
		driver.advance(float(hour + 1) * HOUR, 60.0)
	check(bridge.laid_count() == 40, "Ten planks a world hour over four hours lays forty: %d" % bridge.laid_count())
	# Fractions accumulate rather than being thrown away each call.
	for step in range(10):
		driver.advance(4.0 * HOUR + float(step + 1) * 0.1 * HOUR, 6.0)
	check(bridge.laid_count() == 50, "Ten tenths of an hour lay ten more: %d" % bridge.laid_count())
	check(driver.progress() > 0.0 and driver.progress() < 1.0, "Progress reads %.2f part way" % driver.progress())
	check(driver.advance_by(5) == 5, "advance_by lays exactly what it is asked for")
	check(bridge.laid_count() == 55, "Fifty-five planks down: %d" % bridge.laid_count())
	driver.complete()
	check(bridge.is_complete(), "complete() finishes the bridge")
	check(driver.progress() >= 1.0, "And progress reads 1.0")
	var quarters := 0
	for message in seen:
		if message.find("quarter") >= 0 or message.find("half") >= 0 or message.find("three") >= 0: quarters += 1
	check(seen.size() >= 3, "The build spoke up %d times: %s" % [seen.size(), seen])
	check(quarters >= 2, "Including at the quarters")
	check(seen[-1].find("complete") >= 0 or seen[-1].find("finish") >= 0, "And last of all when it was done: %s" % seen[-1])
	host.queue_free()
	await process_frame

# ------------------------------------------------- the crossing, gated on the deck

func _crossing() -> void:
	scene = load("res://studies/prototype_twin_chunks.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	var editor: Node = scene._chunk_editor
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	await scene.rebuild_second_chunk()
	scene.set_process(false)
	var bridge: Node3D = scene.bridge
	check(bridge != null and bridge.has_method("is_complete"), "The study builds a real suspension bridge")
	if bridge == null or not bridge.has_method("is_complete"):
		return
	# The study defaults to an unbuilt bridge; force it either way from here.
	scene.set_bridge_built(false)
	check(not bridge.is_complete(), "The study's bridge starts unbuilt")
	var camps: Node = scene.island_camps
	check(camps != null, "The far island still has a camp")
	if camps == null: return
	scene._process(DT)
	var crossing: CrossingRoute = scene.crossing
	check(crossing != null, "The link exists even while the bridge is unfinished")
	if crossing == null: return
	check(not crossing.crossable(), "But it is not crossable")
	var entry: Dictionary = camps.camps[scene.camp_id]
	var plan: Array[Dictionary] = crossing.plan(scene.chunk_world, scene.creature.global_position, scene.island_world, scene.island_world.to_world(entry.home))
	check(plan.is_empty(), "So there is no plan across it: %d steps" % plan.size())
	check(not scene.send_bigfoot_across(), "Bigfoot refuses the unfinished bridge")
	check(not scene.send_camper_across(), "And so does a camper")

	# The deck is walkable as far as it is built, which is what a plank-layer
	# needs and nobody else gets.
	scene.build_planks(20)
	check(bridge.laid_count() == 20, "Twenty planks go down: %d" % bridge.laid_count())
	var work: Array[Dictionary] = crossing.plan_to_deck(scene.island_world, scene.island_world.to_world(entry.home), bridge.built_extent())
	check(not work.is_empty(), "A plank-layer can still walk out to the built extent: %d steps" % work.size())
	var beyond := 0
	for step in work:
		if step.space == "deck" and float(step.t) < bridge.built_extent() - 0.001: beyond += 1
	check(beyond == 0, "And never a step past it: %d" % beyond)
	check(not crossing.crossable(), "A part-built bridge is still not a crossing")

	# Finished, everything the crossing branch already does works unchanged.
	scene.set_bridge_built(true)
	check(bridge.is_complete(), "Completing the bridge fills every slot")
	check(crossing.crossable(), "And the link becomes crossable")
	var open: Array[Dictionary] = crossing.plan(scene.chunk_world, scene.creature.global_position, scene.island_world, scene.island_world.to_world(entry.home))
	check(not open.is_empty(), "A route runs from chunk one to the island tent: %d steps" % open.size())
	check(scene.send_camper_across(), "And a camper can be sent over it")

func _bridge(host: Node3D, options: Dictionary) -> SuspensionBridge:
	var bridge := SuspensionBridge.new()
	host.add_child(bridge)
	bridge.setup(Transform3D(Basis(), Vector3(-22.5, 20, 0)), Transform3D(Basis(), Vector3(22.5, 20, 0)), options)
	return bridge
