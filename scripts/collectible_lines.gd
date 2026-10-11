extends RefCounted
## Where the sky's collectible tokens stand (scripts/sky_collectibles.gd):
## the rules that lay a line of them against the real geometry of what they
## belong to, from the world's seed, the same every time. Plain data in,
## plain data out, so the heavy ones run on a worker.
##
## A line is {id, category, glyph, size, points (PackedVector3Array, in its
## host's frame), kind (what laid it, for the curious)}; its tokens are its
## points, each `<line id>:<k>`. Categories:
##   bridge: a short line along a rope bridge's or a footbridge's deck, a
##     walker's height over the planks (`bridge_lines`);
##   under: a line slung under an islet's or an island's hanging rock, a
##     plane's clearance under its keel, so it is found by flying under
##     (`under_line`);
##   air: lines and arcs out in the open that reward a good flying line: a
##     swoop between two islands (`trail_line`), a threading of a cluster's
##     gap between two members or under its bridge (`gap_lines`), an arc
##     round a floating mountain's peak (`spire_line`);
##   foot: collected only on foot (the plane passes through them; scripts/
##     sky_collectibles.gd), on ground the walker stands on, a walker's
##     height over it: across a cluster's stepping stones (`stone_line`),
##     along its stairs, docks and lookouts (`deck_lines`), and on an islet
##     or member where it rewards a walk (`foot_line`): a high perch, a
##     ledge by the rim, behind a cabin, under the trees.
##
## The plane's clearance is read as the glide flies (scripts/sky_glide.gd):
## it rides SkyGlide SKIM over whatever is under it (the ground, the tree
## crowns, the stones), keeps SkyGlide CLEAR under rock, and here also keeps
## its wings (WING, half its span with a little room) off every solid and
## every standing build (a cabin, a windmill, a lighthouse). The air lines
## are checked against it (`plane_fits`); `plane_reaches` says whether the
## plane could come within reach of a point at all.
##
## Hosts are read through `solids`: an Array of {shape (scripts/
## sky_islet.gd), off (its middle in the host's frame), decks (its decks'
## {a, b, width, bow}, copied on the main thread: a live rope bridge's sim
## is never read here), builds (Vector4 x, z, radius, height over the ground,
## its own frame)}.

const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Footbridge = preload("res://scripts/footbridge.gd")

## The density: one multiplier on every kind of line's odds. 1 is the
## tuned sky (some fifty lines over a whole world, a few hundred tokens,
## most lines short); 0 lays none; 2 about twice as many.
const DENSITY := 1.0
## The odds each host lays each kind of line at DENSITY 1: a rope bridge or
## footbridge; a cluster's gap (or the air under its bridge); a floating
## mountain's peak; under a seeded islet, a cluster's anchor, an island;
## on foot on an islet, on a cluster member (one at most a cluster), across
## a run of stepping stones, along a deck (a stair, a dock, a lookout); a
## swoop between two neighbouring islands.
const ODDS := {"bridge":0.6,"gap":0.55,"spire":1.0,"under_islet":0.07,"under_member":0.3,"under_island":0.45,
	"foot_islet":0.08,"foot_member":0.7,"foot_stones":0.6,"foot_deck":0.5,"trail":0.35}
## The glyphs each category's lines draw from (scripts/hud_icons.gd): one
## glyph a line, by its hash.
const GLYPHS := {"bridge":["lamp","heron"],"under":["crystal","moon"],"air":["feather","sun","rainbow","snow"],
	"foot":["wildflower","oak","dandelion","sunflower","deer"]}
