extends RefCounted
## The colonnade spine's art (studies/colonnade_spine_isle.gd): a long
## knife-edge ridge isle, an arete floating in the sky, its crest levelled
## by the builders into a processional way that climbs west in terraces to
## a temple gate on the high head; a curling, dwindling tail of fragments
## east of it, stepping down and away, tied by stepping stones and rope
## bridges. Everything in the world's frame (y up, the isle round the
## aqueduct isle's sky; its rim about TOP).
##
## The ridge: an axis along x from the head (west, X_WEST) to the tail (east,
## X_EAST), bowed a little north (`zc`). Across it `d` = z - zc(x) (+ south).
## Its height (`ground`) is a crest levelled in terraces (`crest`, each
## RISE over the next, a kit stair flight up each step against a coursed
## retaining wall), steep flanks of the ground's own rock dropping FLANK m a
## metre out from the crest's edge, a shelf cut along the north flank (the
## easy way up, climbing from the tail to the head's plaza), a lower bench
## along the south flank's east half, and rock shelves jutting out of the
## flanks (`slabs`: overhangs, the south ones a chain up to the crest).
##
## The colonnade (`colonnade`): two rows of the kit's clustered piers either
## side of the way (ROW m off the axis, BAY apart), lintels along each row
## (walked as balance beams, on clean hulls), pointed portal arches over the
## way at three stair heads (flown through), two cross lintels tying the
## rows (a loop on the lintels), some piers snapped to stubs, lintels fallen
## into the way, a pier toppled in drums; a cleft through the ridge in its
## middle (the saddle, a knife-edge) with a lintel fallen across it and
## drums wedged in it. The temple gate (`temple`): the kit's rose gable on a
## podium at the head, a stair turret either side, the cella's lancet
## walls behind, an altar on the prow past them.
##
## The tail (`fragments`, `platforms`): five fragments in a curl south and
## back west, each lower and smaller, the stones between them (Art's
## floating stones), two of the gaps hung with the game's live rope bridges
## (scripts/footbridge.gd, rope_bridge.gd) on the kit's stone anchors
## (RuinKit `bridge_anchor`); the last bridge comes back up to the south
## bench, so the tail is a loop.
##
## A family (scripts/kit_isle/motif_colonnade_spine.gd): what the ruin has lost
## takes a plan
## (`rolled`: the piers snapped, the lintels fallen, the portals' crowns,
## how much of the tail is left, which rope bridges hold), the authored
## tables below when none is given (`authored`). The ridge itself, its
## terraces and the temple are the one ridge's.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
## The plane's size (scripts/world_scale.gd): the portals and the bays the
## slalom flies out through keep their toy-era widths in wingspans
## (`opening`); the rows stand out, the crest widens with them. At
## `--plane-scale=1 --opening-ratio=1` each is its toy width.
const WorldScale = preload("res://scripts/world_scale.gd")
const Build = RuinKit.Build

const TOP := 30.0
## A kit flight's rise (8 risers): every terrace stands one over the next.
const RISE := RuinKit.STEPS*RuinKit.RISER
## The terraces' heights over TOP: the podium (the temple's), the plaza at
## the grand stair's foot, then down the way east.
const PODIUM := 8.0*RISE
const L3 := 6.0*RISE
const L2 := 5.0*RISE
const L1 := 4.0*RISE
const L0 := 3.0*RISE
## The axis: x from the head's prow to the tail's tip, its bow north.
const X_WEST := 14.0
const X_EAST := 150.0
## Past this the tail's tip breaks off (a cliff).
const TAIL_END := 147.0
const AXIS_Z := -14.0
const BOW := 4.5
## The terraces' steps (world x, the upper side west): the podium's edge
## (the grand stair), the plaza's (a flight), L2's (a flight).
const STEP_PODIUM := 46.0
const STEP_L3 := 70.0
const STEP_L2 := 90.0
## The saddle (a knife-edge between L1 and L0) and the cleft through it.
const SADDLE := Vector2(104.0,116.0)
const CLEFT := Vector3(110.0,2.6,4.5)
## The cleft's floor over TOP: over the north shelf's there, so it opens
## onto the shelf (a way between the crest and the shelf).
const CLEFT_FLOOR := 5.4
## The colonnade's rows: ROW m either side of the axis. A portal's clear
## span between its piers' shafts (2 x (ROW - ORDER)) is a flown opening:
## the toy era's 6.16 (TOY_ROW 3.4), 11.7 at the defaults, so ROW 6.17.
## WIDEN how far the rows stand out past the toy's.
const TOY_ROW := 3.4
const TOY_PORTAL := 2.0*(TOY_ROW-RuinKit.ORDER)
static var ROW: float = WorldScale.opening(TOY_PORTAL)*0.5+RuinKit.ORDER
static var WIDEN: float = ROW-TOY_ROW
## The crest's flat half width: the podium's (the temple's, kept), the
## colonnade's (the toy's 5.4, 2 m past the rows, out with them), the
## knife's.
const WC_HEAD := 7.0
static var WC: float = 5.4+WIDEN
const WC_KNIFE := 0.75
## How steeply the flanks fall (m down a m out), and the crest's lip.
const FLANK := 1.5
const FLANK_KNIFE := 1.9
const MARGIN := 0.6
## The rim, where the island's sides take over (under TOP).
const RIM := -5.0
## The shelves: [x, height over TOP] knots, west to east; their band (m).
## The south bench runs on flat to x 98, so the south chain's first slab
## is a jump-catch off its end (at ratio 1 the bench ended at 99 and the
## jump ran down the flank into the slab's side).
const SHELF_N := [Vector2(44.0,L3),Vector2(52.0,L3),Vector2(58.0,11.4),Vector2(70.0,9.0),Vector2(84.0,7.6),
	Vector2(98.0,L1-RISE),Vector2(110.0,5.0),Vector2(124.0,3.6),Vector2(138.0,2.2),Vector2(148.0,1.0)]
const SHELF_N_BAND := 3.2
const SHELF_S := [Vector2(98.0,3.2),Vector2(99.0,3.2),Vector2(112.0,2.6),Vector2(128.0,2.0),Vector2(146.0,1.0)]
const SHELF_S_BAND := 3.0
## The crest smoothed (x, height over TOP), for the flanks below the lip.
const SMOOTH := [Vector2(8.0,PODIUM),Vector2(42.0,PODIUM),Vector2(52.0,14.6),Vector2(64.0,13.2),Vector2(76.0,11.6),
	Vector2(86.0,10.6),Vector2(96.0,9.2),Vector2(104.0,L1),Vector2(110.0,7.6),Vector2(116.0,L0),Vector2(132.0,L0),Vector2(150.0,1.0)]
## The rock's facets on the flanks (m).
const ROCK_NOISE := 1.3

# --- The axis and the profile ------------------------------------------------------

static func zc(x: float) -> float:
	return AXIS_Z-BOW*sin(PI*clampf((x-X_WEST)/(X_EAST-X_WEST),0.0,1.0))

