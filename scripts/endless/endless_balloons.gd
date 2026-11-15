extends Node3D
## Hot air balloons drifting over the endless land (studies/endless_flight.gd):
## a rare sighting, one loose group of one to three at a time, the first of
## them low. They drift with the clouds (EndlessLook `wind_direction` at the
## clouds' WIND_SPEED), rise and sink gently, climb over the land, trees and
## stone ahead of them, and are taken away out of sight; the next group comes
## after a gap.
##
## Up close: the plane's wash rocks the balloon about its envelope, swings the
## basket under it and sets the cloth shuddering (shaders/balloon_canvas.gdshader);
## the burner fires now and then, and whenever the balloon climbs, with a glow
## inside the envelope and a roar at the balloon. A pass within REACH of the
## cloth or the basket is a graze for the near-miss chain (NearMiss
## `shot_pass`, as the pirate ship's balls). Nothing here is solid and nothing
## pushes the plane: flying through the cloth only shakes it, and scores nothing.
##
## Flags: --balloons=0 (or --no-balloons) none; --balloons=N the most in a
## group (3); --balloon-gap=S the mean wait between sightings (110 s);
## --balloons-now a low group of three ahead of the start, at once;
## --balloon-scale=X their size over SIZE.
##
## The model: art/blender/balloon/balloon_build.py (keep R, MOUTH_Y and
## FLOOR_Y on its numbers). Cost: a handful of nodes a balloon, no terrain
## asked per frame (three ground samples a balloon every SAMPLE_EVERY s), the
## cloth's motion in the shader; `ms` is this frame's.

