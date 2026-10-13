extends "res://scripts/enemies/enemy.gd"
## The headless body (docs/design/roguelike/headless-body-round1.md): the
## inhaler head's (scripts/enemies/inhaler_head.gd) lost stone body, a
## hulking Olmec figure of masonry with an empty neck stump, walking the
## isles to find its head. Round 3 (headless-body-round3-anim.md) gave it
## its model and authored clips (scripts/enemies/headless_body_look.gd,
## art/blender/headless_body/headless_body_build.py), driven from these
## states; its hands are put on the real wall and lip on top of them.
##
## Sized off its head (`head_size` of the walker's heights, the head's own
## `size` knob): legs, torso, arms, breadth in head heights, so a bigger head
## has a bigger body. The walker's numbers come from enemy_field.gd
## `numbers()` (AGENTS.md, Sizes).
##
## In states (`state`):
##   "listen"  it stands, turns its stump one way and the other, a hand
##             cupped by where its ear was: it hears the head (within
##             `hear` m) and turns to its bearing, off by up to `noise` rad,
##             less the nearer it is. Out of hearing it picks any way.
##   "roam"    it walks the way it heard, heavily, `walk` m/s; every
##             `listen_every` s (give or take) it stops to listen again.
##   "home"    the head is within `sense` m with nothing between its neck
##             and the head: it has it. It lifts its arms and strides
##             straight for it at `home` m/s (a tell: the body warms).
##   "climb"   a wall too tall to step stands in its way and the head is
##             above it (it hears it up there): it faces the wall and goes
##             up it hand over hand at `climb` m/s, its rays on the real
##             wall (the face held `standoff` off, the lip found by a ray
##             down past the face from over its reach). A wall taller than
##             `climb_max`, it does not take.
##   "mantle"  its hands over the lip: it hauls itself up and rolls over
##             onto the top (`mantle` s).
##   "windup"  at an edge: a ledge across the gap at about its height
##             (`jump_gap` Hh across at most, `jump_rise` Hh up, `jump_sink`
##             Hh down) it jumps to ("jump"); failing that, a lower floor
##             out along its way within `leap_max` m across and `drop_max` m
##             down it drops to ("drop"). It crouches, arms back, `windup` s.
##   "leap"    the throw: a ballistic arc (`leap_up` m over the takeoff, a
##             jump's higher by `jump_arc` of its length) to that floor, its
##             feet ray-cast along the arc; a wall on the way stops it dead
##             and it drops.
##   "land"    a heavy landing, squashed for `land` s; dust, a quake and a
##             shockwave (`_shock`) running out along the ground: a walker
##             on the ground as the front passes him is thrown back and up,
##             less the farther out; one in the air over it is clear. The
##             mantle's end sends a smaller one.
## Set down by `cling` it starts on a cliff face, climbing, out of sight
## under the lip, and hauls itself over.
##   "fall"    walked off something unseen: it falls (below the study's
##             `lost`, it is gone).
##   "reach"   the head is in arm's reach: it stops, faces it and lifts its
##             arms; the head comes down onto its neck over `settle` s.
##   "triumph" whole again: a beat of triumph, `triumph` s, then on.
## Reunited (`whole`), it walks on whole, the head on its shoulders (eyes
## lit, its breath stopped), roaming any way, climbing and leaping still.
##
## The walker: it is a stone he stands on and rides (the base's box); walked
## into while it moves (or met by its shockwave), he is shoved through his
## own motor (PilotMotor.knock). No damage. He can't push it.
## Round 2: docs/design/roguelike/headless-body-round2.md.

signal reunited(enemy)

const Look = preload("res://scripts/enemies/headless_body_look.gd")

## The head it looks for (found among the field's enemies: the one with a mouth).
var head: Node3D = null
## Reunited: the head on its neck.
var whole := false
## Counted, for the HUD and checks.
var climbs := 0
var leaps := 0
## Of the leaps, those ledge to ledge.
var jumps := 0
var listens := 0
## Shockwaves sent, and those that threw the walker.
var shocks := 0
var shock_hits := 0
## The last leap's kind ("jump" ledge to ledge, "drop" down), for the HUD.
var leap_kind := ""
## Climbing up from a cliff spawn (cleared once it is over the lip).
var spawned_on_cliff := false
var homed := false
## The camera's quake now (m), from its landings.
var quake := 0.0
## Head heights (m): the head's; legs, torso, neck (top of the stump's cut).
var hh := 1.0
var legs_h := 1.0
var torso_h := 1.0
var neck_h := 1.0
var arm_l := 1.0
var _heading := 0.0
var _next_listen := 0.0
var _rng := RandomNumberGenerator.new()
var _phase := 0.0
var _step_side := 0.0
var _climb_from := 0.0
var _lip_y := INF
var _face_pt := Vector3.ZERO
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _listen_from := 0.0
var _picked := false
var _unsensed := 0.0
var _seat_from := Vector3.ZERO
var _seat_k := 1.0
var _ray := PhysicsRayQueryParameters3D.new()
## The model and its clips.
var look: Look
var _clock := 0.0
## The leap's time in the air (s), the landing's clip, the haul's own clock,
## the slap of its hands onto the lip (s since, -1 not yet), the lip it
## mantles over, the cross-fade into the state now, the state it had.
var _flight := 1.0
var _land_clip := "land"
var _haul_t := 0.0
var _grab_t := -1.0
var _mantle_lip := Vector3.ZERO
var _fade := 0.2
var _was := ""
var _snap := true
var _triumph_thud := false
var _dust: Array = []
## Live shockwaves: {at, r, max, power, done (the walker met), parts}.
var _waves: Array = []
func _init() -> void:
	cost = 5
	tags = PackedStringArray(["heavy","climbs","leaps","pushes"])
	tell_sound = &"body_found"
	rest_colour = Color(0.56,0.53,0.48)
	mark_colour = Color(0.85,0.62,0.32)

