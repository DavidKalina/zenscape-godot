extends RefCounted
## The city kit's stone (scripts/city_kit.gd): convex blocks drawn in the
## Olmec's weathered basalt (shaders/olmec_stone.gdshader, the material
## scripts/enemies/inhaler_head_look.gd `stone_material` makes, the head and
## body's own), so the city reads as the quarry he was cut from.
##
## A block is a set of planes (a box, a hex drum, a talud wedge, a sector of
## a ring), its corners found by Geometry3D and each face drawn flat. The
## vertices are dressed as the Sunken Giant's are (scripts/kit_isle/greybox/
## giant_stone.gd, its Mesher): the kit's tone by block and facing
## (scripts/ruin_stone_style.gd `shade`), an occlusion darkest at a block's
## foot in the colour's alpha, a little moss on tops; UV and UV2.x carry where
## the vertex rests times GRAIN, the shader's weathering grain. Rune bands
## (`runes`) are the shader's carved grooves (CUSTOM0/1, the serpent's), dead
## by default: the city's ornament does not glow (fire is the only light).
##
## Drawn only; the pieces collide themselves (clean walk boxes and hulls).
## Arrays and resources only, safe on a worker once `warm` has run.
const HeadLook = preload("res://scripts/enemies/inhaler_head_look.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")

## The quarry's seed (the head's own: one carver).
const STONE_SEED := 7
## The grain's scale on the rest place (the giant's 0.55: a city seen
## across a gulf, coarser than the head's).
const GRAIN := 0.5
## The occlusion: least at a block's foot, rising over FOOT_RISE m; the tone
## kept where it is darkest.
const FOOT_OCC := 0.5
const FOOT_RISE := 1.8
const AO_FLOOR := 0.45
## Moss on tops, sparse underground: the city is dry stone, roots and a
## little moss where water once ran.
const MOSS := Color("3a4228")
const MOSS_LIGHT := Color("525a30")
const MOSS_UP := 0.7
## A rune cell's height (m) and about how long a cell is.
const RUNE_H := 0.8
const RUNE_CELL := 0.75
## A plane's corners are those within this of it (m).
const ON_PLANE := 0.002

static var _stone: ShaderMaterial = null
static var _runes: ShaderMaterial = null

## The materials, made on the main thread. `glow` the runes' light (0: dead
## grooves, the kit's rule).
static func warm(glow := 0.0) -> void:
	_stone = HeadLook.stone_material()
	if _runes == null:
		_runes = ShaderMaterial.new()
		_runes.shader = HeadLook.STONE_SHADER
		_runes.set_shader_parameter("roughness_value",0.95)
		_runes.set_shader_parameter("runes",true)
		_runes.set_shader_parameter("rune_cut",0.75)
		_runes.set_shader_parameter("energy",glow)
		_runes.set_shader_parameter("glow",Color(1.0,0.72,0.42))
		_runes.set_shader_parameter("pulse_wave",14.0)
		Style.dress(_runes)

## `m`'s mesh in the kit's materials, `kind` the piece's wear (WEAR).
static func mesh_of(m: Mesher, kind := "pier") -> ArrayMesh:
	if _stone == null: warm()
	return m.mesh(wear(kind),_runes)

## One basalt, a different wear per piece: the same shader, washes and
## palette, a few knobs apart (weathered stone, kit-stone-weathered.md). The
## lichen is the underground's: dry, olive-grey and ochre, kept dim so it
## never glows in the dark.
const LICHEN_A := Color(0.33,0.35,0.28)
const LICHEN_B := Color(0.46,0.42,0.31)
const WEAR := {
	# The pillars' flanks and wells: the base stone.
	"pier":{},
	# Treads and cheek crests: walked pale, edges chipped, a little crisper.
	"stair":{"pale_mul":Vector3(2.0,1.9,1.75),"weather":1.1,"bump_strength":0.9},
	# The long deck: rain-washed, a touch more grime in its soffits.
	"span":{"weather":1.1,"grime_mul":Vector3(0.28,0.28,0.27)},
	# Fire stone: sooted dark in the crevices, little pale, lichen burnt off.
	"fire":{"grime_mul":Vector3(0.2,0.19,0.18),"pale_mul":Vector3(1.4,1.35,1.28),"weather":0.95,
		"lichen_a":Color(0.24,0.25,0.2),"lichen_b":Color(0.33,0.3,0.23)},
	# What has broken: fresh pale chips and crisp faces, not yet greyed.
	"break":{"pale_mul":Vector3(2.15,2.05,1.9),"weather":0.9,"bump_strength":1.05},
	# The refuges: dust-greyed, lighter crevices, lichen turned to soot.
	"refuge":{"grime_mul":Vector3(0.4,0.39,0.38),"weather":1.0,
		"lichen_a":Color(0.36,0.34,0.31),"lichen_b":Color(0.5,0.45,0.38)},
}
static var _wears := {}

