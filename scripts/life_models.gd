extends RefCounted
## Low-poly creatures for the life that arrives on the land (docs/scenic/life.md):
## fish, frogs, frogspawn, a heron and deer. Every part is a
## faceted spindle (a bipyramid over a few-sided ring), a loft through a few
## rings, or a flat fan, painted with vertex colours and drawn with the Fidelity
## frogs' `reference_surface` material (flat faces, scene palette), so they sit
## in the Fidelity look and share a pipeline that is already compiled. Nothing
## here is fuzzy or smooth.
##
## Fish and frogs come in kinds (FISH_KINDS, FROG_KINDS): a body shape and a
## paint each, with the pattern baked into the vertex colours, so a new kind is
## a table entry. Colours in the tables are sRGB hex, turned linear as the
## source's THREE.Color did; the instance colour only nudges brightness.
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

	## A faceted loft through `rings`, each [centre, half-width, half-height
	## above, half-height below (optional)], closed at `front` and `back`.
	## `paint` colours each face: func(u, a) -> Color, with u running 0 to 1
	## from the first ring to the last and a the angle round the ring (PI/2 on
	## top, -PI/2 underneath).
	func loft(rings: Array, sides: int, paint: Callable, front = null, back = null) -> void:
		var frames: Array = []
		var count := rings.size()
		for i in range(count):
			var ring: Array = rings[i]
			var centre: Vector3 = ring[0]
			var ahead: Vector3 = rings[mini(i+1,count-1)][0]
			var behind: Vector3 = rings[maxi(i-1,0)][0]
			var axis := (ahead-behind).normalized()
			var side := axis.cross(Vector3.UP)
			if side.length_squared() < 1e-6: side = axis.cross(Vector3.RIGHT)
			side = side.normalized()
			var up := side.cross(axis).normalized()
			var points: Array[Vector3] = []
			for k in range(sides):
				var angle := TAU*float(k)/sides
				var tall: float = ring[2] if sin(angle) >= 0.0 or ring.size() < 4 else ring[3]
				points.append(centre+side*cos(angle)*float(ring[1])+up*sin(angle)*tall)
			frames.append(points)
		var along := 1.0/maxf(count-1,1)
		for i in range(count-1):
			for k in range(sides):
				var a: Vector3 = frames[i][k]
				var b: Vector3 = frames[i][(k+1)%sides]
				var c: Vector3 = frames[i+1][k]
				var d: Vector3 = frames[i+1][(k+1)%sides]
				var color: Color = paint.call((i+0.5)*along,TAU*(k+0.5)/sides)
				face(a,c,b,color)
				face(b,c,d,color)
		for k in range(sides):
			var angle := TAU*(k+0.5)/sides
			if front != null: face(front,frames[0][(k+1)%sides],frames[0][k],paint.call(0.0,angle))
			if back != null: face(back,frames[count-1][k],frames[count-1][(k+1)%sides],paint.call(1.0,angle))

	## A triangle, skipped when it has no area (a loft ring drawn to a point).
	func face(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
		if (b-a).cross(c-a).length_squared() < 1e-14: return
		tri(a,b,c,color)

	## A tapered limb from `a` to `b`: rings between the two ends, `bands` of
	## them, so a painter can bar it. `paint` is func(u, a) -> Color, as for
	## `loft`.
	func limb(a: Vector3, b: Vector3, from_radius: float, to_radius: float, paint: Callable, sides := 5, bands := 2) -> void:
		var rings := []
		for i in range(bands):
			var u := lerpf(0.16,0.84,float(i)/maxf(bands-1,1))
			var r := lerpf(from_radius,to_radius,u)
			rings.append([a.lerp(b,u),r,r])
		loft(rings,sides,paint,a,b)

	## A thin fin: a fan from `hub` whose inner part is `base` and outer band
	## `edge`, as fins clear toward their rim.
	func fin(hub: Vector3, rim: Array, base: Color, edge: Color, inner := 0.62) -> void:
		for i in range(rim.size()-1):
			var p: Vector3 = rim[i]
			var q: Vector3 = rim[i+1]
			var pi := hub.lerp(p,inner)
			var qi := hub.lerp(q,inner)
			face(hub,pi,qi,base)
			face(pi,p,q,edge)
			face(pi,q,qi,edge)

	## A flat painted patch lying on a surface: `sides` points round `centre`,
	## lifted a hair along `normal`, `across` by `along` radii, turned `spin`.
	func disc(centre: Vector3, normal: Vector3, across: float, along: float, color: Color, sides := 6, spin := 0.0) -> void:
		var n := normal.normalized()
		var t := n.cross(Vector3.FORWARD if absf(n.z) < 0.9 else Vector3.RIGHT).normalized()
		var w := n.cross(t)
		var hub := centre+n*0.0025
		var rim: Array = []
		for i in range(sides+1):
			var angle := TAU*float(i)/sides+spin
			rim.append(hub+t*cos(angle)*across+w*sin(angle)*along)
		for i in range(sides): face(hub,rim[i],rim[i+1],color)

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

## sRGB hex, turned linear as the source's THREE.Color did.
static func hex(code: String) -> Color:
	return Color.html(code).srgb_to_linear()

## A point on a loft's surface at u (0 to 1 by ring, as `loft` paints) and
## angle a round the ring, pushed `out` beyond it: [point, outward normal].
static func surface(rings: Array, u: float, a: float, out := 0.0) -> Array:
	var count := rings.size()
	var x := clampf(u,0.0,1.0)*(count-1)
	var i := mini(int(x),count-2)
	var f := x-i
	var r0: Array = rings[i]
	var r1: Array = rings[i+1]
	var from: Vector3 = r0[0]
	var to: Vector3 = r1[0]
	var axis := (to-from).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 1e-6: side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(axis).normalized()
	var across := lerpf(r0[1],r1[1],f)
	var tall := lerpf(r0[2],r1[2],f) if sin(a) >= 0.0 else lerpf(r0[3] if r0.size() > 3 else r0[2],r1[3] if r1.size() > 3 else r1[2],f)
	var normal := (side*cos(a)/maxf(across,1e-4)+up*sin(a)/maxf(tall,1e-4)).normalized()
	return [from.lerp(to,f)+side*cos(a)*across+up*sin(a)*tall+normal*out,normal]

# --- Fish -------------------------------------------------------------------

## The pond's fish. `length` nose to tail tip (m); `depth` and `width` the
## body's height and breadth as shares of it; `tail` the tail's share of the
## length and `fork` how deep its notch cuts (0 is a round paddle). `dorsal` is
## [from, to, height share] along the body (0 nose, 1 tail root); `spines`
## splits it into a perch's spiny front fin and soft back one. `hump` lifts
## the back behind the head. Colours: `back`, `flank`, `belly`, `fin`, `edge`
## for the fins' clear rims, `low` for the lower fins where they differ.
## `pattern` names a paint in `_fish_paint`; `seeds` how many patterns a
## patterned kind comes in.
const FISH_KINDS := {
	"kohaku":{"title":"Kohaku koi","length":0.46,"depth":0.25,"width":0.25,"tail":0.2,"fork":0.28,"dorsal":[0.36,0.8,0.055],"pectoral":0.085,"back":"#eeebe3","flank":"#eeebe3","belly":"#f5f3ee","fin":"#e6e2d8","edge":"#f8f6f2","patch":"#d4401c","pattern":"kohaku","seeds":3},
	"sanke":{"title":"Taisho sanke","length":0.46,"depth":0.25,"width":0.25,"tail":0.2,"fork":0.28,"dorsal":[0.36,0.8,0.055],"pectoral":0.085,"back":"#eeebe3","flank":"#eeebe3","belly":"#f5f3ee","fin":"#e6e2d8","edge":"#f8f6f2","patch":"#d4401c","ink":"#1c1b1d","pattern":"sanke","seeds":3},
	"showa":{"title":"Showa koi","length":0.46,"depth":0.25,"width":0.25,"tail":0.2,"fork":0.28,"dorsal":[0.36,0.8,0.055],"pectoral":0.085,"back":"#1c1b1d","flank":"#262426","belly":"#ece8e0","fin":"#1e1d1f","edge":"#eeebe3","patch":"#d4401c","ink":"#eeebe3","pattern":"showa","seeds":3},
	"ogon":{"title":"Yamabuki ogon","length":0.46,"depth":0.25,"width":0.25,"tail":0.2,"fork":0.28,"dorsal":[0.36,0.8,0.055],"pectoral":0.085,"back":"#d89a26","flank":"#ecbb46","belly":"#f4d27a","fin":"#e8b040","edge":"#f6dc92","pattern":"sheen"},
	"asagi":{"title":"Asagi koi","length":0.46,"depth":0.25,"width":0.25,"tail":0.2,"fork":0.28,"dorsal":[0.36,0.8,0.055],"pectoral":0.085,"back":"#4f6e84","flank":"#8aa2b0","belly":"#d8662a","fin":"#d6763a","edge":"#ecc8a4","pattern":"asagi"},
	"chagoi":{"title":"Chagoi","length":0.52,"depth":0.26,"width":0.25,"tail":0.19,"fork":0.25,"dorsal":[0.36,0.8,0.05],"pectoral":0.09,"back":"#664628","flank":"#946e44","belly":"#c29c62","fin":"#7a5a38","edge":"#a8885e","pattern":"net"},
	"carp":{"title":"Common carp","length":0.48,"depth":0.27,"width":0.19,"tail":0.21,"fork":0.35,"dorsal":[0.34,0.8,0.05],"pectoral":0.07,"back":"#403c1d","flank":"#957535","belly":"#dac68e","fin":"#5a472a","edge":"#7a6440","low":"#9a5232","pattern":"net"},
	"rudd":{"title":"Rudd","length":0.32,"depth":0.32,"width":0.13,"tail":0.25,"fork":0.5,"dorsal":[0.5,0.68,0.1],"pectoral":0.05,"back":"#42523a","flank":"#c9c5a4","belly":"#ece6cc","fin":"#cc3c22","edge":"#e0664a","pattern":"sheen"},
	"perch":{"title":"Perch","length":0.36,"depth":0.3,"width":0.14,"tail":0.22,"fork":0.35,"hump":0.35,"dorsal":[0.24,0.8,0.1],"spines":true,"pectoral":0.05,"back":"#3a4a1e","flank":"#a3a446","belly":"#e6e0c2","fin":"#8a8c4e","edge":"#b4b47a","low":"#de5626","bar":"#1e250e","pattern":"bars"},
	"tench":{"title":"Tench","length":0.42,"depth":0.26,"width":0.18,"tail":0.2,"fork":0.04,"dorsal":[0.42,0.62,0.07],"pectoral":0.07,"back":"#2e3c1e","flank":"#5e6a32","belly":"#948f52","fin":"#26301a","edge":"#3c4428","eye":"#c0381c","pattern":"plain"},
	# A rare variant (KOI_GOLDEN_CHANCE in land_life.gd), in no company: the
	# ogon's shape in a brighter, more saturated gold with a stronger ridge.
	"golden":{"title":"Golden koi","length":0.46,"depth":0.25,"width":0.25,"tail":0.2,"fork":0.28,"dorsal":[0.36,0.8,0.055],"pectoral":0.085,"back":"#f0b418","flank":"#ffd54a","belly":"#fff0a0","fin":"#ffd14e","edge":"#fff6c4","pattern":"sheen"},
	"goldfish":{"title":"Goldfish","length":0.27,"depth":0.33,"width":0.17,"tail":0.34,"fork":0.5,"dorsal":[0.32,0.72,0.08],"pectoral":0.05,"back":"#e45a10","flank":"#f07a1e","belly":"#f6a64c","fin":"#f28a34","edge":"#f8c088","pattern":"sheen"},
}
## Who shares a pond: koi, or wild fish with the odd escaped goldfish.
## [kind, weight] pairs.
const FISH_PONDS := [
	[["kohaku",1.0],["sanke",0.8],["showa",0.6],["ogon",0.55],["asagi",0.45],["chagoi",0.35]],
	[["rudd",1.0],["perch",0.8],["carp",0.55],["tench",0.45],["goldfish",0.12]],
]
## The body from nose (0) to tail root (1) in tenths: [height, width] shares.
const FISH_BODY := [[0.36,0.4],[0.72,0.78],[0.9,0.95],[0.99,1.0],[1.0,0.97],[0.94,0.88],[0.83,0.76],[0.68,0.6],[0.51,0.44],[0.36,0.31],[0.26,0.2]]
const FISH_RINGS := 16

## One pond fish of `kind`, nose along +Z and centred on its body; `seed`
## picks a patterned kind's markings.
static func fish(material: Material, kind := "kohaku", seed := 0) -> ArrayMesh:
	var spec: Dictionary = FISH_KINDS[kind]
	var b := Build.new()
	var length: float = spec.length
	var body := length*(1.0-float(spec.tail))
	var nose := length*0.42
	var tall := length*float(spec.depth)*0.5
	var wide := length*float(spec.width)*0.5
	var hump: float = spec.get("hump",0.0)
	var rings := []
	for i in range(FISH_RINGS):
		var t := float(i)/(FISH_RINGS-1)
		var x := t*10.0
		var k := mini(int(x),9)
		var shape: Array = FISH_BODY[k]
		var next: Array = FISH_BODY[k+1]
		var h := lerpf(shape[0],next[0],x-k)
		var w := lerpf(shape[1],next[1],x-k)
		# A hump lifts the back only; the belly keeps its line.
		var lift := hump*tall*exp(-pow((t-0.3)/0.22,2.0))
		rings.append([Vector3(0,0,nose-t*body),wide*w,tall*h+lift,tall*h])
	var root := nose-body
	b.loft(rings,10,_fish_paint(spec,kind,seed),Vector3(0,-tall*0.14,nose+length*0.03),Vector3(0,0,root-length*0.01))
	var fin := hex(spec.fin)
	var edge := hex(spec.edge)
	var low := hex(spec.low) if spec.has("low") else fin
	# The tail: two lobes and the notch between them.
	var tail_long := length*float(spec.tail)
	var tail_tall := tall*1.05
	var fork: float = spec.fork
	var hub := Vector3(0,0,root+0.01)
	var stem: float = rings[-1][2]
	b.fin(hub,[Vector3(0,stem*0.9,root),Vector3(0,tail_tall*0.62,root-tail_long*0.45),Vector3(0,tail_tall,root-tail_long),Vector3(0,0,root-tail_long*(1.0-fork)),Vector3(0,-tail_tall,root-tail_long),Vector3(0,-tail_tall*0.62,root-tail_long*0.45),Vector3(0,-stem*0.9,root)],fin,edge)
	# Dorsal fin along the back; a perch's is two, the front one spiny.
	var dorsal: Array = spec.dorsal
	var high := length*float(dorsal[2])
	var top := func(t: float, rise: float) -> Vector3: return (surface(rings,t,PI*0.5)[0] as Vector3)+Vector3(0,rise,0)
	if spec.get("spines",false):
		var split := lerpf(dorsal[0],dorsal[1],0.45)
		var spines: Array = [top.call(dorsal[0],0.0)]
		for i in range(6): spines.append(top.call(lerpf(dorsal[0],split,(i+0.7)/6.5),high*(1.2 if i%2 == 0 else 0.85)*(1.0-0.08*i)))
		spines.append(top.call(split,0.0))
		b.fin(top.call(lerpf(dorsal[0],split,0.5),0.0),spines,fin,hex(spec.get("bar","#1e250e")),0.5)
		var soft := lerpf(split,dorsal[1],0.1)
		b.fin(top.call(lerpf(soft,dorsal[1],0.5),0.0),[top.call(soft,0.0),top.call(lerpf(soft,dorsal[1],0.2),high*0.9),top.call(lerpf(soft,dorsal[1],0.7),high*0.7),top.call(dorsal[1],0.0)],fin,edge)
	else:
		var from: float = dorsal[0]
		var to: float = dorsal[1]
		b.fin(top.call(lerpf(from,to,0.45),0.0),[top.call(from,0.0),top.call(lerpf(from,to,0.12),high),top.call(lerpf(from,to,0.55),high*0.72),top.call(lerpf(from,to,0.95),high*0.36),top.call(to,0.0)],fin,edge)
	# Pectorals spread low from behind the gills, where they show from above;
	# pelvics under the belly; the anal fin behind them.
	var pectoral: float = spec.pectoral
	for s in [1.0,-1.0]:
		var angle := -0.55 if s > 0.0 else PI+0.55
		var base: Vector3 = surface(rings,0.2,angle)[0]
		var out := Vector3(signf(base.x),0,0)
		b.fin(base+Vector3(0,0,-pectoral*0.2),[base+Vector3(0,0.004,0.004),base+out*pectoral*0.9+Vector3(0,-pectoral*0.28,-pectoral*0.35),base+out*pectoral*0.72+Vector3(0,-pectoral*0.34,-pectoral*0.85),base+Vector3(0,-pectoral*0.04,-pectoral*0.42)],low,edge)
		var belly_side: Vector3 = surface(rings,0.5,-1.15 if s > 0.0 else PI+1.15)[0]
		var pelvic := pectoral*0.6
		b.fin(belly_side,[belly_side+Vector3(0,0,pelvic*0.3),belly_side+out*pelvic*0.45+Vector3(0,-pelvic*0.7,-pelvic*0.6),belly_side+out*pelvic*0.2+Vector3(0,-pelvic*0.5,-pelvic*1.0),belly_side+Vector3(0,0,-pelvic*0.5)],low,edge)
	var under := func(t: float, drop: float) -> Vector3: return (surface(rings,t,-PI*0.5)[0] as Vector3)-Vector3(0,drop,0)
	b.fin(under.call(0.79,0.0),[under.call(0.72,0.0),under.call(0.75,high*0.8),under.call(0.83,high*0.5),under.call(0.86,0.0)],low,edge)
	# Eyes, small and dark; a tench's are red.
	for angle in [0.32,PI-0.32]:
		var on: Array = surface(rings,0.1,angle)
		var eye := length*0.026
		var centre: Vector3 = on[0]+(on[1] as Vector3)*eye*0.35
		if spec.has("eye"):
			b.icosahedron(centre,eye,hex(spec.eye))
			b.icosahedron(centre+(on[1] as Vector3)*eye*0.7,eye*0.5,Color(0.01,0.01,0.01))
		else:
			b.icosahedron(centre,eye,Color(0.012,0.011,0.012))
	return b.commit(material)

## The tail beat reference_surface gives a fish of `kind` (`fish_wave`): the
## source's fish.js wave, fitted to this fish's length. `beat` scales the swing.
static func fish_wave(kind: String, beat := 0.7) -> Vector4:
	var length: float = FISH_KINDS[kind].length
	var fit := length/1.06
	return Vector4(0.15*fit,-0.7*fit,0.12*fit*beat,5.0/fit)

## How far a fish of `kind` at scale 1 reaches above its centre (back and
## dorsal fin), so it swims just under the surface.
static func fish_top(kind: String) -> float:
	var spec: Dictionary = FISH_KINDS[kind]
	return float(spec.length)*(float(spec.depth)*0.5*(1.0+float(spec.get("hump",0.0)))+float(spec.dorsal[2])*1.2)

## Countershaded, then marked: koi patches (hi red, sumi black), an ogon's
## bright ridge, a carp's scale net, an asagi's blue net and red belly, a
## perch's bars.
static func _fish_paint(spec: Dictionary, kind: String, seed: int) -> Callable:
	var back := hex(spec.back)
	var flank := hex(spec.flank)
	var belly := hex(spec.belly)
	var bar := hex(spec.get("bar","#1e250e"))
	var pattern: String = spec.pattern
	var blobs := _koi_blobs(pattern,kind,seed,hex(spec.get("patch","#d4401c")),hex(spec.get("ink","#1c1b1d")))
	return func(u: float, a: float) -> Color:
		var v := sin(a)
		var color := belly.lerp(flank,smoothstep(-0.8,-0.25,v)).lerp(back,smoothstep(0.2,0.75,v))
		var row := int(u*(FISH_RINGS-1))
		var column := int(fposmod(a,TAU)/TAU*10.0)
		match pattern:
			"kohaku","sanke","showa":
				for blob: Array in blobs:
					var du := (u-float(blob[0]))/float(blob[2])
					var da := angle_difference(a,float(blob[1]))/float(blob[3])
					if du*du+da*da < 1.0 and u < 0.97: color = blob[4]
			"sheen":
				if v > 0.9: color = color.lightened(0.14)
			"net":
				if (row+column)%2 == 1 and v > -0.4: color = color.darkened(0.07)
			"asagi":
				if (row+column)%2 == 1 and v > 0.0: color = color.lightened(0.08)
				if v < -0.1 or (u < 0.16 and v < 0.35): color = belly
			"bars":
				if row%2 == 0 and row >= 4 and row <= 12 and v > -0.45: color = color.lerp(bar,0.85 if v > 0.2 else 0.55)
		return color

## Koi markings: [u, angle, u radius, angle radius, colour] blobs, laid down
## in order so later ones sit on top. `seed` picks one of a few layouts.
static func _koi_blobs(pattern: String, kind: String, seed: int, patch: Color, ink: Color) -> Array:
	var blobs := []
	if pattern not in ["kohaku","sanke","showa"]: return blobs
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([kind,seed])
	# The head: a red cap, or (one layout in three) a tancho's round spot.
	if seed%3 == 2 and pattern != "showa": blobs.append([0.12,PI*0.5,0.06,0.5,patch])
	else: blobs.append([0.1,PI*0.5+rng.randf_range(-0.2,0.2),0.12,1.3,patch])
	if not (seed%3 == 2 and pattern != "showa"):
		var u := 0.3
		while u < 0.82:
			var reach := rng.randf_range(0.09,0.15)
			u += reach
			blobs.append([minf(u,0.86),PI*0.5+rng.randf_range(-0.5,0.5),reach,rng.randf_range(1.2,1.7),patch])
			u += reach+rng.randf_range(0.03,0.08)
	if pattern == "sanke":
		for i in range(rng.randi_range(4,6)): blobs.append([rng.randf_range(0.3,0.85),PI*0.5+rng.randf_range(-1.1,1.1),rng.randf_range(0.04,0.06),rng.randf_range(0.4,0.6),ink])
	elif pattern == "showa":
		for i in range(rng.randi_range(2,3)): blobs.append([rng.randf_range(0.25,0.8),PI*0.5+rng.randf_range(0.7,1.3)*(1.0 if i%2 == 0 else -1.0),rng.randf_range(0.06,0.1),rng.randf_range(0.5,0.8),ink])
	return blobs

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

# --- Frogs ------------------------------------------------------------------

## Pond frogs and a toad. `size` scales the animal, `wide` its body across,
## `legs` its hind legs' reach. Colours: `back`, `flank`, `belly`, `spot`,
## `mark` (a common frog's mask, a pool frog's stripe, a leopard frog's spot
## rims, a toad's glands and wart tips), `ridge` for the folds down each side
## of the back, `lip` along the jaw, `iris`. `pattern` names the markings.
const FROG_KINDS := {
	"common":{"title":"Common frog","size":1.0,"wide":1.0,"legs":1.0,"back":"#7a6a3a","flank":"#8c7a4a","belly":"#e2d8b4","spot":"#342a17","mark":"#3e2c1a","ridge":"#a89460","lip":"#d8caa0","iris":"#caa04c","pattern":"mask"},
	"pool":{"title":"Pool frog","size":0.95,"wide":0.95,"legs":1.08,"back":"#5b8a2c","flank":"#6c9434","belly":"#ebe7c9","spot":"#22331a","mark":"#bcc862","ridge":"#c2a954","lip":"#b8cc6c","iris":"#dab444","pattern":"stripe"},
	"leopard":{"title":"Leopard frog","size":1.0,"wide":0.92,"legs":1.12,"back":"#688046","flank":"#7a8c56","belly":"#efebdc","spot":"#232a17","mark":"#d2cb90","ridge":"#dccf9b","lip":"#e4dcb4","iris":"#c89a3c","pattern":"leopard"},
	# Rare variants (FROG_ALBINO_CHANCE, FROG_BLUE_CHANCE in land_life.gd), in no company.
	"albino":{"title":"Albino frog","size":1.0,"wide":1.0,"legs":1.0,"back":"#ecd2cc","flank":"#f2ddd6","belly":"#faf0ea","spot":"#dcb4ae","mark":"#e6c4bc","ridge":"#f6e4de","lip":"#fbeee8","iris":"#d01c2a","pattern":"mask"},
	"blue":{"title":"Blue frog","size":0.95,"wide":0.95,"legs":1.08,"back":"#2c8ee6","flank":"#4aa4f0","belly":"#d6ecfa","spot":"#1a5aa8","mark":"#8cc8f6","ridge":"#7cbcf2","lip":"#c2e2fa","iris":"#f0d24a","pattern":"stripe"},
	"toad":{"title":"Common toad","size":1.12,"wide":1.18,"legs":0.8,"back":"#86653f","flank":"#927348","belly":"#dccfae","spot":"#5a4026","mark":"#b8925e","lip":"#a88a5e","iris":"#cc7430","pattern":"warts"},
}
## Who sits round a pond: one kind mostly, sometimes another. [kind, weight].
const FROG_PONDS := [
	[["common",1.0],["toad",0.35]],
	[["pool",1.0],["common",0.3]],
	[["leopard",1.0],["pool",0.3]],
	[["toad",1.0],["common",0.45]],
]
## The body from rump to snout: [centre, half-width, half-height above,
## half-height below], sitting propped on its arms, then stretched out in a
## leap (and swimming).
const FROG_SIT := [
	[Vector3(0,0.05,-0.118),0.045,0.034,0.034],
	[Vector3(0,0.068,-0.09),0.078,0.054,0.048],
	[Vector3(0,0.093,-0.045),0.098,0.064,0.058],
	[Vector3(0,0.108,0.005),0.101,0.062,0.056],
	[Vector3(0,0.12,0.052),0.095,0.056,0.05],
	[Vector3(0,0.126,0.094),0.088,0.048,0.044],
	[Vector3(0,0.121,0.13),0.07,0.037,0.034],
	[Vector3(0,0.112,0.156),0.045,0.025,0.024],
]
const FROG_LEAP := [
	[Vector3(0,0.1,-0.132),0.042,0.03,0.03],
	[Vector3(0,0.101,-0.104),0.074,0.05,0.046],
	[Vector3(0,0.103,-0.056),0.092,0.06,0.056],
	[Vector3(0,0.106,-0.002),0.096,0.06,0.056],
	[Vector3(0,0.11,0.05),0.092,0.055,0.05],
	[Vector3(0,0.113,0.095),0.086,0.047,0.043],
	[Vector3(0,0.113,0.133),0.068,0.036,0.033],
	[Vector3(0,0.11,0.16),0.044,0.025,0.024],
]

## One frog of `kind`, facing +Z with its feet at the origin. `pose` is "sit"
## (propped on its arms, hind legs folded) or "leap" (arms swept back, hind
## legs thrown out behind); `seed` moves its spots.
static func frog(material: Material, kind := "common", pose := "sit", seed := 0) -> ArrayMesh:
	var spec: Dictionary = FROG_KINDS[kind]
	var b := Build.new()
	var wide: float = spec.wide
	var reach: float = spec.legs
	var back := hex(spec.back)
	var flank := hex(spec.flank)
	var belly := hex(spec.belly)
	var spot := hex(spec.spot)
	var mark := hex(spec.mark)
	var ridge := hex(spec.ridge) if spec.has("ridge") else back
	var lip := hex(spec.lip)
	var pattern: String = spec.pattern
	var leaping := pose == "leap"
	var rings := []
	for ring: Array in (FROG_LEAP if leaping else FROG_SIT):
		rings.append([ring[0],float(ring[1])*wide,ring[2],ring[3]])
	var skin := func(u: float, a: float) -> Color:
		var v := sin(a)
		var side := absf(cos(a))
		var color := belly.lerp(flank,smoothstep(-0.55,-0.1,v)).lerp(back,smoothstep(0.15,0.6,v))
		# The folds down each side of the back, and the jaw's pale line.
		if v > 0.5 and v < 0.95 and u > 0.15 and u < 0.8: color = color.lerp(ridge,0.5)
		if u > 0.6 and v > -0.45 and v < -0.05: color = lip
		match pattern:
			"stripe":
				if v > 0.95 and u > 0.06 and u < 0.9: color = mark
			"mask":
				if u > 0.55 and u < 0.8 and v > -0.1 and v < 0.5 and side > 0.8: color = mark
			"warts":
				if (int(u*7.0)*3+int(fposmod(a,TAU)/TAU*10.0))%3 == 0 and v > -0.2: color = color.darkened(0.14)
		return color
	var tip: Vector3 = (rings[0][0] as Vector3)+Vector3(0,-0.004,-0.018)
	var snout: Vector3 = (rings[-1][0] as Vector3)+Vector3(0,-0.006,0.017)
	b.loft(rings,10,skin,tip,snout)
	# Legs, barred on all but the toad; pale underneath.
	var foot := flank.darkened(0.12)
	var barred := pattern != "warts"
	var leg := func(u: float, a: float) -> Color:
		var color := belly.lerp(back,smoothstep(-0.4,0.3,sin(a)))
		if barred and u > 0.3 and u < 0.7 and sin(a) > -0.3: color = spot.lerp(back,0.25)
		return color
	for s in [1.0,-1.0]:
		var hip: Vector3
		var knee: Vector3
		var heel: Vector3
		var toes: Vector3
		var ahead: Vector3
		var shoulder: Vector3
		var elbow: Vector3
		var wrist: Vector3
		var fingers: Vector3
		if leaping:
			hip = Vector3(s*0.045*wide,0.098,-0.095)
			knee = hip+Vector3(s*0.04,-0.01,-0.105)*reach
			heel = knee+Vector3(s*-0.012,0.004,-0.115)*reach
			toes = heel+Vector3(s*0.008,0.0,-0.07)*reach
			ahead = Vector3(s*0.25,0,-1)
			shoulder = Vector3(s*0.058*wide,0.09,0.062)
			elbow = Vector3(s*0.084*wide,0.072,0.03)
			wrist = Vector3(s*0.072*wide,0.07,-0.022)
			fingers = Vector3(s*0.3,0,-1)
		else:
			hip = Vector3(s*0.055*wide,0.064,-0.085)
			knee = hip+Vector3(s*0.105,-0.014,0.075)*reach
			heel = knee+Vector3(s*-0.03,-0.03,-0.11)*reach
			toes = heel+Vector3(s*0.06,-0.014,0.07)*reach
			toes.y = maxf(toes.y,0.008)
			ahead = Vector3(s*0.55,0,0.83)
			shoulder = Vector3(s*0.058*wide,0.095,0.058)
			elbow = Vector3(s*0.086*wide,0.05,0.07)
			wrist = Vector3(s*0.078*wide,0.012,0.1)
			fingers = Vector3(s*0.25,0,1)
		b.limb(hip,knee,0.04,0.026,leg,6,4)
		b.limb(knee,heel,0.023,0.014,leg,5,4)
		b.limb(heel,toes,0.013,0.009,func(_u: float, _a: float) -> Color: return foot,4,2)
		_digits(b,toes,ahead.normalized(),0.058*reach,5,0.9,0.3 if pattern == "warts" else 0.6,foot)
		b.limb(shoulder,elbow,0.02,0.016,leg,5,2)
		b.limb(elbow,wrist,0.015,0.011,leg,5,2)
		_digits(b,wrist,fingers.normalized(),0.03,4,1.1,0.25,foot)
	# Eyes: a lidded bump, a gold iris and a dark pupil looking out and ahead.
	var iris := hex(spec.iris)
	for a in [1.0,PI-1.0]:
		var on: Array = surface(rings,0.72,a)
		var normal: Vector3 = on[1]
		var centre: Vector3 = (on[0] as Vector3)+normal*0.013
		b.icosahedron((on[0] as Vector3)+normal*0.003,0.03,back,0.75)
		b.icosahedron(centre,0.025,iris)
		var look := (normal+Vector3(signf(centre.x)*0.5,0,0.55)).normalized()
		b.icosahedron(centre+look*0.02,0.012,Color(0.01,0.01,0.008),0.55)
	# The eardrum behind each eye; a common frog's sits in its dark mask.
	for a in [0.28,PI-0.28]:
		var on: Array = surface(rings,0.6,a)
		if pattern == "mask": b.disc(on[0],on[1],0.024,0.034,mark,7)
		b.disc((on[0] as Vector3)+(on[1] as Vector3)*0.002,on[1],0.016,0.016,flank.darkened(0.3) if pattern != "mask" else mark.darkened(0.2),6)
	_frog_marks(b,rings,spec,kind,seed)
	return b.commit(material)

## Toes or fingers fanned from `base` round `ahead`, `spread` radians across,
## webbed `web` of the way out.
static func _digits(b: Build, base: Vector3, ahead: Vector3, length: float, count: int, spread: float, web: float, color: Color) -> void:
	var rim: Array = []
	for i in range(count):
		var angle := lerpf(-spread*0.5,spread*0.5,float(i)/(count-1))
		var toe := ahead.rotated(Vector3.UP,angle)*length*(0.8+0.25*sin(PI*float(i)/(count-1)))
		rim.append(base+toe)
		if i < count-1:
			var gap := ahead.rotated(Vector3.UP,lerpf(-spread*0.5,spread*0.5,(i+0.5)/(count-1)))
			rim.append(base+gap*length*web)
	b.fan(base,rim,color)

## Spots, rimmed spots, or warts and the glands behind a toad's eyes.
static func _frog_marks(b: Build, rings: Array, spec: Dictionary, kind: String, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([kind,seed])
	var spot := hex(spec.spot)
	var mark := hex(spec.mark)
	match str(spec.pattern):
		"mask":
			for i in range(7):
				var on: Array = surface(rings,rng.randf_range(0.08,0.58),PI*0.5+rng.randf_range(-1.1,1.1))
				b.disc(on[0],on[1],rng.randf_range(0.008,0.013),rng.randf_range(0.01,0.017),spot,5,rng.randf()*TAU)
		"stripe":
			for i in range(9):
				var a := PI*0.5+(1.0 if i%2 == 0 else -1.0)*rng.randf_range(0.45,1.25)
				var on: Array = surface(rings,rng.randf_range(0.08,0.6),a)
				b.disc(on[0],on[1],rng.randf_range(0.007,0.011),rng.randf_range(0.008,0.013),spot,5,rng.randf()*TAU)
		"leopard":
			var places := [[0.2,0.4],[0.36,-0.42],[0.52,0.4],[0.28,1.2],[0.46,-1.2],[0.24,-1.3],[0.5,1.3],[0.64,0.0]]
			for place: Array in places:
				var on: Array = surface(rings,float(place[0])+rng.randf_range(-0.03,0.03),PI*0.5+float(place[1])+rng.randf_range(-0.12,0.12))
				var r := rng.randf_range(0.013,0.017)
				b.disc(on[0],on[1],r*1.35,r*1.45,hex(spec.back).lerp(mark,0.55),7)
				b.disc((on[0] as Vector3)+(on[1] as Vector3)*0.002,on[1],r,r*1.1,spot,7)
		"warts":
			for i in range(18):
				var on: Array = surface(rings,rng.randf_range(0.04,0.66),PI*0.5+rng.randf_range(-1.35,1.35))
				var r := rng.randf_range(0.006,0.01)
				b.icosahedron((on[0] as Vector3)+(on[1] as Vector3)*r*0.05,r,mark if i%3 == 0 else spot.lerp(hex(spec.back),0.4),0.5)
			for a in [1.12,PI-1.12]:
				var front: Vector3 = surface(rings,0.62,a,0.004)[0]
				var behind: Vector3 = surface(rings,0.44,a-0.1*signf(cos(a)),0.004)[0]
				var gland := hex(spec.back).lerp(mark,0.6)
				b.limb(front,behind,0.013,0.011,func(_u: float, _a: float) -> Color: return gland,6,2)

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

## Every fish and frog this file can build, for tools/dump_life_models.gd.
static func specimens(material: Material) -> Array:
	var found := []
	for kind: String in FISH_KINDS:
		for seed in range(int(FISH_KINDS[kind].get("seeds",1))):
			found.append({"name":"%s %d" % [kind,seed],"group":"fish","mesh":fish(material,kind,seed)})
	for kind: String in FROG_KINDS:
		for pose in ["sit","leap"]:
			found.append({"name":"%s %s" % [kind,pose],"group":"frog","mesh":frog(material,kind,pose),"scale":float(FROG_KINDS[kind].size)})
	found.append({"name":"frogspawn","group":"spawn","mesh":frogspawn(material)})
	return found
