extends RefCounted
## The gothic set pieces' overgrowth (docs/design/endless-flight/spec-amber-r2.md,
## "Spec change: the ruins overgrown"): the ruin kit's wind-blown growth
## (scripts/ruin_growth.gd, shaders/ruin_growth.gdshader) laid on thick over
## the ruined nave, the belfry tower and the rose gate (scripts/ruin_kit_gothic.gd),
## the way scripts/sundered_growth.gd lays it over a flown hall, on top of the
## little the kit grows by itself.
##
## `nave`, `belfry` and `gate` dress a piece's Build once all its stone is
## laid (before `finish`): vine curtains under the vault's ribs and webbing,
## its broken edges and the flyers; long trails off the snapped ribs; ivy
## cascading down the piers, the buttresses' stages, the tower's faces and
## the gable; leaf mats on wall heads, sills and ledges; moss, tufts and mats
## low on footings and fallen stone. `far` is the cheap hint for a far copy
## (a few hanging strips and mats, no probing).
##
## Every flown opening keeps a clear core (`keep_clear`: the opening's own
## box from Gothic `openings`, a little wider, deeper for a gate through a
## wall) in the Build's `clear`, so every strand, ours and the kit's, stops
## short of it; thin strands beside it are fine (the plane parts them).
##
## `tint` (the Build's `growth_tint`) turns the growth's greens to the
## amberlands' muted dry olive and rust, for these pieces only: the shared
## growth material and every other ruin are as they were.
##
## Growth only, never solid. It draws on its own random stream, so the
## stone and the kit's own growth are as without it.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const RuinGrowth = preload("res://scripts/ruin_growth.gd")
const Sundered = preload("res://scripts/sundered_growth.gd")

## The keep-out round an opening's box: across and up (m), and in depth for
## an opening through a wall (a lane keeps its own length).
const CORE_MARGIN := 1.6
const CORE_DEPTH := 2.0

## The kit's own growth's detail on these pieces (Build `level`, set once
## ours is laid): its fine ivy and cushions are mostly the shader's now.
const KIT_LEVEL := 0.3

## Leaf sizes (RuinGrowth `strand` coarse) of what is seen near (the
## vault's curtains) and far (the piers, the tower's faces).
const COARSE_NEAR := 4.2
const COARSE_MID := 5.0
const COARSE_FAR := 5.6

## The amberlands' growth colours (sRGB), dark to light: muted dry olive,
## dusty green-grey and ochre in broad patches, a rare dull rust. The kit's
## greens map onto them by brightness (so a leaf's light and dark stay).
const OLIVE := [Color("222419"),Color("363923"),Color("4b4f2f"),Color("5f643b"),Color("727846")]
const GREY := [Color("24271f"),Color("373b30"),Color("4c5244"),Color("616856"),Color("757d69")]
const OCHRE := [Color("292416"),Color("413921"),Color("5a4e2d"),Color("706239"),Color("847545")]
const RUST := [Color("281d16"),Color("3e2f22"),Color("56412e"),Color("6b523a"),Color("7f6346")]
## The brightness (linear luminance) the kit's greens run over, and the
## patches: a noise's scale (m); ochre's share, rust's (rare).
const LUM := Vector2(0.03,0.28)
const PATCH_SCALE := 26.0
const OCHRE_SHARE := 0.25
const RUST_SHARE := 0.06

static var _gothic = null

static func _g():
	if _gothic == null: _gothic = load("res://scripts/ruin_kit_gothic.gd")
	return _gothic

## How much to grow: the game's --overgrowth= (shared with the sundered
## hall), the build's detail, a little more on a more weathered piece.
static func density(b) -> float:
	return Sundered.amount*clampf(b.level,0.0,1.0)*lerpf(0.8,1.15,b.weathered)

# --- The dressing's state -----------------------------------------------------

