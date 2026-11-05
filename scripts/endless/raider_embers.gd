extends RefCounted
## The raider's embers (spec-raider-embers.md item 3): while it runs ahead of
## the plane in the chase (raider_chase.gd phase `run`), the plane behind it
## within RANGE m and it in view, it fires an ember back from its tail every
## EVERY s (`--raider-ember-every=S`): a glowing orange ball EMBER_R m round
## with a short streak behind it, at SPEED m/s (`--raider-ember-speed=M/S`)
## along the world, aimed where the plane will meet it if it holds its line.
## No drop: they float, so they read and the parry's straight-line guess holds.
## They seek a little: past SEEK_M m off the plane each turns onto where it
## will meet the plane at SEEK rad/s (`--raider-ember-seek=`), so a plane
## that weaves after the raider still meets them; inside SEEK_M they fly
## straight, so a late jink or the roll's timing is what answers them.
##
## Through the parry (scripts/endless/parry.gd): the raider is a
## `parry_source` and hands its calls here. A roll timed onto one sends it
## home onto the raider: sparks and a puff of smoke there (`landed`; the
## slow comes in task 3). One that reaches the plane unparried (within its
## half span + EMBER_R, as a ship's ball) knocks it: a shove of SHOVE m/s, the
## nose YAW rad off line, a one-turn wobble, the unbanked chain lost (as a
## ball's hit), the banked meter kept; and the raider pulls away, PULL times
## its pace for PULL_S s. A hot surge roll goes through them unknocked. One
## that meets the ground, or LIFE s old, is gone.

const WorldScale = preload("res://scripts/world_scale.gd")

const EVERY := 2.2
const SPEED := 24.0
## The plane between RANGE.x and RANGE.y m off, behind it (its tail toward the
## plane within RANGE_COS), it fires; the first FIRST_S s after it starts to
## run, it doesn't.
const RANGE := Vector2(35.0,300.0)
const RANGE_COS := 0.3
const FIRST_S := 1.5
const MOST := 6
const LIFE := 7.0
const EMBER_R := 1.8
## The soft halo round it (x r across), so it reads far off and down the line.
const HALO := 5.0
const SEEK := 0.6
## Each leaves the tail OFF rad off its line to the plane (up and out to one
## side, the sides in turn), so it bows in from beside the raider and isn't
## hidden behind the plane down the view's line; the seek brings it round.
const OFF := 0.45
const SEEK_M := 35.0
## The streak: its length (m) behind the ball, its width at the ball (x r).
const TRAIL_M := 7.0
const TRAIL_W := 0.7
## The tail: how far back off its middle (x SIZE x the plane's scale).
const TAIL := 1.6
## A hit on the plane.
const KEEP := 0.85
const SHOVE := 11.0
const YAW := 0.25
const WOBBLE := Vector2(1.0,0.7)
const FEEL := Vector2(0.035,10.0)
## The raider pulls away after a hit: times its pace, for s.
const PULL := 1.25
const PULL_S := 2.5
## A parried one lands within this of its middle (x SIZE x the plane's scale).
const BODY := 2.4

var raider: Node3D
var embers: Array[Dictionary] = []
var tuning := {}
var stats := {"fired":0,"hits":0,"passed":0,"home":0,"ground":0}
var pull_t := 0.0

var _wait := FIRST_S
var _side := 1.0
var _pool: Array[Node3D] = []
var _ball_mat: StandardMaterial3D
var _trail_mat: StandardMaterial3D
var _ball_mesh: SphereMesh
var _trail_mesh: CylinderMesh
var _halo_mesh: QuadMesh
var _halo_mat: StandardMaterial3D
var _root: Node3D
## The raider's SIZE (raider.gd).
var _size := 1.0

