extends "res://scripts/enemies/enemy.gd"
## The inhaler head (docs/design/roguelike/inhaler-head.md): a colossal
## carved head of the ruin-builders' (scripts/enemies/inhaler_head_look.gd,
## the Blender model art/blender/inhaler_head/), squared Olmec masonry,
## hovering. It drifts its round over the isle and out past the rims; when
## it sees the wanderer it turns its face to him, and breathes in.
##
## In states (`state`):
##   "drift"    a slow, heavy drift round its `route` (or a ring round where
##              it was set down), bobbing, leaning into its way, its chin
##              `hover` over the turf under it (over the void it keeps the
##              last turf's height). Facing where it goes.
##   "notice"   he is within `sight` m, inside its `sight_half` (rad) of its
##              face and nothing stands between its mouth and him: it stops
##              and grinds round to face him at `lock_turn` rad/s (stone
##              dust off its flanks); once within `lock_angle` of him, the
##              tell. Out of sight `lose` s, it drifts on.
##   "tell"     `tell` s: the jaw grinds open, the eyes light, it sinks
##              till its chin is `hover_low` over the turf (its mouth at his
##              chest), dust and leaves start to stream toward it; the draw
##              (and the pull) rises to `tell_draw` of full.
##   "inhale"   up to `inhale` s at the full draw, its face following him
##              at `track_turn` rad/s (a run across its face gets out of
##              the cone). Out of sight `lose` s, or the time up: "after".
##   "gulp"     he reached its mouth: swallowed (PilotMotor `seize`, the
##              figure hidden), the jaw slammed shut, held `hold` s, the
##              head shuddering, dust out of its ear flaps. Then:
##   "blast"    the jaw flies open and he is blown out along its face
##              (PilotMotor.knock: out `blast_out` m, peaking `blast_up` m,
##              laid down `blast_down` s where he lands): off the isle if it
##              faces a rim, unless he gets the sail open. It recoils.
##   "after"    `after` s: the jaw grinds shut, the eyes go dark, it rises
##              back to `hover`; then it drifts on (or notices him again).
##
## The pull (`pull_at`, `_pull`): the air it draws comes from a cone out
## of its mouth, `cone` rad either side of its face far out, `cone_near`
## near it, reaching `reach` m. At distance d from the mouth it draws at
## `pull` / (1 + (d/`pull_d0`)²) m/s, fading over the cone's edge and its
## last quarter. Only with nothing between its mouth and his chest (a
## pillar, a wall, a chest of stone is cover), never while he rides, swims
## or stands on the head itself. It moves him through
## his own motor, as the ram carries him:
##   on the ground  he is slid toward it (PilotMotor.carry, along the walls
##                  the study's PhysicsGround.slide), on top of his own
##                  running: walking away from it near is losing, running
##                  gains slowly, a lip on the way is a lip he goes over.
##                  Crouched he braces (`brace` of the pull). Where the
##                  pull beats `trip_pull` for `trip` s (unbraced) it drags
##                  him off his feet: knocked toward the mouth (`yank`).
##   on a rim       hanging from a lip he holds on while his hands slip:
##                  `grip` s at the `trip_pull` (longer under it) tear him
##                  off toward the mouth; climbing or shimmying out of its
##                  air rests them.
##   in the air     his velocity is drawn toward the mouth at `air_pull`
##                  times the pull a second: a jump near it is a mistake.
##   the sail       the head's air is in `air_at` for the pocket sail's
##                  wind (the study lays it into PilotMotor `air`), and the
##                  plane's (`plane_wind`).
## Its body is a stone (the base's box): he stands on it (it carries him),
## he can't walk through it, it shoves him out moving into him; he can't
## knock it about. No damage anywhere: the gulp's blast is physics.
## Sizes come from the walker's (enemy_field.gd `numbers()`).

const Look = preload("res://scripts/enemies/inhaler_head_look.gd")
const Air = preload("res://scripts/enemies/inhaler_head_air.gd")

signal gulped(enemy)
signal blew(enemy)

## Whether it holds the pilot now (the study hides the figure).
var swallowed := false
var look: Node3D
var air: Node3D
## Where its round goes (world points; their y is ignored).
var route: Array = []
## The drawn air's share now (0..1), and its pull on him this frame (m/s).
var draw_share := 0.0
var pulling := 0.0
## Gulps and blasts, for the HUD and checks.
var gulps := 0
var blasts := 0
var _leg := 0
var _home := Vector3.ZERO
var _ground := 0.0
var _clock := 0.0
var _unseen := 0.0
var _strain := 0.0
var _grip := 0.0
var _tilt := Vector2.ZERO
var _shake := 0.0
var _grind_t := 0.0
var _open := 0.0
var _glow := 0.0
var _low := 0.0
var _ray := PhysicsRayQueryParameters3D.new()
var _blast_way := Vector3.FORWARD
var _turned := 0.0
## Set by its headless body (scripts/enemies/headless_body.gd) as they meet:
## the head is carried to its neck (`head_seat()`, `head_facing()`), its
## drift and its breath stopped, its eyes lit.
var perch: Node3D = null

