extends Node3D
## A natural rock arch hung in the sky (studies/home_hub.gd's): a ring of
## bedded rock, built bed by bed as home's sea cliffs are layered (scripts/
## sea_cliffs.gd): two legs standing on a sill whose rock tapers under it to
## a keel, as the isles' does, and a crown over the opening, a turf cap on
## top and on the sill. Each bed is a block of its own outline (a rounded
## slab, its rim wandering), a hard bed standing out of the soft ones, so
## the arch steps in ledges and overhangs as the cliffs do; the faces carry
## the cliffs' bed colours (the earth sides' `side_painted`).
##
## The frame: the origin is the opening's floor middle, x across the
## opening, y up, z through it (fly along +-z). The opening is `width` m
## clear at its floor (WorldScale.opening of the spec's toy width, AGENTS.md
## Sizes) and `height` m to its apex; its sides curve in toward the apex
## (a superellipse, SHOULDER), so it is about 90% of its width clear half
## way up. Every bed's jut and wander stays outside that (SPARE).
##
## A layout piece (scripts/layout_overrides.gd) whose knobs are its tunes
## (`layout_tunes`): a changed one builds it again under the same node.

const WorldScale = preload("res://scripts/world_scale.gd")
const RockLooks = preload("res://scripts/rock_looks.gd")

## The beds: each a whole number of BED units high (by weight), drawn THICK
## times over; a hard one stands BED_OUT.x m out, a soft one BED_OUT.y in.
const BED := 2.0
const BEDS := [[1,0.35],[2,0.4],[3,0.25]]
const THICK := Vector2(0.6,1.55)
const BED_OUT := Vector2(0.55,-0.4)
## Each block's rim wanders in and out by up to JITTER m.
const JITTER := 1.3
## A soft bed's middle is notched in this far (m), under the hard one over it.
const NOTCH := 0.7
## The profile's inner edge stands this far outside the clear opening: a
## block's rim is never let past 0.3 m into it.
const SPARE := 0.6
## The opening's sides: a superellipse of this power (higher, squarer).
const SHOULDER := 2.6
## A block's rim: points per corner (a quarter round), and its corners'
## most radius (m).
const ARC := 5
const CORNER := 4.5
## A straight run of a block's rim is broken every EDGE m.
const EDGE := 2.2
## The turf (the sea cliffs' own) on the cap and the sill; the ledges'
## moss, patchy, over LEDGE_PATCH.
const TURF := Color(0.11,0.22,0.06)
const LEDGE_PATCH := -0.3
## The colours' warm and cool patches (as the cliffs').
const WARM := 0.3
const WARM_WAVE := 0.03

## The knobs: seed, toy width (the opening is WorldScale.opening of it),
## height (share of the width), through depth (m), each leg's width and the
## crown's rock (shares of the width), the keel's depth (share of the outer
## half width), the strata's dip (m a metre).
const KNOBS := {"seed":[1,1,999],"toy":[16.0,3.5,40.0],"tall":[0.8,0.4,1.6],"deep":[12.0,4.0,40.0],
	"leg":[0.42,0.15,1.2],"rib":[0.3,0.12,1.0],"keel":[0.9,0.0,2.5],"dip":[0.03,0.0,0.12]}

var spec := {}
## The rock's look: {palette, tone, vary} (scripts/rock_looks.gd).
var look := {"palette":"basalt_warm","tone":0.86,"vary":0.5}
## The sides' material (home's own walls', each arch its own copy, its
## mist at its own keel tip).
var source: Material = null
var made := {}
var _mesh: MeshInstance3D = null
var _body: StaticBody3D = null

static func knobs_of(s: Dictionary) -> Dictionary:
	var out := {}
	for k: String in KNOBS:
		var r: Array = KNOBS[k]
		out[k] = clampf(float(s.get(k,r[0])),float(r[1]),float(r[2]))
	out.seed = int(out.seed)
	return out

## Its opening's clear width and height (m) for `s`.
static func opening_of(s: Dictionary) -> Vector2:
	var k := knobs_of(s)
	var w := WorldScale.opening(float(k.toy))
	return Vector2(w,w*float(k.tall))