## The stone material of wear `kind` (a ShaderMaterial of the Olmec's shader).
static func wear(kind: String) -> ShaderMaterial:
	if _wears.has(kind): return _wears[kind]
	var base := HeadLook.stone_material()
	var m := base.duplicate() as ShaderMaterial
	m.set_shader_parameter("lichen_a",LICHEN_A)
	m.set_shader_parameter("lichen_b",LICHEN_B)
	var d: Dictionary = WEAR.get(kind,{})
	for k: String in d: m.set_shader_parameter(k,d[k])
	_wears[kind] = m
	return m

static func stone_colour() -> Color:
	return Style.stone_of(STONE_SEED) if Style.ruled() else Color("5a5d63")

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
	## Moss on tops (0 none, 1 the giant's heavy cover).
	var moss := 0.35
	## Where a vertex rests is taken in this frame (the piece's), so pieces
	## built apart (a breakable unit) keep the grain they had in place.
	var rest_frame := Transform3D.IDENTITY
	var _noise := FastNoiseLite.new()
	var _centre := Vector3.ZERO
	var _foot := 0.0
	var _tone := 1.0

	func _init(colour: Color, moss_share := 0.35) -> void:
		stone = colour
		moss = moss_share
		_noise.seed = 31
		_noise.frequency = 0.35

	func _dress(p: Vector3, normal: Vector3) -> Array:
		var c := Style.shade(stone,_centre,p,normal,1.0)
		var occ := lerpf(FOOT_OCC,1.0,smoothstep(_foot,_foot+FOOT_RISE,p.y))
		if normal.y < -0.3: occ *= 0.75
		c = c*lerpf(AO_FLOOR,1.0,occ)*_tone
		var up := smoothstep(MOSS_UP,0.97,normal.y)
		if up > 0.0 and moss > 0.0:
			var q := rest_frame*p
			var patch := clampf(_noise.get_noise_3dv(q*0.6)*1.4+0.1,0.0,1.0)
			var green := MOSS.srgb_to_linear().lerp(MOSS_LIGHT.srgb_to_linear(),clampf(_noise.get_noise_3dv(q*3.0)+0.5,0.0,1.0))
			c = c.lerp(green,up*patch*moss)
		c.a = occ
		var rest := (rest_frame*p)*GRAIN
		return [c,Vector2(rest.x,rest.y),Vector2(rest.z,0.0)]

	func _tri(a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
		for p: Vector3 in [a,c,b]:
			var d := _dress(p,normal)
			v.append(p)
			n.append(normal)
			col.append(d[0])
			uv.append(d[1])
			uv2.append(d[2])

	## A flat convex face: `pts` (in any order) on the plane `normal`.
	func _face(pts: Array, normal: Vector3) -> void:
		if pts.size() < 3: return
		var m := Vector3.ZERO
		for p: Vector3 in pts: m += p
		m /= pts.size()
		var u := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
		var w := normal.cross(u)
		var sorted := pts.duplicate()
		sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return atan2((a-m).dot(w),(a-m).dot(u)) > atan2((b-m).dot(w),(b-m).dot(u)))
		# Fan from the first corner; wind so the face looks along `normal`.
		for k in range(1,sorted.size()-1):
			var a: Vector3 = sorted[0]
			var b: Vector3 = sorted[k]
			var c: Vector3 = sorted[k+1]
			if (b-a).cross(c-a).dot(normal) < 0.0: _tri(a,c,b,normal)
			else: _tri(a,b,c,normal)

	## A convex block: the space inside every plane of `planes` (each
	## plane's normal pointing out). `foot` the y its occlusion rises from
	## (its lowest corner if NAN), `tone` a share lighter or darker.
	## Returns its corners (none if the planes enclose nothing).
	func solid(planes: Array, foot := NAN, tone := 1.0) -> PackedVector3Array:
		var typed: Array[Plane] = []
		for p: Plane in planes: typed.append(p)
		var pts := Geometry3D.compute_convex_mesh_points(typed)
		if pts.size() < 4: return PackedVector3Array()
		var lo := INF
		var c := Vector3.ZERO
		for p in pts:
			lo = minf(lo,p.y)
			c += p
		_centre = c/pts.size()
		_foot = lo if is_nan(foot) else foot
		_tone = tone
		for pl: Plane in typed:
			var on: Array = []
			for p in pts:
				if absf(pl.distance_to(p)) < ON_PLANE*maxf(1.0,p.length()*0.02):
					var dup := false
					for q: Vector3 in on:
						if q.distance_squared_to(p) < 1e-8: dup = true
					if not dup: on.append(p)
			_face(on,pl.normal)
		return pts

	## A face of four corners `a`, `b`, `c`, `d` (in order round it, near
	## flat: a swept surface's strip), facing `toward`; `foot` the y its
	## occlusion rises from (its lowest corner if NAN), `tone` as `solid`'s.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, foot := NAN, tone := 1.0) -> void:
		var nl := (c-a).cross(d-b)
		if nl.length_squared() < 1e-10: return
		nl = nl.normalized()
		if nl.dot(toward) < 0.0: nl = -nl
		_centre = (a+b+c+d)*0.25
		_foot = minf(minf(a.y,b.y),minf(c.y,d.y)) if is_nan(foot) else foot
		_tone = tone
		_face([a,b,c,d],nl)

	## A band of carved runes on a flat face: `a`, `b` its bottom corners,
	## `up` its height's way, `normal` out; `seed_value` its glyphs'.
	func runes(a: Vector3, b: Vector3, up: Vector3, normal: Vector3, seed_value: float, height := RUNE_H) -> void:
		_centre = (a+b)*0.5
		_foot = -INF
		_tone = 1.0
		var length := a.distance_to(b)
		var count := maxf(roundf(length/RUNE_CELL),1.0)
		var aspect := (length/count)/height
		var lift := normal*0.02
		var corners := [[a+lift,Vector2(0.0,0.0)],[b+lift,Vector2(1.0,0.0)],[b+up*height+lift,Vector2(1.0,1.0)],[a+up*height+lift,Vector2(0.0,1.0)]]
		var order := [[0,1,2],[0,2,3]] if (b-a).cross(up).dot(normal) < 0.0 else [[0,2,1],[0,3,2]]
		for tri: Array in order:
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

	## The mesh (stone in `stone_mat`, then runes in `rune_mat`), or null.
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

	func triangles() -> int:
		return (v.size()+rv.size())/3