func _init() -> void:
	cost = 4
	tags = PackedStringArray(["pulls","hovers","loud"])
	tell_sound = &"head_grind"

func default_knobs(n: Dictionary) -> Dictionary:
	return {
		"size":3.0,"hover":n.unit*1.1,"hover_low":n.unit*0.28,"bob":n.unit*0.1,"bob_rate":0.8,"tilt":0.07,"settle":1.4,
		"drift_speed":n.walk*0.45,"drift_accel":0.8,"turn":0.55,"ring":n.unit*6.0,
		"sight":n.unit*13.0,"sight_half":1.1,"lose":1.5,"lock_turn":0.9,"lock_angle":0.18,
		"tell":1.4,"tell_draw":0.2,"inhale":4.5,"track_turn":0.45,
		"reach":n.unit*12.0,"cone":0.5,"cone_near":1.35,
		"pull":n.run*1.3,"pull_d0":n.unit*4.0,"air_pull":2.6,"brace":0.55,
		"trip":0.45,"trip_pull":n.run*0.92,"grip":1.6,"yank":n.run*1.5,"yank_up":n.unit*1.6,
		"gulp_reach":n.unit*1.15,"hold":1.0,
		"blast_out":n.unit*24.0,"blast_up":n.unit*2.4,"blast_down":1.0,"recoil":n.run*0.6,"after":3.0,
		"sail_wind":2.2,"plane_wind":3.0,
	}

## Chin to crown `size` of his heights; as wide as the model, as deep.
func _size(n: Dictionary) -> void:
	height = float(knobs.size)*n.unit
	width = height*1.04
	length = height*0.84

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	super.setup(host,at,face,overrides)
	_home = at
	_ground = at.y
	route = knobs.get("route",[])
	if route.is_empty():
		for i in range(5):
			var a := TAU*i/5.0+facing
			route.append(at+Vector3(sin(a),0.0,cos(a))*float(knobs.ring))
	position.y = _ground+float(knobs.hover)
	grounded = false
	state = "drift"

func _art(root: Node3D) -> void:
	look = Look.new()
	look.name = "Look"
	root.add_child(look)
	look.build(height)
	air = Air.new()
	air.name = "Air"
	add_child(air)
	air.setup(self,float(knobs.reach),float(knobs.cone),DisplayServer.get_name() != "headless")

# --- What the air visuals ask --------------------------------------------------------

func mouth() -> Vector3:
	return look.mouth()

## The way its face looks, flat (unit).
func face_flat() -> Vector3:
	var f := PilotMotor.forward(facing)
	return Vector3(f.x,0.0,f.y)

## The turf's height under it (the last seen, over the void).
func ground_y() -> float:
	return _ground

## The turf's height under `p`, -INF over nothing.
func ground_at(p: Vector3) -> float:
	return field.floor_under(Vector3(p.x,_ground,p.z),6.0,12.0,body.get_rid())

## Where it was set down (its home over the turf): its body
## (scripts/enemies/body_spawner.gd) knows it by this.
func home() -> Vector3:
	return _home

## Off its body's neck and back home drifting its round (the body that had
## it taken away: scripts/enemies/body_spawner.gd).
func go_home() -> void:
	perch = null
	vel = Vector3.ZERO
	_ground = _home.y
	position = _home+Vector3.UP*float(knobs.hover)
	_leg = 0
	_low = 0.0
	_go("drift")
	rotation.y = facing

# --- A frame ---------------------------------------------------------------------------