## World (x, z) of the point `d` across from the axis at `x`.
static func at(x: float, d: float) -> Vector2:
	return Vector2(x,zc(x)+d)

static func at3(x: float, d: float, y: float) -> Vector3:
	return Vector3(x,y,zc(x)+d)

## The axis's way at `x` (unit, world x z) and across it (toward +d).
static func along(x: float) -> Vector3:
	return Vector3(1.0,0.0,(zc(x+0.5)-zc(x-0.5))).normalized()

## A frame at the axis point `x`, height `y`, offset `d`: its -Z along the
## axis west (a kit stair climbs that way), X across toward -d... built so
## its +Z points east along the axis.
static func frame(x: float, d: float, y: float) -> Transform3D:
	var t := along(x)
	return Transform3D(Basis(Vector3.UP.cross(t),Vector3.UP,t),at3(x,d,y))

static func _knots(knots: Array, x: float) -> float:
	if x <= (knots[0] as Vector2).x: return (knots[0] as Vector2).y
	for i in range(knots.size()-1):
		var a: Vector2 = knots[i]
		var b: Vector2 = knots[i+1]
		if x <= b.x: return lerpf(a.y,b.y,(x-a.x)/(b.x-a.x))
	return (knots[-1] as Vector2).y

## The crest's levelled height over TOP at `x` (the terraces, the saddle
## falling east, the tail falling to its tip).
static func crest(x: float) -> float:
	if x < STEP_PODIUM: return PODIUM
	if x < STEP_L3: return L3
	if x < STEP_L2: return L2
	if x < SADDLE.x: return L1
	if x < SADDLE.y: return lerpf(L1,L0,(x-SADDLE.x)/(SADDLE.y-SADDLE.x))
	if x < 132.0: return L0
	return lerpf(L0,1.0,clampf((x-132.0)/16.0,0.0,1.0))

## The crest's flat half width at `x`.
static func wc(x: float) -> float:
	if x < STEP_PODIUM-0.5: return lerpf(2.5,WC_HEAD,smoothstep(14.0,24.0,x))
	if x < SADDLE.x+0.5: return lerpf(WC_HEAD,WC,smoothstep(STEP_PODIUM-0.5,STEP_PODIUM+2.0,x))
	if x < SADDLE.y-0.5:
		var k := minf(smoothstep(SADDLE.x+0.5,SADDLE.x+2.5,x),1.0-smoothstep(SADDLE.y-2.5,SADDLE.y-0.5,x))
		return lerpf(WC,WC_KNIFE,k)
	if x < 132.0: return WC
	return lerpf(WC,0.8,smoothstep(132.0,147.0,x))

static func flank(x: float) -> float:
	if x > SADDLE.x+1.0 and x < SADDLE.y-1.0: return FLANK_KNIFE
	return FLANK

## The cleft through the ridge at the saddle: how far it cuts down at `x`.
static func cleft(x: float) -> float:
	return CLEFT.z*clampf(1.0-absf(x-CLEFT.x)/CLEFT.y,0.0,1.0)

static var _noise: FastNoiseLite