func default_knobs(n: Dictionary) -> Dictionary:
	return {
		"head_size":3.0,"legs":0.75,"torso":1.2,"breadth":1.3,"depth":0.72,"arm":1.1,
		"walk":n.walk*0.9,"home":n.run*0.7,"accel":3.0,"turn":0.9,"step":n.unit*0.6,"look":0.9,
		"listen":2.6,"listen_every":7.0,"hear":n.unit*80.0,"sense":n.unit*15.0,"noise":0.35,"lose":2.0,
		"climb":n.unit*1.25,"haul":0.55,"climb_max":n.unit*20.0,"standoff":0.25,"lip_in":0.8,"mantle":1.4,
		"leap_max":n.unit*11.0,"drop_max":n.unit*20.0,"windup":1.1,"leap_up":n.unit*1.6,"land":1.0,
		"leap_gravity":n.gravity*0.7,
		# Ledge to ledge: a gap up to `jump_gap` Hh, onto a ledge up to
		# `jump_rise` Hh over or `jump_sink` Hh under its feet; the arc
		# peaks `jump_arc` of the way's length over the takeoff.
		"jump_gap":3.0,"jump_rise":0.5,"jump_sink":1.5,"jump_arc":0.22,
		"shove_out":n.unit*5.0,"shove_up":n.unit*1.0,
		# Shockwaves: radius in Hh, speed of the front, the shove at the
		# middle (m out, m up), its share left at the rim, the band over
		# the wave's ground that is hit (a walker higher off the ground
		# than `shock_air` m as it passes is jumped clear).
		"shock_r":4.0,"shock_speed":n.unit*16.0,"shock_out":n.unit*9.0,"shock_up":n.unit*2.2,
		"shock_edge":0.2,"shock_band":n.unit*1.7,"shock_air":n.unit*0.45,"shock_mantle":0.5,
		"cling":1.0,
		"reunite":n.unit*1.6,"settle":2.2,"whole_climb":0.6,"seed":1,
		# Round 3, the clips: a step's length walking and striding home (Hh;
		# the clips are made for these, other values slide the feet), and
		# the beat of triumph once whole (s; it was straight to listening).
		"stride":Look.WALK_STEP,"stride_home":Look.STRIDE_STEP,"triumph":1.8,
	}

## Its build in head heights: the box the walker meets is its torso's
## breadth and depth, up to the neck.
func _size(n: Dictionary) -> void:
	hh = float(knobs.head_size)*n.unit
	legs_h = hh*float(knobs.legs)
	torso_h = hh*float(knobs.torso)
	neck_h = legs_h+torso_h
	arm_l = hh*float(knobs.arm)
	width = hh*float(knobs.breadth)
	length = hh*float(knobs.depth)
	height = neck_h

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	super.setup(host,at,face,overrides)
	_rng.seed = int(knobs.seed)
	_heading = facing
	grounded = true
	_go("listen")

## Set on a cliff face, already climbing: `lip` the top edge of the face
## over it, `out` (x, z) the face's outward way. Its raised hands sit `cling`
## m under the lip, so none of it shows over the top till it hauls up.
func cling(lip: Vector3, out: Vector2) -> void:
	var n := out.normalized()
	facing = PilotMotor.facing_of(-n)
	rotation.y = facing
	position = Vector3(lip.x,lip.y-(neck_h+arm_l*0.75)-float(knobs.cling),lip.z)+Vector3(n.x,0.0,n.y)*(length*0.5+float(knobs.standoff))
	grounded = false
	vel = Vector3.ZERO
	_climb_from = position.y
	_lip_y = INF
	climbs += 1
	spawned_on_cliff = true
	_go("climb")
	_snap = true
	_animate(0.0)

# --- The figure -------------------------------------------------------------------------

## The model, sized off its head: the build's head height to ours.
func _art(root: Node3D) -> void:
	look = Look.new()
	look.name = "Look"
	root.add_child(look)
	look.build(hh/Look.HH)

## The tell: the stump's raw cut glows.
func tint(colour: Color) -> void:
	super.tint(colour)
	if look != null: look.warm(0.0 if colour == rest_colour else 1.0)

# --- What the head asks ------------------------------------------------------------------

## Where the head's chin sits now: on the neck, or on its way there.
func head_seat() -> Vector3:
	var seat := look.seat().origin
	if _seat_k >= 1.0: return seat
	var k := smoothstep(0.0,1.0,_seat_k)
	var p := _seat_from.lerp(seat,k)
	p.y += sin(k*PI)*hh*0.5
	return p

func head_facing() -> float:
	return facing

## The stump's turn off its facing (the head's skin takes it as Euler).
func head_tilt() -> Vector3:
	return (Basis(Vector3.UP,facing).inverse()*look.seat().basis.orthonormalized()).get_euler()

# --- A frame -------------------------------------------------------------------------------

