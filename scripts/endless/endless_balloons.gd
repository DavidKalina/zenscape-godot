extends Node3D
## Hot air balloons drifting over the endless land (studies/endless_flight.gd).
## Two kinds of sighting, each on its own clock:
##
## - a group of one to three (the first of them low), every GAP s or so;
## - a field, rarer (FIELD_GAP): a line of low balloons staggered to either
##   side of the way the plane comes in, far enough apart to weave through
##   (FIELD_LANE), a few higher up, a few specks 400 to 600 m up (SKY), and a
##   few standing on a flat meadow beside the line, basket on the grass and
##   the burner firing in bursts, that lift off as the plane comes near.
##
## Each balloon has its own size (1.0 to 2.2 times SIZE) and cloth: a pattern
## and three tones, muted and sun-worn (PALETTES) or brighter festival cloth
## worn less (FESTIVAL, the canvas shader's `wear`). They drift with the clouds
## (EndlessLook `wind_direction` at the clouds' WIND_SPEED), rise and sink
## gently, climb over the land, trees and stone ahead of them, and are taken
## away out of sight.
##
## Up close: the plane's wash rocks the balloon about its envelope, swings the
## basket under it and sets the cloth shuddering (shaders/balloon_canvas.gdshader);
## the burner fires now and then, and whenever the balloon climbs, with a glow
## inside the envelope and a roar at the balloon. A pass within REACH of the
## cloth or the basket is a graze for the near-miss chain (NearMiss
## `shot_pass`, as the pirate ship's balls). Nothing here is solid and nothing
## pushes the plane: flying through the cloth only shakes it, and scores nothing.
##
## Cost: the frame's work stays flat with the pool. Every live balloon only
## glides along its drift and rise each frame (a position set); the rest of
## its step (ground samples, height, burner, going, fade, turn) runs every
## frame only while it is HOT (near the eye, or the plane near it, or still
## rocking), and otherwise THINK_TURNS balloons a frame by turns, each over the
## time since its last turn. A sighting is put in one balloon a frame. The
## drawing was measured cheap (docs/design/balloons/handoff-balloons-field.md):
## the near model's own LODs come from the import (generate_lods), and the far
## model takes over past NEAR_END times the balloon's size.
##
## Flags: --balloons=0 (or --no-balloons) none; --balloons=N the most in a
## group (3); --balloon-gap=S the mean wait between groups (110 s);
## --balloon-fields=0 no fields; --balloon-field-gap=S the mean wait between
## fields (300 s); --balloons-now a low group of three ahead of the start, at
## once; --balloon-field-now a field ahead of the start, at once;
## --balloon-scale=X their size over SIZE; --balloon-pool=N the pool (26).
##
## The model: art/blender/balloon/balloon_build.py (keep R, MOUTH_Y and
## FLOOR_Y on its numbers).

