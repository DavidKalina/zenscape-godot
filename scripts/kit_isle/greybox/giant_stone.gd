extends RefCounted
## The Sunken Giant's carved basalt (turf pass, docs/design/roguelike/
## brainstorm/round1/motif-m2-sunken-giant.md "Turf pass"): the body's
## masses (fist, forearm, elbow block, chest, neck stump, chimney fins,
## stair stones, columns) as plain chamfered blocks and cylinders in the
## Olmec's weathered stone (shaders/olmec_stone.gdshader, the material
## scripts/enemies/inhaler_head_look.gd `stone_material` makes), so the
## giant reads as the same stone as the heads that went hunting. Each vertex
## coloured as the head's are: the kit's tone by facing and height
## (scripts/ruin_stone_style.gd `shade`), times an occlusion darkest at a
## block's foot (alpha the occlusion), moss on what faces up; UV and UV2.x
## carry where the vertex rests (the isle's frame times GRAIN), the
## shader's grain. A band of lit runes round the neck stump (the shader's
## `runes`, as the rune serpent's bands: CUSTOM0 and CUSTOM1).
##
## Drawn only: whoever builds it collides the blocks itself (walk boxes,
## the greybox's exact numbers). Nodes and arrays only, safe on a worker
## once `warm` has made the materials on the main thread.
const HeadLook = preload("res://scripts/enemies/inhaler_head_look.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")

## The stone's seed (the head's own, HeadLook `build`'s default: one carver).
const STONE_SEED := 7
## The grain's scale on the rest place: under 1 coarser than the head's (a
## body seen across a gulf).
const GRAIN := 0.55
## The occlusion: its least at a block's foot, rising over FOOT_RISE m; the
## tone kept where it is darkest (the head's AO_FLOOR).
const FOOT_OCC := 0.45
const FOOT_RISE := 1.6
const AO_FLOOR := 0.42
## Moss on tops (the head's MOSS rule), heavier: the oak has taken him.
const MOSS := Color("374726")
const MOSS_LIGHT := Color("4e612e")
const MOSS_UP := 0.6
const MOSS_MOST := 0.85
## The runes' glyph cell height (m) and about how long a cell is.
const RUNE_H := 0.8
const RUNE_CELL := 0.75

static var _stone: ShaderMaterial = null
static var _runes: ShaderMaterial = null

## The materials, made on the main thread (a motif's `warm`).
static func warm() -> void:
	_stone = HeadLook.stone_material()
	if _runes == null:
		_runes = ShaderMaterial.new()
		_runes.shader = HeadLook.STONE_SHADER
		_runes.set_shader_parameter("roughness_value",0.95)
		_runes.set_shader_parameter("runes",true)
		_runes.set_shader_parameter("rune_cut",0.6)
		_runes.set_shader_parameter("energy",0.8)
		_runes.set_shader_parameter("glow",Color(1.0,0.78,0.46))
		_runes.set_shader_parameter("pulse_wave",14.0)
		Style.dress(_runes)

static func stone_colour() -> Color:
	return Style.stone_of(STONE_SEED) if Style.ruled() else Color("5a5d63")

## A mesher in the giant's stone.
static func mesher() -> Mesher:
	return Mesher.new(stone_colour())

## The gathered mesh in the giant's materials (`warm` first).
static func mesh_of(m: Mesher) -> ArrayMesh:
	if _stone == null: warm()
	return m.mesh(_stone,_runes)