func think(delta: float) -> void:
	state_t += delta
	_clock += delta
	quake = maxf(0.0,quake-delta*1.2)
	_find_head()
	_dusts(delta)
	_shocks(delta)
	if whole: _seat_k = minf(1.0,_seat_k+delta/float(knobs.settle))
	match state:
		"listen": _listen(delta)
		"roam","home": _walking(delta)
		"climb": _climb(delta)
		"mantle": _mantle(delta)
		"windup": _windup(delta)
		"land":
			_brake(delta)
			if state_t >= float(knobs.land): _go("listen")
		"reach": _reach_head(delta)
		"triumph": _triumph(delta)
	_animate(delta)

func _go(to: String) -> void:
	state = to
	state_t = 0.0
	if to == "listen":
		_listen_from = facing
		_picked = false
		listens += 1
		field.sound(&"body_listen",position)
	elif to == "roam":
		_next_listen = float(knobs.listen_every)*_rng.randf_range(0.7,1.3)

func _find_head() -> void:
	if head != null and is_instance_valid(head): return
	head = null
	for e in field.enemies:
		if is_instance_valid(e) and e != self and e.has_method("mouth"): head = e

func _forward3() -> Vector3:
	var f := PilotMotor.forward(facing)
	return Vector3(f.x,0.0,f.y)

func _way3(angle: float) -> Vector3:
	var f := PilotMotor.forward(angle)
	return Vector3(f.x,0.0,f.y)

# --- Listening and walking -----------------------------------------------------------------

func _listen(delta: float) -> void:
	_brake(delta)
	var k := state_t/float(knobs.listen)
	# A sweep one way and the other, the stump cocked as it turns.
	if k < 0.7:
		facing = wrapf(_listen_from+sin(k/0.7*TAU)*0.55,-PI,PI)
		return
	# Heard: turns to the bearing, then goes.
	if not _picked:
		_picked = true
		_heading = _pick_way()
	var step := clampf(angle_difference(facing,_heading),-float(knobs.turn)*1.5*delta,float(knobs.turn)*1.5*delta)
	facing = wrapf(facing+step,-PI,PI)
	if k >= 1.0 and absf(angle_difference(facing,_heading)) < 0.15:
		if not whole and _senses(): _home()
		else: _go("roam")

## The way it heard the head (noisy, less so near), or any way out of
## hearing (or whole); turned off a dead end (a rim with nothing below, a
## wall it won't climb).
func _pick_way() -> float:
	var way := facing+_rng.randf_range(-1.2,1.2)
	if not whole and head != null:
		var to := head.global_position-global_position
		var d := Vector2(to.x,to.z).length()
		if d <= float(knobs.hear):
			var noise := float(knobs.noise)*clampf(d/float(knobs.hear),0.25,1.0)
			way = PilotMotor.facing_of(Vector2(to.x,to.z).normalized())+_rng.randf_range(-noise,noise)
	for turn in [0.0,0.6,-0.6,1.2,-1.2,1.9,-1.9,PI]:
		if _way_ok(way+turn): return wrapf(way+turn,-PI,PI)
	return wrapf(way,-PI,PI)

func _way_ok(angle: float) -> bool:
	var dir := _way3(angle)
	var wall := _wall_along(dir,length*0.5+3.0)
	if not wall.is_empty(): return _climbable(wall) != INF and _wants_up()
	var past := position+dir*(length*0.5+3.0)
	if _floor(past,float(knobs.step),float(knobs.step)*2.0) != -INF: return true
	return not _landing(dir).is_empty()

func _walking(delta: float) -> void:
	if whole: pass
	elif _reunite_near():
		_go("reach")
		head.perch = self
		_seat_from = head.position
		_seat_k = 0.0
		field.sound(&"body_reach",position)
		return
	elif state == "roam" and _senses(): _home()
	elif state == "home":
		if _senses(): _unsensed = 0.0
		else: _unsensed += delta
		if _unsensed > float(knobs.lose):
			homed = false
			rest()
			_go("listen")
			return
		var to := head.global_position-position
		_heading = PilotMotor.facing_of(Vector2(to.x,to.z).normalized())
	var fwd := _forward3()
	var wall := _wall_along(fwd,length*0.5+float(knobs.look))
	if not wall.is_empty():
		_meet_wall(wall)
		return
	if _floor(position+fwd*(length*0.5+float(knobs.look)),float(knobs.step),float(knobs.step)*2.0) == -INF:
		_meet_edge(fwd)
		return
	var speed := float(knobs.home) if state == "home" else float(knobs.walk)*(1.15 if whole else 1.0)
	var step := clampf(angle_difference(facing,_heading),-float(knobs.turn)*delta,float(knobs.turn)*delta)
	facing = wrapf(facing+step,-PI,PI)
	var aligned := clampf(cos(angle_difference(facing,_heading)),0.0,1.0)
	var want := PilotMotor.forward(facing)*speed*aligned*aligned
	var flat := Vector2(vel.x,vel.z).move_toward(want,float(knobs.accel)*delta)
	vel.x = flat.x
	vel.z = flat.y
	if state == "roam":
		_next_listen -= delta
		if _next_listen <= 0.0: _go("listen")

func _home() -> void:
	homed = true
	_unsensed = 0.0
	_go("home")
	tell(mark_colour)