const Field = preload("res://scripts/endless/land_field.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const WorldProfile = preload("res://scripts/endless/world/world_profile.gd")
const FlightSound = preload("res://scripts/endless/flight_sound.gd")
const Clouds = preload("res://scripts/endless/endless_clouds.gd")

const MODEL := "res://assets/models/balloon/balloon.glb"

## The balloon drawn this much over the model at its smallest: 17 m across,
## 24.5 m crown to skids. Each balloon is SIZE times its own size.
const SIZE := 1.3
## A balloon's own size over SIZE: from x to y, the big ones rarer (z, the
## draw's power).
const SIZES := Vector3(1.0,2.2,1.8)

# --- The model's numbers (m, before the size) ---
## The envelope's widest radius, about the balloon's origin.
const R := 6.5
## The mouth and the basket's floor under the origin; the skids under that.
const MOUTH_Y := -9.2
const FLOOR_Y := -12.7
const SKIDS := 0.07
## The lower cloth as a second ball, and the gondola as a rod, for the pass.
const LOW_BALL := Vector2(-5.0,3.7)
const BASKET_R := 0.9

# --- The pool ---
## Balloons made at setup (hidden ones cost nothing drawn).
const POOL := 26

# --- Groups ---
## The most balloons in a group.
const GROUP := 3
## The share of groups with one, two, three balloons.
const GROUP_SHARES: Array[float] = [0.45,0.35,0.2]
## The mean wait after a group has gone (s; drawn from half to one and a half).
const GAP := 110.0
## The first group's wait (s).
const FIRST_GAP := Vector2(25.0,70.0)
## How far ahead of the plane a sighting appears (m) and within what angle of
## its heading (rad); a group's spread about that point.
const APPEAR := Vector2(1300.0,1800.0)
const APPEAR_ARC := 0.9
const SPREAD := Vector2(70.0,170.0)
## Gone past this (m), or past GONE_BEHIND and behind the view for GONE_WAIT s.
const GONE := 2800.0
const GONE_BEHIND := 900.0
const GONE_WAIT := 20.0
## The fade in and out (s).
const FADE := 3.0
## --balloons-now: each balloon's place ahead of the plane (m ahead, m right)
## and its floor over the ground.
const NOW: Array[Vector3] = [Vector3(320.0,-22.0,11.0),Vector3(430.0,38.0,17.0),Vector3(580.0,-75.0,48.0)]

# --- Fields ---
## The mean wait between fields (s, from half to one and a half), and the first.
const FIELD_GAP := 300.0
const FIRST_FIELD := Vector2(120.0,240.0)
## The low line: how many, how far apart along the way in (m), how far off the
## line's middle to either side (m), their floor over the ground (m), their
## size (over SIZE).
const FIELD_LANE := Vector2i(6,8)
const LANE_STEP := Vector2(90.0,135.0)
const LANE_OFF := Vector2(24.0,42.0)
const LANE_CLEAR := Vector2(11.0,22.0)
const LANE_SIZE := Vector2(1.0,1.5)
## The middle ones: how many, within this of the field's middle, floor.
const FIELD_MID := Vector2i(4,6)
const MID_REACH := 300.0
const FIELD_MID_CLEAR := Vector2(35.0,120.0)
## The specks high up: how many, within this of the middle.
const FIELD_SKY := Vector2i(2,4)
const SKY_REACH := 450.0
## The ones on the ground: how many, how far apart (m), where their meadow is
## looked for (m off the line, to one side), how many tries.
const FIELD_GROUND := Vector2i(2,4)
const GROUND_STEP := 34.0
const GROUND_OFF := Vector2(70.0,180.0)
const GROUND_TRIES := 60
## The search's reach: from x m, y m wider each try.
const GROUND_SEEK := Vector2(40.0,12.0)
## The most in a field.
const FIELD_MOST := 20
## A share of festival cloth in a field, and in a group.
const FESTIVAL_FIELD := 0.85
const FESTIVAL_GROUP := 0.6
## --balloon-field-now: the line's start this far ahead of the plane (m).
const FIELD_NOW := 420.0

# --- Height ---
## The floor over the highest of the ground, trees, stone and water under and
## ahead of the balloon (m): the low, middle and high bands, and the sky's.
const LOW := Vector2(11.0,19.0)
const MID := Vector2(30.0,75.0)
const HIGH := Vector2(90.0,220.0)
const SKY := Vector2(400.0,600.0)
## The least floor over that ground, whatever the rise and sink.
const LEAST := 9.0
## The gentle rise and sink: its share of the height and its period (s); the
## sky band's is smaller.
const BOB := 0.22
const BOB_SKY := 0.06
const BOB_PERIOD := Vector2(55.0,110.0)
## Climb and sink rates (m/s), and the climb when the land comes up too close.
const CLIMB := 2.4
const SINK := 1.1
const CLIMB_HARD := 6.0
## Ground samples: a slice every this long a balloon (s; low, and over
## HIGH_SAMPLE m of floor); the set places to each side and ahead along the
## drift, and loose ones (each slice).
const SAMPLE_EVERY := 0.25
const SAMPLE_HIGH := 1.5
const SAMPLE_FAR := 1.0
const HIGH_SAMPLE := 45.0
const SAMPLE_SIDE := 9.0
const SAMPLE_AHEAD: Array[float] = [14.0,34.0]
const SAMPLE_LOOSE := 1
const SAMPLE_EASE := 1.5

# --- On the ground and lifting off ---
## Grass to stand on: the most rise under the basket (m, within BASKET_FLAT
## m), the most slope under the envelope's width, the least height over the
## sea (off the beach).
const FLAT_MOST := 0.8
const BASKET_FLAT := 4.0
const SLOPE_MOST := 0.2
const SHORE_CLEAR := 8.0
## Woods: the tree plan's dense and grove share above this is no meadow.
const WOODS_MOST := 0.08
## Grass by the ground's colour (land_field `colour`): green this much over
## red, and darker than this (snow and ice are pale).
const GRASS_GREEN := 1.02
const GRASS_PALE := 0.75
## Lifting off: the plane within this (m) starts the count, which is drawn from
## LIFT_IN (s); lifted anyway after GROUND_MOST s. The climb (m/s) and how
## fast it comes (m/s2); the drift comes in over the first DRIFT_IN m.
const LIFT_NEAR := 700.0
const LIFT_IN := Vector2(2.0,24.0)
const GROUND_MOST := 150.0
const LIFT_RATE := Vector2(1.4,2.4)
const LIFT_EASE := 0.3
const DRIFT_IN := 35.0
## Bursts on the ground (s): how long, how far apart; and while lifting.
const GROUND_BURN := Vector2(0.6,1.6)
const GROUND_BURN_GAP := Vector2(2.5,7.0)
const LIFT_BURN := Vector2(2.5,4.5)
const LIFT_BURN_GAP := Vector2(0.6,2.0)
## The trees near are known within this of the plane (land_trees' blocks): a
## balloon on the ground is asked again then, and lifts at once if a tree or
## stone stands in its envelope's way.
const CHECK_NEAR := 380.0
## On the ground the wash only sways it a little (rad).
const GROUND_ROCK := 0.05

# --- The wash ---
## The plane's wash reaches this far off the cloth (m, times the balloon's own
## size).
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
## The wash is felt within this of the plane (m, times the balloon's own size).
const AWAKE := 220.0
## A pass under this off the cloth or basket scores (m past the wing's tip,
## times the square root of the balloon's own size).
const REACH := 10.0

# --- The step ---
## A balloon is stepped every frame within this of the eye (m); past it,
## THINK_TURNS of them a frame by turns.
const HOT := 320.0
const THINK_TURNS := 3

# --- The burner ---
## It fires this long (s), this far apart (s).
const BURN_TIME := Vector2(1.4,3.2)
const BURN_GAP := Vector2(7.0,19.0)
## Heard within this (m); the roar's size and level.
const HEAR := 340.0
const ROAR_UNIT := 30.0
const ROAR_DB := -3.0

# --- Drawing ---
## The full model within this (m, times the balloon's scale), the far one past it.
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
## Festival cloth: saturated dyes, worn less (FESTIVAL_WEAR) but still worn.
const FESTIVAL: Array = [
	[Color("cf3b2c"),Color("eab53a"),Color("2b4a7a")],
	[Color("23909a"),Color("e87a30"),Color("efe4c8")],
	[Color("3363b4"),Color("efcd42"),Color("cc4232")],
	[Color("b23d78"),Color("5a49a0"),Color("e9bc4c")],
	[Color("44994d"),Color("ecd953"),Color("f3ecd9")],
	[Color("e2722f"),Color("2e2a27"),Color("efe0c2")],
	[Color("c8432f"),Color("f2e9d3"),Color("2f8250")],
	[Color("e9b632"),Color("c43a2f"),Color("2f5c9c")],
]
const FESTIVAL_WEAR := Vector2(0.2,0.45)
const PATTERNS := 5

enum { AIR, GROUND, LIFT }
enum { SOLO, FIELD }

class Balloon:
	var root: Node3D
	var envelope: MeshInstance3D
	var gondola: MeshInstance3D
	var flame: MeshInstance3D
	var far: MeshInstance3D
	var roar: AudioStreamPlayer3D
	var live := false
	var leaving := false
	## A group's (SOLO) or a field's (FIELD).
	var kind := 0
	## AIR, GROUND (standing on its basket) or LIFT (lifting off).
	var state := 0
	## Its own size over SIZE, and the root's whole scale.
	var k := 1.0
	var scale := 1.3
	## Where its origin is (the envelope's middle).
	var at := Vector3.ZERO
	var rise := 0.0
	## How much of the drift it takes (0 on the ground).
	var drift_k := 1.0
	## Its floor over the ground: the middle of its rise and sink.
	var clear := 12.0
	var bob := 0.22
	var bob_phase := 0.0
	var bob_rate := 0.1
	## The highest ground under and ahead, as last sampled.
	var ground := 0.0
	var sample_in := 0.0
	var sample_i := 0
	var fade := 0.0
	var turn := 0.0
	var behind := 0.0
	## The step's clock at its last step; stepped every frame while `hot`.
	var last := 0.0
	var hot := false
	## On the ground: the meadow's height, the count to lift off, the time
	## stood, whether the near trees were asked; lifting: its climb.
	var ground_y := 0.0
	var lift_in := 0.0
	var ground_t := 0.0
	var checked := false
	var lift_rate := 2.0
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
## The numbers: groups and fields begun, balloons taken away, passes scored,
## washes felt (one a pass), lift-offs, ground spots refused when the near
## trees were asked, this frame's ms, its running mean and the most.
var groups := 0
var fields := 0
var gone := 0
var passes := 0
var washes := 0
var lifts := 0
var blocked := 0
var ms := 0.0
var ms_avg := 0.0
var ms_most := 0.0
## Meadow spots refused, by why (peak, sea, river, slope, solid, bare, woods).
var refused := {}

var _rng := RandomNumberGenerator.new()
var _most := GROUP
var _gap := GAP
var _field_gap := FIELD_GAP
var _fields_on := true
var _size := SIZE
var _now := false
var _field_now := false
var _pool := POOL
var _wait := 0.0
var _try_in := 0.0
var _field_wait := 0.0
var _field_try := 0.0
var _alive := 0
var _solo := 0
var _field := 0
var _wind := Vector2.RIGHT
var _span := 2.8
var _clock := 0.0
var _cursor := 0
var _cold_sampled := false
var _palette := 0
var _festival := 0
## Sightings waiting to be put, one a frame: {at, clear, k, kind, fade,
## festival, ground} or {site, way, n, fade} (a meadow to look for).
var _queue: Array[Dictionary] = []
var _tree_plan: RefCounted

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
		elif a.begins_with("--balloon-field-gap="): _field_gap = maxf(float(a.get_slice("=",1)),1.0)
		elif a == "--balloon-fields=0" or a == "--no-balloon-fields": _fields_on = false
		elif a.begins_with("--balloon-scale="): _size = SIZE*clampf(float(a.get_slice("=",1)),0.3,4.0)
		elif a == "--balloons-now" or a == "--balloons-now=1": _now = true
		elif a == "--balloon-field-now" or a == "--balloon-field-now=1": _field_now = true
		elif a.begins_with("--balloon-pool="): _pool = clampi(int(a.get_slice("=",1)),GROUP,64)
	_span = WorldScale.span
	_wait = _rng.randf_range(FIRST_GAP.x,FIRST_GAP.y)
	_field_wait = _rng.randf_range(FIRST_FIELD.x,FIRST_FIELD.y)*(_field_gap/FIELD_GAP)
	_palette = _rng.randi()%997
	_festival = _rng.randi()%997
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
	for i in _pool:
		var b := Balloon.new()
		b.root = Node3D.new()
		b.root.name = "Balloon%d" % i
		b.root.visible = false
		add_child(b.root)
		b.envelope = _part(b.root,"Envelope",envelope,[canvas])
		b.gondola = _part(b.root,"Gondola",gondola,[gear])
		b.gondola.position.y = MOUTH_Y
		b.flame = _part(b.gondola,"Flame",flame,[fire])
		b.flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.flame.visible = false
		b.far = _part(b.root,"Far",far,[canvas,gear])
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

func _part(under: Node3D, part: String, mesh: Mesh, mats: Array) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = part
	m.mesh = mesh
	for i in mats.size(): m.set_surface_override_material(i,mats[i])
	under.add_child(m)
	return m

## The near and far models' hand-over for `b`'s scale.
func _ranges(b: Balloon) -> void:
	var end := NEAR_END*b.scale
	for g: GeometryInstance3D in [b.envelope,b.gondola,b.flame]:
		g.visibility_range_end = end
		g.visibility_range_end_margin = NEAR_MARGIN
	b.far.visibility_range_begin = end
	b.far.visibility_range_begin_margin = NEAR_MARGIN

## A bench (scratch drivers): `n` of the pool fanned out ahead of `eye` along
## `ahead`, 90 to 90+`span` m off, mixed heights, all live.
func bench(game: Node, eye: Vector3, ahead: Vector3, n: int, span := 1210.0) -> void:
	for b in balloons:
		if b.live: _take(b)
	ahead = Vector3(ahead.x,0.0,ahead.z).normalized()
	var right := Vector3(-ahead.z,0.0,ahead.x)
	for i in mini(n,balloons.size()):
		var f := (float(i)+0.5)/float(n)
		var d := 90.0+fmod(float(i)*397.0,span)
		var side := (f-0.5)*1.1*d
		_put(balloons[i],game,{"at":eye+ahead*d+right*side,"clear":[12.0,40.0,110.0][i%3],"k":1.0,"kind":SOLO,"fade":1.0})
		_solo += 1

## How many are in the world.
func alive() -> int:
	return _alive

## How many are in the world on the ground or lifting off.
func grounded() -> int:
	var n := 0
	for b in balloons:
		if b.live and b.state != AIR: n += 1
	return n

## A frame: `game` is the study (its plane, camera, look, near, plane_ground).
func step(delta: float, game: Node) -> void:
	if not enabled: return
	var t0 := Time.get_ticks_usec()
	_clock += delta
	var plane: RefCounted = game.plane
	var eye: Vector3 = game.camera.global_position
	if (_now or _field_now) and bool(game.hand_landing.flying()):
		if _now: _place_now(game)
		if _field_now: _field_ahead(game)
		_now = false
		_field_now = false
	if _solo == 0 and _queue.is_empty():
		_wait -= delta
		if _wait <= 0.0:
			_try_in -= delta
			if _try_in <= 0.0:
				_try_in = 2.0
				_appear(game)
				if _solo > 0: _wait = _gap*_rng.randf_range(0.5,1.5)
	if _fields_on and _field == 0 and _queue.is_empty():
		_field_wait -= delta
		if _field_wait <= 0.0:
			_field_try -= delta
			if _field_try <= 0.0:
				_field_try = 2.0
				_field_appear(game)
				if _field > 0: _field_wait = _field_gap*_rng.randf_range(0.5,1.5)
	_cold_sampled = false
	if not _queue.is_empty(): _put_next(game)
	if _alive > 0:
		if game.look != null: _wind = game.look.wind_direction
		var drift := Vector3(_wind.x,0.0,_wind.y)*Clouds.WIND_SPEED
		var view: Vector3 = -game.camera.global_basis.z
		var to_plane: Vector3 = plane.position
		# Every one glides; the hot ones are stepped now, the rest by turns.
		for b in balloons:
			if not b.live: continue
			if b.state != GROUND:
				b.at += drift*(b.drift_k*delta)
				b.at.y += b.rise*delta
				b.root.position = b.at
			var a := AWAKE*b.k
			b.hot = (b.at-eye).length_squared() < HOT*HOT or (to_plane-b.at).length_squared() < a*a or not b.still
			if b.hot: _think(b,game,plane,eye,view)
		var turns := THINK_TURNS
		for i in balloons.size():
			if turns <= 0: break
			_cursor = (_cursor+1)%balloons.size()
			var b := balloons[_cursor]
			if b.live and not b.hot:
				_think(b,game,plane,eye,view)
				turns -= 1
	ms = float(Time.get_ticks_usec()-t0)/1000.0
	ms_avg = lerpf(ms_avg,ms,0.02)
	ms_most = maxf(ms_most,ms)

# --- Coming and going -------------------------------------------------------------

## The highest of the land, trees, stone and the sea at `p` (a river's water
## stands a little over its bed: LEAST covers it).
func _ground_at(game: Node, p: Vector3) -> float:
	var g: Variant = game.plane_ground(p,2.0)
	var h: float = float(g) if g is float else float(game.field.height(p.x,p.z))
	return maxf(h,Field.SEA_Y)

## A slice of `b`'s ground samples: one of the five set places (under it, to
## each side, two ahead along the drift) and SAMPLE_LOOSE at random under the
## basket's way ahead, as a tree's spire slips between the set ones. What they
## find is held a while (eased down SAMPLE_EASE m/s over `dt`), so the highest
## of the last few seconds stands.
func _sample(b: Balloon, game: Node, dt: float, loose := SAMPLE_LOOSE) -> void:
	var p := b.at
	var along := Vector3(_wind.x,0.0,_wind.y)
	var side := Vector3(-_wind.y,0.0,_wind.x)*(SAMPLE_SIDE*b.scale)
	var g := -INF
	match b.sample_i:
		0: g = _ground_at(game,p)
		1: g = _ground_at(game,p+side)
		2: g = _ground_at(game,p-side)
		3: g = _ground_at(game,p+along*SAMPLE_AHEAD[0])
		_: g = _ground_at(game,p+along*SAMPLE_AHEAD[1])
	b.sample_i = (b.sample_i+1)%5
	for i in loose:
		g = maxf(g,_ground_at(game,p+along*_rng.randf_range(-4.0,SAMPLE_AHEAD[1])+side*_rng.randf_range(-0.8,0.8)))
	b.ground = maxf(g,b.ground-SAMPLE_EASE*dt)

## A balloon's own size over SIZE, the big ones rarer.
func _size_k(lo := SIZES.x, hi := SIZES.y) -> float:
	return lerpf(lo,hi,pow(_rng.randf(),SIZES.z))

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
			# The second is often low too, the third higher up, now and then
			# far up in the sky.
			if i == 1: band = LOW if _rng.randf() < 0.5 else MID
			else:
				var r := _rng.randf()
				band = MID if r < 0.4 else (HIGH if r < 0.7 else SKY)
		var k := _size_k(1.3,SIZES.y) if band == SKY else _size_k()
		_queue.append({"at":at,"clear":_rng.randf_range(band.x,band.y),"k":k,"kind":SOLO,"fade":0.0,"festival":FESTIVAL_GROUP})
	groups += 1
	_solo += count

## Whether a balloon may stand over `p`: not on the Peak's massif (where it
## moved the land: LandField `_m_on` after a sample; its bounding circle
## takes in the land round the start too).
func _free(game: Node, p: Vector3) -> bool:
	var field: RefCounted = game.field
	if field.peak() == null: return true
	field.sample(p.x,p.z)
	return not bool(field.get("_m_on"))

## --balloons-now: the low group ahead of the plane, already there.
func _place_now(game: Node) -> void:
	var plane: RefCounted = game.plane
	var ahead := Vector3(-sin(float(plane.heading)),0.0,-cos(float(plane.heading)))
	var right := Vector3(-ahead.z,0.0,ahead.x)
	var n := mini(NOW.size(),_most)
	for i in n:
		var p := NOW[i]
		_queue.append({"at":plane.position+ahead*p.x+right*p.y,"clear":p.z,"k":1.0,"kind":SOLO,"fade":1.0,"festival":FESTIVAL_GROUP})
	groups += 1
	_solo += n

## A field somewhere ahead of the plane, its line along the way in.
func _field_appear(game: Node) -> void:
	var plane: RefCounted = game.plane
	var turn := float(plane.heading)+_rng.randf_range(-APPEAR_ARC*0.6,APPEAR_ARC*0.6)
	var way := Vector3(-sin(turn),0.0,-cos(turn))
	var start: Vector3 = plane.position+way*_rng.randf_range(APPEAR.x,APPEAR.y-300.0)
	if not _free(game,start) or not _free(game,start+way*500.0): return
	_lay_field(start,way,0.0)

## --balloon-field-now: a field ahead of the plane, the line's start
## FIELD_NOW m off, already there; turned off the heading as little as will
## keep it off the Peak's massif.
func _field_ahead(game: Node) -> void:
	var plane: RefCounted = game.plane
	var at: Vector3 = plane.position
	for turn: float in [0.0,0.4,-0.4,0.8,-0.8,1.2,-1.2,1.7,-1.7,2.3,-2.3,PI]:
		var h := float(plane.heading)+turn
		var way := Vector3(-sin(h),0.0,-cos(h))
		if _free(game,at+way*FIELD_NOW) and _free(game,at+way*(FIELD_NOW+400.0)) and _free(game,at+way*(FIELD_NOW+800.0)):
			_lay_field(at+way*FIELD_NOW,way,1.0)
			return
	var way := Vector3(-sin(float(plane.heading)),0.0,-cos(float(plane.heading)))
	_lay_field(at+way*FIELD_NOW,way,1.0)

## A field's balloons queued: the low line from `start` along `way`, the
## middle ones and the specks about its middle, a meadow looked for beside
## the line's first stretch for the ones on the ground.
func _lay_field(start: Vector3, way: Vector3, fade: float) -> void:
	var side := Vector3(-way.z,0.0,way.x)
	var n := 0
	var lane := _rng.randi_range(FIELD_LANE.x,FIELD_LANE.y)
	var along := 0.0
	var flip := 1.0 if _rng.randf() < 0.5 else -1.0
	for i in lane:
		# Staggered to either side, now and then twice on one side.
		if i == 0 or _rng.randf() > 0.2: flip = -flip
		var at := start+way*along+side*(flip*_rng.randf_range(LANE_OFF.x,LANE_OFF.y))
		_queue.append({"at":at,"clear":_rng.randf_range(LANE_CLEAR.x,LANE_CLEAR.y),"k":_size_k(LANE_SIZE.x,LANE_SIZE.y),"kind":FIELD,"fade":fade,"festival":FESTIVAL_FIELD})
		n += 1
		if i < lane-1: along += _rng.randf_range(LANE_STEP.x,LANE_STEP.y)
	var mid := start+way*(along*0.5)
	var ground := _rng.randi_range(FIELD_GROUND.x,FIELD_GROUND.y)
	var skies := _rng.randi_range(FIELD_SKY.x,FIELD_SKY.y)
	var mids := mini(_rng.randi_range(FIELD_MID.x,FIELD_MID.y),FIELD_MOST-n-ground-skies)
	for i in mids:
		var a := _rng.randf()*TAU
		var at := mid+Vector3(cos(a),0.0,sin(a))*(MID_REACH*sqrt(_rng.randf_range(0.15,1.0)))
		_queue.append({"at":at,"clear":_rng.randf_range(FIELD_MID_CLEAR.x,FIELD_MID_CLEAR.y),"k":_size_k(),"kind":FIELD,"fade":fade,"festival":FESTIVAL_FIELD})
		n += 1
	for i in skies:
		var a := _rng.randf()*TAU
		var at := mid+Vector3(cos(a),0.0,sin(a))*(SKY_REACH*sqrt(_rng.randf()))
		_queue.append({"at":at,"clear":_rng.randf_range(SKY.x,SKY.y),"k":_size_k(1.3,SIZES.y),"kind":FIELD,"fade":fade,"festival":FESTIVAL_FIELD})
		n += 1
	# The meadow: off to one side of the line's first stretch.
	var off := side*((1.0 if _rng.randf() < 0.5 else -1.0)*_rng.randf_range(GROUND_OFF.x,GROUND_OFF.y))
	_queue.append({"site":start+way*_rng.randf_range(0.0,along*0.4)+off,"way":way,"n":ground,"fade":fade})
	fields += 1
	_field += n

## Puts the next of the queue.
func _put_next(game: Node) -> void:
	var q: Dictionary = _queue.pop_front()
	if q.has("site"):
		_meadow_site(game,q)
		return
	var b := _free_balloon()
	if b == null:
		_lost(int(q.kind))
		return
	_put(b,game,q)

## A balloon of the pool not in use, or null.
func _free_balloon() -> Balloon:
	for b in balloons:
		if not b.live: return b
	return null

func _lost(kind: int) -> void:
	if kind == FIELD: _field = maxi(_field-1,0)
	else: _solo = maxi(_solo-1,0)

## The ones on the ground: open grass near `q.site`, a spot tried a frame
## (GROUND_TRIES of them, each further out), each at least GROUND_STEP from
## the others found; `q.n` of them, or as many as were found.
func _meadow_site(game: Node, q: Dictionary) -> void:
	var site: Vector3 = q.site
	var count := int(q.n)
	var t := int(q.get("try",0))
	var spots: Array = q.get("spots",[])
	var a := _rng.randf()*TAU
	var p := site+Vector3(cos(a),0.0,sin(a))*(GROUND_SEEK.x+GROUND_SEEK.y*float(t))*sqrt(_rng.randf())
	var apart := true
	for o: Vector4 in spots:
		if Vector2(o.x-p.x,o.z-p.z).length() < GROUND_STEP: apart = false
	if apart:
		var k := _size_k(1.0,1.4)
		var y := _meadow(game,p,R*_size*k+3.0)
		if not is_nan(y): spots.append(Vector4(p.x,y,p.z,k))
	t += 1
	if spots.size() < count and t < GROUND_TRIES:
		q["try"] = t
		q["spots"] = spots
		_queue.push_front(q)
		return
	for o: Vector4 in spots:
		var b := _free_balloon()
		if b == null: break
		_put(b,game,{"at":Vector3(o.x,o.y,o.z),"clear":_rng.randf_range(LANE_CLEAR.x,FIELD_MID_CLEAR.x+20.0),"k":o.w,"kind":FIELD,"fade":float(q.fade),"festival":FESTIVAL_FIELD,"ground":true})
		_field += 1

## The meadow's height at `p` if a balloon of envelope radius `r` may stand
## there: open grass (green ground, the tree plan's woods thin), flat under the basket and
## gently sloped under `r`, off the sea, rivers and the Peak's ice and stone, and with no tree, stone or
## arch known there; else NAN.
func _meadow(game: Node, p: Vector3, r: float) -> float:
	var field: RefCounted = game.field
	var s: Vector2 = field.sample(p.x,p.z)
	# The Peak's massif (its glaciers and scree read as grass to the colour).
	if field.peak() != null and bool(field.get("_m_on")): return _refuse(&"peak")
	if s.x < Field.SEA_Y+SHORE_CLEAR: return _refuse(&"sea")
	if not is_nan(field.river_y(p.x,p.z)): return _refuse(&"river")
	for i in 4:
		var a := TAU*float(i)/4.0
		var q := p+Vector3(cos(a),0.0,sin(a))*BASKET_FLAT
		if absf(field.height(q.x,q.z)-s.x) > FLAT_MOST: return _refuse(&"slope")
	for i in 6:
		var a := TAU*float(i)/6.0
		var q := p+Vector3(cos(a),0.0,sin(a))*r
		var h: float = field.height(q.x,q.z)
		if absf(h-s.x) > SLOPE_MOST*r: return _refuse(&"slope")
		if not is_nan(field.river_y(q.x,q.z)): return _refuse(&"river")
		if not _clear_of_solid(game,q,h): return _refuse(&"solid")
	if not _clear_of_solid(game,p,s.x): return _refuse(&"solid")
	var e := 4.0
	var up := Vector3(field.height(p.x-e,p.z)-field.height(p.x+e,p.z),2.0*e,field.height(p.x,p.z-e)-field.height(p.x,p.z+e)).normalized().y
	if not _grassy(field.colour(p.x,p.z,s.x,up,clampf(s.y,0.0,1.0))): return _refuse(&"bare")
	if _woods(game,p,up) > WOODS_MOST: return _refuse(&"woods")
	return field.height(p.x,p.z)

## Whether the ground's colour reads as grass: green over red and blue, not
## the pale of snow and ice.
static func _grassy(c: Color) -> bool:
	return c.g > c.r*GRASS_GREEN and c.g > c.b*1.15 and c.v < GRASS_PALE

func _refuse(why: StringName) -> float:
	refused[why] = int(refused.get(why,0))+1
	return NAN

## Whether nothing the plane can hit (a tree, stone, an arch) stands at `q`
## over ground `h`, as far as the near world knows.
func _clear_of_solid(game: Node, q: Vector3, h: float) -> bool:
	var g: Variant = game.plane_ground(q,0.0)
	return g is float and float(g) < h+0.8

## The tree plan's dense and grove share at `p` (land_trees' own plan, so the
## woods are known far off, before their blocks are built).
func _woods(game: Node, p: Vector3, up: float) -> float:
	var trees: Node = game.trees
	if trees == null or not trees.has_method("_plan_for"): return 0.0
	if _tree_plan == null: _tree_plan = trees._plan_for()
	var field: RefCounted = game.field
	var m: Vector3 = _tree_plan.mask(field,p.x,p.z,field.shape(p.x,p.z),up)
	return m.x+m.y

## `b` live from `q`: {at, clear, k, kind, fade, festival, ground}.
func _put(b: Balloon, game: Node, q: Dictionary) -> void:
	if game.look != null: _wind = game.look.wind_direction
	b.live = true
	b.leaving = false
	b.kind = int(q.kind)
	b.k = float(q.k)
	b.scale = _size*b.k
	b.clear = float(q.clear)
	b.bob = BOB_SKY if b.clear >= SKY.x else BOB
	b.bob_phase = _rng.randf()*TAU
	b.bob_rate = TAU/_rng.randf_range(BOB_PERIOD.x,BOB_PERIOD.y)
	b.at = q.at
	b.rise = 0.0
	b.fade = float(q.fade)
	b.turn = _rng.randf()*TAU
	b.behind = 0.0
	b.last = _clock
	b.checked = false
	if bool(q.get("ground",false)):
		b.state = GROUND
		b.ground_y = b.at.y
		b.ground = b.at.y
		b.drift_k = 0.0
		b.lift_in = _rng.randf_range(LIFT_IN.x,LIFT_IN.y)
		b.ground_t = 0.0
		b.at.y = b.ground_y-(FLOOR_Y-SKIDS)*b.scale
		b.burn_in = _rng.randf_range(0.5,GROUND_BURN_GAP.y)
	else:
		b.state = AIR
		b.drift_k = 1.0
		b.ground = -INF
		for i in 5: _sample(b,game,0.0,0)
		b.at.y = b.ground+_floor(b)-FLOOR_Y*b.scale
		b.burn_in = _rng.randf_range(2.0,BURN_GAP.y)
	b.sample_in = _rng.randf()*SAMPLE_EVERY
	b.rock = Vector2.ZERO
	b.rock_v = Vector2.ZERO
	b.swing = Vector2.ZERO
	b.swing_v = Vector2.ZERO
	b.shudder = 0.0
	b.dent = 0.0
	b.still = true
	b.burn = 0.0
	b.burn_left = 0.0
	b.least = INF
	b.through = false
	b.armed = true
	# Its cloth: muted or festival, no two in a row alike.
	var tones: Array
	var wear := 1.0
	if _rng.randf() < float(q.get("festival",0.0)):
		_festival += _rng.randi_range(1,FESTIVAL.size()-1)
		tones = FESTIVAL[_festival%FESTIVAL.size()]
		wear = _rng.randf_range(FESTIVAL_WEAR.x,FESTIVAL_WEAR.y)
	else:
		_palette += _rng.randi_range(1,PALETTES.size()-1)
		tones = PALETTES[_palette%PALETTES.size()]
	var pattern := float(_rng.randi()%PATTERNS)
	for g: GeometryInstance3D in [b.envelope,b.far]:
		g.set_instance_shader_parameter(&"tone_a",tones[0])
		g.set_instance_shader_parameter(&"tone_b",tones[1])
		g.set_instance_shader_parameter(&"tone_c",tones[2])
		g.set_instance_shader_parameter(&"pattern",pattern)
		g.set_instance_shader_parameter(&"wear",wear)
	b.envelope.set_instance_shader_parameter(&"shudder",0.0)
	b.envelope.set_instance_shader_parameter(&"wash",Vector4.ZERO)
	_ranges(b)
	_set_burn(b,0.0)
	_set_fade(b,b.fade)
	b.root.position = b.at
	b.root.basis = Basis(Vector3.UP,b.turn).scaled(Vector3.ONE*b.scale)
	b.gondola.basis = Basis.IDENTITY
	b.root.visible = true
	_alive += 1

func _take(b: Balloon) -> void:
	if not b.live: return
	b.live = false
	b.root.visible = false
	if b.roar.playing: b.roar.stop()
	_alive -= 1
	_lost(b.kind)
	gone += 1

## The floor over the ground now: the band's height with its rise and sink.
func _floor(b: Balloon) -> float:
	return maxf(b.clear*(1.0+b.bob*sin(b.bob_phase)),LEAST)

func _set_fade(b: Balloon, f: float) -> void:
	for g: GeometryInstance3D in [b.envelope,b.gondola,b.far]:
		g.set_instance_shader_parameter(&"fade",f)

func _set_burn(b: Balloon, v: float) -> void:
	for g: GeometryInstance3D in [b.envelope,b.gondola,b.flame,b.far]:
		g.set_instance_shader_parameter(&"burn",v)
	b.flame.visible = v > 0.001

# --- A balloon's step -------------------------------------------------------------

## `b`'s step over the time since its last: every frame while hot, else by turns.
func _think(b: Balloon, game: Node, plane: RefCounted, eye: Vector3, view: Vector3) -> void:
	var dt := _clock-b.last
	b.last = _clock
	if dt <= 0.0: return
	dt = minf(dt,0.5)
	b.bob_phase += b.bob_rate*dt
	var floor_y := b.at.y+FLOOR_Y*b.scale
	var to: Vector3 = plane.position-b.at
	var d2 := to.length_squared()
	match b.state:
		GROUND:
			b.ground_t += dt
			# Asked again once the near trees are known: a tree or stone in its
			# way sends it up at once.
			if not b.checked and d2 < CHECK_NEAR*CHECK_NEAR:
				b.checked = true
				if not _stands_clear(game,b):
					blocked += 1
					_lift(b,CLIMB_HARD)
			if b.state == GROUND:
				if d2 < LIFT_NEAR*LIFT_NEAR: b.lift_in -= dt
				if b.lift_in <= 0.0 or b.ground_t > GROUND_MOST: _lift(b,_rng.randf_range(LIFT_RATE.x,LIFT_RATE.y))
		LIFT:
			b.rise = move_toward(b.rise,b.lift_rate,dt*LIFT_EASE)
			_sample_due(b,game,dt)
			b.drift_k = clampf((floor_y-b.ground_y)/DRIFT_IN,0.0,1.0)
			if floor_y >= maxf(b.ground,b.ground_y)+b.clear*0.85:
				b.state = AIR
				b.drift_k = 1.0
		_:
			_sample_due(b,game,dt)
			var want := b.ground+_floor(b)
			var rate := clampf((want-floor_y)*0.35,-SINK,CLIMB)
			if floor_y < b.ground+LEAST*0.6: rate = CLIMB_HARD
			b.rise = lerpf(b.rise,rate,minf(dt*1.5,1.0))

	# Going: far off, or behind the view a while; faded out, then taken.
	var off := b.at-eye
	var far2 := off.length_squared()
	if not b.leaving:
		if far2 > GONE_BEHIND*GONE_BEHIND and off.dot(view) < 0.0: b.behind += dt
		else: b.behind = 0.0
		if far2 > GONE*GONE or b.behind > GONE_WAIT: b.leaving = true
	if b.leaving:
		b.fade -= dt/FADE
		if b.fade <= 0.0 or off.dot(view) < 0.0:
			_take(b)
			return
		_set_fade(b,b.fade)
	elif b.fade < 1.0:
		b.fade = minf(b.fade+dt/FADE,1.0)
		_set_fade(b,b.fade)

	_burner(b,dt,far2)

	# The slow turn; the rest only near the plane or while it still moves.
	if b.state == AIR: b.turn += TURN*dt
	var awake := d2 < AWAKE*AWAKE*b.k*b.k
	if awake: _wash(b,dt,game,plane,to,sqrt(d2))
	if not awake and b.still:
		var near := NEAR_END*b.scale*1.15
		if far2 < near*near: b.root.basis = Basis(Vector3.UP,b.turn).scaled(Vector3.ONE*b.scale)
		return
	_swing(b,dt)

## A slice of `b`'s ground samples when due: near the eye every SAMPLE_EVERY
## (SAMPLE_HIGH high up); out of the HOT range every SAMPLE_FAR, with no
## loose ones and one balloon a frame at most (the far ground costs more to
## ask), the rest waiting their turn.
func _sample_due(b: Balloon, game: Node, dt: float) -> void:
	b.sample_in -= dt
	if b.sample_in > 0.0: return
	if b.hot:
		b.sample_in = SAMPLE_EVERY if b.clear < HIGH_SAMPLE else SAMPLE_HIGH
		_sample(b,game,maxf(dt,b.sample_in))
	elif not _cold_sampled:
		_cold_sampled = true
		b.sample_in = SAMPLE_FAR
		_sample(b,game,SAMPLE_FAR,0)

## Lifting off at `rate` m/s.
func _lift(b: Balloon, rate: float) -> void:
	b.state = LIFT
	b.lift_rate = rate
	b.burn_left = 0.0
	b.burn_in = 0.0
	b.sample_in = 0.0
	lifts += 1

## Whether `b` on the ground stands clear of every tree, stone and arch the
## near world knows, round its envelope.
func _stands_clear(game: Node, b: Balloon) -> bool:
	var r := R*b.scale+2.0
	var p := Vector3(b.at.x,b.ground_y,b.at.z)
	for i in 6:
		var a := TAU*float(i)/6.0
		var q := p+Vector3(cos(a),0.0,sin(a))*r
		if not _clear_of_solid(game,q,float(game.field.height(q.x,q.z))): return false
	return _clear_of_solid(game,p,b.ground_y)

## The burner: on its own time, in bursts on the ground, near steady while
## lifting off, and whenever the balloon climbs.
func _burner(b: Balloon, dt: float, far2: float) -> void:
	if b.burn_left > 0.0:
		b.burn_left -= dt
	else:
		b.burn_in -= dt
		if b.burn_in <= 0.0 or (b.state == AIR and b.rise > CLIMB*0.6 and b.burn <= 0.01):
			var time := BURN_TIME
			var gap := BURN_GAP
			if b.state == GROUND:
				time = GROUND_BURN
				gap = GROUND_BURN_GAP
			elif b.state == LIFT:
				time = LIFT_BURN
				gap = LIFT_BURN_GAP
			b.burn_left = _rng.randf_range(time.x,time.y)
			b.burn_in = _rng.randf_range(gap.x,gap.y)
			if far2 < HEAR*HEAR:
				b.roar.pitch_scale = _rng.randf_range(0.92,1.08)
				b.roar.play(_rng.randf()*1.5)
	var burn_to := 1.0 if b.burn_left > 0.0 else 0.0
	if b.burn != burn_to:
		b.burn = move_toward(b.burn,burn_to,dt*(5.0 if burn_to > 0.0 else 2.2))
		_set_burn(b,b.burn)
		if b.roar.playing:
			b.roar.volume_db = ROAR_DB+linear_to_db(maxf(b.burn,0.02))
			if b.burn <= 0.0: b.roar.stop()

## The plane near `b`: its wash on the balloon, and the pass for the chain.
func _wash(b: Balloon, delta: float, game: Node, plane: RefCounted, to: Vector3, d: float) -> void:
	var s := b.scale
	var r := R*s
	# The clearance off the cloth (two balls) and the gondola (a rod).
	var cloth := d-r
	var low := Vector3(to.x,to.y-LOW_BALL.x*s,to.z).length()-LOW_BALL.y*s
	var rod_y := clampf(to.y,FLOOR_Y*s,MOUTH_Y*s)
	var rod := Vector3(to.x,to.y-rod_y,to.z).length()-BASKET_R*s
	var clear := minf(minf(cloth,low),rod)
	var wash_r := WASH_REACH*b.k
	if clear < wash_r:
		var speed := float(plane.speed)
		var k := 1.0-clampf(clear/wash_r,0.0,1.0)
		# A bigger balloon is rocked less by the same wash.
		k = k*k*clampf(speed/float(plane.cruise()),0.5,1.8)/sqrt(b.k)
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
	var reach := REACH*sqrt(b.k)
	var past := clear-_span*0.5
	if past >= reach+4.0:
		b.armed = true
	elif b.armed:
		if cloth < -1.0: b.through = true
		if past < b.least:
			b.least = past
			b.least_at = plane.position
	if b.least < INF and past > b.least+5.0:
		if b.least < reach and not b.through and game.near != null:
			game.near.shot_pass(maxf(b.least,0.0),reach,b.least_at)
			passes += 1
		b.least = INF
		b.through = false
		b.armed = false

## The rock about the envelope and the basket's swing, eased back to rest; on
## the ground only a little sway and no swing.
func _swing(b: Balloon, delta: float) -> void:
	var most := GROUND_ROCK if b.state == GROUND else ROCK_MOST
	b.rock_v += (-b.rock*(ROCK_RATE*ROCK_RATE)-b.rock_v*(2.0*ROCK_DAMP*ROCK_RATE))*delta
	b.rock += b.rock_v*delta
	if b.rock.length_squared() > most*most:
		b.rock = b.rock.normalized()*most
		b.rock_v *= 0.5
	if b.state == GROUND:
		b.swing = Vector2.ZERO
		b.swing_v = Vector2.ZERO
	else:
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
	b.root.basis = basis.scaled(Vector3.ONE*b.scale)
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