## One piece's dressing: its Build, a probe over its stone, its own random
## stream, the density and the tops it may hang from.
class Dress extends RefCounted:
	var b
	var probe
	var rng: RandomNumberGenerator
	var keep_rng: RandomNumberGenerator
	var d := 1.0
	var tops: Array = []
	var strands := 0
	## Triangles grown by section while `measuring` (a tool's breakdown).
	static var measuring := false
	static var tally := {}
	var _label := ""
	var _from := 0

	## Starts section `label` (the last one's triangles are counted).
	func section(label: String) -> void:
		if measuring:
			var n := 0
			for i in range(_from,b.pending.size()):
				var e: Array = b.pending[i]
				if e.size() > 5 and e[5] != null and e[0] is PackedVector3Array: n += (e[0] as PackedVector3Array).size()-2
			tally[_label] = int(tally.get(_label,0))+n
		_label = label
		_from = b.pending.size()

	func _init(build, label: String, density: float) -> void:
		b = build
		d = density
		keep_rng = b.rng
		rng = RandomNumberGenerator.new()
		rng.seed = hash([keep_rng.seed,"gothic growth",label])
		b.rng = rng
		probe = Sundered.Probe.new(b)
		# The tops growth may hang from or lie on: [polygon, area, centre, y].
		for t: Array in b.tops:
			var poly: PackedVector3Array = t[0]
			var c := Vector3.ZERO
			for q in poly: c += q
			c /= poly.size()
			tops.append([poly,float(t[1]),c,poly[0].y])

	func done() -> void:
		section("")
		b.rng = keep_rng
		b.grow = PackedFloat32Array()
		# The kit's own growth, drawn in finish (its ivy, fringes, moss
		# cushions and curtains), thinned: the stone's shader carries the
		# moss now, and ours the silhouette.
		b.level = minf(b.level,KIT_LEVEL)

# --- The openings' clear cores ----------------------------------------------

## Keeps every flown opening of piece `id` clear: its box (the piece's frame)
## into the Build's `clear`.
static func keep_clear(b, id: String, p: Dictionary) -> void:
	for o: Dictionary in _g().openings(id,int(p["seed"]),float(p["weathered"])):
		var f: Transform3D = o["frame"]
		var half: Vector3 = (o["size"] as Vector3)*0.5
		var depth := 0.6 if bool(o["lane"]) else CORE_DEPTH
		if bool(o["round"]):
			# A round opening: its circle (plus the margin) as slabs.
			var r := half.x+CORE_MARGIN
			var n := 6
			for i in range(n):
				var y0 := -r+2.0*r*i/n
				var y1 := y0+2.0*r/n
				var w := sqrt(maxf(r*r-minf(y0*y0,y1*y1) if y0*y1 > 0.0 else r*r,0.0))
				var slab := Vector3(w,(y1-y0)*0.5,half.z+depth)
				b.clear.append(box_of(f*Transform3D(Basis.IDENTITY,Vector3(0.0,(y0+y1)*0.5,0.0)),slab))
			continue
		half += Vector3(CORE_MARGIN,CORE_MARGIN,depth)
		b.clear.append(box_of(f,half))

## The AABB of the oriented box `half` big at frame `f`.
static func box_of(f: Transform3D, half: Vector3) -> AABB:
	var box := AABB(f.origin,Vector3.ZERO)
	for sx: float in [-1.0,1.0]:
		for sy: float in [-1.0,1.0]:
			for sz: float in [-1.0,1.0]:
				box = box.expand(f*Vector3(sx*half.x,sy*half.y,sz*half.z))
	return box

# --- Primitives -----------------------------------------------------------------

## The shortest `length` from `p` straight down that stops above a kept-clear
## box, so a strand ends in its own tendril rather than cut off.
static func _room(x: Dress, p: Vector3, length: float) -> float:
	var t := 0.0
	while t < length:
		if x.probe.kept_clear(p+Vector3.DOWN*t): return maxf(0.0,t-0.3)
		t += 0.3
	return length

## The underside of the stone over (x, z) between `lo` and `hi` (a little
## under it), or -1.
static func _find_under(x: Dress, px: float, pz: float, lo: float, hi: float) -> float:
	var y := lo
	while y < hi:
		if x.probe._inside(Vector3(px,y,pz)):
			var down := y
			while down > lo and x.probe._inside(Vector3(px,down-0.05,pz)): down -= 0.05
			return down-0.03
		y += 0.3
	return -1.0

