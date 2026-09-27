extends RefCounted
## Low-poly creatures for the life that arrives on the land (docs/scenic/life.md):
## fish, frogspawn, a heron and deer. Every part is a
## faceted spindle (a bipyramid over a few-sided ring) or a flat fan, painted
## with vertex colours and drawn with the frogs' own `reference_surface`
## material (flat faces, scene palette), so they sit in the Fidelity look and
## share a pipeline that is already compiled. Nothing here is fuzzy or smooth.
##
## All models face +Z with their feet at the origin; metres at plate scale.

class Build:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var _face := 0

	func tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
		var normal := (b-a).cross(c-a)
		normal = normal.normalized() if normal.length_squared() > 1e-12 else Vector3.UP
		# A small per-face shift keeps big planes from reading as one flat tone.
		_face += 1
		var shade := 0.94+0.12*fposmod(sin(float(_face)*12.9898)*43758.5453,1.0)
		var painted := Color(color.r*shade,color.g*shade,color.b*shade,color.a)
		for p in [a,b,c]:
			vertices.append(p)
			normals.append(normal)
			colors.append(painted)

	## A faceted bipyramid from `a` to `b`: `sides` ring points at `bulge` along
	## the axis, `radius` across (x) and `height` radius up (y of the ring frame).
	func spindle(a: Vector3, b: Vector3, radius: float, color: Color, sides := 5, bulge := 0.45, height := -1.0, twist := 0.0) -> void:
		var axis := (b-a).normalized()
		var side := axis.cross(Vector3.UP)
		if side.length_squared() < 1e-6: side = axis.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(axis).normalized()
		var tall := radius if height < 0.0 else height
		var middle := a.lerp(b,bulge)
		var ring: Array[Vector3] = []
		for i in range(sides):
			var angle := TAU*float(i)/sides+twist
			ring.append(middle+side*cos(angle)*radius+up*sin(angle)*tall)
		for i in range(sides):
			var next := ring[(i+1)%sides]
			tri(a,next,ring[i],color)
			tri(b,ring[i],next,color)

	## A flat fan of triangles around `hub`.
	func fan(hub: Vector3, rim: Array, color: Color, tip_color := Color(0,0,0,0)) -> void:
		for i in range(rim.size()-1):
			var shade := color
			if tip_color.a > 0.0 and i >= rim.size()-3: shade = tip_color
			tri(hub,rim[i],rim[i+1],shade)

	func icosahedron(center: Vector3, radius: float, color: Color, squash := 1.0) -> void:
		var t := (1.0+sqrt(5.0))*0.5
		var points := [Vector3(-1,t,0),Vector3(1,t,0),Vector3(-1,-t,0),Vector3(1,-t,0),Vector3(0,-1,t),Vector3(0,1,t),Vector3(0,-1,-t),Vector3(0,1,-t),Vector3(t,0,-1),Vector3(t,0,1),Vector3(-t,0,-1),Vector3(-t,0,1)]
		var faces := [0,11,5, 0,5,1, 0,1,7, 0,7,10, 0,10,11, 1,5,9, 5,11,4, 11,10,2, 10,7,6, 7,1,8, 3,9,4, 3,4,2, 3,2,6, 3,6,8, 3,8,9, 4,9,5, 2,4,11, 6,2,10, 8,6,7, 9,8,1]
		for i in range(0,faces.size(),3):
			var p: Array[Vector3] = []
			for k in range(3):
				var v: Vector3 = points[faces[i+k]].normalized()*radius
				v.y *= squash
				p.append(center+v)
			tri(p[0],p[1],p[2],color)

	func commit(material: Material) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,material)
		return mesh

## A small pond fish, pale so each instance colour paints it.
static func fish(material: Material) -> ArrayMesh:
	var b := Build.new()
	var body := Color(1,1,1)
	b.spindle(Vector3(0,0,-0.15),Vector3(0,0,0.19),0.055,body,6,0.42,0.075)
	b.fan(Vector3(0,0,-0.12),[Vector3(0,0.085,-0.29),Vector3(0,0.0,-0.24),Vector3(0,-0.085,-0.29)],Color(0.92,0.9,0.86))
	b.fan(Vector3(0,0.06,0.02),[Vector3(0,0.06,0.1),Vector3(0,0.12,-0.02),Vector3(0,0.06,-0.08)],Color(0.9,0.86,0.8))
	return b.commit(material)

## A clump of frogspawn: pale jelly beads, each with a dark egg at its heart,
## floating flat on the surface.
static func frogspawn(material: Material) -> ArrayMesh:
	var b := Build.new()
	var jelly := Color(0.74,0.8,0.72)
	var egg := Color(0.09,0.1,0.08)
	for i in range(11):
		var angle := float(i)*2.39996
		var reach := 0.19*sqrt(float(i)/11.0)
		var p := Vector3(cos(angle)*reach,0.012*sin(float(i)*1.7),sin(angle)*reach)
		var radius := 0.05+0.012*sin(float(i)*3.1)
		b.icosahedron(p,radius,jelly,0.55)
		b.icosahedron(p+Vector3(0,radius*0.28,0),radius*0.34,egg,1.0)
	return b.commit(material)