## The tokens' sizes (m across): the air's read from the chase camera, the
## walker's about his chest.
const SIZES := {"bridge":0.7,"under":1.05,"air":1.2,"foot":0.7}
## Pickup reaches (m, from the walker's middle or the plane's, plus half the
## token): the plane's larger, so an air line is fair at speed (1.1 at
## plane 1, out by half of what the plane is wider: scripts/world_scale.gd).
const WALKER_REACH := 0.6
static var PLANE_REACH: float = 1.1+WorldScale.wider*0.5
## The walker's middle over his feet (m), and a foot or bridge token's
## middle over the ground or the planks.
const WALKER_MIDDLE := 0.5
const FOOT_Y := 0.55
## The plane: half its wingspan (scripts/world_scale.gd span: 0.8 at
## plane 1) and a little room; how far over the ground it rides and under
## rock it keeps (SkyGlide SKIM, CLEAR; drawn about its wheels a bigger
## plane is taller, all of it upward: WorldScale.taller more).
static var WING: float = WorldScale.span*0.5+0.1
const SKIM := SkyGlide.SKIM
static var CLEAR: float = SkyGlide.CLEAR+WorldScale.taller
## Nothing hangs lower than this (home y): the glide's floor (SkyGlide
## FLOOR) with room, over the cloud sea's heaps.
const LOWEST := SkyGlide.FLOOR+6.0
## A bridge line: its tokens apart (m), at least and at most.
const BRIDGE_STEP := 1.6
const BRIDGE_COUNT := Vector2i(2,5)
## Under: how far under the rock (m), the tokens apart (m), and how many.
const UNDER_GAP := 3.2
const UNDER_STEP := 5.0
const UNDER_COUNT := Vector2i(4,7)
## Air: a cluster's gap is threaded where it is GAP_ROOM wide at least and
## GAP_MOST at most (rim to rim); the line's tokens apart and how many; how
## far under a bridge's deck it runs.
const GAP_ROOM := 3.2
const GAP_MOST := 16.0
const GAP_STEP := 4.0
const GAP_COUNT := Vector2i(5,6)
const UNDER_BRIDGE := 3.4
## A peak's arc: its height up the peak (share), clear of the rock (m), how
## far round (rad), tokens, and the climb from one to the next (m).
const SPIRE_UP := Vector2(0.4,0.6)
const SPIRE_CLEAR := 4.0
const SPIRE_TALL := 18.0
const SPIRE_ARC := 2.6
const SPIRE_COUNT := 8
const SPIRE_CLIMB := 0.9
const SPIRE_TRIES := 6
## A swoop between islands: where along the way (share), its tokens apart
## (m) and how many, how high over the two islands' line (m), how far it
## bows to the side and dips (m); and what it keeps clear of (m): an
## islet's spot, a cluster's middle, an island's.
const TRAIL_AT := Vector2(0.35,0.65)
const TRAIL_STEP := 7.0
const TRAIL_COUNT := Vector2i(7,9)
const TRAIL_LIFT := Vector2(8.0,20.0)
const TRAIL_BOW := Vector2(4.0,10.0)
const TRAIL_DIP := Vector2(0.0,4.0)
const TRAIL_ISLET := 26.0
const TRAIL_CLUSTER := 110.0
const TRAIL_ISLAND := 70.0
## A swoop never dips under this (home y): over the cloud sea's heaps, as
## the clusters stand (SkyClusters BAND).
const TRAIL_LOW := -24.0
## Islands this far apart at most count as neighbours (m).
const TRAIL_REACH := 900.0
## Foot: candidates every FOOT_GRID m over the land, at least FOOT_IN in
## from the rim; the FOOT_TRIES best joined into a line; its tokens
## FOOT_STEP apart (at least, at most), FOOT_COUNT of them.
const FOOT_GRID := 0.6
const FOOT_IN := 0.7
const FOOT_TRIES := 48
const FOOT_STEP := Vector2(0.9,2.4)
const FOOT_COUNT := Vector2i(3,5)
## Ground steeper than this over 0.3 m isn't stood on; a line's tokens
## climb no more than FOOT_RISE from one to the next (a jump).
const FOOT_STEEP := 0.35
const FOOT_RISE := 0.8
## A cluster's decks lay this many lines at most.
const DECK_LINES := 2
## The builds the plane's wings keep off: a feature's footprint radius (m)
## and height (m).
const BUILDS := {"cabin":Vector2(1.5,3.3),"windmill":Vector2(1.6,7.5),"lighthouse":Vector2(1.5,9.5),"lamp":Vector2(0.3,1.2),"post":Vector2(0.15,2.0)}

# --- Odds and hashing -----------------------------------------------------------

## A hash of `key` and `salt` under the world's `seed`, 0 to 1.
static func roll(seed_value: int, key: String, salt: String) -> float:
	return float(hash([seed_value,key,salt]) & 0xffffff)/16777216.0

## True when a host keyed `key` lays a line of `kind` (ODDS times DENSITY;
## `force` lays it whatever the odds).
static func lays(seed_value: int, key: String, kind: String, force := false) -> bool:
	if force: return DENSITY > 0.0
	return roll(seed_value,key,kind) < float(ODDS.get(kind,0.0))*DENSITY

## A line record (see the header).
static func line(id: String, category: String, kind: String, points: PackedVector3Array, seed_value: int) -> Dictionary:
	var pool: Array = GLYPHS[category]
	var glyph: String = pool[mini(int(roll(seed_value,id,"glyph")*pool.size()),pool.size()-1)]
	return {"id":id,"category":category,"kind":kind,"glyph":glyph,"size":float(SIZES[category]),"points":points}

# --- Bridges ----------------------------------------------------------------------