## A vine curtain under the stone over `at` (x, z; found between `lo` and
## `hi`): a row of `most` strands at most along the way the underside runs,
## longest in its middle, ragged at the tips; `long` the longest strand.
static func curtain(x: Dress, at: Vector3, lo: float, hi: float, long: float, most: int, coarse: float, full := false) -> bool:
	var from := _find_under(x,at.x,at.z,lo,hi)
	if from < 0.0: return false
	var rng := x.rng
	var way := RuinGrowth._run_way(x.probe,at,from)
	var spacing := rng.randf_range(0.2,0.3)*coarse*0.34
	var count := clampi(int(round(most*rng.randf_range(0.6,1.0))),2,most)
	var facing := Vector3(-way.z,0.0,way.x)
	var shift := rng.randf_range(-0.3,0.3)*count*spacing
	var laid := false
	for i in range(count):
		var t := (i+0.5)/count
		var p := at+way*((t-0.5)*count*spacing+shift+rng.randf_range(-0.04,0.04))
		var top := RuinGrowth._underside(x.probe,p,from-0.9,from+1.2)
		if top < 0.0: continue
		var l := long*(0.45+0.55*sin(PI*t))*rng.randf_range(0.6,1.1)
		l = minf(l,top-0.3)
		var start := Vector3(p.x,top,p.z)
		l = minf(l,_room(x,start,l))
		if l < 0.7: continue
		RuinGrowth.strand(x.probe,start,l,facing,true,coarse,full)
		x.strands += 1
		laid = true
	return laid

## A row of ivy down a face from an edge of the top `top` ([polygon, area,
## centre, y]): `most` strands at most, `long` the longest, hugging the face
## under the edge (hanging free where it falls away). False if no edge of it
## has a face falling away.
static func drape(x: Dress, top: Array, long: float, most: int, coarse: float, full := false) -> bool:
	var poly: PackedVector3Array = top[0]
	var centre: Vector3 = top[2]
	var rng := x.rng
	for attempt in range(6):
		var k := rng.randi()%poly.size()
		var p0 := poly[k]
		var p1 := poly[(k+1)%poly.size()]
		var edge := p1-p0
		if edge.length() < 0.5: continue
		var out := Vector3(edge.z,0.0,-edge.x).normalized()
		if out.length() < 0.5: continue
		var mid := p0.lerp(p1,rng.randf_range(0.2,0.8))
		if out.dot(mid-centre) < 0.0: out = -out
		if x.probe._inside(mid+out*0.12+Vector3.DOWN*0.3) or x.probe._inside(mid+out*0.1+Vector3.UP*0.08): continue
		var along := edge.normalized()
		var spacing := rng.randf_range(0.2,0.3)*coarse*0.34
		var n := clampi(int(edge.length()*0.85/spacing),2,rng.randi_range(maxi(2,most/2),most))
		var laid := 0
		for j in range(n):
			var t := (j+0.5)/n
			var at := mid+along*(t-0.5)*n*spacing
			if (at-p0).dot(along) < 0.05 or (at-p1).dot(along) > -0.05: continue
			var start := at+out*0.05+Vector3.UP*0.02
			var l := minf(long*(0.45+0.55*sin(PI*t))*rng.randf_range(0.7,1.1),start.y-0.1)
			l = minf(l,_room(x,start,l))
			if l < 0.7: continue
			RuinGrowth.strand(x.probe,start,l,out,false,coarse,full)
			x.strands += 1
			laid += 1
		if laid > 0: return true
	return false

## A leaf mat: `count` big ivy clumps lying round `at` within `reach`, only
## fluttering (the kit's own leaf clumps, bigger).
static func mat(x: Dress, at: Vector3, count: int, reach: float, scale := 2.4) -> void:
	var b = x.b
	var rng := x.rng
	b.grow = RuinGrowth.attrs(0.0,0.0,Vector3.ZERO,0.0,0.35,fposmod(at.x*3.17+at.z*5.31,1.0),false,0.6)
	for j in range(count):
		var on := at+Vector3(rng.randf_range(-reach,reach),0.02,rng.randf_range(-reach,reach)*0.6)
		var size := rng.randf_range(RuinKit.IVY_LEAF.x,RuinKit.IVY_LEAF.y)*scale
		if _near_clear(x,on,size*0.6): continue
		b._leaf(on,Vector3.UP,size,0.0)
	b.grow = PackedFloat32Array()

