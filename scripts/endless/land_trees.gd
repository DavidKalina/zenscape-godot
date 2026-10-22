extends Node3D
## The endless land's spruce forests (docs/design/endless-flight/
## forests-handoff.md): where they stand is scripts/endless/tree_plan.gd, a
## pure function of the seed and a cell; this streams them round the eye.
##
## Three rings, each the one before handing over with no seam:
##   near  the spruce family (HeroTrees, in the islets' pine materials:
##         SkyIslets `_tree_parts`), a MultiMesh a BLOCK m square, part and
##         variant, drawn while the block's middle is within NEAR_END m;
##         their shadows cast by the faceted crowns (one batch a block,
##         SHADOWS_ONLY: the full crowns' shadows cost about 6 ms a frame;
##         --no-tree-shadows none);
##   mid   FarTrees' faceted crown, one MultiMesh a block, each tree shown
##         from MID.x to MID.z m (shaders/endless_tree_far.gdshader: by its
##         own distance, so it stands inside the near tree where both draw);
##   far   the same crown for TreePlan `far_cell`'s thinned, grown trees,
##         one MultiMesh a FAR_CELL square, FAR.x to FAR.z m.
## Blocks and far cells are planned on WorkerThreadPool tasks (TASKS at
## once, the near blocks first) and stood on the main thread within
## COMMIT_BUDGET ms a frame.
##
## The flight's solid: each tree is a cone for SkyGlide's `ground` (`ground`
## raises the land under the plane to the tree's top there): its crown's
## reach (CROWN_SOLID of it) plus WING_SOLID of the plane's half span, so a
## wingtip brushing the outer needles passes and anything more turns it
## aside as a cliff's face does (the arches' legs do the same). `inside`
## for the rolling plane. Plan cells within COLLIDE m of the plane also
## stand a convex collider a tree on layer 1 (the wheels, whoever walks).
##
## Flags: --no-trees, --forest=X (the woods' share: 1; 0 none; 1.5 more),
## --forest-meadows=X (how far the woods come out onto the meadows as
## groves, 1; 0 keeps every meadow and flat open), --no-forest-floor (no
## shade sheet under the woods).

