extends Node3D
## A wind shot (docs/design/rune-knight/spec-rune-knight.md): the ball of
## wind both the rune knight (scripts/enemies/rune_knight.gd) and the
## wanderer throw. One shot, one node, in the group GROUP; anything that
## plays tennis reads a shot through that seam only: its `position`,
## `velocity`, `shooter` (who threw it last), `strength` (the knock's
## share) and `state`, and takes it with `hold` and sends it on with
## `launch`.
##
## - **held**: it sits on a socket (`hold(socket)`), growing to full over
##   GROW s once `grow()` is called: a knight's gather, a catch.
## - **flying**: `launch(velocity, fall)`: on along `velocity`, pulled down
##   `fall` m/s/s (0 straight, a blast; more, a lob). A ray ahead of it
##   pops it on stone or turf; passing within its radius plus the walker's
##   of `target`'s chest (a PilotMotor, not its shooter), it bursts on him:
##   the gust's knock (scripts/traps/gust.gd `knock`) along its way,
##   `strength` times the gust's defaults. Past `flight` m it fades out.
## - **Struck back:** a flying shot met by a newer flying shot of another
##   shooter (the wanderer's blast meeting the knight's return) takes the
##   newer one's way and shooter, MEET_GAIN times the faster of the two,
##   and the newer one is `absorb`ed: one shot goes on, faster. A non-shot
##   in the group (a real blast later) only lends its way and shooter.
## - **Struck:** `strike(at)` bursts it on a body that reads shots itself
##   (the knight's hit test), with no knock of its own.
## - **done**: popped or burst: puffs, then it frees itself.
##
## The look (no hard mesh, as the dragon's air blast, scripts/
## dragon_air_blast.gd, whose lens, streak and puff meshes it borrows): a
## bright shimmer ball, a ring of streaks spun round it (its silhouette from
## afar), a trail of streaks and puffs behind it in flight. `look` false
## builds none of it.
const WorldScale = preload("res://scripts/world_scale.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const Gust = preload("res://scripts/traps/gust.gd")
const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
const DragonCyclone = preload("res://scripts/dragon_cyclone.gd")
const DragonGale = preload("res://scripts/dragon_gale.gd")

const GROUP := "wind_shot"
## The ball's radius in the walker's heights; the fuse past the two radii
## (walker heights); the grow (s); the farthest flight (m).
const BALL := 0.3
const FUSE := 0.15
const GROW := 0.75
const FLIGHT := 70.0
## A struck-back shot's speed over the faster of the two that met.
const MEET_GAIN := 1.15
## Stone (layer 1) and turf (layer 11) pop it.
const MASK := 1 | (1 << 11)
## The look's counts and tint (the knight's rune light in the air).
const RING := 9
const TRAIL := 12
const TRAIL_PUFFS := 8
const FREE_PUFFS := 28
const TINT := Color(0.84,0.94,1.0)

signal burst_on(body: Object)
signal popped(at: Vector3)

var velocity := Vector3.ZERO
var shooter: Object = null
var strength := 1.0
var fall := 0.0
var flight := FLIGHT
## "held", "flying", "done".
var state := "held"
## The body it bursts on: a PilotMotor (the wanderer), never its shooter.
var target: Object = null
var look := true
## How full (0..1): grows while held after `grow()`, 1 in flight.
var grown := 0.0
var age := 0.0
var travelled := 0.0
## Metres flown before stone or turf can pop it (a shot sent off a deck
## clears its lip).
var grace := 0.0
var _growing := false
var _socket: Node3D
var _clock := 0.0
var _done_t := 0.0
var _rng := RandomNumberGenerator.new()
var _knock := {}
var _lens: MultiMeshInstance3D
var _streaks: MultiMeshInstance3D
var _puffs: MultiMeshInstance3D
var _free: Array = []
var _free_next := 0
var _trail: Array[Vector3] = []

static var _lens_mesh: Mesh
static var _streak_mesh: Mesh
static var _puff_mesh: Mesh

func _init() -> void:
	name = "WindShot"
	top_level = true
	_rng.randomize()

func _ready() -> void:
	add_to_group(GROUP)
	_knock = Gust.wanderer_defaults()
	if not look: return
	if _lens_mesh == null:
		_lens_mesh = DragonAirBlast._lens_mesh()
		_streak_mesh = DragonCyclone._streak_mesh()
		_puff_mesh = DragonGale._puff_mesh()
	_lens = _batch("Lens",_lens_mesh,1)
	_streaks = _batch("Streaks",_streak_mesh,RING+TRAIL)
	_puffs = _batch("Puffs",_puff_mesh,TRAIL_PUFFS+FREE_PUFFS)
	for i in range(FREE_PUFFS): _free.append({"life":0.0})

static func walker_tall() -> float:
	return PhysicsGround.HEAD*WorldScale.wanderer

## The ball's radius (m).
static func radius() -> float:
	return BALL*walker_tall()

# --- The seam -----------------------------------------------------------------------

## Held on `socket` (it follows it), not growing till `grow()`.
func hold(socket: Node3D) -> void:
	state = "held"
	_socket = socket
	velocity = Vector3.ZERO
	if socket != null: global_position = socket.global_position

## Start growing to full (GROW s).
func grow() -> void:
	_growing = true

## Sent on along `vel`, pulled down `fall_` m/s/s, `grace_` m flown
## before stone or turf can pop it.
func launch(vel: Vector3, fall_ := 0.0, grace_ := 0.0) -> void:
	state = "flying"
	_socket = null
	velocity = vel
	fall = fall_
	grace = grace_
	grown = 1.0
	travelled = 0.0
	_trail.clear()

## Taken into a shot that met it: gone, quietly.
func absorb() -> void:
	if state != "done": _end(global_position,Vector3.UP,false)

## Burst on a body at `at` (the knight's hit test; no knock here).
func strike(at: Vector3) -> void:
	if state == "done": return
	print("wind shot: struck a body at (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])
	burst_on.emit(null)
	_end(at,-velocity.normalized() if velocity.length() > 0.1 else Vector3.UP,true)

## The way to send it from `from` so that it comes down through `to`,
## `time` s on, pulled down `fall_` m/s/s.
static func lob(from: Vector3, to: Vector3, time: float, fall_: float) -> Vector3:
	var t := maxf(time,0.05)
	var d := to-from
	return Vector3(d.x/t,(d.y+0.5*fall_*t*t)/t,d.z/t)

# --- The frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if delta <= 0.0: return
	_clock += delta
	age += delta
	match state:
		"held":
			if _socket != null and is_instance_valid(_socket): global_position = _socket.global_position
			if _growing: grown = move_toward(grown,1.0,delta/GROW)
		"flying":
			_fly(delta)
		"done":
			_done_t += delta
			if _done_t > 1.2: queue_free()
	if look and is_inside_tree():
		_step_free(delta)
		_draw()

func _fly(delta: float) -> void:
	var from := global_position
	velocity += Vector3.DOWN*fall*delta
	var to := from+velocity*delta
	if _meets_other(from,to,delta):
		to = from+velocity*delta
	if _hits_target(from,to): return
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space != null and travelled >= grace:
		var ray := PhysicsRayQueryParameters3D.new()
		ray.collision_mask = MASK
		ray.from = from
		ray.to = to+velocity.normalized()*radius()
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			_pop(hit.position as Vector3,hit.normal as Vector3)
			return
	global_position = to
	travelled += from.distance_to(to)
	_trail.push_front(to)
	if _trail.size() > 24: _trail.pop_back()
	if travelled >= flight: _end(to,Vector3.UP,false)

## Whether a newer flying shot of another shooter met this one on its
## step: then this one takes that one's way and shooter, faster, and that
## one is absorbed.
func _meets_other(from: Vector3, to: Vector3, delta: float) -> bool:
	if not is_inside_tree(): return false
	var t := walker_tall()
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		if node == self or not node is Node3D: continue
		if node.get("state") != "flying": continue
		var other_shooter = node.get("shooter")
		if other_shooter == shooter: continue
		var other_age = node.get("age")
		if other_age != null and float(other_age) >= age: continue
		var ov: Vector3 = node.get("velocity") if node.get("velocity") != null else Vector3.ZERO
		var op := (node as Node3D).global_position
		var near := _segments_closest(from,to,op-ov*delta,op)
		if near.x > radius()*2.0+FUSE*t*2.0: continue
		var speed := maxf(velocity.length(),ov.length())*MEET_GAIN
		velocity = (ov.normalized() if ov.length() > 0.1 else -velocity.normalized())*speed
		var of = node.get("fall")
		fall = float(of) if of != null else 0.0
		shooter = other_shooter
		target = node.get("target")
		var os = node.get("strength")
		if os != null: strength = maxf(strength,float(os))
		travelled = 0.0
		grace = 0.0
		flight = FLIGHT
		_trail.clear()
		if node.has_method("absorb"): node.call("absorb")
		print("wind shot: struck back at (%.1f, %.1f, %.1f), now %.1f m/s" % [from.x,from.y,from.z,speed])
		if look:
			for i in range(10):
				var d := Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1)).normalized()
				_free_puff(from,d*_rng.randf_range(3.0,6.0),radius()*0.8,radius()*2.2,0.45,TINT,0.6)
		return true
	return false

