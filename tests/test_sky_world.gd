extends SceneTree
## The bounded sky world (scripts/sky_world.gd): one seed, the bounds, the
## whole-world layout, the mountain ring and its edge wind.
##
## For several seeds, from the layout alone: the same seed lays the same
## ring and another seed another; the old worlds' hash is unchanged under
## the legacy seed; NOTCHES notches, spread round the ring, and no range's
## crest in one; the crests close the ring everywhere else; every range
## clear of the bounds and the whole world within WORLD; the plate, the
## fixed islands and the wonders in sight of the plate inside the bounds;
## and nothing scattered (islands, islets, cumulus) outside them.
##
## For two seeds, from the ranges' real shapes (scripts/sky_peak.gd): the
## ring's rock closes the ring but for slots no wider than SLOT (a gorge)
## and the notches, which are open at glide height; its rock stands GAP
## clear of the bounds and of the range in sight of the plate, and within
## WORLD.
##
## The edge: no wind inside, a smooth one past the ring rising over the
## glide's cruise, blowing home; a glide out through every notch, let be,
## is turned home, and one held outward in a dive is held by the wind, never
## stopped dead by a wall.
## A world saved before the ring keeps its far islands: the ring leaves
## them room and the edge wind starts past them. The seed is saved, and a
## save without one reads as the legacy seed.
##
## The skyline: every ring range stands far off as coarse faces, steps
## aside for the full range near and comes back when it is let go; the
## ring's jets run in through its gorges; and the ring's haze leaves it in
## sight across the world while the bounds keep the islands' haze.
## Headless: shapes, spots and the glide's own stepping; nothing drawn.
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyHomes = preload("res://scripts/sky_homes.gd")
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SkyHaze = preload("res://scripts/sky_haze.gd")
const SEEDS := [7,1,99,12345,31337,424242]
## The seeds whose ranges are made for real.
const SHAPED := [7,12345]
## The whole world stands within WORLD (m) of its middle, along x and z.
const WORLD := 4000.0
## Rock to the bounds, and to the range in sight of the plate (m).
const GAP := 150.0
## The widest opening through the ring's rock outside the notches (m): a
## gorge's slot.
const SLOT := 220.0
## The notches stay at least this far apart round the ring (radians).
const NOTCH_APART := deg_to_rad(60.0)
const DT := 1.0/30.0

var failures := 0

func _initialize() -> void:
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	_defaults()
	for s: int in SEEDS:
		SkyWorld.seed = s
		_laid_out(s)
	_deterministic()
	_inside()
	for s: int in SHAPED:
		SkyWorld.seed = s
		_shaped(s)
	SkyWorld.seed = SkyWorld.LEGACY_SEED
	_edge()
	_glide_home()
	_saved()
	_skyline()
	_haze()
	print("PASS: sky world" if failures == 0 else "FAIL: sky world")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## In play the ranges and the ring stand; the other wonders don't.
func _defaults() -> void:
	check(SkyHomes.peaks and not SkyHomes.stone and not SkyHomes.isles and SkyWorld.ring and SkyWorld.ring_on(),"The ranges and the ring stand by default; the other stone wonders and the isles don't")
	check(SkyWorld.seed == SkyWorld.LEGACY_SEED,"A world starts on the legacy seed")
	# The hash every kind used before, by hand, under the legacy seed.
	var same := true
	for cell: Vector2i in [Vector2i(0,0),Vector2i(3,-7),Vector2i(-12,40)]:
		for salt in [0,4,1000,3000,5010]:
			var h: int = cell.x*73856093^cell.y*19349663^salt*83492791^7*2654435761
			h = (h^(h >> 13))*1274126177
			h = (h^(h >> 16))*668265263
			h ^= h >> 15
			if not is_equal_approx(float(h & 0xFFFFFF)/float(0x1000000),SkyCells.noise(cell,salt)) or SkyCells.noise(cell,salt) != SkyPeaks.noise(cell,salt): same = false
	check(same,"Under the legacy seed every cell hashes as it did, so an old world's sky is unchanged")
	check(SkyWorld.salted(23) == 23,"The clouds' own seed is unchanged under the legacy seed")