## The lines along a cluster's bridges (plan.bridges, scripts/
## cluster_solver.gd), in the frame of the member at `host_off` (each
## member's middle, `offsets` by name, in the cluster's frame). A rope
## bridge's planks sag, a footbridge's arch: the line follows its deck
## (Footbridge `lift`), FOOT_Y over it, through the middle of the span.
static func bridge_lines(plan: Dictionary, offsets: Dictionary, host_off: Vector3, key: String, seed_value: int, force := false) -> Array:
	var out: Array = []
	var bridges: Array = plan.get("bridges",[])
	for i in range(bridges.size()):
		var br: Dictionary = bridges[i]
		var id := "%s:bridge%d" % [key,i]
		if not lays(seed_value,id,"bridge",force): continue
		var off: Vector3 = (offsets.get(br.from,Vector3.ZERO) as Vector3)-host_off
		var a: Vector3 = (br.a as Vector3)+off
		var b: Vector3 = (br.b as Vector3)+off
		var span := Vector2(b.x-a.x,b.z-a.z).length()
		var n := clampi(int(span*0.6/BRIDGE_STEP)+1,BRIDGE_COUNT.x,BRIDGE_COUNT.y)
		var points := PackedVector3Array()
		for k in range(n):
			var t := 0.5+(float(k)-(n-1)*0.5)*BRIDGE_STEP/maxf(span,0.1)
			t = clampf(t,0.12,0.88)
			points.append(a.lerp(b,t)+Vector3.UP*(Footbridge.lift(span,t)+FOOT_Y))
		out.append(line(id,"bridge","bridge",points,seed_value))
	return out

# --- Under the rock ----------------------------------------------------------------

## A line slung under a hanging rock: `under` (Callable(Vector2) -> float,
## the underside's height at a point of the host's frame, or INF off it)
## read across `reach` m each side of `middle` along a way turned by the
## hash; each token UNDER_GAP under the lowest rock within the plane's wings
## of it, eased into a smooth sag, never under `lowest` (the host's frame).
## Empty where the rock leaves too little room over the floor.
static func under_line(id: String, under: Callable, middle: Vector2, reach: float, lowest: float, seed_value: int) -> Dictionary:
	var way := Vector2.from_angle(roll(seed_value,id,"way")*TAU)
	var side := Vector2(-way.y,way.x)
	var shift := (roll(seed_value,id,"shift")-0.5)*reach*0.4
	# The rock's span along the way.
	var ts: Array[float] = []
	var lows: Array[float] = []
	var t := -reach
	while t <= reach:
		var p := middle+way*t+side*shift
		var low := INF
		for w: Vector2 in [Vector2.ZERO,side*WING,-side*WING,way*WING,-way*WING]:
			var u := float(under.call(p+w))
			if u < INF: low = minf(low,u)
		if low < INF:
			ts.append(t)
			lows.append(low)
		t += 1.0
	if ts.size() < 6: return {}
	var t0: float = ts[0]
	var t1: float = ts[-1]
	var length := (t1-t0)*0.8
	var n := clampi(int(length/UNDER_STEP)+1,UNDER_COUNT.x,UNDER_COUNT.y)
	var step := length/maxf(n-1,1)
	var start := (t0+t1)*0.5-length*0.5
	var points := PackedVector3Array()
	for k in range(n):
		var at := start+step*k
		# The lowest rock within a step either way, so the line clears the
		# keel between its tokens too.
		var low := INF
		for j in range(ts.size()):
			if absf(ts[j]-at) <= step*0.6+WING: low = minf(low,lows[j])
		var y := low-UNDER_GAP
		if y < lowest: return {}
		var p := middle+way*at+side*shift
		points.append(Vector3(p.x,y,p.y))
	# A gentle sag: each token no higher than the straight line between its
	# neighbours allows, so the line reads as one swoop.
	for k in range(1,n-1):
		points[k].y = minf(points[k].y,(points[k-1].y+points[k+1].y)*0.5)
	return line(id,"under","under",points,seed_value)

## The underside of an islet's shape at a point of its frame, or INF off
## its land (SkyIslet `underside`, read without its decks).
static func islet_under(shape: RefCounted, p: Vector2) -> float:
	if not shape.on_land(p): return INF
	return float(shape.base)-float(shape._sample(shape.keel,p,0.0))

# --- Solids, for the plane ---------------------------------------------------------

## A host's solids (see the header) for one islet standing at `off`, with
## its decks copied and its builds read from `features` (a cluster
## member's).
static func solid(shape: RefCounted, off: Vector3, features: Array = []) -> Dictionary:
	var decks: Array = []
	for d: Dictionary in shape.decks: decks.append({"a":d.a,"b":d.b,"width":float(d.get("width",1.0)),"bow":float(d.get("bow",0.0))})
	var builds: Array[Vector4] = []
	for f: Dictionary in features:
		if not BUILDS.has(str(f.type)) or not f.has("at"): continue
		var size: Vector2 = BUILDS[f.type]
		builds.append(Vector4(f.at.x,f.at.y,size.x,size.y))
	return {"shape":shape,"off":off,"decks":decks,"builds":builds,"reach":float(shape.reach)+2.0}

