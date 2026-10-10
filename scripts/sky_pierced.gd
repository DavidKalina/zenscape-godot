extends Node3D
## The pierced isles in the sky (scripts/pierced_isle.gd): now and then, far
## out in the open sky, one big island mass with holes right through it, a
## landmark to fly to and thread. Rarer than the clusters: at most one to a
## CELL-square cell (HOLDS of the cells), jittered in it, none within RING
## of the plate's first home, and each in clear air: ISLAND_CLEAR off an
## island's spot, WALL_CLEAR off the ranges, the walls and the band,
## HAZE_CLEAR inside the band's haze curve, TOWER_CLEAR off a cumulus
## tower, WONDER_CLEAR off a forested isle. The seeded islets and the
## clusters keep KEEP off each (`blocks`, `taken`), and the clouds part
## round it (`keep_spots`).
##
## To visit one: --pierced stands one near the home, on a ring NEAR_RING m
## out (further where that is taken), --pierced-seed=N lays it from seed N
## (NEAR_SEED otherwise), --no-pierced leaves the random ones out.
##   godot --path . -- --no-title --pierced
##
## Streaming: within VIEW of the eye an isle is planned on a worker (its
## plan, its lid islet, its rock near and far, its ruins), one at a time,
## nearest first; then stood up a part a frame within the sky's frame
## budget (scripts/sky_commits.gd): the lid (an islet of the islets', so the
## glide reads its top as a solid and the wanderer perches on it), the rock
## near and far (the far past PiercedMesh FAR), the ruins. Past FORGET it
## goes, never while perched on.
##
## The rock and the ruins are solid to the plane (`bump`, called after each
## glide step): its body, a wing-wide slab turned with its heading, pitch,
## bank and roll (probed at its middle, wingtips, nose and tail against the
## rock's field; as a box against the ruins' hulls, on RUIN_LAYER), pushed
## back out along the face, turned along it and slowed: bump and recover,
## never a crash. `solid` keeps the chase camera out of the rock.

