extends RefCounted
## The pierced isle's body drawn (scripts/pierced_isle.gd `field`): its
## rock sampled on a grid CELL m apart and its face found by surface nets
## (a point in each cell the face crosses, at the mean of where it crosses
## the cell's edges; a quad across each crossed edge), each quad two flat
## faces split along its shorter diagonal, so the rock is faceted as the
## islands' sides are, its facets about a cell across.
##
## Each face carries its colour (PiercedIsle `tint`: beds, streaks, turf on
## the ledges, mist toward the tip) and, in its alpha, how open it is to
## the sky (1 less PiercedIsle `shelter`, read at the points of faces in
## the holes and under overhangs), drawn in the ruin kit's stone material
## (shaders/ruin_stone.gdshader): in shade it takes the sky's hemisphere,
## and deep in the rock the light bouncing in, so the caverns are dim but
## their rock reads. The lid's own wall is coloured the same (`colour`).
##
## A column far outside the lid's outline is all air and never sampled.
## `arrays` is safe on a worker; it gives the surface arrays and, in
## `stats`, the samples taken, the faces and the time.
##   near: CELL; far (past FAR m): FAR_CELL, about a seventh of the faces.

const RuinKit = preload("res://scripts/ruin_kit.gd")

## The grid's cell (m), near and far, and where the far one takes over.
const CELL := 2.6
const FAR_CELL := 6.5
const FAR := 520.0
## A face this near a hole's wall (m) is inside it; points this near, or
## facing down past UNDER, have their shelter read.
const INSIDE := 2.0
const SHELTERED := 3.0
const UNDER := -0.3
## The rock's own stone material: the ruins' (RuinKit `materials`), its
## bounce stronger for the caverns.
const SHELTER_FILL := 3.6
## The sky's fill in shade (the ruins' 1.2): the big faces in shade stay
## stone, not near-black.
const FILL := 1.6
## Faces looking down take the cloud sea's light from under them, this
## much of the stone's bounce at straight down.
const CLOUD_GLOW := 0.4

static var _material: ShaderMaterial

