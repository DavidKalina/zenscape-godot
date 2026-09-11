extends SceneTree
## The rope can be cut, and when it is, the crossing stops being a crossing.
##
## Two bridges over the study's chasm: one severed at mid-span, one a couple of
## links off the near anchor so the long half swings back against its own cliff.
## The questions are the same for both -- do the halves fall, do they stay tied
## to their anchors, does anything explode, and does the deck stop claiming
## there is a plank over the gap.
##
## Pure physics with the painting left on, because the painting is half the
## deliverable: a rope drawn straight across the break would pass every physics
## assertion here.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tests/test_bridge_cut.gd
const SETTLE := 5.0      ## Seconds given to the laid deck before it is cut.
const SWING := 1.0       ## The moment after the cut, while it is still falling.
const FALL := 9.0        ## And long enough after it for both halves to hang.
## How far below the line it was laid on a free end has to end up. A 46 m span
## sags about 6 m; a half of it hanging off its anchor reaches far further.
const FREE_END_DROP := 5.0
const ANCHOR_HOLD := 1.0 ## How close the deck mouth stays to its anchor, in m.
const SANE_REACH := 200.0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
		push_error(message)

func ticks(seconds: float) -> void:
	for i in range(int(seconds * float(Engine.physics_ticks_per_second))): await physics_frame

func run() -> void:
	create_timer(180).timeout.connect(func() -> void:
		print("FAIL: the cut never finished")
		print("Failures: 1")
		quit(2))
	var host := Node3D.new()
	root.add_child(host)

	# ------------------------------------------------------- before anything
	var unbuilt := SuspensionBridge.new()
	check(not unbuilt.cut(Vector3.ZERO), "A bridge that was never built cannot be cut")
	check(not unbuilt.cut_near_t(0.5), "Nor cut at a t on a deck that does not exist")
	check(not unbuilt.is_cut() and unbuilt.cut_at() < 0.0, "And it does not claim to have parted")
	unbuilt.free()

	var mid := _bridge(host, Vector3(-23, 20, 0), Vector3(23, 20, 0), {})
	var near := _bridge(host, Vector3(-23, 20, 40), Vector3(23, 20, 40), {"seed": 3})
	await ticks(SETTLE)
	for case in [mid, near]:
		case.line = case.bridge.deck_point(0.5).y
		case.strand = _longest_strand(case.bridge)
		case.drawn = _drawn_planks(case.bridge)
		check(not case.bridge.is_cut() and case.bridge.deck_gap() == Vector2.ZERO, "%s: the laid deck is whole" % case.label)

	# ---------------------------------------------------------------- the cut
	check(mid.bridge.cut(mid.bridge.deck_point(0.5)), "A cut at mid-span takes")
	check(near.bridge.cut_near_t(0.08), "And one a couple of links off the near anchor")
	for case in [mid, near]:
		var bridge: SuspensionBridge = case.bridge
		var gap: Vector2 = bridge.deck_gap()
		check(bridge.is_cut(), "%s: the deck knows it has parted" % case.label)
		check(gap.x < gap.y and gap.x >= 0.0 and gap.y <= 1.0, "%s: the gap is one link wide, t %.3f to %.3f" % [case.label, gap.x, gap.y])
		check(absf(bridge.cut_at() - (gap.x + gap.y) * 0.5) < 0.001, "%s: and `cut_at` is the middle of it: %.3f" % [case.label, bridge.cut_at()])
		check(not bridge.cut(bridge.deck_point(0.5)), "%s: a deck that has parted cannot part again" % case.label)
	for case in [mid, near]:
		# Where the two new free ends were at the instant the rope parted: the
		# line each half has to fall away from.
		var gap: Vector2 = case.bridge.deck_gap()
		case.was_lo = case.bridge.deck_point(gap.x)
		case.was_hi = case.bridge.deck_point(gap.y)
	var target: float = near.bridge.cut_at()
	check(absf(target - 0.08) < 0.08, "The near cut landed where it was asked for: t %.3f" % target)

	# -------------------------------------------------------- while it falls
	await ticks(SWING)
	for case in [mid, near]:
		var falling: float = case.bridge.deck_motion()
		check(falling > 0.5, "%s: a second after the cut the halves are still going: %.2f m/s" % [case.label, falling])
		_assert_sane(case, "a second in")

	# ----------------------------------------------------------- and hangs
	await ticks(FALL)
	for case in [mid, near]:
		var bridge: SuspensionBridge = case.bridge
		var gap: Vector2 = bridge.deck_gap()
		var lo: Vector3 = bridge.deck_point(gap.x)
		var hi: Vector3 = bridge.deck_point(gap.y)
		_assert_sane(case, "hanging")
		# Both free ends have to have fallen away from where the cut left them.
		# A half only a couple of links long cannot drop the length of one that
		# is half the span, so what is asked of it is the length it has.
		var span: float = (case.a as Vector3).distance_to(case.b)
		_assert_fell(case, "near", case.was_lo, lo, gap.x * span)
		_assert_fell(case, "far", case.was_hi, hi, (1.0 - gap.y) * span)
		check(lo.distance_to(hi) > bridge.segment_length * 3.0, "%s: and the two ends are %.1f m apart, not one link" % [case.label, lo.distance_to(hi)])

		# Each half is still tied on.
		check(bridge.deck_point(0.0).distance_to(case.a) < ANCHOR_HOLD, "%s: the deck mouth still meets the first anchor" % case.label)
		check(bridge.deck_point(1.0).distance_to(case.b) < ANCHOR_HOLD, "%s: and the second" % case.label)
		check(bridge.segments[0].global_position.distance_to(case.a) < bridge.segment_length * 1.4, "%s: the first slab is still on its anchor, %.2f m out" % [case.label, bridge.segments[0].global_position.distance_to(case.a)])
		var last: RigidBody3D = bridge.segments[bridge.segments.size() - 1]
		check(last.global_position.distance_to(case.b) < bridge.segment_length * 1.4, "%s: and the last on its own, %.2f m out" % [case.label, last.global_position.distance_to(case.b)])

		# `deck_point` over the gap: the nearer free end, never a line across it.
		var inside: Vector3 = bridge.deck_point((gap.x + gap.y) * 0.5 - 0.001)
		var past: Vector3 = bridge.deck_point((gap.x + gap.y) * 0.5 + 0.001)
		check(inside.distance_to(lo) < 0.001, "%s: `deck_point` just inside the gap is the near free end" % case.label)
		check(past.distance_to(hi) < 0.001, "%s: and just past the middle, the far one" % case.label)
		var chord: Vector3 = lo.lerp(hi, 0.5)
		check(inside.distance_to(chord) > 1.0 or past.distance_to(chord) > 1.0, "%s: it is not a straight line across the break" % case.label)

		# The paint followed.
		var strand := _longest_strand(bridge)
		check(strand < float(case.strand) + 0.5, "%s: no rope spans the gap, longest strand %.2f m against %.2f m whole" % [case.label, strand, float(case.strand)])
		check(_drawn_planks(bridge) < int(case.drawn), "%s: the boards over the break went with it, %d of %d left" % [case.label, _drawn_planks(bridge), int(case.drawn)])

	host.queue_free()
	print("PASS: the rope can be cut and both halves hang" if failures == 0 else "FAIL: bridge cut")
	print("Failures: ", failures)
	quit(1 if failures else 0)

