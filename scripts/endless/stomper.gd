extends Node3D
## The stomper (docs/design/endless-flight/spec-stomper.md): one giant headless
## stone body in the Amberlands, the only one in the world: on the far side of
## the door in the game (doors world), at the origin with --world=amberlands, the
## debug world. It walks a loop round that land's home (stomper_route.gd), about
## HEIGHT m tall, and only while the plane is on its side, so it is where it was
## left and the first way out of the hall meets it. `--stomper=0` leaves it out.
##
## One skinned mesh and one Skeleton3D from assets/models/stomper_body.glb
## (art/blender/headless_body/reduce_stomper.py), dressed in the kit's stone.
## The `stomp` clip is the weight; here the feet are planted on the real ground
## and the body moves by the way the clip's planted foot goes back under it, so
## nothing slides. stomper_legs.gd lays the legs on the feet.
##   home(world)          where the Amberlands lie in this world, or INF
##   wanted(world)        whether this world has it
##   setup(study)         finds its way and stands it there
##   step(delta)          walks it
##   footfall(at, side)   a foot has come down (at: the ground under it)

signal footfall(at: Vector3, side: int)

const LaunchArgs = preload("res://scripts/launch_args.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")
const Route = preload("res://scripts/endless/stomper_route.gd")
const Legs = preload("res://scripts/endless/stomper_legs.gd")
const Fall = preload("res://scripts/endless/stomper_fall.gd")
const Wake = preload("res://scripts/endless/stomper_wake.gd")
const Door = preload("res://scripts/endless/hall_doors.gd")
const MODEL := "res://assets/models/stomper_body.glb"
## Its height in play (m), and the model's, stump's cut to soles (m).
const HEIGHT := 250.0
const MODEL_HEIGHT := 7.02
## The clip, and when in its cycle each foot lands and lifts (L, R), from the
## build's STOMP_LEN and STOMP_STANCE (headless_body_build.py).
const CLIP := "stomp"
const LENGTH := 16.0
const LAND: Array[float] = [0.0,0.5]
const LIFT: Array[float] = [0.62,0.12]
const STANCE := 0.62
## The cycle's table: samples of the clip, read at setup.
const SAMPLES := 96
## Where on the loop it starts, off the home (m): across the lake, left of the
## way out of the hall, walking north toward the ruin.
const START_OFF := Vector2(1530.0,900.0)
## How far off the hall's mouth on this side it keeps (m; the route's shore
## margin comes on top).
const DOOR_CLEAR := 220.0
## A hip's socket off the hips' middle (model m).
const HIP_X := 1.13568
## A sole's ground: how far round the ankle it is read (m), the most it tilts.
const SOLE := 22.0
const SOLE_TILT := 0.3
## The spare height a swinging foot keeps over the ground on its way (m).
const SWING_CLEAR := 8.0
## A leg's limit (share of its length), and how fast the body sinks to it (m/s).
const REACH := 0.985
const SINK_RATE := 16.0
## The baked occlusion's darkest share and its curve.
const AO_FLOOR := 0.42
const AO_EASE := 0.7
## LODs for the dressed mesh (ImporterMesh.generate_lods).
const LOD_MERGE := 60.0
const LOD_SPLIT := 25.0

var skeleton: Skeleton3D
var body: MeshInstance3D
var player: AnimationPlayer
var legs: SkeletonModifier3D
## The footfall's ring, dust and force (stomper_fall.gd), or null.
var fall: Node3D
## The track it leaves (stomper_wake.gd), or null.
var wake: Node3D
var route: RefCounted
var field: RefCounted
var world: RefCounted
## The land's home: the middle of its loop.
var centre := Vector2.ZERO
var _study: Node
## The model's metres to the world's.
var size := HEIGHT/MODEL_HEIGHT
## The cycle (0 to 1), and how far along the loop (m).
var phase := 0.0
var along := 0.0
## Each foot: down or not, where it stands or last stood (the ground), where it
## will land, the tilt of each, its swing's offset from the clip at the lift and
## its extra rise over the ground between.
var down: Array[bool] = [true,true]
var plant: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var aim: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _tilt_from: Array[Quaternion] = [Quaternion.IDENTITY,Quaternion.IDENTITY]
var _tilt_aim: Array[Quaternion] = [Quaternion.IDENTITY,Quaternion.IDENTITY]
var _off: Array[Vector2] = [Vector2.ZERO,Vector2.ZERO]
var _rise: Array[float] = [0.0,0.0]
## The body's ground height between the plants: this step's start and end.
var _level_from := 0.0
var _level_to := 0.0
var _sink := 0.0
## The table: per sample the body's way (model m), each ankle and the hips.
var _way := PackedFloat32Array()
var _ankle: Array[PackedVector3Array] = [PackedVector3Array(),PackedVector3Array()]
var _hips := PackedVector3Array()
var _whole := 0.0