func _brake(delta: float) -> void:
	var flat := Vector2(vel.x,vel.z).move_toward(Vector2.ZERO,float(knobs.accel)*2.0*delta)
	vel.x = flat.x
	vel.z = flat.y

## The head within `sense` m, nothing between its neck and it.
func _senses() -> bool:
	if head == null or head.perch != null: return false
	var neck := position+Vector3.UP*neck_h
	var at: Vector3 = head.global_position+Vector3.UP*float(head.height)*0.5
	if neck.distance_to(at) > float(knobs.sense): return false
	_ray.from = neck
	_ray.to = at
	_ray.collision_mask = field.study.ground.mask
	_ray.exclude = _skip()
	return field.study.get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()

## Whether it hears the head over it (it climbs for it).
func _wants_up() -> bool:
	if whole: return true
	if head == null: return false
	if Vector2(head.global_position.x-position.x,head.global_position.z-position.z).length() > float(knobs.hear): return false
	return head.ground_y() > position.y+float(knobs.step)*2.0

func _reunite_near() -> bool:
	if head == null or head.perch != null or head.swallowed: return false
	if absf(head.ground_y()-position.y) > float(knobs.step)*3.0: return false
	var flat := Vector2(head.position.x-position.x,head.position.z-position.z).length()
	return flat <= length*0.5+head.length*0.5+float(knobs.reunite)

# --- Walls and climbing -----------------------------------------------------------------------

## A wall (steep) along `dir` from its knees, within `reach` m: the hit, or {}.
func _wall_along(dir: Vector3, reach: float) -> Dictionary:
	for up: float in [float(knobs.step)+0.1,neck_h*0.5]:
		var from := position+Vector3.UP*up
		var hit := _cast(from,from+dir*reach)
		if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.5: return hit
	return {}

## The top of the wall `hit` (a ray down past its face from `climb_max`
## over its feet), INF if it is taller than that.
func _climbable(hit: Dictionary) -> float:
	var n := hit.normal as Vector3
	n = Vector3(n.x,0.0,n.z).normalized()
	var past := (hit.position as Vector3)-n*float(knobs.lip_in)
	var top := _cast(Vector3(past.x,position.y+float(knobs.climb_max),past.z),Vector3(past.x,position.y+float(knobs.step),past.z))
	if top.is_empty() or (top.normal as Vector3).y < 0.6: return INF
	return (top.position as Vector3).y

func _meet_wall(hit: Dictionary) -> void:
	vel.x = 0.0
	vel.z = 0.0
	var climbing := _climbable(hit) != INF and _wants_up()
	if climbing and whole: climbing = _rng.randf() < float(knobs.whole_climb)
	if not climbing:
		_go("listen")
		return
	var n := hit.normal as Vector3
	facing = PilotMotor.facing_of(-Vector2(n.x,n.z).normalized())
	_climb_from = position.y
	_lip_y = INF
	climbs += 1
	_go("climb")
	field.sound(&"body_grip",hit.position)

func _climb(delta: float) -> void:
	vel = Vector3.ZERO
	var fwd := _forward3()
	var chest := position+Vector3.UP*neck_h*0.55
	var hit := _cast(chest,chest+fwd*(length*0.5+float(knobs.standoff)+1.5))
	if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.7:
		var n := hit.normal as Vector3
		var want := PilotMotor.facing_of(-Vector2(n.x,n.z).normalized())
		facing = lerp_angle(facing,want,1.0-exp(-4.0*delta))
		var gap := chest.distance_to(hit.position as Vector3)-length*0.5
		position += fwd*(gap-float(knobs.standoff))*minf(1.0,6.0*delta)
		_face_pt = hit.position
	else:
		_face_pt = position+fwd*(length*0.5+float(knobs.standoff))+Vector3.UP*neck_h*0.55
	# The lip: a ray down past the face from over its reach.
	var reach := neck_h+arm_l*0.75
	var past := _face_pt+fwd*float(knobs.lip_in)
	var lip := _cast(Vector3(past.x,position.y+reach,past.z),Vector3(past.x,position.y+neck_h*0.2,past.z))
	_lip_y = (lip.position as Vector3).y if not lip.is_empty() and (lip.normal as Vector3).y > 0.6 else INF
	if _lip_y != INF and _lip_y-position.y <= neck_h*0.55:
		_mantle_from = position
		var onto := Vector3(_face_pt.x,_lip_y,_face_pt.z)+fwd*(length*0.5+0.6)
		var g := _floor(onto,1.0,1.5)
		_mantle_to = Vector3(onto.x,g if g != -INF else _lip_y,onto.z)
		_mantle_lip = Vector3(_face_pt.x,_lip_y,_face_pt.z)
		_go("mantle")
		field.sound(&"body_grip",Vector3(_face_pt.x,_lip_y,_face_pt.z))
		return
	if hit.is_empty() and _lip_y == INF:
		# The wall gone from under its hands with no top found: it lets go.
		_fall()
		return
	if position.y-_climb_from > float(knobs.climb_max):
		_fall()
		return
	if _lip_y != INF: _haul_t += delta
	else:
		_haul_t = 0.0
		_grab_t = -1.0
	var rise := float(knobs.climb)*delta*(float(knobs.haul) if _lip_y != INF else 1.0)
	position.y += rise
	var was := _phase
	_phase += rise/(arm_l*0.45)
	if int(was) != int(_phase): field.sound(&"body_grip",position+Vector3.UP*(neck_h+arm_l*0.6))

