extends RefCounted
## The dragon's downwash (docs/design/dragon-downwash/round1.md): one field
## of air shaped round his body while he flies. Under him his wings push
## the air DOWN, pulsing with the beat: hard on the downstroke, a lull on
## the upstroke (LULL of it), so a pass under him can be timed; gliding,
## a weaker steady press (GLIDE of it). Over him, a steady UPDRAFT to ride.
## Not physical over him: the symmetry is the game (from below punished,
## from above rewarded). He never notices who rides it.
##
## Shaped from his own size (`span`: the model's wingspan, MODEL_SPAN at
## scale 1, times his scale): an ellipse ACROSS of the span out to each
## side and ALONG of it fore and aft, reaching BELOW of it down and ABOVE
## of it up, through zero within BODY of it of his middle. The wash falls
## at WASH_FALL m/s, so deeper down each beat arrives later.
##
## The dragon (scripts/sky_dragon.gd) owns one and calls `update` every
## frame (flying or not); the host reads it: `plane_air` for the plane
## (merged with the gale's gust, SkyPlane `step` adds `wind` to its
## velocity), `pilot_air` for the pocket sail (scripts/pocket_sail.gd: its
## `wind.y` under 0 presses the sail down, `thermal` lifts it). Low enough
## over turf or water, each downstroke reaching the ground is a gust there:
## the wind tool's burst (zs_burst_*, read by zs_blow_at in every plant's
## and the water's shader), running out from under him, so trees, grass and
## water take it as any other gust; gliding, a weaker one every GLIDE_EVERY s.

## The model's wingspan at scale 1 (m; rim_dragon_c.glb's rest pose).
const MODEL_SPAN := 122.0
## The field's shape, as shares of the span.
const ACROSS := 0.42
const ALONG := 0.24
const BELOW := 0.45
const ABOVE := 0.3
const BODY := 0.03
## The wash under him at the downstroke's peak (m/s down), the lull's share
## of it, the glide's steady share, and how fast it falls (m/s).
const DOWN_PEAK := 9.0
const LULL := 0.15
const GLIDE := 0.4
const WASH_FALL := 30.0
## The updraft over him (m/s up), steady.
const UP := 4.0
## The plane: the nose pushed down by the wash (rad/s at DOWN_PEAK) and a
## buffet (m/s across and up, rad/s of roll) while in it.
const PLANE_NOSE := 0.35
const PLANE_BUFFET := Vector2(1.5,1.2)
const PLANE_ROLL := 1.2
## The sail: the share of the wash that presses it down (the sail is light
## and slow: the full wash would slam it).
const SAIL_PRESS := 0.65
## The gust on the ground: how far its front runs out (share of the span)
## and in how long (s), its lean at full wash (scripts/wind_gust.gd
## BURST_LEAN's top), the least wash that sends one, and the glide's beat (s).
const RING := 0.3
const RING_RUN := 1.4
const RING_LEAN := 1.15
const RING_LEAST := 0.1
const GLIDE_EVERY := 2.5
## The beat's downstroke share (scripts/sky_dragon.gd DOWN).
const DOWN := 0.5

## His state, set by `update`.
var flying := false
var center := Vector3.ZERO
var yaw := 0.0
var span := MODEL_SPAN*1.5
var phase := 0.0
var flap_w := 0.0
var beat_hz := 0.3
var ground_y := -INF
var _clock := 0.0
var _published := false
## The gust on the ground now: where (x, z), its age (s), its lean; the
## beat as it last reached the ground, the glide's clock.
var burst := Vector4.ZERO
var _ground_phase := -1.0
var _glide_t := 0.0

## Set each frame: whether he flies (off: no air at all), his body's middle,
## heading (radians, -z at 0, as the dragon's `yaw`), scale, the beat's
## phase (0 the top, the downstroke till DOWN), how much he flaps (0 a
## glide, 1 beating) and the beat's rate (Hz); `ground` the turf under him
## (-INF none), for the foliage ring. `publish` writes the ring to the
## shaders (headless tests leave it off).
func update(delta: float, is_flying: bool, at: Vector3, heading: float, size: float, beat_phase: float, flap: float, hz: float, ground := -INF, publish := true) -> void:
	_clock += delta
	flying = is_flying
	center = at
	yaw = heading
	span = MODEL_SPAN*size
	phase = beat_phase
	flap_w = flap
	beat_hz = hz
	ground_y = ground
	_step_burst(delta)
	if publish: _publish_burst()

## The beat's push at phase `p`: 1 at the downstroke's middle, 0 on the
## upstroke.
static func pulse(p: float) -> float:
	p = fposmod(p,1.0)
	if p >= DOWN: return 0.0
	var s := sin(PI*p/DOWN)
	return s*s

## The wash's strength now at `depth` m under him (0..1 of DOWN_PEAK):
## the beat as it reaches that depth, or the glide's steady share.
func wash(depth: float) -> float:
	var ph := phase-maxf(depth,0.0)*beat_hz/WASH_FALL
	var beating := LULL+(1.0-LULL)*pulse(ph)
	return lerpf(GLIDE,beating,clampf(flap_w,0.0,1.0))

## How far inside his footprint `p` is (1 under his middle, 0 outside).
func footprint(p: Vector3) -> float:
	var rel := Vector2(p.x-center.x,p.z-center.z)
	var fwd := Vector2(-sin(yaw),-cos(yaw))
	var right := Vector2(-fwd.y,fwd.x)
	var e := Vector2(rel.dot(right)/(ACROSS*span),rel.dot(fwd)/(ALONG*span)).length()
	return 1.0-smoothstep(0.55,1.0,e)

