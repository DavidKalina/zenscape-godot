extends RefCounted
## Pure, frame-rate-independent performance curves for a deliberate hide-and-peek behind a tree.
## Call make_variant once per performance; sample with the actor's action clock.
## Hand reach blends a cached starting palm toward the fixed trunk contact. Add
## arc * clearance OUTWARD along the corresponding side, before solving IK.
## Weight transfers ownership while the hand is still at its starting position.
## Contact stays fixed through the hold: breathing belongs in the torso, not palms.
## Spine/head are additive radians. Compression is optional positive metres down;
## only apply it when feet can remain planted. The sampler never moves the root.
## peek/peek_look are unsigned envelopes: the caller chooses the visible side
## and constrains clearance. Head yaw/roll describe the canonical peek side.

const DURATION := 9.0

static func make_variant(performance_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = performance_seed
	return {
		"tempo": rng.randf_range(0.94, 1.06),
		"amplitude": rng.randf_range(0.91, 1.08),
		"head_tilt": rng.randf_range(0.035, 0.050),
		"breath_phase": rng.randf_range(-0.35, 0.35),
		"follow_delay": rng.randf_range(-0.08, 0.09),
	}

static func duration(variant: Dictionary = {}) -> float:
	return DURATION * clampf(float(variant.get("tempo", 1.0)), 0.85, 1.15)

static func sample(time: float, variant: Dictionary = {}) -> Dictionary:
	var t := clampf(time / (duration(variant) / DURATION), 0.0, DURATION)
	var amplitude := clampf(float(variant.get("amplitude", 1.0)), 0.8, 1.2)
	var delay := clampf(float(variant.get("follow_delay", 0.0)), -0.12, 0.12)
	# Weight shifts back before the leading hand moves. A short suspended beat
	# gives the reach an intention; the torso arrives after both palms do.
	var anticipation := _window(t, 0.08, 0.42, 0.60, 1.25)
	var embrace := _window(t, 1.75, 3.10, 5.55, 7.35)
	var lead := _window(t, 0.62, 1.60, 2.12, 3.08)
	# One restrained overshoot/recovery, with zero value and slope at its edges.
	# It reads as soft mass catching up, without endless mechanical oscillation.
	var settle := _bump(t, 2.78, 3.72) - 0.32 * _bump(t, 3.48, 4.30)
	var quiet := _window(t, 3.18, 3.75, 5.15, 5.85)
	var breath := sin((t - 3.18) * TAU / 3.7 + float(variant.get("breath_phase", 0.0))) * quiet
	var goodbye := _window(t, 5.48, 5.98, 6.35, 7.35)
	var head_tilt := clampf(float(variant.get("head_tilt", 0.042)), 0.025, 0.06)
	# First become still behind the trunk. The eyes lead the curious reveal;
	# return behind cover before the arms disengage. No head-first trunk dip.
	var peek := _window(t, 2.70, 3.50, 5.20, 5.90)
	var peek_look := _window(t, 2.50, 3.15, 5.10, 5.70)
	var spine := Vector3(
		-0.032 * anticipation + 0.022 * embrace + 0.006 * settle + 0.002 * breath,
		-0.036 * lead + 0.012 * goodbye,
		0.003 * breath
	) * amplitude
	spine.x = clampf(spine.x, -0.04, 0.04)
	# Lateral clearance comes from the caller, not a fixed bend into the trunk.
	# A small raised chin keeps the face clear while the head turns to look.
	var attention := _window(t, 0.0, 0.55, 6.50, 7.80)
	var head := Vector3(-0.012 * attention - 0.012 * peek_look,
		0.10 * peek_look, -head_tilt * peek_look)
	return {
		"hands": {
			"R": _hand(t, 0.57, 1.95, 6.20, 8.40),
			"L": _hand(t, 1.03 + delay, 2.43 + delay, 5.90, 8.10),
		},
		"peek": peek,
		"peek_look": peek_look,
		"spine": spine,
		"head": head,
		"compression": maxf(0.0, 0.019 * embrace + 0.006 * settle) * amplitude,
		"breath": breath,
		"phase": _phase(t),
	}

static func _hand(t: float, start: float, arrive: float, leave: float, finish: float) -> Dictionary:
	var inward := _q(t, start, arrive)
	var outward := _q(t, leave, finish)
	var reach := inward * (1.0 - outward)
	# Entry may use a small clearance lobe. Release is a distinct downward
	# peel, not the entry arc played backwards.
	var approach_arc := pow(sin(PI * inward), 2.0)
	return {
		"reach": reach,
		"approach": inward,
		"release": outward,
		"arc": approach_arc,
		"weight": _window(t, start - 0.38, start, finish, finish + 0.45),
		"contact": _window(t, arrive - 0.10, arrive, leave, leave + 0.10),
	}

static func _q(t: float, start: float, finish: float) -> float:
	var x := clampf((t - start) / (finish - start), 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

static func _window(t: float, start: float, arrive: float, leave: float, finish: float) -> float:
	return _q(t, start, arrive) * (1.0 - _q(t, leave, finish))

static func _bump(t: float, start: float, finish: float) -> float:
	var x := clampf((t - start) / (finish - start), 0.0, 1.0)
	# Compact cubic bell: C2 at both boundaries and exactly one at the centre.
	return 64.0 * pow(x * (1.0 - x), 3.0)

static func _phase(t: float) -> String:
	if t < 0.57: return "notice"
	if t < 1.95: return "reach"
	if t < 2.70: return "hide"
	if t < 3.50: return "peek"
	if t < 5.20: return "watch"
	if t < 5.90: return "withdraw"
	if t < 8.40: return "release"
	return "recover"
