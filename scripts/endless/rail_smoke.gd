extends RefCounted
## The steam trains' coal smoke and steam (spec-steam-train.md, the trunk's
## task 3), RailTrains' (`smoke`, stepped in its `before` after the trains are
## placed). Look only: nothing here is solid, and the plane flies through it.
##
## Each train has its own puffs, let go where its engine is and left where the
## air has them (assets/models/train/train_smoke.gdshader plays each one by its
## age), so the train runs on and its trail lies back along the line over the
## cars. The engine is posed from the train's timetable when the train isn't
## built (past RailTrains' LOOK_NEAR), so the far plume shows from anywhere.
## - The stack: a chuff at each of the four exhausts a turn of the drivers,
##   eased under CHUFF_MOST a second (slow heavy chuffs pulling out, a few a
##   second at speed), every other one a little weaker (the beat). How hard it
##   works (`effort`: pulling out, running, drifting into a stop) sets how high
##   a chuff is thrown, how big it swells and how dark it starts. Soot at the
##   mouth, paling to grey, it hangs a train's length back (LIFE). Standing,
##   a thin lazy wisp now and then.
## - Steam: white puffs thrown out of the cylinders' cocks either side while
##   it stands and pulling out (under STEAM_V m/s).
## - The far plume: big pale puffs let go over the stack every FAR_EVERY s,
##   rising and drifting high over the line; shown only from FAR_IN m off and
##   swelling with the distance (the shader), so a train is found by its smoke
##   from across the land, past the 4 km its cars are drawn to.
## - In a bore (the line's `kind` "tunnel"): the stack's puffs are held under
##   the vault (BORE_LID) and no far plume is let go.
##
## Cheap by build: one MultiMesh a train, its buffer written whole once in a
## frame a puff was let go (never one instance in place), its box the live
## puffs' starts padded by how far they go. The engine's mouths are the glb's
## empties (StackMouth, Steam_R, Steam_L), read off the first engine model
## built (else MOUTH, STEAM_AT: the same numbers).
##
## --no-train-smoke: none (the cost A/B).