## Whether its step `from` -> `to` passed the target's chest: then it
## bursts on him (the gust's knock along its way).
func _hits_target(from: Vector3, to: Vector3) -> bool:
	if target == null or target == shooter or not is_instance_valid(target): return false
	var motor = target
	if not Gust.can_take(motor): return false
	var t := walker_tall()
	var feet: Vector3 = motor.feet
	var a := feet+Vector3.UP*0.25*t
	var b := feet+Vector3.UP*0.85*t
	var near := _segments_closest(from,to,a,b)
	var reach := radius()+PhysicsGround.RADIUS*WorldScale.wanderer+FUSE*t
	if near.x > reach: return false
	var way := velocity
	var v := Gust.knock(motor,way,float(_knock.blast_out)*strength,float(_knock.blast_up)*strength,shooter if shooter != null else self)
	print("wind shot: burst on the wanderer at (%.1f, %.1f, %.1f), knock (%.1f, %.1f, %.1f) m/s" % [feet.x,feet.y,feet.z,v.x,v.y,v.z])
	burst_on.emit(motor)
	_end(from.lerp(to,near.y),-velocity.normalized(),true)
	return true

## The nearest approach of segment p0-p1 to q0-q1: (distance, share along p).
static func _segments_closest(p0: Vector3, p1: Vector3, q0: Vector3, q1: Vector3) -> Vector2:
	var pts := Geometry3D.get_closest_points_between_segments(p0,p1,q0,q1)
	var span := p0.distance_to(p1)
	var s := 0.0 if span < 0.0001 else clampf(p0.distance_to(pts[0])/span,0.0,1.0)
	return Vector2((pts[0] as Vector3).distance_to(pts[1]),s)

