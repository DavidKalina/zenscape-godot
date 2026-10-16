extends Node3D
## The gust shot (docs/design/lock-on/spec-lock-on.md): on foot, X with the
## updraft charge at least its release threshold spends it all and throws a
## ball of air from his chest. Locked on (scripts/lock_on/foot_lock.gd) it
## homes on the target and bursts on it (`hit(at, way, strength)`); free, it
## flies level along the camera's flat heading. The ball's flight, homing
## and burst are the dragon's air blast (scripts/dragon_air_blast.gd, built
## with `look` false: none of its shimmer, puffs or haze); no one ever asks
## it for a knock, so it never throws him (or the plane). Its look is its
## own, a focused blast: a tight bright core stretched along its flight, a
## crisp tapered streak of its real path behind it, no puffs; a snap of a
## ring at his chest as it leaves; at the hit a quick flash, a thin ring of
## air thrown out and a few short spokes, gone in a fifth of a second (the
## stone puffs its own dust).
##
## Tennis (the rune knight, docs/design/rune-knight/spec-rune-knight.md):
## each live ball shows itself to whoever plays tennis as a Seam, a node in
## the "wind_shot" group (scripts/enemies/wind_shot.gd's seam: position,
## velocity, shooter, strength, state, age, fall), with `absorb()` (taken
## by a catch or a shot it met: gone quietly) and `strike(at)` (burst on a
## body that reads shots itself: no `hit` call). Its `rally_speed`,
## RALLY_PACE, is the pace a rally counts it at (the stand-in blast's), not
## its 38 m/s. A locked ball whose straight line to its target is blocked
## by stone (a knight on a deck seen from below its buttresses) homes on a
## point over what blocks it till the line is clear (`_steer`), so it comes
## in over the lip rather than into it.

const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
const TargetStone = preload("res://scripts/lock_on/target_stone.gd")

## The ball's pace (m/s; the dragon's is 110, too quick to follow at this
## range), how far a free one flies (m) and how hard a locked one turns
## onto its target (rad/s): enough to meet it from a run or a jump.
const SPEED := 38.0
const FLIGHT := 70.0
const HOMING := 5.0
## Leaves from his chest (walker heights over his feet), this far out (m).
const CHEST := 0.6
const OUT := 0.7
## A ball passing this near (m, past its own radius) the target's middle
## bursts on it; a burst within HIT_NEAR (m) of a target lands on it.
const FUSE := 0.45
const HIT_NEAR := 1.6
## The hit's strength at charge MIN_RELEASE .. full.
const STRENGTH := Vector2(0.6,1.0)
## The look: the tint (pale air; the hit's a touch warm), the core's half
## size (ball radii) and its stretch along the flight, the streak's length
## (m) and half width at the head (ball radii), the snaps' lives (s).
const TINT := Color(0.86,0.94,1.0)
const SNAP_TINT := Color(1.0,0.97,0.9)
const CORE := 0.3
const STRETCH := 2.2
const TRAIL := 4.5
const TRAIL_WIDE := 0.3
const RING_LIFE := 0.22
const FLASH_LIFE := 0.08
const SPOKE_LIFE := 0.16
const SPOKES := 9
const MUZZLE_LIFE := 0.14
## Tennis: the pace a rally counts a ball at (m/s); the most a blocked
## locked ball's way is lifted over what blocks it (m) and the lift's steps.
const RALLY_PACE := 16.0
const LIFT_MOST := 12.0
const LIFT_STEPS := 8
## The straight line counts as clear only with this much room under its
## start (m): the ball's turn onto it lags, so it cuts a little low.
const LIFT_MARGIN := 1.2
const SeamGroup := "wind_shot"

## A live ball as the tennis seam sees it (see the header).
class Seam extends Node3D:
	var shot: Node
	var ball: Dictionary
	var velocity := Vector3.ZERO
	var shooter: Object = null
	var strength := 1.0
	var state := "flying"
	var age := 0.0
	var fall := 0.0
	var target: Object = null
	var rally_speed := 16.0
	func _init() -> void:
		name = "GustSeam"
		top_level = true
	func absorb() -> void:
		if shot != null and is_instance_valid(shot): shot.call("_seam_gone",ball,Vector3.INF)
	func strike(at: Vector3) -> void:
		if shot != null and is_instance_valid(shot): shot.call("_seam_gone",ball,at)

