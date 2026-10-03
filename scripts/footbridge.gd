extends Node3D
## Footbridges (docs/scenic/bridges.md): timber spans laid across a stream or
## a narrow water by a drag with the case's footbridge in hand
## (scripts/hand_materials.gd). The terrain decides. A drag only says roughly
## where to cross; the bridge snaps from bank to bank across the water found
## under it, its two ends resting on the ground. With no water there, a span
## longer than MAX_SPAN or banks too far apart in height, nothing is laid; the
## ghost shown while dragging says so.
##
## A bridge is an object record (NativeTerrainData `add_bridge`: "bridge",
## x/z the near bank, end_x/end_z the far one), so undo, saving and the trash
## can (scripts/clay_tools/trash.gd) take it as they take any record. It is
## drawn here, not by the garden's instance batches: each record is one
## faceted mesh in plate metres, a child of the terrain, rebuilt from the
## ground under its ends whenever the records or the land change. It changes
## no height and holds no water: the live water runs under it untouched.
##
## The planning half is static (`water`, `level_at`, `plan`) so probes and the
## editor read the same answer the ghost shows.

const ClaySound = preload("res://scripts/clay_sound.gd")

## The longest span (bank to bank, m), and the shortest worth a bridge.
const MAX_SPAN := 6.0
const MIN_SPAN := 1.0
## Rise over run between the two banks beyond which it is too steep.
const MAX_GRADE := 0.35
## How far onto each bank (m) past the water's edge an end rests.
const BANK := 0.45
## The planner's step along the drag (m), and how far past the drag's ends it
## looks for the water the drag meant.
const STEP := 0.1
const REACH := 1.5
## Water this deep (m) counts; the deck's underside must clear it by CLEARANCE.
const WET := 0.03
const CLEARANCE := 0.02
## Spans this long and longer have hand rails; shorter ones only end posts.
const RAILS_FROM := 2.5
## The deck: width (m) and the planks' depth.
const WIDTH := 0.74
const PLANK := 0.2
const DECK_DEPTH := 0.12
## Timber tones (sRGB): weathered deck, darker stringers and sills, rails.
const DECK := Color("8a6a4a")
const BEAM := Color("5a4330")
const SILL := Color("4c3a2a")
const RAIL := Color("6f5238")
## The ghost: warm and faint where it would be laid, a dull red where not.
const GHOST_OK := Color(1.0,0.94,0.8,0.42)
const GHOST_NO := Color(0.86,0.42,0.36,0.3)

## The editor (NativeChunkEditor): its `data` holds the records.
var editor: Node
## Bridges rebuilt and reused, for probes.
var rebuilt := 0
var reused := 0
var _entries := {}
var _revision := -1
var _material: StandardMaterial3D
var _ghost: MeshInstance3D
var _ghost_key := PackedByteArray()

func _init() -> void:
	name = "Footbridges"
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.9
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

# --- Reading the water --------------------------------------------------------

## What water the planner reads, gathered once for a drag: the live water's
## depths, the pond surfaces (with their bounds) and the stream beds'
## segments. {"data", "flow", "depths", "ponds", "courses"}.
static func water(source: Node) -> Dictionary:
	var data: NativeTerrainData = source.data
	var flow: Variant = source.get("flow")
	var live: bool = flow != null and flow.ready
	var ponds := []
	for pond: Dictionary in data.ponds:
		var surface := data.pond_surface(pond)
		if surface.is_empty(): continue
		var bounds := Rect2(Vector2(surface[0].x,surface[0].z),Vector2.ZERO)
		for vertex in surface: bounds = bounds.expand(Vector2(vertex.x,vertex.z))
		ponds.append({"surface":surface,"bounds":bounds,"level":float(pond.level)})
	var courses := []
	for stream: Dictionary in data.streams:
		var pts: Array = stream.get("pts",[])
		for i in range(pts.size()-1):
			var a: Dictionary = pts[i]
			var b: Dictionary = pts[i+1]
			courses.append({"a":Vector2(a.x,a.z),"b":Vector2(b.x,b.z),"half":float(stream.get("width",0.6))*0.5,"level":maxf(float(a.h),float(b.h))+float(stream.get("surface",0.06))})
	return {"data":data,"flow":flow if live else null,"depths":flow.depths() if live else PackedFloat32Array(),"ponds":ponds,"courses":courses}