# --- The layout ----------------------------------------------------------------------

## A range's crest ends over the sea (home, plate plane), as laid out.
static func crest_ends(r: Dictionary) -> Array:
	var along := Vector3(1.0,0.0,0.0).rotated(Vector3.UP,float(r.turn))*SkyWorld.CREST_HALF*float(r.spread)
	return [r.at-along,r.at+along]

## Its footprint over the sea (home), as laid out: the crest's ends and its
## flanks across.
static func footprint(r: Dictionary) -> Array:
	var along := Vector3(1.0,0.0,0.0).rotated(Vector3.UP,float(r.turn))*SkyWorld.CREST_HALF*float(r.spread)
	var across := Vector3(0.0,0.0,1.0).rotated(Vector3.UP,float(r.turn))*SkyWorld.FLANK*float(r.spread)
	return [r.at-along-across,r.at-along+across,r.at+along-across,r.at+along+across]

static func angle_of(p: Vector3) -> float:
	return fposmod(atan2(p.z,p.x),TAU)

func _laid_out(s: int) -> void:
	var l := SkyWorld.layout()
	var notches: Array = l.notches
	var ranges: Array = l.ranges
	# The notches: how many, how far apart.
	var closest := INF
	for i in range(notches.size()):
		for j in range(i+1,notches.size()): closest = minf(closest,absf(angle_difference(float(notches[i].angle),float(notches[j].angle))))
	check(notches.size() == SkyWorld.NOTCHES and closest >= NOTCH_APART,"Seed %d: %d notches, %.0f deg apart at the closest; %d ranges" % [s,notches.size(),rad_to_deg(closest),ranges.size()])
	# Every angle round the ring under some range's crest, but the notches;
	# and none in a notch.
	var spans := []
	for r: Dictionary in ranges:
		var ends := crest_ends(r)
		var a := angle_of(ends[0])
		var b := angle_of(ends[1])
		if angle_difference(a,b) < 0.0:
			var t := a
			a = b
			b = t
		spans.append([a,b])
	var open := 0
	var in_notch := 0
	for k in range(3600):
		var angle := TAU*k/3600.0
		var covered := false
		for sp: Array in spans:
			if angle_difference(float(sp[0]),angle) >= 0.0 and angle_difference(angle,float(sp[1])) >= 0.0: covered = true
		var notch := SkyWorld.in_notch(angle)
		if covered and notch: in_notch += 1
		if not covered and not SkyWorld.in_notch(angle,SkyWorld.NOTCH_INSET+60.0): open += 1
	check(open == 0 and in_notch == 0,"Seed %d: the crests run unbroken round the ring but for the notches (%d tenths of a degree open, %d of a crest in a notch)" % [s,open,in_notch])
	# Clear of the bounds, and the whole within WORLD.
	var nearest := INF
	var farthest := 0.0
	for r: Dictionary in ranges:
		for p: Vector3 in footprint(r):
			nearest = minf(nearest,Vector2(p.x,p.z).length())
			farthest = maxf(farthest,maxf(absf(p.x),absf(p.z)))
	check(nearest >= SkyWorld.SCATTER+GAP and farthest <= WORLD,"Seed %d: every range's footprint %.0f m out at the nearest (bounds %.0f m), the world within %.0f m (%.0f m)" % [s,nearest,SkyWorld.SCATTER,WORLD,farthest])

func _deterministic() -> void:
	SkyWorld.seed = 99
	var a := str(SkyWorld.layout())
	SkyWorld.seed = 7
	var b := str(SkyWorld.layout())
	SkyWorld.seed = 99
	var c := str(SkyWorld.layout())
	check(a == c and a != b,"A seed always lays the same ring, another seed another")
	SkyWorld.seed = SkyWorld.LEGACY_SEED

