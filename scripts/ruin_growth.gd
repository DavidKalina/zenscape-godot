extends RefCounted
## The ruins' living growth (docs/scenic/ruin-overgrowth.md): the ivy, vine
## curtains, tendrils, leaf mats, tufts and moss cushions the ruin kit
## (scripts/ruin_kit.gd) grows on its stone, drawn as their own surface in
## shaders/ruin_growth.gdshader so they sway in the shared breeze, ride the
## gust fronts and the ribbons' wake, and part round the pilot and the plane.
## Never collided.
##
## Each growth face is built as the stone's are (Build `pending`), tagged with
## where it hangs from (`attrs`); `emit` writes its vertices into a Faces with
## the shader's per-vertex data (UV, UV2, CUSTOM0: see the shader's header).
##
## The vine curtains (`curtain`, `fringes`) are the new hanging growth: rows
## of strands draped from arch soffits, beam and deck undersides (every free
## strand a piece asks for with Build `hang` becomes a curtain) and down from
## wall heads, each strand a thin faceted stem strung with small folded
## leaves (two triangles each), dense near the root, thinning to a bare
## tendril with a curl at the tip. Many small pieces, a root-to-tip gradient,
## tips that glow when backlit; moss stays low cushions.

const SHADER = preload("res://shaders/ruin_growth.gdshader")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The ivy's leaves as cards: a cluster of leaves modelled and rendered in
## Blender (art/blender/ivy_cards/, assets/textures/ivy_cards.png: four
## clusters in a 2x2 atlas), cut out by the shader, in place of two-triangle
## leaves. A card hangs from a stem's node, CARD times the leaf's size long,
## at CARD_ODDS of the nodes (each card a whole cluster). --ivy-cards=0 the
## old leaves. Each card vertex carries its place on the card in CUSTOM1
## (x: u + 2 + 2 * the cell, y: v down from the stalk; 0 off a card).
static var cards := not "--ivy-cards=0" in LaunchArgs.user_args()
const CARD := 2.1
const CARD_ODDS := 0.42
const CARD_ATLAS = preload("res://assets/textures/ivy_cards.png")

## One growth face's attrs (PackedFloat32Array): its anchor's height, the
## strand's length (0: does not sway), the face its strand lies on (x, z;
## 0 hanging free), how free it hangs (0..1), its flutter (0..1), its clump's
## phase (0..1), upright (1 for a tuft standing up from its anchor), and its
## share of the root-to-tip colour (-1: from how far down the strand it is).
enum {A_Y,A_SPAN,A_OX,A_OZ,A_FREE,A_FLUTTER,A_PHASE,A_UP,A_ALONG,A_SIZE}

## Leaf greens for the curtains (sRGB): the ivy's, a little fresher.
const VINE := [Color("2a4123"),Color("33502a"),Color("3d5f2e"),Color("4b6d33"),Color("5d813b"),Color("6e8f42")]
## A curtain leaf's length (m) at the root and at the tip, its width share,
## the stem's radius, the step between leaf nodes (m) and the stem's
## segments (m); lean (halls by the dozen): bigger, fewer.
const LEAF := Vector2(0.15,0.075)
const LEAF_WIDTH := 0.62
const STEM := 0.013
const NODE_STEP := 0.085
const STEM_STEP := 0.3
const LEAN_SCALE := 1.6
## The tendril: the last share of a strand, bare but for a few small leaves,
## ending in a curl.
const TENDRIL := 0.2
## A curtain from a `hang` request: its strands' spacing (m), how many at
## most, and how much longer than the asked strand it hangs (strong first:
## the motion must read at play distance).
const SPACING := Vector2(0.13,0.22)
const STRANDS := 11
const STRANDS_LEAN := 5
const LENGTH_GAIN := 1.8
const LONGEST := 6.0
## Wall-head fringes: rows of strands draped down a wall from its head, how
## many rows a piece grows (by its high tops' area, capped) and how long.
const FRINGE_RATE := 0.35
const FRINGES := 6
const FRINGES_LEAN := 2
const FRINGE_LENGTH := Vector2(1.6,5.0)

static var _material: ShaderMaterial
## Whether pieces built from now on grow the vine curtains and fringes (the
## gallery's compare, the tests' cost split); the ivy, mats and moss grow
## either way.
static var vines := true

## The growth's material (one, shared: the gallery's wind toggle and the
## pushers set it once for every ruin).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("ivy_cards",CARD_ATLAS)
	return _material