func _pop(at: Vector3, normal: Vector3) -> void:
	print("wind shot: popped at (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])
	popped.emit(at)
	_end(at+normal*radius()*0.5,normal,true)

func _end(at: Vector3, normal: Vector3, loud: bool) -> void:
	state = "done"
	global_position = at
	_done_t = 0.0
	remove_from_group(GROUP)
	if not look or not is_inside_tree(): return
	var r := radius()
	for i in range(18 if loud else 8):
		var d := (normal*0.5+Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.4,1),_rng.randf_range(-1,1))).normalized()
		var size := _rng.randf_range(0.8,1.3)*r
		_free_puff(at,d*_rng.randf_range(3.0,8.0)*(1.0 if loud else 0.5),size,size*2.6,_rng.randf_range(0.5,0.9),TINT,0.5)

# --- The look -----------------------------------------------------------------------

func _batch(label: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 200.0
	# The batches draw in world space: undo the shot's own move.
	node.top_level = true
	add_child(node)
	node.global_transform = Transform3D.IDENTITY
	return node

func _free_puff(p: Vector3, v: Vector3, size: float, grow_: float, life: float, tint: Color, alpha := 1.0) -> void:
	if _free.is_empty(): return
	_free[_free_next] = {"p":p,"v":v,"size":size,"grow":grow_,"life":life,"age":0.0,"alpha":alpha,"tint":tint}
	_free_next = (_free_next+1)%FREE_PUFFS

func _step_free(delta: float) -> void:
	for s: Dictionary in _free:
		if float(s.life) <= 0.0: continue
		s.age = float(s.age)+delta
		if float(s.age) >= float(s.life):
			s.life = 0.0
			continue
		s.v = (s.v as Vector3)*(1.0-minf(0.95,3.0*delta))
		s.p = (s.p as Vector3)+(s.v as Vector3)*delta

## A streak quad from `mid` along `along` (its length in it), `width` wide,
## turned to face `eye`.
static func _streak(mid: Vector3, along: Vector3, width: float, eye: Vector3) -> Transform3D:
	var way := along.normalized()
	var across := way.cross((eye-mid).normalized())
	if across.length() < 0.01: across = Vector3.UP.cross(way)
	if across.length() < 0.01: across = Vector3.RIGHT
	across = across.normalized()
	return Transform3D(Basis(along,across*width,way.cross(across).normalized()),mid)

func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else global_position+Vector3(0,0,10)
	var lm := _lens.multimesh
	var sm := _streaks.multimesh
	var pm := _puffs.multimesh
	var si := 0
	var pj := 0
	var r := radius()*maxf(grown,0.0)
	var at := global_position
	var live := state != "done" and grown > 0.01
	lm.visible_instance_count = 1 if live else 0
	if live:
		var pulse := 1.0+0.1*sin(_clock*30.0)
		lm.set_instance_transform(0,Transform3D(Basis.from_scale(Vector3.ONE*r*2.8*pulse),at))
		lm.set_instance_custom_data(0,Color(minf(1.0,0.4+grown),1.0,0,0))
		lm.set_instance_color(0,TINT)
		# The ring: streaks spun round the ball, about an axis across its way
		# (or up, held), so it reads as a wheel of wind.
		var way := velocity.normalized() if velocity.length() > 0.1 else Vector3.FORWARD
		var axis := way.cross(Vector3.UP)
		if axis.length() < 0.1: axis = Vector3.RIGHT
		axis = axis.normalized()
		var spin := _clock*(14.0 if state == "flying" else 9.0)
		for i in range(RING):
			var a := spin+float(i)/float(RING)*TAU
			var out := way.rotated(axis,a)
			var tangent := axis.cross(out).normalized()
			var mid := at+out*r*1.25
			sm.set_instance_transform(si,_streak(mid,tangent*r*1.6,r*0.35,eye))
			sm.set_instance_custom_data(si,Color(0.85*grown,0,0,0))
			sm.set_instance_color(si,TINT)
			si += 1
	if live and state == "flying" and _trail.size() > 2:
		var n := mini(TRAIL,_trail.size()-1)
		for i in range(n):
			var u := float(i)/float(TRAIL)
			var p0: Vector3 = _trail[i]
			var p1: Vector3 = _trail[mini(i+2,_trail.size()-1)]
			if p0.distance_to(p1) < 0.01: continue
			var side := Vector3(sin(_clock*9.0+i*1.3),cos(_clock*7.0+i*2.1),sin(_clock*5.0+i))*r*0.5*u
			sm.set_instance_transform(si,_streak((p0+p1)*0.5+side,p0-p1,r*lerpf(0.7,0.2,u),eye))
			sm.set_instance_custom_data(si,Color(lerpf(0.7,0.1,u),0,0,0))
			sm.set_instance_color(si,TINT)
			si += 1
		for i in range(TRAIL_PUFFS):
			var k := mini((i+1)*2,_trail.size()-1)
			var u := float(i+1)/float(TRAIL_PUFFS+1)
			var size := r*lerpf(1.2,2.4,u)
			pm.set_instance_transform(pj,Transform3D(Basis.from_scale(Vector3.ONE*size),_trail[k]))
			pm.set_instance_custom_data(pj,Color(0.3*(1.0-u),0,0,0))
			pm.set_instance_color(pj,TINT)
			pj += 1
	for s: Dictionary in _free:
		if float(s.life) <= 0.0: continue
		var u := float(s.age)/float(s.life)
		var size := lerpf(float(s.size),float(s.grow),1.0-pow(1.0-u,2.0))
		pm.set_instance_transform(pj,Transform3D(Basis.from_scale(Vector3.ONE*size),s.p))
		pm.set_instance_custom_data(pj,Color(smoothstep(0.0,0.1,u)*(1.0-smoothstep(0.3,1.0,u))*float(s.alpha),0,0,0))
		pm.set_instance_color(pj,s.tint)
		pj += 1
	sm.visible_instance_count = si
	pm.visible_instance_count = pj