## The plate, the fixed islands and the wonders in sight of the plate stand
## inside the bounds; nothing scattered stands outside them.
func _inside() -> void:
	var ok := true
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	for s: Vector3 in slots:
		if not SkyWorld.inside(s,SkyIslands.HALF*1.5): ok = false
	for w: Array in SkyHomes.spots():
		if not SkyWorld.inside(w[0]): ok = false
	check(ok,"The plate, the fixed islands and the wonders in sight of the plate stand inside the bounds")
	for s: int in [7,99]:
		SkyWorld.seed = s
		var cells := SkyCells.new(slots)
		var islets: Node3D = SkyIslets.new()
		islets.cells = cells
		var counts := {"island":0,"islet":0,"tower":0}
		var out := ""
		var reach := 6000.0
		for x in range(int(-reach/SkyCells.CELL),int(reach/SkyCells.CELL)+1):
			for z in range(int(-reach/SkyCells.CELL),int(reach/SkyCells.CELL)+1):
				var found: Variant = cells.spot(Vector2i(x,z))
				if found == null: continue
				counts.island += 1
				if Vector2(found.x,found.z).length() > SkyWorld.SCATTER: out += " island %s;" % found
		for x in range(int(-reach/SkyIslets.CELL),int(reach/SkyIslets.CELL)+1,2):
			for z in range(int(-reach/SkyIslets.CELL),int(reach/SkyIslets.CELL)+1,2):
				var found: Variant = islets.spot(Vector2i(x,z))
				if found == null: continue
				counts.islet += 1
				if Vector2(found.x,found.z).length() > SkyWorld.SCATTER: out += " islet %s;" % found
		for x in range(-4,5):
			for z in range(-4,5):
				var found: Variant = SkyTowers.spot(Vector2i(x,z))
				if found == null: continue
				counts.tower += 1
				if Vector2(found.x,found.z).length() > SkyWorld.SCATTER: out += " tower %s;" % found
		islets.free()
		check(out == "" and counts.island > 20 and counts.islet > 40 and counts.tower >= 1,"Seed %d: nothing scattered stands outside the bounds (%s)%s" % [s,counts,out])
	SkyWorld.seed = SkyWorld.LEGACY_SEED
	# Wandering: inside, an island turns up ahead; heading out at the edge,
	# none turns up past it.
	var grid := SkyCells.new(slots)
	var found: Variant = null
	for i in range(int((SkyCells.WANDER_TIME+1.0)/DT)):
		found = grid.advance(DT,Vector3(900.0,0.0,900.0),-PI*0.75,[Vector3.ZERO],0.0)
		if found != null: break
	var edge := SkyCells.new(slots)
	var beyond: Variant = null
	for i in range(int((SkyCells.WANDER_TIME*2.0)/DT)):
		var past: Variant = edge.advance(DT,Vector3(SkyWorld.SCATTER-150.0,0.0,0.0),-PI*0.5,[Vector3.ZERO],0.0)
		if past != null and not SkyWorld.inside(past.home): beyond = past
	check(found != null and SkyWorld.inside(found.home) and beyond == null,"Wandering inside, an island turns up ahead; heading out at the edge, none turns up past it")

# --- The real ring ---------------------------------------------------------------------

## Every ring range made: [{shape, at, turn, spread}].
func _made() -> Array:
	var out := []
	for r: Dictionary in SkyWorld.layout().ranges:
		out.append({"shape":SkyPeak.make(int(r.seed),float(r.stature)),"at":r.at,"turn":float(r.turn),"spread":float(r.spread)})
	return out

## The highest rock of `made` at a home point, or -INF.
static func rock(made: Array, p: Vector2) -> float:
	var top := -INF
	for m: Dictionary in made:
		var at: Vector3 = m.at
		var d := Vector2(p.x-at.x,p.y-at.z)
		var spread: float = m.spread
		if d.length() > SkyPeak.HALF.length()*spread: continue
		var local := Vector3(d.x,0.0,d.y).rotated(Vector3.UP,-float(m.turn))/spread
		var h: Variant = m.shape.height_at(Vector2(local.x,local.z))
		if h != null: top = maxf(top,float(h))
	return top