static func attrs(anchor_y: float, span: float, out: Vector3, free: float, flutter: float, phase: float, upright := false, along := -1.0) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(A_SIZE)
	a[A_Y] = anchor_y
	a[A_SPAN] = span
	a[A_OX] = out.x
	a[A_OZ] = out.z
	a[A_FREE] = free
	a[A_FLUTTER] = flutter
	a[A_PHASE] = phase
	a[A_UP] = 1.0 if upright else 0.0
	a[A_ALONG] = along
	return a

## Still growth: moss cushions (pinned, no flutter).
static func still() -> PackedFloat32Array:
	return attrs(0.0,0.0,Vector3.ZERO,0.0,0.0,0.0,false,0.55)

## A surface's growth faces as they are built: the stone's arrays and the
## shader's per-vertex data.
class Faces extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cu := PackedFloat32Array()
	## The cards' places (CUSTOM1, two a vertex), padded with 0 for the
	## vertices before a card's; empty with no card.
	var cd := PackedFloat32Array()

	func is_empty() -> bool:
		return v.is_empty()

	## The surface arrays (for ArrayMesh add_surface_from_arrays with FORMAT).
	func arrays() -> Array:
		var s := []
		s.resize(Mesh.ARRAY_MAX)
		s[Mesh.ARRAY_VERTEX] = v
		s[Mesh.ARRAY_NORMAL] = n
		s[Mesh.ARRAY_COLOR] = c
		s[Mesh.ARRAY_TEX_UV] = uv
		s[Mesh.ARRAY_TEX_UV2] = uv2
		s[Mesh.ARRAY_CUSTOM0] = cu
		if not cd.is_empty():
			cd.resize(v.size()*2)
			s[Mesh.ARRAY_CUSTOM1] = cd
		return s

## The surface format the growth's CUSTOM0 needs.
const FORMAT := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT | Mesh.ARRAY_CUSTOM_RG_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT

## Adds the growth surface `f` to `mesh` (nothing if empty).
static func add_surface(mesh: ArrayMesh, f: Faces) -> void:
	if f.is_empty(): return
	var s := f.arrays()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,s,[],{},FORMAT)
	mesh.surface_set_material(mesh.get_surface_count()-1,material())
	mesh.set_meta("growth_arrays",s)

## A growth surface's arrays from `mesh` (kept, or read back), or [].
static func arrays_of(mesh: Mesh) -> Array:
	if mesh.has_meta("growth_arrays"): return mesh.get_meta("growth_arrays")
	for i in range(mesh.get_surface_count()):
		if mesh.surface_get_material(i) == material(): return mesh.surface_get_arrays(i)
	return []

## Appends a growth surface's arrays `s`, moved by `xf`, to `f`.
static func append(f: Faces, s: Array, xf: Transform3D) -> void:
	var mv: PackedVector3Array = s[Mesh.ARRAY_VERTEX]
	var mn: PackedVector3Array = s[Mesh.ARRAY_NORMAL]
	var mcu: PackedFloat32Array = s[Mesh.ARRAY_CUSTOM0]
	var mcd: Variant = s[Mesh.ARRAY_CUSTOM1] if s.size() > Mesh.ARRAY_CUSTOM1 else null
	if mcd != null:
		f.cd.resize(f.v.size()*2)
		f.cd.append_array(mcd as PackedFloat32Array)
	for i in range(mv.size()):
		f.v.append(xf*mv[i])
		f.n.append((xf.basis*mn[i]).normalized())
		var o := xf.basis*Vector3(mcu[i*4],0.0,mcu[i*4+1])
		f.cu.append_array([o.x,o.z,mcu[i*4+2],mcu[i*4+3]])
	f.c.append_array(s[Mesh.ARRAY_COLOR])
	f.uv.append_array(s[Mesh.ARRAY_TEX_UV])
	f.uv2.append_array(s[Mesh.ARRAY_TEX_UV2])

