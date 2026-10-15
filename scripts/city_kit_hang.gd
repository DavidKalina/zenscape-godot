class_name CityHang
extends RefCounted
## The city kit's hanging growth: the ruin kit's vine strands (scripts/
## ruin_growth.gd, drawn in its wind-swayed material) hung off any stone laid
## by a motif, with roots, water stains and moss cushions beside them. A
## motif lays its stone as axis-aligned boxes (`block`), then grows strands
## from its edges (`strand`, `root`, `stain`, `cushion`) and takes one growth
## mesh (`mesh`). Roots are the kit's HangingRoots (scripts/kit_isle/
## hanging_roots.gd), one MultiMesh taken with `roots`. Growth only, never
## collided; it draws on its own random stream. Strands hug the boxes they hang beside (RuinGrowth's own
## probing), so give it the boxes that face them.
##
## First used by the Weir Stair (scripts/kit_isle/greybox/gb_weir_stair.gd).

const Growth = preload("res://scripts/ruin_growth.gd")
const Roots = preload("res://scripts/kit_isle/hanging_roots.gd")

## Stain colours (sRGB, over the wet stone): the algae's green, the
## water-stain's brown-black.
const ALGAE := Color("2c3a1e")
const STAIN := Color("33322c")
const MOSS := Color("3d4a24")

## One growth pass: the boxes strands hug (AABBs), the faces gathered, the
## state RuinGrowth's strand reads (`rng`, `grow`, `lean`).
class Probe extends RefCounted:
	var boxes: Array = []
	var faces := Growth.Faces.new()
	var rng := RandomNumberGenerator.new()
	var grow := PackedFloat32Array()
	var lean := false
	var triangles := 0
	## Roots laid (Vector4: x, y top, z, length), for `roots`.
	var roots: Array = []

	func _inside(p: Vector3) -> bool:
		for b: AABB in boxes:
			if b.has_point(p): return true
		return false

	func _gap(p: Vector3, dir: Vector3, most: float) -> float:
		var t := 0.0
		while t < most:
			if _inside(p+dir*t): return t
			t += 0.06
		return most

	func floor_at(_x: float, _z: float) -> float:
		return -1.0e6

	func kept_clear(_p: Vector3) -> bool:
		return false

	func growth_face(corners: PackedVector3Array, normal: Vector3, colour: Color) -> void:
		Growth.emit(faces,corners,normal,colour,grow)
		triangles += corners.size()-2

## The roots' mesh and material (main thread, a motif's warm).
static func warm() -> void:
	Roots.warm()

static func probe(seed_value: int) -> Probe:
	var p := Probe.new()
	p.rng.seed = seed_value
	return p

## A solid box the strands hug (centre `c`, half extents `h`).
static func block(p: Probe, c: Vector3, h: Vector3) -> void:
	p.boxes.append(AABB(c-h,h*2.0))

## A vine strand from `start` down `length` m, off a face looking `out`
## (`coarse` 1 leafy and near, up to 2 coarse and far).
static func strand(p: Probe, start: Vector3, length: float, out: Vector3, coarse := 1.6, free := false) -> void:
	Growth.strand(p,start,length,out,free,coarse,true)

## A clump of strands along a wall's head: `count` strands `step` m apart
## along `along`, longest in the middle, off a face looking `out`.
static func fringe(p: Probe, start: Vector3, along: Vector3, count: int, step: float, length: float, out: Vector3, coarse := 1.6, free := false) -> void:
	for j in count:
		var t := (j+0.5)/count
		var at := start+along*(t-0.5)*count*step
		var l := length*(0.45+0.55*sin(PI*t))*p.rng.randf_range(0.7,1.1)
		if l < 0.4: continue
		strand(p,at,l,out,coarse,free)

## A bare root hung from `start`, `length` m (HangingRoots' strand, whose
## thickness follows its length; `_width`, `_drift`, `_free` are kept so
## callers hold). It still burns the three draws a segment the old ribbon
## took, so the stains and strands laid after it fall where they did.
static func root(p: Probe, start: Vector3, length: float, _width := 0.1, _drift := Vector3.BACK, _free := 0.85) -> void:
	for i in clampi(int(ceil(length/1.6)),1,8)*3: p.rng.randf()
	p.roots.append(Vector4(start.x,start.y,start.z,length))

## The pass's roots as one MultiMeshInstance3D (HangingRoots), or null.
static func roots(p: Probe, seed_value: int) -> MultiMeshInstance3D:
	if p.roots.is_empty(): return null
	var mm := Roots.batch(p.roots,seed_value)
	mm.set_meta("triangles",p.roots.size()*Roots.triangles())
	return mm

## A water stain or algae streak lying on a face: a tapering strip from
## `top` down `length` m, `width` wide, `out` the face's way (sat 3 cm off it,
## creeping `creep` m out a m down for a battered face).
static func stain(p: Probe, top: Vector3, length: float, width: float, out: Vector3, colour: Color, creep := 0.0) -> void:
	var o := Vector3(out.x,0.0,out.z).normalized()
	var side := Vector3(-o.z,0.0,o.x)
	var a := top+o*0.03
	var seg := 1.2
	var n := maxi(int(ceil(length/seg)),1)
	var lin := colour.srgb_to_linear()
	p.grow = Growth.still()
	for i in n:
		var t0 := float(i)/n
		var t1 := float(i+1)/n
		var w0 := width*0.5*(1.0-0.75*t0)*(1.0+0.3*sin(t0*9.0+top.x))
		var w1 := width*0.5*(1.0-0.75*t1)*(1.0+0.3*sin(t1*9.0+top.x))
		var b := a+Vector3.DOWN*length/n+o*creep*length/n+side*p.rng.randf_range(-0.05,0.05)
		var f := 1.0-0.5*t1
		p.growth_face(PackedVector3Array([a-side*w0,a+side*w0,b+side*w1,b-side*w1]),o,Color(lin.r*f,lin.g*f,lin.b*f,1.0))
		a = b
	p.grow = PackedFloat32Array()

## A moss cushion lying on a top at `at`: an uneven disc `radius` m.
static func cushion(p: Probe, at: Vector3, radius: float, colour := MOSS) -> void:
	p.grow = Growth.attrs(0.0,0.0,Vector3.ZERO,0.0,0.0,0.0,false,0.45)
	var pts := PackedVector3Array()
	var n := 7
	var turn := p.rng.randf()*TAU
	for i in n:
		var a := turn+TAU*i/n
		pts.append(at+Vector3(cos(a),0.0,sin(a))*radius*p.rng.randf_range(0.6,1.1)+Vector3.UP*p.rng.randf_range(0.02,0.07))
	var lin := colour.srgb_to_linear()
	var cf := p.rng.randf_range(0.85,1.2)
	var c := Color(lin.r*cf,lin.g*cf,lin.b*cf,1.0)
	p.growth_face(pts,Vector3.UP,c)
	p.grow = PackedFloat32Array()

## The pass's growth as a mesh instance in the growth material, or null.
static func mesh(p: Probe, node_name := "Hang") -> MeshInstance3D:
	if p.faces.is_empty(): return null
	var m := ArrayMesh.new()
	Growth.add_surface(m,p.faces)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("triangles",p.triangles)
	return mi
