extends Node3D
## An air ring (docs/design/air-ring/air-ring-handoff.md): a ring of worn
## stone blocks hanging in the air, lying flat, a band of light round its
## inside. Passed through (his chest crossing its plane inside HOLE), it is
## taken: the host (scripts/interactables/foot_pieces.gd `air_ring`) fills
## the updraft's charge, starts its air chain afresh and boosts him up POP m.
## Its light goes out in a burst (a bright hoop thrown out, motes off the
## rim) and comes back over COOL s, when it may be taken again.
##
## Its top is a trampoline (`try_bounce`): his feet coming down onto its
## stones bounce him BOUNCE m back up, every time with no cool-down (the
## host refills the updraft's charge each bounce too); the ring dips and
## rings out under him (FLEX_*). On a flat ring the top is the whole band of
## stones; on one tipped up on edge (as the slide rock's ring A) it is the
## stones' upper face wherever he comes down on them, in practice its upper
## rim.
##
## Lengths go by the walker's size where they meet him (`try_take`); the
## ring itself is built at size 1. It has no collision: he flies through.
const RuinKit = preload("res://scripts/ruin_kit.gd")

## m from its middle to the stones' middle; the stones' radial depth and
## height; how many.
const RADIUS := 1.75
const DEPTH := 0.42
const HIGH := 0.38
const BLOCKS := 10
const JOINT := 0.035             # rad left open between blocks
## m from its middle his chest must pass within; his chest over his feet.
const HOLE := 1.5
const CHEST := 0.9
## m the pop throws him (the spring launch's hang counted): a real boost,
## so from a ring one updraft (pop + Q: 9.7 m) reaches a ring 7.5 m on and
## a close one needs none (the user, after the first pass's 2 m pop made
## every step two updrafts); s before it is taken again.
const POP := 6.0
const COOL := 2.5
## The trampoline: m a bounce throws him (the launch's hang counted); m
## his soles reach past the stones' edge; the flex: m it dips along its
## axis, s it rings out over, its ringing (Hz), the stones' squash.
const BOUNCE := 5.0
const SOLE := 0.3
const FLEX_DIP := 0.32
const FLEX_TIME := 0.7
const FLEX_HZ := 3.2
const FLEX_SQUASH := 0.35
## The look: the band's light, its hoop thrown out on a take (s, the most
## it grows by), the drift (m, s) and turn (rad/s).
const LIGHT := Color("fbf6ea")
const TINT := Color("d2eef0")
const GLOW := 2.4
const BURST := 0.45
const BURST_GROW := 2.4
const BOB := 0.05
const BOB_TIME := 3.6
const SPIN := 0.12

var cool := 0.0
var takes := 0
var _home := Transform3D.IDENTITY
var _clock := 0.0
var _prev := NAN               # his chest's height over the plane last frame
var _feet_prev := NAN          # his feet's height over the stones' top last frame
var bounces := 0
var _flex_t := -1.0
var _flex_k := 1.0             # how hard the last bounce hit (0..1)
var _burst_t := -1.0
var _ready_at := -10.0
var _was_cool := false
var _stones: Node3D
var _band: MeshInstance3D
var _band_mat: StandardMaterial3D
var _hoop: MeshInstance3D
var _hoop_mat: StandardMaterial3D
var _motes: CPUParticles3D