## The Amberlands' home in `w`: the origin alone (--world=amberlands), the far
## side of the door in the game (profiles/doors.gd). INF: none here.
static func home(w: RefCounted) -> Vector2:
	if str(w.id) == "amberlands": return Vector2.ZERO
	if str(w.id) == "doors": return w.offset
	return Vector2.INF

static func wanted(w: RefCounted) -> bool:
	return home(w).is_finite() and not ("--stomper=0" in LaunchArgs.user_args())

func setup(study: Node) -> void:
	field = study.field
	world = study.world
	_study = study
	centre = home(world)
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	model.scale = Vector3.ONE*size
	add_child(model)
	skeleton = model.find_children("*","Skeleton3D",true,false)[0]
	body = skeleton.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	body.mesh = _dressed(body.mesh)
	var stone: Material = RuinKit.materials().stone
	for s in range(body.mesh.get_surface_count()):
		body.set_surface_override_material(s,stone)
	player = model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(CLIP)
	_read_clip()
	route = Route.walked(field,centre,_open)
	along = route.nearest(centre+START_OFF)
	_stand()
	legs = Legs.new()
	skeleton.add_child(legs)
	legs.bind(skeleton)
	_pose(1000.0)
	if Fall.wanted():
		fall = Fall.new()
		add_child(fall)
		fall.setup(study,self)
	if Wake.wanted():
		wake = Wake.new()
		add_child(wake)
		wake.setup(study,self)
	visible = _plane_here()

## Whether it may stand at (x, z): on its side of the door, off the hall's mouth.
func _open(x: float, z: float) -> bool:
	if world.has_method("side_of") and int(world.side_of(x,z)) != 1: return false
	return Vector2(x,z).distance_to(centre+Door.AMBER_AT) > DOOR_CLEAR

func _plane_here() -> bool:
	if not world.has_method("side_of"): return true
	var plane: RefCounted = _study.plane
	if plane == null: return false
	var p: Vector3 = plane.position
	return int(world.side_of(p.x,p.z)) == 1

## Walks it: the cycle on, the body by the planted foot's way, feet down and up
## as they cross their marks. All of it stands still, and draws nothing, while
## the plane is on the other side of the door.
func step(delta: float) -> void:
	visible = _plane_here()
	if not visible: return
	var was := phase
	phase = fposmod(phase+delta/LENGTH,1.0)
	along = fposmod(along+_gone(was,phase)*size,route.length)
	for side in range(2):
		if _crossed(was,phase,LAND[side]): _landed(side)
		if _crossed(was,phase,LIFT[side]): _lifted(side)
	_pose(delta)
	if fall != null: fall.step(delta)
	if wake != null: wake.step(delta)