const Field = preload("res://scripts/endless/land_field.gd")
const Plan = preload("res://scripts/endless/tree_plan.gd")
const HeroTrees = preload("res://scripts/hero_trees.gd")
const FarTrees = preload("res://scripts/far_trees.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const LandArches = preload("res://scripts/endless/land_arches.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const FAR_SHADER = preload("res://shaders/endless_tree_far.gdshader")
const FLOOR_SHADER = preload("res://shaders/endless_forest_floor.gdshader")

## The near and mid rings' square (m; whole plan cells), and the ring
## distances (m): the near trees while the block's middle is within
## NEAR_END (crossing over NEAR_MARGIN); the crowns of the mid ring (x from,
## y growing in over, z to, w sinking over), of the far ring likewise.
const BLOCK := 256.0
const NEAR_END := 430.0
const NEAR_MARGIN := 40.0
const MID := Vector4(190.0,30.0,1500.0,120.0)
const FAR := Vector4(1380.0,120.0,6200.0,900.0)
## The mid ring's crowns stand this much smaller than their tree, inside it.
const MID_SIZE := 0.94
## Blocks are built out to MID.z+BLOCK, far cells to FAR.z+FAR_CELL/2;
## replanned every REPLAN m; TASKS at once; COMMIT_BUDGET ms a frame.
const REPLAN := 48.0
const TASKS := 3
const COMMIT_BUDGET := 1.5
const PRIME := 420.0
## The flight's solid: the crown's reach times CROWN_SOLID plus WING_SOLID
## of the plane's half span; the bucket (m) the trees are looked up by.
const CROWN_SOLID := 0.85
const WING_SOLID := 0.5
const BUCKET := 16.0
## Plan cells within this of the plane (m, to the cell) stand colliders.
const COLLIDE := 70.0
const LAYER := 1
## The crowns' tint over the islets' (each tree a little either way), and
## the far crowns' colour (linear) and how much of their baked shade shows.
const TINT_SPREAD := Vector2(0.86,1.04)
const FAR_ALBEDO := Color(0.3,0.42,0.24)
const FAR_BAKED := 0.75
## The forest floor (shaders/endless_forest_floor.gdshader): a sheet over
## the land under the woods, its weight the dense woods' (after lanes and
## clearings) and TreePlan.FLOOR_GROVE of a grove's clump; a vertex every
## FLOOR_STEP m (the far cells' TreePlan.FAR_SLOT), drawn to MID.z m by the
## blocks and on by the far cells. --no-forest-floor leaves it out.
const FLOOR_STEP := 16.0
const FLOOR_COLOUR := Color(0.2,0.29,0.14)
const FLOOR_STRENGTH := 0.82

var seed := 1
var share := 1.0
var meadows := 1.0
var enabled := true
var stats := {"blocks":0,"far":0,"trees":0,"far_trees":0,"plan_ms":0.0,"plans":0,"slowest_plan_ms":0.0,"slowest_commit_ms":0.0,"slowest_commit":"","colliders":0}

var _parts: Array = []        # variant -> [trunk mesh, crown mesh]
var _dims: Array = []         # variant -> Vector3(crown radius, top, bottom) at scale 1
var _tint := Color.WHITE
var _crown: Mesh              # the far crown (FarTrees proxy of the mature crown)
var _crown_fit: Array = []    # variant -> Vector3(xz scale, y scale, y offset) onto _crown
var _mid_material: ShaderMaterial
var _shade_material: StandardMaterial3D
var _far_material: ShaderMaterial
var _arch_flags := {}
var _floor := true
var _shadows := not ("--no-tree-shadows" in LaunchArgs.user_args())
var _near_floor: ShaderMaterial
var _far_floor: ShaderMaterial

var _blocks := {}             # Vector2i -> {node, cells: {Vector2i: {trees, buckets}}}
var _far := {}                # Vector2i -> node
var _pending := {}            # String key -> task id
var _done: Array = []
var _lock := Mutex.new()
var _queue: Array = []
var _planned_at := Vector3.INF
var _quit := false
var _eye := Vector3.ZERO
var _bodies := {}             # plan cell -> StaticBody3D

## The flags: {on, share, meadows}.
static func flags() -> Dictionary:
	var out := {"on":true,"share":1.0,"meadows":1.0,"floor":true}
	for a: String in LaunchArgs.user_args():
		if a == "--no-trees": out.on = false
		elif a.begins_with("--forest="): out.share = maxf(0.0,float(a.get_slice("=",1)))
		elif a.begins_with("--forest-meadows="): out.meadows = maxf(0.0,float(a.get_slice("=",1)))
		elif a == "--no-forest-floor": out.floor = false
	if out.share <= 0.0: out.on = false
	return out

func setup(land_seed: int) -> void:
	seed = land_seed
	var f := flags()
	enabled = f.on
	share = f.share
	meadows = f.meadows
	_floor = f.floor
	_arch_flags = LandArches.flags()
	if not enabled: return
	var SkyIslets: GDScript = load("res://scripts/sky_islets.gd")
	for v in HeroTrees.SPRUCE.size():
		var parts: Array = SkyIslets.call("_tree_parts",v)
		_parts.append(parts)
		var box := (parts[1] as Mesh).get_aabb()
		_dims.append(Vector3(maxf(box.size.x,box.size.z)*0.5,box.end.y,maxf(box.position.y,0.0)))
	_tint = SkyIslets.get("_canopy_tint")
	_crown = FarTrees.proxy("tree:spruce-endless-canopies",_parts[0][1])
	var base: Vector3 = _dims[0]
	for d: Vector3 in _dims:
		var sy := (d.y-d.z)/maxf(base.y-base.z,0.01)
		_crown_fit.append(Vector3(d.x/base.x,sy,d.z-base.z*sy))
	_mid_material = _far_shader(MID)
	_shade_material = StandardMaterial3D.new()
	_shade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_far_material = _far_shader(FAR)
	_near_floor = _floor_shader(Vector4(-1.0,1.0,MID.z,MID.w))
	_far_floor = _floor_shader(Vector4(MID.z-MID.w,MID.w,FAR.z,FAR.w))

func _floor_shader(band: Vector4) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLOOR_SHADER
	m.set_shader_parameter("band",band)
	m.set_shader_parameter("colour",FLOOR_COLOUR)
	m.set_shader_parameter("strength",FLOOR_STRENGTH)
	return m

func _far_shader(band: Vector4) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FAR_SHADER
	m.set_shader_parameter("band",band)
	m.set_shader_parameter("albedo",FAR_ALBEDO)
	m.set_shader_parameter("baked",FAR_BAKED)
	return m

func _plan_for() -> RefCounted:
	var p: RefCounted = Plan.new(seed,share,_dims,_arch_flags)
	p.meadows = meadows
	return p

func _exit_tree() -> void:
	_quit = true
	for id: int in _pending.values(): WorkerThreadPool.wait_for_task_completion(id)

## Stands the blocks within PRIME m of `at` now, on this thread.
func prime(at: Vector3) -> void:
	if not enabled: return
	_eye = at
	var field := Field.new(seed)
	var plan := _plan_for()
	for key: Vector2i in _wanted_blocks(at,PRIME):
		if _blocks.has(key): continue
		_commit(_build_block(key,field,plan))
	_planned_at = Vector3.INF

## One frame: replanned if the eye has moved, tasks asked, finished blocks
## stood within the budget, colliders round `plane_at`.
func step(at: Vector3, plane_at: Vector3) -> void:
	if not enabled: return
	_eye = at
	if _planned_at == Vector3.INF or Vector2(at.x-_planned_at.x,at.z-_planned_at.z).length() > REPLAN:
		_planned_at = at
		_plan(at)
	for key: String in _pending.keys():
		var id: int = _pending[key]
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_pending.erase(key)
	while _pending.size() < TASKS and not _queue.is_empty():
		var job: Array = _queue.pop_front()
		var key: Vector2i = job[1]
		var name := "%s%d_%d" % [job[0],key.x,key.y]
		if _pending.has(name): continue
		if job[0] == "b" and _blocks.has(key): continue
		if job[0] == "f" and _far.has(key): continue
		_pending[name] = WorkerThreadPool.add_task(_task.bind(String(job[0]),key))
	var began := Time.get_ticks_usec()
	while true:
		_lock.lock()
		var next: Variant = _done.pop_front() if not _done.is_empty() else null
		_lock.unlock()
		if next == null: break
		var t0 := Time.get_ticks_usec()
		_commit(next)
		var took := (Time.get_ticks_usec()-t0)/1000.0
		if took > stats.slowest_commit_ms:
			stats.slowest_commit_ms = took
			stats.slowest_commit = "%s %s, %d trees" % [next.kind,next.key,int(next.n)]
		if (Time.get_ticks_usec()-began)/1000.0 > COMMIT_BUDGET: break
	_collide(plane_at)

# --- Streaming ---------------------------------------------------------------

func _block_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x/BLOCK),floori(z/BLOCK))

