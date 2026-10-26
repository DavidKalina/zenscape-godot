extends Node3D
## The slot halls standing in their cuts (scripts/endless/hall_sites.gd
## finds them and cuts the land; docs/design/endless-flight/
## overgrown-halls-handoff.md), streamed round the eye as the arches are.
##
## A hall is one straight Sundered piece (scripts/sundered_hall.gd
## `slot_piece`), stood in SECTION-bay sections. Far detail
## (SunderedBuild `far`) for a square's hall is built by a WorkerThreadPool
## task when the square comes within REACH m and committed on the main
## thread within COMMIT_BUDGET ms a frame; the hall is freed past
## REACH+CELL. Near detail (SunderedBuild `near`: the kit's bays) is built a
## section at a time, the nearest first, TASKS at once, within NEAR_BUILD of
## the section; shown within NEAR_SHOW (its far hidden), let go past
## NEAR_FORGET. Its bodies stand one chunk a frame, on the walker's and the
## wheels' layer as well as the ruins'.
##
## The flight's solid: the land is a heightfield, so a section gives its
## solid as its boxes in the hall's frame (scripts/endless/box_solid.gd),
## grown as each query asks: by the plane's reach round its middle, none
## for a point on its edge.
## Until its near detail is made, a section's grid comes from its plan (its
## walls, columns and whole roofs); then from the near build's own hulls.
## `ground(p, h)` answers SkyGlide's `ground` with them as the arches do:
## the land raised by what stands on it (a column, a wall: a face the glide
## turns along), or Vector2(top, underside) for a roof or a tie the plane is
## nearer than the floor, which it slides under.
##
## Each hall is named as its site is (`<world>/hall/<cx>_<cz>`) and tracked
## through scripts/layout_overrides.gd; the site already stands where the
## layout file moved it.