var blast: DragonAirBlast
## Counts and the last shot, for checks: shots fired, hits landed on a
## target, the last shot's charge spent and whether it was locked.
var shots := 0
var hits := 0
var last_charge := 0.0
var last_locked := false
var _strength := 1.0
var _from := Vector3.ZERO
var _target: Node3D = null
## The look: one ImmediateMesh redrawn each frame (world space); the
## streak's path (newest first) and its fade once the ball is gone; the
## snaps alive, each {at, way, age, kind, spin}.
var _mesh: ImmediateMesh
var _draw_node: MeshInstance3D
var _material: ShaderMaterial
var _path: Array[Vector3] = []
var _path_fade := 0.0
var _snaps: Array = []
var _rng := RandomNumberGenerator.new()
## Tennis: the seams (one per live ball) and a strike under way (its burst
## calls no `hit`).
var _seams: Array = []
## Off: a locked ball flies its straight line into whatever blocks it, as
## before `_steer`.
var steer := true
var _struck := false
var _verts := 0

func _init() -> void:
	name = "GustShot"

func _ready() -> void:
	blast = DragonAirBlast.new()
	blast.name = "GustBall"
	blast.on = false
	blast.look = false
	blast.speed = SPEED
	blast.flight = FLIGHT
	add_child(blast)
	blast.landed.connect(_landed)
	blast.broke.connect(_landed)
	_rng.seed = 7
	_mesh = ImmediateMesh.new()
	_material = ShaderMaterial.new()
	_material.shader = _shader()
	_draw_node = MeshInstance3D.new()
	_draw_node.name = "GustLook"
	_draw_node.top_level = true
	_draw_node.mesh = _mesh
	_draw_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_draw_node.extra_cull_margin = 2000.0
	add_child(_draw_node)

## Fires from his `feet` (facing `heading`, flat) at `target` (null: along
## `heading`), with `charge` spent.
func fire(feet: Vector3, heading: Vector3, target: Node3D, charge: float) -> void:
	var flat := Vector3(heading.x,0.0,heading.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var from := feet+Vector3.UP*CHEST*DragonAirBlast.walker_tall()+flat*OUT
	var aim: Vector3 = target.call("aim_point") if target != null else from+flat*FLIGHT
	_target = target
	_from = from
	_strength = lerpf(STRENGTH.x,STRENGTH.y,inverse_lerp(0.15,1.0,clampf(charge,0.15,1.0)))
	shots += 1
	last_charge = charge
	last_locked = target != null
	blast.homing = HOMING if target != null else 0.0
	if target != null and is_inside_tree(): aim = _steer(from,aim,get_world_3d().direct_space_state)
	blast.fire(from,aim)
	_path = [from]
	_path_fade = 1.0
	_snaps.append({"at":from,"way":flat,"age":0.0,"kind":"muzzle","spin":0.0})
	print("gust shot: charge %.2f, %s" % [charge,"at %s" % target.name if target != null else "free"])

## A frame: flies the balls; a locked ball bursts on its target's middle.
## `mouth` is where he shoots from now (the ball's carry out of his chest).
func step(delta: float, feet: Vector3, space: PhysicsDirectSpaceState3D) -> void:
	var aim := Vector3.INF
	if _target != null and is_instance_valid(_target) and not blast.balls.is_empty():
		aim = _target.call("aim_point")
		blast._catch(aim,DragonAirBlast.ball_radius()+FUSE)
		if not blast.balls.is_empty():
			var b: Dictionary = blast.balls[0]
			var real := aim
			aim = _steer(b.pos,aim,space)
			# Steering over a lip it may pass its waypoint: it homes on while
			# the target is still ahead of it.
			if aim != real and (b.vel as Vector3).dot(real-(b.pos as Vector3)) > 0.0: b.homing = true
	var mouth := feet+Vector3.UP*CHEST*DragonAirBlast.walker_tall()
	blast.advance(delta,space,false,mouth,aim)
	_sync_seams()
	_look(delta)

## Where a locked ball at `from` homes: `aim`, or, when stone stands
## between, a point over what stands there (LIFT_MARGIN, then up in steps
## to LIFT_MOST) with clear lines from the ball and on to `aim`: it goes
## over the lip and comes down onto him.
func _steer(from: Vector3, aim: Vector3, space: PhysicsDirectSpaceState3D) -> Vector3:
	if not steer or space == null or _clear(from+Vector3.DOWN*LIFT_MARGIN,aim,space): return aim
	var ray := PhysicsRayQueryParameters3D.create(from,aim,DragonAirBlast.SOLID)
	var hit := space.intersect_ray(ray)
	if hit.is_empty(): return aim
	var over: Vector3 = hit.position
	for i in range(LIFT_STEPS+1):
		var wp := over+Vector3.UP*(LIFT_MARGIN+(LIFT_MOST-LIFT_MARGIN)*float(i)/float(LIFT_STEPS))
		if _clear(from,wp,space,false) and _clear(wp,aim,space): return wp
	return aim

## Whether nothing of stone stands between `from` and `to` (the target's
## own stone, or with `at_target` a hit at `to`, its middle, counts as
## clear).
func _clear(from: Vector3, to: Vector3, space: PhysicsDirectSpaceState3D, at_target := true) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from,to,DragonAirBlast.SOLID)
	var hit := space.intersect_ray(ray)
	if hit.is_empty(): return true
	var body := hit.collider as Node
	if body != null and _target != null and is_instance_valid(_target) and (body == _target or _target.is_ancestor_of(body)): return true
	return at_target and (hit.position as Vector3).distance_to(to) < 0.6

