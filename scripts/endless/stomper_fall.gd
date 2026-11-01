extends Node3D
## A footfall of the stomper (docs/design/endless-flight/spec-stomper.md), one
## shared pass, whatever is near: the ring runs out over the land, the dust goes
## up, the grass and the eye feel it, and the plane is shoved if it is close.
##
##   ring   shaders/stomper_ring.gdshader: one screen quad that lays the front
##          on whatever ground the depth shows, so it climbs the land as it is.
##   dust   shaders/stomper_dust.gdshader: one MultiMesh, written at the landing
##          and moved by the shader from then on, so a frame costs one clock.
##   grass  a stamp in the push map (GrassReact `shock`), with the same front.
##   felt   when the front reaches the plane (FRONT, not at the landing): the
##          view's shake and punch, the pad, the thump, and within SHOVE_REACH
##          the shove (SkyPlane `knock`), flying only.
##
## `--no-stomper-fall` leaves it all out; the feet still land.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const RING_SHADER = preload("res://shaders/stomper_ring.gdshader")
const DUST_SHADER = preload("res://shaders/stomper_dust.gdshader")

## The front's speed (m/s), how far it runs (m), and the rings alive at once.
const FRONT := 220.0
const REACH := 1500.0
const RINGS := 2
## The grass: how hard the front lays it over, and how long it is held (s).
const GRASS := 3.2
const GRASS_HOLD := 0.3
## The eye: the shake (rad) and punch (degrees) at the foot, the distance they
## have gone by (m), how long the shake is held up as the front goes by (s).
const SHAKE := 0.02
const PUNCH := 2.2
const FELT_REACH := 2200.0
const SHAKE_HOLD := 0.55
## The pad: weak motor, strong motor, seconds, at the foot.
const PAD := Vector3(0.7,1.0,0.5)
## The thump: gain at the foot and its pitch, low for the size of what fell.
const THUMP := 1.0
const THUMP_PITCH := 0.42
## The shove: its reach from the foot (m), most speed out (m/s), share of it up,
## the most the nose is turned (rad).
const SHOVE_REACH := 520.0
const SHOVE := 34.0
const SHOVE_UP := 0.55
const SHOVE_YAW := 0.1
## The dust: puffs a landing in the skirt and the column, the most alive, how
## far the skirt runs out (m), the seconds it takes to spend its way.
const SKIRT := 30
const COLUMN := 16
const LANDINGS := 2*(SKIRT+COLUMN)
## The puffs a wake can hang over its track (`hang`), their life (s), how thin
## they are and the share of their life they take to come up.
const HUNG := 40
const HUNG_LIFE := Vector2(35.0,60.0)
const HUNG_THIN := 0.45
const HUNG_RISE := 0.2
const MOST := LANDINGS+HUNG
const SKIRT_RUN := 300.0
const SKIRT_TAU := 2.2
const COLUMN_TAU := 3.5
## Each kind's size (m), low and high, and life (s).
const SKIRT_SIZE := Vector2(60.0,110.0)
const COLUMN_SIZE := Vector2(60.0,105.0)
const LIFE := Vector2(5.5,9.0)
## The dust's colour: lit top and shaded foot; how thick a puff is at its most.
const DUST_TOP := Color(0.74,0.66,0.52)
const DUST_FOOT := Color(0.42,0.35,0.27)
const DUST_MOST := 0.95

var enabled := true
var now := 0.0
## For drivers: footfalls seen, fronts that have reached the plane, shoves.
var stats := {"falls": 0, "felt": 0, "shoves": 0, "last_shove": Vector3.ZERO}

var _study: Node
var _field: RefCounted
var _rng := RandomNumberGenerator.new()
var _ring_mat: ShaderMaterial
var _ring_mesh: MeshInstance3D
var _dust_mat: ShaderMaterial
var _dust: MultiMesh
var _dust_next := 0
var _hung_next := 0
## Each ring: at, born, felt (the front has reached the plane), felt_at.
var _rings: Array[Dictionary] = []