const Field = preload("res://scripts/endless/land_field.gd")
const Sites = preload("res://scripts/endless/hall_sites.gd")
const Sundered = preload("res://scripts/sundered_hall.gd")
const SunderedBuild = preload("res://scripts/sundered_build.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const HallPath = Hall.HallPath
const RuinKit = preload("res://scripts/ruin_kit.gd")
const ArchBuild = preload("res://scripts/endless/arch_build.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The squares whose hall stands round the eye (m to the square's middle).
const REACH := 3200.0
const REPLAN := 60.0
const TASKS := 2
const COMMIT_BUDGET := 1.5
## Bays a section; near detail built, shown and let go (m, eye to the
## section's middle line).
const SECTION := 6
const NEAR_BUILD := 650.0
const NEAR_SHOW := 330.0
const NEAR_FORGET := 800.0
## Near builds at once: one (SunderedBuild `near` sets the kit's detail for
## its whole build, scripts/ruin_kit.gd `set_detail`).
const NEAR_TASKS := 1
## The walker's and the wheels' layer (the ruins' own stays as well).
const LAYER := 1
## The ruin stone lifted for the endless land's sun (LandArches' STONE_LIFT).
const STONE_LIFT := Color(3.0,2.55,1.95)

var seed := 1
var density := 0.0
var stats := {"halls":0,"sections":0,"near":0,"near_ms":0.0,"slowest_near_ms":0.0,"slowest_commit_ms":0.0,"far_tris":0,"near_tris":0}

var _halls := {}        # Vector2i -> record (or {} for a square with none)
var _pending := {}      # Vector2i -> task id
var _done: Array = []
var _lock := Mutex.new()
var _queue: Array = []
var _near_tasks := 0
var _planned_at := Vector3.INF
var _quit := false
var _eye := Vector3.ZERO
var _stone: ShaderMaterial
## Materials of its own for the kit's (kit material -> its own), worn in
## place of the sunlit stone: the tunnels' stretches under rock
## (land_tunnels.gd, the dark inside). Empty: the sunlit stone.
var swap: Dictionary = {}
## With `swap`, the render layers its pieces stand on (0: as built).
var swap_layers := 0
var _old_stone := "--old-ruin-stone" in LaunchArgs.user_args()
## Fixed pieces (key -> info: name, seed, bays, frame, coded, site), built
## from their own infos rather than the squares' sites, never freed:
## scripts/endless/land_tunnels.gd's hall stretches. With `squares` false
## (a tunnel's own streamer) no square is planned at all.
var fixed := {}
var squares := true

func setup(land_seed: int) -> void:
	seed = land_seed
	density = Field.new(seed).halls
	RuinKit.materials()

func _exit_tree() -> void:
	_quit = true
	for id: int in _pending.values(): WorkerThreadPool.wait_for_task_completion(id)
	for key: Vector2i in _halls:
		var r: Dictionary = _halls[key]
		for sec: Dictionary in r.get("sections",[]):
			if int(sec.task) >= 0: WorkerThreadPool.wait_for_task_completion(int(sec.task))

## A fixed piece (`fixed`): planned with the next step, freed only by
## `remove_fixed`.
func add_fixed(key: Vector2i, info: Dictionary) -> void:
	fixed[key] = info
	_planned_at = Vector3.INF

## Drops fixed piece `key` and whatever of it stands (a build of it still
## on a worker is thrown away when it comes back).
func remove_fixed(key: Vector2i) -> void:
	fixed.erase(key)
	_queue.erase(key)
	if _halls.has(key): _free(key)

## Builds the halls within `near` of `at` now, far and near, on this thread
## (every fixed piece's far detail too).
func prime(at: Vector3, near := 700.0) -> void:
	if density <= 0.0: return
	_eye = at
	var field := Field.new(seed) if squares else null
	for key: Vector2i in (_wanted(at,near) if squares else []):
		if _halls.has(key): continue
		_commit(_build_hall(key,field))
	for key: Vector2i in fixed:
		if not _halls.has(key) and not _pending.has(key): _commit(_build_from(key,fixed[key]))
	for key: Vector2i in _halls:
		var r: Dictionary = _halls[key]
		for sec: Dictionary in r.get("sections",[]):
			if _distance(r,sec,at) < NEAR_SHOW:
				sec.out = _build_near(sec)
				_stand_near(r,sec)
				while _stand_body(sec): pass
	_planned_at = Vector3.INF

func step(at: Vector3) -> void:
	if density <= 0.0: return
	_eye = at
	if _planned_at == Vector3.INF or Vector2(at.x-_planned_at.x,at.z-_planned_at.z).length() > REPLAN:
		_planned_at = at
		_plan(at)
	for key: Vector2i in _pending.keys():
		var id: int = _pending[key]
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_pending.erase(key)
	while _pending.size() < TASKS and not _queue.is_empty():
		var key: Vector2i = _queue.pop_front()
		if _halls.has(key) or _pending.has(key): continue
		# The info goes with the task: `fixed` changes on this thread.
		_pending[key] = WorkerThreadPool.add_task(_task.bind(key,fixed.get(key)))
	var began := Time.get_ticks_usec()
	while true:
		_lock.lock()
		var next: Variant = _done.pop_back() if not _done.is_empty() else null
		_lock.unlock()
		if next == null: break
		_commit(next)
		if (Time.get_ticks_usec()-began)/1000.0 > COMMIT_BUDGET: break
	_advance_near(at,began)

func _wanted(at: Vector3, reach: float) -> Array:
	var out: Array = []
	var r := int(ceil(reach/Sites.CELL))+1
	var c := Vector2i(floori(at.x/Sites.CELL),floori(at.z/Sites.CELL))
	for dz in range(-r,r+1):
		for dx in range(-r,r+1):
			var key := c+Vector2i(dx,dz)
			if _cell_distance(key,at) <= reach: out.append(key)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cell_distance(a,at) < _cell_distance(b,at))
	return out

func _cell_distance(key: Vector2i, at: Vector3) -> float:
	return Vector2((key.x+0.5)*Sites.CELL-at.x,(key.y+0.5)*Sites.CELL-at.z).length()

func _plan(at: Vector3) -> void:
	_queue.clear()
	for key: Vector2i in fixed:
		if not _halls.has(key) and not _pending.has(key): _queue.append(key)
	if not squares: return
	for key: Vector2i in _wanted(at,REACH):
		if not _halls.has(key) and not _pending.has(key): _queue.append(key)
	for key: Vector2i in _halls.keys():
		if not fixed.has(key) and _cell_distance(key,at) > REACH+Sites.CELL: _free(key)

func _task(key: Vector2i, info: Variant = null) -> void:
	if _quit or (info == null and not squares): return
	var result := _build_from(key,info) if info != null else _build_hall(key,Field.new(seed))
	_lock.lock()
	_done.append(result)
	_lock.unlock()

# --- Building (on a worker) -----------------------------------------------------

## A square's hall planned and its far detail built: {key, info, sections:
## [{sub, x0, x1, far, solid}]}, or {key} for a square with none.
func _build_hall(key: Vector2i, field: RefCounted) -> Dictionary:
	return _build_from(key,field.hall_info(key))

## A hall from its info ({name, seed, bays, frame, coded, site}), as
## `_build_hall`.
func _build_from(key: Vector2i, info: Dictionary) -> Dictionary:
	if info.is_empty(): return {"key":key}
	# A fixed hall may bring its piece ready made (the tunnels' stretches,
	# their centre row as Tunnels.centre_row sets it).
	var piece: Dictionary = info.piece if info.has("piece") else Sundered.slot_piece(int(info.seed),int(info.bays))
	var sections: Array = []
	var bays := int(piece.bays)
	var a := 0
	while a < bays:
		var b := mini(a+SECTION,bays)
		# No section of a single bay: the last takes it.
		if bays-b < 2: b = bays
		var sub := _sub(piece,a,b)
		var far := SunderedBuild.far(sub)
		var x0 := a*Hall.BAY
		sections.append({"sub":sub,"x0":x0,"x1":b*Hall.BAY,"far":far,"tris":SunderedBuild._tris(far),
			"solid":_grid(_plan_boxes(sub),x0),"near":null,"task":-1,"out":{},"bodies":[],"exact":false})
		a = b
	return {"key":key,"info":info,"piece":piece,"sections":sections}

## Bays a..b of `piece` as a piece of their own (its frame at bay a).
static func _sub(piece: Dictionary, a: int, b: int) -> Dictionary:
	var layout := [{"bays":b-a,"turn":0.0}]
	var path := HallPath.make(layout,Hall.BAY)
	var plans: Array = (piece.plans as Array).slice(a,b)
	return {"index":a,"act":"slot","bays":b-a,"layout":layout,"path":path,"length":path.length,"frame":Transform3D.IDENTITY,
		"floor":0.0,"theta":0.0,"first":a == 0,"last":b == int(piece.bays),"apse":piece.get("apse",true),"s0":0.0,"seed":hash([int(piece.seed),a]) & 0xffffff,"plans":plans}

## A section's solid from its plan (section frame): its walls, its bay
## lines' columns and its whole roofs; the near build's hulls replace it.
static func _plan_boxes(sub: Dictionary) -> Array:
	var out: Array = []
	var plans: Array = sub.plans
	var soffit := Hall.COLUMN_H+Hall.BEAM.x
	for i in range(plans.size()):
		var p: Dictionary = plans[i]
		var x0 := i*Hall.BAY
		for z: float in [-Hall.WALL_Z,Hall.WALL_Z]:
			var high := Hall.ROOF_TOP+1.0 if p.roof != "open" else 7.5
			out.append(AABB(Vector3(x0,0.0,z-Hall.WALL_THICK*0.5),Vector3(Hall.BAY,high,Hall.WALL_THICK)))
		var zs: Array = [-Hall.ROW_Z,Hall.ROW_Z]
		zs.append_array(p.inner)
		for z: float in zs:
			out.append(AABB(Vector3(x0-Hall.COLUMN_R,0.0,z-Hall.COLUMN_R),Vector3(Hall.COLUMN_R*2.0,Hall.COLUMN_H,Hall.COLUMN_R*2.0)))
		if p.roof == "whole": out.append(AABB(Vector3(x0,soffit,-Hall.WALL_Z),Vector3(Hall.BAY,Hall.SLAB,Hall.WALL_Z*2.0)))
	return out

## Boxes (section frame, its x0 along the hall) as the flight's solid
## (BoxSolid, hall frame).
static func _grid(boxes: Array, shift: float) -> Dictionary:
	return BoxSolid.build(boxes,shift)

## A section's near detail and its exact solid (on a worker).
func _build_near(sec: Dictionary) -> Dictionary:
	var began := Time.get_ticks_usec()
	var node := SunderedBuild.near(sec.sub)
	var boxes: Array = []
	for body: Node in node.get_meta("bodies",[]):
		for holder in body.get_children():
			if not holder is CollisionShape3D: continue
			var shape := (holder as CollisionShape3D).shape
			var xf := (body as Node3D).transform*(holder as CollisionShape3D).transform
			var pts := PackedVector3Array()
			if shape is ConvexPolygonShape3D: pts = (shape as ConvexPolygonShape3D).points
			elif shape is BoxShape3D:
				var h := (shape as BoxShape3D).size*0.5
				for c in 8: pts.append(Vector3(h.x*(1 if c & 1 else -1),h.y*(1 if c & 2 else -1),h.z*(1 if c & 4 else -1)))
			if pts.is_empty(): continue
			var lo := Vector3.INF
			var hi := -Vector3.INF
			for q in pts:
				var w := xf*q
				lo = lo.min(w)
				hi = hi.max(w)
			boxes.append(AABB(lo,hi-lo))
	var tris := 0
	for mi in node.find_children("*","MeshInstance3D",true,false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null: continue
		for s in m.get_surface_count():
			tris += (m.surface_get_array_index_len(s) if m.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX else m.surface_get_array_len(s))/3
	return {"node":node,"solid":_grid(boxes,float(sec.x0)),"ms":(Time.get_ticks_usec()-began)/1000.0,"tris":tris}

# --- Standing (main thread) -----------------------------------------------------

func _commit(done: Dictionary) -> void:
	var key: Vector2i = done.key
	var t0 := Time.get_ticks_usec()
	if _halls.has(key) or (not fixed.has(key) and (not squares or _cell_distance(key,_eye) > REACH+Sites.CELL*2.0)): return
	if not done.has("info"):
		_halls[key] = {}
		return
	var info: Dictionary = done.info
	var name := String(info.name)
	var frame: Transform3D = info.frame
	var root := Node3D.new()
	root.name = name.replace("/","_")
	root.transform = frame
	add_child(root)
	LayoutOverrides.track(name,root,"piece",info.coded)
	for sec: Dictionary in done.sections:
		var mi := MeshInstance3D.new()
		mi.name = "Far%d" % int(sec.sub.index)
		mi.mesh = sec.far
		mi.position.x = float(sec.x0)
		root.add_child(mi)
		_sunlit(mi)
		sec.far_node = mi
		stats.far_tris += int(sec.tris)
	_halls[key] = {"name":name,"info":info,"node":root,"frame":frame,"inv":frame.affine_inverse(),"site":info.site,"sections":done.sections,
		"length":float(done.piece.length)}
	stats.halls += 1
	stats.sections += (done.sections as Array).size()
	stats.slowest_commit_ms = maxf(stats.slowest_commit_ms,(Time.get_ticks_usec()-t0)/1000.0)

func _free(key: Vector2i) -> void:
	var r: Dictionary = _halls[key]
	_halls.erase(key)
	if r.is_empty(): return
	for sec: Dictionary in r.sections:
		if int(sec.task) >= 0:
			WorkerThreadPool.wait_for_task_completion(int(sec.task))
			_near_tasks -= 1
			var made: Variant = (sec.out as Dictionary).get("node")
			if made != null: _free_near(made)
		for chunk: Node in sec.bodies: chunk.free()
		if sec.near != null: stats.near_tris -= int(sec.get("near_tris",0))
		stats.far_tris -= int(sec.tris)
	LayoutOverrides.entries.erase(r.name)
	(r.node as Node).queue_free()
	stats.halls -= 1
	stats.sections -= (r.sections as Array).size()

static func _free_near(node: Node) -> void:
	for chunk: Node in node.get_meta("bodies",[]): chunk.free()
	node.free()

## Distance from `at` to a section's middle line (m).
func _distance(r: Dictionary, sec: Dictionary, at: Vector3) -> float:
	var local: Vector3 = (r.inv as Transform3D)*at
	var x := clampf(local.x,float(sec.x0),float(sec.x1))
	return Vector3(local.x-x,local.y,local.z).length()

## Near detail: the nearest sections built, made ones stood within the
## frame's budget, shown or let go by distance.
func _advance_near(at: Vector3, began: int) -> void:
	var best := INF
	var nearest: Array = []
	for key: Vector2i in _halls:
		var r: Dictionary = _halls[key]
		if r.is_empty(): continue
		for sec: Dictionary in r.sections:
			var d := _distance(r,sec,at)
			if int(sec.task) >= 0 and WorkerThreadPool.is_task_completed(int(sec.task)):
				if (Time.get_ticks_usec()-began)/1000.0 < COMMIT_BUDGET:
					WorkerThreadPool.wait_for_task_completion(int(sec.task))
					sec.task = -1
					_near_tasks -= 1
					_stand_near(r,sec)
			if not (sec.bodies as Array).is_empty() and (Time.get_ticks_usec()-began)/1000.0 < COMMIT_BUDGET: _stand_body(sec)
			if sec.near != null:
				var show := d < NEAR_SHOW
				(sec.near as Node3D).visible = show
				(sec.far_node as Node3D).visible = not show
				if d > NEAR_FORGET:
					(sec.near as Node).queue_free()
					for chunk: Node in sec.bodies: chunk.free()
					sec.bodies = []
					sec.near = null
					stats.near -= 1
					stats.near_tris -= int(sec.get("near_tris",0))
					(sec.far_node as Node3D).visible = true
			elif int(sec.task) < 0 and d < NEAR_BUILD and d < best:
				best = d
				nearest = [r,sec]
	if not nearest.is_empty() and _near_tasks < NEAR_TASKS:
		var sec: Dictionary = nearest[1]
		var out := {}
		sec.out = out
		_near_tasks += 1
		sec.asked = Time.get_ticks_msec()
		sec.task = WorkerThreadPool.add_task(func() -> void:
			if _quit: return
			out.started = Time.get_ticks_msec()
			out.merge(_build_near(sec)),true,"Slot hall section")

func _stand_near(r: Dictionary, sec: Dictionary) -> void:
	var out: Dictionary = sec.out
	sec.out = {}
	var made: Variant = out.get("node")
	if made == null: return
	var node: Node3D = made
	node.position.x = float(sec.x0)
	(r.node as Node3D).add_child(node)
	if not _old_stone or not swap.is_empty(): _sunlit(node)
	sec.near = node
	sec.bodies = (node.get_meta("bodies",[]) as Array).duplicate()
	node.remove_meta("bodies")
	sec.solid = out.solid
	sec.exact = true
	sec.near_tris = int(out.tris)
	stats.near += 1
	stats.near_tris += int(out.tris)
	stats.near_ms += float(out.ms)
	stats.slowest_near_ms = maxf(stats.slowest_near_ms,float(out.ms))
	if sec.has("asked"):
		stats.slowest_wait_ms = maxf(float(stats.get("slowest_wait_ms",0.0)),float(int(out.get("started",0))-int(sec.asked)))
		stats.slowest_ready_ms = maxf(float(stats.get("slowest_ready_ms",0.0)),float(Time.get_ticks_msec()-int(sec.asked)))
	var show := _distance(r,sec,_eye) < NEAR_SHOW
	node.visible = show
	(sec.far_node as Node3D).visible = not show

## Stands the next of a section's pending body chunks; false when none is left.
func _stand_body(sec: Dictionary) -> bool:
	var pending: Array = sec.bodies
	if pending.is_empty() or sec.near == null: return false
	var chunk: StaticBody3D = pending.pop_back()
	chunk.collision_layer = SunderedBuild.RUIN_LAYER | LAYER
	(sec.near as Node3D).add_child(chunk)
	return true

func _sunlit(node: Node) -> void:
	if not swap.is_empty():
		_swap(node)
		return
	if _old_stone: return
	var kit: Material = RuinKit.materials().stone
	if _stone == null:
		_stone = (kit as ShaderMaterial).duplicate() as ShaderMaterial
		_stone.set_shader_parameter("albedo",STONE_LIFT)
		_stone.set_shader_parameter("fill",3.6)
		_stone.set_shader_parameter("rim",0.1)
	var list: Array = node.find_children("*","MeshInstance3D",true,false)
	if node is MeshInstance3D: list.append(node)
	for mi: MeshInstance3D in list:
		if mi.mesh == null: continue
		for i in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_material(i) == kit: mi.set_surface_override_material(i,_stone)

func _swap(node: Node) -> void:
	var list: Array = node.find_children("*","GeometryInstance3D",true,false)
	if node is GeometryInstance3D: list.append(node)
	for gi: GeometryInstance3D in list:
		if swap_layers != 0: gi.layers = swap_layers
		if gi is MeshInstance3D:
			var mi: MeshInstance3D = gi
			if mi.mesh == null: continue
			for i in mi.mesh.get_surface_count():
				var own: Variant = swap.get(mi.mesh.surface_get_material(i))
				if own != null: mi.set_surface_override_material(i,own)
		elif gi is MultiMeshInstance3D:
			var mm: MultiMesh = (gi as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null: continue
			for i in mm.mesh.get_surface_count():
				var own: Variant = swap.get(mm.mesh.surface_get_material(i))
				if own != null: gi.material_override = own

## Every hall standing now: [{name, info, node, sections...}].
func standing() -> Array:
	var out: Array = []
	for key: Vector2i in _halls:
		if not (_halls[key] as Dictionary).is_empty(): out.append(_halls[key])
	return out

# --- The flight's solid -----------------------------------------------------

## The solid stretches over world XZ `p` (world y, low to high), each box
## grown by `pad` m round (the wingtip's reach when not given).
func stretches(p: Vector3, pad := -1.0) -> Array:
	var out: Array = []
	if pad < 0.0: pad = WorldScale.span*0.5
	for key: Vector2i in _halls:
		var r: Dictionary = _halls[key]
		if r.is_empty(): continue
		var site: PackedFloat32Array = r.site
		if absf(p.x-site[0]) > site[7]+40.0 or absf(p.z-site[1]) > site[7]+40.0: continue
		var local: Vector3 = (r.inv as Transform3D)*p
		var floor_y: float = (r.frame as Transform3D).origin.y
		for sec: Dictionary in r.sections:
			BoxSolid.stretches(sec.solid,local.x,local.z,pad,floor_y,out)
	return BoxSolid.joined(out,ArchBuild.JOIN)

## SkyGlide's `ground` at `p` over `h` (the land's height, or what the
## layers under this one answered): as LandArches `ground`.
func ground(p: Vector3, h: Variant, pad := -1.0) -> Variant:
	if not h is float: return h
	var list := stretches(p,pad)
	if list.is_empty(): return h
	return over(p,h,list)

## SkyGlide's `ground` at `p` over the floor `h` with the solid `list`
## (stretches, world y, low to high) standing on it: the land raised by
## what stands on it, or Vector2(top, underside) under the stretch the
## plane is nearer than the floor (land_tunnels.gd adds the bore's rock
## roof as one more).
static func over(p: Vector3, h: float, list: Array) -> Variant:
	var top: float = h
	var under := -INF
	for s: Vector2 in list:
		if s.x <= top+0.6:
			top = maxf(top,s.y)
			continue
		if p.y >= s.y:
			top = s.y
			under = s.x
			continue
		if p.y >= (top+s.x)*0.5: return Vector2(s.y,s.x)
		break
	return top if under == -INF else Vector2(top,under)

## True inside a hall's solid, grown by `pad` (as `stretches`; the camera
## keeps out, the wheels stop).
func inside(p: Vector3, pad := -1.0) -> bool:
	# As `stretches`, without building the list (the camera's sight asks
	# this every half metre).
	if pad < 0.0: pad = WorldScale.span*0.5
	for key: Vector2i in _halls:
		var r: Dictionary = _halls[key]
		if r.is_empty(): continue
		var site: PackedFloat32Array = r.site
		if absf(p.x-site[0]) > site[7]+40.0 or absf(p.z-site[1]) > site[7]+40.0: continue
		var local: Vector3 = (r.inv as Transform3D)*p
		local.y = p.y-(r.frame as Transform3D).origin.y
		for sec: Dictionary in r.sections:
			if BoxSolid.inside(sec.solid,local,pad): return true
	return false

## One line for the numbers HUD.
func note() -> String:
	return "halls %d (%d sections, %d near) far %dk near %dk tris, near build %.0f ms worst" % [stats.halls,stats.sections,stats.near,stats.far_tris/1000,stats.near_tris/1000,stats.slowest_near_ms]