## One growth face (its corners as drawn, a fan) into `f`: each vertex its
## reach from the anchor, the strand's length, flutter, phase, face and
## colour share. `turn` turns the face it lies on (a bend), or identity.
static func emit(f: Faces, corners: PackedVector3Array, normal: Vector3, colour: Color, a: PackedFloat32Array, turn := Basis.IDENTITY) -> void:
	var o := turn*Vector3(a[A_OX],0.0,a[A_OZ])
	var span := a[A_SPAN]
	var up := a[A_UP] > 0.5
	for k in range(1,corners.size()-1):
		var tri := [corners[0],corners[k],corners[k+1]]
		if (tri[1]-tri[0]).cross(tri[2]-tri[0]).dot(normal) > 0.0: tri = [tri[0],tri[2],tri[1]]
		for p: Vector3 in tri:
			var reach := 0.0
			if span > 0.0: reach = clampf(p.y-a[A_Y],0.0,span*1.2) if up else clampf(a[A_Y]-p.y,0.0,span*1.2)
			f.v.append(p)
			f.n.append(normal)
			f.c.append(colour)
			f.uv.append(Vector2(-reach if up else reach,span))
			f.uv2.append(Vector2(a[A_PHASE],a[A_FLUTTER]))
			var along := a[A_ALONG] if a[A_ALONG] >= 0.0 else (clampf(reach/span,0.0,1.0) if span > 0.0 else 0.5)
			f.cu.append_array([o.x,o.z,a[A_FREE],along])

## One card's quad (its corners as drawn, a fan of two triangles) into `f`,
## each corner its place on the card (`uvs`) in atlas cell `cell`; the rest
## as `emit`.
static func emit_card(f: Faces, corners: PackedVector3Array, uvs: PackedVector2Array, cell: int, normal: Vector3, colour: Color, a: PackedFloat32Array, turn := Basis.IDENTITY) -> void:
	f.cd.resize(f.v.size()*2)
	var o := turn*Vector3(a[A_OX],0.0,a[A_OZ])
	var span := a[A_SPAN]
	for k in range(1,corners.size()-1):
		var tri := [0,k,k+1]
		if (corners[k]-corners[0]).cross(corners[k+1]-corners[0]).dot(normal) > 0.0: tri = [0,k+1,k]
		for i: int in tri:
			var p := corners[i]
			var reach := clampf(a[A_Y]-p.y,0.0,span*1.2) if span > 0.0 else 0.0
			f.v.append(p)
			f.n.append(normal)
			f.c.append(colour)
			f.uv.append(Vector2(reach,span))
			f.uv2.append(Vector2(a[A_PHASE],a[A_FLUTTER]))
			var along := a[A_ALONG] if a[A_ALONG] >= 0.0 else (clampf(reach/span,0.0,1.0) if span > 0.0 else 0.5)
			f.cu.append_array([o.x,o.z,a[A_FREE],along])
			f.cd.append_array([uvs[i].x+2.0+2.0*cell,uvs[i].y])

# --- Curtains -------------------------------------------------------------------

## A curtain for each free strand `b` asked for (Build `hang`): a row of
## strands under the underside over it, along the way the underside runs,
## longest in the row's middle, their tips ragged. Thinned by the detail (by
## index, so the seed's draw is kept), fewer and coarser on lean stone.
static func curtains(b) -> void:
	if not vines: return
	for hi in range(b.hangs.size()):
		var h: Array = b.hangs[hi]
		if b.level < 1.0 and fmod(hi*0.618,1.0) >= b.level: continue
		curtain(b,h[0],h[1],h[3])

## One curtain under the underside over `at` (x, z; from height `from`, or
## found by looking up from the floor): a row of strands along the way the
## underside runs, longest in its middle, its tips ragged, hanging
## LENGTH_GAIN x `length` (at most `longest`). `most`: its strands at most
## (-1: STRANDS, or STRANDS_LEAN on lean stone); `full`: as `strand`.
static func curtain(b, at: Vector3, length: float, from := -1.0, most := -1, longest := LONGEST, full := false, coarse := 1.0) -> void:
	if from < 0.0:
		from = _underside(b,at,0.5,14.0)
		if from < 0.0: return
	if length < 0.2: return
	var way := _run_way(b,at,from)
	var spacing: float = b.rng.randf_range(SPACING.x,SPACING.y)*(LEAN_SCALE if b.lean else 1.0)
	if most < 0: most = STRANDS_LEAN if b.lean else STRANDS
	var count := clampi(int(round(most*b.rng.randf_range(0.55,1.0))),2,most)
	var long := minf(length*LENGTH_GAIN+0.6,longest)
	var facing := Vector3(-way.z,0.0,way.x)
	var shift: float = b.rng.randf_range(-0.3,0.3)*count*spacing
	for i in range(count):
		var t := (i+0.5)/count
		var p: Vector3 = at+way*((t-0.5)*count*spacing+shift+b.rng.randf_range(-0.03,0.03))
		var top := _underside(b,p,from-0.9,from+1.2)
		if top < 0.0: continue
		var envelope := 0.5+0.5*sin(PI*t)
		var room: float = top-b.floor_at(p.x,p.z)-0.35
		var l := minf(long*envelope*b.rng.randf_range(0.6,1.1),room)
		if l < 0.3: continue
		strand(b,Vector3(p.x,top,p.z),l,facing,true,coarse,full)