## The water's surface over plate point `p`, or -INF where it is dry (or off
## the land): live water at least WET deep, a pond, or a stream bed.
static func level_at(found: Dictionary, p: Vector2) -> float:
	var data: NativeTerrainData = found.data
	var ground: Variant = data.ground_height(p)
	if ground == null: return -INF
	var best := -INF
	var flow: Variant = found.flow
	if flow != null:
		var cell: int = flow.cell_at(p)
		var depths: PackedFloat32Array = found.depths
		if cell >= 0 and cell < depths.size() and depths[cell] >= WET: best = float(ground)+depths[cell]
	for pond: Dictionary in found.ponds:
		if float(pond.level) < float(ground)+WET or not (pond.bounds as Rect2).has_point(p): continue
		if GardenWater.covers(pond.surface,p): best = maxf(best,float(pond.level))
	for course: Dictionary in found.courses:
		if float(course.level) <= float(ground): continue
		if Geometry2D.get_closest_point_to_segment(p,course.a,course.b).distance_to(p) <= float(course.half): best = maxf(best,float(course.level))
	return best

## The arch's rise (m) at mid-span for a span `span` m long.
static func rise(span: float) -> float:
	return clampf(0.08*span+0.1,0.15,0.6)

## Where a drag from `from` to `to` (plate) would lay a bridge over `found`
## (`water`). {"ok": true, "a", "b" (banks, plate), "ya", "yb" (ground
## there), "span", "water" (highest level crossed)}, or {"ok": false,
## "reason"}: "short" (no drag to read), "dry" (no water near the drag),
## "too_long" (more than MAX_SPAN bank to bank), "edge" (a bank off the
## land), "no_bank" (water at an end), "too_steep", or "flooded" (the water
## stands as high as the deck). A refusal past the snap keeps "a" and "b".
static func plan(found: Dictionary, from: Vector2, to: Vector2) -> Dictionary:
	var axis := to-from
	var length := axis.length()
	if length < 0.25: return {"ok":false,"reason":"short"}
	var way := axis/length
	# The wet sample nearest the drag's middle, on the drag or just past it.
	var seed_t := NAN
	var nearest := INF
	var t := -REACH
	while t <= length+REACH:
		if level_at(found,from+way*t) > -INF and absf(t-length*0.5) < nearest:
			nearest = absf(t-length*0.5)
			seed_t = t
		t += STEP
	if is_nan(seed_t): return {"ok":false,"reason":"dry"}
	# Out along the line to the water's edges on both sides.
	var low := seed_t
	var high := seed_t
	while level_at(found,from+way*(low-STEP)) > -INF:
		low -= STEP
		if high-low+STEP+2.0*BANK > MAX_SPAN: return {"ok":false,"reason":"too_long"}
	while level_at(found,from+way*(high+STEP)) > -INF:
		high += STEP
		if high-low+STEP+2.0*BANK > MAX_SPAN: return {"ok":false,"reason":"too_long"}
	var ta := low-STEP*0.5-BANK
	var tb := high+STEP*0.5+BANK
	var span := tb-ta
	var a := from+way*ta
	var b := from+way*tb
	if span > MAX_SPAN: return {"ok":false,"reason":"too_long","a":a,"b":b}
	if span < MIN_SPAN:
		# A rill: lengthen the ends evenly to the shortest bridge.
		var grow := (MIN_SPAN-span)*0.5
		ta -= grow
		tb += grow
		span = MIN_SPAN
		a = from+way*ta
		b = from+way*tb
	var data: NativeTerrainData = found.data
	var ga: Variant = data.ground_height(a)
	var gb: Variant = data.ground_height(b)
	if ga == null or gb == null: return {"ok":false,"reason":"edge","a":a,"b":b}
	if level_at(found,a) > -INF or level_at(found,b) > -INF: return {"ok":false,"reason":"no_bank","a":a,"b":b}
	var ya := float(ga)
	var yb := float(gb)
	if absf(yb-ya)/span > MAX_GRADE: return {"ok":false,"reason":"too_steep","a":a,"b":b}
	var top := -INF
	var arch := rise(span)
	t = low
	while t <= high+0.001:
		var level := level_at(found,from+way*t)
		var u := (t-ta)/span
		var under := lerpf(ya,yb,u)+arch*sin(PI*u)-DECK_DEPTH
		if level > -INF and under < level+CLEARANCE: return {"ok":false,"reason":"flooded","a":a,"b":b}
		top = maxf(top,level)
		t += STEP
	return {"ok":true,"a":a,"b":b,"ya":ya,"yb":yb,"span":span,"water":top}

