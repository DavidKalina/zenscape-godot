extends RefCounted
## The flight study's CPU pilot (tools/flight_bench.gd, studies/flight_study.gd
## B key): it fills the same input dict a person's keys do (SkyPlane.step's
## turn, pitch, boost, brake, lean, roll), so its runs are recorded and
## measured the same way (scripts/flight_run.gd).
##
## It chases the next token with a look-ahead (pure pursuit): it aims at the
## point `look` metres on along the path from where it is through the tokens
## it knows, so near a token it is already swinging toward the one after.
## It knows a token once it has been seen for `reaction` seconds (the
## perfect reference knows every token from the start). It steers on a
## view of itself `lag` seconds old, its stick wanders by `noise` (a slow
## random drift, `drift` seconds long, half as much in pitch), and `gain` is how hard it corrects
## (per second of angle off). With `brake`, it closes the throttle when the
## way to the token swings more than BRAKE_OFF from its nose within
## BRAKE_NEAR m. Nothing else: no dodging, no knife edge, no rolls.
##
## A skill is a dictionary of those numbers (SKILLS); a station's band is
## the least skill that clears it (FlightMetrics `band`).

const SkyPlane = preload("res://scripts/sky_plane.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")

const SKILLS := {
	"sloppy":{"reaction":0.45,"lag":0.12,"look":4.0,"noise":0.16,"drift":0.35,"gain":2.0,"brake":false},
	"decent":{"reaction":0.3,"lag":0.08,"look":6.0,"noise":0.08,"drift":0.35,"gain":2.6,"brake":true},
	"sharp":{"reaction":0.18,"lag":0.04,"look":8.0,"noise":0.03,"drift":0.35,"gain":3.2,"brake":true},
	"perfect":{"reaction":0.0,"lag":0.0,"look":8.0,"noise":0.0,"drift":0.35,"gain":3.5,"brake":true,"knows_all":true},
}
## The perfect reference is flown at each of these look-aheads (m), and the
## best run kept.
const PERFECT_LOOKS := [3.0,5.0,7.0,9.0,12.0]
## The stick wanders less up and down than across (a share of `noise`).
const PITCH_NOISE := 0.5
const BRAKE_OFF := 0.6
const BRAKE_NEAR := 30.0

var params := {}
var rng := RandomNumberGenerator.new()
var _noise := Vector2.ZERO
var _past := []

func _init(skill: Dictionary, seed_value := 0) -> void:
	params = skill
	rng.seed = seed_value

static func skill(name: String) -> Dictionary:
	return (SKILLS.get(name,{}) as Dictionary).duplicate()

## This tick's input for `run`'s plane.
func input(run: RefCounted, delta: float) -> Dictionary:
	var plane: SkyPlane = run.plane
	_past.append({"t":run.t,"p":plane.position,"h":plane.heading,"pitch":plane.pitch})
	var lag := float(params.get("lag",0.0))
	var me: Dictionary = _past.back()
	while _past.size() > 1 and float(_past[1].t) <= run.t-lag: _past.pop_front()
	if lag > 0.0: me = _past.front()
	# The path through the tokens it knows, in order, from the next.
	var known: Array[Vector3] = []
	var reaction := float(params.get("reaction",0.0))
	var knows_all := bool(params.get("knows_all",false))
	for i in range(run.next_token(),run.tokens.size()):
		if i < 0: break
		if run.state[i] != run.STANDING: continue
		if not knows_all and (run.seen_at[i] < 0.0 or run.t-run.seen_at[i] < reaction): break
		known.append(run.tokens[i])
	var out := {"turn":0.0,"pitch":0.0,"boost":0.0,"brake":0.0,"lean":0.0,"roll":0.0}
	var drift := float(params.get("drift",0.35))
	var k := delta/maxf(drift,0.001)
	var sigma := float(params.get("noise",0.0))
	_noise += -_noise*k+Vector2(rng.randfn(),rng.randfn()*PITCH_NOISE)*sigma*sqrt(2.0*k)
	if known.is_empty():
		out.turn = clampf(_noise.x,-1.0,1.0)
		out.pitch = clampf(_noise.y,-1.0,1.0)
		return out
	var at: Vector3 = me.p
	var aim := _ahead(at,known,float(params.get("look",6.0)))
	var want := Metrics.angles(aim-at)
	var gain := float(params.get("gain",3.0))
	var off := angle_difference(float(me.h),want.x)
	out.turn = clampf(-gain*off/SkyPlane.TURN_RATE+_noise.x,-1.0,1.0)
	out.pitch = clampf(gain*(want.y-float(me.pitch))/SkyPlane.PITCH_SPEED+_noise.y,-1.0,1.0)
	if bool(params.get("brake",false)):
		var to_token := known[0]-at
		var off_token := absf(angle_difference(float(me.h),Metrics.angles(to_token).x))
		if off_token > BRAKE_OFF and to_token.length() < BRAKE_NEAR: out.brake = 1.0
	return out

## The point `look` m on along the path from `at` through `known`.
static func _ahead(at: Vector3, known: Array[Vector3], look: float) -> Vector3:
	var left := look
	var from := at
	for p: Vector3 in known:
		var d := from.distance_to(p)
		if d >= left: return from+(p-from)/d*left if d > 0.0001 else p
		left -= d
		from = p
	# Past the last known token: on along the way to it.
	var last := known.back() as Vector3
	var before := at if known.size() < 2 else known[known.size()-2]
	var way := (last-before)
	if way.length() < 0.001: return last
	return last+way.normalized()*left