func setup(t: Transform3D, a_spec: Dictionary, a_look: Dictionary, material: Material) -> void:
	transform = t
	spec = knobs_of(a_spec)
	look = a_look
	source = material
	_build()

func _build() -> void:
	for n: Node in [_mesh,_body]:
		if n != null:
			remove_child(n)
			n.queue_free()
	made = make(spec,look)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Rock"
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,made.arrays)
	var m: Material = source.duplicate() if source != null else null
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("earth_sides_base",float(made.bottom))
		(m as ShaderMaterial).set_shader_parameter("earth_sides_top",float(made.top))
	if m != null: mesh.surface_set_material(0,m)
	_mesh.mesh = mesh
	_mesh.set_meta("skip_reflection",true)
	add_child(_mesh)
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 1
	_body.collision_mask = 0
	for hull: PackedVector3Array in made.hulls:
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		var holder := CollisionShape3D.new()
		holder.shape = shape
		_body.add_child(holder)
	add_child(_body)

## The arch for knobs `s` and rock `rock` ({palette, tone, vary}): {arrays
## (the mesh's), hulls (each block's points, for its convex shape), width,
## height (the opening's), top, bottom (m), outer (its outer half width at
## the floor), triangles}. Plain data, safe on a worker.
static func make(s: Dictionary, rock: Dictionary) -> Dictionary:
	var k := knobs_of(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["rock arch",int(k.seed)])
	var w := WorldScale.opening(float(k.toy))
	var h := w*float(k.tall)
	var hw := w*0.5+SPARE
	var hi := h+SPARE
	var leg := maxf(w*float(k.leg),5.0)
	var x0 := hw+leg
	var rib := maxf(w*float(k.rib),4.0)
	var top := hi+rib
	var keel := x0*float(k.keel)
	var dz0 := float(k.deep)*0.5
	var dip := Vector2.from_angle(rng.randf()*TAU)*float(k.dip)
	var noise := FastNoiseLite.new()
	noise.seed = int(k.seed)*7+3
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.16
	noise.fractal_octaves = 2
	var warm := FastNoiseLite.new()
	warm.seed = int(k.seed)*7+5
	warm.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warm.frequency = WARM_WAVE
	# The beds, bottom up, with a boundary at the sill (0) and at the apex.
	var floors := PackedFloat32Array()
	var hard := PackedFloat32Array()
	var y := -keel if keel > 0.5 else 0.0
	var is_hard := rng.randf() < 0.5
	while y < top-0.4:
		floors.append(y)
		hard.append(rng.randf_range(0.65,1.0) if is_hard else rng.randf_range(0.0,0.35))
		var roll := rng.randf()
		var units := 1
		for b: Array in BEDS:
			roll -= float(b[1])
			if roll <= 0.0:
				units = int(b[0])
				break
		var next := y+units*BED*rng.randf_range(THICK.x,THICK.y)
		for cut: float in [0.0,hi]:
			if y < cut-0.3 and next > cut+0.3: next = cut
			elif absf(next-cut) <= 0.3: next = cut
		y = minf(next,top)
		is_hard = not is_hard if rng.randf() < 0.75 else is_hard
	floors.append(top)
	var tones := _tones(rock,hard,int(k.seed))
	# Not a picture frame: one leg broader than the other, the whole leaning
	# a little, the crown's top swelling or sagging.
	var legs := Vector2(rng.randf_range(0.8,1.2),rng.randf_range(0.8,1.2))
	var lean := rng.randf_range(-0.1,0.1)
	var sag := rng.randf_range(-0.6,0.5)*rib
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	var hulls: Array = []
	var shape := {"hw":hw,"hi":hi,"top":top,"keel":keel,"dz0":dz0,"x0":x0,"leg":leg,"legs":legs}
	for b in range(floors.size()-1):
		var y0 := floors[b]
		var y1 := floors[b+1]
		var ym := (y0+y1)*0.5
		var push := lerpf(BED_OUT.y,BED_OUT.x,hard[b])
		# A hard bed bulges at its middle, a soft one is notched in.
		var belly := push+(0.35 if hard[b] > 0.5 else -NOTCH)*minf((y1-y0)/2.0,1.0)
		var topmost := b == floors.size()-2
		var cap := TURF if topmost or is_equal_approx(y1,0.0) else Color.TRANSPARENT
		var sides: Array = [0.0] if y0 >= hi-0.01 or y1 <= 0.01 else [-1.0,1.0]
		for side: float in sides:
			var rings: Array = []
			# Every ring of a block the same points round: its runs broken
			# as often as its longest asks.
			var cuts := Vector2i.ONE
			for yy: float in [y0,ym,y1]:
				var sp := _span(yy,side,shape)
				cuts.x = maxi(cuts.x,clampi(int(ceil((sp.y-sp.x)/EDGE)),1,14))
				cuts.y = maxi(cuts.y,clampi(int(ceil(_depth(yy,dz0,hi,top,keel)*2.0/EDGE)),1,14))
			for at: Array in [[y0,push],[ym,belly],[y1,push]]:
				var yy: float = at[0]
				var r := _span(yy,side,shape)
				var clip := Vector2(-INF,INF)
				if side > 0.0: clip.x = r.x-0.3
				elif side < 0.0: clip.y = r.y+0.3
				var ring := _ring(r.x,r.y,_depth(yy,dz0,hi,top,keel),yy,float(at[1]),noise,dip,clip,cuts)
				if topmost and is_equal_approx(yy,y1):
					for q in range(ring.size()):
						var pt := ring[q]
						var across := clampf(absf(pt.x)/maxf(x0,1.0),0.0,1.0)
						pt.y += sag*(1.0-across*across)+noise.get_noise_2d(pt.x*1.7,pt.z*1.7)*1.2
						ring[q] = pt
				for q in range(ring.size()):
					var pt := ring[q]
					pt.x += pt.y*lean
					ring[q] = pt
				rings.append(ring)
			hulls.append((rings[0] as PackedVector3Array)+(rings[1] as PackedVector3Array)+(rings[2] as PackedVector3Array))
			_block(vertices,colours,rings,tones[b],cap,hard[b] > 0.5,noise,warm)
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,vertices.size(),3):
		var n := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3): normals[i+j] = n
	var uvs := PackedVector2Array()
	uvs.resize(vertices.size())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return {"arrays":arrays,"hulls":hulls,"width":w,"height":h,"top":top,"bottom":-keel,"outer":x0,"deep":dz0*2.0,
		"triangles":vertices.size()/3,"blocks":hulls.size()}