const PiercedIsle = preload("res://scripts/pierced_isle.gd")
const PiercedMesh = preload("res://scripts/pierced_mesh.gd")
const PiercedRuins = preload("res://scripts/pierced_ruins.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyForestIsles = preload("res://scripts/sky_forest_isles.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")

## The cells: side (m), the share holding an isle, how far its spot may
## sit off the cell's middle (share of the cell), the salt.
const CELL := 3200.0
const HOLDS := 0.35
const JITTER := 0.3
const SALT := 5200
const TRIES := 24
## None of the random ones within RING of the plate's first home.
const RING := 1500.0
## The rim's height (home coordinates, m): high, so the holes stand clear
## of the cloud sea under it and the summit under the sky's ceiling.
const HOME_Y := Vector2(46.0,54.0)
## Kept clear (m): of an island's spot, the ranges, walls and band, the
## haze curve, a cumulus tower, a forested isle.
const ISLAND_CLEAR := 280.0
## --pierced's own, nearer (the home's ring is busy with islands).
const NEAR_ISLAND := 220.0
const WALL_CLEAR := 180.0
const HAZE_CLEAR := 260.0
const TOWER_CLEAR := 300.0
const WONDER_CLEAR := 160.0
## The islets and clusters keep this far off an isle's middle.
const KEEP := 270.0
## --pierced: the ring round the home, its step out, places tried round
## each, the seed.
const NEAR_RING := 440.0
const NEAR_STEP := 50.0
const NEAR_STEPS := 24
const NEAR_TURNS := 36
const NEAR_SEED := 3
## Planned within VIEW of the eye, let go past FORGET; checked every CHECK s.
const VIEW := 1900.0
const FORGET := 2250.0
const CHECK := 0.5
## The bump: how near the rock's field the plane's body may come (m: the
## drawn faces stand up to about this far off it), the share of its speed
## a bump keeps, the plane's body for the ruins' hulls (its wings' span,
## a thin slab, its length).
const MARGIN := 0.6
const BUMP_KEEP := 0.55
const BUMP_BODY := Vector3(PlaneFigure.SPAN,0.3,1.2)
## The ruins' hulls' physics layer (the bump asks only it).
const RUIN_LAYER := 1 << 19
## The rock fades in over FADE_IN s as the lid does (SkyIslets FADE_IN).
const FADE_IN := 1.4

## Every isle's middle (home coordinates) laid out at the last `reset`, for
## the others to keep clear of (`blocks`).
static var taken: Array[Vector3] = []

## --pierced-trace: each step of making and standing one, printed.
static func _trace(what: String) -> void:
	if "--pierced-trace" in preload("res://scripts/launch_args.gd").user_args(): print("PIERCED trace ",what)

static func forced() -> bool:
	return "--pierced" in preload("res://scripts/launch_args.gd").user_args()

static func random_enabled() -> bool:
	return not "--no-pierced" in preload("res://scripts/launch_args.gd").user_args()

static func forced_seed() -> int:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--pierced-seed="): return int(a.trim_prefix("--pierced-seed="))
	return NEAR_SEED

## True if a home point stands within KEEP (and `margin`) of an isle.
static func blocks(home: Vector3, margin := 0.0) -> bool:
	for s: Vector3 in taken:
		if Vector2(s.x-home.x,s.z-home.z).length() < KEEP+margin: return true
	return false

## The islets (SkyIslets) its lid stands in.
var islets: Node3D
var cells: SkyCells
## Every isle's spot: {key, at (home), seed}.
var spots: Array = []
## Isles planned or standing, by key: {spot, task, out, plan, stage (the
## parts still to stand), b (the lid's built record), rock, far, ruins, age}.
var isles := {}
var with_forced := false
var with_random := true
var seed_value := NEAR_SEED
## Bumps since the start (tests, the record).
var bumps := 0
var _since := CHECK
var _palette := {}

func _init() -> void:
	name = "SkyPierced"
	with_forced = forced()
	with_random = random_enabled()
	seed_value = forced_seed()

func _exit_tree() -> void:
	clear()
	PiercedMesh.release()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE: _wait_all()

func _wait_all() -> void:
	for key in isles:
		var s: Dictionary = isles[key]
		if int(s.get("task",-1)) >= 0:
			WorkerThreadPool.wait_for_task_completion(s.task)
			s.task = -1

func clear() -> void:
	_wait_all()
	for key in isles.keys(): _forget(key)
	isles.clear()

## Lays out every isle's spot over the cells (after the islets' `reset`,
## before the clusters'), and keeps the islets off them.
func reset(new_cells: SkyCells) -> void:
	clear()
	cells = new_cells
	spots.clear()
	taken.clear()
	_palette = islets.prepare_authored()
	PiercedRuins.prepare()
	PiercedMesh.material()
	var made: Array = []
	if with_forced:
		var s: Variant = near_spot(seed_value)
		if s != null: made.append(s)
	if with_random:
		var reach := ceili(4800.0/CELL)
		for x in range(-reach,reach+1):
			for z in range(-reach,reach+1):
				var s: Variant = spot_of(Vector2i(x,z))
				if s == null: continue
				if made.any(func(f: Dictionary) -> bool: return _flat(f.at,s.at) < CELL*0.5): continue
				made.append(s)
	spots = made
	for s: Dictionary in spots:
		taken.append(s.at)
		islets.keep_clear.append(Vector3(s.at.x,s.at.z,KEEP))
	_since = CHECK

## True where an isle's middle may stand: clear of the islands' spots, the
## ranges, walls and band, the haze, the towers and the forested isles.
## `why` tallies what stood in the way.
func clear_at(here: Vector3, why := {}, island := ISLAND_CLEAR) -> bool:
	var blocked := ""
	if cells != null and not cells.spots_near(here,island).is_empty(): blocked = "island"
	elif SkyPeaks.blocks(here,WALL_CLEAR): blocked = "range"
	elif SkyTowers.blocks(here,TOWER_CLEAR): blocked = "tower"
	elif SkyForestIsles.blocks(here,WONDER_CLEAR): blocked = "forested isle"
	elif in_haze(here): blocked = "haze"
	if blocked.is_empty(): return true
	why[blocked] = int(why.get(blocked,0))+1
	return false

## A cell's isle ({key, at, seed}), or null.
func spot_of(cell: Vector2i) -> Variant:
	if SkyCells.noise(cell,SALT) >= HOLDS: return null
	var middle := (Vector2(cell)+Vector2.ONE*0.5)*CELL
	for k in range(TRIES):
		var off := Vector2(SkyCells.noise(cell,SALT+10+k*2)-0.5,SkyCells.noise(cell,SALT+11+k*2)-0.5)*2.0*JITTER*CELL
		var here := Vector3(middle.x+off.x,lerpf(HOME_Y.x,HOME_Y.y,SkyCells.noise(cell,SALT+3)),middle.y+off.y)
		if Vector2(here.x,here.z).length() < RING: continue
		if not clear_at(here): continue
		return {"key":"%d,%d" % [cell.x,cell.y],"at":here,"seed":int(SkyCells.noise(cell,SALT+5)*16777216.0)}
	return null

## The isle stood near the home (--pierced): round a ring from NEAR_RING
## out, the first place clear.
func near_spot(seed_: int) -> Variant:
	var why := {}
	for step in range(NEAR_STEPS):
		for k in range(NEAR_TURNS):
			var turn := 0.9+TAU/NEAR_TURNS*ceilf(k/2.0)*(1.0 if k % 2 == 0 else -1.0)
			var here := Vector3(cos(turn),0.0,sin(turn))*(NEAR_RING+step*NEAR_STEP)+Vector3.UP*(HOME_Y.x+HOME_Y.y)*0.5
			if not clear_at(here,why,NEAR_ISLAND): continue
			return {"key":"near","at":here,"seed":seed_}
	push_warning("--pierced: no clear room near the home %s" % why)
	return null

static func in_haze(home: Vector3) -> bool:
	var flat := Vector2(home.x,home.z)
	if flat.length() < 1.0: return false
	return SkyWorld.haze_share(flat*(1.0+HAZE_CLEAR/flat.length())) > 0.0

## The clouds part round each standing isle (SkyClouds `keep_off`).
func keep_spots(eye := Vector3.ZERO) -> Array:
	var out := []
	for key in isles:
		var s: Dictionary = isles[key]
		if s.get("plan") == null: continue
		var at: Vector3 = position+(s.spot.at as Vector3)+(cells.origin if cells != null else Vector3.ZERO)
		out.append(Vector4(at.x,at.z,0.0,float((s.plan.bounds() as AABB).size.x)*0.5+40.0))
	out.sort_custom(func(a: Vector4, c: Vector4) -> bool: return Vector2(a.x-eye.x,a.y-eye.z).length() < Vector2(c.x-eye.x,c.y-eye.z).length())
	return out

# --- Streaming ----------------------------------------------------------------------

## Each frame of the glide (the eye in the islands' frame): plan the near,
## stand what is made, let the far go, fade in the new.
func advance(delta: float, eye: Vector3) -> void:
	if cells == null: return
	var home := eye-cells.origin
	_since += delta
	if _since >= CHECK:
		_since = 0.0
		_survey(home)
	_stand_some()
	for key in isles:
		var s: Dictionary = isles[key]
		if float(s.get("age",FADE_IN)) < FADE_IN:
			s.age = float(s.age)+delta
			_fade(s)

func _survey(home: Vector3) -> void:
	for key in isles.keys():
		var s: Dictionary = isles[key]
		if _flat(s.spot.at,home) > FORGET and not _perched(s): _forget(key)
	for key in isles:
		if int(isles[key].get("task",-1)) >= 0: return
	var nearest: Variant = null
	var best := INF
	for s: Dictionary in spots:
		if isles.has(s.key): continue
		var d := _flat(s.at,home)
		if d < VIEW and d < best:
			best = d
			nearest = s
	if nearest != null: _plan(nearest)

## Plans an isle on a worker: its plan, its lid islet, its rock near and
## far, its ruins.
func _plan(s: Dictionary) -> void:
	var out := {}
	var palette := _palette
	var home_y: float = (s.at as Vector3).y
	var task := WorkerThreadPool.add_task(func() -> void: make(int(s.seed),palette,home_y,out),false,"Pierced isle")
	isles[s.key] = {"spot":s,"task":task,"out":out,"stage":[],"age":FADE_IN}

## Everything an isle is made of, safe on a worker once `prepare_authored`
## and PiercedRuins `prepare` have run: {plan, lid (SkyIslets `make`), near,
## far (PiercedMesh arrays), ruins (a Node3D, not in the tree), usec}.
static func make(seed_: int, palette: Dictionary, home_y: float, out: Dictionary) -> void:
	var began := Time.get_ticks_usec()
	_trace("make %d: planning" % seed_)
	var plan: RefCounted = PiercedIsle.make(seed_)
	out.plan = plan
	var t := Time.get_ticks_usec()
	_trace("make %d: lid" % seed_)
	out.lid = SkyIslets.make(plan.lid_seed(),plan.recipe,palette,home_y)
	# The lid's wall in the rock's colours.
	out.lid.meshes.sides = PiercedMesh.mesh(PiercedMesh.colour(plan,out.lid.sides))
	var lid_usec := Time.get_ticks_usec()-t
	var near_stats := {}
	var far_stats := {}
	_trace("make %d: rock" % seed_)
	out.near = PiercedMesh.mesh(PiercedMesh.arrays(plan,PiercedMesh.CELL,near_stats))
	out.far = PiercedMesh.mesh(PiercedMesh.arrays(plan,PiercedMesh.FAR_CELL,far_stats,false))
	_trace("make %d: ruins" % seed_)
	out.ruins = PiercedRuins.build(plan,out.lid.shape)
	_trace("make %d: made" % seed_)
	out.stats = {"near":near_stats,"far":far_stats,"lid_usec":lid_usec}
	out.usec = Time.get_ticks_usec()-began

func _stand_some() -> void:
	for key in isles:
		var s: Dictionary = isles[key]
		if int(s.task) >= 0:
			if not WorkerThreadPool.is_task_completed(s.task): continue
			WorkerThreadPool.wait_for_task_completion(s.task)
			s.task = -1
			s.plan = s.out.plan
			s.stage = ["lid","rock","far","ruins"]
		if (s.stage as Array).is_empty() or not SkyCommits.open(): continue
		var began := Time.get_ticks_usec()
		_stand(s,(s.stage as Array).pop_front())
		SkyCommits.spend("pierced",Time.get_ticks_usec()-began)
		return

## Stands one part of an isle.
func _stand(s: Dictionary, part: String) -> void:
	var out: Dictionary = s.out
	match part:
		"lid":
			var b: Dictionary = islets.stand("Pierced_%s" % str(s.spot.key).replace(",","_"),s.spot.at,out.lid)
			b.fixed = true
			b.age = 0.0
			b.pierced = s.spot.key
			islets.built[_built_key(s.spot.key)] = b
			s.b = b
			s.age = 0.0
			# The lid's wall in the rock's own colours and stone.
			var sides := (b.node as Node3D).get_node_or_null("Sides") as MeshInstance3D
			if sides != null: sides.material_override = PiercedMesh.material()
		"rock":
			var rock := MeshInstance3D.new()
			rock.name = "Rock"
			rock.mesh = out.near
			rock.material_override = PiercedMesh.material()
			rock.visibility_range_end = PiercedMesh.FAR+40.0
			rock.visibility_range_end_margin = 40.0
			rock.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			rock.set_meta("skip_reflection",true)
			(s.b.node as Node3D).add_child(rock)
			s.rock = rock
		"far":
			var far := MeshInstance3D.new()
			far.name = "RockFar"
			far.mesh = out.far
			far.material_override = PiercedMesh.material()
			far.visibility_range_begin = PiercedMesh.FAR
			far.visibility_range_begin_margin = 40.0
			far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			far.set_meta("skip_reflection",true)
			(s.b.node as Node3D).add_child(far)
			s.far = far
		"ruins":
			var ruins: Node3D = out.ruins
			if ruins != null:
				(s.b.node as Node3D).add_child(ruins)
				s.ruins = ruins
	_fade(s)

func _fade(s: Dictionary) -> void:
	var t := 1.0-smoothstep(0.0,1.0,clampf(float(s.get("age",FADE_IN))/FADE_IN,0.0,1.0))
	for part in ["rock","far"]:
		var g: Variant = s.get(part)
		if g is GeometryInstance3D and is_instance_valid(g): (g as GeometryInstance3D).transparency = t

## Stands every planned isle whole at once (tests, probes, captures). Never
## while a worker is still making one in a run that draws no frames (see
## `plan_now`).
func flush() -> void:
	for key in isles:
		var s: Dictionary = isles[key]
		if int(s.task) >= 0:
			WorkerThreadPool.wait_for_task_completion(s.task)
			s.task = -1
			s.plan = s.out.plan
			s.stage = ["lid","rock","far","ruins"]
		while not (s.stage as Array).is_empty():
			var part: String = (s.stage as Array).pop_front()
			_trace("stand %s" % part)
			_stand(s,part)
		s.age = FADE_IN
		_fade(s)
	_trace("islets flush")
	islets.flush()
	_trace("flushed")

## Plans (now, on this thread's wait) the isle at `key` and stands it.
## Made here, on this thread; one a worker was still making is let go.
func plan_now(key: String) -> void:
	for s: Dictionary in spots:
		if s.key != key: continue
		if isles.has(key) and int(isles[key].get("task",-1)) >= 0: _forget(key)
		if isles.has(key): break
		var out := {}
		make(int(s.seed),_palette,(s.at as Vector3).y,out)
		isles[key] = {"spot":s,"task":-1,"out":out,"plan":out.plan,"stage":["lid","rock","far","ruins"],"age":FADE_IN}
	flush()

func _forget(key: String) -> void:
	var s: Dictionary = isles[key]
	if int(s.get("task",-1)) >= 0: WorkerThreadPool.wait_for_task_completion(s.task)
	var b: Variant = s.get("b")
	if b is Dictionary:
		if is_instance_valid(b.node): (b.node as Node3D).queue_free()
		islets.built.erase(_built_key(s.spot.key))
	elif s.out.get("ruins") is Node3D and is_instance_valid(s.out.ruins):
		(s.out.ruins as Node3D).free()
	isles.erase(key)

func _perched(s: Dictionary) -> bool:
	var b: Variant = s.get("b")
	return islets.pinned != null and b is Dictionary and b.node == islets.pinned

static func _built_key(key: String) -> String:
	return "pierced:%s" % key

## The standing isles, as {key: record} (tests).
func standing() -> Dictionary:
	var out := {}
	for key in isles:
		if isles[key].get("b") is Dictionary: out[key] = isles[key]
	return out

# --- Solid to the plane ---------------------------------------------------------------

## The rock's field at a point of the islands' frame (negative in rock), the
## nearest standing isle's; INF far from all.
func field_at(point: Vector3) -> float:
	var s := _near(point)
	if s.is_empty(): return INF
	return float(s.plan.field(point-islets.place(s.b)))

## True in the rock (the chase camera keeps out of it).
func solid(point: Vector3) -> bool:
	return field_at(point) < 0.3

## The standing isle whose box holds a point of the islands' frame, or {}.
func _near(point: Vector3) -> Dictionary:
	for key in isles:
		var s: Dictionary = isles[key]
		if not s.get("b") is Dictionary or not is_instance_valid(s.b.node): continue
		var local: Vector3 = point-islets.place(s.b)
		if (s.plan.bounds() as AABB).grow(4.0).has_point(local): return s
	return {}

## Bump and recover: after a glide step, if the plane's body is in the rock
## (or a ruin), it is put back out along the face, turned along it, its
## pitch eased and a share of its speed lost. `frame` is the islands'
## global transform (the ruins' hulls are asked in the world's). True if it
## bumped.
func bump(glide: RefCounted, frame := Transform3D.IDENTITY) -> bool:
	var s := _near(glide.position)
	if s.is_empty(): return false
	var plan: RefCounted = s.plan
	var place: Vector3 = islets.place(s.b)
	var turn := body_turn(glide)
	var at: Vector3 = glide.position
	var worst := INF
	var worst_at := at
	for p: Vector3 in probes(glide):
		var f: float = plan.field(p-place)
		if f < worst:
			worst = f
			worst_at = p
	var normal := Vector3.ZERO
	var push := 0.0
	if worst < MARGIN:
		normal = plan.normal(worst_at-place)
		push = MARGIN-worst+0.05
	else:
		var hit := _ruin_hit(at,turn,frame)
		if hit.is_empty(): return false
		normal = frame.basis.inverse()*(hit.normal as Vector3)
		if normal.length() < 0.5: normal = -(glide.forward() as Vector3)
		normal = normal.normalized()
		push = 0.25
	bumps += 1
	glide.position = at+normal*push
	var way: Vector3 = glide.forward()
	var along := way-normal*way.dot(normal)
	if along.length() > 0.05:
		along = along.normalized()
		var flat := Vector2(along.x,along.z)
		if flat.length() > 0.05: glide.heading = atan2(-flat.x,-flat.y)
		glide.pitch = clampf(asin(clampf(along.y,-1.0,1.0)),-0.6,0.6)
	var least: float = (glide.get_script() as Script).get_script_constant_map().get("SLOW",3.5)
	glide.speed = maxf(least,float(glide.speed)*BUMP_KEEP)
	glide.velocity = glide.forward()*float(glide.speed)
	return true

## The plane's body turned as it flies: heading, pitch, bank and roll.
static func body_turn(glide: RefCounted) -> Basis:
	var spin: Variant = glide.get("spin")
	return PlaneFigure.pose(Vector3.ZERO,float(glide.heading),float(glide.pitch),float(glide.bank)+(float(spin) if spin != null else 0.0)).basis

## Where the plane's body is probed against the rock: its middle, its
## wingtips, its nose and its tail (the glide's frame).
static func probes(glide: RefCounted) -> Array[Vector3]:
	var turn := body_turn(glide)
	var at: Vector3 = glide.position
	var out: Array[Vector3] = []
	for probe: Vector3 in [Vector3.ZERO,Vector3(BUMP_BODY.x*0.5,0,0),Vector3(-BUMP_BODY.x*0.5,0,0),Vector3(0,0,-BUMP_BODY.z*0.5),Vector3(0,0,BUMP_BODY.z*0.5)]:
		out.append(at+turn*probe)
	return out

## The ruins' hull the plane's body (BUMP_BODY at `at`, turned by `turn`, in
## the islands' frame) sits in: {normal (world)} or {}.
func _ruin_hit(at: Vector3, turn: Basis, frame: Transform3D) -> Dictionary:
	var world := get_world_3d()
	if world == null: return {}
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = BUMP_BODY
	query.shape = box
	query.collision_mask = RUIN_LAYER
	query.transform = frame*Transform3D(turn,at)
	return world.direct_space_state.get_rest_info(query)

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
