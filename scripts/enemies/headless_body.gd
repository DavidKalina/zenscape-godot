extends "res://scripts/enemies/enemy.gd"
## The headless body (docs/design/roguelike/headless-body-round1.md): the
## inhaler head's (scripts/enemies/inhaler_head.gd) lost stone body, a
## hulking greybox figure with an empty neck stump, walking the isles to
## find its head. Greybox: boxes on pivots, no model yet.
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
##   "windup"  at an edge, with a lower floor out along its way within
##             `leap_max` m across and `drop_max` m down: it crouches, arms
##             back, `windup` s.
##   "leap"    the throw: a ballistic arc (`leap_up` m over the takeoff) to
##             that floor, its feet ray-cast along the arc; a wall on the
##             way stops it dead and it drops.
##   "land"    a heavy landing, squashed for `land` s; dust and a quake;
##             a walker within `shock_r` m is thrown off his feet.
##   "fall"    walked off something unseen: it falls (below the study's
##             `lost`, it is gone).
##   "reach"   the head is in arm's reach: it stops, faces it and lifts its
##             arms; the head comes down onto its neck over `settle` s.
## Reunited (`whole`), it walks on whole, the head on its shoulders (eyes
## lit, its breath stopped), roaming any way, climbing and leaping still.
##
## The walker: it is a stone he stands on and rides (the base's box); walked
## into while it moves (or landing near him), he is shoved through his own
## motor (PilotMotor.knock). No damage. He can't push it.

signal reunited(enemy)

## The head it looks for (found among the field's enemies: the one with a mouth).
var head: Node3D = null
## Reunited: the head on its neck.
var whole := false
## Counted, for the HUD and checks.
var climbs := 0
var leaps := 0
var listens := 0
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
var _dust: Array = []
## Pivots of the greybox figure.
var _hips: Node3D
var _trunk: Node3D
var _seat: Node3D
var _arms: Array[Node3D] = []
var _fores: Array[Node3D] = []
var _thighs: Array[Node3D] = []
var _knees: Array[Node3D] = []
## The pose eased toward: crouch (m the hips drop), lean (rad forward),
## twist (rad), cock (rad, the stump tipped), arm reach [left, right] (rad
## about x, 0 hanging, PI straight up), forearm bend (rad), leg swing.
var _crouch := 0.0
var _lean := 0.0
var _twist := 0.0
var _cock := 0.0
var _reach := [0.0,0.0]
var _bend := [0.0,0.0]
var _swing := 0.0

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
		"climb":n.unit*1.25,"climb_max":n.unit*20.0,"standoff":0.25,"lip_in":0.8,"mantle":1.4,
		"leap_max":n.unit*11.0,"drop_max":n.unit*20.0,"windup":1.1,"leap_up":n.unit*1.6,"land":1.0,
		"leap_gravity":n.gravity*0.7,
		"shove_out":n.unit*5.0,"shove_up":n.unit*1.0,"shock_r":n.unit*7.0,"shock_out":n.unit*6.0,"shock_up":n.unit*1.2,
		"reunite":n.unit*1.6,"settle":2.2,"whole_climb":0.6,"seed":1,
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

# --- The figure -------------------------------------------------------------------------

func _art(root: Node3D) -> void:
	var leg_w := hh*0.38
	var arm_w := hh*0.3
	var cut := Color(0.42,0.3,0.26)
	_hips = Node3D.new()
	_hips.position.y = legs_h
	root.add_child(_hips)
	for side in [-1.0,1.0]:
		var thigh := Node3D.new()
		thigh.position.x = side*width*0.26
		_hips.add_child(thigh)
		_part(Vector3(leg_w,legs_h*0.55,leg_w),Vector3(0.0,-legs_h*0.26,0.0),true,Color.WHITE,thigh)
		var knee := Node3D.new()
		knee.position.y = -legs_h*0.5
		thigh.add_child(knee)
		_part(Vector3(leg_w*0.92,legs_h*0.52,leg_w*0.92),Vector3(0.0,-legs_h*0.25,0.0),true,Color.WHITE,knee)
		_part(Vector3(leg_w*1.05,legs_h*0.1,leg_w*1.5),Vector3(0.0,-legs_h*0.46,-leg_w*0.2),true,Color.WHITE,knee)
		_thighs.append(thigh)
		_knees.append(knee)
	_trunk = Node3D.new()
	_hips.add_child(_trunk)
	# Pelvis, belly, the broad chest, the shoulders' slab.
	_part(Vector3(width*0.8,torso_h*0.22,length*0.9),Vector3(0.0,torso_h*0.08,0.0),true,Color.WHITE,_trunk)
	_part(Vector3(width*0.86,torso_h*0.4,length),Vector3(0.0,torso_h*0.36,0.0),true,Color.WHITE,_trunk)
	_part(Vector3(width,torso_h*0.42,length*1.05),Vector3(0.0,torso_h*0.74,-length*0.02),true,Color.WHITE,_trunk)
	_part(Vector3(width*1.06,torso_h*0.12,length*0.9),Vector3(0.0,torso_h*0.95,0.0),true,Color.WHITE,_trunk)
	# The stump: a short neck block, its cut face raw.
	var stump := hh*0.12
	_part(Vector3(hh*0.55,stump,hh*0.5),Vector3(0.0,torso_h+stump*0.5,0.0),true,Color.WHITE,_trunk)
	_part(Vector3(hh*0.5,0.06,hh*0.45),Vector3(0.0,torso_h+stump+0.03,0.0),false,cut,_trunk)
	_seat = Node3D.new()
	_seat.position.y = torso_h+stump-hh*0.06
	_trunk.add_child(_seat)
	for side in [-1.0,1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side*(width*0.5+arm_w*0.45),torso_h*0.88,0.0)
		_trunk.add_child(arm)
		_part(Vector3(arm_w*1.2,arm_w*1.0,arm_w*1.2),Vector3.ZERO,true,Color.WHITE,arm)
		_part(Vector3(arm_w,arm_l*0.5,arm_w),Vector3(0.0,-arm_l*0.25,0.0),true,Color.WHITE,arm)
		var fore := Node3D.new()
		fore.position.y = -arm_l*0.5
		arm.add_child(fore)
		_part(Vector3(arm_w*0.9,arm_l*0.42,arm_w*0.9),Vector3(0.0,-arm_l*0.21,0.0),true,Color.WHITE,fore)
		_part(Vector3(arm_w*1.35,arm_l*0.16,arm_w*1.35),Vector3(0.0,-arm_l*0.48,0.0),true,Color.WHITE,fore)
		_arms.append(arm)
		_fores.append(fore)