func setup(pose: Transform3D, seed_value := 0) -> void:
	name = "AirRing"
	_home = pose
	transform = pose
	_clock = float(seed_value%17)*0.37
	var b := RuinKit.Build.new(seed_value,0.45,"AirRing")
	var a := PI/float(BLOCKS)-JOINT*0.5
	var hr := DEPTH*0.5
	for i in range(BLOCKS):
		var turn := TAU*float(i)/float(BLOCKS)
		var r := RADIUS+b.rng.randf_range(-0.03,0.03)
		var at := Vector3(cos(turn),0.0,-sin(turn))*r+Vector3.UP*b.rng.randf_range(-0.03,0.03)
		var pose_i := Transform3D(Basis(Vector3.UP,turn),at)
		var hh := HIGH*0.5*b.rng.randf_range(0.92,1.08)
		var planes: Array[Plane] = [Plane(Vector3.LEFT,hr),Plane(Vector3.RIGHT,hr),Plane(Vector3.UP,hh),Plane(Vector3.DOWN,hh),
			Plane(Vector3(-sin(a),0.0,cos(a)),r*sin(a)),Plane(Vector3(-sin(a),0.0,-cos(a)),r*sin(a))]
		b.solid(planes,pose_i,RuinKit._stone(b,1.25),false,true)
	_stones = b.finish()
	_stones.name = "Stones"
	add_child(_stones)
	_band_mat = _glow_mat(0.85)
	_band = _torus("Band",RADIUS-hr-0.13,RADIUS-hr+0.03,_band_mat)
	_hoop_mat = _glow_mat(0.0)
	_hoop = _torus("Hoop",RADIUS-0.04,RADIUS+0.04,_hoop_mat)
	_hoop.visible = false
	_motes = CPUParticles3D.new()
	_motes.name = "Motes"
	_motes.emitting = false
	_motes.one_shot = true
	_motes.amount = 28
	_motes.lifetime = 0.8
	_motes.explosiveness = 0.95
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_motes.emission_ring_axis = Vector3.UP
	_motes.emission_ring_radius = RADIUS
	_motes.emission_ring_inner_radius = RADIUS-0.2
	_motes.emission_ring_height = 0.1
	_motes.direction = Vector3.UP
	_motes.spread = 70.0
	_motes.initial_velocity_min = 2.0
	_motes.initial_velocity_max = 4.5
	_motes.gravity = Vector3(0.0,-3.0,0.0)
	_motes.damping_min = 2.0
	_motes.damping_max = 3.0
	_motes.scale_amount_min = 0.6
	_motes.scale_amount_max = 1.2
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	dot.radial_segments = 6
	dot.rings = 3
	dot.material = _glow_mat(1.0)
	_motes.mesh = dot
	add_child(_motes)

