extends RefCounted
## A plain description of a piece of the giants' city (giant_city.gd, whose
## header is the contract): a list of upright shapes in the piece's own frame,
## from which one code path makes the near mesh, the far mesh and the solid.
##
## Every shape is convex with a level top and bottom, so over a point it covers
## one stretch of height, worked out exactly (`stretch`):
##   box(lo, hi)                      a box
##   slope(low, high, y0, y1)         a box whose level rect runs from `low` at y0
##                                    to `high` at y1, any side leaning any way:
##                                    Rect2s in (x, z), so a battered wall, a
##                                    stepped pyramid's course, a jamb
##   cyl(at, r0, r1, tall, sides)     a round shaft, drum or cone from `at` up
##   stamp(block, at, yaw)            another CityShapes, its meshes shared by
##                                    every stamp of it: a column in a row
##
## `layer` says what the shapes after it belong to: BOTH (near and far, the
## solid), NEAR (detail: near only, solid) or FAR (the far mesh's stand-in, never
## solid). A round shape's far mesh has half its sides. A shape that starts under
## y = 0 draws no underside: it stands in the land.

const NEAR := 1
const FAR := 2
const BOTH := 3
## Floats a solid keeps (`solid_row`).
const FIELDS := 11
const SIDE := 0.0
const ROUND := 1.0
const FAR_SIDES_LEAST := 6

var layer := BOTH
## Each {"low": Rect2, "high": Rect2, "y0", "y1", "layer"}, or {"at": Vector3,
## "r0", "r1", "tall", "sides", "layer"}.
var parts: Array[Dictionary] = []
## Each {"block": CityShapes, "at": Transform3D}.
var stamps: Array[Dictionary] = []

func box(lo: Vector3, hi: Vector3) -> void:
	var r := Rect2(lo.x,lo.z,hi.x-lo.x,hi.z-lo.z)
	slope(r,r,lo.y,hi.y)

func slope(low: Rect2, high: Rect2, y0: float, y1: float) -> void:
	parts.append({"low":low,"high":high,"y0":y0,"y1":y1,"layer":layer})

func cyl(at: Vector3, r0: float, r1: float, tall: float, sides := 12) -> void:
	parts.append({"at":at,"r0":r0,"r1":r1,"tall":tall,"sides":sides,"layer":layer})

func stamp(block: RefCounted, at: Vector3, yaw := 0.0) -> void:
	stamps.append({"block":block,"at":Transform3D(Basis(Vector3.UP,yaw),at)})

## The level bounds (Rect2 in x, z) of this and all it stamps.
func bounds() -> Rect2:
	var out := Rect2()
	var first := true
	for p: Dictionary in parts:
		var r := _flat(p)
		out = r if first else out.merge(r)
		first = false
	for s: Dictionary in stamps:
		var inner: Rect2 = (s.block as RefCounted).bounds()
		var xf: Transform3D = s.at
		for c: Vector2 in [inner.position,inner.position+Vector2(inner.size.x,0.0),inner.position+Vector2(0.0,inner.size.y),inner.end]:
			var q := xf*Vector3(c.x,0.0,c.y)
			var dot := Rect2(q.x,q.z,0.0,0.0)
			out = dot if first else out.merge(dot)
			first = false
	return out

static func _flat(p: Dictionary) -> Rect2:
	if p.has("low"): return (p.low as Rect2).merge(p.high)
	var at: Vector3 = p.at
	var r := maxf(float(p.r0),float(p.r1))
	return Rect2(at.x-r,at.z-r,r*2.0,r*2.0)

## A part as floats for the solid (giant_city.gd `_stretch`): y0, y1, then each
## edge at y0 and at y1 (x low, x high, z low, z high), then SIDE. A round: y0,
## y1, x, z, r0, r1, then at 10 ROUND.
static func solid_row(p: Dictionary) -> PackedFloat64Array:
	var row := PackedFloat64Array()
	row.resize(FIELDS)
	if p.has("low"):
		var a: Rect2 = p.low
		var b: Rect2 = p.high
		row[0] = float(p.y0)
		row[1] = float(p.y1)
		row[2] = a.position.x
		row[3] = b.position.x
		row[4] = a.end.x
		row[5] = b.end.x
		row[6] = a.position.y
		row[7] = b.position.y
		row[8] = a.end.y
		row[9] = b.end.y
		row[10] = SIDE
	else:
		var at: Vector3 = p.at
		row[0] = at.y
		row[1] = at.y+float(p.tall)
		row[2] = at.x
		row[3] = at.z
		row[4] = float(p.r0)
		row[5] = float(p.r1)
		row[10] = ROUND
	return row