## The air's rise at `p` (m/s: up over him, down under him), 0 away.
func air_at(p: Vector3) -> float:
	if not flying: return 0.0
	var foot := footprint(p)
	if foot <= 0.0: return 0.0
	var dy := p.y-center.y
	var body := BODY*span
	if dy >= 0.0:
		var w := smoothstep(0.0,body,dy)*(1.0-smoothstep(0.4*ABOVE*span,ABOVE*span,dy))
		return UP*w*foot
	var depth := -dy
	var w := smoothstep(0.0,body,depth)*(1.0-smoothstep(0.3*BELOW*span,BELOW*span,depth))
	return -DOWN_PEAK*wash(depth)*w*foot

## The field as air for the plane at `p`, `nose` its forward: {wind, shove,
## gust, thermal}, as dragon_gale.gd `plane_gust` gives it; empty where
## there is none.
func plane_air(p: Vector3, nose: Vector3) -> Dictionary:
	var v := air_at(p)
	if absf(v) < 0.05: return {}
	var down := maxf(-v,0.0)/DOWN_PEAK
	var t := _clock
	var n1 := sin(t*7.1+p.x*0.05)*0.6+sin(t*12.3+p.z*0.07)*0.4
	var n2 := sin(t*9.3+p.z*0.05+1.3)*0.6+sin(t*14.1+p.x*0.06)*0.4
	var side := Vector3(cos(yaw),0.0,-sin(yaw))
	var wind := Vector3.UP*v+(side*n1*PLANE_BUFFET.x+Vector3.UP*n2*PLANE_BUFFET.y)*down
	var shove := Vector3(-PLANE_NOSE*down,0.0,n1*PLANE_ROLL*down)
	return {"wind":wind,"shove":shove,"gust":down,"thermal":maxf(v,0.0)/UP}

## The field as air for the pilot's sail at `p` ({wind, thermal}, as
## PocketSail `atmosphere_air`): the wash a press down, the updraft a
## thermal (`thermal_unit` m/s a unit: PocketSail.THERMAL).
func pilot_air(p: Vector3, thermal_unit: float) -> Dictionary:
	var v := air_at(p)
	if absf(v) < 0.05: return {}
	if v < 0.0: return {"wind":Vector3.UP*v*SAIL_PRESS,"thermal":0.0}
	return {"wind":Vector3.ZERO,"thermal":v/maxf(thermal_unit,0.01)}

## Two airs as one: winds and shoves added, the strongest gust and thermal.
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.is_empty(): return b
	if b.is_empty(): return a
	var out := a.duplicate()
	out["wind"] = (a.get("wind",Vector3.ZERO) as Vector3)+(b.get("wind",Vector3.ZERO) as Vector3)
	out["shove"] = (a.get("shove",Vector3.ZERO) as Vector3)+(b.get("shove",Vector3.ZERO) as Vector3)
	out["gust"] = maxf(float(a.get("gust",0.0)),float(b.get("gust",0.0)))
	out["thermal"] = maxf(float(a.get("thermal",0.0)),float(b.get("thermal",0.0)))
	return out

## How much of the wash reaches the ground under him (0..1 of its full
## strength there, before the beat), 0 too high or over nothing.
func reach_ground() -> float:
	if not flying or not is_finite(ground_y): return 0.0
	var depth := center.y-ground_y
	if depth <= 0.0: return 0.0
	return 1.0-smoothstep(0.3*BELOW*span,BELOW*span,depth)

## A gust fired under him each time a downstroke reaches the ground (its
## phase there wrapping round to the stroke's start), or gliding every
## GLIDE_EVERY s at the glide's share; the last one aged.
func _step_burst(delta: float) -> void:
	if burst.w > 0.0:
		burst.z += delta
		if burst.z > RING_RUN+2.5: burst = Vector4.ZERO
	var reach := reach_ground()
	if reach <= 0.0:
		_ground_phase = -1.0
		return
	var depth := center.y-ground_y
	var ph := fposmod(phase-depth*beat_hz/WASH_FALL,1.0)
	var lean := 0.0
	if flap_w > 0.5:
		if _ground_phase >= 0.0 and ph < _ground_phase-0.5: lean = reach*flap_w
		_glide_t = 0.0
	else:
		_glide_t += delta
		if _glide_t >= GLIDE_EVERY:
			_glide_t = 0.0
			lean = reach*GLIDE
	_ground_phase = ph
	if lean >= RING_LEAST: burst = Vector4(center.x,center.z,0.0,lean*RING_LEAN)

## The gust as the wind tool's burst (zs_burst_*, shaders/
## reference_wind.gdshaderinc zs_blow_at: a front running out from a
## centre): cleared once when it ends.
func _publish_burst() -> void:
	if burst.w <= 0.0:
		if _published:
			RenderingServer.global_shader_parameter_set("zs_burst_a",Vector4.ZERO)
			RenderingServer.global_shader_parameter_set("zs_burst_b",Vector4.ZERO)
			_published = false
		return
	_published = true
	var travel := RING*span
	RenderingServer.global_shader_parameter_set("zs_burst_a",burst)
	RenderingServer.global_shader_parameter_set("zs_burst_b",Vector4(RING_RUN,0.0,travel,travel))