func think(delta: float) -> void:
	_clock += delta
	state_t += delta
	if perch != null:
		_perched(delta)
		return
	var m: PilotMotor = field.motor
	var chest := _chest(m)
	var sees := _sees(m,chest)
	_unseen = 0.0 if sees else _unseen+delta
	var want_open := 0.0
	var want_glow := 0.0
	var want_draw := 0.0
	_low = move_toward(_low,1.0 if state in ["tell","inhale","gulp","blast"] else 0.0,delta/float(knobs.settle))
	match state:
		"drift":
			_drift(delta)
			if sees: _go("notice")
		"notice":
			_brake(delta)
			_turn_to(chest,float(knobs.lock_turn),delta)
			want_glow = 0.25
			if _unseen > float(knobs.lose): _go("drift")
			elif absf(_aim_off(chest)) < float(knobs.lock_angle):
				_go("tell")
				tell()
				field.sound(&"head_inhale",global_position)
		"tell":
			_brake(delta)
			_turn_to(chest,float(knobs.track_turn),delta)
			var k := clampf(state_t/float(knobs.tell),0.0,1.0)
			want_open = smoothstep(0.0,1.0,k)*0.85
			want_glow = lerpf(0.4,1.0,k)
			want_draw = float(knobs.tell_draw)*k
			_shake = 0.012*k
			if state_t >= float(knobs.tell): _go("inhale")
		"inhale":
			_brake(delta)
			_turn_to(chest,float(knobs.track_turn),delta)
			want_open = 1.0+0.04*sin(_clock*17.0)
			want_glow = 1.0
			want_draw = 1.0
			_shake = 0.01
			if _unseen > float(knobs.lose) or state_t >= float(knobs.inhale): _go("after")
		"gulp":
			_brake(delta)
			want_open = 0.0
			want_glow = 1.0
			_shake = 0.04*(1.0-smoothstep(0.0,float(knobs.hold),state_t))+0.015
			_hold(m)
			if fmod(state_t,0.25) < delta:
				var side := Vector3(-face_flat().z,0.0,face_flat().x)*width*0.55
				var flaps := global_position+Vector3.UP*height*0.45
				air.swallowing(flaps-side,flaps+side,face_flat())
			if state_t >= float(knobs.hold): _blast(m)
		"after":
			_brake(delta)
			var k := clampf(state_t/float(knobs.after),0.0,1.0)
			want_open = 0.0 if state_t > 0.6 else 1.1*(1.0-state_t/0.6)
			want_glow = 1.0-k
			_shake = 0.0
			if state_t >= float(knobs.after):
				_go("drift")
				rest()
	# The jaw and the eyes, heavy: the jaw grinds (snaps shut in a gulp).
	var jaw_rate := 9.0 if state == "gulp" or (state == "after" and state_t < 0.6) else 1.6
	_open = move_toward(_open,want_open,jaw_rate*delta)
	_glow = move_toward(_glow,want_glow,1.5*delta)
	look.open(_open)
	look.glow(_glow)
	draw_share = move_toward(draw_share,want_draw,(3.0 if want_draw > draw_share else 2.0)*delta)
	air.draw(draw_share,delta)
	_pull(m,chest,delta)

## Carried by its body: the jaw shut, no draw, the eyes lit.
func _perched(delta: float) -> void:
	state = "perched"
	vel = Vector3.ZERO
	_shake = 0.0
	_open = move_toward(_open,0.0,1.6*delta)
	_glow = move_toward(_glow,1.0,1.0*delta)
	look.open(_open)
	look.glow(_glow)
	draw_share = 0.0
	pulling = 0.0
	air.draw(0.0,delta)

func _go(to: String) -> void:
	state = to
	state_t = 0.0
	_strain = 0.0

# --- Drifting and turning ---------------------------------------------------------------

func _drift(delta: float) -> void:
	var goal: Vector3 = route[_leg%route.size()]
	var to := Vector2(goal.x-position.x,goal.z-position.z)
	if to.length() < 1.5:
		_leg += 1
		return
	var way := to.normalized()
	# It turns its face into its way, then goes; slowly either way.
	_turn_to(Vector3(goal.x,position.y,goal.z),float(knobs.turn),delta)
	var ahead := PilotMotor.forward(facing)
	var speed := float(knobs.drift_speed)*clampf(ahead.dot(way),0.0,1.0)
	# A stone in the way (a wall it would grind into): on to the next.
	if field.blocked(position+Vector3.UP*height*0.4,Vector3(way.x,0.0,way.y)*(length*0.5+1.0),body.get_rid()):
		_leg += 1
		speed = 0.0
	var want := ahead*speed
	var flat := Vector2(vel.x,vel.z).move_toward(want,float(knobs.drift_accel)*delta)
	vel.x = flat.x
	vel.z = flat.y

func _brake(delta: float) -> void:
	var flat := Vector2(vel.x,vel.z).move_toward(Vector2.ZERO,float(knobs.drift_accel)*1.5*delta)
	vel.x = flat.x
	vel.z = flat.y