## The rows draped down from wall heads: a few of the high tops' edges whose
## face falls away under them, each a row of strands hugging the face (out
## round what stands proud, free where it overhangs).
static func fringes(b) -> void:
	if not vines: return
	var high: Array = []
	var area := 0.0
	for t: Array in b.tops:
		var poly: PackedVector3Array = t[0]
		if poly[0].y < 1.8: continue
		high.append(t)
		area += float(t[1])
	if high.is_empty(): return
	var cap: int = FRINGES_LEAN if b.lean else FRINGES
	var count := int(mini(cap,int(area*FRINGE_RATE*(0.4+b.weathered)+b.rng.randf()))*b.level)
	for i in range(count):
		for attempt in range(8):
			var roll: float = b.rng.randf()*area
			var pick: Array = high[0]
			for t: Array in high:
				roll -= float(t[1])
				if roll <= 0.0:
					pick = t
					break
			var poly: PackedVector3Array = pick[0]
			var centre := Vector3.ZERO
			for q in poly: centre += q
			centre /= poly.size()
			var k: int = b.rng.randi()%poly.size()
			var p0 := poly[k]
			var p1 := poly[(k+1)%poly.size()]
			var edge := p1-p0
			if edge.length() < 0.5: continue
			var out := Vector3(edge.z,0.0,-edge.x).normalized()
			var mid := p0.lerp(p1,b.rng.randf_range(0.2,0.8))
			if out.dot(mid-centre) < 0.0: out = -out
			if b._inside(mid+out*0.12+Vector3.DOWN*0.3) or b._inside(mid+out*0.1+Vector3.UP*0.08): continue
			var along := edge.normalized()
			var spacing: float = b.rng.randf_range(0.14,0.2)*(LEAN_SCALE if b.lean else 1.0)
			var strands := mini(int(edge.length()*0.8/spacing),b.rng.randi_range(4,9) if not b.lean else 3)
			var long: float = lerpf(FRINGE_LENGTH.x,FRINGE_LENGTH.y,b.weathered)*b.rng.randf_range(0.6,1.0)
			for j in range(strands):
				var t := (j+0.5)/strands
				var at := mid+along*(t-0.5)*strands*spacing
				if (at-p0).dot(along) < 0.05 or (at-p1).dot(along) > -0.05: continue
				var l := minf(long*(0.45+0.55*sin(PI*t))*b.rng.randf_range(0.7,1.1),at.y-0.1)
				strand(b,at+out*0.05+Vector3.UP*0.02,l,out,false)
			break