const Field = preload("res://scripts/endless/land_field.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const WorldProfile = preload("res://scripts/endless/world/world_profile.gd")
const FlightSound = preload("res://scripts/endless/flight_sound.gd")
const Clouds = preload("res://scripts/endless/endless_clouds.gd")

const MODEL := "res://assets/models/balloon/balloon.glb"

## The balloon drawn this much over the model: 17 m across, 24.5 m crown to
## skids, so it reads from a kilometre off.
const SIZE := 1.3

# --- The model's numbers (m, before SIZE) ---
## The envelope's widest radius, about the balloon's origin.
const R := 6.5
## The mouth and the basket's floor under the origin.
const MOUTH_Y := -9.2
const FLOOR_Y := -12.7
## The lower cloth as a second ball, and the gondola as a rod, for the pass.
const LOW_BALL := Vector2(-5.0,3.7)
const BASKET_R := 0.9

# --- Sightings ---
## The most balloons in a group.
const GROUP := 3
## The share of groups with one, two, three balloons.
const GROUP_SHARES: Array[float] = [0.45,0.35,0.2]
## The mean wait after a group has gone (s; drawn from half to one and a half).
const GAP := 110.0
## The first sighting's wait (s).
const FIRST_GAP := Vector2(25.0,70.0)
## How far ahead of the plane a group appears (m) and within what angle of its
## heading (rad); the group's spread about that point.
const APPEAR := Vector2(1300.0,1800.0)
const APPEAR_ARC := 0.9
const SPREAD := Vector2(70.0,170.0)
## Gone past this (m), or past GONE_BEHIND and behind the view for GONE_WAIT s.
const GONE := 2400.0
const GONE_BEHIND := 900.0
const GONE_WAIT := 20.0
## The fade in and out (s).
const FADE := 3.0
## --balloons-now: each balloon's place ahead of the plane (m ahead, m right)
## and its floor over the ground.
const NOW: Array[Vector3] = [Vector3(320.0,-22.0,11.0),Vector3(430.0,38.0,17.0),Vector3(580.0,-75.0,48.0)]

# --- Height ---
## The floor over the highest of the ground, trees, stone and water under and
## ahead of the balloon (m): the low, middle and high bands.
const LOW := Vector2(11.0,19.0)
const MID := Vector2(30.0,75.0)
const HIGH := Vector2(90.0,220.0)
## The least floor over that ground, whatever the rise and sink.
const LEAST := 9.0
## The gentle rise and sink: its share of the height and its period (s).
const BOB := 0.22
const BOB_PERIOD := Vector2(55.0,110.0)
## Climb and sink rates (m/s), and the climb when the land comes up too close.
const CLIMB := 2.4
const SINK := 1.1
const CLIMB_HARD := 6.0
## Ground samples: a slice every this long a balloon (s); the set places to
## each side and ahead along the drift.
const SAMPLE_EVERY := 0.25
const SAMPLE_SIDE := 9.0
const SAMPLE_AHEAD: Array[float] = [14.0,34.0]
const SAMPLE_LOOSE := 2
const SAMPLE_EASE := 1.5

# --- The wash ---
## The plane's wash reaches this far off the cloth (m).
const WASH_REACH := 16.0
## The rock about the envelope: its rate (rad/s), damping, the push at a
## touching pass at cruise (rad/s2) and the most lean (rad).
const ROCK_RATE := 1.15
const ROCK_DAMP := 0.2
const ROCK_PUSH := 1.0
const ROCK_MOST := 0.3
## The basket's own swing under the mouth.
const SWING_RATE := 2.5
const SWING_DAMP := 0.14
const SWING_PUSH := 3.0
const SWING_MOST := 0.45
## The cloth's shudder dies in this long (s), the dent in this.
const SHUDDER_TIME := 1.7
const DENT_TIME := 0.45
const DENT := 0.85
## The motion is stepped within this of the plane (m), or while it still moves.
const AWAKE := 220.0
## A pass under this off the cloth or basket scores (m, past the wing's tip).
const REACH := 10.0

# --- The burner ---
## It fires this long (s), this far apart (s).
const BURN_TIME := Vector2(1.4,3.2)
const BURN_GAP := Vector2(7.0,19.0)
## Heard within this (m); the roar's size and level.
const HEAR := 340.0
const ROAR_UNIT := 30.0
const ROAR_DB := -3.0

# --- Drawing ---
## The full model within this (m), the far one past it.
const NEAR_END := 380.0
const NEAR_MARGIN := 24.0
## A slow turn about the balloon's axis (rad/s).
const TURN := 0.035

## The cloth's tones (sRGB): ground, second, third. Sun-faded and muted.
const PALETTES: Array = [
	[Color("5c2a25"),Color("ac9d7f"),Color("2f383b")],
	[Color("98793c"),Color("683828"),Color("aca084")],
	[Color("48606a"),Color("b5ab92"),Color("6c3a2a")],
	[Color("a89c7e"),Color("5c2b26"),Color("33342f")],
	[Color("585c40"),Color("9a8b66"),Color("5f2e27")],
]
const PATTERNS := 5

class Balloon:
	var root: Node3D
	var envelope: MeshInstance3D
	var gondola: MeshInstance3D
	var flame: MeshInstance3D
	var far: MeshInstance3D
	var roar: AudioStreamPlayer3D
	var live := false
	var leaving := false
	## Where its origin is (the envelope's middle).
	var at := Vector3.ZERO
	var rise := 0.0
	## Its floor over the ground: the middle of its rise and sink.
	var clear := 12.0
	var bob_phase := 0.0
	var bob_rate := 0.1
	## The highest ground under and ahead, as last sampled.
	var ground := 0.0
	var sample_in := 0.0
	var sample_i := 0
	var fade := 0.0
	var turn := 0.0
	var behind := 0.0
	# The rock (the basket's displacement way, rad) and the basket's swing.
	var rock := Vector2.ZERO
	var rock_v := Vector2.ZERO
	var swing := Vector2.ZERO
	var swing_v := Vector2.ZERO
	var shudder := 0.0
	var dent := 0.0
	var dent_way := Vector3.ZERO
	var still := true
	# The burner.
	var burn := 0.0
	var burn_left := 0.0
	var burn_in := 5.0
	# The pass under way: the least clearance so far, where, and through the cloth;
	# `armed` again once the plane has drawn right off.
	var armed := true
	var least := INF
	var least_at := Vector3.ZERO
	var through := false

## None at all (--balloons=0, --no-balloons, or the world's `balloons` layer off).
var enabled := true
var balloons: Array[Balloon] = []
## The numbers: groups begun, balloons taken away, passes scored, washes felt
## (one a pass), this frame's ms and its running mean.
var groups := 0
var gone := 0
var passes := 0
var washes := 0
var ms := 0.0
var ms_avg := 0.0

var _rng := RandomNumberGenerator.new()
var _most := GROUP
var _gap := GAP
var _size := SIZE
var _now := false
var _wait := 0.0
var _try_in := 0.0
var _alive := 0
var _wind := Vector2.RIGHT
var _span := 2.8

## Whether to make any: --balloons=0 or --no-balloons none.
static func wanted() -> bool:
	if not bool(WorldProfile.current().layer("balloons",true)): return false
	for a: String in LaunchArgs.user_args():
		if a == "--no-balloons" or a == "--balloons=0": return false
	return true

func setup(land_seed: int) -> void:
	_rng.seed = hash([land_seed,"balloons"])
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--balloons="): _most = clampi(int(a.get_slice("=",1)),1,GROUP)
		elif a.begins_with("--balloon-gap="): _gap = maxf(float(a.get_slice("=",1)),1.0)
		elif a.begins_with("--balloon-scale="): _size = SIZE*clampf(float(a.get_slice("=",1)),0.3,4.0)
		elif a == "--balloons-now" or a == "--balloons-now=1": _now = true
	_span = WorldScale.span
	_wait = _rng.randf_range(FIRST_GAP.x,FIRST_GAP.y)
	FlightSound.ensure_buses()
	var scene: Node = (load(MODEL) as PackedScene).instantiate()
	var canvas := ShaderMaterial.new()
	canvas.shader = load("res://shaders/balloon_canvas.gdshader")
	var gear := ShaderMaterial.new()
	gear.shader = load("res://shaders/balloon_gear.gdshader")
	var fire := ShaderMaterial.new()
	fire.shader = load("res://shaders/balloon_flame.gdshader")
	var envelope: Mesh = (scene.get_node("Envelope") as MeshInstance3D).mesh
	var gondola: Mesh = (scene.get_node("Gondola") as MeshInstance3D).mesh
	var flame: Mesh = (scene.get_node("Flame") as MeshInstance3D).mesh
	var far: Mesh = (scene.get_node("Far") as MeshInstance3D).mesh
	scene.free()
	var stream := _roar()
	for i in GROUP:
		var b := Balloon.new()
		b.root = Node3D.new()
		b.root.name = "Balloon%d" % i
		b.root.visible = false
		b.root.scale = Vector3.ONE*_size
		add_child(b.root)
		b.envelope = _part(b.root,"Envelope",envelope,[canvas],true)
		b.gondola = _part(b.root,"Gondola",gondola,[gear],true)
		b.gondola.position.y = MOUTH_Y
		b.flame = _part(b.gondola,"Flame",flame,[fire],true)
		b.flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.flame.visible = false
		b.far = _part(b.root,"Far",far,[canvas,gear],false)
		b.far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.roar = AudioStreamPlayer3D.new()
		b.roar.stream = stream
		b.roar.bus = FlightSound.AMBIENCE
		b.roar.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		b.roar.unit_size = ROAR_UNIT
		b.roar.max_distance = HEAR
		b.roar.volume_db = ROAR_DB
		b.roar.position.y = MOUTH_Y-1.5
		b.root.add_child(b.roar)
		var s := float(i)*3.7+_rng.randf()*20.0
		for g: GeometryInstance3D in [b.envelope,b.gondola,b.flame,b.far]:
			g.set_instance_shader_parameter(&"seed",s)
		balloons.append(b)

func _part(under: Node3D, part: String, mesh: Mesh, mats: Array, near: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = part
	m.mesh = mesh
	for i in mats.size(): m.set_surface_override_material(i,mats[i])
	if near:
		m.visibility_range_end = NEAR_END*_size
		m.visibility_range_end_margin = NEAR_MARGIN
	else:
		m.visibility_range_begin = NEAR_END*_size
		m.visibility_range_begin_margin = NEAR_MARGIN
	under.add_child(m)
	return m

## How many are in the world.
func alive() -> int:
	return _alive

## A frame: `game` is the study (its plane, camera, look, near, plane_ground).
func step(delta: float, game: Node) -> void:
	if not enabled: return
	var t0 := Time.get_ticks_usec()
	var plane: RefCounted = game.plane
	var eye: Vector3 = game.camera.global_position
	if _now and bool(game.hand_landing.flying()):
		_now = false
		_place_now(game)
	if _alive == 0:
		_wait -= delta
		if _wait <= 0.0:
			_try_in -= delta
			if _try_in <= 0.0:
				_try_in = 2.0
				_appear(game)
	else:
		if game.look != null: _wind = game.look.wind_direction
		var drift := Vector3(_wind.x,0.0,_wind.y)*(Clouds.WIND_SPEED*delta)
		var view: Vector3 = -game.camera.global_basis.z
		for b in balloons:
			if b.live: _fly(b,delta,drift,game,plane,eye,view)
		if _alive == 0: _wait = _gap*_rng.randf_range(0.5,1.5)
	ms = float(Time.get_ticks_usec()-t0)/1000.0
	ms_avg = lerpf(ms_avg,ms,0.02)

# --- Coming and going -------------------------------------------------------------

## The highest of the land, trees, stone and water at `p`.
func _ground_at(game: Node, p: Vector3) -> float:
	var g: Variant = game.plane_ground(p,2.0)
	var h: float = float(g) if g is float else float(game.field.height(p.x,p.z))
	var river: float = game.field.river_y(p.x,p.z)
	if not is_nan(river): h = maxf(h,river)
	return maxf(h,Field.SEA_Y)

## A slice of `b`'s ground samples: one of the five set places (under it, to
## each side, two ahead along the drift) and SAMPLE_LOOSE at random under the
## basket's way ahead, as a tree's spire slips between the set ones. What they
## find is held a while (eased down SAMPLE_EASE m/s), so the highest of the
## last few seconds stands.
func _sample(b: Balloon, game: Node) -> void:
	var p := b.at
	var along := Vector3(_wind.x,0.0,_wind.y)
	var side := Vector3(-_wind.y,0.0,_wind.x)*(SAMPLE_SIDE*_size)
	var g := -INF
	match b.sample_i:
		0: g = _ground_at(game,p)
		1: g = _ground_at(game,p+side)
		2: g = _ground_at(game,p-side)
		3: g = _ground_at(game,p+along*SAMPLE_AHEAD[0])
		_: g = _ground_at(game,p+along*SAMPLE_AHEAD[1])
	b.sample_i = (b.sample_i+1)%5
	for i in SAMPLE_LOOSE:
		g = maxf(g,_ground_at(game,p+along*_rng.randf_range(-4.0,SAMPLE_AHEAD[1])+side*_rng.randf_range(-0.8,0.8)))
	b.ground = maxf(g,b.ground-SAMPLE_EASE*SAMPLE_EVERY)

## A group somewhere ahead of the plane, out past APPEAR, off the Peak.
func _appear(game: Node) -> void:
	var plane: RefCounted = game.plane
	var turn := float(plane.heading)+_rng.randf_range(-APPEAR_ARC,APPEAR_ARC)
	var mid: Vector3 = plane.position+Vector3(-sin(turn),0.0,-cos(turn))*_rng.randf_range(APPEAR.x,APPEAR.y)
	if not _free(game,mid): return
	var count := 1
	var roll := _rng.randf()
	if roll > GROUP_SHARES[0]: count = 2
	if roll > GROUP_SHARES[0]+GROUP_SHARES[1]: count = 3
	count = mini(count,_most)
	var way := _rng.randf()*TAU
	for i in count:
		var at := mid
		var band := LOW
		if i > 0:
			way += _rng.randf_range(1.6,2.6)
			at += Vector3(cos(way),0.0,sin(way))*_rng.randf_range(SPREAD.x,SPREAD.y)
			# The second is often low too, the third higher up.
			band = (LOW if _rng.randf() < 0.5 else MID) if i == 1 else (MID if _rng.randf() < 0.5 else HIGH)
		_put(balloons[i],game,at,_rng.randf_range(band.x,band.y),0.0)
	groups += 1

## Whether a balloon may stand over `p`: not on the Peak's massif.
func _free(game: Node, p: Vector3) -> bool:
	var peak: RefCounted = game.field.peak()
	return peak == null or not bool(peak.reaches(p.x,p.z))

## --balloons-now: the low group ahead of the plane, already there.
func _place_now(game: Node) -> void:
	for b in balloons:
		if b.live: _take(b)
	var plane: RefCounted = game.plane
	var ahead := Vector3(-sin(float(plane.heading)),0.0,-cos(float(plane.heading)))
	var right := Vector3(-ahead.z,0.0,ahead.x)
	for i in mini(NOW.size(),_most):
		var n := NOW[i]
		_put(balloons[i],game,plane.position+ahead*n.x+right*n.y,n.z,1.0)
	groups += 1

func _put(b: Balloon, game: Node, at: Vector3, clear: float, fade: float) -> void:
	if game.look != null: _wind = game.look.wind_direction
	b.live = true
	b.leaving = false
	b.clear = clear
	b.bob_phase = _rng.randf()*TAU
	b.bob_rate = TAU/_rng.randf_range(BOB_PERIOD.x,BOB_PERIOD.y)
	b.at = at
	b.ground = -INF
	for i in 10: _sample(b,game)
	b.at.y = b.ground+_floor(b)-FLOOR_Y*_size
	b.sample_in = _rng.randf()*SAMPLE_EVERY
	b.rise = 0.0
	b.fade = fade
	b.turn = _rng.randf()*TAU
	b.behind = 0.0
	b.rock = Vector2.ZERO
	b.rock_v = Vector2.ZERO
	b.swing = Vector2.ZERO
	b.swing_v = Vector2.ZERO
	b.shudder = 0.0
	b.dent = 0.0
	b.still = true
	b.burn = 0.0
	b.burn_left = 0.0
	b.burn_in = _rng.randf_range(2.0,BURN_GAP.y)
	b.least = INF
	b.through = false
	b.armed = true
	# Its cloth: no two of a group alike.
	var look := _rng.randi()
	var slot := balloons.find(b)
	var tones: Array = PALETTES[(look+slot)%PALETTES.size()]
	var pattern := float(((look>>8)+slot*2)%PATTERNS)
	for g: GeometryInstance3D in [b.envelope,b.far]:
		g.set_instance_shader_parameter(&"tone_a",tones[0])
		g.set_instance_shader_parameter(&"tone_b",tones[1])
		g.set_instance_shader_parameter(&"tone_c",tones[2])
		g.set_instance_shader_parameter(&"pattern",pattern)
	b.envelope.set_instance_shader_parameter(&"shudder",0.0)
	b.envelope.set_instance_shader_parameter(&"wash",Vector4.ZERO)
	_set_burn(b,0.0)
	_set_fade(b,fade)
	b.root.position = b.at
	b.root.basis = Basis(Vector3.UP,b.turn).scaled(Vector3.ONE*_size)
	b.gondola.basis = Basis.IDENTITY
	b.root.visible = true
	_alive += 1

func _take(b: Balloon) -> void:
	if not b.live: return
	b.live = false
	b.root.visible = false
	if b.roar.playing: b.roar.stop()
	_alive -= 1
	gone += 1

## The floor over the ground now: the band's height with its rise and sink.
func _floor(b: Balloon) -> float:
	return maxf(b.clear*(1.0+BOB*sin(b.bob_phase)),LEAST)

func _set_fade(b: Balloon, f: float) -> void:
	for g: GeometryInstance3D in [b.envelope,b.gondola,b.far]:
		g.set_instance_shader_parameter(&"fade",f)

func _set_burn(b: Balloon, v: float) -> void:
	for g: GeometryInstance3D in [b.envelope,b.gondola,b.flame,b.far]:
		g.set_instance_shader_parameter(&"burn",v)
	b.flame.visible = v > 0.001

# --- A balloon's frame ------------------------------------------------------------

func _fly(b: Balloon, delta: float, drift: Vector3, game: Node, plane: RefCounted, eye: Vector3, view: Vector3) -> void:
	# Drift, and the height kept over the land ahead.
	b.at += drift
	b.bob_phase += b.bob_rate*delta
	b.sample_in -= delta
	if b.sample_in <= 0.0:
		b.sample_in = SAMPLE_EVERY
		_sample(b,game)
	var floor_y := b.at.y+FLOOR_Y*_size
	var want := b.ground+_floor(b)
	var rate := clampf((want-floor_y)*0.35,-SINK,CLIMB)
	if floor_y < b.ground+LEAST*0.6: rate = CLIMB_HARD
	b.rise = lerpf(b.rise,rate,minf(delta*1.5,1.0))
	b.at.y += b.rise*delta
	b.root.position = b.at

	# Going: far off, or behind the view a while; faded out, then taken.
	var off := b.at-eye
	var far2 := off.length_squared()
	if not b.leaving:
		if far2 > GONE_BEHIND*GONE_BEHIND and off.dot(view) < 0.0: b.behind += delta
		else: b.behind = 0.0
		if far2 > GONE*GONE or b.behind > GONE_WAIT: b.leaving = true
	if b.leaving:
		b.fade -= delta/FADE
		if b.fade <= 0.0 or off.dot(view) < 0.0:
			_take(b)
			return
		_set_fade(b,b.fade)
	elif b.fade < 1.0:
		b.fade = minf(b.fade+delta/FADE,1.0)
		_set_fade(b,b.fade)

	# The burner: on its own time, and while the balloon climbs.
	if b.burn_left > 0.0:
		b.burn_left -= delta
	else:
		b.burn_in -= delta
		if b.burn_in <= 0.0 or (b.rise > CLIMB*0.6 and b.burn <= 0.01):
			b.burn_left = _rng.randf_range(BURN_TIME.x,BURN_TIME.y)
			b.burn_in = _rng.randf_range(BURN_GAP.x,BURN_GAP.y)
			if far2 < HEAR*HEAR:
				b.roar.pitch_scale = _rng.randf_range(0.92,1.08)
				b.roar.play(_rng.randf()*1.5)
	var burn_to := 1.0 if b.burn_left > 0.0 else 0.0
	if b.burn != burn_to:
		b.burn = move_toward(b.burn,burn_to,delta*(5.0 if burn_to > 0.0 else 2.2))
		_set_burn(b,b.burn)
		if b.roar.playing:
			b.roar.volume_db = ROAR_DB+linear_to_db(maxf(b.burn,0.02))
			if b.burn <= 0.0: b.roar.stop()

	# The slow turn; the rest only near the plane or while it still moves.
	b.turn += TURN*delta
	var to: Vector3 = plane.position-b.at
	var d2 := to.length_squared()
	var awake := d2 < AWAKE*AWAKE
	if awake: _wash(b,delta,game,plane,to,sqrt(d2))
	if not awake and b.still:
		if far2 < NEAR_END*NEAR_END*_size*_size*1.3: b.root.basis = Basis(Vector3.UP,b.turn).scaled(Vector3.ONE*_size)
		return
	_swing(b,delta)

## The plane near `b`: its wash on the balloon, and the pass for the chain.
func _wash(b: Balloon, delta: float, game: Node, plane: RefCounted, to: Vector3, d: float) -> void:
	var r := R*_size
	# The clearance off the cloth (two balls) and the gondola (a rod).
	var cloth := d-r
	var low := Vector3(to.x,to.y-LOW_BALL.x*_size,to.z).length()-LOW_BALL.y*_size
	var rod_y := clampf(to.y,FLOOR_Y*_size,MOUTH_Y*_size)
	var rod := Vector3(to.x,to.y-rod_y,to.z).length()-BASKET_R*_size
	var clear := minf(minf(cloth,low),rod)
	if clear < WASH_REACH:
		var speed := float(plane.speed)
		var k := 1.0-clampf(clear/WASH_REACH,0.0,1.0)
		k = k*k*clampf(speed/float(plane.cruise()),0.5,1.8)
		# The basket is carried the plane's way and off its side.
		var vel: Vector3 = plane.velocity
		var push := Vector2(vel.x,vel.z).normalized()-Vector2(to.x,to.z).normalized()*0.6
		if push.length_squared() > 0.0001: push = push.normalized()
		b.rock_v += push*(ROCK_PUSH*k*delta)
		b.swing_v += push*(SWING_PUSH*k*delta)
		var shook := b.shudder
		b.shudder = maxf(b.shudder,minf(k*1.2,1.0))
		if shook < 0.15 and b.shudder >= 0.15: washes += 1
		if k*DENT > b.dent:
			b.dent = k*DENT
			# The dent's way in the envelope's own frame.
			b.dent_way = (b.root.basis.orthonormalized().inverse()*to).normalized()
		b.still = false
	# The pass: the least clearance, scored once the plane draws off again.
	var past := clear-_span*0.5
	if past >= REACH+4.0:
		b.armed = true
	elif b.armed:
		if cloth < -1.0: b.through = true
		if past < b.least:
			b.least = past
			b.least_at = plane.position
	if b.least < INF and past > b.least+5.0:
		if b.least < REACH and not b.through and game.near != null:
			game.near.shot_pass(maxf(b.least,0.0),REACH,b.least_at)
			passes += 1
		b.least = INF
		b.through = false
		b.armed = false

## The rock about the envelope and the basket's swing, eased back to rest.
func _swing(b: Balloon, delta: float) -> void:
	b.rock_v += (-b.rock*(ROCK_RATE*ROCK_RATE)-b.rock_v*(2.0*ROCK_DAMP*ROCK_RATE))*delta
	b.rock += b.rock_v*delta
	if b.rock.length_squared() > ROCK_MOST*ROCK_MOST:
		b.rock = b.rock.normalized()*ROCK_MOST
		b.rock_v *= 0.5
	# The basket lags the envelope's rock and overshoots it.
	b.swing_v += (-b.swing*(SWING_RATE*SWING_RATE)-b.swing_v*(2.0*SWING_DAMP*SWING_RATE)-b.rock*0.9)*delta
	b.swing += b.swing_v*delta
	if b.swing.length_squared() > SWING_MOST*SWING_MOST:
		b.swing = b.swing.normalized()*SWING_MOST
		b.swing_v *= 0.5
	b.shudder = maxf(b.shudder-delta/SHUDDER_TIME,0.0)
	b.dent = maxf(b.dent-delta/DENT_TIME*DENT,0.0)
	var spin := Basis(Vector3.UP,b.turn)
	var lean := b.rock.length()
	var basis := spin
	if lean > 0.0001:
		# About the level axis that carries the basket along `rock`.
		basis = Basis(Vector3(b.rock.x,0.0,b.rock.y).cross(Vector3.UP)/lean,lean)*spin
	b.root.basis = basis.scaled(Vector3.ONE*_size)
	var hang := b.swing.length()
	if hang > 0.0001:
		# The gondola's frame is the balloon's: the swing's way turned into it.
		var way := spin.inverse()*Vector3(b.swing.x,0.0,b.swing.y)
		b.gondola.basis = Basis(way.cross(Vector3.UP)/hang,hang)
	else:
		b.gondola.basis = Basis.IDENTITY
	b.envelope.set_instance_shader_parameter(&"shudder",b.shudder)
	b.envelope.set_instance_shader_parameter(&"wash",Vector4(b.dent_way.x,b.dent_way.y,b.dent_way.z,b.dent))
	if b.shudder <= 0.0 and b.dent <= 0.0 and lean < 0.002 and hang < 0.002 and b.rock_v.length_squared() < 0.00001 and b.swing_v.length_squared() < 0.00001:
		b.still = true
		b.rock = Vector2.ZERO
		b.swing = Vector2.ZERO
		b.rock_v = Vector2.ZERO
		b.swing_v = Vector2.ZERO

# --- The burner's roar ------------------------------------------------------------

## Two seconds of a propane burner: a deep rush with a hard hiss over it and a
## flutter through both, looped (its end eased into its start).
static func _roar() -> AudioStreamWAV:
	const RATE := 22050
	var n := RATE*2
	var lap := RATE/5
	var raw := PackedFloat32Array()
	raw.resize(n+lap)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var low := 0.0
	var lower := 0.0
	var mid := 0.0
	var flutter := 0.0
	for i in range(n+lap):
		var white := rng.randf()*2.0-1.0
		low = lerpf(low,white,0.045)
		lower = lerpf(lower,low,0.02)
		mid = lerpf(mid,white,0.35)
		flutter = lerpf(flutter,rng.randf(),0.004)
		raw[i] = ((low-lower)*5.5+lower*9.0+(white-mid)*0.16)*(0.62+0.76*flutter)
	var data := PackedByteArray()
	data.resize(n*2)
	for i in range(n):
		var v := raw[i]
		if i < lap:
			var f := float(i)/float(lap)
			v = v*f+raw[n+i]*(1.0-f)
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav
