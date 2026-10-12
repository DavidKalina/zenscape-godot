extends RefCounted
## Smooth, rounded meshes for the painted look (the plane, scripts/
## plane_figure.gd, and its cockpit pilot, scripts/plane_pilot.gd): the
## same builders as scripts/facet_mesh.gd, but well subdivided and shaded
## smooth, so a form reads as a soft painted solid, not cut facets.
##
## `smooth` takes any flat-shaded mesh (FacetMesh's) and shares the normals
## of faces meeting at a point within `crease` degrees, so the hard edges
## a form means (a cap's rim, a trailing edge) stay and the rest rounds.
## Built meshes are kept (`_kept`) by their arguments, so a second plane or
## a found part reuses them.

const FacetMesh = preload("res://scripts/facet_mesh.gd")

static var _kept := {}

## `mesh` (one surface of triangles) with its normals shared across every
## edge gentler than `crease` degrees, weighted by the faces' areas.
static func smooth(mesh: ArrayMesh, crease := 60.0) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var face := PackedVector3Array()
	face.resize(v.size())
	for t in range(0,v.size()-2,3):
		var area := (v[t+1]-v[t]).cross(v[t+2]-v[t]).length()*0.5
		for k in range(3): face[t+k] = n[t+k]*maxf(area,1e-9)
	var groups := {}
	for i in range(v.size()):
		var key := Vector3i(roundi(v[i].x*20000.0),roundi(v[i].y*20000.0),roundi(v[i].z*20000.0))
		if not groups.has(key): groups[key] = PackedInt32Array()
		(groups[key] as PackedInt32Array).append(i)
	var limit := cos(deg_to_rad(crease))
	var out := PackedVector3Array()
	out.resize(v.size())
	for key: Vector3i in groups:
		var idx: PackedInt32Array = groups[key]
		for i in idx:
			var sum := Vector3.ZERO
			for j in idx:
				if n[j].dot(n[i]) >= limit: sum += face[j]
			out[i] = sum.normalized() if sum.length_squared() > 1e-18 else n[i]
	arrays[Mesh.ARRAY_NORMAL] = out
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return made

## A smooth body along Z (as FacetMesh `hull`: rings of Vector3(z, half
## width, half height)), `sides` round, each span between rings eased into
## `steps` by a Catmull-Rom curve so the outline flows.
static func hull(rings: Array, sides: int, steps := 4, crease := 70.0) -> ArrayMesh:
	var key := "hull%s|%d|%d|%f" % [str(rings),sides,steps,crease]
	if _kept.has(key): return _kept[key]
	var fine := []
	if rings.size() <= 2 or steps <= 1:
		fine = rings
	else:
		for k in range(rings.size()-1):
			var p0: Vector3 = rings[maxi(k-1,0)]
			var p1: Vector3 = rings[k]
			var p2: Vector3 = rings[k+1]
			var p3: Vector3 = rings[mini(k+2,rings.size()-1)]
			for s in range(steps):
				var t := float(s)/steps
				var q := _catmull(p0,p1,p2,p3,t)
				q.y = maxf(q.y,0.0)
				q.z = maxf(q.z,0.0)
				fine.append(q)
		fine.append(rings[-1])
	var made := smooth(FacetMesh.hull(fine,sides),crease)
	_kept[key] = made
	return made

## A smooth cylinder (or cone) along Y, centred, as FacetMesh `frustum`;
## its caps' rims stay crisp.
static func cylinder(bottom: float, top: float, height: float, sides: int) -> ArrayMesh:
	var key := "cyl%f|%f|%f|%d" % [bottom,top,height,sides]
	if _kept.has(key): return _kept[key]
	var made := smooth(FacetMesh.frustum(bottom,top,height,sides),50.0)
	_kept[key] = made
	return made

## A smooth ball of radius `r` (stretched by `stretch`), along Z.
static func ball(r: float, sides := 12, stretch := Vector3.ONE) -> ArrayMesh:
	var rings := []
	var n := maxi(sides/2,4)
	for i in range(n+1):
		var a := PI*float(i)/n
		rings.append(Vector3(-cos(a)*r*stretch.z,sin(a)*r*stretch.x,sin(a)*r*stretch.y))
	return hull(rings,sides,1,89.0)

## A torus round Y: `radius` to the tube's middle, the tube `tube` thick
## (radius), `sides` round the ring and `round` round the tube.
static func torus(radius: float, tube: float, sides := 32, round := 12) -> ArrayMesh:
	var key := "torus%f|%f|%d|%d" % [radius,tube,sides,round]
	if _kept.has(key): return _kept[key]
	var at := func(i: int, j: int) -> Vector3:
		var a := TAU*float(i)/sides
		var b := TAU*float(j)/round
		var out := Vector3(cos(a),0.0,sin(a))
		return out*radius+(out*cos(b)+Vector3.UP*sin(b))*tube
	var tris := []
	for i in range(sides):
		var a := TAU*(float(i)+0.5)/sides
		var core := Vector3(cos(a),0.0,sin(a))*radius
		for j in range(round):
			var c00: Vector3 = at.call(i,j)
			var c10: Vector3 = at.call(i+1,j)
			var c01: Vector3 = at.call(i,j+1)
			var c11: Vector3 = at.call(i+1,j+1)
			tris.append([c00,c01,c11,core])
			tris.append([c00,c11,c10,core])
	var made := smooth(FacetMesh.shell(tris),89.0)
	_kept[key] = made
	return made

## A flat piece along X, `width` thick and centred, its outline in (z, y)
## convex, its edges rounded over by `bevel` (m) all round: a fin, a
## rudder, a painted emblem.
static func slab(outline: Array, width: float, bevel: float) -> ArrayMesh:
	var key := "slab%s|%f|%f" % [str(outline),width,bevel]
	if _kept.has(key): return _kept[key]
	var mid := Vector2.ZERO
	for p: Vector2 in outline: mid += p
	mid /= outline.size()
	var h := width*0.5
	var b := minf(bevel,h)
	# Layers across the thickness: (x, how far the outline is drawn in).
	var layers := [Vector2(-h,b),Vector2(-h+b*0.3,b*0.28),Vector2(-h+b,0.0),Vector2(h-b,0.0),Vector2(h-b*0.3,b*0.28),Vector2(h,b)]
	var ring := func(layer: Vector2) -> Array:
		var out := []
		for p: Vector2 in outline:
			var d := p-mid
			var q := mid+d*maxf(1.0-layer.y/maxf(d.length(),1e-5),0.05)
			out.append(Vector3(layer.x,q.y,q.x))
		return out
	var tris := []
	var inside := Vector3(0.0,mid.y,mid.x)
	var before: Array = ring.call(layers[0])
	for k in range(1,layers.size()):
		var now: Array = ring.call(layers[k])
		for i in range(outline.size()):
			var j := (i+1)%outline.size()
			tris.append([before[i],now[i],now[j],inside])
			tris.append([before[i],now[j],before[j],inside])
		before = now
	for e: Vector2 in [layers[0],layers[-1]]:
		var cap: Array = ring.call(e)
		var centre := Vector3(e.x,mid.y,mid.x)
		for i in range(outline.size()):
			tris.append([centre,cap[i],cap[(i+1)%outline.size()],inside])
	var made := smooth(FacetMesh.shell(tris),75.0)
	_kept[key] = made
	return made

static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t*t
	var t3 := t2*t
	return 0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t2+(-p0+3.0*p1-3.0*p2+p3)*t3)