## A grey heron standing: body, legs and a neck pivot are separate so the
## neck can strike and the wings can open.
static func heron_body(material: Material) -> ArrayMesh:
	var b := Build.new()
	var grey := Color(0.56,0.61,0.67)
	var leg := Color(0.34,0.31,0.22)
	b.spindle(Vector3(0,0.7,-0.36),Vector3(0,0.9,0.14),0.12,grey,6,0.4,0.15)
	# Folded primaries lie darker along the back.
	b.spindle(Vector3(0,0.82,-0.44),Vector3(0,0.9,0.02),0.1,Color(0.36,0.39,0.45),5,0.5,0.06)
	return b.commit(material)

## Both legs from the hip (0.72 m up) down to the toes, so they can trail
## behind in flight.
static func heron_legs(material: Material) -> ArrayMesh:
	var b := Build.new()
	var leg := Color(0.34,0.31,0.22)
	for x in [-0.055,0.055]:
		b.spindle(Vector3(x,0.0,0.0),Vector3(x*1.2,-0.72,0.06),0.018,leg,4,0.35)
		b.fan(Vector3(x*1.2,-0.715,0.06),[Vector3(x*1.2-0.05,-0.715,0.16),Vector3(x*1.2,-0.715,0.18),Vector3(x*1.2+0.05,-0.715,0.16)],leg)
	return b.commit(material)

static func heron_neck(material: Material) -> ArrayMesh:
	var b := Build.new()
	var pale := Color(0.87,0.88,0.87)
	b.spindle(Vector3(0,-0.04,-0.02),Vector3(0,0.22,0.1),0.05,pale,5,0.45)
	b.spindle(Vector3(0,0.18,0.1),Vector3(0,0.38,0.04),0.042,pale,5,0.5)
	b.spindle(Vector3(0,0.34,-0.01),Vector3(0,0.41,0.12),0.05,pale,5,0.45)
	b.spindle(Vector3(0,0.395,0.1),Vector3(0,0.37,0.36),0.02,Color(0.86,0.66,0.22),4,0.2)
	b.spindle(Vector3(0,0.41,0.03),Vector3(0,0.385,-0.14),0.012,Color(0.1,0.1,0.12),4,0.3)
	return b.commit(material)

## One wing reaching along +X from the shoulder; the left wing mirrors it.
static func heron_wing(material: Material, left := false) -> ArrayMesh:
	var b := Build.new()
	var s := -1.0 if left else 1.0
	var rim := [Vector3(0,0,0.12),Vector3(0.3*s,0.02,0.17),Vector3(0.6*s,0.0,0.1),Vector3(0.82*s,-0.02,-0.1),Vector3(0.5*s,0.0,-0.26),Vector3(0.0,0.0,-0.2)]
	b.fan(Vector3(0.0,0.0,-0.02),rim,Color(0.55,0.6,0.66),Color(0.3,0.32,0.38))
	return b.commit(material)

## A deer's body; neck and legs are separate pivots.
static func deer_body(material: Material, coat: Color) -> ArrayMesh:
	var b := Build.new()
	b.spindle(Vector3(0,0.8,-0.4),Vector3(0,0.85,0.36),0.17,coat,7,0.5,0.2)
	b.spindle(Vector3(0,0.86,-0.4),Vector3(0,0.72,-0.5),0.04,Color(0.9,0.88,0.82),4,0.3)
	b.spindle(Vector3(0,0.7,-0.3),Vector3(0,0.72,0.26),0.1,coat.lightened(0.3),5,0.5,0.06)
	return b.commit(material)

static func deer_neck(material: Material, coat: Color) -> ArrayMesh:
	var b := Build.new()
	b.spindle(Vector3(0,-0.06,-0.04),Vector3(0,0.34,0.14),0.075,coat,6,0.45)
	b.spindle(Vector3(0,0.3,0.06),Vector3(0,0.22,0.36),0.075,coat,6,0.35,0.085)
	b.spindle(Vector3(0,0.225,0.33),Vector3(0,0.21,0.39),0.032,Color(0.12,0.1,0.09),4,0.3)
	for x in [-1.0,1.0]:
		b.fan(Vector3(x*0.04,0.34,0.1),[Vector3(x*0.06,0.36,0.14),Vector3(x*0.16,0.46,0.1),Vector3(x*0.06,0.38,0.06)],coat.darkened(0.1))
	return b.commit(material)

static func deer_leg(material: Material, coat: Color, length := 0.74) -> ArrayMesh:
	var b := Build.new()
	b.spindle(Vector3(0,0.04,0),Vector3(0,-length,0.01),0.045,coat.darkened(0.2),4,0.25)
	return b.commit(material)