func _init(r: Node3D) -> void:
	raider = r
	_size = float(r.get_script().get_script_constant_map().get("SIZE",1.0))
	tuning = {"every":maxf(r._flag("--raider-ember-every",EVERY),0.2),"speed":maxf(r._flag("--raider-ember-speed",SPEED),2.0),
		"seek":r._flag("--raider-ember-seek",SEEK)}
	_root = Node3D.new()
	_root.name = "Embers"
	_root.top_level = true
	r.add_child(_root)
	_ball_mat = StandardMaterial3D.new()
	_ball_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ball_mat.albedo_color = Color(1.0,0.55,0.12)
	_ball_mat.emission_enabled = true
	_ball_mat.emission = Color(1.0,0.45,0.08)
	_ball_mat.emission_energy_multiplier = 3.0
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_mat.albedo_color = Color(1.0,0.4,0.08,0.75)
	_ball_mesh = SphereMesh.new()
	_ball_mesh.radius = EMBER_R
	_ball_mesh.height = EMBER_R*2.0
	_ball_mesh.radial_segments = 12
	_ball_mesh.rings = 6
	_trail_mesh = CylinderMesh.new()
	_trail_mesh.top_radius = EMBER_R*TRAIL_W
	_trail_mesh.bottom_radius = 0.05
	_trail_mesh.height = TRAIL_M
	_trail_mesh.radial_segments = 8
	_trail_mesh.rings = 1
	_trail_mesh.cap_top = false
	_trail_mesh.cap_bottom = false
	var g := Gradient.new()
	g.set_color(0,Color(1.0,0.6,0.2,0.8))
	g.set_color(1,Color(1.0,0.35,0.05,0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(0.5,0.0)
	tex.width = 64
	tex.height = 64
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_mat.albedo_texture = tex
	_halo_mesh = QuadMesh.new()
	_halo_mesh.size = Vector2.ONE*EMBER_R*HALO

## Its pace now: PULL while pulling away after a hit, else 1.
func pace_k() -> float:
	return PULL if pull_t > 0.0 else 1.0

## One frame: fire when it may, the embers flown, a hit settled into `events`.
## `was`/`p`: the plane's position last frame and now.
func step(delta: float, was: Vector3, p: Vector3, events: Dictionary) -> void:
	pull_t = maxf(pull_t-delta,0.0)
	var game: Node3D = raider.game
	var flying: bool = game.hand_landing.flying()
	if raider.state == &"flee" and raider.chase.phase == &"run" and flying:
		_wait -= delta
		if _wait <= 0.0 and _may_fire(p):
			_fire(p)
			_wait = float(tuning.every)
	else:
		_wait = maxf(_wait,FIRST_S)
	_fly(delta,was,p,events,flying)

## Off: every one in the air gone (a leave, a kill).
func clear() -> void:
	for e: Dictionary in embers: _drop(e.node)
	embers.clear()
	_wait = FIRST_S
	pull_t = 0.0

func _may_fire(p: Vector3) -> bool:
	if embers.size() >= MOST or not raider._in_view(): return false
	var f = raider.flight
	var to: Vector3 = p-f.position
	var d := to.length()
	if d < RANGE.x or d > RANGE.y: return false
	return (-f.forward()).dot(to/d) >= RANGE_COS

func _tail() -> Vector3:
	var f = raider.flight
	return f.position-f.forward()*TAIL*_size*WorldScale.plane

## Where to: the plane met on its line at SPEED, else straight at it.
func _fire(p: Vector3) -> void:
	var game: Node3D = raider.game
	var from := _tail()
	var shot := _lead(from,p)
	var right := shot.cross(Vector3.UP).normalized()
	if right.is_normalized():
		_side = -_side
		var up := right.cross(shot).normalized()
		shot = shot.rotated((up*_side*0.8+right*0.6).normalized(),OFF)
	var node := _ember()
	node.position = from
	_face(node,shot)
	node.visible = true
	embers.append({"node":node,"at":from,"v":shot,"age":0.0,"least":INF,"near":from,"done":false,"parry":true,"r":EMBER_R})
	stats.fired = int(stats.fired)+1
	var d := from.distance_to(p)
	game.sound.shot("thump",0.5/(1.0+d/120.0),1.6,from)

## The velocity from `from` that meets the plane (at `p`, holding its way)
## at SPEED, else straight at it.
func _lead(from: Vector3, p: Vector3) -> Vector3:
	var s := float(tuning.speed)
	var to: Vector3 = p-from
	var v: Vector3 = raider.game.plane.velocity
	var a := v.length_squared()-s*s
	var b := 2.0*to.dot(v)
	var c := to.length_squared()
	var root := b*b-4.0*a*c
	if root >= 0.0 and absf(a) > 0.01:
		var t1 := (-b-sqrt(root))/(2.0*a)
		var t2 := (-b+sqrt(root))/(2.0*a)
		var t := t1 if t1 > 0.0 else t2
		if t > 0.0 and t < LIFE: return (to+v*t)/t
	return to.normalized()*s

func _fly(delta: float, was: Vector3, p: Vector3, events: Dictionary, flying: bool) -> void:
	var game: Node3D = raider.game
	var reach := WorldScale.span*0.5+EMBER_R
	var hot: bool = game.smash != null and bool(game.smash.hot)
	var plane_ok := was != Vector3.INF
	for i in range(embers.size()-1,-1,-1):
		var e: Dictionary = embers[i]
		var a: Vector3 = e.at
		var v: Vector3 = e.v
		if flying and not bool(e.done) and a.distance_to(p) > SEEK_M and float(tuning.seek) > 0.0:
			var want := _lead(a,p)
			var ang := v.angle_to(want)
			if ang > 0.0001:
				var axis := v.cross(want).normalized()
				if axis.is_normalized(): v = v.rotated(axis,minf(ang,float(tuning.seek)*delta))
			e.v = v
			_face(e.node,v)
		var n: Vector3 = a+v*delta
		e.at = n
		e.age = float(e.age)+delta
		(e.node as Node3D).position = n
		if flying and plane_ok and not bool(e.done):
			var r0 := a-was
			var r1 := n-p
			var k := clampf(-r0.dot(r1-r0)/maxf((r1-r0).length_squared(),0.0001),0.0,1.0)
			var gap := r0.lerp(r1,k).length()
			if gap < float(e.least):
				e.least = gap
				e.near = was.lerp(p,k)
			if float(e.least) <= reach:
				e.done = true
				if not hot: _struck(e,events)
				_drop(e.node)
				embers.remove_at(i)
				continue
			elif float(e.least) < reach+12.0 and gap > float(e.least)+6.0:
				e.done = true
				stats.passed = int(stats.passed)+1
				game.sound.shot("whoosh",0.5,1.5,e.near)
		var ground := maxf(float(game.field.height(n.x,n.z)),float(game.water_at(n)))
		if n.y <= ground or float(e.age) > LIFE:
			if n.y <= ground:
				stats.ground = int(stats.ground)+1
				game.debris.burst("sparks",Vector3(n.x,ground,n.z),Vector3.UP)
			_drop(e.node)
			embers.remove_at(i)

## Ember `e` reached the plane: knocked, no damage; the raider pulls away.
func _struck(e: Dictionary, events: Dictionary) -> void:
	stats.hits = int(stats.hits)+1
	var game: Node3D = raider.game
	var plane = game.plane
	var v: Vector3 = e.v
	var flat := Vector3(v.x,0.0,v.z)
	flat = flat.normalized() if flat.length() > 0.1 else Vector3.ZERO
	var fwd: Vector3 = plane.forward()
	# Its side from the plane's middle: an ember on the right shoves it left.
	var off: Vector3 = (e.near as Vector3)-(plane.position as Vector3)
	var right := fwd.cross(Vector3.UP).normalized()
	var side := -1.0 if off.dot(right) >= 0.0 else 1.0
	var speed_was := float(plane.speed)
	plane.knock(KEEP,flat*SHOVE*0.5+right*side*SHOVE+Vector3.UP*2.0,YAW*-side)
	plane.surge_roll(side,WOBBLE.x,WOBBLE.y)
	var lost: float = game.near.lose()
	if lost > 0.0: events["lost"] = {"points":lost}
	events["scrape"] = {"at":e.near,"normal":-v.normalized(),"what":"stone","into":SHOVE,"angle":0.5,"speed":speed_was,"keep":KEEP}
	game.debris.burst("sparks",e.near,-v.normalized(),true)
	game.feel_hit(FEEL.x,FEEL.y)
	game.sound.shot("crash",0.9,1.1)
	pull_t = PULL_S

# --- The parry's calls (raider.gd hands them on) -------------------------------

func take(e: Dictionary) -> void:
	embers.erase(e)

## Home: where it'll be a beat on, so the ball turns onto it in time.
func aim() -> Vector3:
	var f = raider.flight
	return f.position+f.velocity*0.08

func inside(q: Vector3) -> bool:
	if not raider.alive(): return false
	return q.distance_to(raider.flight.position) < BODY*_size*WorldScale.plane

func moved(e: Dictionary, _a: Vector3, _n: Vector3) -> void:
	_face(e.node,e.v)

## A parried ember's end: on it, a burst of sparks and a puff of smoke.
func landed(e: Dictionary, at: Vector3, hit: bool) -> void:
	_drop(e.node)
	if not hit: return
	stats.home = int(stats.home)+1
	var game: Node3D = raider.game
	var back: Vector3 = -(raider.flight.forward() as Vector3)
	game.debris.burst("sparks",at,back,true)
	game.debris.burst("dust",at,Vector3.UP+back*0.5,true)
	var d := at.distance_to(game.plane.position)
	game.sound.shot("crash",1.2/(1.0+d/150.0),1.0,at)
	game.sound.shot("thump",1.0/(1.0+d/150.0),0.8,at)
	raider.ember_home(at)

# --- The look -----------------------------------------------------------------

func _ember() -> Node3D:
	if not _pool.is_empty(): return _pool.pop_back()
	var n := Node3D.new()
	_root.add_child(n)
	var ball := MeshInstance3D.new()
	ball.mesh = _ball_mesh
	ball.material_override = _ball_mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ball)
	var trail := MeshInstance3D.new()
	trail.mesh = _trail_mesh
	trail.material_override = _trail_mat
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The cylinder's +Y laid along +Z (behind the ball as it faces -Z), its
	# wide end at the ball.
	trail.basis = Basis(Vector3.RIGHT,-PI*0.5)
	trail.position = Vector3(0.0,0.0,TRAIL_M*0.5)
	n.add_child(trail)
	var halo := MeshInstance3D.new()
	halo.mesh = _halo_mesh
	halo.material_override = _halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(halo)
	return n

func _face(node: Node3D, v: Vector3) -> void:
	if v.length() < 0.5: return
	var w := v.normalized()
	node.basis = Basis.looking_at(w,Vector3.UP if absf(w.y) < 0.99 else Vector3.RIGHT)

func _drop(node: Node3D) -> void:
	node.visible = false
	if not _pool.has(node): _pool.append(node)