## The opening's side at `y` (m out from the middle): the superellipse up
## to the apex `hi`, nothing over it.
static func _inner(y: float, hw: float, hi: float) -> float:
	if y >= hi: return 0.0
	var t := clampf(y/hi,0.0,1.0)
	return hw*pow(1.0-pow(t,SHOULDER),1.0/SHOULDER)

## A block's x span at `y` (x from, x to): the whole width (`side` 0) or
## one leg (-1 left, 1 right), the opening between.
static func _span(y: float, side: float, f: Dictionary) -> Vector2:
	var legs: Vector2 = f.legs
	var right := _outer(y,float(f.hw)+float(f.leg)*legs.y,float(f.hi),float(f.top),float(f.keel))
	var left := _outer(y,float(f.hw)+float(f.leg)*legs.x,float(f.hi),float(f.top),float(f.keel))
	var inner := _inner(y,float(f.hw),float(f.hi))
	if side > 0.0: return Vector2(inner,right)
	if side < 0.0: return Vector2(-left,-inner)
	return Vector2(-left,right)

## The outer face at `y`: the legs flared into a broad foot, drawn in
## toward the crown's rounded top, and under the sill the keel tapering to
## its tip.
static func _outer(y: float, x0: float, hi: float, top: float, keel: float) -> float:
	if y < 0.0:
		var t := clampf(-y/maxf(keel,0.1),0.0,1.0)
		return maxf(x0*1.12*pow(1.0-t,0.55),1.6)
	var flare := 1.0+0.16*(1.0-smoothstep(0.0,hi*0.5,y))
	var draw := 1.0-0.42*pow(smoothstep(hi*0.25,top,y),1.6)
	return x0*flare*draw

