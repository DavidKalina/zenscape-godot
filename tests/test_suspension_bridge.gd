extends SceneTree
## A rope bridge hangs, holds together, and answers the wind. Pure physics: no
## rendering, no terrain, just two anchor poses and Jolt.
var failures := 0

const SETTLE := 3.0

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

	# ------------------------------------------------------------ a level span
	var level := _bridge(host, Vector3(-4, 3, 0), Vector3(4, 3, 0), {})
	check(level.bridge.plank_count() == int(floor(8.0 / 0.4)) - 1, "An eight metre span at 0.4 m spacing lays nineteen planks: %d" % level.bridge.plank_count())
	check(absf(level.bridge.deck_point(0.0).distance_to(level.a) ) < 0.6, "The deck starts at the first anchor")
	await ticks(SETTLE)
	_assert_hangs(level, "level 8 m")

	# ------------------------------------------- a longer span, anchors unlevel
	var tilted := _bridge(host, Vector3(0, 4.2, -5), Vector3(0, 2.7, 5), {"seed": 21})
	check(tilted.bridge.plank_count() == int(floor(tilted.span / 0.4)) - 1, "The plank count follows the longer span: %d" % tilted.bridge.plank_count())
	await ticks(SETTLE)
	_assert_hangs(tilted, "10 m with a 1.5 m drop")

	# ----------------------------------------------------------------- settling
	check(level.bridge.deck_motion() < 0.25, "Three seconds in, the level deck is at rest: %.3f m/s" % level.bridge.deck_motion())
	check(tilted.bridge.deck_motion() < 0.25, "So is the unlevel one: %.3f m/s" % tilted.bridge.deck_motion())

	# --------------------------------------------------------------- the gust
	var calm := _lateral_offset(level)
	level.bridge.apply_wind(level.lateral, 7.0)
	await ticks(2.0)
	var gusted := _lateral_offset(level)
	check(absf(gusted - calm) > 0.08, "A gust pushes the middle of the deck sideways: %.3f m" % (gusted - calm))
	check(absf(gusted - calm) < 2.0, "But it does not blow the bridge away: %.3f m" % (gusted - calm))
	level.bridge.apply_wind(Vector3.ZERO, 0.0)
	# It swings back through the calm line rather than stopping on it, so the
	# return is the closest approach over the swing, not the pose at one tick.
	var closest := INF
	for sample in range(10):
		await ticks(0.5)
		closest = minf(closest, absf(_lateral_offset(level) - calm))
	check(closest < 0.08, "Dropping the wind lets it swing back through calm: %.3f m" % closest)
	check(absf(_lateral_offset(level) - calm) < 0.2, "And it stays there: %.3f m" % (_lateral_offset(level) - calm))
	_assert_hangs(level, "after the gust")

	# ----------------------------------------------------- seeds are the look
	var twin := _bridge(host, Vector3(-4, 3, 0), Vector3(4, 3, 0), {})
	check(twin.bridge.plank_count() == level.bridge.plank_count(), "The same span and seed build the same deck")

	host.queue_free()
	print("PASS: the bridge hangs, holds and sways" if failures == 0 else "FAIL: suspension bridge")
	print("Failures: ", failures)
	quit(1 if failures else 0)

func _bridge(host: Node3D, a: Vector3, b: Vector3, options: Dictionary) -> Dictionary:
	var bridge := SuspensionBridge.new()
	host.add_child(bridge)
	bridge.setup(Transform3D(Basis(), a), Transform3D(Basis(), b), options)
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	return {"bridge": bridge, "a": a, "b": b, "span": a.distance_to(b), "lateral": flat.cross(Vector3.UP)}

## Sideways travel of the mid-deck away from the line between the anchors.
func _lateral_offset(case: Dictionary) -> float:
	var bridge: SuspensionBridge = case.bridge
	return (bridge.deck_point(0.5) - (case.a as Vector3).lerp(case.b, 0.5)).dot(case.lateral)

func _assert_hangs(case: Dictionary, label: String) -> void:
	var bridge: SuspensionBridge = case.bridge
	var span: float = case.span
	var drop: float = bridge.sag_depth()
	check(drop > span * 0.03 and drop < span * 0.15, "%s: the deck hangs %.2f m below the anchor line, %.1f%% of the span" % [label, drop, drop / span * 100.0])
	var widest := 0.0
	var planks: Array = bridge.planks
	for i in range(planks.size() - 1):
		widest = maxf(widest, (planks[i] as Node3D).global_position.distance_to((planks[i + 1] as Node3D).global_position))
	check(widest < bridge.plank_spacing * 1.5, "%s: the chain is intact, widest gap %.3f m" % [label, widest])
	check(bridge.deck_point(0.0).distance_to(case.a) < 0.6, "%s: the deck still meets the first anchor" % label)
	check(bridge.deck_point(1.0).distance_to(case.b) < 0.6, "%s: and the second" % label)