# --- Planes ---------------------------------------------------------------------------

## A box's planes: half-size `h` at `xf`, its edges chamfered `bevel` m.
static func box(xf: Transform3D, h: Vector3, bevel := 0.0) -> Array:
	var out: Array = []
	for axis in 3:
		for s: float in [-1.0,1.0]:
			var nl := Vector3.ZERO
			nl[axis] = s
			out.append(_plane(xf,nl,h[axis]))
	if bevel > 0.0:
		for k in 3:
			var a := (k+1)%3
			var b := (k+2)%3
			for sa: float in [-1.0,1.0]:
				for sb: float in [-1.0,1.0]:
					var nl := Vector3.ZERO
					nl[a] = sa
					nl[b] = sb
					out.append(_plane(xf,nl.normalized(),(h[a]+h[b]-bevel)/sqrt(2.0)))
	return out

## A drum's planes: `sides` round (the first face toward +Z), its
## apothem `r0` at its foot and `r1` at its top (a batter), `tall` high,
## its foot at `xf`'s origin; its top rim chamfered `bevel`.
static func drum(xf: Transform3D, sides: int, r0: float, r1: float, tall: float, bevel := 0.0, turn := 0.0) -> Array:
	var out: Array = [_plane(xf,Vector3.DOWN,0.0),_plane(xf,Vector3.UP,tall)]
	var lean := atan2(r0-r1,tall)
	for k in range(sides):
		var a := turn+TAU*k/sides
		var d := Vector3(sin(a),0.0,cos(a))
		var nl := (d*cos(lean)+Vector3.UP*sin(lean)).normalized()
		out.append(_plane(xf,nl,r0*cos(lean)))
		if bevel > 0.0:
			var nb := (d+Vector3.UP).normalized()
			out.append(_plane(xf,nb,(r1+tall-bevel)/sqrt(2.0)))
	return out

## The plane with normal `nl` (in `xf`'s frame) `d` m out from its origin.
static func _plane(xf: Transform3D, nl: Vector3, d: float) -> Plane:
	var wn := (xf.basis*nl).normalized()
	var p := xf*(nl*d) if nl.length() > 0.0 else xf.origin
	# A non-uniform basis: the point on the plane is the local one moved.
	return Plane(wn,wn.dot(p))