## Whether a kept-clear box is within `r` of `p` (a clump's reach).
static func _near_clear(x: Dress, p: Vector3, r: float) -> bool:
	for o: Vector3 in [Vector3.ZERO,Vector3(r,0,0),Vector3(-r,0,0),Vector3(0,r,0),Vector3(0,0,r),Vector3(0,0,-r)]:
		if x.probe.kept_clear(p+o): return true
	return false

## A random point on the top `top`.
static func _on(x: Dress, top: Array) -> Vector3:
	var poly: PackedVector3Array = top[0]
	var centre: Vector3 = top[2]
	var k := x.rng.randi()%poly.size()
	return centre.lerp(poly[k].lerp(poly[(k+1)%poly.size()],x.rng.randf()),x.rng.randf()*0.8)+Vector3.UP*0.02

## `count` picks (with repeats) of the tops between heights `lo` and `hi` of
## at least `area` m2, the odds of each weighted by its area (capped).
static func _pick(x: Dress, lo: float, hi: float, area: float, count: int) -> Array:
	var found: Array = []
	var total := 0.0
	for t: Array in x.tops:
		var y: float = t[3]
		if y < lo or y >= hi or float(t[1]) < area: continue
		found.append(t)
		total += minf(float(t[1]),6.0)
	var out: Array = []
	if found.is_empty(): return out
	for i in range(count):
		var roll := x.rng.randf()*total
		var pick: Array = found[0]
		for t: Array in found:
			roll -= minf(float(t[1]),6.0)
			if roll <= 0.0:
				pick = t
				break
		out.append(pick)
	return out

## Ivy off `count` tops between `lo` and `hi`: rows down their edges, a mat
## on the top they come from.
static func cascades(x: Dress, lo: float, hi: float, count: int, long: Vector2, most: int, coarse: float, mats_odds := 0.7, area := 0.5, full := false) -> void:
	count = int(round(count*x.d))
	for top: Array in _pick(x,lo,hi,area,count*3):
		if count <= 0: break
		var l := x.rng.randf_range(long.x,long.y)
		if not drape(x,top,minf(l,float(top[3])),most,coarse,full): continue
		count -= 1
		if x.rng.randf() < mats_odds: mat(x,_on(x,top),x.rng.randi_range(2,4),minf(1.4,sqrt(float(top[1]))*0.45))

## Leaf mats on `count` tops between `lo` and `hi`.
static func mats(x: Dress, lo: float, hi: float, count: int, area := 0.4, clumps := Vector2i(2,4), scale := 2.4) -> void:
	count = int(round(count*x.d))
	for top: Array in _pick(x,lo,hi,area,count):
		mat(x,_on(x,top),x.rng.randi_range(clumps.x,clumps.y),minf(1.8,sqrt(float(top[1]))*0.5),scale)

## Low on footings and fallen stone: mats and standing tufts.
static func low(x: Dress, count: int, hi := 4.2) -> void:
	count = int(round(count*x.d))
	for top: Array in _pick(x,-1.0,hi,0.25,count):
		var at := _on(x,top)
		if x.probe.kept_clear(at): continue
		var reach := minf(1.2,sqrt(float(top[1]))*0.5)
		mat(x,at,x.rng.randi_range(2,4),reach,2.0)
		if x.rng.randf() < 0.7:
			x.b.tuft(at+Vector3(x.rng.randf_range(-1,1),0.0,x.rng.randf_range(-1,1))*reach*0.5,x.rng.randf_range(0.7,1.7),x.rng.randi_range(6,10))

## Tendrils trailing off the free end of a stone: `count` strands hanging
## free along `along` from `at` (the stone's underside there).
static func trail(x: Dress, at: Vector3, count: int, long: float, coarse: float, along: Vector3) -> void:
	var facing := Vector3(-along.z,0.0,along.x)
	for i in range(count):
		var p := at+along*(float(i)-count*0.5)*0.4*coarse*0.55
		var top := RuinGrowth._underside(x.probe,p,at.y-0.8,at.y+1.0)
		if top < 0.0: top = at.y
		var start := Vector3(p.x,top,p.z)
		var l := long*(0.5+0.5*sin(PI*(i+0.5)/count))*x.rng.randf_range(0.7,1.1)
		l = minf(l,_room(x,start,l))
		if l < 0.8: continue
		RuinGrowth.strand(x.probe,start,l,facing,true,coarse,true)
		x.strands += 1

