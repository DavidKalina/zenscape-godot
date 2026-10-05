extends RefCounted
## The plate's terrain mesh, made from Plate rather than authored. It keeps
## the authored plate's character (assets/zen_reference/geometry.scn: a 28 m
## square of 44 squares a side, its inner points nudged up to 0.35 of a
## square each way, every square split along the same diagonal into two
## faces of about the same size): here a grid POINT_STEP apart, POINT_CELLS
## squares a side, its inner points nudged by a fixed hash, so every plate
## is the same plate. The rim's points stay on the rim, unnudged, as the
## authored ones do; the points on the lines at ±LEGACY_HALF only move along
## them, so the old 28 m square's edge runs straight along faces' edges.
##
## The arrays carry the channels the authored mesh does and the terrain
## shader and NativeTerrainData read: unindexed faces, flat normals, a
## tangent, the face's grass colour (COLOR, and CUSTOM0 the colour the rising
## ground grows from), UV.x the growth's delay for the point and UV2 a dirt
## shade for the face (x) and the point's height (y). Flat at height 0, as
## NativeTerrainData.reset_flat leaves the land.

const Plate = preload("res://scripts/plate.gd")
## How far an inner point is nudged, as a share of POINT_STEP, each way.
const NUDGE := 0.35
## A face sharper than this (degrees at its narrowest corner) has its
## corners' nudges halved until it is not: the authored plate has two faces
## folded over, the made one none.
const SHARPEST := 6.0
## The growth's delay (UV.x) runs over this range, as the authored mesh's.
const GROWTH_DELAY := Vector2(0.07,0.6)

static var _made: Array = []
static var _lock := Mutex.new()

## The plate's mesh, with `material` on its one surface.
static func build(material: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays(),[],{},Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	if material != null: mesh.surface_set_material(0,material)
	return mesh

## Puts the plate's mesh on the scene's terrain node in place of the
## authored one, keeping the authored material. Once: a node already
## carrying it is left alone.
static func adopt(terrain: MeshInstance3D) -> void:
	if terrain.mesh != null and terrain.mesh.has_meta(&"plate_mesh"): return
	var mesh := build(terrain.mesh.surface_get_material(0) if terrain.mesh != null else null)
	mesh.set_meta(&"plate_mesh",true)
	terrain.mesh = mesh

## The mesh's surface arrays (a copy each call; made once).
static func arrays() -> Array:
	_lock.lock()
	if _made.is_empty(): _made = _make()
	var copy := _made.duplicate(true)
	_lock.unlock()
	return copy

## The grid's points, row by row from (-HALF, -HALF): nudged, then eased
## back wherever a face came out too sharp.
static func grid() -> PackedVector2Array:
	var n := Plate.POINT_CELLS
	var made := PackedVector2Array()
	var plain := PackedVector2Array()
	made.resize((n+1)*(n+1))
	plain.resize(made.size())
	for j in range(n+1):
		for i in range(n+1):
			made[j*(n+1)+i] = point(i,j)
			plain[j*(n+1)+i] = point(i,j,0.0)
	for _pass in range(6):
		var eased := false
		for j in range(n):
			for i in range(n):
				var a := j*(n+1)+i
				for face: PackedInt32Array in [PackedInt32Array([a,a+1,a+n+1]),PackedInt32Array([a+n+1,a+1,a+n+2])]:
					if _sharpest(made[face[0]],made[face[1]],made[face[2]]) >= SHARPEST: continue
					for id in face: made[id] = plain[id].lerp(made[id],0.5)
					eased = true
		if not eased: break
	return made

## The narrowest corner of a face, in degrees; 0 for one folded over.
static func _sharpest(a: Vector2, b: Vector2, c: Vector2) -> float:
	if (b-a).cross(c-a) <= 0.0: return 0.0
	var least := 180.0
	for corner in [[a,b,c],[b,c,a],[c,a,b]]:
		least = minf(least,rad_to_deg(absf((corner[1]-corner[0]).angle_to(corner[2]-corner[0]))))
	return least

## Where grid point (i, j) stands, nudged by `nudge` of a step at most.
static func point(i: int, j: int, nudge := NUDGE) -> Vector2:
	var n := Plate.POINT_CELLS
	var p := Vector2(-Plate.HALF+float(i)*Plate.SIZE/float(n),-Plate.HALF+float(j)*Plate.SIZE/float(n))
	if i == 0 or j == 0 or i == n or j == n: return p
	var reach := nudge*Plate.POINT_STEP
	if not _on_legacy_line(p.x): p.x += (_hash(i,j,1)*2.0-1.0)*reach
	if not _on_legacy_line(p.y): p.y += (_hash(i,j,2)*2.0-1.0)*reach
	return p

static func _on_legacy_line(value: float) -> bool:
	return absf(absf(value)-Plate.LEGACY_HALF) < 0.000001

## A fixed hash of (i, j, salt) in 0..1, the same on every machine.
static func _hash(i: int, j: int, salt: int) -> float:
	var h := ((i*73856093) ^ (j*19349663) ^ (salt*83492791)) & 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 0x2C1B3C6D) & 0xFFFFFFFF
	h = ((h ^ (h >> 12)) * 0x297A2D39) & 0xFFFFFFFF
	h ^= h >> 15
	return float(h & 0xFFFFFF)/float(0x1000000)

