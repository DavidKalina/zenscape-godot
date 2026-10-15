class_name CityHang
extends RefCounted
## The city kit's hanging growth: the ruin kit's vine strands (scripts/
## ruin_growth.gd, drawn in its wind-swayed material) hung off any stone laid
## by a motif, with roots, water stains and moss cushions beside them. A
## motif lays its stone as axis-aligned boxes (`block`), then grows strands
## from its edges (`strand`, `root`, `stain`, `cushion`) and takes one growth
## mesh (`mesh`). Growth only, never collided; it draws on its own random
## stream. Strands hug the boxes they hang beside (RuinGrowth's own
## probing), so give it the boxes that face them.
##
## First used by the Weir Stair (scripts/kit_isle/greybox/gb_weir_stair.gd).

const Growth = preload("res://scripts/ruin_growth.gd")

## Root and stain colours (sRGB, over the wet stone): a dark root, the
## algae's green, the water-stain's brown-black.
const ROOT := Color("4a3a28")
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

## A bare root: a dark ribbon hung from `start` (kinking), `length` m,
## `width` m at the root and thinning, leaning along `drift`.
static func root(p: Probe, start: Vector3, length: float, width: float, drift: Vector3, free := 0.85) -> void:
	var out := Vector3(drift.x,0.0,drift.z)
	out = out.normalized() if out.length() > 0.01 else Vector3.BACK
	var side := Vector3(-out.z,0.0,out.x)
	var a := start
	var n := clampi(int(ceil(length/1.6)),1,8)
	for i in n:
		var t0 := float(i)/n
		var t1 := float(i+1)/n
		var w0 := width*(1.0-0.85*t0)
		var w1 := width*(1.0-0.85*t1)
		var kink := side*p.rng.randf_range(-0.12,0.12)+drift*0.18
		var b := a+Vector3.DOWN*length/n+kink
		p.grow = Growth.attrs(start.y,length,out,free,0.25,p.rng.randf(),false,t1)
		var rt := ROOT.srgb_to_linear()
		var rf := p.rng.randf_range(0.8,1.15)
		var colour := Color(rt.r*rf,rt.g*rf,rt.b*rf,1.0)
		p.growth_face(PackedVector3Array([a-side*w0,a+side*w0,b+side*w1,b-side*w1]),out,colour)
		a = b
	p.grow = PackedFloat32Array()

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