# --- What the head asks ------------------------------------------------------------------

## Where the head's chin sits now: on the neck, or on its way there.
func head_seat() -> Vector3:
	var seat := _seat.global_position
	if _seat_k >= 1.0: return seat
	var k := smoothstep(0.0,1.0,_seat_k)
	var p := _seat_from.lerp(seat,k)
	p.y += sin(k*PI)*hh*0.5
	return p

func head_facing() -> float:
	return wrapf(facing+_twist,-PI,PI)

func head_tilt() -> Vector3:
	return Vector3(skin.rotation.x+_lean*0.6,0.0,skin.rotation.z+_cock)

# --- A frame -------------------------------------------------------------------------------

func think(delta: float) -> void:
	state_t += delta
	quake = maxf(0.0,quake-delta*1.2)
	_find_head()
	_dusts(delta)
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
	_pose(delta)

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
	var rise := float(knobs.climb)*delta*(0.55 if _lip_y != INF else 1.0)
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
	_go("windup")
	field.sound(&"body_windup",position)

## A floor out along `dir` lower than its feet (or level), within
## `leap_max` m across and `drop_max` m down, room on it for its body:
## {at} or {}.
func _landing(dir: Vector3) -> Dictionary:
	var d := length*0.5+float(knobs.look)
	while d <= float(knobs.leap_max):
		var p := position+dir*d
		var hit := _cast(p+Vector3.UP*float(knobs.step),p-Vector3.UP*float(knobs.drop_max))
		if not hit.is_empty() and (hit.normal as Vector3).y > 0.7:
			var y := (hit.position as Vector3).y
			if y < position.y-float(knobs.step):
				var onto := position+dir*(d+length*0.5+1.0)
				var g := _floor(Vector3(onto.x,y,onto.z),1.0,1.0)
				if g != -INF: return {"at":Vector3(onto.x,g,onto.z)}
		d += 0.75
	return {}

func _windup(delta: float) -> void:
	_brake(delta)
	var to := Vector2(_leap_to.x-position.x,_leap_to.z-position.z)
	facing = lerp_angle(facing,PilotMotor.facing_of(to.normalized()),1.0-exp(-5.0*delta))
	if state_t < float(knobs.windup): return
	var g := float(knobs.leap_gravity)
	var vy := sqrt(2.0*g*float(knobs.leap_up))
	var drop := position.y-_leap_to.y
	var t := (vy+sqrt(maxf(vy*vy+2.0*g*drop,0.0)))/g
	var flat := to/t
	vel = Vector3(flat.x,vy,flat.y)
	grounded = false
	leaps += 1
	_go("leap")
	field.sound(&"body_leap",position)

func _fall() -> void:
	grounded = false
	vel = Vector3(vel.x,minf(vel.y,0.0),vel.z)
	_go("fall")

func _landed() -> void:
	grounded = true
	vel = Vector3.ZERO
	_go("land")
	quake = 0.5
	_puff(position,hh*2.2)
	field.sound(&"body_land",position)
	var m: PilotMotor = field.motor
	var off := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	if m.grounded and off.length() < float(knobs.shock_r) and absf(m.feet.y-position.y) < float(knobs.step)*3.0 and not m.seized():
		var way := off.normalized() if off.length() > 0.1 else Vector2(1.0,0.0)
		shove_pilot(m,way,float(knobs.shock_out)*(1.0-0.5*off.length()/float(knobs.shock_r)),float(knobs.shock_up))

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
		_puff(_seat.global_position,hh*1.2)
		quake = 0.3
		field.sound(&"body_whole",position)
		reunited.emit(self)
		_go("listen")

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
		var was := _phase
		_phase += Vector2(vel.x,vel.z).length()*delta/(legs_h*1.2)
		if int(was*2.0) != int(_phase*2.0):
			field.sound(&"body_step",position)
			quake = maxf(quake,0.06)
	rotation.y = facing