## One mesh being gathered: the stone's surface and the runes'.
class Mesher extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var rv := PackedVector3Array()
	var rn := PackedVector3Array()
	var rcol := PackedColorArray()
	var ruv := PackedVector2Array()
	var ruv2 := PackedVector2Array()
	var rc0 := PackedFloat32Array()
	var rc1 := PackedFloat32Array()
	var stone := Color("5a5d63")
	var _noise := FastNoiseLite.new()
	## The block's middle (its tone group) and foot (its occlusion), set per
	## block; `tone` a share lighter or darker (an unweathered cut face).
	var _centre := Vector3.ZERO
	var _foot := 0.0
	var _tone := 1.0

	func _init(colour: Color) -> void:
		stone = colour
		_noise.seed = 31
		_noise.frequency = 0.35

	## A corner's colour (linear, occlusion in alpha) and rest place.
	func _dress(p: Vector3, normal: Vector3) -> Array:
		var c := Style.shade(stone,_centre,p,normal,1.0)
		var occ := lerpf(FOOT_OCC,1.0,smoothstep(_foot,_foot+FOOT_RISE,p.y))
		if normal.y < -0.3: occ *= 0.8
		c = c*lerpf(AO_FLOOR,1.0,occ)*_tone
		var up := smoothstep(MOSS_UP,0.95,normal.y)
		if up > 0.0:
			var patch := clampf(_noise.get_noise_3dv(p)*0.9+0.5,0.0,1.0)
			var moss := MOSS.srgb_to_linear().lerp(MOSS_LIGHT.srgb_to_linear(),clampf(_noise.get_noise_3dv(p*3.0)+0.5,0.0,1.0))
			c = c.lerp(moss,up*patch*MOSS_MOST)
		c.a = occ
		var rest := p*GRAIN
		return [c,Vector2(rest.x,rest.y),Vector2(rest.z,0.0)]

	func _tri(a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
		# Godot's fronts wind clockwise as seen: (a, c, b) for an outward
		# normal along (b-a)x(c-a).
		for p: Vector3 in [a,c,b]:
			var d := _dress(p,normal)
			v.append(p)
			n.append(normal)
			col.append(d[0])
			uv.append(d[1])
			uv2.append(d[2])

	## A flat convex face (its corners in any order, `place` applied).
	func _poly(place: Transform3D, pts: Array, centre_local: Vector3) -> void:
		var m := Vector3.ZERO
		for p: Vector3 in pts: m += p
		m /= pts.size()
		var guess := (m-centre_local).normalized()
		var u := guess.cross(Vector3.UP if absf(guess.y) < 0.9 else Vector3.RIGHT).normalized()
		var w := guess.cross(u)
		var sorted := pts.duplicate()
		sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return atan2((a-m).dot(w),(a-m).dot(u)) < atan2((b-m).dot(w),(b-m).dot(u)))
		var world: Array[Vector3] = []
		for p: Vector3 in sorted: world.append(place*p)
		var normal := (world[1]-world[0]).cross(world[2]-world[0])
		if normal.length_squared() < 1e-10: return
		normal = normal.normalized()
		if normal.dot(place.basis*guess) < 0.0:
			world.reverse()
			normal = -normal
		for k in range(1,world.size()-1): _tri(world[0],world[k],world[k+1],normal)

	## A block `size` at `place` (its middle), its edges chamfered `bevel`
	## m; `foot` the world y its occlusion rises from (its bottom if NAN).
	func box(place: Transform3D, size: Vector3, bevel := 0.2, foot := NAN, tone := 1.0) -> void:
		var h := size*0.5
		var c := minf(bevel,minf(h.x,minf(h.y,h.z))*0.45)
		_centre = place.origin
		_foot = (place*Vector3(0.0,-h.y,0.0)).y if is_nan(foot) else foot
		_tone = tone
		var polys: Array = []
		var i := h-Vector3.ONE*maxf(c,0.0)
		for axis in 3:
			for s: float in [-1.0,1.0]:
				var pts: Array = []
				for a: float in [-1.0,1.0]:
					for b: float in [-1.0,1.0]:
						var p := Vector3.ZERO
						p[axis] = s*h[axis]
						p[(axis+1)%3] = a*i[(axis+1)%3]
						p[(axis+2)%3] = b*i[(axis+2)%3]
						pts.append(p)
				polys.append(pts)
		if c > 0.001:
			for k in 3:
				var a := (k+1)%3
				var b := (k+2)%3
				for sa: float in [-1.0,1.0]:
					for sb: float in [-1.0,1.0]:
						var pts: Array = []
						for sk: float in [-1.0,1.0]:
							var p1 := Vector3.ZERO
							p1[k] = sk*i[k]
							p1[a] = sa*h[a]
							p1[b] = sb*i[b]
							var p2 := Vector3.ZERO
							p2[k] = sk*i[k]
							p2[a] = sa*i[a]
							p2[b] = sb*h[b]
							pts.append(p1)
							pts.append(p2)
						polys.append(pts)
			for sx: float in [-1.0,1.0]:
				for sy: float in [-1.0,1.0]:
					for sz: float in [-1.0,1.0]:
						var s := Vector3(sx,sy,sz)
						var pts: Array = []
						for axis in 3:
							var p := s*i
							p[axis] = s[axis]*h[axis]
							pts.append(p)
						polys.append(pts)
		for pts: Array in polys: _poly(place,pts,Vector3.ZERO)

	## A cylinder (`segments` round, its axis `place`'s y, its middle at
	## `place`), its top rim chamfered `bevel`.
	func cylinder(place: Transform3D, radius: float, tall: float, segments := 12, bevel := 0.12, foot := NAN, tone := 1.0) -> void:
		_centre = place.origin
		_foot = (place*Vector3(0.0,-tall*0.5,0.0)).y if is_nan(foot) else foot
		_tone = tone
		var lo := -tall*0.5
		var hi := tall*0.5
		var r2 := radius-bevel
		for k in range(segments):
			var a0 := TAU*k/segments
			var a1 := TAU*(k+1)/segments
			var d0 := Vector3(cos(a0),0.0,sin(a0))
			var d1 := Vector3(cos(a1),0.0,sin(a1))
			# The side.
			var side: Array = [d0*radius+Vector3(0,lo,0),d1*radius+Vector3(0,lo,0),d1*radius+Vector3(0,hi-bevel,0),d0*radius+Vector3(0,hi-bevel,0)]
			_poly(place,side,Vector3(0,(lo+hi-bevel)*0.5,0))
			# The chamfer and the top.
			_poly(place,[d0*radius+Vector3(0,hi-bevel,0),d1*radius+Vector3(0,hi-bevel,0),d1*r2+Vector3(0,hi,0),d0*r2+Vector3(0,hi,0)],Vector3(0,hi-bevel*3.0,0))
			_poly(place,[Vector3(0,hi,0),d0*r2+Vector3(0,hi,0),d1*r2+Vector3(0,hi,0)],Vector3(0,lo,0))

	## A band of lit runes on a flat face: `a`, `b` its bottom corners
	## (world), `up` its height's way and `normal` out; `seed_value` its
	## glyphs'.
	func runes(a: Vector3, b: Vector3, up: Vector3, normal: Vector3, seed_value: float) -> void:
		_centre = (a+b)*0.5
		_foot = -INF
		_tone = 1.0
		var length := a.distance_to(b)
		var count := maxf(roundf(length/RUNE_CELL),1.0)
		var aspect := (length/count)/RUNE_H
		var lift := normal*0.02
		var corners := [[a+lift,Vector2(0.0,0.0)],[b+lift,Vector2(1.0,0.0)],[b+up*RUNE_H+lift,Vector2(1.0,1.0)],[a+up*RUNE_H+lift,Vector2(0.0,1.0)]]
		for tri: Array in [[0,2,1],[0,3,2]]:
			for k: int in tri:
				var p: Vector3 = corners[k][0]
				var sq: Vector2 = corners[k][1]
				var d := _dress(p,normal)
				rv.append(p)
				rn.append(normal)
				rcol.append(d[0])
				ruv.append(d[1])
				ruv2.append(d[2])
				rc0.append_array([2.0,aspect,sq.x*length,seed_value])
				rc1.append_array([sq.x,sq.y,count,0.0])

	## The mesh (the stone's surface in `stone_mat`, then the runes' in
	## `rune_mat`), or null.
	func mesh(stone_mat: Material, rune_mat: Material) -> ArrayMesh:
		if v.is_empty(): return null
		var out := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		out.surface_set_material(0,stone_mat)
		if not rv.is_empty():
			var ra := []
			ra.resize(Mesh.ARRAY_MAX)
			ra[Mesh.ARRAY_VERTEX] = rv
			ra[Mesh.ARRAY_NORMAL] = rn
			ra[Mesh.ARRAY_COLOR] = rcol
			ra[Mesh.ARRAY_TEX_UV] = ruv
			ra[Mesh.ARRAY_TEX_UV2] = ruv2
			ra[Mesh.ARRAY_CUSTOM0] = rc0
			ra[Mesh.ARRAY_CUSTOM1] = rc1
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,ra,[],{},
				(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
			out.surface_set_material(1,rune_mat)
		return out

	## Its triangles.
	func triangles() -> int:
		return (v.size()+rv.size())/3
