extends Node3D
## Puffs round the pilot's feet (scripts/wanderer_eye.gd), as a platformer's
## hero kicks them up: a little cloud off the heel at a run's footfalls
## (`footfall`), a ring of them landing and a push of them setting off or
## jumping (`burst`), a spray thrown ahead the whole of a skid (`spray`), a
## ring of little white wisps whirled round him by a twirl (`swirl`). Each
## is a little cloud of LOBES faceted balls, cut as the trees' crowns and the
## rocks are; it swells in a blink, billows as its throw dies and it rises,
## turning slowly, and shrinks away: it never fades, so nothing is
## see-through. Its colour is the
## ground's (KINDS, by scripts/wanderer_steps.gd surface): pale dust off
## grass, tan off earth, sand, a white powder off snow; wading throws
## droplets instead, flung up and falling back, and a wet pilot drips
## (`drip`).
##
## One MultiMesh of POOL faceted balls (an icosahedron cut once more) in
## the world's frame (top level; the oldest is reused when all are out), lit
## as the folk are (shaders/pilot_puff.gdshader).

const SHADER := preload("res://shaders/pilot_puff.gdshader")
const FacetMesh = preload("res://scripts/facet_mesh.gd")
const POOL := 192
## Balls a puff is made of: the biggest, and smaller ones round it.
const LOBES := 3
## Seconds a puff lasts (shortest, longest), and a droplet.
const LIFE := Vector2(0.3,0.46)
const DROP_LIFE := 0.45
## Radians a second a puff turns as it drifts, at most.
const TUMBLE := 2.0
## Seconds a puff takes to swell to its size.
const SWELL := 0.07
## How fast a puff's throw dies (a second), how fast it comes to rise (m/s
## at the end of its life), and the droplets' fall.
const DRAG := 6.0
const RISE := 0.5
const GRAVITY := 9.0
## A run's footfall puffs only over this effort (0 a walk, 1 a full run).
const RUN_PUFF := 0.55
## Puffs a second thrown in a skid.
const SPRAY_RATE := 18.0
## Each surface's puff: its colour and its biggest ball's size (diameter,
## m); water's are droplets.
const KINDS := {
	"grass":{"colour":Color(0.84,0.86,0.76),"size":0.2},
	"earth":{"colour":Color(0.78,0.69,0.56),"size":0.22},
	"sand":{"colour":Color(0.9,0.83,0.67),"size":0.22},
	"stone":{"colour":Color(0.8,0.79,0.76),"size":0.17},
	"snow":{"colour":Color(0.95,0.96,0.98),"size":0.24},
	"wood":{"colour":Color(0.82,0.77,0.67),"size":0.14},
	"water":{"colour":Color(0.84,0.92,0.96),"size":0.06,"drops":true},
	"air":{"colour":Color(0.96,0.97,1.0),"size":0.11},
}
## A twirl's swirl: its wisps, their ring's radius (m) and their whirl and
## throw out (m/s).
const SWIRL := 8
const SWIRL_RADIUS := 0.32
const SWIRL_WHIRL := 3.2
const SWIRL_OUT := 0.8

var _mesh: MultiMeshInstance3D
var _at := PackedVector3Array()
var _velocity := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _drop := PackedByteArray()
## Each ball's turn (Euler, radians) and how fast it tumbles.
var _turn := PackedVector3Array()
var _tumble := PackedFloat32Array()
var _next := 0
var _spray_due := 0.0
var _rng := RandomNumberGenerator.new()
## Puffs alive, for probes.
var alive := 0