## Turns its face toward `p` at `rate` rad/s; dust off its flanks as it grinds.
func _turn_to(p: Vector3, rate: float, delta: float) -> void:
	var to := Vector2(p.x-position.x,p.z-position.z)
	if to.length() < 0.2: return
	var want := PilotMotor.facing_of(to.normalized())
	var step := clampf(angle_difference(facing,want),-rate*delta,rate*delta)
	facing = wrapf(facing+step,-PI,PI)
	_turned = step/maxf(delta,0.0001)
	_grind_t -= delta
	if absf(step) > rate*delta*0.5 and _grind_t <= 0.0 and state != "drift":
		_grind_t = 0.25
		var side := Vector3(-face_flat().z,0.0,face_flat().x)*width*0.5*signf(-step)
		air.grind(global_position+side+Vector3.UP*height*0.3)

## How far off its face `p` is (rad, flat).
func _aim_off(p: Vector3) -> float:
	var to := Vector2(p.x-position.x,p.z-position.z)
	if to.length() < 0.01: return 0.0
	return angle_difference(facing,PilotMotor.facing_of(to.normalized()))

func _move(delta: float) -> void:
	if perch != null:
		position = perch.head_seat()
		facing = perch.head_facing()
		rotation.y = facing
		skin.rotation = perch.head_tilt()
		skin.position = Vector3.ZERO
		return
	position.x += vel.x*delta
	position.z += vel.z*delta
	var g := ground_at(position)
	if g != -INF: _ground = g
	var hover := lerpf(float(knobs.hover),float(knobs.hover_low),smoothstep(0.0,1.0,_low))
	var bob := sin(_clock*TAU*float(knobs.bob_rate)*0.5)*float(knobs.bob)*(1.0-0.7*_low)
	var want_y := _ground+hover+bob
	position.y = lerpf(position.y,want_y,1.0-exp(-2.0*delta))
	rotation.y = facing
	# Leaning into its way, a little into its turn; the shudder on top.
	var ahead := PilotMotor.forward(facing)
	var flat := Vector2(vel.x,vel.z)
	var lean := Vector2(-flat.dot(ahead),Vector2(-ahead.y,ahead.x).dot(flat))*float(knobs.tilt)/maxf(float(knobs.drift_speed),0.1)
	lean.y += clampf(_turned,-1.0,1.0)*0.03
	_tilt = _tilt.lerp(lean,1.0-exp(-1.5*delta))
	var shake := Vector3(sin(_clock*53.0),sin(_clock*41.0+1.3),sin(_clock*47.0+2.1))*_shake
	skin.rotation = Vector3(_tilt.x+sin(_clock*0.9)*0.012+shake.x*0.6,0.0,_tilt.y+sin(_clock*0.7+1.0)*0.015+shake.z*0.6)
	skin.position = Vector3(shake.x,shake.y,shake.z)*height*0.3

# --- Seeing him -------------------------------------------------------------------------

func _chest(m: PilotMotor) -> Vector3:
	return m.feet+Vector3.UP*field.study.ground.head_top*0.55

## Whether it sees him: near enough, inside its sight (wider once it has
## him), nothing between its mouth and his chest.
func _sees(m: PilotMotor, chest: Vector3) -> bool:
	if swallowed: return true
	var mouth_at := mouth()
	if mouth_at.distance_to(chest) > float(knobs.sight): return false
	var half := float(knobs.sight_half)*(1.6 if state in ["notice","tell","inhale"] else 1.0)
	if absf(_aim_off(chest)) > half: return false
	return _clear(mouth_at,chest)

## Nothing stands between `a` and `b` (its own body left out).
func _clear(a: Vector3, b: Vector3) -> bool:
	_ray.from = a
	_ray.to = b
	_ray.collision_mask = field.study.ground.mask
	_ray.exclude = [body.get_rid()]
	return field.study.get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()

# --- The pull ----------------------------------------------------------------------------

## The pull (m/s, toward the mouth) at `p` at a full draw: the cone, the
## reach, the falloff; no cover counted.
func pull_at(p: Vector3) -> float:
	var mouth_at := mouth()
	var off := p-mouth_at
	var d := off.length()
	if d > float(knobs.reach) or d < 0.001: return 0.0
	var half := lerpf(float(knobs.cone_near),float(knobs.cone),smoothstep(0.0,float(knobs.reach)*0.5,d))
	var angle := face_flat().angle_to(off/d)
	var in_cone := 1.0-smoothstep(half*0.7,half,angle)
	var fade := 1.0-smoothstep(float(knobs.reach)*0.75,float(knobs.reach),d)
	var k := d/float(knobs.pull_d0)
	return float(knobs.pull)*in_cone*fade/(1.0+k*k)