func _mantle(delta: float) -> void:
	var k := clampf(state_t/float(knobs.mantle),0.0,1.0)
	var up := smoothstep(0.0,0.6,k)
	var over := smoothstep(0.45,1.0,k)
	position = Vector3(lerpf(_mantle_from.x,_mantle_to.x,over),lerpf(_mantle_from.y,_mantle_to.y,up),lerpf(_mantle_from.z,_mantle_to.z,over))
	if k >= 1.0:
		grounded = true
		spawned_on_cliff = false
		# Its weight comes down on the top: a smaller wave.
		_shock(position,float(knobs.shock_mantle))
		_go("listen")

# --- Edges and leaps ------------------------------------------------------------------------

func _meet_edge(fwd: Vector3) -> void:
	vel.x = 0.0
	vel.z = 0.0
	var land := _landing(fwd)
	if land.is_empty() or (head == null and not whole):
		_go("listen")
		return
	_leap_to = land.at
	leap_kind = land.kind
	_go("windup")
	field.sound(&"body_windup",position)

## Where it would come down going off the edge along `dir`: across the
## gap onto a ledge at about its height if the gap is narrow enough
## (`_ledge`), else down onto a lower floor: {at, kind} or {}.
func _landing(dir: Vector3) -> Dictionary:
	var ledge := _ledge(dir)
	if not ledge.is_empty(): return ledge
	return _drop(dir)

## The widest gap it jumps ledge to ledge (m): `jump_gap` head heights.
func jump_gap() -> float:
	return float(knobs.jump_gap)*hh

## A ledge across the gap along `dir`: the far rim within `jump_gap()` of
## the near one, its top no more than `jump_rise` Hh over its feet or
## `jump_sink` Hh under, room on it for its body: {at, kind "jump", gap}
## or {}.
func _ledge(dir: Vector3) -> Dictionary:
	var step := float(knobs.step)
	var rim := -1.0
	var d := 0.0
	while d <= length*0.5+float(knobs.look)+1.0:
		if _floor(position+dir*d,step,step*2.0) == -INF:
			rim = d
			break
		d += 0.25
	if rim < 0.0: return {}
	var over := float(knobs.jump_rise)*hh
	var under := float(knobs.jump_sink)*hh
	d = rim+0.25
	while d <= rim+jump_gap():
		var p := position+dir*d
		var hit := _cast(Vector3(p.x,position.y+over+step,p.z),Vector3(p.x,position.y-under,p.z))
		if not hit.is_empty() and (hit.normal as Vector3).y > 0.7:
			var y := (hit.position as Vector3).y
			var onto := position+dir*(d+length*0.5+1.0)
			var g := _floor(Vector3(onto.x,y,onto.z),1.0,1.0)
			if g == -INF: return {}
			return {"at":Vector3(onto.x,g,onto.z),"kind":"jump","gap":d-rim}
		d += 0.25
	return {}

## A floor out along `dir` lower than its feet, within `leap_max` m across
## and `drop_max` m down, room on it for its body: {at, kind "drop"} or {}.
func _drop(dir: Vector3) -> Dictionary:
	var d := length*0.5+float(knobs.look)
	while d <= float(knobs.leap_max):
		var p := position+dir*d
		var hit := _cast(p+Vector3.UP*float(knobs.step),p-Vector3.UP*float(knobs.drop_max))
		if not hit.is_empty() and (hit.normal as Vector3).y > 0.7:
			var y := (hit.position as Vector3).y
			if y < position.y-float(knobs.step):
				var onto := position+dir*(d+length*0.5+1.0)
				var g := _floor(Vector3(onto.x,y,onto.z),1.0,1.0)
				if g != -INF: return {"at":Vector3(onto.x,g,onto.z),"kind":"drop"}
		d += 0.75
	return {}

func _windup(delta: float) -> void:
	_brake(delta)
	var to := Vector2(_leap_to.x-position.x,_leap_to.z-position.z)
	facing = lerp_angle(facing,PilotMotor.facing_of(to.normalized()),1.0-exp(-5.0*delta))
	if state_t < float(knobs.windup): return
	var g := float(knobs.leap_gravity)
	var drop := position.y-_leap_to.y
	var up := float(knobs.leap_up)
	if leap_kind == "jump":
		# Across: a longer, flatter throw, peaking a share of its length
		# (and over the far ledge if that stands higher).
		up = maxf(up,float(knobs.jump_arc)*to.length())+maxf(0.0,-drop)
		jumps += 1
	var vy := sqrt(2.0*g*up)
	var t := (vy+sqrt(maxf(vy*vy+2.0*g*drop,0.0)))/g
	var flat := to/t
	_flight = t
	vel = Vector3(flat.x,vy,flat.y)
	grounded = false
	leaps += 1
	_go("leap")
	field.sound(&"body_leap",position)

func _fall() -> void:
	grounded = false
	vel = Vector3(vel.x,minf(vel.y,0.0),vel.z)
	_go("fall")

## Down: the harder it came down, the bigger the wave (a head height's
## fall is 1; 0.6 to 1.5).
func _landed() -> void:
	var impact := maxf(0.0,-vel.y)
	_land_clip = "drop_land" if state == "leap" and leap_kind == "drop" else "land"
	grounded = true
	vel = Vector3.ZERO
	_go("land")
	_puff(position,hh*2.2)
	field.sound(&"body_land",position)
	_shock(position,clampf(impact/sqrt(2.0*float(knobs.leap_gravity)*hh),0.6,1.5))