static func _rock(x: float, z: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 4471
		_noise.frequency = 0.21
		_noise.fractal_octaves = 2
	return _noise.get_noise_2d(x,z)

## A shelf's outer edge (|d|, m) at `x` on the north (side < 0) or south,
## or -1 where there is none: laid off a steady crest width (not the
## knife's), so the shelf runs on smooth past the saddle.
static func shelf_out(x: float, side: float) -> float:
	var knots: Array = SHELF_N if side < 0.0 else SHELF_S
	if x < (knots[0] as Vector2).x or x > (knots[-1] as Vector2).x: return -1.0
	var ct := crest(x)
	var cs := maxf(_knots(SMOOTH,x),ct-0.2)
	var base := wc(x) if x < STEP_PODIUM else WC
	var u1 := maxf((maxf(ct,cs)+MARGIN-_knots(knots,x))/FLANK,0.0)
	return base+u1+(SHELF_N_BAND if side < 0.0 else SHELF_S_BAND)

static func shelf_band(side: float) -> float:
	return SHELF_N_BAND if side < 0.0 else SHELF_S_BAND

## The ground's height over TOP and which part it is ("crest", "shelf",
## "flank"), before the rock's facets: [height, part, the flat above].
static func profile(x: float, d: float) -> Array:
	var ct := crest(x)
	var cs := maxf(_knots(SMOOTH,x),ct-0.2)
	var g := flank(x)
	var u := maxf(absf(d)-wc(x),0.0)
	# The head's prow and the tail's tip fall as the flanks do.
	u = maxf(u,maxf(maxf(20.0-x,0.0)*0.9,(x-TAIL_END)*3.0))
	var f := lerpf(maxf(ct,cs),_knots(SMOOTH,x),clampf(u/3.0,0.0,1.0))+MARGIN-g*u
	var h := f
	var part := "flank"
	var flat := ct
	var out := shelf_out(x,d)
	if out > 0.0:
		var sh := _knots(SHELF_N if d < 0.0 else SHELF_S,x)
		var l := sh-g*maxf(absf(d)-out,0.0)
		if l > h:
			h = l
			part = "shelf" if absf(d) <= out else "flank"
			flat = sh
	if h >= ct:
		h = ct
		part = "crest"
		flat = ct
	var cut := cleft(x)
	if cut > 0.0 and h > CLEFT_FLOOR:
		h = maxf(h-cut,CLEFT_FLOOR)
		if part == "crest": part = "cleft"
	return [h,part,flat]

## The ground's height (world y) at world (x, z): the profile with the
## rock's facets on the flanks (none within a lip's reach of a flat).
static func ground(x: float, z: float) -> float:
	var d := z-zc(x)
	var p := profile(x,d)
	var h: float = p[0]
	if p[1] == "flank":
		var w := smoothstep(0.0,1.6,float(p[2])-h)*smoothstep(RIM-1.0,RIM+1.5,h)
		h += _rock(x,z)*ROCK_NOISE*w
	return TOP+h

## The outline (world x, z), west round the north to the east and back
## along the south: where the ground falls to RIM.
static func outline() -> Array:
	var north: Array = []
	var south: Array = []
	var x := X_WEST-12.0
	while x <= X_EAST+4.0:
		for s: float in [-1.0,1.0]:
			var d := 0.0
			if profile(x,0.0)[0] < RIM:
				break
			while d < 40.0 and float(profile(x,s*(d+0.25))[0]) >= RIM: d += 0.25
			(north if s < 0.0 else south).append(at(x,s*d))
		x += 2.0
	var ring: Array = north.duplicate()
	south.reverse()
	ring.append_array(south)
	return ring

# --- The island ---------------------------------------------------------------------

## The keel's depth under TOP along the axis (deeper under the head).
static func keel(x: float) -> float:
	return TOP-lerpf(34.0,14.0,clampf((x-X_WEST)/(X_EAST-X_WEST),0.0,1.0))

## The lines where the ground's slope breaks (the crest's lips, the
## shelves' inner and outer edges, the terraces' steps, the cleft): points
## laid along them (and a row either side) so the ground's faces fold
## there, crisp, and no face spans a lip.
static func creases() -> PackedVector2Array:
	var out := PackedVector2Array()
	var x := X_WEST-11.863
	while x < X_EAST+3.0:
		for s: float in [-1.0,1.0]:
			var w := wc(x)
			var edges: Array = [w]
			var sout := shelf_out(x,s)
			if sout > 0.0:
				edges.append(sout-shelf_band(s))
				edges.append(sout)
			else:
				# Where the flank's lerp ends (its own fold).
				edges.append(w+(maxf(crest(x),_knots(SMOOTH,x))+MARGIN-crest(x))/flank(x))
			for e: float in edges:
				for off: float in [-0.32,0.0,0.32]:
					out.append(at(x,s*(e+off)))
		x += 0.5
	for step: float in [STEP_PODIUM,STEP_L3,STEP_L2]:
		var d := -12.0+0.071
		while d < 12.0:
			for off: float in [-0.04,0.04,-0.45,0.45]: out.append(at(step+off,d))
			d += 0.4
	for off: float in [-CLEFT.y,CLEFT.y,-CLEFT.y-0.35,CLEFT.y+0.35,0.0]:
		var d := -14.0+0.033
		while d < 14.0:
			out.append(at(CLEFT.x+off,d))
			d += 0.45
	return out

## The spine's island: its top the ground (`ground`), triangulated over a
## CELL grid jittered and the creases, coloured as the game's terrain
## (Art `ground_tone`: grass, rock past the palette's rock slope, the worn
## paths), collided as one trimesh with a convex prism under each steep
## face (a ray started under a lip finds its top; a cliff is never a pit);
## its sides of hanging rock down from the rim to a keel along the axis.
const CELL := 1.05
static func spine_island(seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var raw: Array = outline()
	var ring: Array[Vector2] = Art._resample(raw,int(Art._perimeter(raw)/1.1/8.0)*8,rng)
	var poly := PackedVector2Array(ring)
	var points := PackedVector2Array(ring)
	var heights := PackedFloat32Array()
	for p in ring: heights.append(ground(p.x,p.y))
	var taken := {}
	var add := func(p: Vector2) -> void:
		if not Geometry2D.is_point_in_polygon(p,poly) or Art._edge_distance(p,poly) < 0.45: return
		var key := Vector2i(floori(p.x/0.2),floori(p.y/0.2))
		for dx in range(-1,2):
			for dz in range(-1,2):
				var other: Variant = taken.get(key+Vector2i(dx,dz))
				if other != null and (other as Vector2).distance_to(p) < 0.16: return
		taken[key] = p
		points.append(p)
		heights.append(ground(p.x,p.y))
	for p in creases(): add.call(p)
	var box := Rect2(ring[0],Vector2.ZERO)
	for p in ring: box = box.expand(p)
	var gx := box.position.x+CELL*0.5+0.113
	while gx < box.end.x:
		var gz := box.position.y+CELL*0.5+0.071
		while gz < box.end.y:
			add.call(Vector2(gx+rng.randf_range(-0.25,0.25)*CELL,gz+rng.randf_range(-0.25,0.25)*CELL))
			gz += CELL
		gx += CELL
	# A face on the flanks is rock however its facets tilt (no stray grass
	# speckled down a crag).
	var rocky := func(mid: Vector2, normal: Vector3) -> bool:
		if normal.y > 0.3 and profile(mid.x,mid.y-zc(mid.x))[1] == "flank": return true
		return KitLook.is_rock(normal)
	var built := KitLand.surface(points,heights,poly,rng,KitLook.turf(seed_value,KitLand.wear_of(paths())),rocky,PackedByteArray(),0.8)
	var node := Node3D.new()
	node.name = "Spine"
	KitLand.draw(node,built)
	node.add_child(_sides(ring,rng))
	# The prisms in bodies of their own (a body's compound runs out of
	# sub-shape ids past a few thousand).
	KitLand.bodies(node,built.faces,built.solid,false)
	node.set_meta("outline",poly)
	node.set_meta("prisms",(built.solid as Array).size())
	return node

## The spine's sides: rings from the rim down and in toward the axis, the
## rock faceted (pushed in and out), a spur hanging lower here and there,
## closed under the last ring along a keel under the axis.
static func _sides(ring: Array[Vector2], rng: RandomNumberGenerator) -> MeshInstance3D:
	var count := ring.size()
	# [toward the axis, drop (a share of rim to keel), push out, stride].
	var specs := [[0.0,0.0,0.0,1],[0.04,0.05,0.35,1],[0.14,0.14,0.4,1],[0.32,0.32,0.0,2],[0.55,0.55,0.0,4],[0.78,0.78,0.0,8],[0.93,0.95,0.0,8]]
	var rims: Array = []
	var spurs := {}
	for i in range(6): spurs[rng.randi_range(0,count/8-1)] = rng.randf_range(0.08,0.2)
	for k in range(specs.size()):
		var spec: Array = specs[k]
		var stride: int = spec[3]
		var r: Array[Vector3] = []
		for i in range(0,count,stride):
			var p: Vector2 = ring[i]
			var axis := _axis_point(p)
			var out := (p-axis).normalized() if p.distance_to(axis) > 0.01 else Vector2.ZERO
			var q := p.lerp(axis,float(spec[0])*rng.randf_range(0.9,1.1))+out*float(spec[2])*rng.randf_range(0.3,1.2)
			var rim_y := ground(p.x,p.y)-0.02
			var low := keel(p.x)
			var f: float = float(spec[1])*rng.randf_range(0.9,1.1)
			if k == 0: f = 0.0
			if stride == 8 and spurs.has(i/8): f = minf(f+float(spurs[i/8]),1.0)
			r.append(Vector3(q.x,lerpf(rim_y,low,f),q.y))
		rims.append(r)
	var rock := KitLook.RockMesh.new()
	var rim_y := PackedFloat32Array()
	for p: Vector2 in ring: rim_y.append(ground(p.x,p.y))
	for k in range(rims.size()-1):
		var upper: Array = rims[k]
		var lower: Array = rims[k+1]
		var su: int = specs[k][3]
		var sl: int = specs[k+1][3]
		var ratio := upper.size()/lower.size()
		for j in range(lower.size()):
			var l0: Vector3 = lower[j]
			var l1: Vector3 = lower[(j+1)%lower.size()]
			for s in range(ratio):
				var u0: Vector3 = upper[j*ratio+s]
				var u1: Vector3 = upper[(j*ratio+s+1)%upper.size()]
				var m := (u0+u1+l0)/3.0
				rock.add([u0,l0,u1],rim_y[((j*ratio+s)*su)%count],_out(m),rng.randf_range(0.88,1.1))
			var ue: Vector3 = upper[((j+1)*ratio)%upper.size()]
			var m2 := (ue+l0+l1)/3.0
			rock.add([ue,l0,l1],rim_y[(j*sl)%count],_out(m2),rng.randf_range(0.88,1.1))
	# The keel: the last ring closed along the axis.
	var last: Array = rims[rims.size()-1]
	var flat := PackedVector2Array()
	for p: Vector3 in last: flat.append(Vector2(p.x,p.z))
	var idx := Geometry2D.triangulate_polygon(flat)
	for t in range(0,idx.size(),3):
		var a: Vector3 = last[idx[t]]
		var b: Vector3 = last[idx[t+1]]
		var e: Vector3 = last[idx[t+2]]
		var m := (a+b+e)/3.0
		rock.add([a,b,e],ground(m.x,m.z),Vector3.DOWN,rng.randf_range(0.88,1.1))
	return rock.node("Mesh")

## The axis's nearest point to `p` (world x, z), held in from its ends so
## the prow and the tail's tip have an outward way along it.
static func _axis_point(p: Vector2) -> Vector2:
	var ax := clampf(p.x,X_WEST+12.0,X_EAST-8.0)
	return Vector2(ax,zc(ax))

static func _out(at_point: Vector3) -> Vector3:
	var o := Vector2(at_point.x,at_point.z)-_axis_point(Vector2(at_point.x,at_point.z))
	return Vector3(o.x,0.0,o.y).normalized() if o.length() > 0.01 else Vector3.BACK

# --- The worn paths -------------------------------------------------------------------

## The paths worn in the turf (world polylines): the way along the crest,
## the north shelf, the south bench (KitLand `wear_of` wears them).
static func paths() -> Array:
	var way: Array = []
	var x := 20.0
	while x <= 146.0:
		way.append(at(x,0.0))
		x += 4.0
	var shelf: Array = []
	x = 46.0
	while x <= 146.0:
		shelf.append(at(x,-(shelf_out(x,-1.0)-SHELF_N_BAND*0.55)))
		x += 4.0
	var bench: Array = []
	x = 100.0
	while x <= 145.0:
		bench.append(at(x,shelf_out(x,1.0)-SHELF_S_BAND*0.5))
		x += 5.0
	return [way,shelf,bench]

# --- The colonnade ---------------------------------------------------------------------

## The rows (ROW, at the head); the piers PIER_H to their abacus's top;
## lintels LINTEL (across, deep) on them, walked LINTEL_TOP over the
## terrace (walker-sized: the lintels are balance beams reached on foot from
## a drum and a stub, so the height under them is the toy's 3.4).
const PIER_H := 3.4
const LINTEL := Vector2(0.95,0.6)
const LINTEL_TOP := PIER_H+0.6
const WEATHERED := 0.55
## The bays the slalom flies out through (flown openings, between the
## piers' shafts, PIER_SHAFT each side of a pier's middle): the plaza's
## first bay (out through the north row; the toy era's 20/3 m pitch, 5.55
## clear) and L2's first (out through the south row; the toy's 5.5 pitch,
## 4.38 clear), OUT_PITCH and IN_PITCH pier to pier (11.66 and 9.44 at the
## defaults). The rest of each terrace is one walker bay (lintels walked;
## not flown). L1's and L0's bays (5.75, 6 m) are walker bays, kept.
const PIER_SHAFT := RuinKit.SHAFT_MAIN.x+RuinKit.SHAFT_MAIN.y
const TOY_OUT := 20.0/3.0-2.0*PIER_SHAFT
const TOY_IN := 5.5-2.0*PIER_SHAFT
static var OUT_PITCH: float = WorldScale.opening(TOY_OUT)+2.0*PIER_SHAFT
static var IN_PITCH: float = WorldScale.opening(TOY_IN)+2.0*PIER_SHAFT
## The pier lines: [world x, terrace height over TOP (-1: the tail's
## falling crest), kind] ("" a plain line, "portal" a pointed arch over the
## way on its two piers, "cross" a lintel across the way tying the rows).
## The plaza's flown bay is 0-1, L2's 3-4.
static var LINES: Array = [
	[47.5,L3,""],[47.5+OUT_PITCH,L3,""],[67.5,L3,"portal"],
	[71.5,L2,""],[71.5+IN_PITCH,L2,"cross"],[88.0,L2,"portal"],
	[91.5,L1,""],[97.25,L1,""],[103.0,L1,""],
	[117.5,L0,"portal"],[123.5,L0,"cross"],[129.5,L0,""],
	[135.5,-1.0,""],
]
## Piers not standing whole: "line index,side" (-1 north, 1 south) -> the
## stub's height (0: gone, toppled: TOPPLED's south pier).
const STUBS := {"7,1":0.0,"8,1":2.2,"12,-1":1.2,"12,1":2.0}
const TOPPLED := 7
## Lintels fallen ("line index of their west end,side"): they lie in the way.
const FALLEN := ["1,1","4,-1","10,-1"]
## Portal arches: line index -> voussoirs lost from the crown.
const PORTAL_LOST := {2:0,5:3,9:1}
## The ways up onto the lintels from the way: a drum lying in the way and a
## broken pier's stub beside the row ([world x, side]).
const STACKS := [[126.5,1.0],[100.1,-1.0]]
const STUB_TOP := LINTEL_TOP-1.35
const DRUM_TOP := 1.05

static func line_y(i: int) -> float:
	var y: float = LINES[i][1]
	if y < 0.0: return crest(float(LINES[i][0]))
	return y

# --- The plan ---------------------------------------------------------------------

static var _authored: Dictionary = {}
## The authored plan: {stubs (as STUBS), fallen (as FALLEN), portal_lost
## (as PORTAL_LOST), tail (fragments left, of FRAGMENTS), bridges (each of
## `bridge_ends` holding or snapped)}.
static func authored() -> Dictionary:
	if _authored.is_empty():
		_authored = {"stubs":STUBS,"fallen":FALLEN,"portal_lost":PORTAL_LOST,"tail":FRAGMENTS.size(),"bridges":[true,true]}
	return _authored

static func _p(p: Dictionary) -> Dictionary:
	return authored() if p.is_empty() else p

## The lines whose piers may snap: plain ones (a portal's carry its arch, a
## cross line's its lintel), on a terrace.
static func stub_lines() -> Array:
	var out: Array = []
	for i in range(LINES.size()):
		if LINES[i][2] == "" and float(LINES[i][1]) >= 0.0: out.append(i)
	return out

## Whether the lintel from line `i` on `side` may lie fallen: its piers
## whole on one terrace, and no way up (STACKS) stands where it would lie.
static func may_fall(i: int, side: float, p := {}) -> bool:
	if i < 0 or i >= LINES.size()-1: return false
	if float(LINES[i][1]) < 0.0 or float(LINES[i][1]) != float(LINES[i+1][1]): return false
	if pier_height(i,side,p) < INF or pier_height(i+1,side,p) < INF: return false
	for st: Array in STACKS:
		if float(st[1]) == side and float(st[0]) > float(LINES[i][0]) and float(st[0]) < float(LINES[i+1][0]): return false
	return true

## A plan rolled from `seed_value` at `collapse` (0 whole to 1 as fallen as
## it gets; the authored is 0.5), `tail` fragments left and `bridges`
## ("intact", "one" snapped, "both" snapped): round(collapse x SNAP) piers
## snapped to stubs, as many lintels fallen, each portal's crown losing up
## to as many voussoirs (at most LOST_MOST). TOPPLED's pier is always down.
const SNAP := 6
const LOST_MOST := 4
static func rolled(seed_value: int, collapse: float, tail: int, bridges: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*6151+29
	var many := roundi(collapse*SNAP)
	var stubs := {"%d,1" % TOPPLED:0.0}
	var piers: Array = []
	for i: int in stub_lines():
		for side: int in [-1,1]:
			if not stubs.has("%d,%d" % [i,side]): piers.append("%d,%d" % [i,side])
	_shuffle(piers,rng)
	for k in range(mini(many,piers.size())): stubs[piers[k]] = snappedf(rng.randf_range(1.0,2.6),0.1)
	var p := {"stubs":stubs,"fallen":[],"portal_lost":{},"tail":clampi(tail,1,FRAGMENTS.size()),"bridges":[true,true]}
	var spans: Array = []
	for i in range(LINES.size()-1):
		for side: int in [-1,1]:
			if may_fall(i,side,p): spans.append("%d,%d" % [i,side])
	_shuffle(spans,rng)
	p.fallen = spans.slice(0,mini(many,spans.size()))
	for i in range(LINES.size()):
		if LINES[i][2] == "portal": p.portal_lost[i] = rng.randi_range(0,mini(many,LOST_MOST))
	match bridges:
		"one": p.bridges[rng.randi_range(0,1)] = false
		"both": p.bridges = [false,false]
	return p

static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size()):
		var j := rng.randi_range(i,list.size()-1)
		var t: Variant = list[i]
		list[i] = list[j]
		list[j] = t

## The pier on line `i`, `side`: INF whole, else its stub's height (0 gone).
static func pier_height(i: int, side: float, p := {}) -> float:
	var key := "%d,%d" % [i,int(side)]
	var stubs: Dictionary = _p(p).stubs
	if stubs.has(key): return float(stubs[key])
	return INF

static func _run_on(i: int, side: float, p := {}) -> bool:
	if i < 0 or i >= LINES.size()-1: return false
	if float(LINES[i][1]) < 0.0 or float(LINES[i][1]) != float(LINES[i+1][1]): return false
	if pier_height(i,side,p) < INF or pier_height(i+1,side,p) < INF: return false
	return not (_p(p).fallen as Array).has("%d,%d" % [i,int(side)])

## Every lintel standing: {a, b (world: its top's middle line's ends), side
## (0 a cross lintel), top (world y), line}. Between consecutive whole
## piers on one terrace; at a run's open end it reaches on over the
## abacus; at a portal it stops at the arch's foot.
static func lintels(p := {}) -> Array:
	var out: Array = []
	for i in range(LINES.size()-1):
		var j := i+1
		for side: float in [-1.0,1.0]:
			if not _run_on(i,side,p): continue
			var xa: float = LINES[i][0]
			var xb: float = LINES[j][0]
			var top := TOP+line_y(i)+LINTEL_TOP
			if LINES[i][2] == "portal": xa += 0.6
			elif not _run_on(i-1,side,p): xa -= 0.6
			if LINES[j][2] == "portal": xb -= 0.6
			elif not _run_on(j,side,p): xb += 0.6
			out.append({"a":at3(xa,side*ROW,top),"b":at3(xb,side*ROW,top),"side":side,"top":top,"line":i})
	for i in range(LINES.size()):
		if LINES[i][2] != "cross": continue
		var x: float = LINES[i][0]
		var top := TOP+line_y(i)+LINTEL_TOP
		out.append({"a":at3(x,-ROW-0.3,top),"b":at3(x,ROW+0.3,top),"side":0.0,"top":top,"line":i})
	return out

## A stone laid from `a` to `e` (its top's middle line, world), `size`
## (across, deep), drawn worn; walked on a clean true hull.
static func _beam(b: Build, a: Vector3, e: Vector3, size: Vector2, walk := true, collide := false) -> void:
	var way := e-a
	var length := way.length()
	var x := way/length
	var z := x.cross(Vector3.UP).normalized()
	var y := z.cross(x).normalized()
	var pose := Transform3D(Basis(x,y,z),(a+e)*0.5-y*size.y*0.5)
	var half := Vector3(length*0.5,size.y*0.5,size.x*0.5)
	b.lean = true
	b.solid(RuinKit._box(b,half-Vector3(0.01,0.0,0.0)),pose,RuinKit._stone(b,1.03),collide,true,[],-1,1.0)
	b.lean = false
	if walk: RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)])