# --- Tennis -------------------------------------------------------------------------------

## One seam per live ball, kept on it.
func _sync_seams() -> void:
	for seam: Seam in _seams.duplicate():
		if not blast.balls.has(seam.ball):
			_seams.erase(seam)
			seam.queue_free()
	for b: Dictionary in blast.balls:
		var seam: Seam = null
		for s: Seam in _seams:
			if is_same(s.ball,b): seam = s
		if seam == null:
			seam = Seam.new()
			seam.shot = self
			seam.ball = b
			var who = get_parent().get("motor") if get_parent() != null else null
			seam.shooter = who if who != null else self
			seam.strength = _strength
			seam.rally_speed = RALLY_PACE
			add_child(seam)
			seam.add_to_group(SeamGroup)
			_seams.append(seam)
		seam.global_position = b.pos
		seam.velocity = b.vel
		seam.age = float(b.age)

## A seam's ball taken (`at` INF: quietly, else burst there with no hit).
func _seam_gone(b: Dictionary, at: Vector3) -> void:
	if not blast.balls.has(b): return
	if at == Vector3.INF:
		blast.balls.erase(b)
		if _path.is_empty() or _path[0].distance_to(b.pos) > 0.01: _path.push_front(b.pos)
	else:
		_struck = true
		blast.burst(b,at)
		_struck = false
	_sync_seams()

func flying() -> bool:
	return blast != null and not blast.balls.is_empty()

func _landed(at: Vector3) -> void:
	var way := at-_from
	if _path.is_empty() or _path[0].distance_to(at) > 0.01: _path.push_front(at)
	_snaps.append({"at":at,"way":way.normalized() if way.length() > 0.01 else Vector3.FORWARD,"age":0.0,"kind":"hit","spin":_rng.randf()*TAU})
	if _struck: return
	for t: Node in get_tree().get_nodes_in_group(TargetStone.GROUP):
		var n := t as Node3D
		if n == null or not n.has_method("hit"): continue
		var mid: Vector3 = n.call("aim_point")
		if mid.distance_to(at) > HIT_NEAR: continue
		n.call("hit",at,way,_strength)
		hits += 1
		print("gust shot: hit %s %.2f m from its middle" % [n.name,mid.distance_to(at)])
		return

# --- The look ---------------------------------------------------------------------------