const RailTrain = preload("res://scripts/endless/rail_train.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const SHADER := preload("res://assets/models/train/train_smoke.gdshader")

## The puffs' roles in the shader.
const STACK := 0.0
const STEAM := 1.0
const FAR := 2.0

## A train's puffs: the stack's and the steam's, then the far plume's.
const NEAR_POOL := 320
const FAR_POOL := 128

## In the engine's frame (m): the stack's mouth and the cylinders' steam points.
const MOUTH := Vector3(0.0,8.5,-8.2)
const STEAM_AT := [Vector3(2.0,1.7,-8.3),Vector3(-2.0,1.7,-8.3)]

## The rhythm: four exhausts a turn of the drivers (radius DRIVER_R m), eased
## under CHUFF_MOST a second: 0.8 a second at 2 m/s, 2.9 at 10, 4.4 at 32.
## BEAT: each exhaust's share of a full chuff, round a turn.
const DRIVER_R := 1.45
const CHUFF_MOST := 4.5
const BEAT := [1.0,0.78,0.94,0.72]
## How hard it works: pulling out, running, drifting (shut off, braking);
## followed at EFFORT_EASE a second. Over ACCEL_IS m/s² it's pulling.
const EFFORT_PULL := 1.0
const EFFORT_RUN := 0.5
const EFFORT_DRIFT := 0.15
const EFFORT_EASE := 1.5
const ACCEL_IS := 0.05
## A chuff by effort (x at none, y at full): thrown up (m/s), its radius at
## the most (m), how pale at first (0 soot), opacity. First radius CHUFF_R0.
## It lifts CHUFF_LIFT m/s after, and lasts LIFE s at full speed (a train's
## length back), LIFE_SLOW at a crawl. The train's speed at the stack is kept:
## the air takes it off (the shader's drag), so the puff falls back along it.
const CHUFF_UP := Vector2(4.0,10.0)
const CHUFF_R := Vector2(4.5,9.0)
const CHUFF_PALE := Vector2(0.45,0.05)
const CHUFF_OPACITY := Vector2(0.6,0.95)
const CHUFF_R0 := 1.5
const CHUFF_LIFT := 0.15
const LIFE := 19.0
const LIFE_SLOW := 11.0
## Standing: a wisp every IDLE_EVERY s.
const IDLE_EVERY := 1.6
## Steam: under STEAM_V m/s pulling out, or standing; a puff from one side
## and then the other every STEAM_EVERY s (x standing, y pulling out), thrown
## out STEAM_OUT m/s (x, y the same), radius STEAM_R (first, most), STEAM_LIFE s,
## opacity STEAM_OPACITY.
const STEAM_V := 6.0
const STEAM_EVERY := Vector2(0.3,0.14)
const STEAM_OUT := Vector2(3.5,8.0)
const STEAM_R := Vector2(0.6,3.6)
const STEAM_LIFE := 2.6
const STEAM_OPACITY := 0.85
## The far plume: a puff every FAR_EVERY s (x running, y standing), let go
## FAR_OVER m over the mouth, thrown up FAR_UP m/s, lifting FAR_LIFT m/s,
## radius FAR_R (first, most: before the shader's swelling with distance),
## lasting FAR_LIFE s, opacity FAR_OPACITY (x running, y standing).
const FAR_EVERY := Vector2(0.7,1.6)
const FAR_OVER := 6.0
const FAR_UP := 3.0
const FAR_LIFT := 2.8
const FAR_R := Vector2(12.0,34.0)
const FAR_LIFE := 48.0
const FAR_OPACITY := Vector2(0.85,0.55)
## Stack and steam puffs are let go only within NEAR_EMIT m of the plane.
const NEAR_EMIT := 4400.0
## In a bore, the most a stack puff rises over the mouth (m: under the vault).
const BORE_LID := 4.0
## A clock step longer than this (s: a skip, a jump) lets nothing go.
const JUMP := 0.5
## How far a puff goes from its start (m), for the box: the stack's and the
## far's (its swelling with the distance more); the box made again every
## BOX_EVERY s.
const REACH := 60.0
const FAR_REACH := 260.0
const BOX_EVERY := 2.0

static var _mouth := MOUTH
static var _steam := STEAM_AT.duplicate()
static var _read := false

var trains: Node3D
var root: Node3D
var _mat: ShaderMaterial
var _quad: ArrayMesh
## One per run of `trains.runs` (Emitter, below).
var _each: Array[Emitter] = []
## The puffs' clock (s): the trains' clock's steps, each at most JUMP.
var now := 0.0
var _was := NAN
## Counts, for the checks.
var chuffs := 0
var steams := 0
var fars := 0

static func wanted() -> bool:
	return not ("--no-train-smoke" in LaunchArgs.user_args())

func _init(holder: Node3D) -> void:
	trains = holder
	root = Node3D.new()
	root.name = "Smoke"
	root.top_level = true
	holder.add_child(root)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_quad = _disc()

## One frame, at the trains' clock `time` (s), after they are placed.
func step(_delta: float, time: float) -> void:
	var dt := 0.0 if is_nan(_was) else time-_was
	_was = time
	var jumped := dt < 0.0 or dt > JUMP
	dt = 0.0 if jumped else dt
	now += dt
	_mat.set_shader_parameter("now",now)
	var runs: Array = trains.runs
	while _each.size() < runs.size(): _each.append(_new_one())
	var plane = trains.game.get("plane") if trains.game != null else null
	var eye: Vector3 = plane.position if plane != null else Vector3.ZERO
	for i in range(runs.size()):
		var e: Emitter = _each[i]
		_run_step(runs[i],e,dt,jumped,eye)
		if e.dirty: e.write(now)

## Train `run`'s puffs for a step of `dt` s.
func _run_step(run: Dictionary, e: Emitter, dt: float, jumped: bool, eye: Vector3) -> void:
	var tr: Node3D = run.train
	var table: RefCounted = run.timetable
	var xf: Transform3D
	var v := 0.0
	var standing := false
	var d := 0.0
	if tr != null:
		var c0: Dictionary = tr.cars[0]
		xf = c0.xf
		v = float(tr.speed)
		standing = int(tr.stop) >= 0
		d = float(tr.d)
		if not _read: _read_mouths(c0)
	else:
		var at: Dictionary = table.at(trains.time)
		d = float(at.d)
		v = float(at.v)
		standing = int(at.stop) >= 0
		xf = engine_pose(trains.path,table,int(run.track),d)
	if jumped or dt <= 0.0:
		e.v = v
		e.chuff = 0.0
		return
	var accel := (v-e.v)/dt
	e.v = v
	var still := standing or v < 0.3
	var aim := EFFORT_RUN
	if still: aim = 0.0
	elif accel > ACCEL_IS: aim = EFFORT_PULL
	elif accel < -ACCEL_IS: aim = EFFORT_DRIFT
	e.effort = lerpf(e.effort,aim,1.0-exp(-EFFORT_EASE*dt))
	var near := xf.origin.distance_to(eye) < NEAR_EMIT
	var mouth := xf*_mouth
	var fwd := -xf.basis.z
	var bore := _in_bore(table,d)
	if near:
		if not still:
			var turns := 4.0*v/(TAU*DRIVER_R)
			var rate := CHUFF_MOST*(1.0-exp(-turns/CHUFF_MOST))
			e.chuff = e.chuff+rate*dt
			while e.chuff >= 1.0:
				e.chuff = e.chuff-1.0
				e.beat = (e.beat+1)%BEAT.size()
				_chuff(e,mouth,fwd*v,e.effort*float(BEAT[e.beat]),v,bore)
		else:
			e.idle = e.idle+dt
			if e.idle >= IDLE_EVERY:
				e.idle = 0.0
				_chuff(e,mouth,Vector3.ZERO,0.0,0.0,bore,true)
		var pulling := not still and v < STEAM_V and accel > 0.0
		if still or pulling:
			e.steam = e.steam+dt
			var every := STEAM_EVERY.x if still else STEAM_EVERY.y
			if e.steam >= every:
				e.steam = 0.0
				e.side = 1-e.side
				var p: Vector3 = xf*(_steam[e.side] as Vector3)
				var out := xf.basis.x*(1.0 if e.side == 0 else -1.0)
				var push := STEAM_OUT.x if still else STEAM_OUT.y
				var throw := out*push*randf_range(0.8,1.2)+Vector3.UP*randf_range(0.6,1.8)+fwd*(v+randf_range(-0.5,1.5))
				e.puff(now,false,p,throw,STEAM_R.x,STEAM_R.y*randf_range(0.85,1.15),STEAM_LIFE*randf_range(0.8,1.15),1.0,STEAM_OPACITY,1.0e4,STEAM,0.7)
				steams += 1
	if not bore:
		e.far_t = e.far_t+dt
		if e.far_t >= (FAR_EVERY.y if still else FAR_EVERY.x):
			e.far_t = 0.0
			var op := FAR_OPACITY.y if still else FAR_OPACITY.x
			e.puff(now,true,mouth+Vector3.UP*FAR_OVER,fwd*v+Vector3.UP*FAR_UP,FAR_R.x,FAR_R.y*randf_range(0.85,1.15),FAR_LIFE*randf_range(0.9,1.1),0.7,op,1.0e4,FAR,FAR_LIFT)
			fars += 1

## A chuff from `mouth` at `carry` (the train's velocity), at `effort` (0..1).
## `idle`: a standing wisp.
func _chuff(e: Emitter, mouth: Vector3, carry: Vector3, effort: float, v: float, bore: bool, idle := false) -> void:
	var k := clampf(effort,0.0,1.0)
	var up := lerpf(CHUFF_UP.x,CHUFF_UP.y,k)*(0.5 if idle else 1.0)
	var side := Vector3(randf_range(-0.6,0.6),0.0,randf_range(-0.6,0.6))
	var r1 := lerpf(CHUFF_R.x,CHUFF_R.y,k)*randf_range(0.88,1.12)
	var life := lerpf(LIFE_SLOW,LIFE,clampf(v/RailTrain.SPEED,0.0,1.0))*randf_range(0.9,1.1)
	var pale := 0.6 if idle else lerpf(CHUFF_PALE.x,CHUFF_PALE.y,k)
	var op := 0.4 if idle else lerpf(CHUFF_OPACITY.x,CHUFF_OPACITY.y,k)
	if bore: r1 *= 0.75
	e.puff(now,false,mouth,carry+Vector3.UP*up+side,CHUFF_R0,r1,life,pale,op,BORE_LID if bore else 1.0e4,STACK,CHUFF_LIFT)
	chuffs += 1

## How many puffs are showing now, each kind: {stack, steam, far}.
func live() -> Dictionary:
	var out := {"stack":0,"steam":0,"far":0}
	for e: Emitter in _each:
		for i in range(NEAR_POOL+FAR_POOL):
			var o := i*16
			if now-e.buf[o+12] >= e.buf[o+9]: continue
			out[["stack","steam","far"][int(e.buf[o+14])]] += 1
	return out

## Train `i`'s MultiMesh (for the checks), or null.
func mesh_of(i: int) -> MultiMeshInstance3D:
	return null if i >= _each.size() else _each[i].mmi

## The engine's frame at odometer `d` on `track` (RailTrain `place`'s, car 0).
static func engine_pose(path: RefCounted, table: RefCounted, track: int, d: float) -> Transform3D:
	var long := float(RailTrain.CARS[0][1])
	var a: Transform3D = path.pose(table.s_of(d-RailTrain.BOGIE),track)
	var b: Transform3D = path.pose(table.s_of(d-long+RailTrain.BOGIE),track)
	var f := (a.origin-b.origin).normalized()
	var up := (a.basis.y+b.basis.y).normalized()
	up = (up-f*f.dot(up)).normalized()
	var z := -f
	return Transform3D(Basis(up.cross(z),up,z),(a.origin+b.origin)*0.5)

## True with the stack (a few metres back of the nose at odometer `d`) in a bore.
func _in_bore(table: RefCounted, d: float) -> bool:
	var p: RefCounted = trains.path
	if p == null or not p.has_method("kind"): return false
	return str(p.kind(table.s_of(d+_mouth.z))) == "tunnel"

## The engine model's empties, in its car's frame, read once.
static func _read_mouths(c0: Dictionary) -> void:
	_read = true
	var model: Node3D = c0.get("model")
	if model == null: return
	var top: Node3D = model.get_child(0) if model.get_child_count() > 0 else model
	var m := top.get_node_or_null("StackMouth") as Node3D
	if m != null: _mouth = top.transform*m.position
	for k in range(2):
		var s := top.get_node_or_null(["Steam_R","Steam_L"][k]) as Node3D
		if s != null: _steam[k] = top.transform*s.position

func _new_one() -> Emitter:
	var e := Emitter.new(_quad,_mat)
	e.mmi.name = "Puffs%d" % _each.size()
	root.add_child(e.mmi)
	e.far_t = randf()*FAR_EVERY.x
	return e

## A puff's disc, its corners at its centre for the shader to spread.
static func _disc() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

## A train's puffs: its MultiMesh and buffer (the near ring, then the far
## ring: NEAR_POOL and FAR_POOL), its rhythm's state.
class Emitter:
	var mmi: MultiMeshInstance3D
	var buf := PackedFloat32Array()
	var near := 0
	var far := 0
	var chuff := 0.0
	var beat := 0
	var effort := EFFORT_RUN
	var v := 0.0
	var idle := 0.0
	var steam := 0.0
	var side := 0
	var far_t := 0.0
	var dirty := false
	## The MultiMesh's box: grown by each puff let go, made again from the
	## live puffs every BOX_EVERY s.
	var box := AABB()
	var box_at := 0.0

	func _init(quad: Mesh, mat: Material) -> void:
		var n := NEAR_POOL+FAR_POOL
		buf.resize(n*16)
		for i in range(n): buf[i*16+12] = -1.0e5
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = n
		mm.buffer = buf
		mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visible = false

	## One puff let go at clock `now` into the near ring (the far ring if
	## `is_far`): its start, throw, radii, life, paleness, opacity, lid, role
	## and lift (the shader's header).
	func puff(now: float, is_far: bool, at: Vector3, throw: Vector3, r0: float, r1: float, life: float, pale: float, opacity: float, lid: float, role: float, lift: float) -> void:
		var i: int
		if is_far:
			i = NEAR_POOL+far
			far = (far+1)%FAR_POOL
		else:
			i = near
			near = (near+1)%NEAR_POOL
		var o := i*16
		buf[o] = throw.x
		buf[o+4] = throw.y
		buf[o+8] = throw.z
		buf[o+1] = r0
		buf[o+5] = r1
		buf[o+9] = life
		buf[o+2] = pale
		buf[o+6] = opacity
		buf[o+10] = lid
		buf[o+3] = at.x
		buf[o+7] = at.y
		buf[o+11] = at.z
		buf[o+12] = now
		buf[o+13] = randf()
		buf[o+14] = role
		buf[o+15] = lift
		var room := _room(at,is_far)
		box = room if box.size == Vector3.ZERO else box.merge(room)
		dirty = true

	## The buffer to the MultiMesh (whole), and its box.
	func write(now: float) -> void:
		dirty = false
		if now >= box_at:
			box_at = now+BOX_EVERY
			box = AABB()
			for i in range(NEAR_POOL+FAR_POOL):
				var o := i*16
				if now-buf[o+12] >= buf[o+9]: continue
				var room := _room(Vector3(buf[o+3],buf[o+7],buf[o+11]),i >= NEAR_POOL)
				box = room if box.size == Vector3.ZERO else box.merge(room)
		mmi.multimesh.buffer = buf
		mmi.multimesh.custom_aabb = box
		mmi.visible = box.size != Vector3.ZERO

	## The room a puff let go at `at` may be drawn in, over its life.
	static func _room(at: Vector3, is_far: bool) -> AABB:
		if not is_far: return AABB(at-Vector3.ONE*REACH,Vector3.ONE*REACH*2.0)
		return AABB(at-Vector3.ONE*FAR_REACH,Vector3(2.0,3.0,2.0)*FAR_REACH+Vector3.UP*FAR_LIFT*FAR_LIFE)