## Ivy down a round pier from under its capital: strands hugging the shafts.
static func pier(x: Dress, foot: Vector3, top_y: float, radius: float, count: int, long: Vector2, coarse: float) -> void:
	var rng := x.rng
	var turn := rng.randf()*TAU
	for i in range(count):
		var a := turn+TAU*i/maxf(count,1)+rng.randf_range(-0.4,0.4)
		var out := Vector3(cos(a),0.0,sin(a))
		var start := foot+out*radius
		start.y = top_y-rng.randf_range(0.0,1.2)
		if x.probe._inside(start): continue
		var l := minf(rng.randf_range(long.x,long.y),start.y-0.2)
		l = minf(l,_room(x,start,l))
		if l < 1.0: continue
		RuinGrowth.strand(x.probe,start,l,out,false,coarse,i%2 == 0)
		x.strands += 1

# --- The nave -------------------------------------------------------------------

## Dresses the ruined nave's Build `b` (all its stone laid) from its plan `p`.
static func nave(b, p: Dictionary) -> void:
	keep_clear(b,"gothic_nave",p)
	var d := density(b)
	if d <= 0.0: return
	var g = _g()
	var bays: int = g.BAYS
	var bay: float = g.BAY
	var half_len: float = g.HALF_LEN
	var nave_half: float = g.NAVE_HALF
	var pier_x: float = g.PIER_X
	var pier_r: float = g.PIER_R
	var spring: float = g.VAULT_SPRING
	var buttress_x: float = g.BUTTRESS_X
	var x := Dress.new(b,"nave",d)
	var rng := x.rng
	var vines := RuinGrowth.vines
	if vines:
		x.section("ribs")
		# The vault's ribs: curtains under each rib standing, long trails off
		# the ones that snapped.
		var ribs: Array = p["ribs"]
		for k in range(1,bays):
			var z := half_len-k*bay
			var keep: Vector2i = ribs[k]
			for s: float in [-1.0,1.0]:
				var n := keep.x if s < 0.0 else keep.y
				if n <= 0: continue
				var reach := nave_half*(1.0-float(n)/9.0*0.85) if n < 9 else nave_half
				var spots := int(round(rng.randf_range(2.5,4.5)*d))
				for j in range(spots):
					var px := s*lerpf(nave_half-1.0,nave_half-reach+1.0,rng.randf())
					curtain(x,Vector3(px,0.0,z+rng.randf_range(-0.3,0.3)),spring-1.0,spring+22.0,rng.randf_range(3.5,9.0),7,COARSE_NEAR,true)
				if n < 9:
					# The snapped end: the furthest stone along the rib, its trails.
					var tip := -1.0
					var tx := nave_half-0.5
					while tx > 0.5:
						if _find_under(x,s*tx,z,spring-1.0,spring+22.0) > 0.0:
							tip = tx
							break
						tx -= 0.5
					if tip > 0.0:
						var ty := _find_under(x,s*tip,z,spring-1.0,spring+22.0)
						trail(x,Vector3(s*tip,ty,z),int(round(rng.randf_range(3.0,4.0)*d)),rng.randf_range(7.0,14.0),COARSE_NEAR,Vector3(1.0,0.0,0.0))
		x.section("webs")
		# The webbing and its holes: curtains under the barrel, thicker at the
		# edges of a hole (the vault broken).
		var web: Array = p["web"]
		for i in range(bays):
			if not bool(web[i]): continue
			var z0 := half_len-(i+0.5)*bay
			var plain := int(round(rng.randf_range(2.0,3.5)*d))
			var edges := int(round(rng.randf_range(2.0,3.0)*d))
			for attempt in range(60):
				if plain <= 0 and edges <= 0: break
				var px := rng.randf_range(-nave_half+1.5,nave_half-1.5)
				var pz := z0+rng.randf_range(-bay*0.4,bay*0.4)
				var under := _find_under(x,px,pz,spring-1.0,spring+22.0)
				if under < 0.0: continue
				var edge := false
				for dir: Vector2 in [Vector2(1.4,0.0),Vector2(-1.4,0.0),Vector2(0.0,1.4),Vector2(0.0,-1.4)]:
					if _find_under(x,px+dir.x,pz+dir.y,under-1.0,under+1.5) < 0.0:
						edge = true
						break
				if edge and edges > 0:
					if curtain(x,Vector3(px,0.0,pz),under-1.0,under+1.5,rng.randf_range(5.0,10.0),7,COARSE_NEAR,true): edges -= 1
				elif plain > 0 and not edge:
					if curtain(x,Vector3(px,0.0,pz),under-1.0,under+1.5,rng.randf_range(2.5,6.0),5,COARSE_NEAR): plain -= 1
		x.section("flyers")
		# The flyers: curtains under the standing ones' soffits.
		var flyers: Dictionary = p["flyers"]
		for s: int in [-1,1]:
			for k in range(1,bays):
				if not bool(flyers["%d/%d" % [s,k]]): continue
				var z := half_len-k*bay
				for j in range(int(round(rng.randf_range(1.0,2.0)*d))):
					var px := s*rng.randf_range(pier_x+2.0,buttress_x-1.5)
					curtain(x,Vector3(px,0.0,z+rng.randf_range(-0.6,0.6)),12.0,26.0,rng.randf_range(2.0,5.0),4,COARSE_NEAR)
	x.section("piers")
	# Ivy down the piers (the tall ones' shafts) from under their capitals.
	for k in range(bays+1):
		for s: float in [-1.0,1.0]:
			if rng.randf() > 0.4*d: continue
			pier(x,Vector3(s*pier_x,0.0,half_len-k*bay),spring-1.7-0.3,pier_r*1.55+0.2,rng.randi_range(1,2),Vector2(7.0,22.0),COARSE_MID)
	if vines:
		x.section("cascades")
		# Wall heads, the gables, the buttresses' stages and the flyers' backs:
		# ivy cascading down their faces, mats on them.
		cascades(x,12.0,50.0,30,Vector2(6.0,17.0),5,COARSE_MID,0.5,0.5,false)
		x.section("long")
		# The long ones off the highest broken heads.
		cascades(x,22.0,50.0,12,Vector2(10.0,22.0),5,COARSE_FAR,0.4,0.4,true)
		x.section("stages")
		# The stages and set-offs down the buttresses: shorter.
		cascades(x,3.0,12.0,6,Vector2(3.0,8.0),4,COARSE_MID,0.5,0.3,false)
	x.section("mats")
	mats(x,3.0,48.0,24,0.4,Vector2i(1,3),3.4)
	x.section("low")
	low(x,16)
	x.done()