# --- Shockwaves -------------------------------------------------------------------------------

## A shockwave from `at`, `power` (1 a leap's landing): a ring and a dust
## wall running out along the ground to `shock_r` Hh × √power, stones
## kicked up; the walker it passes on the ground is thrown back and up
## through his motor, less the farther out.
func _shock(at: Vector3, power: float) -> void:
	shocks += 1
	quake = maxf(quake,0.35+0.45*power)
	var reach := float(knobs.shock_r)*hh*sqrt(power)
	var parts: Array = []
	# The front: a thin bright ring hugging the ground.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	ring.mesh = torus
	ring.material_override = _wave_mat(Color(0.95,0.88,0.74,0.9))
	parts.append(ring)
	# Behind it, a skirt of dust thrown up off the ground.
	var wall := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 48
	wall.mesh = tube
	wall.material_override = _wave_mat(Color(0.74,0.68,0.58,0.55))
	parts.append(wall)
	for p: MeshInstance3D in parts:
		field.add_child(p)
		p.global_position = at+Vector3.UP*0.15
		p.scale = Vector3(0.1,0.1,0.1)
	# Stones kicked up round it.
	var chips: Array = []
	for i in 10:
		var chip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE*hh*_rng.randf_range(0.08,0.16)*sqrt(power)
		chip.mesh = box
		chip.material_override = _wave_mat(Color(0.6,0.56,0.5,1.0))
		field.add_child(chip)
		var a := TAU*(i+_rng.randf())/10.0
		chip.global_position = at+Vector3(sin(a),0.3,cos(a))*hh*0.6
		chips.append([chip,Vector3(sin(a)*_rng.randf_range(3.0,7.0),_rng.randf_range(5.0,10.0)*sqrt(power),cos(a)*_rng.randf_range(3.0,7.0))])
	_waves.append({"at":at,"r":0.0,"max":reach,"power":power,"done":false,"t":0.0,"parts":parts,"chips":chips})
	field.sound(&"body_shock",at)

func _wave_mat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _shocks(delta: float) -> void:
	for w: Dictionary in _waves:
		w.t += delta
		w.r = minf(w.max,w.r+float(knobs.shock_speed)*delta)
		var k: float = w.r/w.max
		var fade := 1.0-smoothstep(0.55,1.0,k) if w.r < w.max else maxf(0.0,1.0-(w.t-w.max/float(knobs.shock_speed))/0.35)
		var ring: MeshInstance3D = w.parts[0]
		var wall: MeshInstance3D = w.parts[1]
		var thick := hh*0.35*sqrt(w.power)
		ring.scale = Vector3(w.r,thick*(1.0-0.6*k),w.r)
		var high := hh*0.9*sqrt(w.power)*sin(minf(k,1.0)*PI*0.5+0.35)*(1.0-0.7*k)
		wall.scale = Vector3(maxf(w.r-thick*0.4,0.1),maxf(high,0.05),maxf(w.r-thick*0.4,0.1))
		wall.global_position.y = (w.at as Vector3).y+high*0.5
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.9*fade
		(wall.material_override as StandardMaterial3D).albedo_color.a = 0.55*fade
		for c: Array in w.chips:
			var chip: MeshInstance3D = c[0]
			c[1].y -= float(knobs.leap_gravity)*delta
			chip.global_position += c[1]*delta
			chip.rotation += Vector3(3.0,2.0,1.0)*delta
			if chip.global_position.y < (w.at as Vector3).y: chip.visible = false
		if not w.done: _shock_meets(w)
	for w: Dictionary in _waves:
		if w.t > w.max/float(knobs.shock_speed)+0.6:
			for p: Node in w.parts+w.chips.map(func(c: Array) -> Node: return c[0]):
				if is_instance_valid(p): p.queue_free()
	_waves = _waves.filter(func(w: Dictionary) -> bool: return w.t <= w.max/float(knobs.shock_speed)+0.6)

## The front reaching the walker: on the ground in the wave's band (or
## barely off it), he is thrown; airborne over it, he is clear.
func _shock_meets(w: Dictionary) -> void:
	var m: PilotMotor = field.motor
	var at: Vector3 = w.at
	var off := Vector2(m.feet.x-at.x,m.feet.z-at.z)
	var d := off.length()
	if d > w.max:
		w.done = true
		return
	if d > w.r: return
	w.done = true
	if m.seized() or m.rider != null: return
	var dy := m.feet.y-at.y
	if absf(dy) > float(knobs.shock_band): return
	if not m.grounded and m.feet.y-_floor(m.feet,0.1,float(knobs.shock_band)*2.0) > float(knobs.shock_air): return
	# On its shoulders he rides it out.
	if m.grounded and field.under_pilot() == body.get_rid(): return
	var f := lerpf(1.0,float(knobs.shock_edge),d/w.max)*float(w.power)
	var way := off.normalized() if d > 0.1 else PilotMotor.forward(facing)
	shock_hits += 1
	shove_pilot(m,way,float(knobs.shock_out)*f,float(knobs.shock_up)*f)

# --- Reunion -----------------------------------------------------------------------------------