## The ground's height at `p` (the solid's own frame), or -INF off its land
## and decks: the land as drawn, a deck's planks at rest.
static func ground(s: Dictionary, p: Vector2) -> float:
	var shape: RefCounted = s.shape
	if shape.on_land(p): return float(shape._sample(shape.heights,p,SkyIslet.RIM_HEIGHT))
	return deck_y(s,p)

static func deck_y(s: Dictionary, p: Vector2) -> float:
	var best := -INF
	for d: Dictionary in s.decks:
		var a: Vector3 = d.a
		var b: Vector3 = d.b
		var from := Vector2(a.x,a.z)
		var way := Vector2(b.x,b.z)-from
		var t := (p-from).dot(way)/maxf(way.length_squared(),0.0001)
		if t < 0.0 or t > 1.0: continue
		if absf((p-from).cross(way)/way.length()) > float(d.width)*0.5: continue
		var bow := float(d.bow)
		var shape := sin(PI*t)
		best = maxf(best,lerpf(a.y,b.y,t)+bow*(shape if bow > 0.0 else shape*shape))
	return best

## The solid's column at `p` (its own frame): Vector2(the top the plane
## rides over: the ground, a crown, a stone, a build; the underside), or
## Vector2.INF where there is none.
static func column(s: Dictionary, p: Vector2) -> Vector2:
	var shape: RefCounted = s.shape
	var land: bool = shape.on_land(p)
	var top := float(shape._sample(shape.heights,p,SkyIslet.RIM_HEIGHT)) if land else deck_y(s,p)
	if top == -INF: return Vector2.INF
	var under := float(shape.base)-float(shape._sample(shape.keel,p,0.0)) if land else top-0.4
	if land:
		for c: Vector4 in shape.crowns:
			if absf(p.x-c.x) < c.w and absf(p.y-c.y) < c.w and p.distance_to(Vector2(c.x,c.y)) < c.w:
				top = maxf(top,float(shape._sample(shape.heights,Vector2(c.x,c.y),SkyIslet.RIM_HEIGHT))+c.z)
		for b: Vector4 in s.builds:
			if p.distance_to(Vector2(b.x,b.y)) < b.z:
				top = maxf(top,float(shape._sample(shape.heights,Vector2(b.x,b.y),SkyIslet.RIM_HEIGHT))+b.w)
	return Vector2(top,under)

## The heights a plane's middle may not take over the host-frame point
## `p`: each solid's [underside - CLEAR, top + SKIM], over its wings' reach
## round `p`. Vector2 intervals, unsorted. Columns are read on a LATTICE m
## grid and kept in `cache` (by solid and grid point) when one is given, so
## a search over many places reads each spot once.
static func blocked_heights(solids: Array, p: Vector2, cache = null) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in range(solids.size()):
		var s: Dictionary = solids[i]
		var off: Vector3 = s.off
		var local := p-Vector2(off.x,off.z)
		if local.length() > float(s.reach)+WING: continue
		for w: Vector2 in WINGS:
			var c: Vector2
			if cache is Dictionary:
				var q := Vector3i(i,roundi((local.x+w.x)/LATTICE),roundi((local.y+w.y)/LATTICE))
				if cache.has(q): c = cache[q]
				else:
					c = column(s,Vector2(q.y,q.z)*LATTICE)
					cache[q] = c
			else:
				c = column(s,local+w)
			if c == Vector2.INF: continue
			out.append(Vector2(c.y+off.y-CLEAR,c.x+off.y+SKIM))
	return out

## The grid the plane's places are read on (m), and its wings' reach round
## its middle on that grid (about WING: 0.9 and 0.6 at plane 1, grown
## with it).
const LATTICE := 0.3
static var WING_REACH: float = 0.9*WING/0.8
static var WING_SLANT: float = 0.6*WING/0.8
static var WINGS := [Vector2.ZERO,Vector2(WING_REACH,0.0),Vector2(-WING_REACH,0.0),Vector2(0.0,WING_REACH),Vector2(0.0,-WING_REACH),
	Vector2(WING_SLANT,WING_SLANT),Vector2(-WING_SLANT,WING_SLANT),Vector2(WING_SLANT,-WING_SLANT),Vector2(-WING_SLANT,-WING_SLANT)]


## True when the plane's middle can stand at host-frame point `p`.
static func plane_fits(solids: Array, p: Vector3) -> bool:
	for b in blocked_heights(solids,Vector2(p.x,p.z)):
		if p.y > b.x and p.y < b.y: return false
	return true