## One strand from `start` down `length` m, `out` the way it faces: free
## (in the air under an underside) or hugging the face under it (pushed out
## round what stands proud, hanging free where the face falls away).
## `coarse` scales its leaves and their spacing (fewer, bigger: growth seen
## from further off), its stem then a flat ribbon; `full`: two leaves a
## node on lean stone too (a fuller strand).
static func strand(b, start: Vector3, length: float, out: Vector3, free: bool, coarse := 1.0, full := false) -> void:
	var lean: bool = b.lean
	var scale := (LEAN_SCALE if lean else 1.0)*coarse
	var side := Vector3(-out.z,0.0,out.x)
	var step := NODE_STEP*scale
	var p := start
	var travelled := 0.0
	var in_air := 0.0
	var stem_from := start
	var stem_len := 0.0
	var phase: float = b.rng.randf()
	var drift: Vector3 = side*b.rng.randf_range(-0.05,0.05)
	var keep: PackedFloat32Array = b.grow
	var bare := length*(1.0-TENDRIL)
	var node := 0
	while travelled < length:
		# A flown lane kept clear (Build `clear`): the strand stops short.
		if b.kept_clear(p): break
		var t := travelled/length
		var hug := 0.0 if free else (1.0 if in_air <= 0.0 else 0.0)
		var air_share := 1.0 if free else clampf(in_air/0.4,0.0,1.0)
		# The leaves at this node: two (one on lean stone) about the stem,
		# alternating sides; on the tendril only now and then, and smaller.
		var on_tendril := travelled > bare
		if not on_tendril or node%3 == 0:
			var size: float = lerpf(LEAF.x,LEAF.y,smoothstep(0.3,1.0,t))*scale*b.rng.randf_range(0.8,1.15)
			if on_tendril: size *= 0.7
			for j in range(1 if ((lean and not full) or on_tendril) else 2):
				var s := 1.0 if (node+j)%2 == 0 else -1.0
				b.grow = attrs(start.y,length,out,air_share,1.0,fmod(phase+node*0.137+j*0.31,1.0))
				_vine_leaf(b,p,out,side*s,size,t,hug)
		node += 1
		var next: Vector3 = p+Vector3.DOWN*step+drift*step+side*b.rng.randf_range(-0.02,0.02)
		if not free:
			var pushed := 0.0
			while b._inside(next) and pushed < 0.7:
				next += out*0.05
				pushed += 0.05
			if pushed >= 0.7: break
			var gap: float = b._gap(next,-out,0.45)
			if gap < 0.45:
				next -= out*maxf(0.0,gap-0.04)
				in_air = 0.0
			else:
				in_air += step
		elif b._inside(next): break
		if next.y < b.floor_at(next.x,next.z)+0.06: break
		stem_len += step
		if stem_len >= STEM_STEP*scale or travelled+step >= length:
			b.grow = attrs(start.y,length,out,air_share,0.0,phase)
			if coarse > 1.0: _ribbon(b,stem_from,next,STEM*scale*lerpf(1.0,0.6,t),out)
			else: _stem(b,stem_from,next,STEM*scale*lerpf(1.0,0.6,t))
			stem_from = next
			stem_len = 0.0
		p = next
		travelled += step
	# The tendril's curl: a little hook turned up at its tip.
	if travelled >= length*0.9:
		b.grow = attrs(start.y,length,out,1.0,0.6,phase)
		var hook := p+Vector3.DOWN*0.06*scale+side*0.05*scale
		_stem(b,p,hook,STEM*scale*0.55)
		_stem(b,hook,hook+Vector3.UP*0.05*scale+side*0.02*scale+out*0.02,STEM*scale*0.45)
	b.grow = keep

## A small folded leaf (two triangles) hanging from the stem at `at`: its
## blade tipped down and out, folded along its midrib, facing `out` (or
## lying on the face when it `hug`s it).
static func _vine_leaf(b, at: Vector3, out: Vector3, side: Vector3, size: float, t: float, hug: float) -> void:
	if cards and b.has_method("card_face"):
		_leaf_card(b,at,out,side,size,t,hug)
		return
	var rng: RandomNumberGenerator = b.rng
	var down := Vector3.DOWN*lerpf(0.55,0.85,hug)
	var axis := (down+out*lerpf(0.6,0.15,hug)+side*rng.randf_range(0.2,0.7)+Vector3(rng.randf_range(-0.2,0.2),rng.randf_range(-0.1,0.25),rng.randf_range(-0.2,0.2))).normalized()
	var face := (out-axis*axis.dot(out)).normalized()
	if face.length() < 0.5: face = side.cross(axis).normalized()
	var across := axis.cross(face).normalized()
	var w := size*LEAF_WIDTH*0.5
	var base := at+side*0.01
	var tip := base+axis*size
	var mid := base+axis*size*0.42
	var fold := face*size*rng.randf_range(0.08,0.16)
	var left := mid+across*w+fold
	var right := mid-across*w+fold
	var shade := clampf(0.35+0.5*t+rng.randf_range(-0.3,0.3),0.0,0.999)
	var colour: Color = (VINE[int(shade*VINE.size())] as Color).srgb_to_linear()*rng.randf_range(0.9,1.08)
	colour.a = 1.0
	b.growth_face(PackedVector3Array([base,left,tip]),(left-base).cross(tip-base).normalized()*_sign_to((left-base).cross(tip-base),face),colour)
	b.growth_face(PackedVector3Array([base,tip,right]),(tip-base).cross(right-base).normalized()*_sign_to((tip-base).cross(right-base),face),colour)