## The body at `along`, the pose at `phase`, each ankle's goal.
func _pose(delta: float) -> void:
	player.seek(phase*LENGTH,true)
	var p2: Vector2 = route.at(along)
	var dir: Vector2 = route.way(along)
	var turn := atan2(-dir.x,-dir.y)
	var hip := _sampled(_hips,phase)
	var level := lerpf(_level_from,_level_to,_share())
	var goal: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
	var rock: Array[Quaternion] = [Quaternion.IDENTITY,Quaternion.IDENTITY]
	for side in range(2):
		var o := _sampled(_ankle[side],phase)*size
		if down[side]:
			goal[side] = plant[side]+Vector3.UP*o.y
			rock[side] = _tilt_from[side]
			continue
		var k := fposmod(phase-LIFT[side],1.0)/(1.0-STANCE)
		var glide := smoothstep(0.0,1.0,k)
		var off := _off[side]*(1.0-glide)
		var c := Vector2(o.x,o.z).rotated(-turn)
		goal[side] = Vector3(p2.x+c.x+off.x,lerpf(plant[side].y,aim[side].y,glide)+o.y+_rise[side]*sin(PI*k),p2.y+c.y+off.y)
		rock[side] = _tilt_from[side].slerp(_tilt_aim[side],glide)
	var want := 0.0
	var hip_y := level+hip.y*size
	var longest: float = legs.reach(0)*size*REACH
	for side in range(2):
		var socket := Vector2((hip.x+(-HIP_X if side == 0 else HIP_X))*size,hip.z*size).rotated(-turn)
		var run := Vector2(goal[side].x,goal[side].z).distance_to(p2+socket)
		var drop := hip_y-goal[side].y
		var room := sqrt(maxf(longest*longest-run*run,1.0))
		want = maxf(want,drop-room)
	_sink = move_toward(_sink,want,SINK_RATE*delta)
	position = Vector3(p2.x,level-_sink,p2.y)
	rotation.y = turn
	legs.goals = goal
	var yaw := Quaternion(Vector3.UP,turn)
	for side in range(2): legs.tilts[side] = yaw.inverse()*rock[side]*yaw

## The first stance: both feet down, the left just landed.
func _stand() -> void:
	var p2: Vector2 = route.at(along)
	var dir: Vector2 = route.way(along)
	var turn := atan2(-dir.x,-dir.y)
	for side in range(2):
		var o := _sampled(_ankle[side],phase)*size
		plant[side] = _ground(p2+Vector2(o.x,o.z).rotated(-turn))
		_tilt_from[side] = _tilt_of(plant[side])
	_aim(1)
	_level_from = (plant[0].y+plant[1].y)*0.5
	_level_to = (plant[0].y+aim[1].y)*0.5

func _landed(side: int) -> void:
	plant[side] = aim[side]
	_tilt_from[side] = _tilt_aim[side]
	down[side] = true
	var other := 1-side
	_aim(other)
	_level_from = (plant[0].y+plant[1].y)*0.5
	_level_to = (plant[side].y+aim[other].y)*0.5
	footfall.emit(plant[side],side)

func _lifted(side: int) -> void:
	down[side] = false
	var p2: Vector2 = route.at(along)
	var dir: Vector2 = route.way(along)
	var o := _sampled(_ankle[side],phase)*size
	var c := Vector2(o.x,o.z).rotated(-atan2(-dir.x,-dir.y))
	_off[side] = Vector2(plant[side].x,plant[side].z)-p2-c
	# Any ground higher than the straight line between gets cleared.
	var high := 0.0
	for i in range(1,6):
		var f := float(i)/6.0
		var at := plant[side].lerp(aim[side],f)
		high = maxf(high,float(field.height(at.x,at.z))+SWING_CLEAR-at.y)
	_rise[side] = high

## Where `side`, next to land, comes down: where the clip puts it at its mark,
## with the body as far along as it will be by then.
func _aim(side: int) -> void:
	var s: float = along+_gone(phase,LAND[side])*size
	var p2: Vector2 = route.at(s)
	var dir: Vector2 = route.way(s)
	var o := _sampled(_ankle[side],LAND[side])*size
	aim[side] = _ground(p2+Vector2(o.x,o.z).rotated(-atan2(-dir.x,-dir.y)))
	_tilt_aim[side] = _tilt_of(aim[side])

## The ground under a sole at `at`: its mean, so it beds in over bumps.
func _ground(at: Vector2) -> Vector3:
	var sum := float(field.height(at.x,at.y))
	for i in range(4):
		var d := Vector2.from_angle(TAU*float(i)/4.0)*SOLE
		sum += float(field.height(at.x+d.x,at.y+d.y))
	return Vector3(at.x,sum/5.0,at.y)

