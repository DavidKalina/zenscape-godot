extends RefCounted
## The Olmec's destruction, round 2: masonry pre-cut for
## scripts/kit_isle/colonnade_breaks.gd to
## bring down. A piece is built again once for each part it breaks into, the
## same stones as the whole each time (RuinKit Build `keep_only`), so the
## parts break along its joints: a coursed wall comes apart in stepped
## cracks, an arch at its voussoirs.
##
##   gable(seed, weathered)   the temple's rose gable (RuinKit `rose_gable`),
##                            punched through at its door: what stands after
##                            (both flanks, the plinth, the drift) and the
##                            slabs that fall (the door's two halves, the
##                            walls either side over it, the rose in
##                            quarters, the rake, the apex).
##   ring(seed, frame, ...)   a portal's arch ring (RuinKit `_arch_ring`):
##                            its springer each side (a remains, as the pier
##                            under it stands) and five chunks.
##
## A part: {mesh (MeshInstance3D, its stone round `at`), shape (Shape3D),
## at (its middle, the piece's frame), kg, kind}.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build
const STONE_KG := 2300.0
## A falling part's hull drawn in this share toward its middle (in the
## wall's plane; its depth kept): neighbours' hulls never start inside each
## other, nor in what stands.
const HULL_IN := 0.86

# --- The rose gable --------------------------------------------------------------------------

## The breach his punch opens (the gable's frame: x across, y up, z out its
## face): this half wide at `y` up, widening as it goes (his shoulders
## through at the bottom, the wall above it unsupported).
static func breach(y: float, seed_value: int) -> float:
	return 5.3+0.2*y+0.35*sin(y*1.9+seed_value)+0.2*sin(y*4.3+seed_value*2.0)

## How high a flank stands at `x` (its side's own: the north flank higher).
static func flank_top(x: float, seed_value: int) -> float:
	var out := absf(x)-5.3
	var base := 6.6+1.1*out if x < 0.0 else 5.0+0.9*out
	return base+0.5*sin(x*2.3+seed_value)

## The part of the gable a stone whose middle is `c` belongs to: "" stands.
static func gable_part(c: Vector3, seed_value: int) -> String:
	var rose := Vector2(0.0,RuinKit.ROSE.x)
	var d := RuinKit.ARCH_DEPTH*0.5
	if c.y < 0.42: return ""
	# The drift and rubble on the ground before it, the fallen hub.
	if absf(c.z) > d+0.25 and c.y < 1.6 and absf(c.x) < RuinKit.GABLE.x*0.5-1.4: return ""
	if absf(c.x) > breach(c.y,seed_value) and c.y < flank_top(c.x,seed_value): return ""
	# The rose in quarters (whole, a wheel this big lands on its rim and
	# stands): cut across its middle, a little off square.
	if Vector2(c.x,c.y).distance_to(rose) < RuinKit.ROSE.y+0.45:
		var a := atan2(c.y-rose.y,c.x)+0.35
		return "rose_"+("t" if sin(a) > 0.0 else "b")+("r" if cos(a) > 0.0 else "l")
	var crack := 0.25*(c.y-2.0)+0.3*sin(c.y*2.7+seed_value)
	var side := "l" if c.x < crack else "r"
	# Over a flank's broken top: the rake's (never a wall slab's hull
	# reaching out over the flank that stands).
	if absf(c.x) > breach(c.y,seed_value): return "rake_"+("l" if c.x < 0.0 else "r")
	if c.y < 4.9: return "door_"+side
	if c.y < 9.2: return "wall_"+side
	if absf(c.x) < 2.6 and c.y > rose.y: return "apex"
	return "rake_"+side

const GABLE_PARTS := ["door_l","door_r","wall_l","wall_r","rose_tl","rose_tr","rose_bl","rose_br","rake_l","rake_r","apex"]

## The gable as it stands after (a piece: Mesh and Body, `detail` its
## growth) and its falling parts, each in the gable's frame.
static func gable(seed_value: int, weathered: float, detail: float) -> Dictionary:
	var was := Build.detail
	Build.detail = detail
	Build.keep_only = func(c: Vector3) -> bool: return gable_part(c,seed_value) == ""
	var stands: Node3D = RuinKit.rose_gable(seed_value,weathered)
	stands.name = "GableStands"
	Build.detail = 0.0
	var parts: Array = []
	for id: String in GABLE_PARTS:
		Build.keep_only = func(c: Vector3) -> bool: return gable_part(c,seed_value) == id
		var built: Node3D = RuinKit.rose_gable(seed_value,weathered)
		var part := _part(built,id)
		built.free()
		if not part.is_empty(): parts.append(part)
	Build.keep_only = Callable()
	Build.detail = was
	return {"stands":stands,"parts":parts}

# --- Any kit piece, by bands ------------------------------------------------------------------

## A kit piece (RuinKit `piece` id, seed, wear) broken where his bulk meets
## it: what stands below `stump` m (a ragged line) and the rest above in
## halves along its length, and in two tiers if it stands over `tier` m;
## `box` its stone's bounds (its frame).
static func piece_part(c: Vector3, box: AABB, stump: float, tier: float, seed_value: int) -> String:
	var mid := box.get_center()
	var line := stump+0.5*sin(c.x*1.7+seed_value)+0.3*sin(c.z*2.3+seed_value)
	if c.y < line: return ""
	var long := 0 if box.size.x >= box.size.z else 2
	var side := "a" if c[long] < mid[long]+0.4*sin(c.y*1.3+seed_value) else "b"
	if box.size.y > tier and c.y > box.position.y+box.size.y*0.55: return "hi_"+side
	return "lo_"+side