## A card of leaves (CARD_ODDS of the time) hanging from the stem at `at`:
## CARD times `size` long, as wide, down and a little out from the stone (or
## lying on it when it `hug`s it), folded down its middle toward `out`; a
## random cluster of the atlas, mirrored half the time.
static func _leaf_card(b, at: Vector3, out: Vector3, side: Vector3, size: float, t: float, hug: float) -> void:
	var rng: RandomNumberGenerator = b.rng
	if rng.randf() > CARD_ODDS: return
	var length := size*CARD*rng.randf_range(0.85,1.15)
	var axis := (Vector3.DOWN+out*lerpf(0.4,0.1,hug)+side*rng.randf_range(-0.3,0.3)).normalized()
	var face := (out-axis*axis.dot(out)).normalized()
	if face.length() < 0.5: face = side.cross(axis).normalized()
	var across := axis.cross(face).normalized()
	var top := at+face*0.02
	var w := length*0.5
	var fold := face*length*rng.randf_range(0.06,0.16)
	var bl := top-across*w
	var br := top+across*w
	var bm := top+fold*0.4
	var tl := bl+axis*length
	var tr := br+axis*length
	var tm := top+axis*length+fold
	var cell := rng.randi_range(0,3)
	var u0 := 1.0 if rng.randf() < 0.5 else 0.0
	var u1 := 1.0-u0
	var shade := clampf(0.35+0.5*t+rng.randf_range(-0.3,0.3),0.0,0.999)
	var colour: Color = (VINE[int(shade*VINE.size())] as Color).srgb_to_linear()*rng.randf_range(0.9,1.08)
	colour.a = 1.0
	var nl := (tl-bl).cross(bm-bl).normalized()
	var nr := (tm-bm).cross(br-bm).normalized()
	b.card_face(PackedVector3Array([bl,tl,tm,bm]),PackedVector2Array([Vector2(u0,0.0),Vector2(u0,1.0),Vector2(0.5,1.0),Vector2(0.5,0.0)]),nl*_sign_to(nl,face),colour,cell)
	b.card_face(PackedVector3Array([bm,tm,tr,br]),PackedVector2Array([Vector2(0.5,0.0),Vector2(0.5,1.0),Vector2(u1,1.0),Vector2(u1,0.0)]),nr*_sign_to(nr,face),colour,cell)

static func _sign_to(n: Vector3, face: Vector3) -> float:
	return 1.0 if n.dot(face) >= 0.0 else -1.0

## A thin three-sided stem from `a` to `b2`, `r` across.
static func _stem(b, a: Vector3, b2: Vector3, r: float) -> void:
	var axis := b2-a
	if axis.length() < 0.005: return
	axis = axis.normalized()
	var u := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	var colour := Color("3b4a26").srgb_to_linear()
	for k in range(3):
		var a0 := TAU*k/3.0
		var a1 := TAU*(k+1)/3.0
		var d0 := u*cos(a0)+v*sin(a0)
		var d1 := u*cos(a1)+v*sin(a1)
		var n := (d0+d1).normalized()
		b.growth_face(PackedVector3Array([a+d0*r,a+d1*r,b2+d1*r,b2+d0*r]),n,colour)

## A flat stem from `a` to `b2`, `r` across, facing `out` (one quad; the
## growth draws both sides).
static func _ribbon(b, a: Vector3, b2: Vector3, r: float, out: Vector3) -> void:
	var axis := b2-a
	if axis.length() < 0.005: return
	var across := axis.cross(out).normalized()
	if across.length() < 0.5: return
	b.growth_face(PackedVector3Array([a-across*r,a+across*r,b2+across*r,b2-across*r]),out,Color("3b4a26").srgb_to_linear())

## The underside over `at` (x, z): the lowest stone looking up from `low`
## to `high`, a little under it; -1 if none.
static func _underside(b, at: Vector3, low: float, high: float) -> float:
	var y := low
	while y < high:
		if b._inside(Vector3(at.x,y,at.z)): return y-0.03
		y += 0.06
	return -1.0

## The way the underside over `at` (from height `from`) runs furthest: of
## four ways across, the one with stone over it for longest (a soffit's run,
## a beam's length, a deck's span).
static func _run_way(b, at: Vector3, from: float) -> Vector3:
	var best := Vector3.RIGHT
	var most := -1.0
	var turn: float = b.rng.randf()*0.3
	for k in range(4):
		var a := turn+PI*k/4.0
		var way := Vector3(cos(a),0.0,sin(a))
		var run := 0.0
		for s: float in [-1.0,1.0]:
			var d := 0.15
			while d < 1.6:
				var q := at+way*s*d
				if b._inside(Vector3(q.x,from+0.12,q.z)) or b._inside(Vector3(q.x,from+0.45,q.z)) or b._inside(Vector3(q.x,from+0.9,q.z)): run += 0.15
				else: break
				d += 0.15
		if run > most:
			most = run
			best = way
	return best