# --- The belfry ---------------------------------------------------------------------

static func belfry(b, p: Dictionary) -> void:
	keep_clear(b,"belfry_tower",p)
	var d := density(b)
	if d <= 0.0: return
	var x := Dress.new(b,"belfry",d)
	if RuinGrowth.vines:
		x.section("head")
		# The ragged head: long trails down every face.
		cascades(x,66.0,100.0,16,Vector2(14.0,32.0),5,COARSE_FAR,0.4,0.3,true)
		x.section("upper")
		# The upper stage and the belfry's sills and string courses.
		cascades(x,46.0,66.0,8,Vector2(8.0,18.0),5,COARSE_FAR,0.5,0.3,false)
		x.section("lower")
		# The lower stages' set-offs, tracery sill, courses.
		cascades(x,14.0,46.0,16,Vector2(8.0,20.0),5,COARSE_FAR,0.5,0.3,false)
		cascades(x,2.0,14.0,4,Vector2(3.0,9.0),4,COARSE_MID,0.5,0.3,false)
	x.section("mats")
	mats(x,2.0,98.0,18,0.3,Vector2i(1,3),3.4)
	x.section("low")
	low(x,12)
	x.done()

# --- The rose gate ----------------------------------------------------------------------

static func gate(b, p: Dictionary) -> void:
	keep_clear(b,"rose_gate",p)
	var d := density(b)
	if d <= 0.0: return
	var x := Dress.new(b,"gate",d)
	if RuinGrowth.vines:
		x.section("gable")
		# The gable's edges, draped.
		cascades(x,22.0,50.0,12,Vector2(7.0,18.0),5,COARSE_MID,0.4,0.3,true)
		x.section("ring")
		# The rose's ring, the buttresses' stages and the slots' heads.
		cascades(x,6.0,22.0,6,Vector2(3.0,12.0),4,COARSE_MID,0.5,0.3,false)
	x.section("mats")
	mats(x,3.0,40.0,10,0.3,Vector2i(1,3),3.4)
	x.section("low")
	low(x,8)
	x.done()