func _reach_head(delta: float) -> void:
	_brake(delta)
	var to := Vector2(_seat_from.x-position.x,_seat_from.z-position.z)
	if to.length() > 0.2: facing = lerp_angle(facing,PilotMotor.facing_of(to.normalized()),1.0-exp(-3.0*delta))
	_seat_k = minf(1.0,state_t/float(knobs.settle))
	if _seat_k >= 1.0:
		whole = true
		homed = false
		rest()
		_puff(look.seat().origin,hh*1.2)
		quake = 0.3
		field.sound(&"body_whole",position)
		reunited.emit(self)
		_triumph_thud = false
		_go("triumph")

## Whole: arms up, then the fists down with a thud (at the clip's 1.34 of
## its 1.8 s), then on.
func _triumph(delta: float) -> void:
	_brake(delta)
	var t := float(knobs.triumph)
	if not _triumph_thud and state_t >= t*1.34/1.8:
		_triumph_thud = true
		quake = maxf(quake,0.25)
		field.sound(&"body_step",position)
	if state_t >= t: _go("listen")

# --- Moving -------------------------------------------------------------------------------------

func _move(delta: float) -> void:
	if state in ["leap","fall"]:
		vel.y -= float(knobs.leap_gravity)*delta
		var to := position+vel*delta
		var hit := _cast(position+Vector3.UP*0.05,to)
		if not hit.is_empty():
			var n := hit.normal as Vector3
			if n.y > 0.5 and vel.y <= 0.0:
				position = hit.position
				_landed()
			else:
				# A wall on the way: it stops dead against it and drops.
				position = (hit.position as Vector3)+Vector3(n.x,0.0,n.z)*0.1-Vector3.UP*0.05
				vel.x = 0.0
				vel.z = 0.0
				if state == "leap": _go("fall")
		else: position = to
		if position.y < field.lost:
			gone = true
			field.gone_count += 1
			fell.emit(self)
			queue_free()
	elif state not in ["climb","mantle"]:
		position.x += vel.x*delta
		position.z += vel.z*delta
		var g := _floor(position,float(knobs.step),float(knobs.step))
		if g == -INF: _fall()
		else: position.y = move_toward(position.y,g,maxf(absf(g-position.y)*8.0,2.0)*delta) if g > position.y else g
		# A step each phase (the clips' feet come down on whole phases).
		var was := _phase
		_phase += Vector2(vel.x,vel.z).length()*delta/(hh*float(knobs.stride_home if state == "home" else knobs.stride))
		if floori(was) != floori(_phase):
			field.sound(&"body_step",position)
			quake = maxf(quake,0.06)
	rotation.y = facing

# --- The clips ------------------------------------------------------------------------------

## The cross-fade into each state (s); others take FADE.
const FADE := 0.22
const FADES := {"land":0.05,"leap":0.08,"fall":0.15,"mantle":0.12,"windup":0.1,"triumph":0.08,"reach":0.3}
## The slap of the hands onto a lip: up and over (s), then down on it.
const GRAB := 0.32

## The clips its state wants, at the places its own clocks say (the walk's
## and the climb's phase, its state's time over that state's knob), then
## the corrections on top: hands on the real wall and lip.
func _animate(delta: float) -> void:
	if look == null: return
	if state != _was:
		_was = state
		_fade = float(FADES.get(state,FADE))
	var idle := fposmod(_clock,float(look.lengths.idle))
	match state:
		"listen":
			if whole: look.want("idle",idle)
			else: look.want("listen",state_t/float(knobs.listen)*float(look.lengths.listen))
		"roam","home":
			var gait := "stride" if state == "home" else "walk"
			var pace := float(knobs.home) if state == "home" else float(knobs.walk)
			var m := clampf(Vector2(vel.x,vel.z).length()/maxf(pace*0.5,0.1),0.0,1.0)
			look.want(gait,look.loop_time(gait,_phase,2.0),m)
			look.want("idle",idle,1.0-m)
		"climb":
			if _lip_y == INF: look.want("climb",look.loop_time("climb",_phase,2.0))
			else:
				var clip := "spawn_haul" if spawned_on_cliff else "haul"
				look.want(clip,fposmod(_haul_t,float(look.lengths[clip])))
		"mantle": look.want("mantle",state_t/float(knobs.mantle)*float(look.lengths.mantle))
		"windup": look.want("windup",state_t/float(knobs.windup)*float(look.lengths.windup))
		"leap":
			var clip := "drop_air" if leap_kind == "drop" else "jump_air"
			look.want(clip,state_t/maxf(_flight,0.1)*float(look.lengths[clip]))
		"fall": look.want("drop_air",minf(state_t+0.3,float(look.lengths.drop_air)*0.9))
		"land": look.want(_land_clip,state_t/float(knobs.land)*float(look.lengths[_land_clip]))
		"reach": look.want("reach",state_t/float(knobs.settle)*float(look.lengths.reach))
		"triumph": look.want("triumph",state_t/float(knobs.triumph)*float(look.lengths.triumph))
		_: look.want("idle",idle)
	look.advance(delta,0.0 if _snap else _fade)
	_snap = false
	_hands(delta)

## Its right (global, flat).
func _right3() -> Vector3:
	var f := _forward3()
	return Vector3(-f.z,0.0,f.x)

