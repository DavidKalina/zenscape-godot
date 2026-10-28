extends Node3D
## The endless land's arches (docs/design/endless-flight/arches-handoff.md),
## streamed round the eye as the land is: each world cell's arches
## (scripts/endless/arch_plan.gd, a pure function of the seed) are built
## by a WorkerThreadPool task (scripts/endless/arch_build.gd) when the cell
## comes within REACH m, committed on the main thread within COMMIT_BUDGET
## ms a frame, and freed past REACH+CELL.
##
## The flight's solid: the land is a heightfield, so the arches give theirs
## as their boxes (scripts/endless/box_solid.gd), and `ground(p, h)` answers SkyGlide's `ground` with them: the
## land's height `h`, raised by a leg or pier standing on it, or a span's
## Vector2(top, underside) when the plane is nearer the span than the land
## under it, so it slides under the span and is turned aside by a leg.
## Each arch also has colliders on layer 1 (the wheels, whoever walks).
##
## Each arch is named `endless/arch/<cx>_<cz>/<i>` and placed through
## scripts/layout_overrides.gd (a move in the layout file wins; only its
## yaw and place are kept, the flight's solid follows it).

const Field = preload("res://scripts/endless/land_field.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const Plan = preload("res://scripts/endless/arch_plan.gd")
const Build = preload("res://scripts/endless/arch_build.gd")
const Bridges = preload("res://scripts/endless/bridge_plan.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const STONE_LIFT := Color(3.0, 2.55, 1.95)
const RuinKit = preload("res://scripts/ruin_kit.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const RockShape = preload("res://scripts/endless/rock_shape.gd")

## The cells built round the eye (m to the cell's middle), and those kept
## until past REACH+CELL.
const REACH := 2600.0
const NEAR := 500.0
const REPLAN := 40.0
const TASKS := 2
const COMMIT_BUDGET := 1.5
const LAYER := 1

var seed := 1
var density := 1.0
var rock := 1.0
var ruin := 1.0
var material: Material
var stats := {"cells":0,"arches":0,"built_ms":0.0,"slowest_build_ms":0.0,"slowest_commit_ms":0.0,"tris":0}

var _cells := {}        # Vector2i -> Array of records (committed)
var _pending := {}      # Vector2i -> task id
var _done: Array = []
var _lock := Mutex.new()
var _queue: Array = []
var _planned_at := Vector3.INF
var _quit := false
var _eye := Vector3.ZERO

## Whether the flags want arches: --no-arches or --arches=0 none.
static func flags() -> Dictionary:
	# The world's arches layer (its density), the flags over it.
	var out := {"density":float(preload("res://scripts/endless/world/world_profile.gd").current().layer("arches",1.0)),"rock":1.0,"ruin":1.0}
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a == "--no-arches": out.density = 0.0
		elif a.begins_with("--arches="): out.density = maxf(0.0,float(a.get_slice("=",1)))
		elif a.begins_with("--rock-arches="): out.rock = maxf(0.0,float(a.get_slice("=",1)))
		elif a.begins_with("--ruin-arches="): out.ruin = maxf(0.0,float(a.get_slice("=",1)))
	return out

func setup(land_seed: int, ground: Material = null) -> void:
	seed = land_seed
	var f := flags()
	density = f.density
	rock = f.rock
	ruin = f.ruin
	material = ground
	if material == null:
		var plain := StandardMaterial3D.new()
		plain.vertex_color_use_as_albedo = true
		plain.vertex_color_is_srgb = true
		plain.roughness = 1.0
		material = plain
	# The kit's shared materials are made lazily: once here, before workers.
	RuinKit.materials()

## The ruin stone for the endless land only (the kit's own material is shared
## with the isles and the motif editor, so it is copied, not changed): the same
## faces and weathering, lifted and warmed so the stone stands in the sun as
## the land's rock does. `--old-ruin-stone` leaves the kit's dark stone.
var _old_stone := "--old-ruin-stone" in LaunchArgs.user_args()
var _stone: ShaderMaterial

func _sunlit(node: Node) -> void:
	var kit: Material = RuinKit.materials().stone
	if _stone == null:
		_stone = (kit as ShaderMaterial).duplicate() as ShaderMaterial
		_stone.set_shader_parameter("albedo",STONE_LIFT)
		_stone.set_shader_parameter("fill",3.6)
		_stone.set_shader_parameter("rim",0.1)
	for mi in node.find_children("*","MeshInstance3D",true,false):
		var m := mi as MeshInstance3D
		if m.mesh == null: continue
		for i in m.mesh.get_surface_count():
			if m.mesh.surface_get_material(i) == kit: m.set_surface_override_material(i,_stone)

func _exit_tree() -> void:
	_quit = true
	for id: int in _pending.values(): WorkerThreadPool.wait_for_task_completion(id)

## Builds the cells within NEAR of `at` now, on this thread.
func prime(at: Vector3) -> void:
	if density <= 0.0: return
	_eye = at
	var field := Field.new(seed)
	for key: Vector2i in _wanted(at,NEAR):
		if _cells.has(key): continue
		_done.append(_build_cell(key,field))
	_planned_at = Vector3.INF
	while not _done.is_empty(): _commit_one(_done.pop_back())

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
		if _cells.has(key) or _pending.has(key): continue
		_pending[key] = WorkerThreadPool.add_task(_task.bind(key))
	var began := Time.get_ticks_usec()
	while true:
		_lock.lock()
		var next: Variant = _done.pop_front() if not _done.is_empty() else null
		_lock.unlock()
		if next == null: break
		_commit_one(next)
		if (Time.get_ticks_usec()-began)/1000.0 > COMMIT_BUDGET: break

func _wanted(at: Vector3, reach: float) -> Array:
	var out: Array = []
	var c := Plan.cell_of(at.x,at.z)
	var r := int(ceil(reach/Plan.CELL))+1
	for dz in range(-r,r+1):
		for dx in range(-r,r+1):
			var key := c+Vector2i(dx,dz)
			if _cell_distance(key,at) <= reach: out.append(key)
	out.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return _cell_distance(p,at) < _cell_distance(q,at))
	return out

func _cell_distance(key: Vector2i, at: Vector3) -> float:
	return Vector2((key.x+0.5)*Plan.CELL-at.x,(key.y+0.5)*Plan.CELL-at.z).length()

func _plan(at: Vector3) -> void:
	_queue.clear()
	for key: Vector2i in _wanted(at,REACH):
		if not _cells.has(key) and not _pending.has(key): _queue.append(key)
	for key: Vector2i in _cells.keys():
		if _cell_distance(key,at) > REACH+Plan.CELL: _free_cell(key)

func _task(key: Vector2i) -> void:
	if _quit: return
	var result := _build_cell(key,Field.new(seed))
	_lock.lock()
	_done.append(result)
	_lock.unlock()

## A cell's arches built: {key, arches: [built...], ms}.
func _build_cell(key: Vector2i, field: RefCounted) -> Dictionary:
	var began := Time.get_ticks_usec()
	var built: Array = []
	# The cell's arches (less those under a bridge) and the bridges whose middle
	# stands in it (bridge_plan.gd; only a world whose layers set `bridges`).
	var specs: Array = Bridges.with_arches(field,key.x,key.y,Plan.plan(field,key.x,key.y,density,rock,ruin),density,rock,ruin)
	for spec: Dictionary in specs:
		var b := Build.build(spec,field)
		# A rock arch's solid follows its skin; a ruin's, its stones.
		b["solid"] = BoxSolid.build(BoxSolid.from_faces(b.faces) if b.kind == "rock" else b.boxes)
		if b.kind == "rock":
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(b.faces)
			b["shape"] = shape
		built.append(b)
	return {"key":key,"arches":built,"ms":(Time.get_ticks_usec()-began)/1000.0}

func _commit_one(done: Dictionary) -> void:
	var key: Vector2i = done.key
	var t0 := Time.get_ticks_usec()
	stats.built_ms += float(done.ms)
	stats.slowest_build_ms = maxf(stats.slowest_build_ms,float(done.ms))
	if _cells.has(key) or _cell_distance(key,_eye) > REACH+Plan.CELL*2.0:
		for b: Dictionary in done.arches:
			if b.has("node"): (b.node as Node).free()
		return
	var records: Array = []
	for b: Dictionary in done.arches:
		var spec: Dictionary = b.spec
		var name := String(spec.name)
		if LayoutOverrides.deleted(name):
			if b.has("node"): (b.node as Node).free()
			continue
		var coded := Transform3D(Build.basis_of(spec),spec.pos)
		var xf := LayoutOverrides.xform(name,coded)
		var yaw := atan2(-xf.basis.x.z,xf.basis.x.x)
		xf = Transform3D(Basis(Vector3.UP,yaw),xf.origin)
		var node: Node3D
		if b.kind == "rock":
			node = Node3D.new()
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,b.arrays,[],{},RockShape.format(b.arrays))
			mesh.surface_set_material(0,material)
			var mi := MeshInstance3D.new()
			mi.name = "Mesh"
			mi.mesh = mesh
			node.add_child(mi)
			var body := StaticBody3D.new()
			body.name = "Body"
			var cs := CollisionShape3D.new()
			cs.shape = b.shape
			body.add_child(cs)
			node.add_child(body)
			stats.tris += int(b.tris)
		else:
			node = b.node
			if not _old_stone: _sunlit(node)
		for body in node.find_children("*","StaticBody3D",true,false):
			(body as StaticBody3D).collision_layer = LAYER
			(body as StaticBody3D).collision_mask = 0
		node.name = name.replace("/","_")
		node.transform = xf
		add_child(node)
		LayoutOverrides.track(name,node,"piece",coded)
		var solid: Dictionary = b.solid
		var sx := BoxSolid.span_x(solid)
		var reach := maxf(maxf(absf(sx.x),absf(sx.y)),absf(float(solid.z0))+int(solid.nz)*BoxSolid.CELL)+40.0
		records.append({"name":name,"kind":String(spec.get("form",spec.kind)),"node":node,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
			"solid":solid,"reach":reach,"spec":spec})
		stats.arches += 1
	_cells[key] = records
	stats.cells = _cells.size()
	stats.slowest_commit_ms = maxf(stats.slowest_commit_ms,(Time.get_ticks_usec()-t0)/1000.0)

func _free_cell(key: Vector2i) -> void:
	for r: Dictionary in _cells[key]:
		LayoutOverrides.entries.erase(r.name)
		(r.node as Node).queue_free()
		stats.arches -= 1
	_cells.erase(key)
	stats.cells = _cells.size()

## Every arch standing now: [{name, kind, pos, spec, ...}].
func standing() -> Array:
	var out: Array = []
	for key in _cells: out.append_array(_cells[key])
	return out

# --- The flight's solid -----------------------------------------------------

## The solid stretches over world XZ `p` (world y, low to high), from every
## arch there, each box grown by `pad` m round (the wingtip's reach when
## not given; 0 for a point on the plane's own edge).
func stretches(p: Vector3, pad := -1.0) -> Array:
	var out: Array = []
	if _cells.is_empty(): return out
	if pad < 0.0: pad = Build.wingtip()
	var c := Plan.cell_of(p.x,p.z)
	for dz in range(-1,2):
		for dx in range(-1,2):
			var list: Variant = _cells.get(c+Vector2i(dx,dz))
			if list == null: continue
			for r: Dictionary in list:
				var o: Vector3 = r.pos
				var ox := p.x-o.x
				var oz := p.z-o.z
				if absf(ox) > float(r.reach) or absf(oz) > float(r.reach): continue
				var lx := ox*float(r.cos)-oz*float(r.sin)
				var lz := ox*float(r.sin)+oz*float(r.cos)
				BoxSolid.stretches(r.solid,lx,lz,pad,o.y,out)
	return BoxSolid.joined(out,Build.JOIN)

## SkyGlide's `ground` at `p` over land of height `h`: a float (the land,
## raised by what stands on it) or Vector2(top, underside) for a span the
## plane is nearer than the ground under it.
func ground(p: Vector3, h: float, pad := -1.0) -> Variant:
	var list := stretches(p,pad)
	if list.is_empty(): return h
	var top := h
	var under := -INF
	for s: Vector2 in list:
		if s.x <= top+0.6:
			# On the ground (or on what stands on it): it raises it.
			top = maxf(top,s.y)
			continue
		# A span over the ground: the plane over its middle height or in
		# it belongs to it; under that, to the ground.
		if p.y >= s.y:
			top = s.y
			under = s.x
			continue
		if p.y >= (top+s.x)*0.5: return Vector2(s.y,s.x)
		break
	return top if under == -INF else Vector2(top,under)

## True inside an arch's solid, grown by `pad` (as `stretches`; the camera
## keeps out).
func inside(p: Vector3, pad := -1.0) -> bool:
	for s: Vector2 in stretches(p,pad):
		if p.y >= s.x and p.y <= s.y: return true
	return false