# --- Drawing ------------------------------------------------------------------

## Each frame: a change to the records (a placement, the trash can, an undo)
## redraws what changed. The editor's refresh redraws after the land moves.
func _process(_delta: float) -> void:
	if editor == null or editor.data == null: return
	if int(editor.data.objects_revision) != _revision: rebuild()

## Draws every bridge record from the ground under its ends; a bridge whose
## ends have not moved keeps its mesh.
func rebuild() -> void:
	if editor == null: return
	var data: NativeTerrainData = editor.data
	_revision = data.objects_revision
	var current := {}
	for item: Dictionary in data.objects:
		if item.asset != "bridge" or not item.has("end_x"): continue
		var ends := ends_of(data,item)
		if ends.is_empty(): continue
		var signature := var_to_bytes(ends)
		var entry: Dictionary = _entries.get(int(item.id),{})
		if not entry.is_empty() and entry.signature == signature and is_instance_valid(entry.node):
			reused += 1
		else:
			if not entry.is_empty() and is_instance_valid(entry.node): entry.node.free()
			var node := MeshInstance3D.new()
			node.name = "bridge_%d" % int(item.id)
			node.mesh = build_mesh(ends[0],ends[1],int(item.id))
			node.material_override = _material
			add_child(node)
			entry = {"node":node,"signature":signature}
			rebuilt += 1
		current[int(item.id)] = entry
	for id: int in _entries:
		if not current.has(id) and is_instance_valid(_entries[id].node): _entries[id].node.free()
	_entries = current

## A record's two ends on the ground (plate), or [] when one is off the land.
static func ends_of(data: NativeTerrainData, item: Dictionary) -> PackedVector3Array:
	var a := Vector2(float(item.x),float(item.z))
	var b := Vector2(float(item.end_x),float(item.end_z))
	var ya: Variant = data.ground_height(a)
	var yb: Variant = data.ground_height(b)
	if ya == null or yb == null: return PackedVector3Array()
	return PackedVector3Array([Vector3(a.x,float(ya),a.y),Vector3(b.x,float(yb),b.y)])

## The drawn bridge for record `id`, or null.
func node_of(id: int) -> MeshInstance3D:
	var entry: Dictionary = _entries.get(id,{})
	return entry.node if not entry.is_empty() and is_instance_valid(entry.node) else null

## Bridges drawn now.
func count() -> int:
	return _entries.size()

## Record `id`'s drawn parts, [{mesh, material, transform (world)}], for the
## trash can's flight.
func parts(id: int) -> Array[Dictionary]:
	var node := node_of(id)
	if node == null: return []
	return [{"mesh":node.mesh,"material":_material,"transform":node.global_transform}]

# --- The ghost ----------------------------------------------------------------