func _rect_distance(x0: float, z0: float, size: float, at: Vector3) -> float:
	var dx := maxf(maxf(x0-at.x,at.x-(x0+size)),0.0)
	var dz := maxf(maxf(z0-at.z,at.z-(z0+size)),0.0)
	return sqrt(dx*dx+dz*dz)

func _wanted_blocks(at: Vector3, reach: float) -> Array:
	var out: Array = []
	var c := _block_of(at.x,at.z)
	var r := int(ceil(reach/BLOCK))+1
	for dz in range(-r,r+1):
		for dx in range(-r,r+1):
			var key := c+Vector2i(dx,dz)
			if _rect_distance(key.x*BLOCK,key.y*BLOCK,BLOCK,at) <= reach: out.append(key)
	out.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return _rect_distance(p.x*BLOCK,p.y*BLOCK,BLOCK,at) < _rect_distance(q.x*BLOCK,q.y*BLOCK,BLOCK,at))
	return out

func _wanted_far(at: Vector3, reach: float) -> Array:
	var out: Array = []
	var c := Vector2i(floori(at.x/Plan.FAR_CELL),floori(at.z/Plan.FAR_CELL))
	var r := int(ceil(reach/Plan.FAR_CELL))+1
	for dz in range(-r,r+1):
		for dx in range(-r,r+1):
			var key := c+Vector2i(dx,dz)
			if _rect_distance(key.x*Plan.FAR_CELL,key.y*Plan.FAR_CELL,Plan.FAR_CELL,at) <= reach: out.append(key)
	out.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return _rect_distance(p.x*Plan.FAR_CELL,p.y*Plan.FAR_CELL,Plan.FAR_CELL,at) < _rect_distance(q.x*Plan.FAR_CELL,q.y*Plan.FAR_CELL,Plan.FAR_CELL,at))
	return out