## Ages the streak and the snaps and draws them all.
func _look(delta: float) -> void:
	if _mesh == null: return
	var ball: Dictionary = {} if blast.balls.is_empty() else blast.balls[0]
	if not ball.is_empty():
		var at: Vector3 = ball.pos
		if _path.is_empty() or _path[0].distance_to(at) > 0.05: _path.push_front(at)
		_path_fade = 1.0
	else:
		# Gone: the streak snaps shut behind it, fast.
		_path_fade = maxf(0.0,_path_fade-delta/0.07)
		if _path_fade <= 0.0: _path.clear()
	# Only the last TRAIL m of the path.
	var long := 0.0
	for i in range(1,_path.size()):
		long += _path[i].distance_to(_path[i-1])
		if long > TRAIL:
			_path.resize(i+1)
			break
	for s: Dictionary in _snaps.duplicate():
		s.age = float(s.age)+delta
		if float(s.age) > maxf(RING_LIFE,SPOKE_LIFE): _snaps.erase(s)
	_mesh.clear_surfaces()
	if ball.is_empty() and _path.size() < 2 and _snaps.is_empty(): return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null: return
	var eye := cam.global_position
	var r := DragonAirBlast.ball_radius()
	_verts = 0
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,_material)
	_strip(eye,_path,r*TRAIL_WIDE,TINT,0.8*_path_fade)
	_strip(eye,_path,r*TRAIL_WIDE*0.4,Color(1,1,1),0.95*_path_fade)
	if not ball.is_empty():
		var at: Vector3 = ball.pos
		var way := (ball.vel as Vector3).normalized()
		var grown := smoothstep(0.0,0.06,float(ball.age))
		var fade := grown*(1.0-smoothstep(FLIGHT*0.85,FLIGHT,float(ball.travelled)))
		var pulse := 1.0+0.06*sin(float(ball.age)*55.0)
		var size := r*CORE*lerpf(0.5,1.0,grown)*pulse
		# A faint tight halo, then the dense core, both stretched along it.
		_round(eye,at,way,size*1.35,STRETCH*1.05,0.0,TINT,0.15*fade)
		_round(eye,at,way,size,STRETCH,0.0,TINT,fade)
	for s: Dictionary in _snaps: _snap(eye,s,r)
	# (A ball taken quietly, a catch, may leave nothing to draw this frame.)
	if _verts == 0:
		for i in range(3): _vert(eye,Vector2.ZERO,Vector2.ZERO,Color(1,1,1,0))
	_mesh.surface_end()

## A muzzle ring, or a hit: a flash, a ring and spokes, eased out fast.
func _snap(eye: Vector3, s: Dictionary, r: float) -> void:
	var t := float(s.age)
	var at: Vector3 = s.at
	if s.kind == "muzzle":
		var um := t/MUZZLE_LIFE
		if um >= 1.0: return
		var em := 1.0-pow(1.0-um,3.0)
		_round(eye,at,Vector3.ZERO,r*lerpf(0.25,0.9,em),1.0,lerpf(0.55,0.86,um),TINT,(1.0-um)*0.85)
		return
	var ur := t/RING_LIFE
	if ur < 1.0:
		var e := 1.0-pow(1.0-ur,3.0)
		_round(eye,at,Vector3.ZERO,r*lerpf(0.6,3.0,e),1.0,lerpf(0.6,0.9,ur),SNAP_TINT,pow(1.0-ur,1.5))
	var uf := t/FLASH_LIFE
	if uf < 1.0:
		_round(eye,at,Vector3.ZERO,r*lerpf(0.9,0.4,uf),1.0,0.0,Color(1,1,1),1.0-uf*uf)
	var us := t/SPOKE_LIFE
	if us < 1.0:
		var e := 1.0-pow(1.0-us,2.0)
		var view := (eye-at).normalized()
		var side := view.cross(Vector3.UP if absf(view.y) < 0.95 else Vector3.RIGHT).normalized()
		var up := side.cross(view).normalized()
		for i in range(SPOKES):
			var a := float(s.spin)+TAU*float(i)/float(SPOKES)+0.25*sin(float(i)*5.1)
			var d := side*cos(a)+up*sin(a)
			var reach := 1.0+0.3*sin(float(i)*3.7)
			var tip := at+d*r*lerpf(0.7,3.4,e)*reach
			var tail := at+d*r*lerpf(0.4,2.4,e)*reach
			_strip(eye,[tip,tail],r*0.12*(1.0-us),SNAP_TINT,0.9*(1.0-us))