func _shaped(s: int) -> void:
	var began := Time.get_ticks_msec()
	var made := _made()
	print("     seed %d: %d ranges made in %.1f s" % [s,made.size(),(Time.get_ticks_msec()-began)/1000.0])
	# Round the ring, every fifth of a degree: is any rock over the sea on
	# the way out through it, and how high does the ring stand there?
	var steps := 1800
	var walled: Array[bool] = []
	var tops: Array[float] = []
	var nearest := INF
	var farthest := 0.0
	for k in range(steps):
		var angle := TAU*k/steps
		var c := SkyWorld.crest(angle)
		var way := Vector2(cos(angle),sin(angle))
		var top := -INF
		var r := c-1100.0
		while r <= c+1100.0:
			var h := rock(made,way*r)
			if h > SkyPeak.SEA:
				nearest = minf(nearest,r)
				farthest = maxf(farthest,maxf(absf(way.x*r),absf(way.y*r)))
			top = maxf(top,h)
			r += 8.0
		walled.append(top > SkyPeak.SEA)
		tops.append(top)
	# Open stretches outside the notches, in metres along the crest line.
	var widest := 0.0
	var slots := 0
	var run := 0.0
	var start := 0
	while start < steps and not walled[start]: start += 1
	for i in range(steps+1):
		var k := (start+i)%steps
		var angle := TAU*k/steps
		if not walled[k] and not SkyWorld.in_notch(angle,SkyWorld.NOTCH_INSET+80.0):
			run += SkyWorld.crest(angle)*TAU/steps
		elif run > 0.0:
			widest = maxf(widest,run)
			slots += 1
			run = 0.0
	check(widest <= SLOT,"Seed %d: the ring's rock closes it but for the notches; %d slots through it, the widest %.0f m (a gorge's at most %.0f m)" % [s,slots,widest,SLOT])
	# The notches: open at glide height across their middle.
	var shut := 0
	var looked := 0
	for n: Dictionary in SkyWorld.layout().notches:
		var half := float(n.arc)*0.4/SkyWorld.crest(float(n.angle))
		for k in range(steps):
			var angle := TAU*k/steps
			if absf(angle_difference(angle,float(n.angle))) > half: continue
			looked += 1
			if tops[k] > SkyGlide.FLOOR: shut += 1
	check(shut == 0 and looked > 0,"Seed %d: every notch is open at glide height across its middle (%d of %d looked at shut)" % [s,shut,looked])
	# The saddles where two ranges meet: the ring's top across the joint.
	var ranges: Array = SkyWorld.layout().ranges
	var saddles: Array[float] = []
	for i in range(ranges.size()):
		var a: Dictionary = ranges[i]
		var b: Dictionary = ranges[(i+1)%ranges.size()]
		var ea := crest_ends(a)
		var eb := crest_ends(b)
		var best := INF
		var joint := Vector3.ZERO
		for p: Vector3 in ea:
			for q: Vector3 in eb:
				if p.distance_to(q) < best:
					best = p.distance_to(q)
					joint = (p+q)*0.5
		if best > 1000.0: continue
		var k := int(round(angle_of(joint)/TAU*steps))%steps
		if SkyWorld.in_notch(TAU*k/steps,SkyWorld.NOTCH_INSET+80.0): continue
		var saddle := -INF
		for d in range(-1,2): saddle = maxf(saddle,tops[(k+d+steps)%steps])
		saddles.append(saddle)
	saddles.sort()
	var high := -INF
	for t in tops: high = maxf(high,t)
	print("     seed %d: %d saddles where ranges meet, %s m over the islands' plane; the highest summit %.0f m" % [s,saddles.size(),str(saddles.map(func(v: float) -> int: return roundi(v))),high])
	check(not saddles.is_empty() and saddles[0] > SkyPeak.SEA+20.0,"Seed %d: where two ranges meet the ring dips to a saddle, never down to the cloud (the lowest %.0f m)" % [s,saddles[0] if not saddles.is_empty() else -INF])
	# Clear of the bounds and within the world.
	check(nearest >= SkyWorld.SCATTER+GAP and farthest <= WORLD,"Seed %d: the ring's rock stands %.0f m out at the nearest (bounds %.0f m, %.0f m clear), all within %.0f m (%.0f m)" % [s,nearest,SkyWorld.SCATTER,nearest-SkyWorld.SCATTER,WORLD,farthest])
	# Clear of the range in sight of the plate.
	var home: RefCounted = SkyPeak.make(SkyPeaks.seed_of(Vector2i.ZERO),SkyPeaks.stature_of(Vector2i.ZERO))
	var home_far := 0.0
	for j in range(0,home.nz,3):
		for i in range(0,home.nx,3):
			if home.heights[j*home.nx+i] <= SkyPeak.SEA: continue
			var p: Vector2 = home.point(i,j)
			var g := SkyPeaks.HOME+Vector3(p.x,0.0,p.y).rotated(Vector3.UP,SkyPeaks.HOME_TURN)
			home_far = maxf(home_far,Vector2(g.x,g.z).length())
	check(nearest-home_far >= GAP,"Seed %d: the ring's rock stands %.0f m clear of the range in sight of the plate (its rock reaches %.0f m out)" % [s,nearest-home_far,home_far])