static func wanted() -> bool:
	return not "--no-stomper-fall" in LaunchArgs.user_args()

func setup(study: Node, stomper: Node3D) -> void:
	name = "StomperFall"
	top_level = true
	global_transform = Transform3D.IDENTITY
	_study = study
	_field = study.field
	_rng.seed = 17011
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = RING_SHADER
	_ring_mat.set_shader_parameter("reach",REACH)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*2.0
	quad.material = _ring_mat
	_ring_mesh = MeshInstance3D.new()
	_ring_mesh.name = "Ring"
	_ring_mesh.mesh = quad
	_ring_mesh.custom_aabb = _everywhere()
	_ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_mesh.visible = false
	add_child(_ring_mesh)
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE
	_dust_mat = ShaderMaterial.new()
	_dust_mat.shader = DUST_SHADER
	_dust_mat.set_shader_parameter("top",DUST_TOP)
	_dust_mat.set_shader_parameter("foot",DUST_FOOT)
	_dust_mat.set_shader_parameter("thick",DUST_MOST)
	puff.material = _dust_mat
	_dust = MultiMesh.new()
	_dust.transform_format = MultiMesh.TRANSFORM_3D
	_dust.use_custom_data = true
	_dust.mesh = puff
	_dust.instance_count = MOST
	# Born never: each stays hidden until a landing writes it.
	for i in range(MOST):
		_dust.set_instance_transform(i,Transform3D())
		_dust.set_instance_custom_data(i,Color(-1000.0,0.0,0.0,0.0))
	var dusts := MultiMeshInstance3D.new()
	dusts.name = "Dust"
	dusts.multimesh = _dust
	dusts.custom_aabb = _everywhere()
	dusts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dusts)
	stomper.footfall.connect(fell)

## A landing: at `at`, the ground under the foot.
func fell(at: Vector3, _side: int) -> void:
	if not enabled: return
	stats.falls = int(stats.falls)+1
	if _rings.size() >= RINGS: _rings.pop_front()
	_rings.append({"at": at, "born": now, "felt": false, "felt_at": 0.0})
	_write_rings()
	_ring_mesh.visible = true
	_raise_dust(at)
	var react: Node = _study.react
	if react != null: react.shock(Vector2(at.x,at.z),REACH,FRONT,GRASS,GRASS_HOLD)

func step(delta: float) -> void:
	if not enabled: return
	now += delta
	_dust_mat.set_shader_parameter("now",now)
	if _rings.is_empty(): return
	var eye: Vector3 = _study.plane.position
	var i := 0
	while i < _rings.size():
		var r: Dictionary = _rings[i]
		var run := (now-float(r.born))*FRONT
		var gone: float = eye.distance_to(r.at)
		if not r.felt and run >= gone:
			r.felt = true
			r.felt_at = now
			_arrived(r.at,gone)
		if r.felt and now-float(r.felt_at) < SHAKE_HOLD: _shake(gone)
		if run > REACH*1.05 and (r.felt or gone > FELT_REACH): _rings.remove_at(i)
		else: i += 1
	_write_rings()
	_ring_mesh.visible = not _rings.is_empty()

## The share felt `gone` m from the foot: all of it near, none past FELT_REACH.
static func felt_share(gone: float) -> float:
	var k := 1.0-smoothstep(120.0,FELT_REACH,gone)
	return k*k

func _shake(gone: float) -> void:
	_study.feel_hit(SHAKE*felt_share(gone),0.0)