# --- The pose -----------------------------------------------------------------------------------

func _pose(delta: float) -> void:
	var c := 0.0
	var lean := 0.0
	var twist := 0.0
	var cock := 0.0
	var reach := [0.0,0.0]
	var bend := [0.0,0.0]
	var swing := 0.0
	var spd := Vector2(vel.x,vel.z).length()
	match state:
		"roam","home":
			var amount := clampf(spd/maxf(float(knobs.walk),0.1),0.0,1.3)
			swing = sin(_phase*PI)*0.45*amount
			lean = 0.08*amount
			if state == "home":
				lean = 0.2
				reach = [1.25+swing*0.3,1.25-swing*0.3]
				bend = [-0.3,-0.3]
			else:
				reach = [-swing*0.7,swing*0.7]
				bend = [-0.25,-0.25]
			c = absf(sin(_phase*PI))*legs_h*0.04
		"listen":
			var k := state_t/float(knobs.listen)
			cock = sin(minf(k,0.7)/0.7*TAU)*0.18*(1.0 if not whole else 0.4)
			twist = sin(minf(k,0.7)/0.7*TAU)*0.25
			if not whole:
				# A hand cupped up by where its ear was.
				var side := 0 if sin(minf(k,0.7)/0.7*TAU) > 0.0 else 1
				reach[side] = 2.5
				bend[side] = -1.9
		"climb":
			# Hand over hand: one up, one pulling down; the legs kick in turn.
			var s := sin(_phase*PI)
			var top := 2.95 if _lip_y == INF else clampf(acos(clampf(-(_lip_y-position.y-legs_h-torso_h*0.88)/arm_l,-1.0,1.0)),1.6,3.0)
			if _lip_y == INF: reach = [top-0.55*(1.0+s),top-0.55*(1.0-s)]
			else: reach = [top,top]
			bend = [-0.2,-0.2]
			swing = s*0.35
			lean = 0.1
			c = legs_h*0.12
		"mantle":
			var k := clampf(state_t/float(knobs.mantle),0.0,1.0)
			reach = [lerpf(2.9,0.5,k),lerpf(2.9,0.5,k)]
			bend = [-0.1,-0.1]
			lean = lerpf(-0.05,0.45,smoothstep(0.3,0.8,k))-0.45*smoothstep(0.8,1.0,k)
			c = legs_h*0.35*sin(k*PI)
			swing = 0.6*sin(k*PI)
		"windup":
			var k := clampf(state_t/float(knobs.windup),0.0,1.0)
			c = legs_h*0.4*smoothstep(0.0,0.7,k)
			lean = 0.35*k
			reach = [-0.9*k,-0.9*k]
			bend = [-0.3,-0.3]
		"leap","fall":
			var rising := vel.y > 0.0
			reach = [2.6,2.6] if rising else [1.6,1.6]
			bend = [-0.4,-0.4]
			lean = -0.1 if rising else 0.12
			c = legs_h*(0.25 if rising else 0.05)
			swing = 0.3 if rising else -0.1
		"land":
			var k := clampf(state_t/float(knobs.land),0.0,1.0)
			c = legs_h*0.45*(1.0-smoothstep(0.15,1.0,k))
			lean = 0.3*(1.0-k)
			reach = [0.7*(1.0-k),0.7*(1.0-k)]
			bend = [-0.5,-0.5]
		"reach":
			var k := clampf(state_t/0.8,0.0,1.0)
			reach = [lerpf(0.0,2.75,k),lerpf(0.0,2.75,k)]
			bend = [-0.6*k,-0.6*k]
			lean = -0.12*k
	var e := 1.0-exp(-8.0*delta)
	_crouch = lerpf(_crouch,c,e)
	_lean = lerpf(_lean,lean,e)
	_twist = lerpf(_twist,twist,e)
	_cock = lerpf(_cock,cock,e)
	_swing = lerpf(_swing,swing,e)
	for i in 2:
		_reach[i] = lerpf(_reach[i],reach[i],e)
		_bend[i] = lerpf(_bend[i],bend[i],e)
	# Bent legs: the hips drop `_crouch`, the thighs forward, the knees back.
	var thigh_len := legs_h*0.5
	var a := acos(clampf(1.0-_crouch/(2.0*thigh_len),-1.0,1.0))
	_hips.position.y = legs_h-_crouch
	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		_thighs[i].rotation.x = a+_swing*sgn
		_knees[i].rotation.x = -2.0*a+minf(0.0,-_swing*sgn)*0.6
		_arms[i].rotation.x = _reach[i]
		_arms[i].rotation.z = 0.0
		_fores[i].rotation.x = _bend[i]
	_trunk.rotation = Vector3(-_lean,_twist,_cock)
	skin.rotation = Vector3.ZERO

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