func _glow_mat(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(LIGHT.lerp(TINT,0.35),alpha)
	m.emission_enabled = true
	m.emission = LIGHT.lerp(TINT,0.35)
	m.emission_energy_multiplier = GLOW
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _torus(called: String, inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 48
	t.ring_segments = 8
	var view := MeshInstance3D.new()
	view.name = called
	view.mesh = t
	view.material_override = mat
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	return view

## Whether it may be taken now.
func ready_to_take() -> bool:
	return cool <= 0.0

## The world point of its middle.
func middle() -> Vector3:
	return global_transform.origin

## One frame: its drift and turn, the light coming back, the burst.
func advance(delta: float) -> void:
	_clock += delta
	cool = maxf(cool-delta,0.0)
	var flex := _flex(delta)
	transform = Transform3D(_home.basis,_home.origin+_home.basis.y*(BOB*sin(_clock*TAU/BOB_TIME)-FLEX_DIP*_flex_k*flex))
	_stones.rotation.y = _clock*SPIN
	var sq := FLEX_SQUASH*_flex_k*maxf(flex,-0.5)
	_stones.scale = Vector3(1.0+sq*0.25,1.0-sq,1.0+sq*0.25)
	_band.scale = Vector3(1.0+sq*0.2,1.0,1.0+sq*0.2)
	# The band: dark just after a take, lit back up over COOL, a swell as it
	# comes back, and a slow breath while lit.
	var back := 1.0-cool/COOL
	var lit := 0.0 if cool > 0.0 else 1.0
	var swell := 0.0
	if cool > 0.0 and back > 0.75: lit = (back-0.75)/0.25*0.6
	if cool <= 0.0 and _clock-_ready_at < 0.35: swell = 1.0-(_clock-_ready_at)/0.35
	_band_mat.albedo_color.a = 0.15+0.7*lit+0.15*swell+0.06*sin(_clock*2.1)*lit
	_band_mat.emission_energy_multiplier = GLOW*(0.25+0.75*lit+0.8*swell)
	if _burst_t >= 0.0:
		_burst_t += delta
		var k := clampf(_burst_t/BURST,0.0,1.0)
		var e := 1.0-pow(1.0-k,3.0)
		_hoop.visible = k < 1.0
		var grow := 1.0+BURST_GROW*e/RADIUS
		_hoop.scale = Vector3(grow,1.0,grow)
		_hoop_mat.albedo_color.a = (1.0-k)*0.8
		_hoop_mat.emission_energy_multiplier = GLOW*2.0*(1.0-k)
		if k >= 1.0: _burst_t = -1.0
	if cool <= 0.0 and _was_cool:
		_ready_at = _clock
		_was_cool = false

## The flex now: 1 at the bottom of the dip, ringing out to 0 (signed).
func _flex(delta: float) -> float:
	if _flex_t < 0.0: return 0.0
	_flex_t += delta
	if _flex_t >= FLEX_TIME:
		_flex_t = -1.0
		return 0.0
	var u := _flex_t/FLEX_TIME
	# Down hard in the first few frames, then rung out, dying away.
	var into := clampf(_flex_t/0.05,0.0,1.0)
	return into*cos(TAU*FLEX_HZ*maxf(_flex_t-0.05,0.0))*(1.0-u)*(1.0-u)

## The top of its stones over the ring's circle nearest `feet`: {q (the
## circle point), y (the stones' top there, world)}; {} on its axis.
func _top(feet: Vector3) -> Dictionary:
	var n := global_transform.basis.y.normalized()
	var rel := feet-middle()
	var flat := rel-n*rel.dot(n)
	if flat.length() < 0.01: return {}
	var radial := flat.normalized()
	var q := middle()+radial*RADIUS
	# Their height along the axis and depth along the radius, as each faces up.
	return {"q":q,"y":q.y+HIGH*0.5*absf(n.y)+DEPTH*0.5*absf(radial.y)}

## Whether his feet, coming down (`vel` his velocity), crossed the top of
## its stones since the last frame where they are under him; if so it
## flexes and he is to bounce (the host's). Any time, no cool-down.
func try_bounce(feet: Vector3, vel: Vector3, size := 1.0) -> bool:
	var t := _top(feet)
	if t.is_empty():
		_feet_prev = NAN
		return false
	var q: Vector3 = t.q
	var d: float = feet.y-float(t.y)
	var prev := _feet_prev
	_feet_prev = d
	if is_nan(prev) or vel.y >= 0.0 or prev < 0.0 or d > 0.0: return false
	if prev-d > 4.0: return false
	var reach := maxf(DEPTH,HIGH)*0.5+SOLE*maxf(size,0.5)
	if Vector2(feet.x-q.x,feet.z-q.z).length() > reach: return false
	bounces += 1
	_flex_t = 0.0
	_flex_k = clampf(-vel.y/12.0,0.45,1.0)
	return true

## The top of its stones under `feet`, world y (for setting him on it).
func top_at(feet: Vector3) -> float:
	var t := _top(feet)
	return feet.y if t.is_empty() else float(t.y)

## Whether his chest crossed its plane inside the hole since the last frame
## (either way); if so, and it is lit, it is taken. `chest` his chest point.
func try_take(chest: Vector3, size := 1.0) -> bool:
	var n := global_transform.basis.y.normalized()
	var c := middle()
	var d := (chest-c).dot(n)
	var prev := _prev
	_prev = d
	if not ready_to_take() or is_nan(prev) or absf(d-prev) > 4.0: return false
	if not ((prev < 0.0 and d >= 0.0) or (prev > 0.0 and d <= 0.0)): return false
	var u := prev/(prev-d) if prev != d else 1.0
	var at := chest-n*d*(1.0-u)
	var across := at-c
	across -= n*across.dot(n)
	if across.length() > HOLE*maxf(size,0.5): return false
	take()
	return true

## Taken: dark, the burst, the cool-down.
func take() -> void:
	cool = COOL
	_was_cool = true
	takes += 1
	_burst_t = 0.0
	_hoop.scale = Vector3.ONE
	_hoop.visible = true
	_motes.restart()
	_motes.emitting = true