# --- Far ------------------------------------------------------------------------------

const RuinLod = preload("res://scripts/ruin_lod.gd")
## Past this (m) a piece's growth isn't drawn (its strands are under a pixel
## by then; the stone's shader carries the moss), faded over the margin.
const FAR_GROWTH := 800.0
const FAR_MARGIN := 80.0

## A built piece's levels (scripts/ruin_lod.gd: the stone simplified, the
## growth lifted into its own "Growth" instance thinning with distance) and
## that growth dropped past FAR_GROWTH. Nothing if its mesh isn't made yet
## (a build handing its meshes to the main thread).
static func far_off(node: Node3D) -> void:
	RuinLod.add(node)
	for g: MeshInstance3D in node.find_children("Growth","MeshInstance3D",true,false):
		g.visibility_range_end = FAR_GROWTH
		g.visibility_range_end_margin = FAR_MARGIN
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## A far copy's hint (its far Build `b`, no stone to probe): a few hanging
## strips down the faces and mats on the heads, from the piece's plan;
## tinted as the near one. `id` the piece, `rng` the caller's.
static func far(id: String, b, rng: RandomNumberGenerator) -> void:
	b.growth_tint = Callable(tint)
	if Sundered.amount <= 0.0: return
	var g = _g()
	match id:
		"gothic_nave":
			var ox: float = g.PIER_X+g.WALL_D+0.15
			var hl: float = g.HALF_LEN
			for s: float in [-1.0,1.0]:
				for i in range(9):
					var z := rng.randf_range(-hl+4.0,hl-4.0)
					_far_strip(b,Vector3(s*ox,rng.randf_range(20.0,g.WALL_H),z),Vector3(s,0.0,0.0),rng.randf_range(1.2,2.4),rng.randf_range(8.0,20.0),rng)
				for i in range(4):
					_far_mat(b,Vector3(s*(g.PIER_X+rng.randf_range(-1.0,1.0)),g.WALL_H-rng.randf_range(0.0,5.0),rng.randf_range(-hl+4.0,hl-4.0)),rng)
			for f: float in [-1.0,1.0]:
				var fz: float = f*(hl+g.PIER_R*0.4+g.END_D+0.1)
				for i in range(6):
					_far_strip(b,Vector3(rng.randf_range(-12.0,12.0),rng.randf_range(24.0,34.0),fz),Vector3(0.0,0.0,f),rng.randf_range(1.2,2.4),rng.randf_range(8.0,18.0),rng)
		"belfry_tower":
			var h: float = g.TOWER_H
			var hf: float = g.TOWER_HALF+0.2
			for face in range(4):
				var turn := Basis(Vector3.UP,PI*0.5*face)
				for i in range(5):
					var at: Vector3 = turn*Vector3(rng.randf_range(-6.0,6.0),h-rng.randf_range(0.0,5.0),hf)
					_far_strip(b,at,turn*Vector3.BACK,rng.randf_range(1.5,3.0),rng.randf_range(14.0,30.0),rng)
				for sy: float in [18.0,34.0,50.0]:
					var at: Vector3 = turn*Vector3(rng.randf_range(-6.0,6.0),sy,hf+0.5)
					_far_strip(b,at,turn*Vector3.BACK,rng.randf_range(1.2,2.4),rng.randf_range(8.0,15.0),rng)
		"rose_gate":
			var hw: float = g.GATE.x
			for f: float in [-1.0,1.0]:
				for i in range(8):
					var xx := rng.randf_range(-hw+2.0,hw-2.0)
					var top := lerpf(g.GATE.z,g.GATE.y,absf(xx)/hw)-1.0
					_far_strip(b,Vector3(xx,top,f*(g.GATE.w+0.1)),Vector3(0.0,0.0,f),rng.randf_range(1.2,2.6),rng.randf_range(6.0,16.0),rng)
	b.grow = PackedFloat32Array()

static func _far_strip(b, top: Vector3, out: Vector3, w: float, l: float, rng: RandomNumberGenerator) -> void:
	if b.kept_clear(top+Vector3.DOWN*l*0.5): return
	Sundered._strip(b,top,out,w,l,rng)

