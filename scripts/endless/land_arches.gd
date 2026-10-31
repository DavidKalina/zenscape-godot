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
const Sets = preload("res://scripts/endless/set_plan.gd")
const Carve = preload("res://scripts/endless/peak_carve.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const STONE_LIFT := Color(3.0, 2.55, 1.95)
## The ruins' stone colour in the land, by name: the albedo lift (sRGB) over
## the kit's dark stone. "amber" the warm gold it had (it matches the
## amberlands' grass); the others stand apart from the land. The world
## profile's "ruin_tone" layer picks one, --ruin-tone=NAME overrides. In a
## world of regions it is the region's at the ruin (`at`, world XZ in x and
## z; null: the world's own, the home region's).
const TONES := {
	"amber": Color(3.0, 2.55, 1.95),
	"basalt": Color(1.3, 1.32, 1.42),
	"slate": Color(1.85, 2.0, 2.4),
	"limestone": Color(2.85, 2.85, 2.95),
	"sandstone": Color(2.95, 1.95, 1.5),
}
static func tone_name(at: Variant = null) -> String:
	var name := str(_profile_at(at).layer("ruin_tone","amber"))
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--ruin-tone="): name = a.get_slice("=",1)
	return name if TONES.has(name) else "amber"
static func tone_lift(at: Variant = null) -> Color:
	return TONES[tone_name(at)]
static func _profile_at(at: Variant) -> RefCounted:
	var world: RefCounted = preload("res://scripts/endless/world/world_profile.gd").current()
	if at is Vector3: return world.at((at as Vector3).x,(at as Vector3).z)
	return world
const RuinKit = preload("res://scripts/ruin_kit.gd")
const GothicGrowth = preload("res://scripts/gothic_growth.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const RockShape = preload("res://scripts/endless/rock_shape.gd")
const Colosseum = preload("res://scripts/ruin_kit_colosseum.gd")

## The cells built round the eye (m to the cell's middle), and those kept
## until past REACH+CELL.
const REACH := 2600.0
const NEAR := 500.0
const REPLAN := 40.0
const TASKS := 2
const COMMIT_BUDGET := 1.5
const LAYER := 1
## The Peak's carve (peak_carve.gd) stands from this far: its walls show up the valley.
const CARVE_REACH := 6500.0

var seed := 1
var density := 1.0
var rock := 1.0
var ruin := 1.0
var material: Material
## The carve's rock (LandRocks' bare: all rock, whatever the slope).
var carve_rock: Material
## The cells holding the carve (they stand from CARVE_REACH).
var carve_cells := {}
var _gates := {}
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
	var carve_field := Field.new(seed)
	carve_cells = Carve.cells(carve_field)
	_gates = Carve.gates_grid(carve_field)

## The ruin stone for the endless land only (the kit's own material is shared
## with the isles and the motif editor, so it is copied, not changed): the same
## faces and weathering, lifted and warmed so the stone stands in the sun as
## the land's rock does. `--old-ruin-stone` leaves the kit's dark stone.
## Each kept per tone (TONES' name: the region's, in a world of regions).
var _old_stone := "--old-ruin-stone" in LaunchArgs.user_args()
var _stone := {}
## The gothic set pieces' mossed stone (scripts/gothic_growth.gd `stone`),
## lifted the same way (`GothicGrowth.lifted`); `--no-stone-moss` gives them
## the plain sunlit stone instead, to compare (look, frame time).
var _gothic_stone := {}
var _moss_off := "--no-stone-moss" in LaunchArgs.user_args()
## The colosseum's stone: the mossed stone with the moss on its tops only (no
## tongues down the faces, no band at the foot), so the cut stone reads from
## afar instead of a camouflage of moss and bare patches. `--colosseum-moss=full`
## gives it the gothic pieces' moss as before.
var _tops_stone := {}
var _tops_only := not "--colosseum-moss=full" in LaunchArgs.user_args()
## Every set piece (the gothic ones too) mossed on its tops only: the
## profile's "set_moss" layer at the piece (the region's; "tops", else the
## gothic pieces' full moss), --set-moss=tops|full overrides.
static func _set_moss(at: Variant = null) -> String:
	var how := str(_profile_at(at).layer("set_moss","full"))
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--set-moss="): how = a.get_slice("=",1)
	return how

## `mossed` (a plateau bridge, amberlands only): its kit stone takes the
## gothic pieces' mossed stone too (the look pass: the ruins overgrown).
## `at`: where it stands (its region's tone).
func _sunlit(node: Node, mossed := false, tops := false, at: Variant = null) -> void:
	var kit: Material = RuinKit.materials().stone
	var tone := tone_name(at)
	if not _stone.has(tone):
		var plain := (kit as ShaderMaterial).duplicate() as ShaderMaterial
		plain.set_shader_parameter("albedo",TONES[tone])
		plain.set_shader_parameter("fill",3.6)
		plain.set_shader_parameter("rim",0.1)
		_stone[tone] = plain
	var stone: ShaderMaterial = _stone[tone]
	if tops and _tops_only and not _moss_off:
		if not _tops_stone.has(tone):
			var t := GothicGrowth.lifted(TONES[tone],3.6,0.1)
			t.set_shader_parameter("moss_tongue",2.0)
			t.set_shader_parameter("moss_low",0.0)
			_tops_stone[tone] = t
		_override(node,_tops_stone[tone])
		return
	if not _gothic_stone.has(tone): _gothic_stone[tone] = stone if _moss_off else GothicGrowth.lifted(TONES[tone],3.6,0.1)
	var mossy: ShaderMaterial = _gothic_stone[tone]
	var gothic: Material = GothicGrowth.stone()
	for mi in node.find_children("*","MeshInstance3D",true,false):
		var m := mi as MeshInstance3D
		if m.mesh == null: continue
		for i in m.mesh.get_surface_count():
			var own := m.mesh.surface_get_material(i)
			if own == kit and not (mossed and not _moss_off): m.set_surface_override_material(i,stone)
			elif own == gothic or own == kit: m.set_surface_override_material(i,mossy)
	# The colosseum's bays, drawn as MultiMeshes (scripts/ruin_kit_colosseum.gd).
	for mmi in node.find_children("*","MultiMeshInstance3D",true,false):
		var mm := (mmi as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null or mm.mesh.get_surface_count() == 0: continue
		if mm.mesh.surface_get_material(0) != gothic: continue
		(mmi as MultiMeshInstance3D).material_override = mossy

## Every stone surface under `node` (the kit's or the gothic pieces') and its
## MultiMeshes drawn with `stone`.
func _override(node: Node, stone: Material) -> void:
	var kit: Material = RuinKit.materials().stone
	var gothic: Material = GothicGrowth.stone()
	for mi in node.find_children("*","MeshInstance3D",true,false):
		var m := mi as MeshInstance3D
		if m.mesh == null: continue
		for i in m.mesh.get_surface_count():
			var own := m.mesh.surface_get_material(i)
			if own == kit or own == gothic: m.set_surface_override_material(i,stone)
	for mmi in node.find_children("*","MultiMeshInstance3D",true,false):
		var mm := (mmi as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null or mm.mesh.get_surface_count() == 0: continue
		var own := mm.mesh.surface_get_material(0)
		if own == kit or own == gothic: (mmi as MultiMeshInstance3D).material_override = stone

func _exit_tree() -> void:
	_quit = true
	for id: int in _pending.values(): WorkerThreadPool.wait_for_task_completion(id)
	# Built but not yet committed (a set piece's build ending as the game
	# quits): out of the tree, so freed here, or its bodies leak at exit.
	_lock.lock()
	for done: Dictionary in _done:
		var arches: Array = done.arches
		for i in range(int(done.get("at",0)),arches.size()):
			var b: Dictionary = arches[i]
			if b.has("node") and is_instance_valid(b.node): (b.node as Node).free()
	_done.clear()
	_lock.unlock()
	for next: Array in _feed: (next[1] as Node).free()
	_feed.clear()

## Builds the cells within NEAR of `at` now, each on a worker (a long
## aqueduct's cell takes seconds), waiting for them all.
func prime(at: Vector3) -> void:
	if density <= 0.0: return
	_eye = at
	var ids: Array = []
	for key: Vector2i in _wanted(at,NEAR):
		if _cells.has(key) or _pending.has(key): continue
		ids.append(WorkerThreadPool.add_task(_task.bind(key),true))
	for id: int in ids: WorkerThreadPool.wait_for_task_completion(id)
	_planned_at = Vector3.INF
	_lock.lock()
	var done := _done.duplicate()
	_done.clear()
	_lock.unlock()
	while not done.is_empty(): _commit_one(done.pop_back())

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
		var next: Variant = _done.front() if not _done.is_empty() else null
		_lock.unlock()
		if next == null: break
		# A cell part done (its budget spent) stays first, for the next frame.
		if _commit_one(next,not _whole_cells,began):
			_lock.lock()
			_done.pop_front()
			_lock.unlock()
		if (Time.get_ticks_usec()-began)/1000.0 > COMMIT_BUDGET: break
	_feed_bodies(began)

## Each body joining the space has Jolt build its shape there and then, so a big
## rock's go in over frames: at least one a frame, then while the budget from
## `began` (µs) lasts. A rock freed meanwhile takes its waiting bodies with it.
func _feed_bodies(began: int) -> void:
	var first := true
	while not _feed.is_empty() and (first or (Time.get_ticks_usec()-began)/1000.0 <= COMMIT_BUDGET):
		var next: Array = _feed.pop_front()
		if is_instance_valid(next[0]):
			(next[0] as Node).add_child(next[1])
			first = false
		else: (next[1] as Node).free()

func _wanted(at: Vector3, reach: float) -> Array:
	var out: Array = []
	var c := Plan.cell_of(at.x,at.z)
	var r := int(ceil(reach/Plan.CELL))+1
	for dz in range(-r,r+1):
		for dx in range(-r,r+1):
			var key := c+Vector2i(dx,dz)
			if _cell_distance(key,at) <= reach: out.append(key)
	if reach >= REACH:
		for key: Vector2i in carve_cells:
			if not key in out and _cell_distance(key,at) <= CARVE_REACH: out.append(key)
	out.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return _cell_distance(p,at) < _cell_distance(q,at))
	return out

func _reach_of(key: Vector2i) -> float:
	return CARVE_REACH if carve_cells.has(key) else REACH

func _cell_distance(key: Vector2i, at: Vector3) -> float:
	return Vector2((key.x+0.5)*Plan.CELL-at.x,(key.y+0.5)*Plan.CELL-at.z).length()

func _plan(at: Vector3) -> void:
	_queue.clear()
	for key: Vector2i in _wanted(at,REACH):
		if not _cells.has(key) and not _pending.has(key): _queue.append(key)
	for key: Vector2i in _cells.keys():
		if _cell_distance(key,at) > _reach_of(key)+Plan.CELL: _free_cell(key)

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
	# And the set pieces whose middle stands in it (set_plan.gd; only a world
	# whose layers set `sets`), the arches by them given way.
	specs = Sets.with_arches(field,key.x,key.y,specs,density,rock,ruin)
	# And the Peak's carve (peak_carve.gd).
	specs = Carve.with_arches(field,key.x,key.y,specs)
	for spec: Dictionary in specs:
		var b := Build.build(spec,field)
		# A rock arch's solid follows its skin; a ruin's, its stones.
		if spec.has("carve"): b["solid"] = BoxSolid.build(b.solid_boxes)
		else: b["solid"] = BoxSolid.build(BoxSolid.from_faces(b.faces) if b.kind == "rock" else b.boxes)
		if b.kind == "rock":
			b["shapes"] = Build.split_faces(b.faces)
		built.append(b)
	return {"key":key,"arches":built,"ms":(Time.get_ticks_usec()-began)/1000.0}

## A cell's arches all committed in the frame its build is taken
## (--arch-commit=cell, as before); else one arch at a time, the frame's
## budget looked at after each, so a cell of bridges and set pieces spreads
## over frames.
var _whole_cells := "--arch-commit=cell" in LaunchArgs.user_args()
## Bodies of a committed rock not yet in the tree: [rock, body], oldest first.
var _feed: Array = []

## Commits `done`'s arches from where it stopped: all of them, or with
## `sliced` until the budget from `began` (µs) is spent. True once the cell
## is done (or dropped); the cell's records stand in `_cells` from its
## first arch on.
func _commit_one(done: Dictionary, sliced := false, began := 0) -> bool:
	var key: Vector2i = done.key
	var t0 := Time.get_ticks_usec()
	var arches: Array = done.arches
	if not done.has("at"):
		stats.built_ms += float(done.ms)
		stats.slowest_build_ms = maxf(stats.slowest_build_ms,float(done.ms))
		if _cells.has(key) or _cell_distance(key,_eye) > _reach_of(key)+Plan.CELL*2.0:
			for b: Dictionary in arches:
				if b.has("node"): (b.node as Node).free()
			return true
		done.at = 0
		done.records = []
		_cells[key] = done.records
	var records: Array = done.records
	if not is_same(_cells.get(key),records):
		# Freed (out of reach) part done: the rest never joins the tree.
		for i in range(int(done.at),arches.size()):
			if (arches[i] as Dictionary).has("node"): (arches[i].node as Node).free()
		return true
	while int(done.at) < arches.size():
		if sliced and int(done.at) > 0 and (Time.get_ticks_usec()-began)/1000.0 > COMMIT_BUDGET:
			stats.slowest_commit_ms = maxf(stats.slowest_commit_ms,(Time.get_ticks_usec()-t0)/1000.0)
			return false
		var b: Dictionary = arches[int(done.at)]
		done.at = int(done.at)+1
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
			var mesh: ArrayMesh = b.get("mesh")
			if mesh == null:
				mesh = ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,b.arrays,[],{},RockShape.format(b.arrays))
			mesh.surface_set_material(0,carve_rock if spec.has("carve") and carve_rock != null else material)
			var mi := MeshInstance3D.new()
			mi.name = "Mesh"
			mi.mesh = mesh
			node.add_child(mi)
			var shapes: Array = b.shapes
			for i in shapes.size():
				var body := StaticBody3D.new()
				body.name = "Body" if i == 0 else "Body%d" % (i+1)
				body.collision_layer = LAYER
				body.collision_mask = 0
				var cs := CollisionShape3D.new()
				cs.shape = shapes[i]
				body.add_child(cs)
				# The rest of a big rock's solid joins over frames (`_feed_bodies`).
				if i > 0 and sliced: _feed.append([node,body])
				else: node.add_child(body)
			stats.tris += int(b.tris)
		else:
			node = b.node
			if spec.get("kind","") == "colosseum": Colosseum.realize(node)
			if not _old_stone and not spec.has("tone"): _sunlit(node,spec.has("bridge"),spec.get("kind","") == "colosseum" or (_set_moss(xf.origin) == "tops" and not spec.has("bridge")),xf.origin)
		for body in node.find_children("*","StaticBody3D",true,false):
			(body as StaticBody3D).collision_layer = LAYER
			(body as StaticBody3D).collision_mask = 0
		node.name = name.replace("/","_")
		node.transform = xf
		Build.add_shapes(node)
		add_child(node)
		LayoutOverrides.track(name,node,"piece",coded)
		var solid: Dictionary = b.solid
		var sx := BoxSolid.span_x(solid)
		var reach := maxf(maxf(absf(sx.x),absf(sx.y)),absf(float(solid.z0))+int(solid.nz)*BoxSolid.CELL)+40.0
		records.append({"name":name,"kind":String(spec.get("form",spec.kind)),"node":node,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
			"solid":solid,"reach":reach,"spec":spec})
		stats.arches += 1
	stats.cells = _cells.size()
	stats.slowest_commit_ms = maxf(stats.slowest_commit_ms,(Time.get_ticks_usec()-t0)/1000.0)
	return true

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

## The carve's opening a plane went through moving `from` to `to` this frame:
## {room (m, its middle to the rim, the nearer way), half (the smaller half size),
## name}, or {}. NearMiss scores these: a hole a plane is threading is counted by
## where it went through, whatever a ray up through the roof met.
func gate_crossed(from: Vector3, to: Vector3) -> Dictionary:
	if _gates.is_empty(): return {}
	var list: Variant = _gates.get(Vector2i(floori(to.x/Carve.GATE_CELL),floori(to.z/Carve.GATE_CELL)))
	if list == null: return {}
	for g: Dictionary in list:
		var c: Vector3 = g.c
		var n: Vector3 = g.n
		var d0 := (from-c).dot(n)
		var d1 := (to-c).dot(n)
		if (d0 > 0.0) == (d1 > 0.0): continue
		var p := from.lerp(to,d0/(d0-d1))-c
		var w := float(g.w)
		var h := float(g.h)
		var u := absf(p.dot(g.r as Vector3))
		var v := absf(p.dot(g.u as Vector3))
		if u > w+Carve.GATE_SLACK or v > h+Carve.GATE_SLACK: continue
		return {"room":minf(w-u,h-v),"half":minf(w,h),"name":g.name}
	return {}

## The set pieces (set_plan.gd) standing within their reach of world `p`:
## their records ({name, node, pos, spec, ...}).
func sets_near(p: Vector3) -> Array:
	var out: Array = []
	if _cells.is_empty(): return out
	var c := Plan.cell_of(p.x,p.z)
	for dz in range(-1,2):
		for dx in range(-1,2):
			var list: Variant = _cells.get(c+Vector2i(dx,dz))
			if list == null: continue
			for r: Dictionary in list:
				if not (r.spec as Dictionary).has("set"): continue
				var o: Vector3 = r.pos
				if absf(p.x-o.x) > float(r.reach) or absf(p.z-o.z) > float(r.reach): continue
				out.append(r)
	return out