## The turn from up to the ground's slope under a sole, world, capped.
func _tilt_of(at: Vector3) -> Quaternion:
	var dx := float(field.height(at.x+SOLE,at.z))-float(field.height(at.x-SOLE,at.z))
	var dz := float(field.height(at.x,at.z+SOLE))-float(field.height(at.x,at.z-SOLE))
	var n := Vector3(-dx,SOLE*2.0,-dz).normalized()
	var axis := Vector3.UP.cross(n)
	if axis.length() < 0.0001: return Quaternion.IDENTITY
	return Quaternion(axis.normalized(),minf(Vector3.UP.angle_to(n),SOLE_TILT))

## How far the body goes from cycle point `a` on to `b` (model m).
func _gone(a: float, b: float) -> float:
	var d := _way_at(b)-_way_at(a)
	return d+_whole if b < a else d

## The share of this step the body has made, by the last landing.
func _share() -> float:
	var from: float = LAND[1] if phase >= LAND[1] else LAND[0]
	return clampf(_gone(from,phase)/(_whole*0.5),0.0,1.0)

func _way_at(u: float) -> float:
	var f := fposmod(u,1.0)*float(SAMPLES)
	var i := int(f)
	return lerpf(_way[i],_way[i+1],f-float(i))

func _sampled(table: PackedVector3Array, u: float) -> Vector3:
	var f := fposmod(u,1.0)*float(SAMPLES)
	var i := int(f)
	return table[i].lerp(table[i+1],f-float(i))

## True if a step from `a` to `b` round the cycle passes `mark`.
func _crossed(a: float, b: float, mark: float) -> bool:
	if b >= a: return a < mark and mark <= b
	return a < mark or mark <= b

## The clip read into the table. The planted foot goes back under the body, so
## its way is the body's: the left over the first half, the right the second.
func _read_clip() -> void:
	var ids := [skeleton.find_bone("foot.L"),skeleton.find_bone("foot.R")]
	var hips := skeleton.find_bone("hips")
	for side in range(2):
		_ankle[side].resize(SAMPLES+1)
	_hips.resize(SAMPLES+1)
	_way.resize(SAMPLES+1)
	for i in range(SAMPLES+1):
		player.seek(LENGTH*float(i)/float(SAMPLES),true)
		skeleton.force_update_all_bone_transforms()
		for side in range(2):
			_ankle[side][i] = skeleton.get_bone_global_pose(ids[side]).origin
		_hips[i] = skeleton.get_bone_global_pose(hips).origin
	# Forward is -Z. From the L's landing on, the left foot's z grows as the body
	# passes it; from the R's landing, the right's.
	var half := SAMPLES/2
	for i in range(half+1):
		_way[i] = _ankle[0][i].z-_ankle[0][0].z
	for i in range(half,SAMPLES+1):
		_way[i] = _way[half]+_ankle[1][i].z-_ankle[1][half].z
	_whole = _way[SAMPLES]

## The mesh in the kit's stone: each vertex coloured as the kit colours a face
## and darkened by the baked occlusion. Generated again as an ImporterMesh, or
## it has no LODs.
func _dressed(mesh: Mesh) -> ArrayMesh:
	var out := ImporterMesh.new()
	var stone := Style.stone_of(7) if Style.ruled() else Color("5a5d63")
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var ao: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var colours := PackedColorArray()
		colours.resize(verts.size())
		for i in range(verts.size()):
			var p := verts[i]
			var occ := 1.0
			if ao.size() == verts.size(): occ = pow(clampf(ao[i].r,0.0,1.0),AO_EASE)
			var c := Style.shade(stone,p,p+Vector3.UP*4.0,normals[i],1.0)*lerpf(AO_FLOOR,1.0,occ)
			c.a = occ
			colours[i] = c
		arrays[Mesh.ARRAY_COLOR] = colours
		out.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
	out.generate_lods(LOD_MERGE,LOD_SPLIT,[])
	return out.get_mesh()
