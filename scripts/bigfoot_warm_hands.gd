extends RefCounted
## Pure, frame-rate-independent performance curves for warming hands over the
## embers of a fire that has just gone out. Authored like bigfoot_tree_hug.gd:
## the sampler owns time, never the world. Call `sample` with the actor's
## action clock and hand the result to the actor as `environment_motion`.
##
## Beats: crouch (0.4-2.2), palms out (1.6-2.9), two-second hold (2.9-4.9),
## one slow head shake (5.1-6.9), stand (7.2-9.0), settle.
##
## `crouch` is 0..1 and `bend` is the knee angle it asks for in radians. The
## actor owns the solve: hip flexes by `bend`, the knee counter-flexes by
## `2*bend`, the ankle returns `bend`, and the pelvis drops by however much that
## fold lifted the sole. `reach` is the hand weight; palm points are the
## caller's, because only it knows where the embers are. `head` and `spine` are
## additive radians on the authored pose.

const DURATION := 10.2
## Knee angle at a full crouch, in radians.
const MAX_BEND := 0.52

static func duration(variant: Dictionary = {}) -> float:
	return DURATION*clampf(float(variant.get("tempo",1.0)),0.85,1.15)

static func make_variant(performance_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = performance_seed
	return {
		"tempo": rng.randf_range(0.95,1.05),
		"amplitude": rng.randf_range(0.94,1.06),
		"breath_phase": rng.randf_range(-0.3,0.3),
		"lead": rng.randf_range(-0.07,0.07),
	}

static func sample(time: float, variant: Dictionary = {}) -> Dictionary:
	var t := clampf(time/(duration(variant)/DURATION),0.0,DURATION)
	var amplitude := clampf(float(variant.get("amplitude",1.0)),0.85,1.15)
	var lead := clampf(float(variant.get("lead",0.0)),-0.1,0.1)
	# Sink first, reach second, so the crouch reads as the reason for the pose
	# rather than a side effect of the arms going down.
	var crouch := _window(t,0.40,2.20,7.20,9.00)
	var reach_r := _window(t,1.55+lead,2.90+lead,6.90,8.05)
	var reach_l := _window(t,1.70-lead,3.05-lead,6.75,7.90)
	# The hold is deliberately flat: two seconds of nothing but breathing is
	# what sells "these are still warm".
	var hold := _window(t,2.75,3.10,4.85,5.25)
	var breath := sin((t-2.75)*TAU/2.6+float(variant.get("breath_phase",0.0)))*hold
	# One shake, not a wobble: a single full cycle inside its own envelope.
	# The envelope opens before the cycle starts and closes after it ends, so
	# both halves of the shake read at the same size.
	var shake_gate := _window(t,4.95,5.45,6.55,7.10)
	var shake := shake_gate*sin((t-5.05)*TAU/1.85)
	var bend := MAX_BEND*crouch
	var spine := Vector3(0.12*crouch+0.022*breath,0.0,0.010*breath)*amplitude
	# Chin lifts a little out of the crouch so the face is not buried; the head
	# shake is pure yaw over that.
	var head := Vector3(-0.10*crouch,0.42*shake,-0.05*shake)*amplitude
	return {
		"crouch": crouch,
		"bend": bend,
		"reach": {"R":reach_r,"L":reach_l},
		"hold": hold,
		"shake": shake,
		"spine": spine,
		"head": head,
		"breath": breath,
		"phase": _phase(t),
	}

static func _q(t: float, start: float, finish: float) -> float:
	var x := clampf((t-start)/(finish-start),0.0,1.0)
	return x*x*x*(x*(x*6.0-15.0)+10.0)

static func _window(t: float, start: float, arrive: float, leave: float, finish: float) -> float:
	return _q(t,start,arrive)*(1.0-_q(t,leave,finish))

static func _phase(t: float) -> String:
	if t < 1.55: return "crouch"
	if t < 2.90: return "reach"
	if t < 5.10: return "hold"
	if t < 6.95: return "shake"
	if t < 9.00: return "stand"
	return "settle"