## While a drag is under way: the bridge it would lay, faint and warm, or,
## where none would go, a dull red one along the drag itself (from the snap's
## banks when the refusal came after it). Hidden for a drag too short to read.
func show_ghost(found: Dictionary, from: Vector2, to: Vector2) -> void:
	var data: NativeTerrainData = editor.data
	var ok: bool = found.get("ok",false)
	var a: Vector2 = found.get("a",from)
	var b: Vector2 = found.get("b",to)
	var ya: Variant = data.ground_height(a)
	var yb: Variant = data.ground_height(b)
	if a.distance_to(b) < 0.3 or ya == null or yb == null:
		hide_ghost()
		return
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.name = "BridgeGhost"
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ghost.material_override = material
		add_child(_ghost)
	var ends := PackedVector3Array([Vector3(a.x,float(ya),a.y),Vector3(b.x,float(yb),b.y)])
	var key := var_to_bytes([ends,ok])
	if key != _ghost_key:
		_ghost_key = key
		_ghost.mesh = build_mesh(ends[0],ends[1],0)
		(_ghost.material_override as StandardMaterial3D).albedo_color = GHOST_OK if ok else GHOST_NO
	_ghost.visible = true

func hide_ghost() -> void:
	if _ghost != null: _ghost.visible = false

## The ghost's state, for probes: "" hidden, else "ok" or "no".
func ghost_state() -> String:
	if _ghost == null or not _ghost.visible: return ""
	return "ok" if (_ghost.material_override as StandardMaterial3D).albedo_color == GHOST_OK else "no"

# --- The mesh -----------------------------------------------------------------

## A faceted timber footbridge from `a` to `b` (plate, on the ground), in
## plate metres. A gentle arch (`rise`) of planks laid across two stringers,
## a sill log under each end, and posts: corner stubs on a short span, posts
## and a hand rail each side from RAILS_FROM. Every plank is cut a little
## differently (`seed`), each face flat-shaded in its own tone.
static func build_mesh(a: Vector3, b: Vector3, seed: int) -> ArrayMesh:
	var flat := Vector3(b.x-a.x,0.0,b.z-a.z)
	var span := maxf(flat.length(),0.01)
	var across := (flat/span).cross(Vector3.UP).normalized()
	var arch := rise(span)
	var curve := func(t: float) -> Vector3: return a.lerp(b,t)+Vector3.UP*arch*sin(PI*t)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*7919+104729
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Planks across the arch, each on the curve's slope.
	var planks := maxi(4,roundi(span/PLANK))
	for i in range(planks):
		var t := (i+0.5)/planks
		var along: Vector3 = (curve.call(minf(t+0.01,1.0))-curve.call(maxf(t-0.01,0.0))).normalized()
		var up := across.cross(along).normalized()
		if up.y < 0.0: up = -up
		var yaw := Basis(up,rng.randf_range(-0.05,0.05))
		var centre: Vector3 = curve.call(t)+across*rng.randf_range(-0.03,0.03)+up*rng.randf_range(-0.008,0.008)
		var half := Vector3(span/planks*0.42,0.025+rng.randf_range(0.0,0.008),WIDTH*0.5+rng.randf_range(-0.04,0.03))
		_box(st,centre-up*half.y,yaw*along,up,yaw*across,half,DECK.darkened(rng.randf_range(0.0,0.14)),rng)
	# Two stringers under them, in straight pieces along the arch.
	var pieces := 8
	for side in [-1.0,1.0]:
		var offset: Vector3 = across*side*WIDTH*0.34
		_beam(st,curve,offset+Vector3.DOWN*0.11,pieces,Vector2(0.05,0.045),BEAM,rng)
	# A sill log across under each end, half sunk.
	for t in [0.0,1.0]:
		var at: Vector3 = curve.call(t)
		var way := (b-a).normalized()
		_box(st,at+Vector3.DOWN*0.12,way,Vector3.UP,across,Vector3(0.09,0.08,WIDTH*0.62),SILL.darkened(rng.randf_range(0.0,0.1)),rng)
	# Posts, and a rail along them on a longer span.
	var rails := span >= RAILS_FROM
	var stops := [0.03,0.97]
	if rails:
		stops = [0.03,0.5,0.97] if span < 4.5 else [0.03,0.3,0.7,0.97]
	var tall := 0.56 if rails else 0.2
	for side in [-1.0,1.0]:
		var offset: Vector3 = across*side*(WIDTH*0.5+0.03)
		for t: float in stops:
			var foot: Vector3 = curve.call(t)+offset+Vector3.DOWN*0.12
			_box(st,foot+Vector3.UP*(tall+0.12)*0.5,(b-a).normalized(),Vector3.UP,across,Vector3(0.04,(tall+0.12)*0.5,0.04),RAIL.darkened(rng.randf_range(0.0,0.12)),rng)
		if rails:
			_beam(st,curve,offset+Vector3.UP*(tall-0.03),pieces,Vector2(0.028,0.032),RAIL,rng,stops[0],stops[-1])
	return st.commit()