func _init() -> void:
	name = "Puffs"
	top_level = true
	_rng.randomize()
	var ball := _ball()
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("fill",1.15)
	material.set_shader_parameter("rim",0.6)
	ball.surface_set_material(0,material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = ball
	multimesh.instance_count = POOL
	_mesh = MultiMeshInstance3D.new()
	_mesh.multimesh = multimesh
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_at.resize(POOL)
	_velocity.resize(POOL)
	_age.resize(POOL)
	_life.resize(POOL)
	_size.resize(POOL)
	_drop.resize(POOL)
	_turn.resize(POOL)
	_tumble.resize(POOL)
	for i in range(POOL):
		_age[i] = 1.0
		_life[i] = 0.0
		multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	set_process(false)

## A footfall at `at` (the boot, on the ground), the run going away from
## `back` (flat), at `effort`: a puff off the heel at a run, drops wading.
func footfall(at: Vector3, back: Vector3, surface: String, effort: float) -> void:
	var kind: Dictionary = KINDS.get(surface,KINDS.earth)
	var side := Vector3(-back.z,0.0,back.x)
	if kind.has("drops"):
		for i in range(_rng.randi_range(2,4)):
			_spawn(at,back*_rng.randf_range(0.3,0.9)+side*_rng.randf_range(-0.6,0.6)+Vector3.UP*_rng.randf_range(1.4,2.3),kind,lerpf(0.6,1.0,effort),true)
		return
	if effort < RUN_PUFF: return
	var size := lerpf(0.75,1.0,effort)
	for i in range(2 if surface in ["sand","snow"] else 1):
		_cloud(at+back*0.06+Vector3.UP*0.06,back*_rng.randf_range(0.6,1.1)+side*_rng.randf_range(-0.35,0.35)+Vector3.UP*_rng.randf_range(0.25,0.55),kind,size*_rng.randf_range(0.8,1.15),LOBES)

## A drip falling off him from `at` (a wet mitt, hem or boot), `fall` m
## over the ground: a small droplet let go with no throw, falling until it
## reaches the ground.
func drip(at: Vector3, fall: float) -> void:
	var kind: Dictionary = KINDS.water
	var i := _next
	_spawn(at,Vector3(_rng.randf_range(-0.05,0.05),-0.2,_rng.randf_range(-0.05,0.05)),kind,_rng.randf_range(0.8,1.1),true)
	_life[i] = maxf(0.08,(sqrt(0.04+2.0*GRAVITY*maxf(fall,0.0))-0.2)/GRAVITY)/0.75

## A ring of puffs thrown out flat from `at`, `strength` 0 (a hop) to 1 (a
## hard landing); `back` (flat, or zero) leans the ring that way, for a push
## off the ground.
func burst(at: Vector3, surface: String, strength: float, back := Vector3.ZERO) -> void:
	var kind: Dictionary = KINDS.get(surface,KINDS.earth)
	strength = clampf(strength,0.0,1.0)
	var count := 5+roundi(5.0*strength)
	var turn := _rng.randf_range(0.0,TAU)
	for i in range(count):
		var way := Vector3.FORWARD.rotated(Vector3.UP,turn+TAU*(float(i)+_rng.randf_range(-0.25,0.25))/count)
		if kind.has("drops"):
			_spawn(at+way*0.12,way*_rng.randf_range(0.5,1.2)+back*0.8+Vector3.UP*_rng.randf_range(1.8,3.0)*(0.6+0.4*strength),kind,1.0,true)
		else:
			_cloud(at+way*0.1+Vector3.UP*0.05,(way*_rng.randf_range(1.0,1.6)+back*0.9)*(0.6+0.6*strength)+Vector3.UP*_rng.randf_range(0.1,0.3),kind,(0.75+0.4*strength)*_rng.randf_range(0.85,1.15),2)

## A twirl's swirl round `at` (his middle), turning `way` (1 the way a
## positive yaw turns, -1 the other): little wisps whirled round and out,
## `strength` 0 to 1.
func swirl(at: Vector3, way: float, strength: float) -> void:
	var kind: Dictionary = KINDS.air
	var turn := _rng.randf_range(0.0,TAU)
	for i in range(SWIRL):
		var out := Vector3.FORWARD.rotated(Vector3.UP,turn+TAU*float(i)/SWIRL)
		var whirl := out.cross(Vector3.UP)*-way
		var lift := Vector3.UP*_rng.randf_range(-0.15,0.15)*(1.0 if i%2 else -1.0)
		_cloud(at+out*SWIRL_RADIUS+lift,(whirl*SWIRL_WHIRL+out*SWIRL_OUT)*(0.6+0.4*strength),kind,(0.7+0.3*strength)*_rng.randf_range(0.85,1.15),2)

## A skid's spray from `at` over `delta` s, thrown the way it slides (`way`,
## flat) and up, as fast as `effort` (0 to 1) of a run.
func spray(at: Vector3, way: Vector3, surface: String, effort: float, delta: float) -> void:
	var kind: Dictionary = KINDS.get(surface,KINDS.earth)
	var side := Vector3(-way.z,0.0,way.x)
	_spray_due += delta*SPRAY_RATE
	while _spray_due >= 1.0:
		_spray_due -= 1.0
		var from := at+side*_rng.randf_range(-0.1,0.1)+way*0.12
		if kind.has("drops"):
			_spawn(from,way*_rng.randf_range(1.0,2.0)*effort+side*_rng.randf_range(-0.5,0.5)+Vector3.UP*_rng.randf_range(1.2,2.2),kind,1.0,true)
		else:
			_cloud(from+Vector3.UP*0.05,way*_rng.randf_range(1.2,2.2)*effort+side*_rng.randf_range(-0.6,0.6)+Vector3.UP*_rng.randf_range(0.3,0.8),kind,lerpf(0.7,1.0,effort)*_rng.randf_range(0.8,1.1),2)

## A puff: its biggest ball at `at`, `lobes`-1 smaller ones heaped round
## it, all thrown at about `velocity`.
func _cloud(at: Vector3, velocity: Vector3, kind: Dictionary, size: float, lobes: int) -> void:
	var across := float(kind.size)*size
	_spawn(at,velocity,kind,size,false)
	for i in range(lobes-1):
		var way := Vector3.FORWARD.rotated(Vector3.UP,_rng.randf_range(0.0,TAU))
		var spread := Vector3(_rng.randf_range(-0.15,0.15),_rng.randf_range(0.0,0.15),_rng.randf_range(-0.15,0.15))
		_spawn(at+(way*0.32+Vector3.UP*0.12)*across,velocity+spread,kind,size*_rng.randf_range(0.55,0.75),false)

func _spawn(at: Vector3, velocity: Vector3, kind: Dictionary, size: float, drop: bool) -> void:
	var i := _next
	_next = (_next+1)%POOL
	_at[i] = at
	_velocity[i] = velocity
	_age[i] = 0.0
	_life[i] = DROP_LIFE*_rng.randf_range(0.85,1.15) if drop else _rng.randf_range(LIFE.x,LIFE.y)
	_size[i] = float(kind.size)*size
	_drop[i] = 1 if drop else 0
	_turn[i] = Vector3(_rng.randf_range(-PI,PI),_rng.randf_range(-PI,PI),_rng.randf_range(-PI,PI))
	_tumble[i] = _rng.randf_range(-TUMBLE,TUMBLE)
	var tint: Color = kind.colour
	_mesh.multimesh.set_instance_color(i,tint.lightened(_rng.randf_range(0.0,0.08)))
	set_process(true)

func _process(delta: float) -> void:
	var multimesh := _mesh.multimesh
	alive = 0
	for i in range(POOL):
		if _life[i] <= 0.0: continue
		_age[i] += delta
		var u := _age[i]/_life[i]
		if u >= 1.0:
			_life[i] = 0.0
			multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),_at[i]))
			continue
		alive += 1
		var size := _size[i]
		var velocity := _velocity[i]
		var turn := _turn[i]
		if _drop[i] == 1:
			velocity.y -= GRAVITY*delta
			_velocity[i] = velocity
			_at[i] += velocity*delta
			size *= 1.0-smoothstep(0.6,1.0,u)
			multimesh.set_instance_transform(i,Transform3D(Basis.from_euler(turn).scaled_local(Vector3.ONE*size),_at[i]))
			continue
		# Thrown, slowing, then billowing up and turning as it shrinks away.
		velocity *= exp(-DRAG*delta)
		_velocity[i] = velocity
		_at[i] += (velocity+Vector3.UP*RISE*u)*delta
		turn.y += _tumble[i]*delta
		_turn[i] = turn
		var swell := 1.0-pow(1.0-minf(_age[i]/SWELL,1.0),3.0)
		size *= (0.4+0.6*swell)*(1.0+0.8*u)*pow(1.0-u,0.9)
		multimesh.set_instance_transform(i,Transform3D(Basis.from_euler(turn).scaled_local(Vector3(size,size*0.85,size)),_at[i]))
	if alive == 0: set_process(false)

## A ball 1 m across, faceted: an icosahedron with each face cut in four,
## pushed out round.
static func _ball() -> ArrayMesh:
	var t := (1.0+sqrt(5.0))/2.0
	var corners: Array[Vector3] = []
	for c in [Vector3(-1,t,0),Vector3(1,t,0),Vector3(-1,-t,0),Vector3(1,-t,0),Vector3(0,-1,t),Vector3(0,1,t),Vector3(0,-1,-t),Vector3(0,1,-t),Vector3(t,0,-1),Vector3(t,0,1),Vector3(-t,0,-1),Vector3(-t,0,1)]:
		corners.append(c.normalized()*0.5)
	var faces := [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],
		[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
	var tris := []
	for f: Array in faces:
		var a := corners[f[0]]
		var b := corners[f[1]]
		var c := corners[f[2]]
		var ab := ((a+b)*0.5).normalized()*0.5
		var bc := ((b+c)*0.5).normalized()*0.5
		var ca := ((c+a)*0.5).normalized()*0.5
		for tri: Array in [[a,ab,ca],[b,bc,ab],[c,ca,bc],[ab,bc,ca]]: tris.append(tri+[Vector3.ZERO])
	return FacetMesh.shell(tris)