## A drum lying along `way` (world, flat), its top at `top`, middle at `p`
## (world x, z): a clustered drum on its side, walked on a clean box.
static func _lying_drum(b: Build, p: Vector2, top: float, way: Vector3, length := 1.1) -> void:
	var r := 0.56
	var y := Vector3(way.x,0.0,way.z).normalized()
	var x := Vector3.UP.cross(y).normalized()
	var mid := Vector3(p.x,top-r,p.y)
	RuinKit._drum_cluster(b,Transform3D(Basis(x,y,x.cross(y)),mid-y*length*0.5),length,[])
	var pose := Transform3D(Basis(x,Vector3.UP,x.cross(Vector3.UP)),mid)
	RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,r*0.75),Plane(Vector3.LEFT,r*0.75),Plane(Vector3.UP,r),Plane(Vector3.DOWN,r),Plane(Vector3.BACK,length*0.5),Plane(Vector3.FORWARD,length*0.5)])

## The colonnade along the crest, one Build (one mesh, one body). Meta:
## "lintels" (as `lintels`), "portals" [{x, y (the springing), crown}],
## "stubs" [{at (top middle, world)}], "drums" [{at}], "wedged" (the
## cleft's drums' tops), "cleft_beam" {a, b}.
## `breakable` (the Olmec's destruction, scripts/kit_isle/colonnade_breaks.gd):
## the piers not under a
## portal and every standing lintel are left out of the one Build, for the
## breaks to stand each on its own (meta "breakable": {piers [{line, side,
## frame, height}], lintels (as `lintels`)}).
## Round 2: the portals too, their piers among
## the piers (`portal` their line) and their rings left out (meta
## "breakable" "portals" [{line, frame, h, lost, lost_side}]).
static func colonnade(seed_value: int, p := {}, breakable := false) -> Node3D:
	p = _p(p)
	var b := Build.new(seed_value,WEATHERED,"Colonnade")
	b.settle = 0.5
	var stubs: Array = []
	var drums: Array = []
	var loose: Array = []
	var rings: Array = []
	for i in range(LINES.size()):
		var x: float = LINES[i][0]
		var y := TOP+line_y(i)
		for side: float in [-1.0,1.0]:
			var hgt := pier_height(i,side,p)
			if hgt <= 0.0: continue
			var f := frame(x,side*ROW,y)
			f.basis = f.basis*Basis(Vector3.UP,b.rng.randf_range(-0.2,0.2))
			if breakable: loose.append({"line":i,"side":side,"frame":f,"height":hgt,"portal":LINES[i][2] == "portal"})
			else: RuinKit._pier(b,f,PIER_H,hgt)
			if hgt < INF: stubs.append({"at":at3(x,side*ROW,y+hgt)})
		if LINES[i][2] == "portal":
			var h := ROW-RuinKit.ORDER
			var f := frame(x,0.0,y)
			# No hood mould: with no wall behind it a hood stands proud of
			# the ring's face, a loose-looking slab where the ring settles.
			if breakable: rings.append({"line":i,"frame":f,"h":h,"lost":int(p.portal_lost[i]),"lost_side":-1.0 if i%2 == 0 else 1.0})
			else: RuinKit._arch_ring(b,f,0.0,PIER_H,h,2.0*h,RuinKit.ARCH_DEPTH*0.5,false,int(p.portal_lost[i]),-1.0 if i%2 == 0 else 1.0)
	if not breakable:
		for l: Dictionary in lintels(p): _beam(b,l.a,l.b,LINTEL)
	# Fallen lintels: lying in the way beside their row, broken in two.
	for key: String in p.fallen:
		var i := int(key.get_slice(",",0))
		var side := float(key.get_slice(",",1))
		var xa: float = float(LINES[i][0])+0.4
		var xb: float = float(LINES[i+1][0])-0.4
		var y := TOP+line_y(i)
		var mid := (xa+xb)*0.5+b.rng.randf_range(-0.5,0.5)
		var d := side*(ROW-1.5)
		for part: Array in [[xa,mid-0.15,0.12],[mid+0.15,xb,-0.2]]:
			var a := at3(float(part[0]),d+float(part[2]),y+LINTEL.y)
			var e := at3(float(part[1]),d-float(part[2])*0.6,y+LINTEL.y-0.08)
			_beam(b,a,e,LINTEL,true,false)
	# The pier toppled across the way at L1, south: its drums in a line, its
	# capital rolled further.
	var tx: float = LINES[TOPPLED][0]
	for k in range(3):
		var q := at(tx+b.rng.randf_range(-0.25,0.25)+k*0.15,ROW-0.5-k*1.15)
		_lying_drum(b,q,TOP+line_y(TOPPLED)+DRUM_TOP-k*0.04,along(tx),1.0)
		drums.append({"at":Vector3(q.x,TOP+line_y(TOPPLED)+DRUM_TOP,q.y)})
	RuinKit._capital(b,Transform3D(Basis(Vector3.UP,0.4)*Basis(Vector3.RIGHT,1.4),at3(tx+0.8,-ROW+1.9,TOP+line_y(TOPPLED)+0.55)))
	# The ways up onto the lintels: a drum lying in the way, a broken pier's
	# stub beside the row.
	for s: Array in STACKS:
		var x: float = s[0]
		var side: float = s[1]
		var y := TOP+crest(x)
		var stub_d := side*(ROW-1.5)
		var f := frame(x,stub_d,y)
		RuinKit._pier(b,f,PIER_H,STUB_TOP)
		RuinKit._walk_hull(b,f,RuinKit._prism(8,0.5,0.5,STUB_TOP-0.4,STUB_TOP,PI/8.0))
		stubs.append({"at":at3(x,stub_d,y+STUB_TOP)})
		var dp := at(x,side*(ROW-2.8))
		_lying_drum(b,dp,y+DRUM_TOP,along(x),1.3)
		drums.append({"at":Vector3(dp.x,y+DRUM_TOP,dp.y)})
	# The cleft at the saddle: a lintel fallen across it (a balance beam),
	# two drums wedged lower in it.
	var ca := at3(CLEFT.x-CLEFT.y-0.7,0.15,0.0)
	ca.y = ground(ca.x,ca.z)+0.32
	var cb := at3(CLEFT.x+CLEFT.y+0.7,-0.1,0.0)
	cb.y = ground(cb.x,cb.z)+0.32
	_beam(b,ca,cb,Vector2(LINTEL.x,0.55))
	var wedged: Array = []
	for k in range(2):
		var x := CLEFT.x+(-0.6 if k == 0 else 0.7)
		var top := TOP+CLEFT_FLOOR+1.1
		var q := at(x,0.6-1.2*k)
		_lying_drum(b,q,top,Vector3(0.0,0.0,1.0),1.6)
		wedged.append(Vector3(q.x,top,q.y))
	var node := b.finish()
	var portals: Array = []
	for i in range(LINES.size()):
		if LINES[i][2] == "portal":
			var h := ROW-RuinKit.ORDER
			portals.append({"x":float(LINES[i][0]),"y":TOP+line_y(i)+PIER_H,"crown":TOP+line_y(i)+PIER_H+RuinKit._rise(h,2.0*h)})
	node.set_meta("lintels",lintels(p))
	node.set_meta("portals",portals)
	node.set_meta("stubs",stubs)
	node.set_meta("drums",drums)
	node.set_meta("wedged",wedged)
	node.set_meta("cleft_beam",{"a":ca,"b":cb})
	if breakable: node.set_meta("breakable",{"piers":loose,"lintels":lintels(p),"portals":rings})
	return node