static func _far_mat(b, at: Vector3, rng: RandomNumberGenerator) -> void:
	b.grow = RuinGrowth.attrs(0.0,0.0,Vector3.ZERO,0.0,0.3,rng.randf(),false,0.6)
	var r := rng.randf_range(1.2,2.2)
	b.growth_face(PackedVector3Array([at+Vector3(-r,0.05,-r*0.7),at+Vector3(r,0.05,-r*0.7),at+Vector3(r*1.1,0.05,r*0.7),at+Vector3(-r*1.1,0.05,r*0.7)]),Vector3.UP,Sundered._green(rng,0.3))
	b.grow = PackedFloat32Array()

# --- The stone's own moss ---------------------------------------------------------------

## The gothic pieces' stone: the kit's stone (its shared material's look,
## RuinKit `materials`) with the moss painted over it and its shade lifted
## (shaders/gothic_stone.gdshader, shaders/stone_moss.gdshaderinc). One
## material for all three; every other ruin keeps the shared one. Its
## knobs (`STONE_MOSS`) are the stone's: how much, the colours, the lifts.
const GOTHIC_STONE = preload("res://shaders/gothic_stone.gdshader")
const STONE_MOSS := {"moss":1.0,"moss_low":11.0,"moss_tongue":0.46,"stone_lift":1.35,"shade_lift":6.5,
	"moss_olive":Color("434b2c"),"moss_grey":Color("50584a"),"moss_ochre":Color("66603a"),
	"moss_rust":Color("57412f"),"moss_deep":Color("24291a")}
static var _stone: ShaderMaterial = null
static var _stone_key := ""

static func stone() -> ShaderMaterial:
	var shared: ShaderMaterial = RuinKit.materials().stone
	if _stone == null:
		var s := ShaderMaterial.new()
		s.shader = GOTHIC_STONE
		for k: String in STONE_MOSS: s.set_shader_parameter(k,STONE_MOSS[k])
		_stone = s
	# The shared look's knobs, again when the look changed.
	var keys := ["fill","rim","roughness_value","stone_weather"]
	var key := str(keys.map(func(k: String) -> Variant: return shared.get_shader_parameter(k)))
	if key != _stone_key:
		for k: String in keys: _stone.set_shader_parameter(k,shared.get_shader_parameter(k))
		_stone_key = key
	return _stone

# --- The colour -----------------------------------------------------------------------

## The Build's `growth_tint`: the growth's faces (RuinGrowth.Faces `g`, linear
## vertex colours) turned from green to the amberlands' dry olive and rust,
## by brightness (so the leaves' light and dark stay), rust in patches.
static func tint(g) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7141
	noise.frequency = 1.0/PATCH_SCALE
	noise.fractal_octaves = 2
	var cs: PackedColorArray = g.c
	var vs: PackedVector3Array = g.v
	for i in range(cs.size()):
		var c := cs[i]
		var t := clampf((c.get_luminance()-LUM.x)/(LUM.y-LUM.x),0.0,1.0)
		var v := vs[i]
		var grey := smoothstep(0.35,0.65,noise.get_noise_3d(v.x,v.y*0.6,v.z)*0.5+0.5)
		var ochre := smoothstep(1.0-OCHRE_SHARE-0.08,1.0-OCHRE_SHARE+0.08,noise.get_noise_3d(v.x+311.0,v.y*0.6,v.z-97.0)*0.5+0.5)
		var rust := smoothstep(1.0-RUST_SHARE-0.03,1.0-RUST_SHARE+0.03,noise.get_noise_3d(v.x-517.0,v.y*0.5+40.0,v.z+233.0)*0.5+0.5)
		var k := t*float(OLIVE.size()-1)
		var lo := int(floor(k))
		var hi := mini(lo+1,OLIVE.size()-1)
		var f := k-lo
		var out := _ramp(OLIVE,lo,hi,f).lerp(_ramp(GREY,lo,hi,f),grey)
		out = out.lerp(_ramp(OCHRE,lo,hi,f),ochre*0.8)
		out = out.lerp(_ramp(RUST,lo,hi,f),rust*0.7)
		out = out.srgb_to_linear()
		out.a = c.a
		cs[i] = out
	g.c = cs

static func _ramp(ramp: Array, lo: int, hi: int, f: float) -> Color:
	return (ramp[lo] as Color).lerp(ramp[hi],f)