## The mesh of the parts in `which` (NEAR or FAR), or null with none. Flat faces
## keep their own edges; a round's side is smooth.
func mesh(which: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for p: Dictionary in parts:
		if not (int(p.layer) & which): continue
		if p.has("low"): _hexa(p,v,n)
		else: _round(p,which,v,n)
	if v.is_empty(): return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return out

func _hexa(p: Dictionary, v: PackedVector3Array, n: PackedVector3Array) -> void:
	var a: Rect2 = p.low
	var b: Rect2 = p.high
	var y0 := float(p.y0)
	var y1 := float(p.y1)
	var c: Array[Vector3] = []
	for level: Array in [[a,y0],[b,y1]]:
		var r: Rect2 = level[0]
		var y: float = level[1]
		c.append(Vector3(r.position.x,y,r.position.y))
		c.append(Vector3(r.end.x,y,r.position.y))
		c.append(Vector3(r.end.x,y,r.end.y))
		c.append(Vector3(r.position.x,y,r.end.y))
	var mid := Vector3.ZERO
	for q: Vector3 in c: mid += q/8.0
	for i in 4:
		var j := (i+1)%4
		_quad(c[i],c[j],c[j+4],c[i+4],mid,v,n)
	_quad(c[4],c[5],c[6],c[7],mid,v,n)
	if y0 >= 0.0: _quad(c[0],c[1],c[2],c[3],mid,v,n)

## A quad, wound clockwise seen from outside (Godot's front), lit flat.
static func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, mid: Vector3, v: PackedVector3Array, n: PackedVector3Array) -> void:
	var face := (b-a).cross(c-a)
	if face.length_squared() < 0.0001: face = (c-a).cross(d-a)
	if face.length_squared() < 0.0001: return
	face = face.normalized()
	var out := face if face.dot((a+c)*0.5-mid) >= 0.0 else -face
	if face.dot(out) > 0.0:
		var t := b
		b = d
		d = t
	for q: Vector3 in [a,b,c,a,c,d]:
		v.append(q)
		n.append(out)

func _round(p: Dictionary, which: int, v: PackedVector3Array, n: PackedVector3Array) -> void:
	var at: Vector3 = p.at
	var r0 := float(p.r0)
	var r1 := float(p.r1)
	var tall := float(p.tall)
	var sides := int(p.sides)
	if which == FAR: sides = maxi(FAR_SIDES_LEAST,sides/2)
	var lean := (r0-r1)/tall
	var ring: Array[Vector3] = []
	for i in sides: ring.append(Vector3(cos(i*TAU/sides),0.0,sin(i*TAU/sides)))
	var top := at+Vector3.UP*tall
	for i in sides:
		var e0 := ring[i]
		var e1 := ring[(i+1)%sides]
		var n0 := (e0+Vector3.UP*lean).normalized()
		var n1 := (e1+Vector3.UP*lean).normalized()
		# Clockwise from outside.
		for q: Array in [[e0,0.0,n0],[e1,1.0,n1],[e0,1.0,n0],[e0,0.0,n0],[e1,0.0,n1],[e1,1.0,n1]]:
			var e: Vector3 = q[0]
			var h: float = q[1]
			v.append(at.lerp(top,h)+e*lerpf(r0,r1,h))
			n.append(q[2])
		if i > 0 and i < sides-1:
			if r1 > 0.0:
				for e: Vector3 in [ring[0],ring[i],ring[i+1]]:
					v.append(top+e*r1)
					n.append(Vector3.UP)
			if at.y >= 0.0 and r0 > 0.0:
				for e: Vector3 in [ring[0],ring[i+1],ring[i]]:
					v.append(at+e*r0)
					n.append(Vector3.DOWN)