## A beam along the arch from `t0` to `t1` in `pieces` straight lengths,
## `offset` from the curve, `size` (half height, half width).
static func _beam(st: SurfaceTool, curve: Callable, offset: Vector3, pieces: int, size: Vector2, colour: Color, rng: RandomNumberGenerator, t0 := 0.0, t1 := 1.0) -> void:
	for k in range(pieces):
		var p: Vector3 = curve.call(lerpf(t0,t1,float(k)/pieces))+offset
		var q: Vector3 = curve.call(lerpf(t0,t1,float(k+1)/pieces))+offset
		var along := (q-p).normalized()
		var side := along.cross(Vector3.UP).normalized()
		var up := side.cross(along).normalized()
		_box(st,(p+q)*0.5,along,up,side,Vector3(p.distance_to(q)*0.5+0.015,size.x,size.y),colour.darkened(rng.randf_range(0.0,0.08)),rng)

## A box centred at `centre` on axes `x`, `y`, `z` (unit) with half extents
## `half`, each face flat in a tone near `colour`.
static func _box(st: SurfaceTool, centre: Vector3, x: Vector3, y: Vector3, z: Vector3, half: Vector3, colour: Color, rng: RandomNumberGenerator) -> void:
	var corner := func(i: int, j: int, k: int) -> Vector3: return centre+x*half.x*i+y*half.y*j+z*half.z*k
	# Each face: its outward axis and four corners round it.
	var faces := [
		[y,[corner.call(-1,1,-1),corner.call(1,1,-1),corner.call(1,1,1),corner.call(-1,1,1)],1.08],
		[-y,[corner.call(-1,-1,1),corner.call(1,-1,1),corner.call(1,-1,-1),corner.call(-1,-1,-1)],0.7],
		[x,[corner.call(1,-1,-1),corner.call(1,-1,1),corner.call(1,1,1),corner.call(1,1,-1)],0.92],
		[-x,[corner.call(-1,-1,1),corner.call(-1,-1,-1),corner.call(-1,1,-1),corner.call(-1,1,1)],0.88],
		[z,[corner.call(1,-1,1),corner.call(-1,-1,1),corner.call(-1,1,1),corner.call(1,1,1)],0.96],
		[-z,[corner.call(-1,-1,-1),corner.call(1,-1,-1),corner.call(1,1,-1),corner.call(-1,1,-1)],0.84],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var quad: Array = face[1]
		var tone: Color = colour*float(face[2])*rng.randf_range(0.95,1.04)
		tone.a = 1.0
		# Clockwise seen from outside, Godot's front face.
		var order := [0,1,2,0,2,3]
		var n: Vector3 = ((quad[1]-quad[0]) as Vector3).cross(quad[2]-quad[0])
		if n.dot(normal) > 0.0: order = [0,2,1,0,3,2]
		for index: int in order:
			st.set_color(tone)
			st.set_normal(normal)
			st.add_vertex(quad[index])
