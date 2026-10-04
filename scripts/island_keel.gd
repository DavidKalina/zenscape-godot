extends RefCounted
## The rock an island hangs from: a faceted, upside-down mountain under the
## plate, so a glide can dip beneath an island and see stone, not the open
## foot of its earth sides (NativeTerrainData.SLAB_BASE).
##
## The underside is one height field in the terrain's frame: `depth_at` says
## how far under SLAB_BASE the rock hangs at a plate point, zero all round the
## rim, deepest a little off the middle, with a few spurs hanging lower. The
## mesh is laid on the same grid, so the glide's sense of the island
## (scripts/sky_islands.gd `body`) is the stone it sees.
##
## It shows only while gliding; the build view keeps its plain slab.

## The plate's half width, the deepest the rock hangs under SLAB_BASE, and
## the grid it is laid on (cells a side).
const HALF := 14.0
const DEPTH := 19.0
const CELLS := 14
## Spurs: (x, z, radius, extra depth), terrain-local.
const SPURS := [Vector4(3.5,-2.0,4.5,7.0),Vector4(-5.0,4.0,3.5,4.5),Vector4(6.0,6.5,2.8,3.0),Vector4(-6.5,-6.0,3.0,3.5)]
## Bands of colour down the rock: warm earth under the sides, then stone,
## then a cool, dusky tip.
const EARTH := Color("6e5340")
const STONE := Color("7d7468")
const TIP := Color("5c5a66")

## How far under SLAB_BASE the rock hangs at a terrain-local plate point, in
## metres: 0 at and beyond the rim. Bilinear over the mesh's grid, so it
## matches what is drawn.
static func depth_at(point: Vector2) -> float:
	if absf(point.x) >= HALF or absf(point.y) >= HALF: return 0.0
	var step := 2.0*HALF/CELLS
	var g := (point+Vector2(HALF,HALF))/step
	var i := mini(int(g.x),CELLS-1)
	var j := mini(int(g.y),CELLS-1)
	var f := g-Vector2(i,j)
	var a := _node_depth(i,j)
	var b := _node_depth(i+1,j)
	var c := _node_depth(i,j+1)
	var d := _node_depth(i+1,j+1)
	return lerpf(lerpf(a,b,f.x),lerpf(c,d,f.x),f.y)

## The depth at grid node (i, j).
static func _node_depth(i: int, j: int) -> float:
	if i <= 0 or j <= 0 or i >= CELLS or j >= CELLS: return 0.0
	var step := 2.0*HALF/CELLS
	var p := Vector2(i*step-HALF,j*step-HALF)
	# Half square, half round, so it hangs like a cone under a square plate.
	var square := maxf(absf(p.x),absf(p.y))/HALF
	var round := p.length()/(HALF*1.25)
	var out := clampf(lerpf(square,round,0.55),0.0,1.0)
	var depth := DEPTH*pow(1.0-out,1.35)
	for s: Vector4 in SPURS:
		var near := 1.0-clampf(p.distance_to(Vector2(s.x,s.y))/s.z,0.0,1.0)
		depth += s.w*near*near
	# A seeded jitter breaks the cone into facets.
	var h := hash(Vector2i(i,j))
	depth *= 0.86+0.28*float(h%1000)/1000.0
	return depth

## The rock's underside in the terrain's frame at a plate point.
static func underside(point: Vector2) -> float:
	return NativeTerrainData.SLAB_BASE-depth_at(point)

## The faceted rock: one face per grid triangle, each shaded flat, its
## colour banded by depth.
static func build_mesh() -> ArrayMesh:
	var step := 2.0*HALF/CELLS
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var node := func(i: int, j: int) -> Vector3:
		return Vector3(i*step-HALF,NativeTerrainData.SLAB_BASE-_node_depth(i,j),j*step-HALF)
	for i in range(CELLS):
		for j in range(CELLS):
			var a: Vector3 = node.call(i,j)
			var b: Vector3 = node.call(i+1,j)
			var c: Vector3 = node.call(i,j+1)
			var d: Vector3 = node.call(i+1,j+1)
			# Split along alternate diagonals so the facets don't line up.
			var tris := [[a,b,d],[a,d,c]] if (i+j)%2 == 0 else [[a,b,c],[b,d,c]]
			for t: Array in tris:
				var n: Vector3 = ((t[1] as Vector3)-(t[0] as Vector3)).cross((t[2] as Vector3)-(t[0] as Vector3)).normalized()
				# Faces look down and out: clockwise seen from below, which
				# is Godot's front.
				if n.y < 0.0:
					t = [t[0],t[2],t[1]]
				else:
					n = -n
				var mid: Vector3 = ((t[0] as Vector3)+(t[1] as Vector3)+(t[2] as Vector3))/3.0
				var color := _band(NativeTerrainData.SLAB_BASE-mid.y,hash(Vector2i(i*2+int(t[1] == c),j)))
				for v: Vector3 in t:
					vertices.append(v)
					normals.append(n)
					colors.append(color)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	mesh.surface_set_material(0,material)
	return mesh

## A face's colour `depth` metres under the slab's foot, nudged per face.
static func _band(depth: float, seed: int) -> Color:
	var k := clampf(depth/DEPTH,0.0,1.0)
	var color := EARTH.lerp(STONE,smoothstep(0.05,0.4,k)).lerp(TIP,smoothstep(0.55,1.0,k))
	var nudge := 0.92+0.16*float(seed%997)/997.0
	return Color(color.r*nudge,color.g*nudge,color.b*nudge)