## The queue: the blocks out to the mid ring's end, nearest first, with the
## far cells after the blocks within the near ring.
func _plan(at: Vector3) -> void:
	_queue.clear()
	var blocks := _wanted_blocks(at,MID.z)
	var fars := _wanted_far(at,FAR.z)
	var near: Array = []
	var rest: Array = []
	for key: Vector2i in blocks:
		if _blocks.has(key): continue
		if _rect_distance(key.x*BLOCK,key.y*BLOCK,BLOCK,at) <= NEAR_END: near.append(["b",key])
		else: rest.append(["b",key])
	var far_jobs: Array = []
	for key: Vector2i in fars:
		if not _far.has(key): far_jobs.append(["f",key])
	# The near blocks, then blocks and far cells taking turns.
	_queue.append_array(near)
	var i := 0
	var j := 0
	while i < rest.size() or j < far_jobs.size():
		if i < rest.size():
			_queue.append(rest[i])
			i += 1
		if j < far_jobs.size():
			_queue.append(far_jobs[j])
			j += 1
	for key: Vector2i in _blocks.keys():
		if _rect_distance(key.x*BLOCK,key.y*BLOCK,BLOCK,at) > MID.z+BLOCK: _free_block(key)
	for key: Vector2i in _far.keys():
		if _rect_distance(key.x*Plan.FAR_CELL,key.y*Plan.FAR_CELL,Plan.FAR_CELL,at) > FAR.z+Plan.FAR_CELL*0.5:
			var gone: MultiMeshInstance3D = _far[key]
			stats.far_trees -= gone.multimesh.instance_count
			gone.queue_free()
			_far.erase(key)
			stats.far = _far.size()

func _task(kind: String, key: Vector2i) -> void:
	if _quit: return
	var field := Field.new(seed)
	var plan := _plan_for()
	var result: Dictionary = _build_block(key,field,plan) if kind == "b" else _build_far(key,field,plan)
	_lock.lock()
	_done.append(result)
	_lock.unlock()

# --- Building (on a worker) ------------------------------------------------------

## A block's trees: its plan cells' trees, the near batches' buffers (per
## variant and part), the mid crowns' buffer and each cell's lookup.
func _build_block(key: Vector2i, field: RefCounted, plan: RefCounted) -> Dictionary:
	var began := Time.get_ticks_usec()
	var per := int(BLOCK/Plan.CELL)
	var all: PackedFloat32Array = plan.area(field,key.x*BLOCK,key.y*BLOCK,BLOCK)
	var split := {}
	for q in range(0,all.size(),Plan.STRIDE):
		var ck := Plan.cell_of(all[q],all[q+2])
		if not split.has(ck): split[ck] = PackedFloat32Array()
		var list: PackedFloat32Array = split[ck]
		list.append_array(all.slice(q,q+Plan.STRIDE))
		split[ck] = list
	var cells := {}
	for j in per:
		for i in per:
			var ck := Vector2i(key.x*per+i,key.y*per+j)
			cells[ck] = _lookup(ck,split.get(ck,PackedFloat32Array()))
	var n := all.size()/Plan.STRIDE
	var variants := _dims.size()
	var near: Array = []
	for v in variants: near.append([PackedFloat32Array(),PackedFloat32Array(),0])
	var mid := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed,key.x,key.y,"trees"])
	for t in n:
		var q := t*Plan.STRIDE
		var at := Vector3(all[q],all[q+1],all[q+2])
		var sc := all[q+3]
		var wide := all[q+4]
		var yaw := all[q+5]
		var v := int(all[q+6])
		var basis := Basis(Vector3.UP,yaw).scaled(Vector3(sc*wide,sc,sc*wide))
		var tone := _tint*rng.randf_range(TINT_SPREAD.x,TINT_SPREAD.y)
		var slot: Array = near[v]
		_put(slot[0],basis,at,Color.WHITE)
		_put(slot[1],basis,at,tone)
		slot[2] = int(slot[2])+1
		var fit: Vector3 = _crown_fit[v]
		var cb := Basis(Vector3.UP,yaw).scaled(Vector3(sc*wide*fit.x,sc*fit.y,sc*wide*fit.x)*MID_SIZE)
		_put(mid,cb,at+Vector3(0.0,fit.z*sc,0.0),Color(tone.r/_tint.r,tone.g/_tint.g,tone.b/_tint.b))
	var ground: Dictionary = _floor_arrays(plan.floor_grid(field,key.x*BLOCK,key.y*BLOCK,BLOCK,FLOOR_STEP)) if _floor else {}
	var ms := (Time.get_ticks_usec()-began)/1000.0
	return {"kind":"b","key":key,"cells":cells,"near":near,"mid":mid,"n":n,"floor":ground,"ms":ms}