# --- The edge --------------------------------------------------------------------------

func _edge() -> void:
	var calm := true
	var home_way := true
	var strong := true
	var smooth := 0.0
	for k in range(360):
		var angle := TAU*k/360.0
		var way := Vector3(cos(angle),0.0,sin(angle))
		var c := SkyWorld.crest(angle)
		for r in [0.0,1000.0,SkyWorld.SCATTER,c,c+SkyWorld.OUTSIDE-1.0]:
			if not SkyWorld.edge_air(way*r).is_empty(): calm = false
		var past: Dictionary = SkyWorld.edge_air(way*(c+SkyWorld.OUTSIDE+SkyWorld.RAMP+10.0))
		if past.is_empty() or (past.wind as Vector3).dot(-way) < SkyWorld.EDGE_WIND*0.99: strong = false
		var r := c+SkyWorld.OUTSIDE
		while r < c+SkyWorld.OUTSIDE+SkyWorld.RAMP+3000.0:
			var a: Dictionary = SkyWorld.edge_air(way*r)
			var b: Dictionary = SkyWorld.edge_air(way*(r+10.0))
			var wa: Vector3 = a.get("wind",Vector3.ZERO)
			var wb: Vector3 = b.get("wind",Vector3.ZERO)
			smooth = maxf(smooth,(wb-wa).length())
			if not wb.is_zero_approx() and wb.normalized().dot(-way) < 0.999: home_way = false
			r += 50.0
	check(calm,"No edge wind anywhere inside the ring")
	check(strong and home_way,"Past the ring's outer flank the wind blows home, harder than the glide cruises (%.0f m/s over %.0f)" % [SkyWorld.EDGE_WIND,SkyGlide.CRUISE])
	check(smooth < 0.25,"It rises smoothly, no wall (at most %.2f m/s more over 10 m)" % smooth)

## A glide out through every notch: let be, it is turned home; held outward
## in a dive, the wind holds it, rising smoothly, never a wall.
func _glide_home() -> void:
	var air := func(p: Vector3) -> Dictionary: return SkyWorld.edge_air(p)
	var none := func(_p: Vector3) -> Variant: return null
	var bound := 0.0
	var home := true
	var held_bound := 0.0
	var held_slow := 0.0
	for n: Dictionary in SkyWorld.layout().notches:
		var way := Vector3(cos(float(n.angle)),0.0,sin(float(n.angle)))
		var c := SkyWorld.crest(float(n.angle))
		# Let be: a few minutes after flying out through the notch.
		var glide := SkyGlide.new()
		glide.launch(way*(c-200.0)+Vector3.UP*40.0,atan2(-way.x,-way.z),SkyGlide.CRUISE,false)
		var out := 0.0
		for i in range(int(240.0/DT)):
			glide.step(DT,{},none,air)
			out = maxf(out,Vector2(glide.position.x,glide.position.z).length()-c)
		bound = maxf(bound,out)
		var flat := Vector2(glide.position.x,glide.position.z)
		var moving := Vector2(glide.velocity.x,glide.velocity.z)
		if flat.length()-c > SkyWorld.OUTSIDE+SkyWorld.RAMP and moving.dot(flat) > 0.0: home = false
		# Held outward, nose down: pushed back all the same.
		var held := SkyGlide.new()
		held.launch(way*(c-200.0)+Vector3.UP*40.0,atan2(-way.x,-way.z),SkyGlide.CRUISE,false)
		var held_out := 0.0
		var late := 0.0
		for i in range(int(360.0/DT)):
			held.heading = atan2(-way.x,-way.z)
			held.step(DT,{"dive":1.0},none,air)
			held_out = maxf(held_out,Vector2(held.position.x,held.position.z).length()-c)
			late = Vector2(held.velocity.x,held.velocity.z).dot(Vector2(way.x,way.z))
		held_bound = maxf(held_bound,held_out)
		held_slow = maxf(held_slow,late)
	check(home and bound < SkyWorld.OUTSIDE+SkyWorld.RAMP+600.0,"Flown out through a notch and let be, the glide is turned home (at most %.0f m past the crest line)" % bound)
	check(held_slow < 2.0 and held_bound < SkyWorld.OUTSIDE+SkyWorld.RAMP+1500.0,"Held outward in a dive, the edge wind holds it all the same (at most %.0f m past the crest line, making %.1f m/s outward by the end), never a wall" % [held_bound,held_slow])