## True when the plane can come within `reach` of host-frame point `p`:
## some place round it, its wings clear, within reach. Read on the LATTICE
## round `p` across, and up and down each the nearest free height.
static func plane_reaches(solids: Array, p: Vector3, reach: float, cache = null) -> bool:
	var n := int(ceilf(reach/LATTICE))
	var base := Vector2(roundf(p.x/LATTICE),roundf(p.z/LATTICE))*LATTICE
	for i in range(-n,n+1):
		for j in range(-n,n+1):
			var c := base+Vector2(i,j)*LATTICE
			var d := c-Vector2(p.x,p.z)
			if d.length() > reach: continue
			var half := sqrt(maxf(reach*reach-d.length_squared(),0.0))
			if _free_within(blocked_heights(solids,c,cache),p.y-half,p.y+half): return true
	return false

## True when some height in [lo, hi] lies outside every interval.
static func _free_within(blocked: Array[Vector2], lo: float, hi: float) -> bool:
	blocked.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var at := lo
	for b in blocked:
		if b.y <= at: continue
		if b.x > at: return true
		at = b.y
		if at >= hi: return false
	return at < hi

# --- Foot ---------------------------------------------------------------------------

## A short line on foot on solid `index` of `solids` (in the host's frame):
## places the walker stands (on its land, FOOT_IN from the rim, not in a
## trunk, a stone or the water, the ground level enough to stand on), the
## best by what makes a walk worth it (`_worth`: height over the rest of
## the land, the rim's edge, a build's back, the trees' cover), joined
## FOOT_STEP apart into a line of FOOT_COUNT; {} where there's no room.
static func foot_line(id: String, solids: Array, index: int, seed_value: int) -> Dictionary:
	var s: Dictionary = solids[index]
	var shape: RefCounted = s.shape
	var off: Vector3 = s.off
	var reach := float(shape.reach)
	var places: Array = []
	var low := INF
	var high := -INF
	var x := -reach
	while x <= reach:
		var z := -reach
		while z <= reach:
			var p := Vector2(x,z)
			z += FOOT_GRID
			if not _standable(shape,p): continue
			var g := float(shape._sample(shape.heights,p,SkyIslet.RIM_HEIGHT))
			low = minf(low,g)
			high = maxf(high,g)
			places.append([p,g])
		x += FOOT_GRID
	if places.size() < FOOT_COUNT.x: return {}
	# What each place is worth, its hash breaking ties, the best first.
	var scored: Array = []
	for e: Array in places:
		var p: Vector2 = e[0]
		var g: float = e[1]
		var worth := _worth(s,p,g,low,high)+roll(seed_value,id,"%d,%d" % [int(p.x*10.0),int(p.y*10.0)])*0.6
		scored.append([worth,Vector3(p.x,g+FOOT_Y,p.y)])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var safe: Array[Vector3] = []
	for k in range(mini(scored.size(),FOOT_TRIES)): safe.append(scored[k][1])
	# The line: from the best, on to the nearest place a step away that
	# doesn't turn back on it.
	var want := FOOT_COUNT.x+int(roll(seed_value,id,"count")*(FOOT_COUNT.y-FOOT_COUNT.x+1))
	var points := PackedVector3Array([safe[0]+off])
	var last := safe[0]
	var heading := Vector2.ZERO
	var used := {0:true}
	while points.size() < want:
		var best := -1
		var best_d := INF
		for k in range(safe.size()):
			if used.has(k): continue
			var d := Vector2(safe[k].x-last.x,safe[k].z-last.z)
			if d.length() < FOOT_STEP.x or d.length() > FOOT_STEP.y or absf(safe[k].y-last.y) > FOOT_RISE: continue
			if heading != Vector2.ZERO and d.normalized().dot(heading) < 0.3: continue
			if d.length() < best_d:
				best_d = d.length()
				best = k
		if best < 0: break
		used[best] = true
		heading = Vector2(safe[best].x-last.x,safe[best].z-last.z).normalized()
		last = safe[best]
		points.append(last+off)
	if points.size() < FOOT_COUNT.x: return {}
	return line(id,"foot","foot",points,seed_value)

## True where the walker can stand at `p` (its own frame): on its land,
## FOOT_IN from the rim, clear of trunks, stones and water, level enough.
static func _standable(shape: RefCounted, p: Vector2) -> bool:
	if not shape.on_land(p) or float(shape.inland(p)) < FOOT_IN or shape.wet(p): return false
	if _trunk(shape,p): return false
	var g := float(shape._sample(shape.heights,p,SkyIslet.RIM_HEIGHT))
	for d: Vector2 in [Vector2(0.3,0.0),Vector2(-0.3,0.0),Vector2(0.0,0.3),Vector2(0.0,-0.3)]:
		if not shape.on_land(p+d) or absf(float(shape._sample(shape.heights,p+d,SkyIslet.RIM_HEIGHT))-g) > FOOT_STEEP: return false
	return true