## The block's half depth (through, z) at `y`.
static func _depth(y: float, dz0: float, hi: float, top: float, keel: float) -> float:
	if y < 0.0:
		var t := clampf(-y/maxf(keel,0.1),0.0,1.0)
		return maxf(dz0*1.1*pow(1.0-t,0.6),1.4)
	return dz0*(1.0+0.12*(1.0-smoothstep(0.0,hi*0.5,y))-0.25*smoothstep(hi*0.5,top,y))

## One block's rim at `y`: a rounded slab from x `a` to `b`, `dz` either
## side of the middle, its straight runs broken every EDGE m; every point
## stood out by `push` and its wander (buttresses and gullies running up
## the beds, as the cliffs' columns: the noise drawn out in y), never past
## `clip` (x) into the opening; the whole dipped (`dip`).
static func _ring(a: float, b: float, dz: float, y: float, push: float, noise: FastNoiseLite, dip: Vector2, clip: Vector2, cuts: Vector2i) -> PackedVector3Array:
	var out := PackedVector3Array()
	var r := minf(CORNER,minf((b-a)*0.45,dz*0.8))
	var corners := [Vector2(b-r,dz-r),Vector2(a+r,dz-r),Vector2(a+r,-dz+r),Vector2(b-r,-dz+r)]
	for c in range(4):
		var base := PI*0.5*c
		for j in range(ARC):
			var ang := base+PI*0.5*j/ARC
			var p: Vector2 = (corners[c] as Vector2)+Vector2.from_angle(ang)*r
			out.append(_stood(p,Vector2.from_angle(ang),y,push,noise,dip,clip))
		# The straight run on to the next corner.
		var along := Vector2.from_angle(base+PI*0.5)
		var from: Vector2 = (corners[c] as Vector2)+along*r
		var to: Vector2 = (corners[(c+1)%4] as Vector2)+along*r
		var steps := cuts.x if c % 2 == 0 else cuts.y
		for j in range(steps):
			out.append(_stood(from.lerp(to,float(j)/steps),along,y,push,noise,dip,clip))
	return out

static func _stood(p: Vector2, way: Vector2, y: float, push: float, noise: FastNoiseLite, dip: Vector2, clip: Vector2) -> Vector3:
	var wander := noise.get_noise_3d(p.x*0.7,y*0.08,p.y*0.7)*JITTER+noise.get_noise_3d(p.x*3.0+50.0,y*0.6,p.y*3.0)*0.25
	var q := p+way*(push+wander)
	q.x = clampf(q.x,clip.x,clip.y)
	return Vector3(q.x,y+dip.dot(q),q.y)

## A block of `rings` (bottom, middle, top; each the same points round):
## its sides in the bed's `tone`, a shade apart face by face, its top the
## turf (`cap`, if set) or the ledge's rock, mossed in patches on a hard
## bed, its underside the rock in shade.
static func _block(vertices: PackedVector3Array, colours: PackedColorArray, rings: Array, tone: Color, cap: Color, hard: bool, noise: FastNoiseLite, warm: FastNoiseLite) -> void:
	var lo: PackedVector3Array = rings[0]
	var up: PackedVector3Array = rings[rings.size()-1]
	var n := lo.size()
	var mid := Vector3.ZERO
	for ring: PackedVector3Array in rings:
		for p in ring: mid += p
	mid /= float(n*rings.size())
	for k in range(rings.size()-1):
		var r0: PackedVector3Array = rings[k]
		var r1: PackedVector3Array = rings[k+1]
		for i in range(n):
			var j := (i+1)%n
			var shade := 1.0+0.09*sin(float(i*7+k*3)*1.7)
			var inside := Vector3(mid.x,(r0[i].y+r1[i].y)*0.5,mid.z)
			_tri(vertices,colours,[r0[i],r0[j],r1[j]],inside,_tint(tone*shade,r0[i],warm))
			_tri(vertices,colours,[r0[i],r1[j],r1[i]],inside,_tint(tone*shade,r1[i],warm))
	var top_mid := Vector3.ZERO
	var low_mid := Vector3.ZERO
	for p in up: top_mid += p
	for p in lo: low_mid += p
	top_mid /= float(n)
	low_mid /= float(n)
	var moss := noise.get_noise_2d(top_mid.x*0.3+11.0,top_mid.z*0.3) > (LEDGE_PATCH if hard else 0.35)
	var top_c: Color = cap if cap.a > 0.0 else (tone*0.85).lerp(TURF,0.6 if moss else 0.0)
	for i in range(n):
		var j := (i+1)%n
		_tri(vertices,colours,[up[i],up[j],top_mid],top_mid+Vector3.DOWN*4.0,top_c)
		_tri(vertices,colours,[lo[j],lo[i],low_mid],low_mid+Vector3.UP*4.0,tone*0.6)