# --- Saved worlds ----------------------------------------------------------------------

func _saved() -> void:
	var islands: Node3D = SkyIslands.new()
	islands.load_state({})
	check(SkyWorld.seed == SkyWorld.LEGACY_SEED and int(islands.save_state().get("seed",-1)) == SkyWorld.LEGACY_SEED,"A new world takes the legacy seed and saves it")
	islands.load_state({"origin":[0.0,0.0,0.0],"plate_seed":-1,"built":[],"seed":99})
	check(SkyWorld.seed == 99 and int(islands.save_state().seed) == 99,"A world's seed is read back from its save")
	islands.load_state({"origin":[0.0,0.0,0.0],"plate_seed":-1,"built":[]})
	check(SkyWorld.seed == SkyWorld.LEGACY_SEED,"A save from before the seed reads as the legacy seed")
	# A world saved before the ring, with an island out where it stands.
	var before: int = SkyWorld.layout().ranges.size()
	var r: Dictionary = SkyWorld.layout().ranges[2]
	var far: Vector3 = r.at+Vector3(0.0,-10.0,0.0)
	islands.load_state({"origin":[-far.x,10.0,-far.z],"plate_seed":-1,"built":[{"home":[far.x+400.0,0.0,far.z],"label":"Far","document":{}}]})
	var after: Array = SkyWorld.layout().ranges
	var clear := true
	for q: Dictionary in after:
		for h: Vector3 in [far,far+Vector3(400.0,0.0,0.0)]:
			if Vector2(q.at.x-h.x,q.at.z-h.z).length() < SkyWorld.CREST_HALF*float(q.spread): clear = false
	var calm := SkyWorld.edge_air(far).is_empty() and SkyWorld.edge_air(far+Vector3(400.0,0.0,0.0)).is_empty()
	check(after.size() < before and clear and calm,"Islands saved out where the ring stands keep their place: %d of %d ranges leave them room, and no edge wind blows there" % [after.size(),before])
	islands.load_state({})
	check(SkyWorld.layout().ranges.size() == before and SkyWorld.kept.is_empty(),"Islands inside the bounds change nothing")
	islands.free()

# --- The skyline -----------------------------------------------------------------------