## True within a trunk's or a stone's block (and a little room) at `p`.
static func _trunk(shape: RefCounted, p: Vector2) -> bool:
	for b: Vector3 in shape.blocks:
		if p.distance_to(Vector2(b.x,b.y)) < b.z+0.15: return true
	return false

## What makes a place worth walking to (0 for plain middle ground): how
## high it stands over the rest of the land (a perch), how near the rim (a
## ledge), how near the back of a build (behind a cabin), the trees' cover.
static func _worth(s: Dictionary, p: Vector2, g: float, low: float, high: float) -> float:
	var shape: RefCounted = s.shape
	var worth := 0.0
	if high-low > 0.8: worth += 2.0*(g-low)/(high-low)
	worth += 1.2*clampf(1.0-(float(shape.inland(p))-FOOT_IN)/1.5,0.0,1.0)
	for b: Vector4 in s.builds:
		var d := p.distance_to(Vector2(b.x,b.y))
		if b.w > 1.8 and d > b.z and d < b.z+1.6: worth += 1.0
	return worth+minf(_cover(s,p,g+FOOT_Y),2.0)*0.5

## A line across a cluster's stepping stones: one token on each stone of a
## run (plan.routes, a stone being any member of the run but its ends), a
## walker's height over its middle's ground. `offsets` by member name.
static func stone_lines(plan: Dictionary, offsets: Dictionary, host_off: Vector3, key: String, seed_value: int, force := false) -> Array:
	var out: Array = []
	var shapes := {}
	for m: Dictionary in plan.members: shapes[m.name] = m.shape
	var routes: Array = plan.get("routes",[])
	for i in range(routes.size()):
		var route: Array = routes[i]
		var id := "%s:stones%d" % [key,i]
		if route.size() < 3 or not lays(seed_value,id,"foot_stones",force): continue
		var points := PackedVector3Array()
		for k in range(1,route.size()-1):
			var shape: RefCounted = shapes.get(route[k])
			if shape == null: continue
			# The stone's best standing place near its middle.
			var at := Vector2.INF
			for ring in range(5):
				for turn in range(8 if ring > 0 else 1):
					var r := Vector2.from_angle(TAU*turn/8.0)*0.3*ring
					if shape.on_land(r) and not shape.wet(r) and not _trunk(shape,r):
						at = r
						break
				if at != Vector2.INF: break
			if at == Vector2.INF: continue
			var off: Vector3 = (offsets[route[k]] as Vector3)-host_off
			points.append(Vector3(at.x,float(shape._sample(shape.heights,at,SkyIslet.RIM_HEIGHT))+FOOT_Y,at.y)+off)
		if points.size() >= 2: out.append(line(id,"foot","stones",points,seed_value))
	return out

## Lines along a cluster's decks that are not its bridges: a stack's
## stairs, a dock, a lookout's planks, each a walker's height over them.
## Each solid's decks (`solids`), its offset its own.
static func deck_lines(plan: Dictionary, solids: Array, names: Array, key: String, seed_value: int, force := false) -> Array:
	var out: Array = []
	for i in range(solids.size()):
		var s: Dictionary = solids[i]
		var decks: Array = s.decks
		for j in range(decks.size()):
			var d: Dictionary = decks[j]
			var bridged := false
			for br: Dictionary in plan.get("bridges",[]):
				if (br.a as Vector3).is_equal_approx(d.a) and (br.b as Vector3).is_equal_approx(d.b): bridged = true
			if bridged: continue
			var id := "%s:deck:%s:%d" % [key,names[i],j]
			if not lays(seed_value,id,"foot_deck",force): continue
			var a: Vector3 = d.a
			var b: Vector3 = d.b
			var span := Vector2(b.x-a.x,b.z-a.z).length()
			if span < 1.5: continue
			var n := clampi(int(span/BRIDGE_STEP),1,3)
			var points := PackedVector3Array()
			for k in range(n):
				var t := (k+0.5)/n
				var p := Vector2(lerpf(a.x,b.x,t),lerpf(a.z,b.z,t))
				var y := deck_y(s,p)
				if y == -INF: continue
				points.append(Vector3(p.x,y+FOOT_Y,p.y)+(s.off as Vector3))
			if not points.is_empty(): out.append(line(id,"foot","deck",points,seed_value))
	# A run of short decks (a stair's flights) reads as one line: kept to
	# the hash's few, so a long stair isn't strung end to end.
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return roll(seed_value,p.id,"keep") < roll(seed_value,q.id,"keep"))
	return out.slice(0,DECK_LINES)