## The air it draws at `p` for the sail and the plane: toward the mouth,
## `scale` times the pull there, cover counted.
func air_at(p: Vector3, scale: float) -> Vector3:
	if draw_share <= 0.0 or gone: return Vector3.ZERO
	var s := pull_at(p)*draw_share
	if s <= 0.0 or not _clear(mouth(),p): return Vector3.ZERO
	return (mouth()-p).normalized()*s*scale

func _pull(m: PilotMotor, chest: Vector3, delta: float) -> void:
	pulling = 0.0
	if swallowed or draw_share <= 0.0: return
	if m.rider != null or m.swimming or m.seized(): return
	# Stood on the head itself: out of its air.
	if m.feet.y > position.y+height*0.8: return
	var mouth_at := mouth()
	var to := mouth_at-chest
	var d := to.length()
	if Vector2(Vector2(to.x,to.z).length(),to.y*0.5).length() <= float(knobs.gulp_reach):
		_gulp(m)
		return
	var p := pull_at(chest)*draw_share
	if p <= 0.01 or not _clear(mouth_at,chest):
		_grip = maxf(0.0,_grip-delta)
		return
	if m.on_ledge():
		# Hanging from a rim he holds on, his hands slipping: torn off
		# toward it after `grip` s of the pull at `trip_pull` (longer under
		# it); shimmy out of its air or climb, and they rest.
		pulling = p
		_grip += delta*p/float(knobs.trip_pull)
		if _grip >= float(knobs.grip):
			_grip = 0.0
			m.knock(to/d*float(knobs.yank)+Vector3.UP*sqrt(2.0*m.gravity*float(knobs.yank_up)*0.5),self)
			field.sound(&"head_yank",chest)
		return
	_grip = maxf(0.0,_grip-delta)
	if m.grounded and m.move != "tumble":
		var braced := m.crouch
		if braced: p *= float(knobs.brace)
		pulling = p
		var flat := Vector2(to.x,to.z).normalized()*p*delta
		var dest: Vector3 = field.study.ground.slide(m.feet,flat)
		m.carry(Transform3D(Basis.IDENTITY,Vector3(dest.x-m.feet.x,0.0,dest.z-m.feet.z)),0.0)
		# Too strong to stand in: dragged off his feet.
		if not braced and p >= float(knobs.trip_pull): _strain += delta
		else: _strain = maxf(0.0,_strain-delta)
		if _strain >= float(knobs.trip):
			_strain = 0.0
			var way := to.normalized()
			m.knock(way*float(knobs.yank)+Vector3.UP*sqrt(2.0*m.gravity*float(knobs.yank_up)),self)
			field.sound(&"head_yank",chest)
	else:
		pulling = p
		m.velocity += to/d*p*float(knobs.air_pull)*delta

# --- The gulp and the blast ---------------------------------------------------------

func _gulp(m: PilotMotor) -> void:
	swallowed = true
	gulps += 1
	m.seize()
	_hold(m)
	_go("gulp")
	draw_share = 0.0
	field.sound(&"head_gulp",mouth())
	gulped.emit(self)

## Held in its mouth: his feet just inside the lips.
func _hold(m: PilotMotor) -> void:
	m.feet = mouth()-Vector3.UP*field.study.ground.head_top*0.5-face_flat()*0.3
	m.velocity = Vector3.ZERO

func _blast(m: PilotMotor) -> void:
	swallowed = false
	blasts += 1
	_blast_way = face_flat()
	m.feet = mouth()+_blast_way*(float(knobs.radius)+0.4)-Vector3.UP*field.study.ground.head_top*0.5
	var v := m.knock_velocity(Vector2(_blast_way.x,_blast_way.z),float(knobs.blast_out),float(knobs.blast_up))
	m.knock(v,self,float(knobs.blast_down))
	_open = 1.15
	air.blast(mouth(),_blast_way)
	vel -= _blast_way*float(knobs.recoil)
	_shake = 0.05
	field.sound(&"head_blast",mouth())
	blew.emit(self)
	_go("after")

# --- The base's contact, as a hovering stone -----------------------------------------

## It can't be knocked about, and nothing it does by touch hurts.
func touch(_m: PilotMotor, _v_pre: Vector3) -> void:
	pass

## A rider on its helmet stays on, except in the blast's recoil.
func bucks() -> bool:
	return state == "after" and state_t < 0.4

func push_out(m: PilotMotor, slide: Callable, body_low: float, head: float) -> void:
	if swallowed: return
	super.push_out(m,slide,body_low,head)

## Its sail wind and plane wind (m/s) at `p`.
func sail_wind(p: Vector3) -> Vector3:
	return air_at(p,float(knobs.sail_wind))

func plane_wind(p: Vector3) -> Vector3:
	return air_at(p,float(knobs.plane_wind))