func _bridge(host: Node3D, a: Vector3, b: Vector3, options: Dictionary) -> Dictionary:
	var bridge := SuspensionBridge.new()
	host.add_child(bridge)
	bridge.setup(Transform3D(Basis(), a), Transform3D(Basis(), b), options)
	# The painting stays on: a rope drawn across the break is the bug this is
	# here to catch, and it cannot be seen with the repaint switched off.
	bridge.repaint_stride = 1
	return {"bridge": bridge, "a": a, "b": b, "label": "%.0f m at z %.0f" % [a.distance_to(b), a.z], "line": a.y, "strand": 0.0, "drawn": 0, "was_lo": a, "was_hi": b}

## One half has swung down off the line the cut left it on. A half with half a
## span of rope in it ends up hanging under its own anchor. A two-link stub does
## not: each joint only bends `BEND_LIMIT` radians, so a half with two of them
## in it can turn a third of a radian and no further. It droops rather than
## hangs, and a fraction of its own length is all that can be asked of it.
func _assert_fell(case: Dictionary, side: String, was: Vector3, now: Vector3, rope: float) -> void:
	if rope < 1.0:
		check(now.distance_to(was) < 1.0, "%s: the %s half is nothing but the anchor mouth, and has not moved" % [case.label, side])
		return
	var wanted: float = FREE_END_DROP if rope > 10.0 else maxf(0.4, rope * 0.15)
	check(was.y - now.y > wanted, "%s: the %s half's free end, %.0f m of rope, fell %.1f m below where the cut left it (wanted %.1f)" % [case.label, side, rope, was.y - now.y, wanted])

## Nothing has left the world, gone infinite or been flung into orbit.
func _assert_sane(case: Dictionary, label: String) -> void:
	var bridge: SuspensionBridge = case.bridge
	var worst := 0.0
	for body in bridge.segments:
		var at: Vector3 = body.global_position
		if not (is_finite(at.x) and is_finite(at.y) and is_finite(at.z)):
			check(false, "%s: %s went to NaN" % [case.label, label])
			return
		worst = maxf(worst, minf(at.distance_to(case.a), at.distance_to(case.b)))
	check(worst < SANE_REACH, "%s, %s: every slab is still in the world, furthest %.1f m from an anchor" % [case.label, label, worst])

## The longest rope tube drawn this tick, in metres: a strand across a severed
## span would be tens of metres where the whole deck's longest is a couple.
func _longest_strand(bridge: SuspensionBridge) -> float:
	var batch: MultiMesh = bridge._ropes.multimesh
	var longest := 0.0
	for i in range(batch.instance_count):
		longest = maxf(longest, batch.get_instance_transform(i).basis.y.length())
	return longest

## Boards actually placed this tick, over every tone batch.
func _drawn_planks(bridge: SuspensionBridge) -> int:
	var total := 0
	for tone in range(bridge._cursor.size()): total += bridge._cursor[tone]
	return total