## How well covered a walker's place is (0 none): the crowns and builds
## over it, each counted by how far in under it the place stands and only
## if it rises at least 1.4 m over the token.
static func _cover(s: Dictionary, p: Vector2, y: float) -> float:
	var shape: RefCounted = s.shape
	var cover := 0.0
	for c: Vector4 in shape.crowns:
		var d := p.distance_to(Vector2(c.x,c.y))
		if d >= c.w: continue
		var top := float(shape._sample(shape.heights,Vector2(c.x,c.y),SkyIslet.RIM_HEIGHT))+c.z
		if top < y+1.4: continue
		cover += c.w-d
	for b: Vector4 in s.builds:
		var d := p.distance_to(Vector2(b.x,b.y))
		if d < b.z+WING and b.w > 1.8: cover += 0.3
	return cover

# --- Air -----------------------------------------------------------------------------

## The air lines of a cluster, in the frame of the member at `host_off`:
## threading the gap between two members where it is wide enough for the
## plane's wings, at the height of their rims, or, where a bridge spans it,
## under the bridge's planks; each token checked clear of every solid. One
## line at most, of the gaps the hash prefers.
static func gap_lines(plan: Dictionary, solids: Array, host_off: Vector3, key: String, seed_value: int, force := false) -> Array:
	var id := "%s:gap" % key
	if not lays(seed_value,id,"gap",force): return []
	var members: Array = plan.members
	var pairs: Array = []
	for i in range(members.size()):
		for j in range(i+1,members.size()):
			var a: Dictionary = members[i]
			var b: Dictionary = members[j]
			var near := _nearest_rims(a,b)
			var gap: float = near[2]
			if gap < GAP_ROOM or gap > GAP_MOST: continue
			pairs.append([roll(seed_value,id,"%s-%s" % [a.name,b.name]),a,b,near])
	pairs.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	for pair: Array in pairs:
		var a: Dictionary = pair[1]
		var b: Dictionary = pair[2]
		var near: Array = pair[3]
		var pa: Vector3 = near[0]
		var pb: Vector3 = near[1]
		var middle := (pa+pb)*0.5
		var across := Vector2(pb.x-pa.x,pb.z-pa.z).normalized()
		var way := Vector2(-across.y,across.x)
		if roll(seed_value,id,"turn") < 0.5: way = -way
		# Under its bridge, if one spans these two; else at the rims'
		# height, a little under the lower lip.
		var y := minf(pa.y,pb.y)-1.6
		var kind := "gap"
		for br: Dictionary in plan.bridges:
			if not ((br.from == a.name and br.to == b.name) or (br.from == b.name and br.to == a.name)): continue
			var off: Vector3 = (a.offset if br.from == a.name else b.offset)
			var mid: Vector3 = ((br.a as Vector3)+(br.b as Vector3))*0.5+off
			var span := Vector2(br.b.x-br.a.x,br.b.z-br.a.z).length()
			y = mid.y+Footbridge.lift(span,0.5)-UNDER_BRIDGE
			middle = Vector3(mid.x,middle.y,mid.z)
			kind = "under_bridge"
		middle = Vector3(middle.x,y,middle.z)-host_off
		var n := GAP_COUNT.x+int(roll(seed_value,id,"count")*(GAP_COUNT.y-GAP_COUNT.x+1))
		var points := PackedVector3Array()
		var clear := true
		for k in range(n):
			var s := (float(k)-(n-1)*0.5)
			var u := s/maxf((n-1)*0.5,1.0)
			# A shallow dip through the gap, lowest in its middle.
			var at := Vector3(middle.x+way.x*s*GAP_STEP,middle.y-0.8*(1.0-u*u),middle.z+way.y*s*GAP_STEP)
			if not plane_fits(solids,at) or not plane_fits(solids,at+Vector3(way.x,0.0,way.y)*GAP_STEP*0.5):
				clear = false
				break
			points.append(at)
		if clear: return [line(id,"air",kind,points,seed_value)]
	return []

## The two nearest points of two members' rims (RIM_SAMPLES round each,
## at their rims' height, in the cluster's frame) and the gap between them.
static func _nearest_rims(a: Dictionary, b: Dictionary) -> Array:
	var best := [Vector3.ZERO,Vector3.ZERO,INF]
	var ao: Vector3 = a.offset
	var bo: Vector3 = b.offset
	var ra := rim(a.shape)
	var rb := rim(b.shape)
	for p: Vector2 in ra:
		for q: Vector2 in rb:
			var d := Vector2(bo.x+q.x-ao.x-p.x,bo.z+q.y-ao.z-p.y).length()
			if d < float(best[2]): best = [Vector3(ao.x+p.x,ao.y+SkyIslet.RIM_HEIGHT,ao.z+p.y),Vector3(bo.x+q.x,bo.y+SkyIslet.RIM_HEIGHT,bo.z+q.y),d]
	return best

