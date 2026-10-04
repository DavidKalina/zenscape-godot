extends RefCounted
## Perch limbs on the hero oak (docs/scenic/songbirds.md). Two crooked limbs
## reach out from the trunk under the crown, where the leaves hang highest, so
## a songbird can sit on them in plain sight. They are added to the oak's bark
## mesh (scripts/hero_trees.gd `swap`), take its bark colour and bend with it,
## and their perch points are what scripts/songbirds.gd lands on.
##
## Everything is in the oak mesh's own space (record scale 1: bark 1.46 m,
## crown 0.89–1.84 m). The trunk axis is at AXIS.

## The trunk's axis (x, z), measured from the bark between 0.3 and 0.55 m.
const AXIS := Vector2(0.019,-0.013)
## Limbs: [bearing (radians about the axis, from +x toward +z), base height,
## kink (reach, height), tip (reach, height), base radius, tip radius]. The
## first reaches under the side where the leaves hang highest (about 1.1 m),
## the second under the opposite side (about 1.0 m).
const LIMBS := [
	[0.72,0.6,Vector2(0.36,0.73),Vector2(0.76,0.82),0.032,0.009],
	[3.85,0.54,Vector2(0.3,0.64),Vector2(0.66,0.72),0.03,0.009],
]
## Perches: [limb, share along the limb's outer segment].
const PERCHES := [[0,0.38],[0,0.8],[1,0.6]]
const SIDES := 6

## The limbs' segments in mesh space: [[base, kink, tip, base radius, tip radius], ...].
static func segments() -> Array:
	var out := []
	for limb: Array in LIMBS:
		var way := Vector3(cos(limb[0]),0.0,sin(limb[0]))
		var axis := Vector3(AXIS.x,0.0,AXIS.y)
		var base := axis+Vector3.UP*float(limb[1])
		var kink: Vector2 = limb[2]
		var tip: Vector2 = limb[3]
		# The kink turns a little off the bearing, so the limb looks grown.
		var bent := way.rotated(Vector3.UP,0.22)
		out.append([base,axis+bent*kink.x+Vector3.UP*kink.y,axis+way*tip.x+Vector3.UP*tip.y,float(limb[4]),float(limb[5])])
	return out

## Each perch: {at (the bird's feet, mesh space), face (a level unit vector
## across the limb, away from the trunk side the bird first faces), along (the
## limb's level direction), limb}.
static func perches() -> Array:
	var out := []
	var limbs := segments()
	for perch: Array in PERCHES:
		var limb: Array = limbs[int(perch[0])]
		var t := float(perch[1])
		var kink: Vector3 = limb[1]
		var tip: Vector3 = limb[2]
		var mid := lerpf(float(limb[3]),float(limb[4]),0.5)
		var radius := lerpf(mid,float(limb[4]),t)
		var along := Vector3(tip.x-kink.x,0.0,tip.z-kink.z).normalized()
		# Birds sit across a branch; face the open side (away from the crown's middle).
		var face := along.cross(Vector3.UP).normalized()
		if face.dot(Vector3(tip.x,0.0,tip.z)) < 0.0: face = -face
		out.append({"at":kink.lerp(tip,t)+Vector3.UP*radius,"face":face,"along":along,"limb":int(perch[0])})
	return out

## The bark mesh with the limbs added to its one surface, coloured like the
## bark where each limb starts.
static func add_to(mesh: ArrayMesh) -> ArrayMesh:
	if mesh == null or mesh.get_surface_count() != 1: return mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in range(vertices.size()): indices.append(i)
	for limb: Array in segments():
		var color := _bark_near(vertices,colors,limb[0])
		var kink_radius := lerpf(float(limb[3]),float(limb[4]),0.5)
		_tube(limb[0],limb[1],float(limb[3]),kink_radius,color,vertices,normals,colors,tangents,indices)
		_tube(limb[1],limb[2],kink_radius,float(limb[4]),color,vertices,normals,colors,tangents,indices)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not colors.is_empty(): arrays[Mesh.ARRAY_COLOR] = colors
	if not tangents.is_empty(): arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	out.surface_set_material(0,mesh.surface_get_material(0))
	out.resource_name = mesh.resource_name
	return out

static func _bark_near(vertices: PackedVector3Array, colors: PackedColorArray, at: Vector3) -> Color:
	if colors.is_empty(): return Color.WHITE
	var best := 0
	var nearest := INF
	for i in range(vertices.size()):
		var d := vertices[i].distance_squared_to(at)
		if d < nearest:
			nearest = d
			best = i
	return colors[best]

## A tapered tube of SIDES flat sides from `a` to `b`, capped at the tip.
static func _tube(a: Vector3, b: Vector3, ra: float, rb: float, color: Color, vertices: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, tangents: PackedFloat32Array, indices: PackedInt32Array) -> void:
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.0001: side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(axis).normalized()
	for i in range(SIDES):
		var a0 := TAU*i/SIDES
		var a1 := TAU*(i+1)/SIDES
		var d0 := side*cos(a0)+up*sin(a0)
		var d1 := side*cos(a1)+up*sin(a1)
		var quad: Array[Vector3] = [a+d0*ra,a+d1*ra,b+d1*rb,b+d0*rb]
		var normal := (d0+d1).normalized()
		_triangle(quad[0],quad[1],quad[2],normal,axis,color,vertices,normals,colors,tangents,indices)
		_triangle(quad[0],quad[2],quad[3],normal,axis,color,vertices,normals,colors,tangents,indices)
	# The tip's cap.
	for i in range(SIDES):
		var a0 := TAU*i/SIDES
		var a1 := TAU*(i+1)/SIDES
		_triangle(b,b+(side*cos(a0)+up*sin(a0))*rb,b+(side*cos(a1)+up*sin(a1))*rb,axis,side,color,vertices,normals,colors,tangents,indices)

## One flat triangle facing `normal`. Godot's front faces wind clockwise, so
## the corners are ordered for that.
static func _triangle(p0: Vector3, p1: Vector3, p2: Vector3, normal: Vector3, tangent: Vector3, color: Color, vertices: PackedVector3Array,
		normals: PackedVector3Array, colors: PackedColorArray, tangents: PackedFloat32Array, indices: PackedInt32Array) -> void:
	var corners: Array[Vector3] = [p0,p1,p2]
	if (p1-p0).cross(p2-p0).dot(normal) > 0.0: corners = [p0,p2,p1]
	for p in corners: _vertex(p,normal,tangent,color,vertices,normals,colors,tangents,indices)

static func _vertex(p: Vector3, normal: Vector3, tangent: Vector3, color: Color, vertices: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, tangents: PackedFloat32Array, indices: PackedInt32Array) -> void:
	indices.append(vertices.size())
	vertices.append(p)
	normals.append(normal)
	if colors.size() == vertices.size()-1: colors.append(color)
	if tangents.size() == (vertices.size()-1)*4: tangents.append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,1.0]))