## A triangle wound to face away from `inside`.
static func _tri(vertices: PackedVector3Array, colours: PackedColorArray, t: Array, inside: Vector3, c: Color) -> void:
	var a: Vector3 = t[0]
	var b: Vector3 = t[1]
	var d: Vector3 = t[2]
	var n := (d-a).cross(b-a)
	if n.dot((a+b+d)/3.0-inside) < 0.0:
		var s := b
		b = d
		d = s
	vertices.append(a)
	vertices.append(b)
	vertices.append(d)
	for k in range(3): colours.append(c)

static func _tint(c: Color, at: Vector3, warm: FastNoiseLite) -> Color:
	var w := warm.get_noise_3d(at.x,at.y*1.5,at.z)
	return Color(c.r*(1.0+WARM*w),c.g*(1.0+WARM*0.3*w),c.b*(1.0-WARM*w))

## Each bed's colour, as the cliffs' (SeaCliffs `_bed_tones`): a hard bed
## one of the look's pale bands, a soft one a dark band, a shade apart.
static func _tones(rock: Dictionary, hard: PackedFloat32Array, seed_value: int) -> PackedColorArray:
	var name := str(rock.get("palette","basalt"))
	var tone := float(rock.get("tone",1.0))
	var vary := float(rock.get("vary",0.5))
	var pale: Array = [RockLooks.colour_of(name,"core_a",tone,vary),RockLooks.colour_of(name,"core_b",tone,vary)]
	var dark: Array = [RockLooks.colour_of(name,"core_c",tone,vary),RockLooks.colour_of(name,"bedrock",tone,vary)*1.25,RockLooks.colour_of(name,"core_a",tone,vary)]
	var out := PackedColorArray()
	for b in range(hard.size()):
		var pick := absi(hash([seed_value,b,"bed tone"]))
		var from: Array = pale if hard[b] > 0.5 else dark
		var c: Color = from[pick%from.size()]
		out.append(c*lerpf(0.75,1.15,float(pick/7%101)/100.0))
	return out

# --- The layout contract ------------------------------------------------------------

func layout_pose() -> Transform3D:
	return transform

func layout_place(t: Transform3D) -> void:
	transform = t

func layout_mid() -> Vector3:
	return global_transform*Vector3(0.0,float(made.get("height",10.0))*0.5,0.0)

func layout_reach() -> float:
	return float(made.get("outer",10.0))

func layout_tunes() -> Array:
	var labels := {"seed":"seed (shape)","toy":"toy width (opening = WorldScale.opening)","tall":"height (share of width)","deep":"through depth (m)",
		"leg":"leg width (share)","rib":"crown rock (share)","keel":"keel depth (share)","dip":"strata dip"}
	var out: Array = []
	for k: String in KNOBS:
		var r: Array = KNOBS[k]
		out.append([k,labels[k],spec.get(k,r[0]),r[1],r[2],1 if k == "seed" else (0.5 if k in ["toy","deep"] else 0.01)])
	return out

func layout_tune(key: String) -> float:
	return float(spec.get(key,0.0))

func layout_retune(key: String, v: float) -> void:
	var was := float(spec.get(key,0.0))
	spec = knobs_of(spec.merged({key:v},true))
	if is_equal_approx(was,float(spec.get(key,0.0))): return
	_build()