static func _make() -> Array:
	var n := Plate.POINT_CELLS
	var grid := grid()
	var delay := FastNoiseLite.new()
	delay.seed = 7
	delay.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	delay.frequency = 0.12
	delay.fractal_octaves = 2
	var palette := NativeTerrainPalette.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var young := PackedFloat32Array()
	var count := n*n*6
	vertices.resize(count)
	normals.resize(count)
	tangents.resize(count*4)
	colors.resize(count)
	uv.resize(count)
	uv2.resize(count)
	young.resize(count*3)
	var k := 0
	for j in range(n):
		for i in range(n):
			var a := j*(n+1)+i
			# Two faces a square, split along the same diagonal as authored:
			# (i, j), (i+1, j), (i, j+1); then (i, j+1), (i+1, j), (i+1, j+1).
			for face: PackedInt32Array in [PackedInt32Array([a,a+1,a+n+1]),PackedInt32Array([a+n+1,a+1,a+n+2])]:
				var middle := (grid[face[0]]+grid[face[1]]+grid[face[2]])/3.0
				var color := palette.grass_at_coordinates(middle.x,middle.y)
				var shade := _hash(i,j,3 if k%6 == 0 else 4)
				for id in face:
					var p := grid[id]
					vertices[k] = Vector3(p.x,0.0,p.y)
					normals[k] = Vector3.UP
					tangents[k*4] = 1.0
					tangents[k*4+3] = 1.0
					colors[k] = Color(color.r,color.g,color.b,1.0)
					young[k*3] = color.r
					young[k*3+1] = color.g
					young[k*3+2] = color.b
					uv[k] = Vector2(lerpf(GROWTH_DELAY.x,GROWTH_DELAY.y,clampf(delay.get_noise_2d(p.x,p.y)*0.75+0.5,0.0,1.0)),0.0)
					uv2[k] = Vector2(shade,0.0)
					k += 1
	var made := []
	made.resize(Mesh.ARRAY_MAX)
	made[Mesh.ARRAY_VERTEX] = vertices
	made[Mesh.ARRAY_NORMAL] = normals
	made[Mesh.ARRAY_TANGENT] = tangents
	made[Mesh.ARRAY_COLOR] = colors
	made[Mesh.ARRAY_TEX_UV] = uv
	made[Mesh.ARRAY_TEX_UV2] = uv2
	made[Mesh.ARRAY_CUSTOM0] = young
	return made