const PIECE_PARTS := ["lo_a","lo_b","hi_a","hi_b"]

static func piece(id: String, seed_value: int, weathered: float, box: AABB, stump: float, tier: float, detail: float) -> Dictionary:
	var was := Build.detail
	Build.detail = detail
	Build.keep_only = func(c: Vector3) -> bool: return piece_part(c,box,stump,tier,seed_value) == ""
	var stands: Node3D = RuinKit.piece(id,seed_value,weathered)
	stands.name = "Stands"
	Build.detail = 0.0
	var parts: Array = []
	for pid: String in PIECE_PARTS:
		Build.keep_only = func(c: Vector3) -> bool: return piece_part(c,box,stump,tier,seed_value) == pid
		var built: Node3D = RuinKit.piece(id,seed_value,weathered)
		var part := _part(built,pid)
		built.free()
		if not part.is_empty(): parts.append(part)
	Build.keep_only = Callable()
	Build.detail = was
	return {"stands":stands,"parts":parts}

# --- A portal's ring ----------------------------------------------------------------------------

## The chunk of a portal's ring (its frame: x across, y up from its foot) a
## voussoir whose middle is `c` falls in: "spring_l" / "spring_r" the
## springer on that side, "low_", "high_" up it, "crown".
static func ring_part(c: Vector3, spring: float, h: float) -> String:
	var up := c.y-spring
	var side := "l" if c.x < 0.0 else "r"
	var crown := RuinKit._rise(h,2.0*h)
	if up < crown*0.22: return "spring_"+side
	if up < crown*0.55: return "low_"+side
	if up < crown*0.82: return "high_"+side
	return "crown"

const RING_PARTS := ["low_l","low_r","high_l","high_r","crown"]

## A portal's ring at `frame` (world), springing at `spring` over it, clear
## half span `h`: standing whole (a piece, `detail` its growth), its
## springers each as a remains (`spring_l`, `spring_r`: pieces too) and the
## chunks (parts, world).
static func ring(seed_value: int, weathered: float, frame: Transform3D, spring: float, h: float, lost: int, lost_side: float, detail: float) -> Dictionary:
	var inv := frame.affine_inverse()
	var make := func(keep: Callable, label: String) -> Node3D:
		Build.keep_only = keep
		var b := Build.new(seed_value,weathered,label)
		b.settle = 0.5
		RuinKit._arch_ring(b,frame,0.0,spring,h,2.0*h,RuinKit.ARCH_DEPTH*0.5,false,lost,lost_side)
		var node := b.finish()
		Build.keep_only = Callable()
		return node
	var was := Build.detail
	Build.detail = detail
	var whole: Node3D = make.call(Callable(),"Portal")
	var springs := {}
	for side: String in ["l","r"]:
		var id := "spring_"+side
		springs[id] = make.call(func(c: Vector3) -> bool: return ring_part(inv*c,spring,h) == id,"PortalSpring")
	Build.detail = 0.0
	var parts: Array = []
	for id: String in RING_PARTS:
		var built: Node3D = make.call(func(c: Vector3) -> bool: return ring_part(inv*c,spring,h) == id,"PortalChunk")
		var part := _part(built,id)
		built.free()
		if not part.is_empty(): parts.append(part)
	Build.detail = was
	return {"whole":whole,"springs":springs,"parts":parts}

# --- A part ----------------------------------------------------------------------------------

## A built piece's stone (its "Mesh", surface 0) round its middle, with a
## hull drawn in a little: {mesh, shape, at, kg, kind}, or {} if empty.
static func _part(built: Node3D, kind: String) -> Dictionary:
	var mi := built.get_node_or_null("Mesh") as MeshInstance3D
	if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0: return {}
	var arrays: Array = mi.mesh.get_meta("arrays") if mi.mesh.has_meta("arrays") else mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if v.size() < 12: return {}
	var box := AABB(v[0],Vector3.ZERO)
	for q in v: box = box.expand(q)
	var at := box.get_center()
	var moved := PackedVector3Array()
	moved.resize(v.size())
	for i in range(v.size()): moved[i] = v[i]-at
	var surface := arrays.duplicate()
	surface[Mesh.ARRAY_VERTEX] = moved
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface)
	mesh.surface_set_material(0,RuinKit.materials().stone)
	mesh.set_meta("arrays",surface)
	var out := MeshInstance3D.new()
	out.name = "Mesh"
	out.mesh = mesh
	# The hull: the stone's points (thinned), drawn in toward the middle
	# across its least-deep way (the wall's plane), its depth kept.
	var thin := _least_axis(box.size)
	var pts := PackedVector3Array()
	var stride := maxi(1,moved.size()/1500)
	for i in range(0,moved.size(),stride):
		var q := moved[i]
		var s := q*HULL_IN
		s[thin] = q[thin]
		pts.append(s)
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	# Its mass: what its hull holds, a wall's stones close-laid.
	var vol := box.size.x*box.size.y*box.size.z*0.45
	return {"mesh":out,"shape":shape,"at":at,"kg":STONE_KG*vol,"kind":kind,"size":box.size}

static func _least_axis(s: Vector3) -> int:
	if s.x <= s.y and s.x <= s.z: return 0
	if s.y <= s.z: return 1
	return 2