## The hands onto the world: climbing, each hand moved in or out to the
## real face (the clip has a flat wall `standoff` off its front); hauling,
## both on the lip (slapped down onto it once they can reach it); early in
## the mantle, pressing on it.
func _hands(delta: float) -> void:
	var fwd := _forward3()
	var right := _right3()
	var k := look.k
	match state:
		"climb":
			if _lip_y == INF:
				var face := position+fwd*(length*0.5+float(knobs.standoff))
				for side in ["L","R"]:
					var w := look.wrist(side)
					var hit := _cast(w-fwd*1.6*k,w+fwd*2.2*k)
					if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.7: continue
					look.reach(side,w+fwd*((hit.position as Vector3)-face).dot(fwd),1.0)
				return
			var lip := Vector3(_face_pt.x,_lip_y,_face_pt.z)
			var reach := look.arm_reach()
			var lift := 0.0
			if _grab_t < 0.0:
				var near := look.shoulder("L").distance_to(lip+Vector3.UP*0.42*k-right*1.5*k)
				if near <= reach*1.02: _grab_t = 0.0
			if _grab_t >= 0.0:
				var was := _grab_t
				_grab_t += delta
				# Up over the lip, a beat, then slammed down on it.
				lift = 1.3*k*smoothstep(0.0,0.12,_grab_t)*(1.0-smoothstep(0.2,GRAB,_grab_t))
				if was < GRAB and _grab_t >= GRAB:
					field.sound(&"body_grip",lip)
					quake = maxf(quake,0.12)
					for s in [-1.0,1.0]: _puff(lip+right*s*1.5*k+fwd*0.4*k,hh*0.45)
			var w := smoothstep(0.0,0.2,_haul_t)
			for side in ["L","R"]:
				var s := -1.0 if side == "L" else 1.0
				var at := lip+fwd*0.35*k+right*s*1.5*k+Vector3.UP*(0.42*k+lift)
				look.reach(side,at,w,fwd,Vector3.DOWN)
		"mantle":
			var kk := clampf(state_t/float(knobs.mantle),0.0,1.0)
			var w := 1.0-smoothstep(0.16,0.34,kk)
			for side in ["L","R"]:
				var s := -1.0 if side == "L" else 1.0
				look.reach(side,_mantle_lip+fwd*0.3*k+right*s*1.7*k+Vector3.UP*0.42*k,w,fwd,Vector3.DOWN)

# --- The world, as it asks ------------------------------------------------------------------------

## Its own body and its head's left out of every ray.
func _skip() -> Array[RID]:
	var out: Array[RID] = [body.get_rid()]
	for e in field.enemies:
		if is_instance_valid(e) and e.get("body") != null: out.append(e.body.get_rid())
	return out

func _cast(from: Vector3, to: Vector3) -> Dictionary:
	_ray.from = from
	_ray.to = to
	_ray.collision_mask = field.study.ground.mask
	_ray.exclude = _skip()
	return field.study.get_world_3d().direct_space_state.intersect_ray(_ray)

## The floor under `p`, looked for from `up` over it to `down` under it; -INF none.
func _floor(p: Vector3, up: float, down: float) -> float:
	var hit := _cast(p+Vector3.UP*up,p-Vector3.UP*down)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.5: return -INF
	return (hit.position as Vector3).y

# --- Dust (greybox: a ring that spreads and fades) ------------------------------------------------

func _puff(at: Vector3, size: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 1.0
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78,0.72,0.62,0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	field.add_child(ring)
	ring.global_position = at+Vector3.UP*0.2
	ring.scale = Vector3.ONE*size*0.3
	_dust.append([ring,0.0,size])

func _dusts(delta: float) -> void:
	for d: Array in _dust:
		d[1] += delta
		var k := clampf(float(d[1])/0.8,0.0,1.0)
		var ring: MeshInstance3D = d[0]
		ring.scale = Vector3(1.0,0.4,1.0)*float(d[2])*lerpf(0.3,1.0,sqrt(k))
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.7*(1.0-k)
		if k >= 1.0: ring.queue_free()
	_dust = _dust.filter(func(d: Array) -> bool: return float(d[1]) < 0.8)

func _exit_tree() -> void:
	for d: Array in _dust:
		if is_instance_valid(d[0]): d[0].queue_free()
	_dust.clear()
	for w: Dictionary in _waves:
		for p: Node in w.parts+w.chips.map(func(c: Array) -> Node: return c[0]):
			if is_instance_valid(p): p.queue_free()
	_waves.clear()

# --- The walker -------------------------------------------------------------------------------------

## Heavy: he can't push it; walked into while it moves he is shoved.
func touch(m: PilotMotor, _v_pre: Vector3) -> void:
	if gone or _cool > 0.0 or not harmful() or m.seized(): return
	var local := Basis(Vector3.UP,facing).inverse()*(m.feet-position)
	var margin := float(knobs.radius)+0.25
	if absf(local.x) > width*0.5+margin or absf(local.z) > length*0.5+margin: return
	if m.feet.y > position.y+height-0.1 or m.feet.y < position.y-0.6: return
	if m.recovering() and not m.stunnable(self): return
	var way := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	if way.length() < 0.01: way = PilotMotor.forward(facing)
	shove_pilot(m,way.normalized(),float(knobs.shove_out),float(knobs.shove_up))

func harmful() -> bool:
	return state in ["leap","fall","mantle"] or Vector2(vel.x,vel.z).length() > 0.3

func bucks() -> bool:
	return state in ["leap","fall"]