# --- The terraces' steps -----------------------------------------------------------------

## The steps between the terraces: [world x of the wall's face, the upper
## height, the lower (over TOP), the stair]. A coursed retaining wall
## across the crest either side of its stair, the stair on the lower
## terrace climbing west to the wall's top.
const STEPS := [[STEP_PODIUM,PODIUM,L3,"grand"],[STEP_L3,L3,L2,"flight"],[STEP_L2,L2,L1,"flight"]]
const GRAND_RUN := 2.0*(RuinKit.GRAND_STEPS-1)*RuinKit.GRAND_TREAD+RuinKit.GRAND_LANDING+RuinKit.LANDING
const KIT_RUN := (RuinKit.STEPS-1)*RuinKit.TREAD+RuinKit.LANDING

## The stair at step `k`: its frame in the world (the kit's: its run
## centred, climbing toward -Z, west).
static func stair_frame(k: int) -> Transform3D:
	var s: Array = STEPS[k]
	var run: float = GRAND_RUN if s[3] == "grand" else KIT_RUN
	return frame(float(s[0])+run*0.5,0.0,TOP+float(s[2]))

static func step_walls(seed_value: int) -> Node3D:
	var b := Build.new(seed_value,0.4,"StepWalls")
	# Loose stones left resting on nothing have fallen (RuinKit Build `drop_loose`).
	b.drop_floating = true
	b.drop_loose = true
	for k in range(STEPS.size()):
		var s: Array = STEPS[k]
		var x: float = s[0]
		var lower := TOP+float(s[2])
		var high := float(s[1])-float(s[2])
		var gap: float = RuinKit.GRAND_WIDTH*0.5+RuinKit.CHEEK.x if s[3] == "grand" else RuinKit.STAIR_WIDTH*0.5+RuinKit.CHEEK.x
		var reach := wc(x-1.0)+1.2
		var wall_top := func(_x: float) -> float: return high
		for run: Vector2 in [Vector2(-reach,-gap-0.02),Vector2(gap+0.02,reach)]:
			var mid := (run.x+run.y)*0.5
			var half := (run.y-run.x)*0.5
			var f := frame(x+0.05,0.0,lower)
			RuinKit._courses(b,Transform3D(f.basis,f.origin+f.basis.x*mid),-half,half,-3.2,wall_top,0.3,Callable(),0.5,true)
	return b.finish()