func _skyline() -> void:
	var cells := SkyCells.new([Vector3.ZERO])
	var currents: Node3D = SkyCurrents.new()
	root.add_child(currents)
	currents.build([Vector3.ZERO])
	var peaks: Node3D = SkyPeaks.new()
	root.add_child(peaks)
	var began := Time.get_ticks_msec()
	peaks.ring.warm(peaks)
	peaks.reset(cells,currents)
	peaks.flush()
	var count: int = SkyWorld.layout().ranges.size()
	print("     the skyline's %d ranges made in %.1f s (workers)" % [count,(Time.get_ticks_msec()-began)/1000.0])
	var faces := 0
	for key in peaks.ring.lines: faces += (peaks.ring.lines[key].node.get_node("Body").mesh as ArrayMesh).surface_get_array_len(0)/3
	check(peaks.ring.line_count() == count,"Every ring range stands far off as a skyline (%d, %d faces in all)" % [count,faces])
	# Near one of them: it is made in full, and its skyline steps aside.
	var r: Dictionary = SkyWorld.layout().ranges[0]
	var cell := Vector2i(SkyPeaks.RING_ROW,int(r.index))
	var key: String = peaks._key(cell)
	var eye: Vector3 = r.at*0.85
	peaks.advance(1.0,eye)
	peaks.flush()
	check(peaks.built.has(key) and not peaks.ring.showing(key),"Flown near, the range is made in full and its skyline steps aside")
	var shown := 0
	for k in peaks.ring.lines:
		if peaks.ring.showing(k): shown += 1
	check(shown == count-_ring_built(peaks),"Every ring range not made in full still shows as skyline (%d)" % shown)
	check(peaks.body(r.at+Vector3(0.0,500.0,0.0)) != null or _solid_somewhere(peaks,r),"The ring range made in full is a solid to the glide")
	# Its jet runs in through its gorge, toward the world's middle.
	var inward := true
	var jets := 0
	for c: Dictionary in currents.currents:
		if not str(c.get("key","")).begins_with("peak:%d," % SkyPeaks.RING_ROW): continue
		jets += 1
		var pts: PackedVector3Array = c.points
		if Vector2(pts[0].x,pts[0].z).length() <= Vector2(pts[pts.size()-1].x,pts[pts.size()-1].z).length(): inward = false
	check(jets > 0 and inward,"A ring range's jet runs in through its gorge, toward the world's middle (%d)" % jets)
	# Flown back to the middle: let go, and the skyline back.
	peaks.advance(1.0,Vector3.ZERO)
	peaks.flush()
	check(not peaks.built.has(key) and peaks.ring.showing(key),"Flown away, it is let go and its skyline comes back")
	# A new glide keeps the skyline made.
	peaks.reset(cells,currents)
	check(peaks.ring.line_count() == count and peaks.ring._making.is_empty(),"A new glide keeps the skyline as it was, nothing made again")
	peaks.queue_free()
	currents.queue_free()

func _ring_built(peaks: Node3D) -> int:
	var n := 0
	for key in peaks.built:
		if SkyPeaks.is_ring(peaks.built[key].cell): n += 1
	return n

func _solid_somewhere(peaks: Node3D, r: Dictionary) -> bool:
	for dx in range(-400,401,40):
		for dz in range(-400,401,40):
			if peaks.body(r.at+Vector3(dx,0.0,dz)) != null: return true
	return false

# --- The haze --------------------------------------------------------------------------

func _haze() -> void:
	var middle := Vector3.ZERO
	# From the plate, the ring stands in sight; on the far side of the world
	# from its edge, it is all but gone.
	var near_seen := 1.0-SkyHaze.fog_ring(SkyWorld.RADIUS,60.0)
	var island_seen := 1.0-SkyHaze.fog(SkyWorld.RADIUS,60.0)
	var across := 1.0-SkyHaze.fog_ring(SkyWorld.RADIUS*2.2,60.0)
	check(near_seen > 0.3 and island_seen < 0.01,"From the plate the ring stands in sight (%.0f%% seen at %.0f m, where an island would be gone)" % [near_seen*100.0,SkyWorld.RADIUS])
	check(across < 0.05,"From one edge, the far side of the ring is all but gone (%.1f%% seen)" % (across*100.0))
	check(SkyWorld.VIEW_FAR > SkyWorld.HAZE_WHOLE,"The glide's view reaches past where the ring's haze is whole (%.0f m)" % SkyWorld.VIEW_FAR)
	# Nothing scattered takes the ring's curve: the bounds stand inside it.
	check(SkyHaze.ring_share(Vector3(SkyWorld.SCATTER+50.0,0.0,0.0),middle) == 0.0 and SkyHaze.ring_share(Vector3(SkyWorld.SCATTER+GAP,0.0,0.0),middle) > 0.0,"The islands' haze keeps to the bounds; the ring's rock takes its own")
	var spot := SkyHaze.ring_spot(Vector3(100.0,0.0,-50.0))
	check(spot == Vector4(100.0,-50.0,SkyWorld.HAZE_FROM,SkyWorld.HAZE_TO),"The shader is told where the world's middle is now")