## Rim samples round an islet (its own frame).
const RIM_SAMPLES := 32

static func rim(shape: RefCounted) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(RIM_SAMPLES): out.append(shape.rim_point(TAU*k/RIM_SAMPLES))
	return out

## An arc round a floating mountain's peak (SkyIslet `spire`, scripts/
## mountain_spire.gd) on solid `index`: part way up it, SPIRE_CLEAR off its
## rock all along, climbing a little token by token, each clear of every
## solid. {} for a peak too low to be worth circling.
static func spire_line(id: String, solids: Array, index: int, seed_value: int, force := false) -> Dictionary:
	var s: Dictionary = solids[index]
	var shape: RefCounted = s.shape
	var spire: RefCounted = shape.spire
	if spire == null or float(spire.height) < SPIRE_TALL: return {}
	if not lays(seed_value,id,"spire",force): return {}
	var off: Vector3 = s.off
	var centre: Vector2 = spire.centre
	# Tried from SPIRE_TRIES starts round the peak and heights up it, the
	# first whose every token is clear of every solid (the peak's own
	# neighbours, a stone's run past its foot) taken.
	for attempt in range(SPIRE_TRIES):
		var up := lerpf(SPIRE_UP.x,SPIRE_UP.y,fposmod(roll(seed_value,id,"up")+attempt*0.37,1.0))
		var base := float(spire.ground)+float(spire.height)*up
		var start := roll(seed_value,id,"start")*TAU+attempt*TAU/SPIRE_TRIES
		var turn := 1.0 if roll(seed_value,id,"turn") < 0.5 else -1.0
		var points := PackedVector3Array()
		for k in range(SPIRE_COUNT):
			var a := start+turn*SPIRE_ARC*float(k)/(SPIRE_COUNT-1)
			var y := base+SPIRE_CLIMB*k
			var dir := Vector2.from_angle(a)
			# Out from the summit till the rock is SPIRE_CLEAR under the
			# token, then out a little more.
			var r := 1.0
			while r < float(shape.reach)+6.0:
				var c := column(s,centre+dir*r)
				if c == Vector2.INF or c.x < y-SPIRE_CLEAR: break
				r += 0.5
			var at := Vector3(centre.x+dir.x*(r+SPIRE_CLEAR*0.6),y,centre.y+dir.y*(r+SPIRE_CLEAR*0.6))+off
			if not plane_fits(solids,at): break
			points.append(at)
		if points.size() == SPIRE_COUNT: return line(id,"air","spire",points,seed_value)
	return {}

## A swoop between two islands' spots `a` and `b` (home), or {} where it
## would cross something: part way along, over the line between them,
## bowed to one side and dipping, its tokens TRAIL_STEP apart. `clear`
## (Callable(home) -> bool) says where the air is open.
static func trail_line(id: String, a: Vector3, b: Vector3, clear: Callable, seed_value: int) -> Dictionary:
	var flat := Vector2(b.x-a.x,b.z-a.z)
	if flat.length() < 120.0: return {}
	var way := flat.normalized()
	var side := Vector2(-way.y,way.x)
	var f := lerpf(TRAIL_AT.x,TRAIL_AT.y,roll(seed_value,id,"at"))
	var n := TRAIL_COUNT.x+int(roll(seed_value,id,"count")*(TRAIL_COUNT.y-TRAIL_COUNT.x+1))
	var lift := lerpf(TRAIL_LIFT.x,TRAIL_LIFT.y,roll(seed_value,id,"lift"))
	var bow := lerpf(TRAIL_BOW.x,TRAIL_BOW.y,roll(seed_value,id,"bow"))*(1.0 if roll(seed_value,id,"side") < 0.5 else -1.0)
	var dip := lerpf(TRAIL_DIP.x,TRAIL_DIP.y,roll(seed_value,id,"dip"))
	var length := TRAIL_STEP*(n-1)
	var points := PackedVector3Array()
	for k in range(n):
		var u := float(k)/(n-1)
		var along := flat.length()*f+(u-0.5)*length
		var share := along/flat.length()
		var bend := sin(PI*u)
		var p := Vector2(a.x,a.z)+way*along+side*bow*bend
		var y := maxf(lerpf(a.y,b.y,share)+lift,TRAIL_LOW+dip)-dip*bend
		var at := Vector3(p.x,y,p.y)
		if not clear.call(at): return {}
		points.append(at)
	return line(id,"air","trail",points,seed_value)