## The far cell's crowns' buffer.
func _build_far(key: Vector2i, field: RefCounted, plan: RefCounted) -> Dictionary:
	var began := Time.get_ticks_usec()
	var far: Dictionary = plan.far_cell(field,key.x,key.y)
	var trees: PackedFloat32Array = far.trees
	var n := trees.size()/Plan.STRIDE
	var buf := PackedFloat32Array()
	for t in n:
		var q := t*Plan.STRIDE
		var v := int(trees[q+6])
		var fit: Vector3 = _crown_fit[v]
		var sc := trees[q+3]
		var wide := trees[q+4]
		var cb := Basis(Vector3.UP,trees[q+5]).scaled(Vector3(sc*wide*fit.x,sc*fit.y,sc*wide*fit.x))
		var shade := lerpf(TINT_SPREAD.x,TINT_SPREAD.y,fposmod(trees[q]*0.37+trees[q+2]*0.61,1.0))
		_put(buf,cb,Vector3(trees[q],trees[q+1]+fit.z*sc,trees[q+2]),Color(shade,shade,shade))
	var ground: Dictionary = _floor_arrays(far) if _floor else {}
	return {"kind":"f","key":key,"buf":buf,"n":n,"floor":ground,"ms":(Time.get_ticks_usec()-began)/1000.0}

