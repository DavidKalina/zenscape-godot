extends SceneTree
## A rope crossing hangs, holds together and answers the wind. The span it is
## tuned for is forty-five metres of level chasm; a hundred metres, a hundred
## with a drop and a short twenty-two all have to work too. Pure physics: no
## rendering, no terrain, just two anchor poses and Jolt, with the deck
## painting switched off.
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: " + message)
	else:
		failures += 1
		print("FAIL: " + message)
		push_error(message)

func ticks(seconds: float) -> void:
	for i in range(int(seconds * float(Engine.physics_ticks_per_second))): await physics_frame

func run() -> void:
	create_timer(110).timeout.connect(func() -> void: quit(2))
	var host := Node3D.new()
	root.add_child(host)

	# ------------------------------------------------ the level forty-five metres
	var long := _bridge(host, Vector3(-22.5, 20, 0), Vector3(22.5, 20, 0), {})
	check(long.bridge.segments.size() >= 24 and long.bridge.segments.size() <= 32, "Forty-five metres of rope is %d segments" % long.bridge.segments.size())
	check(long.bridge.plank_count() > 80, "And carries %d plank slots" % long.bridge.plank_count())
	await ticks(5.0)
	var settled: float = long.bridge.sag_depth()
	_assert_hangs(long, "level 45 m", 0.12, 0.14)
	var early: float = long.bridge.deck_motion()
	check(early < 0.3, "Five seconds in it is already at rest: %.3f m/s" % early)

	# A minute of standing still: no creep, no oscillation winding itself up.
	await ticks(55.0)
	# It tightens, very slowly, as the solver works the last of the stretch out
	# of the joints: about a fifth of a percent of the span in a minute, and
	# falling. Not drift away from the shape, but toward the laid one.
	check(absf(long.bridge.sag_depth() - settled) < 0.25, "A minute later it has barely moved: %.3f m, %.2f%% of the span" % [long.bridge.sag_depth() - settled, absf(long.bridge.sag_depth() - settled) / long.span * 100.0])
	check(long.bridge.deck_motion() <= maxf(0.05, early), "Nor is it swinging harder: %.3f m/s" % long.bridge.deck_motion())
	_assert_hangs(long, "level 45 m after a minute", 0.12, 0.14)

	# ------------------------------------------------------------- the weight
	var before: float = long.bridge.sag_depth()
	var weight: RigidBody3D = long.bridge.drop_weight(0.5)
	await ticks(2.5)
	check(long.bridge.sag_depth() > before, "Five kilograms lands and the deck gives: %.3f m" % (long.bridge.sag_depth() - before))
	_assert_chain(long, "under the weight")
	weight.queue_free()
	await ticks(6.0)
	check(absf(long.bridge.sag_depth() - before) < 0.2, "Six seconds after it is lifted the deck is back: %.3f m" % (long.bridge.sag_depth() - before))

	# --------------------------------------------------------------- the gust
	var calm := _lateral_offset(long)
	long.bridge.apply_wind(long.lateral, 3.0)
	await ticks(6.0)
	var bow := absf(_lateral_offset(long) - calm)
	check(bow > 0.4 and bow < 2.0, "Three metres per second squared bows the middle %.2f m" % bow)
	long.bridge.apply_wind(Vector3.ZERO, 0.0)
	# It swings back through the calm line rather than stopping on it, so the
	# return is the closest approach over the swing, not the pose at one tick.
	var closest := INF
	for sample in range(16):
		await ticks(0.5)
		closest = minf(closest, absf(_lateral_offset(long) - calm))
	check(closest < 0.3, "Dropping the wind lets it swing back through calm: %.3f m" % closest)
	_assert_chain(long, "after the gust")

	# ------------------------------------------------- the two secondary spans
	var century := _bridge(host, Vector3(-50, 40, 0), Vector3(50, 40, 0), {"seed": 3})
	var stepped := _bridge(host, Vector3(0, 24, -50), Vector3(0, 16, 50), {"seed": 3})
	var short := _bridge(host, Vector3(-11, 6, 0), Vector3(11, 3, 0), {"seed": 5})
	check(century.bridge.segments.size() <= 48, "A hundred metres caps out at %d segments of %.2f m" % [century.bridge.segments.size(), century.bridge.segment_length])
	check(short.bridge.segment_length >= 0.8, "A short span keeps its segments above the floor: %.2f m" % short.bridge.segment_length)
	await ticks(5.0)
	_assert_hangs(century, "level 100 m", 0.11, 0.16)
	_assert_hangs(stepped, "100 m with an 8 m drop", 0.11, 0.16)
	_assert_hangs(short, "22 m with a 3 m drop", 0.10, 0.18)

	host.queue_free()
	print("PASS: the crossing hangs, holds and sways" if failures == 0 else "FAIL: suspension bridge")
	print("Failures: ", failures)
	quit(1 if failures else 0)

func _bridge(host: Node3D, a: Vector3, b: Vector3, options: Dictionary) -> Dictionary:
	var bridge := SuspensionBridge.new()
	bridge.repaint_stride = 0  # Nothing renders here; do not pay for planks.
	host.add_child(bridge)
	bridge.setup(Transform3D(Basis(), a), Transform3D(Basis(), b), options)
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	return {"bridge": bridge, "a": a, "b": b, "span": a.distance_to(b), "lateral": flat.cross(Vector3.UP)}

## Sideways travel of the mid-deck away from the line between the anchors.
func _lateral_offset(case: Dictionary) -> float:
	var bridge: SuspensionBridge = case.bridge
	return (bridge.deck_point(0.5) - (case.a as Vector3).lerp(case.b, 0.5)).dot(case.lateral)

func _assert_chain(case: Dictionary, label: String) -> void:
	var bridge: SuspensionBridge = case.bridge
	var widest := 0.0
	for i in range(bridge.segments.size() - 1):
		widest = maxf(widest, bridge.segments[i].global_position.distance_to(bridge.segments[i + 1].global_position))
	check(widest < bridge.segment_length * 1.3, "%s: the rope is intact, widest link %.3f m of %.2f" % [label, widest, bridge.segment_length])

func _assert_hangs(case: Dictionary, label: String, low: float, high: float) -> void:
	var bridge: SuspensionBridge = case.bridge
	var span: float = case.span
	var drop: float = bridge.sag_depth()
	check(drop > span * low and drop < span * high, "%s: the deck hangs %.2f m below the anchor line, %.1f%% of the span" % [label, drop, drop / span * 100.0])
	_assert_chain(case, label)
	check(bridge.deck_point(0.0).distance_to(case.a) < 1.0, "%s: the deck still meets the first anchor" % label)
	check(bridge.deck_point(1.0).distance_to(case.b) < 1.0, "%s: and the second" % label)