## The front has reached the plane, `gone` m from the foot at `at`.
func _arrived(at: Vector3, gone: float) -> void:
	stats.felt = int(stats.felt)+1
	var k := felt_share(gone)
	if k <= 0.0: return
	_study.feel_hit(SHAKE*k,PUNCH*k)
	_study.rumble.knock(Vector3(PAD.x*k,PAD.y*k,PAD.z))
	_study.sound.shot("thump",THUMP*sqrt(k),THUMP_PITCH)
	if gone > SHOVE_REACH or not _study.hand_landing.flying(): return
	if _study.stage != null: return
	var plane: RefCounted = _study.plane
	var near := 1.0-smoothstep(0.0,SHOVE_REACH,gone)
	var flat := Vector2(plane.position.x-at.x,plane.position.z-at.z)
	flat = flat.normalized() if flat.length() > 1.0 else Vector2.from_angle(_rng.randf()*TAU)
	var shove := Vector3(flat.x,SHOVE_UP,flat.y)*SHOVE*near
	# The nose goes with it: away from the foot on the side it is on.
	var nose: Vector3 = plane.forward()
	var side := Vector2(nose.x,nose.z).cross(flat)
	plane.knock(1.0,shove,-signf(side)*SHOVE_YAW*near)
	stats.shoves = int(stats.shoves)+1
	stats.last_shove = shove

func _write_rings() -> void:
	var at := PackedVector4Array()
	at.resize(RINGS)
	for i in range(_rings.size()):
		var r: Dictionary = _rings[i]
		var c: Vector3 = r.at
		at[i] = Vector4(c.x,c.y,c.z,(now-float(r.born))*FRONT)
	for i in range(_rings.size(),RINGS):
		at[i] = Vector4(0.0,0.0,0.0,-1.0)
	_ring_mat.set_shader_parameter("rings",at)

## The puffs of one landing: the skirt thrown out along the ground, which it
## follows to where it stops; the column going up off the foot.
func _raise_dust(at: Vector3) -> void:
	for i in range(SKIRT):
		var a := TAU*(float(i)+_rng.randf_range(-0.4,0.4))/float(SKIRT)
		var way := Vector2.from_angle(a)
		var from := Vector2(at.x,at.z)+way*_rng.randf_range(20.0,55.0)
		var run := SKIRT_RUN*_rng.randf_range(0.65,1.15)
		var to := from+way*run
		var y0 := float(_field.height(from.x,from.y))
		var y1 := float(_field.height(to.x,to.y))
		var v := Vector3(way.x*run,maxf(y1-y0,-40.0)+_rng.randf_range(10.0,30.0),way.y*run)/SKIRT_TAU
		_puff(Vector3(from.x,y0+10.0,from.y),v,SKIRT_TAU,_rng.randf_range(SKIRT_SIZE.x,SKIRT_SIZE.y))
	for i in range(COLUMN):
		var off := Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(0.0,34.0)
		var v := Vector3(off.x,_rng.randf_range(120.0,340.0),off.y)/COLUMN_TAU
		_puff(at+Vector3(off.x,8.0,off.y),v,COLUMN_TAU,_rng.randf_range(COLUMN_SIZE.x,COLUMN_SIZE.y))

## One puff into the ring of them. The transform's basis carries the way and
## the seconds it spends it (see the shader), not a turn.
func _puff(at: Vector3, v: Vector3, tau: float, size: float) -> void:
	var t := Transform3D(Basis(v,Vector3(tau,1.0,0.06),Vector3.ZERO),at)
	_dust.set_instance_transform(_dust_next,t)
	_dust.set_instance_custom_data(_dust_next,Color(now,_rng.randf_range(LIFE.x,LIFE.y),size,_rng.randf()))
	_dust_next = (_dust_next+1)%LANDINGS

## A thin puff left hanging at `at`, drifting at `v` (m/s), in its own part of the
## ring: a landing's dozens would push it out long before its time.
func hang(at: Vector3, v: Vector3, size: float) -> void:
	var life := _rng.randf_range(HUNG_LIFE.x,HUNG_LIFE.y)
	var t := Transform3D(Basis(v,Vector3(life,HUNG_THIN,HUNG_RISE),Vector3.ZERO),at)
	var i := LANDINGS+_hung_next
	_dust.set_instance_transform(i,t)
	_dust.set_instance_custom_data(i,Color(now,life,size,_rng.randf()))
	_hung_next = (_hung_next+1)%HUNG

func _everywhere() -> AABB:
	return AABB(Vector3.ONE*-50000.0,Vector3.ONE*100000.0)