## The floor's sheet from a grid (TreePlan `floor_grid`, `far_cell`):
## each weight softened by its eight neighbours, the quads from the grid's
## own nodes (two in from its edge) to the next, so neighbouring squares
## meet with no gap; {} if no weight.
func _floor_arrays(g: Dictionary) -> Dictionary:
	var n := int(g.n)
	var hs: PackedFloat32Array = g.h
	var raw: PackedFloat32Array = g.w
	if raw.is_empty(): return {}
	var step := float(g.step)
	var ox := float(g.x)
	var oz := float(g.z)
	var wn := n-2
	# Softened weights at nodes 1..n-2 of the height grid (raw's 0..wn-1).
	var ws := PackedFloat32Array()
	ws.resize(n*n)
	var any := false
	for j in range(2,n-1):
		for i in range(2,n-1):
			var sum := 0.0
			for dj in range(-1,2):
				for di in range(-1,2):
					var ri := clampi(i-1+di,0,wn-1)
					var rj := clampi(j-1+dj,0,wn-1)
					sum += raw[rj*wn+ri]
			ws[j*n+i] = sum/9.0
			if sum > 0.18: any = true
	if not any: return {}
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var index := PackedInt32Array()
	var at := PackedInt32Array()
	at.resize(n*n)
	at.fill(-1)
	for j in range(2,n-2):
		for i in range(2,n-2):
			if maxf(maxf(ws[j*n+i],ws[j*n+i+1]),maxf(ws[(j+1)*n+i],ws[(j+1)*n+i+1])) <= 0.02: continue
			var q: Array = []
			for c: Vector2i in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
				var k := c.y*n+c.x
				if at[k] < 0:
					at[k] = verts.size()
					verts.append(Vector3(ox+c.x*step,hs[k],oz+c.y*step))
					normals.append(Vector3(hs[k-1]-hs[k+1],step*2.0,hs[k-n]-hs[k+n]).normalized())
					colours.append(Color(1,1,1,ws[k]))
				q.append(at[k])
			index.append_array([q[0],q[1],q[2],q[0],q[2],q[3]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	return {"arrays":arrays}

func _floor_node(ground: Dictionary, material: Material) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,ground.arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Floor"
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("skip_reflection",true)
	return mi

## A MultiMesh instance (TRANSFORM_3D with colours: 12 + 4 floats).
static func _put(buf: PackedFloat32Array, b: Basis, o: Vector3, c: Color) -> void:
	buf.append_array([b.x.x,b.y.x,b.z.x,o.x,b.x.y,b.y.y,b.z.y,o.y,b.x.z,b.y.z,b.z.z,o.z,c.r,c.g,c.b,c.a])

## A plan cell's trees for the flight: Vector4s of [x, z, foot y, top] and
## [crown bottom over the foot, solid reach, -, -], bucketed BUCKET m.
func _lookup(ck: Vector2i, trees: PackedFloat32Array) -> Dictionary:
	var n := trees.size()/Plan.STRIDE
	var solid := PackedFloat32Array()
	var buckets := {}
	var wing := WorldScale.span*0.5*WING_SOLID
	for t in n:
		var q := t*Plan.STRIDE
		var d: Vector3 = _dims[int(trees[q+6])]
		var sc := trees[q+3]
		var reach := d.x*sc*trees[q+4]*CROWN_SOLID+wing
		solid.append_array([trees[q],trees[q+2],trees[q+1],d.y*sc,d.z*sc,reach,d.x*sc*trees[q+4]*CROWN_SOLID,0.0])
		var b := Vector2i(floori(trees[q]/BUCKET),floori(trees[q+2]/BUCKET))
		if not buckets.has(b): buckets[b] = PackedInt32Array()
		var list: PackedInt32Array = buckets[b]
		list.append(t)
		buckets[b] = list
	return {"solid":solid,"buckets":buckets,"n":n}

# --- Standing (main thread) --------------------------------------------------------

func _commit(done: Dictionary) -> void:
	var key: Vector2i = done.key
	stats.plan_ms += float(done.ms)
	stats.plans += 1
	stats.slowest_plan_ms = maxf(stats.slowest_plan_ms,float(done.ms))
	if done.kind == "f":
		if _far.has(key) or _rect_distance(key.x*Plan.FAR_CELL,key.y*Plan.FAR_CELL,Plan.FAR_CELL,_eye) > FAR.z+Plan.FAR_CELL: return
		var node := _batch(_crown,done.buf,int(done.n),_far_material)
		node.name = "Far_%d_%d" % [key.x,key.y]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not (done.floor as Dictionary).is_empty(): node.add_child(_floor_node(done.floor,_far_floor))
		add_child(node)
		_far[key] = node
		stats.far = _far.size()
		stats.far_trees += int(done.n)
		return
	if _blocks.has(key) or _rect_distance(key.x*BLOCK,key.y*BLOCK,BLOCK,_eye) > MID.z+BLOCK*2.0: return
	var holder := Node3D.new()
	holder.name = "Block_%d_%d" % [key.x,key.y]
	for v in done.near.size():
		var slot: Array = done.near[v]
		if int(slot[2]) == 0: continue
		for part in 2:
			var batch := _batch(_parts[v][part],slot[part],int(slot[2]),null)
			batch.name = "Spruce%d%s" % [v,"Crown" if part == 1 else "Trunk"]
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visibility_range_end = NEAR_END
			batch.visibility_range_end_margin = NEAR_MARGIN
			batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			holder.add_child(batch)
	if int(done.n) > 0:
		var mid := _batch(_crown,done.mid,int(done.n),_mid_material)
		mid.name = "Mid"
		mid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mid)
		if _shadows:
			# The near trees' shadows, cast by their faceted crowns (a tenth
			# of the faces, one batch a block): SHADOWS_ONLY.
			var shade := _batch(_crown,done.mid,int(done.n),_shade_material)
			shade.name = "Shade"
			shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			shade.visibility_range_end = NEAR_END
			shade.visibility_range_end_margin = NEAR_MARGIN
			holder.add_child(shade)
	if not (done.floor as Dictionary).is_empty(): holder.add_child(_floor_node(done.floor,_near_floor))
	add_child(holder)
	_blocks[key] = {"node":holder,"cells":done.cells,"n":int(done.n)}
	stats.blocks = _blocks.size()
	stats.trees += int(done.n)

func _batch(mesh: Mesh, buf: PackedFloat32Array, count: int, material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	if count > 0: mm.buffer = buf
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = mm
	if material != null: batch.material_override = material
	batch.set_meta("skip_reflection",true)
	return batch

func _free_block(key: Vector2i) -> void:
	var b: Dictionary = _blocks[key]
	(b.node as Node).queue_free()
	stats.trees -= int(b.n)
	for ck: Vector2i in b.cells:
		if _bodies.has(ck):
			(_bodies[ck] as Node).queue_free()
			_bodies.erase(ck)
	_blocks.erase(key)
	stats.blocks = _blocks.size()

# --- The solid -----------------------------------------------------------------

func _cell_data(ck: Vector2i) -> Variant:
	var per := int(BLOCK/Plan.CELL)
	var b: Variant = _blocks.get(Vector2i(floori(float(ck.x)/per),floori(float(ck.y)/per)))
	if b == null: return null
	return (b as Dictionary).cells.get(ck)

## The tallest tree solid over world XZ `p` (world y), or -INF.
func top_at(p: Vector3) -> float:
	if _blocks.is_empty(): return -INF
	var best := -INF
	var bx := floori(p.x/BUCKET)
	var bz := floori(p.z/BUCKET)
	for dz in range(-1,2):
		for dx in range(-1,2):
			var b := Vector2i(bx+dx,bz+dz)
			var cell: Variant = _cell_data(Plan.cell_of((b.x+0.5)*BUCKET,(b.y+0.5)*BUCKET))
			if cell == null: continue
			var list: Variant = (cell as Dictionary).buckets.get(b)
			if list == null: continue
			var solid: PackedFloat32Array = (cell as Dictionary).solid
			for t: int in list:
				var q := t*8
				var ox := p.x-solid[q]
				var oz := p.z-solid[q+1]
				var reach := solid[q+5]
				var d2 := ox*ox+oz*oz
				if d2 >= reach*reach: continue
				# A cone from the crown's foot (its reach) to its top.
				var bottom := solid[q+2]+solid[q+4]
				var top := solid[q+2]+solid[q+3]
				best = maxf(best,lerpf(top,bottom,sqrt(d2)/reach))
	return best

## SkyGlide's `ground` over what the arches gave (`under`: the land's height,
## or Vector2(top, underside) for a span): a tree raises the land to its top.
func ground(p: Vector3, under: Variant) -> Variant:
	if not enabled or under is Vector2: return under
	var t := top_at(p)
	return maxf(float(under),t) if t > -INF else under

## True inside a tree's solid (the rolling plane stops).
func inside(p: Vector3) -> bool:
	if not enabled: return false
	return p.y < top_at(p)

# --- Colliders --------------------------------------------------------------------

func _collide(at: Vector3) -> void:
	for ck: Vector2i in _bodies.keys():
		if _rect_distance(ck.x*Plan.CELL,ck.y*Plan.CELL,Plan.CELL,at) > COLLIDE*1.5:
			(_bodies[ck] as Node).queue_free()
			_bodies.erase(ck)
	var c := Plan.cell_of(at.x,at.z)
	# At most one plan cell's colliders a frame.
	for dz in range(-1,2):
		for dx in range(-1,2):
			var ck := c+Vector2i(dx,dz)
			if _bodies.has(ck) or _rect_distance(ck.x*Plan.CELL,ck.y*Plan.CELL,Plan.CELL,at) > COLLIDE: continue
			var cell: Variant = _cell_data(ck)
			if cell == null: continue
			var t0 := Time.get_ticks_usec()
			_bodies[ck] = _body(ck,cell)
			stats.slowest_collider_ms = maxf(float(stats.get("slowest_collider_ms",0.0)),(Time.get_ticks_usec()-t0)/1000.0)
			stats.colliders = _bodies.size()
			return

## A convex spinning top a tree: the trunk's foot, the crown's widest ring
## (its reach, CROWN_SOLID), the top.
func _body(ck: Vector2i, cell: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Trees_%d_%d" % [ck.x,ck.y]
	body.collision_layer = LAYER
	body.collision_mask = 0
	var solid: PackedFloat32Array = cell.solid
	for t in int(cell.n):
		var q := t*8
		var r := solid[q+6]
		var bottom := solid[q+4]
		var top := solid[q+3]
		var points := PackedVector3Array()
		for k in 6:
			var a := TAU*k/6.0
			points.append(Vector3(cos(a)*0.3,0.0,sin(a)*0.3))
			points.append(Vector3(cos(a)*r,bottom,sin(a)*r))
		points.append(Vector3(0.0,top,0.0))
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(solid[q],solid[q+2],solid[q+1])
		body.add_child(cs)
	add_child(body)
	return body

## The numbers line (F1).
func note() -> String:
	if not enabled: return "\nno trees"
	return "\ntrees: %d in %d blocks, %dk far in %d cells  ·  %.0f ms a plan on a worker (slowest %.0f), slowest stand %.2f ms (%s), %d collider cells (slowest %.2f ms)" % [
		int(stats.trees),int(stats.blocks),int(stats.far_trees)/1000,int(stats.far),float(stats.plan_ms)/maxf(float(stats.plans),1.0),float(stats.slowest_plan_ms),float(stats.slowest_commit_ms),String(stats.slowest_commit),int(stats.colliders),float(stats.get("slowest_collider_ms",0.0))]