## A camera-facing ribbon through `pts` (head first), `wide` m each side
## at the head, tapering to nothing and fading to the tail. UV.x along,
## UV.y across; UV2.y 0 marks a strip for the shader.
func _strip(eye: Vector3, pts: Array, wide: float, col: Color, alpha: float) -> void:
	if pts.size() < 2 or alpha <= 0.0: return
	var total := 0.0
	for i in range(1,pts.size()): total += (pts[i] as Vector3).distance_to(pts[i-1])
	if total < 0.01: return
	var run := 0.0
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_u := 0.0
	for i in range(pts.size()):
		var p: Vector3 = pts[i]
		if i > 0: run += p.distance_to(pts[i-1])
		var u := run/total
		var along: Vector3 = (pts[maxi(i-1,0)] as Vector3)-(pts[mini(i+1,pts.size()-1)] as Vector3)
		var across := along.cross(eye-p)
		across = across.normalized() if across.length() > 0.0001 else Vector3.UP
		var w := wide*(1.0-u)*(0.6+0.4*(1.0-u))
		var l := p+across*w
		var rr := p-across*w
		if i > 0:
			var c0 := Color(col.r,col.g,col.b,alpha*pow(1.0-prev_u,1.4))
			var c1 := Color(col.r,col.g,col.b,alpha*pow(1.0-u,1.4))
			_vert(prev_l,Vector2(prev_u,0),Vector2.ZERO,c0)
			_vert(prev_r,Vector2(prev_u,1),Vector2.ZERO,c0)
			_vert(rr,Vector2(u,1),Vector2.ZERO,c1)
			_vert(prev_l,Vector2(prev_u,0),Vector2.ZERO,c0)
			_vert(rr,Vector2(u,1),Vector2.ZERO,c1)
			_vert(l,Vector2(u,0),Vector2.ZERO,c1)
		prev_l = l
		prev_r = rr
		prev_u = u

## A camera-facing round at `at`, `size` m to its rim, stretched `stretch`
## along `way` as the screen sees it; `inner` > 0 a ring with that inner
## share, 0 a filled disc with a white-hot middle.
func _round(eye: Vector3, at: Vector3, way: Vector3, size: float, stretch: float, inner: float, col: Color, alpha: float) -> void:
	if alpha <= 0.0 or size <= 0.0: return
	var view := (eye-at).normalized()
	var along := way-view*way.dot(view)
	if along.length() < 0.05:
		along = view.cross(Vector3.RIGHT if absf(view.x) < 0.9 else Vector3.UP)
		stretch = 1.0
	along = along.normalized()
	var across := along.cross(view).normalized()
	var a := along*size*stretch
	var b := across*size
	var c := Color(col.r,col.g,col.b,clampf(alpha,0.0,1.0))
	var k := Vector2(inner,1.0)
	_vert(at-a-b,Vector2(0,0),k,c)
	_vert(at+a-b,Vector2(1,0),k,c)
	_vert(at+a+b,Vector2(1,1),k,c)
	_vert(at-a-b,Vector2(0,0),k,c)
	_vert(at+a+b,Vector2(1,1),k,c)
	_vert(at-a+b,Vector2(0,1),k,c)

func _vert(p: Vector3, uv: Vector2, uv2: Vector2, c: Color) -> void:
	_verts += 1
	_mesh.surface_set_color(c)
	_mesh.surface_set_uv(uv)
	_mesh.surface_set_uv2(uv2)
	_mesh.surface_add_vertex(p)

## Strips: a crisp edge, a hotter middle line, faint brush streaks along.
## Rounds: a dense disc (white at its heart) or a thin ring, the edges
## wobbling a touch so they read painted rather than cut.
static func _shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	vec3 col = COLOR.rgb;
	float a;
	if (UV2.y < 0.5) {
		float d = abs(c.y);
		a = 1.0 - smoothstep(0.45, 1.0, d);
		col = mix(col, vec3(1.0), (1.0 - smoothstep(0.0, 0.35, d)) * 0.5);
		a *= 0.85 + 0.15 * sin(UV.x * 40.0 + c.y * 6.0 - TIME * 30.0);
	} else {
		float r = length(c);
		float ang = atan(c.y, c.x);
		float wob = 0.035 * sin(ang * 5.0 + TIME * 23.0) + 0.02 * sin(ang * 11.0 - TIME * 31.0);
		a = 1.0 - smoothstep(0.9 + wob, 1.0 + wob, r);
		if (UV2.x > 0.0) {
			a *= smoothstep(UV2.x - 0.06 + wob, UV2.x + wob, r);
		} else {
			col = mix(col, vec3(1.0), 1.0 - smoothstep(0.0, 0.6, r));
			col = mix(col, vec3(0.55, 0.7, 0.92), smoothstep(0.72, 0.92, r) * 0.6);
		}
	}
	ALBEDO = col;
	ALPHA = clamp(a * COLOR.a, 0.0, 1.0);
}
"""
	return sh