# --- The temple gate ---------------------------------------------------------------------

const GATE_X := 43.4
const TURRET_D := 6.0
## The cella's lancet walls: [world x, d].
const CELLA := [[33.6,-4.6],[40.4,-4.6],[40.4,4.6]]
const ALTAR_X := 25.5

## The temple on the podium: the kit's rose gable as its gate, facing east
## down the way; a stair turret either side; the cella's lancet walls
## behind (one side fallen); floor slabs; the altar on the prow. The kit's
## pieces, colliding as built. Meta "gate" (world), "turrets"; each turret
## and lancet wall "kit" [id, seed, wear] (the Olmec's breaks build it again
## cut: scripts/kit_isle/colonnade_breaks.gd).
static func temple(seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Temple"
	var y := TOP+PODIUM
	var gate: Node3D = RuinKit.piece("rose_gable",seed_value,0.45)
	gate.transform = frame(GATE_X,0.0,y)
	root.add_child(gate)
	var turrets: Array = []
	for side: float in [-1.0,1.0]:
		var t: Node3D = RuinKit.piece("turret",seed_value+(1 if side < 0.0 else 2),0.35 if side < 0.0 else 0.7)
		t.set_meta("kit",["turret",seed_value+(1 if side < 0.0 else 2),0.35 if side < 0.0 else 0.7])
		var f := frame(GATE_X-0.8,side*TURRET_D,y)
		t.transform = Transform3D(f.basis*Basis(Vector3.UP,PI*0.5*side),f.origin)
		root.add_child(t)
		turrets.append(f.origin)
	for k in range(CELLA.size()):
		var c: Array = CELLA[k]
		var w: Node3D = RuinKit.piece("lancet_wall",seed_value+3+k,0.5+0.15*k)
		w.set_meta("kit",["lancet_wall",seed_value+3+k,0.5+0.15*k])
		var f := frame(float(c[0]),float(c[1]),y)
		var face := Basis(Vector3.UP,PI*0.5) if float(c[1]) < 0.0 else Basis(Vector3.UP,-PI*0.5)
		w.transform = Transform3D(f.basis*face,f.origin)
		root.add_child(w)
	var floor_piece: Node3D = RuinKit.piece("floor",seed_value+7,0.6)
	floor_piece.transform = frame(37.0,0.0,y)
	root.add_child(floor_piece)
	var altar: Node3D = RuinKit.piece("tomb_chest",seed_value+8,0.5)
	altar.transform = frame(ALTAR_X,0.0,y)
	root.add_child(altar)
	root.set_meta("gate",at3(GATE_X,0.0,y))
	root.set_meta("turrets",turrets)
	return root

# --- Shelves jutting from the flanks, the tail's fragments --------------------------------

## Rock shelves jutting out of the flanks (overhangs: each a little island
## of the same ground and rock, its top flat): [name, world x, d, radius,
## top over TOP]. The south three are a way up from the bench's west end to the crest
## (each a jump-catch); the pulpit hangs off the podium's south flank (a
## vista dropped onto); the balcony under the north shelf.
## The south three and the balcony stand out with the crest (WIDEN).
static var SLABS: Array = [
	["south_1",97.0,9.9+WIDEN,1.8,4.55],
	["south_2",94.4,9.0+WIDEN,1.7,5.9],
	["south_3",91.9,8.1+WIDEN,1.6,7.25],
	["pulpit",33.0,11.2,2.6,15.6],
	["balcony",63.0,-12.2-WIDEN,2.4,8.6],
]
## The tail's fragments, in the curl's order: [name, world x, z, radius,
## top over TOP].
const FRAGMENTS := [
	["frag_1",157.0,-10.0,4.4,0.8],
	["frag_2",164.0,-0.5,3.8,0.0],
	["frag_3",159.0,14.0,3.4,-0.8],
	["frag_4",145.5,18.5,2.8,-1.6],
	["frag_5",134.5,12.0,2.3,-2.4],
]

static func slab(name: String, p := {}) -> Array:
	for s: Array in SLABS+fragments(p):
		if s[0] == name: return s
	return []

## The tail's fragments left (the first `tail` of the curl).
static func fragments(p := {}) -> Array:
	return FRAGMENTS.slice(0,int(_p(p).tail))

## A slab's or fragment's middle (world x, z).
static func slab_at(s: Array) -> Vector2:
	if FRAGMENTS.has(s): return Vector2(float(s[1]),float(s[2]))
	return at(float(s[1]),float(s[2]))

const LAND_SOLID := 2.2

static func lands(seed_value: int, p := {}) -> Array:
	var out: Array = []
	var k := 0
	for s: Array in SLABS+fragments(p):
		k += 1
		var c := slab_at(s)
		var top := TOP+float(s[4])
		var flat := func(_x: float, _z: float) -> float: return top
		var depth := 4.0+float(s[3])*(2.2 if FRAGMENTS.has(s) else 1.2)
		var node := Art.island(Art.blob(c,float(s[3]),seed_value+k),depth,seed_value+k,flat,top)
		node.name = str(s[0])
		# Solid under its top (its rim a wall, caught as a ledge; never
		# passed into from the side): the outline's hull down LAND_SOLID m.
		var hull := PackedVector3Array()
		for q: Vector2 in (node.get_meta("outline") as PackedVector2Array):
			hull.append(Vector3(q.x,top-0.01,q.y))
			hull.append(Vector3(c.x+(q.x-c.x)*0.7,top-LAND_SOLID,c.y+(q.y-c.y)*0.7))
		var solid := ConvexPolygonShape3D.new()
		solid.points = hull
		var held := CollisionShape3D.new()
		held.shape = solid
		node.get_node("Body").add_child(held)
		out.append(node)
	return out

# --- Stepping stones and the rope bridges -------------------------------------------------

## The tail's tip on the crest (world): where the chain to the first
## fragment begins.
static func tail_tip() -> Vector3:
	var x := TAIL_END-0.4
	return Vector3(x,ground(x,zc(x)),zc(x))

## The point of fragment `name` toward `toward` (world), `in_by` m in from
## its rim, on its top.
static func edge(name: String, toward: Vector3, in_by := 0.9) -> Vector3:
	var s := slab(name)
	var c := slab_at(s)
	var way := (Vector2(toward.x,toward.z)-c).normalized()
	var p := c+way*(float(s[3])*0.8-in_by)
	return Vector3(p.x,TOP+float(s[4]),p.y)

## The south bench's walk line at `x` (world, on the ground).
static func bench_point(x: float) -> Vector3:
	var p := at(x,shelf_out(x,1.0)-SHELF_S_BAND*0.45)
	return Vector3(p.x,ground(p.x,p.y),p.y)

## The north shelf's walk line at `x` (world, on the ground).
static func shelf_point(x: float) -> Vector3:
	var p := at(x,-(shelf_out(x,-1.0)-SHELF_N_BAND*0.5))
	return Vector3(p.x,ground(p.x,p.y),p.y)

## The rope bridges' ends on the ground (world): frag_2 to frag_3; frag_5
## back up to the south bench (each while its fragments are left).
static func bridge_ends(p := {}) -> Array:
	var tail := int(_p(p).tail)
	var out: Array = []
	if tail >= 3:
		var f2 := slab_at(slab("frag_2"))
		var f3 := slab_at(slab("frag_3"))
		out.append([edge("frag_2",Vector3(f3.x,0.0,f3.y),0.6),edge("frag_3",Vector3(f2.x,0.0,f2.y),0.6)])
	if tail >= 5:
		var bench := bench_point(131.0)
		out.append([edge("frag_5",bench,0.5),bench])
	return out

## Each of `bridge_ends`' bridges holding (false: snapped, its anchors
## standing over the gap).
static func bridges_held(p := {}) -> Array:
	p = _p(p)
	var out: Array = []
	if int(p.tail) >= 3:
		out.append(bool(p.bridges[0]))
	if int(p.tail) >= 5:
		out.append(bool(p.bridges[1]))
	return out

## The floating stones (Art `floating_stones` builds them from these):
## {name, at (its
## top's middle), size, yaw, kind, chain}, laid evenly across each gap.
static func platforms(p := {}) -> Array:
	var tail := int(_p(p).tail)
	var at := func(k: int) -> Vector2: return slab_at(FRAGMENTS[k])
	var rim := func(name: String, toward: Vector2) -> Vector3:
		return edge(name,Vector3(toward.x,0.0,toward.y),-0.3*float(slab(name)[3]))
	var tip := tail_tip()
	var chains := [["tip",tip,rim.call("frag_1",Vector2(tip.x,tip.z))]]
	if tail >= 2: chains.append(["f12",rim.call("frag_1",at.call(1)),rim.call("frag_2",at.call(0))])
	if tail >= 4: chains.append(["f34",rim.call("frag_3",at.call(3)),rim.call("frag_4",at.call(2))])
	if tail >= 5: chains.append(["f45",rim.call("frag_4",at.call(4)),rim.call("frag_5",at.call(3))])
	var out: Array = []
	for c: Array in chains:
		var a: Vector3 = c[1]
		var e: Vector3 = c[2]
		var n := maxi(1,int(Vector2(e.x-a.x,e.z-a.z).length()/2.9))
		var way := Vector2(e.x-a.x,e.z-a.z)
		for k in range(n):
			var q := a.lerp(e,float(k+1)/(n+1))
			out.append({"name":"%s_%d" % [c[0],k+1],"at":q+Vector3(0.0,0.12*(k%2),0.0),"size":Vector3(1.9,0.7,1.7),
				"yaw":atan2(-way.y,way.x)+0.3*float(k%2*2-1),"kind":"block","chain":str(c[0])})
	return out

## The rope bridges' anchors (RuinKit `bridge_anchor`), one at each end,
## facing out over the gap.
static func anchors(seed_value: int, p := {}) -> Node3D:
	var root := Node3D.new()
	root.name = "Anchors"
	var k := 0
	for ends: Array in bridge_ends(p):
		for e in range(2):
			var here: Vector3 = ends[e]
			var there: Vector3 = ends[1-e]
			var way := Vector3(there.x-here.x,0.0,there.z-here.z).normalized()
			var piece: Node3D = RuinKit.bridge_anchor(seed_value+k,WEATHERED,Footbridge.WIDTH)
			piece.transform = Transform3D(Basis(way.cross(Vector3.UP).normalized()*-1.0,Vector3.UP,way),here)
			root.add_child(piece)
			k += 1
	return root

# --- The plane's line ---------------------------------------------------------------------

## The tokens for the plane (the sky collectibles', studies/
## colonnade_spine_isle_sky.gd): [line id, category, kind, points (world)].
## The slalom from the gate east down the colonnade: out under the north
## row's lintels between two piers, back in through the plaza's portal, out
## through the south row, through the broken portal, over the cleft's
## lintel, through the low terrace's portal and under its cross lintel;
## then off the tail's tip and down the curl: between the first fragments'
## stones, under the first rope bridge, between the third and fourth
## fragments, under the bridge home.
static func plane_tokens(p := {}) -> Array:
	var mid := func(i: int) -> float: return (float(LINES[i][0])+float(LINES[i+1][0]))*0.5
	var slalom := PackedVector3Array([
		at3(mid.call(0),-ROW,TOP+L3+1.8),
		at3(float(LINES[2][0]),0.0,TOP+L3+2.6),
		at3(mid.call(3),ROW,TOP+L2+1.8),
		at3(float(LINES[5][0]),0.0,TOP+L2+2.6),
		at3(CLEFT.x,0.0,TOP+crest(CLEFT.x)+2.2),
		at3(117.5,0.0,TOP+L0+2.6),
		at3(123.5,0.0,TOP+L0+2.0),
	])
	var tail := PackedVector3Array()
	var tip := tail_tip()
	tail.append(tip+Vector3(2.5,2.0,0.0))
	for stone: Dictionary in platforms(p):
		if stone.chain == "f12": tail.append((stone.at as Vector3)+Vector3(0.0,2.4,0.0))
	for ends: Array in bridge_ends(p):
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		var span := Vector2(b.x-a.x,b.z-a.z).length()
		# Under the bridge's middle, out 1 m east and 2 m south off the cliff
		# under it (a THREAD's room from the rock, CollectibleLines WING).
		tail.append(a.lerp(b,0.5)+Vector3.UP*(Footbridge.lift(span,0.5)-2.6)+Vector3(1.0,0.0,2.0))
	if int(_p(p).tail) >= 4:
		var f3 := slab_at(FRAGMENTS[2])
		var f4 := slab_at(FRAGMENTS[3])
		tail.insert(tail.size()-1 if int(_p(p).tail) >= 5 else tail.size(),Vector3((f3.x+f4.x)*0.5,TOP-1.2+2.0,(f3.y+f4.y)*0.5))
	return [["cs:slalom","air","thread",slalom],["cs:tail","air","thread",tail]]