## The body's surface arrays (vertices, normals, colours) at `cell`, in
## the lid's frame; `stats` gets {samples, faces, usec}. `sheltered` reads
## the shelter (the near mesh); the far one only marks the holes' inside.
static func arrays(plan: RefCounted, cell: float, stats := {}, sheltered := true) -> Array:
	var began := Time.get_ticks_usec()
	var box: AABB = plan.bounds()
	var lo := Vector3(box.position.x,plan.tip_y-cell*2.0,box.position.z)
	var hi := Vector3(box.end.x,plan.top_y+cell*1.5,box.end.z)
	var nx := ceili((hi.x-lo.x)/cell)+1
	var ny := ceili((hi.y-lo.y)/cell)+1
	var nz := ceili((hi.z-lo.z)/cell)+1
	var values := PackedFloat32Array()
	values.resize(nx*ny*nz)
	var samples := 0
	# Columns: far outside the outline all air (the face never stands more
	# than the lumps' reach past it).
	var reach := 8.0
	for k in range(nz):
		var z := lo.z+k*cell
		for i in range(nx):
			var x := lo.x+i*cell
			var d2: float = plan.outline_sd(x,z)
			var base_index := k*ny*nx+i
			if d2 > reach:
				for j in range(ny): values[base_index+j*nx] = d2
				continue
			for j in range(ny):
				values[base_index+j*nx] = plan.field(Vector3(x,lo.y+j*cell,z))
			samples += ny
	# A point in each cell the face crosses.
	var cells := PackedInt32Array()
	cells.resize((nx-1)*(ny-1)*(nz-1))
	cells.fill(-1)
	var points := PackedVector3Array()
	var corner := [Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(0,1,0),Vector3i(1,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(0,1,1),Vector3i(1,1,1)]
	var edges := [[0,1],[2,3],[4,5],[6,7],[0,2],[1,3],[4,6],[5,7],[0,4],[1,5],[2,6],[3,7]]
	var sx := 1
	var sy := nx
	var sz := nx*ny
	var offsets := PackedInt32Array()
	for c: Vector3i in corner: offsets.append(c.x*sx+c.y*sy+c.z*sz)
	var v := PackedFloat32Array()
	v.resize(8)
	for k in range(nz-1):
		for j in range(ny-1):
			for i in range(nx-1):
				var at := k*sz+j*sy+i
				var rock := 0
				for c in range(8):
					v[c] = values[at+offsets[c]]
					if v[c] < 0.0: rock += 1
				if rock == 0 or rock == 8: continue
				var sum := Vector3.ZERO
				var n := 0
				for e: Array in edges:
					var a: int = e[0]
					var b: int = e[1]
					if (v[a] < 0.0) == (v[b] < 0.0): continue
					var t := v[a]/(v[a]-v[b])
					sum += Vector3(corner[a]).lerp(Vector3(corner[b]),t)
					n += 1
				cells[(k*(ny-1)+j)*(nx-1)+i] = points.size()
				points.append(lo+(Vector3(i,j,k)+sum/n)*cell)
	# A quad across each crossed edge, from the four cells round it: two
	# faces, as point indices, wound to look out of the rock.
	var tris := PackedInt32Array()
	var cy := nx-1
	var cz := (nx-1)*(ny-1)
	for k in range(1,nz-1):
		for j in range(1,ny-1):
			for i in range(1,nx-1):
				var at := k*sz+j*sy+i
				var here := values[at] < 0.0
				for axis in range(3):
					var next := at+(sx if axis == 0 else (sy if axis == 1 else sz))
					if (values[next] < 0.0) == here: continue
					var c := (k*(ny-1)+j)*(nx-1)+i
					var quad: Array
					var out: Vector3
					if axis == 0:
						quad = [c-cy-cz,c-cz,c,c-cy]
						out = Vector3.RIGHT
					elif axis == 1:
						quad = [c-1-cz,c-cz,c,c-1]
						out = Vector3.UP
					else:
						quad = [c-1-cy,c-cy,c,c-1]
						out = Vector3.BACK
					if not here: out = -out
					var q := PackedInt32Array()
					var ok := true
					for cell_index: int in quad:
						if cell_index < 0 or cells[cell_index] < 0:
							ok = false
							break
						q.append(cells[cell_index])
					if not ok: continue
					if points[q[0]].distance_squared_to(points[q[2]]) <= points[q[1]].distance_squared_to(points[q[3]]):
						_tri(tris,points,q[0],q[1],q[2],out)
						_tri(tris,points,q[0],q[2],q[3],out)
					else:
						_tri(tris,points,q[1],q[2],q[3],out)
						_tri(tris,points,q[1],q[3],q[0],out)
	# Each point's normal (its faces' mean) and, where it is in a hole or
	# under an overhang, its shelter.
	var point_normals := PackedVector3Array()
	point_normals.resize(points.size())
	for f in range(0,tris.size(),3):
		var n := _normal(points[tris[f]],points[tris[f+1]],points[tris[f+2]])
		for k in range(3): point_normals[tris[f+k]] += n
	var shelter := PackedFloat32Array()
	shelter.resize(points.size())
	var read := 0
	if sheltered:
		for i in range(points.size()):
			var n := point_normals[i].normalized()
			var p := points[i]
			if plan.carved(p) < SHELTERED or n.y < UNDER:
				shelter[i] = plan.shelter(p,n)
				read += 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var count := tris.size()
	vertices.resize(count)
	normals.resize(count)
	colours.resize(count)
	for f in range(0,count,3):
		var a := points[tris[f]]
		var b := points[tris[f+1]]
		var c := points[tris[f+2]]
		var n := _normal(a,b,c)
		var middle := (a+b+c)/3.0
		var inside: bool = plan.carved(middle) < INSIDE
		var colour: Color = plan.tint(middle,n,inside)
		var open := 1.0-(shelter[tris[f]]+shelter[tris[f+1]]+shelter[tris[f+2]])/3.0
		if not sheltered and inside: open = 0.35
		# The cloud sea's light thrown up under the keel (the stone's bounce).
		open = minf(open,1.0-CLOUD_GLOW*smoothstep(-0.15,-0.85,n.y))
		colour.a = open
		for k in range(3):
			vertices[f+k] = points[tris[f+k]]
			normals[f+k] = n
			colours[f+k] = colour
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	stats.samples = samples
	stats.sheltered = read
	stats.faces = count/3
	stats.usec = Time.get_ticks_usec()-began
	return arrays

## A face's normal as the shader takes its front: (c-a)×(b-a), as the
## islands' sides.
static func _normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (c-a).cross(b-a).normalized()

## One face, wound so its front looks out along `out`.
static func _tri(tris: PackedInt32Array, points: PackedVector3Array, a: int, b: int, c: int, out: Vector3) -> void:
	var n := (points[c]-points[a]).cross(points[b]-points[a])
	if n.length_squared() < 0.0000001: return
	if n.dot(out) < 0.0:
		tris.append_array([a,c,b])
	else:
		tris.append_array([a,b,c])

## Colours another part's faces in the rock's colours (the lid's wall, its
## faces flat, three vertices each), open to the sky: its arrays with a
## colour array added.
static func colour(plan: RefCounted, arrays: Array) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colours := PackedColorArray()
	colours.resize(vertices.size())
	for f in range(0,vertices.size()-2,3):
		var middle := (vertices[f]+vertices[f+1]+vertices[f+2])/3.0
		var c: Color = plan.tint(middle,normals[f],false)
		c.a = 1.0
		for k in range(3): colours[f+k] = c
	var out := arrays.duplicate()
	out[Mesh.ARRAY_COLOR] = colours
	out[Mesh.ARRAY_TEX_UV] = null
	return out

## A one-surface mesh from the arrays, wearing `material`.
static func mesh(arrays: Array, material: Material = null) -> ArrayMesh:
	var m := ArrayMesh.new()
	if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty(): return m
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if material != null: m.surface_set_material(0,material)
	return m

## The rock's material: the ruins' stone, its bounce strengthened (made on
## the main thread, shared).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = (RuinKit.materials().stone as ShaderMaterial).duplicate()
		_material.set_shader_parameter("shelter_fill",SHELTER_FILL)
		_material.set_shader_parameter("fill",FILL)
	return _material

static func release() -> void:
	_material = null
