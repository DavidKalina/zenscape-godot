extends RefCounted
## The sky world's shape: one seed every placement in the sky reads, a
## bounded world laid out as a whole, mountains through its middle and a
## mountain band round its edge.
##
## The seed: every kind scattered through the sky hashes its cells with
## `seed` (`noise`: scripts/sky_cells.gd, sky_islets.gd, sky_peaks.gd,
## sky_towers.gd, sky_pillars.gd, sky_forest_isles.gd), and the drifting
## clouds take theirs from it (`salted`). It is saved with the world
## (SkyIslands `save_state`); a world saved before it had one reads as
## LEGACY_SEED, the number every hash used before, so its sky stands as it
## did. `--sky-seed=N` tries another.
##
## The bounds: the plate's first home (home coordinates, the origin) is the
## world's middle. Islands, islets, cumulus and clouds stand only within
## SCATTER of it (`inside`, read through SkyPeaks `blocks`), and keep clear
## of every range laid out here (SkyPeaks `blocks`).
##
## Every range is a real one (scripts/sky_peak.gd, made by seed), placed
## and scaled here: `scale` stretches it along its crest (x), across (z)
## and in height (y, about the cloud sea's top, so its foot stays in the
## sea). The whole is laid out once per seed (`layout`), each kind against
## those laid before it, so nothing stands on anything else:
##
##   the band round the edge (kind "run" and "massif"): ranges end to end
##     round a crest line about RADIUS out that bulges out at the massifs and
##     pinches in between (`crest`). Each range is laid by where its planned
##     crest stands over SADDLE (SkyPeak `crest_span`), from one joint to the
##     next, its crest ends meeting the next range's on the line, so where
##     two meet the crests cross over SADDLE high: over the glide's ceiling.
##     MASSIFS giant massifs (taller, longer, deeper) stand where it bulges,
##     the lower runs between them. Only GORGES of the runs keep their gorge
##     (an optional tight line through, its jet running in); the rest are
##     whole. NOTCHES clear gaps, NOTCH_ARC wide at the glide's height, stay
##     open round it, low shoulders either side: the only other ways
##     through, kept for valleys to be carved later;
##   foothills (kind "foot"): low ranges in front of the band on its inner
##     side, before the massifs and where the band bulges out, so the big
##     peaks stand behind lower ones;
##   the far row (kind "far"): a few tall ranges out behind the band,
##     fading into the haze;
##   the inner ranges (kind "inner"): INNER ranges within the bounds, out
##     past the island groups, their crests running round with the band,
##     of varied heights (one under the glide's ceiling), CORRIDOR clear of
##     each other and of the range in sight of the plate, a valley running
##     round between them and the band; clear of the plate, the
##     fixed islands, the cumulus and the islands' jet streams.
##
## Ranges on an island the world has saved (`kept`) are left out: a world
## saved before the ring might have one out where it would stand.
##
## The edge: no wall. Past the band (OUTSIDE past the crest line) an edge
## wind rises over RAMP metres, blowing back toward the middle harder than
## the glide cruises, and turns an unsteered glide home (`edge_air`, read
## by SkyIslands `air`). Never a hard stop, and never past a saved island:
## the wind starts KEPT_ROOM past the farthest one.
##
## Seen from afar: the band's rock takes a haze curve of its own
## (HAZE_REACH, HAZE_WHOLE: shaders/glide_haze.gdshaderinc
## zs_glide_fog_ring), so it stands as a skyline right across the world,
## and the glide's view reaches VIEW_FAR. Every range stands as a coarse
## skyline far off (scripts/sky_ring.gd) and as the full range near
## (SkyPeaks).
##
## `ring` (on unless `--no-ring`) turns all of this on together; off, the
## sky is the old open one, endless, its ranges scattered through the cells.
## It is made of the peaks, so it stands only while they do (SkyHomes
## `peaks`).

const SkyHomes = preload("res://scripts/sky_homes.gd")
const SkyPeak = preload("res://scripts/sky_peak.gd")

## The seed every hash used before there was one; and the world's.
const LEGACY_SEED := 7
static var seed := LEGACY_SEED
## The ring, the bounds and the edge wind.
static var ring := true
## The homes of every island the world has saved, and the plate's own (home
## coordinates): the ranges keep clear of them and the edge wind holds them.
static var kept: Array[Vector3] = []

## The fixed islands (SkyIslands OFFSETS, kept equal: tests/
## test_sky_world.gd), the plate at the origin among them.
const SLOTS := [Vector3.ZERO,Vector3(380.0,-20.0,-160.0),Vector3(-260.0,25.0,-520.0),Vector3(-640.0,-35.0,120.0),Vector3(180.0,-50.0,700.0),Vector3(820.0,15.0,420.0)]
## Everything scattered stands within SCATTER (m) of the middle.
const SCATTER := 2200.0
## The band's rock stands at least GAP (m) past the bounds.
const GAP := 150.0
## The crest line: its mean radius (m); its waves twice, three and five
## times round (m); and how far it bulges out at a massif (m) over how wide
## (radians).
const RADIUS := 3150.0
const WAVES := Vector3(70.0,45.0,25.0)
const BULGE := 280.0
const BULGE_WIDTH := 0.5
## A range's rock over the sea reaches about this far each side of its
## middle along its crest, and across it (m, before its scale).
const SEA_HALF := 720.0
const FLANK := 420.0
## The band's saddles stand at least SADDLE (m) high, over the glide's
## ceiling (SkyGlide CEILING and CEILING_FADE); a range is laid by where its
## planned crest stands HEADROOM over that (the erosion and the crest's
## notches take a little off). Neighbours' crests meet JOIN (m) along the
## line; each joint jogs up to JOG (m) in or out of it.
const SADDLE := 135.0
const HEADROOM := 75.0
const JOIN := 70.0
const JOG := 50.0
## The band's runs and massifs: their scale (x and z: along and across the
## crest, y: height), and stature.
const RUN_X := Vector2(1.4,1.9)
const RUN_Z := Vector2(1.0,1.1)
const RUN_Y := Vector2(0.95,1.05)
const RUN_STATURE := Vector2(0.88,1.0)
const MASSIFS := Vector2i(2,3)
const MASSIF_X := Vector2(1.8,2.1)
const MASSIF_Z := Vector2(1.25,1.4)
const MASSIF_Y := Vector2(1.28,1.38)
## How many of the runs keep their gorge (at least, at most).
const GORGES := Vector2i(2,3)
## The foothills: two before each massif, and up to FOOT_MORE where the band
## bulges enough; FOOT_IN (m) in front of the crest line; their scale.
const FOOT_MORE := 3
const FOOT_IN := 650.0
const FOOT_X := Vector2(0.9,1.2)
const FOOT_Z := Vector2(0.7,0.8)
const FOOT_Y := Vector2(0.45,0.6)
## The far row: how many, how far out past the crest line (m), their scale.
const FAR := 5
const FAR_OUT := 1000.0
const FAR_X := Vector2(1.8,2.1)
const FAR_Z := Vector2(1.2,1.3)
const FAR_Y := Vector2(1.3,1.45)
## The inner ranges: how many, how far out their middles stand (m), their
## scale along and across, and their heights (one each, shuffled: the first
## brings the summits under the glide's ceiling). Kept CORRIDOR (m) from
## each other's rock, the range in sight of the plate's and the band's,
## PLATE_ROOM (m) from the plate, ISLAND_ROOM from a fixed island, AIR_ROOM
## from the islands' jet streams.
const INNER := 3
const INNER_AT := Vector2(1350.0,1700.0)
const INNER_X := Vector2(0.65,0.9)
const INNER_Z := Vector2(0.7,0.85)
const INNER_Y := [0.45,0.8,1.05]
const INNER_TURN := 0.5
const CORRIDOR := 300.0
const PLATE_ROOM := 600.0
const ISLAND_ROOM := 250.0
const AIR_ROOM := 120.0
## The notches: how many, how wide (m along the crest line), and how far
## each may stray (radians) from an even share of the ring.
const NOTCHES := 3
const NOTCH_ARC := 600.0
const NOTCH_STRAY := 0.35
## The ranges either side stand this far back from a notch's edge (m).
const NOTCH_INSET := 80.0
## A range's low end beside a notch may run this far (m) into the inset and
## the notch's edge, falling into the sea: the notch's shoulders.
const SHOULDER := 150.0
## The low shoulder before a range's crest by a notch: no longer than
## LEAD_MOST (m) if a few draws can help it.
const LEAD_MOST := 250.0
## The edge wind: from OUTSIDE (m) past the crest line it rises over RAMP
## (m) to EDGE_WIND (m/s, over the glide's cruise), on past that a little
## harder each kilometre (EDGE_GROW, share), up to EDGE_MOST times (past the
## glide's fastest), so no glide makes headway for long; it turns
## an unsteered glide home by EDGE_VANE (SkyGlide `along`). KEPT_ROOM (m)
## past the farthest saved island before it starts.
const OUTSIDE := 750.0
const RAMP := 900.0
const EDGE_WIND := 8.0
const EDGE_GROW := 1.0
const EDGE_MOST := 5.5
const EDGE_VANE := 0.35
const KEPT_ROOM := 800.0
## The band's haze: the rock past HAZE_FROM (m from the middle) takes the
## band's curve, fully by HAZE_TO; its reach and where it is whole (m).
const HAZE_FROM := SCATTER+60.0
const HAZE_TO := SCATTER+460.0
const HAZE_REACH := 3500.0
const HAZE_WHOLE := 8500.0
## How far the glide's view reaches with the ring (m), and without.
const VIEW_FAR := 9000.0
const VIEW_OPEN := 3000.0
## The salt for the layout's hashes.
const SALT := 9100

static var _layout := {}
## The seed and saved islands the layout was worked out for, and whether
## `kept` has changed since.
static var _layout_key := ""
static var _layout_seed := -1
static var _kept_changed := true
## The crest line's frame for a seed: its waves' phases, the notches' and
## the massifs' angles.
static var _frame := {}
static var _frame_seed := -1

## True while the ring, the bounds and the edge wind stand.
static func ring_on() -> bool:
	read_flags()
	return ring and (SkyHomes.peaks or SkyHomes.stone)

## How much of the Opal cloud sea's painted distant peaks to draw (shaders/
## sky_cloud_sea_opal.gdshaderinc `sea_peaks`): none while the ring's real
## ranges stand (they travel with the eye and read wrong beside them).
static func sea_peaks() -> float:
	return 0.0 if ring_on() else 1.0

static var _flags_read := false

## Reads `--no-ring` and `--no-peaks` from the command line, once, whoever
## asks first (the look pass sets the sky before the glide's islands exist).
static func read_flags() -> void:
	if _flags_read: return
	_flags_read = true
	var args := OS.get_cmdline_user_args()
	if "--no-ring" in args: ring = false
	if "--no-peaks" in args: SkyHomes.peaks = false

## `--sky-seed=N`, or -1.
static func seed_flag() -> int:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--sky-seed=") and a.trim_prefix("--sky-seed=").is_valid_int(): return int(a.trim_prefix("--sky-seed="))
	return -1

## A hash of a cell, 0 to 1, one per salt, under the world's seed: the one
## every kind's cells read.
static func noise(cell: Vector2i, salt: int) -> float:
	var h := cell.x*73856093^cell.y*19349663^salt*83492791^seed*2654435761
	h = (h^(h >> 13))*1274126177
	h = (h^(h >> 16))*668265263
	h ^= h >> 15
	return float(h & 0xFFFFFF)/float(0x1000000)

## A fixed seed (`base`) turned by the world's: `base` itself under the
## LEGACY_SEED, so an old world's sky is unchanged.
static func salted(base: int) -> int:
	if seed == LEGACY_SEED: return base
	return int(noise(Vector2i(base,seed),SALT+77)*2147483647.0)

# --- The bounds ----------------------------------------------------------------------

## True if a home point stands within the bounds (SCATTER), less `margin`;
## always, with the ring off.
static func inside(home: Vector3, margin := 0.0) -> bool:
	if not ring_on(): return true
	return Vector2(home.x,home.z).length() <= SCATTER-margin

## The crest line's frame for the world's seed: {phase: Vector3, notches,
## massifs: Array[float] (angles)}. The massifs stand midway between two
## notches, in MASSIFS of the stretches.
static func frame() -> Dictionary:
	if _frame_seed == seed: return _frame
	_frame_seed = seed
	var rng := RandomNumberGenerator.new()
	rng.seed = int(noise(Vector2i(seed,1),SALT)*2147483647.0)
	var phase := Vector3(rng.randf(),rng.randf(),rng.randf())*TAU
	var first := rng.randf()*TAU
	var notches: Array[float] = []
	for k in range(NOTCHES): notches.append(fposmod(first+TAU*k/NOTCHES+rng.randf_range(-NOTCH_STRAY,NOTCH_STRAY),TAU))
	notches.sort()
	var count := rng.randi_range(MASSIFS.x,MASSIFS.y)
	var skip := rng.randi_range(0,NOTCHES-1)
	var massifs: Array[float] = []
	for k in range(NOTCHES):
		if massifs.size() >= count or (count < NOTCHES and k == skip): continue
		var a := notches[k]
		var b := notches[(k+1)%NOTCHES]+(TAU if k == NOTCHES-1 else 0.0)
		massifs.append(fposmod(lerpf(a,b,rng.randf_range(0.4,0.6)),TAU))
	_frame = {"phase":phase,"notches":notches,"massifs":massifs}
	return _frame

## The crest line's radius (m) at an angle round the middle (radians, from
## +x toward +z): out at the massifs, in and out on its waves.
static func crest(angle: float) -> float:
	var f := frame()
	var p: Vector3 = f.phase
	var r := RADIUS+WAVES.x*sin(2.0*angle+p.x)+WAVES.y*sin(3.0*angle+p.y)+WAVES.z*sin(5.0*angle+p.z)
	for m: float in f.massifs:
		var d := angle_difference(angle,m)/BULGE_WIDTH
		r += BULGE*exp(-d*d)
	return r

## A point on the crest line (home, y 0), `out` m past it.
static func crest_point(angle: float, out := 0.0) -> Vector3:
	var r := crest(angle)+out
	return Vector3(cos(angle)*r,0.0,sin(angle)*r)

## The air the edge adds at a home point: {wind (m/s), along (the way home,
## for the glide's vane)}, or empty inside.
static func edge_air(home: Vector3) -> Dictionary:
	if not ring_on(): return {}
	var flat := Vector2(home.x,home.z)
	var r := flat.length()
	if r < 1.0: return {}
	var from := edge_from(atan2(flat.y,flat.x))
	if r <= from: return {}
	var k := smoothstep(from,from+RAMP,r)
	k *= minf(1.0+EDGE_GROW*maxf(0.0,r-from-RAMP)/1000.0,EDGE_MOST)
	var home_way := -flat/r
	return {"wind":Vector3(home_way.x,0.0,home_way.y)*EDGE_WIND*k,"along":Vector3(home_way.x,0.0,home_way.y)*EDGE_VANE*minf(k,1.0)}

## Where the edge wind starts at an angle (m from the middle).
static func edge_from(angle: float) -> float:
	var from := crest(angle)+OUTSIDE
	for h: Vector3 in kept: from = maxf(from,Vector2(h.x,h.z).length()+KEPT_ROOM)
	return from

# --- The layout ----------------------------------------------------------------------

## True for the kinds standing in the band round the edge (and its far
## row), false for the inner ranges.
static func in_band(kind: String) -> bool:
	return kind != "inner"

## The whole world's ranges for its seed (and its saved islands), worked
## out once: {ranges: [{index, kind, at (home), turn, seed, stature, scale
## (Vector3), gorge (bool), angle}], notches: [{angle, arc (m), at (home,
## on the crest line)}], massifs: [angles]}. A range's index stays its own
## when one before it is left out for a saved island.
static func layout() -> Dictionary:
	if _layout_seed == seed and not _kept_changed: return _layout
	var key := "%d|%s" % [seed,str(kept)]
	_layout_seed = seed
	_kept_changed = false
	if key == _layout_key: return _layout
	_layout_key = key
	var f := frame()
	_layout = {"ranges":[],"notches":[],"massifs":f.massifs}
	for a: float in f.notches: _layout.notches.append({"angle":a,"arc":NOTCH_ARC,"at":crest_point(a)})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(noise(Vector2i(seed,3),SALT)*2147483647.0)
	# The band, a stretch between each notch and the next.
	var ranges: Array = []
	var notches: Array = f.notches
	for k in range(NOTCHES):
		var start: float = notches[k]+_half_notch(notches[k])
		var end: float = notches[(k+1)%NOTCHES]+(TAU if k == NOTCHES-1 else 0.0)-_half_notch(notches[(k+1)%NOTCHES])
		ranges.append_array(_stretch(start,end,f.massifs,rng))
	_gorges(ranges,rng)
	ranges.append_array(_foothills(ranges,rng))
	ranges.append_array(_far_row(rng))
	ranges.append_array(_inner(ranges,rng))
	# None on a saved island.
	for i in range(ranges.size()):
		var r: Dictionary = ranges[i]
		r.index = i
		for h: Vector3 in kept:
			if box_distance(r,Vector2(h.x,h.z)) < 250.0: r.index = -1
	for r: Dictionary in ranges:
		if r.index >= 0: _layout.ranges.append(r)
	return _layout

## Half a notch's width, and the ranges' inset from it, as an angle at its
## place on the crest line.
static func _half_notch(angle: float) -> float:
	return (NOTCH_ARC*0.5+NOTCH_INSET)/crest(angle)

## The crest line's length (m) from one angle to another.
static func _length(from: float, to: float) -> float:
	var total := 0.0
	var steps := maxi(8,int((to-from)/0.004))
	var d := (to-from)/steps
	for i in range(steps): total += crest(from+(i+0.5)*d)*d
	return total

## The angle `along` metres down the crest line from `from`.
static func _walk(from: float, along: float) -> float:
	var a := from
	var left := along
	for i in range(100000):
		var piece := crest(a+0.002)*0.004
		if piece >= left: return a+0.004*left/piece
		left -= piece
		a += 0.004
	return a

## A range of `kind` drawn from `rng`: its seed, stature and scale, and
## where its planned crest stands over SADDLE (`span`: its own x, before
## scaling), flipped end for end half the time (`flip`, and `span` as seen
## flipped). Drawn again until its crest stands that high for long enough.
static func _draw(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var xs := MASSIF_X if kind == "massif" else RUN_X
	var zs := MASSIF_Z if kind == "massif" else RUN_Z
	var ys := MASSIF_Y if kind == "massif" else RUN_Y
	for tries in range(40):
		var r := {"kind":kind,"seed":int(rng.randf()*16777216.0),"stature":1.0 if kind == "massif" else rng.randf_range(RUN_STATURE.x,RUN_STATURE.y),
			"scale":Vector3(rng.randf_range(xs.x,xs.y),rng.randf_range(ys.x,ys.y),rng.randf_range(zs.x,zs.y)),"gorge":false,"flip":rng.randf() < 0.5}
		# Over SADDLE once lifted: SEA+(h-SEA)*y.
		var y: float = r.scale.y
		var span := SkyPeak.crest_span(r.seed,r.stature,SkyPeak.SEA+(SADDLE+HEADROOM-SkyPeak.SEA)/y)
		if span.y-span.x < 300.0: continue
		r.span = Vector2(-span.y,-span.x) if r.flip else span
		return r
	push_error("SkyWorld: no range stands high enough")
	return {}

## The band along one stretch of the crest line, from one notch to the
## next: ranges laid crest to crest, each's crest over SADDLE from one joint
## to the next, its rock over the sea stopping short of the notches. The
## first standing nearest a massif's angle is a massif.
static func _stretch(from: float, to: float, massifs: Array, rng: RandomNumberGenerator) -> Array:
	var length := _length(from,to)
	var targets: Array[float] = []
	for m: float in massifs:
		var a := m
		while a < from: a += TAU
		if a < to: targets.append(_length(from,a))
	var drawn := []
	var starts: Array[float] = []
	var at := 0.0
	while true:
		var kind := "run"
		for t in targets:
			if absf(at+700.0-t) < 750.0 and not drawn.any(func(d: Dictionary) -> bool: return d.kind == "massif" and absf(float(d.start)+600.0-t) < 1500.0): kind = "massif"
		var r := _draw(kind,rng)
		# The first: turned so its crest starts nearest the notch, and drawn
		# again while the low shoulder before its crest runs past LEAD_MOST.
		if drawn.is_empty():
			for tries in range(16):
				if r.span.x > -r.span.y: _turn_round(r)
				if _lead(r) <= LEAD_MOST: break
				r = _draw(kind,rng)
		var start: float = _lead(r) if drawn.is_empty() else at-JOIN
		# The last, reaching the stretch's end: likewise, its crest ending
		# nearest the next notch.
		var ends := false
		var best := {}
		var candidate := r
		for tries in range(16):
			var round := candidate.duplicate()
			if -round.span.x > round.span.y: _turn_round(round)
			var reach: float = start+(float(round.span.y)-float(round.span.x))*float(round.scale.x)
			if reach+_tail(round) >= length and (best.is_empty() or _tail(round) < _tail(best)): best = round
			# Not reaching the end: not the last; or one ending near enough.
			if best.is_empty() or _tail(best) <= LEAD_MOST: break
			candidate = _draw(kind,rng)
		if not best.is_empty():
			r = best
			ends = true
		r.start = start
		drawn.append(r)
		starts.append(start)
		at = start+(float(r.span.y)-float(r.span.x))*float(r.scale.x)
		if (ends and at+_tail(r) >= length) or drawn.size() > 40: break
	# Overshot: the joints overlap more, evenly, so the last's rock ends at
	# the stretch's end.
	var last: Dictionary = drawn[-1]
	var over := at+_tail(last)-length
	var n := drawn.size()
	var out := []
	for i in range(n):
		var r: Dictionary = drawn[i]
		var start: float = starts[i]-(over*i/(n-1) if n > 1 else over*0.5)
		var finish: float = start+(float(r.span.y)-float(r.span.x))*float(r.scale.x)
		r.erase("start")
		r.order = i
		r.of = n
		_lay(r,_on_line(from,start),_on_line(from,finish))
		out.append(r)
	# Joints jog together: a range's end and the next's start share one.
	for i in range(n-1):
		var jog := rng.randf_range(-JOG,JOG)
		out[i].jog_end = jog
		out[i+1].jog_start = jog
	for r: Dictionary in out:
		var a: Vector3 = r.p_lo
		var b: Vector3 = r.p_hi
		_lay(r,a+Vector3(a.x,0.0,a.z).normalized()*float(r.get("jog_start",0.0)),b+Vector3(b.x,0.0,b.z).normalized()*float(r.get("jog_end",0.0)))
		r.erase("jog_start")
		r.erase("jog_end")
		# Its inner flank no nearer the bounds than GAP: narrower across
		# where the line runs in.
		var s: Vector3 = r.scale
		s.z = clampf((_nearest(r)-SCATTER-GAP)/FLANK,0.8,s.z)
		r.scale = s
	return out

## How near the middle a range's crest line comes (m), over its rock's whole
## length.
static func _nearest(r: Dictionary) -> float:
	var at: Vector3 = r.at
	var way := Vector3(1.0,0.0,0.0).rotated(Vector3.UP,float(r.turn))
	var half := SEA_HALF*float(r.scale.x)
	var t := clampf(-Vector2(at.x,at.z).dot(Vector2(way.x,way.z)),-half,half)
	var p := at+way*t
	return Vector2(p.x,p.z).length()

## A drawn range turned end for end: its span as seen the other way.
## The low shoulder before a range's crest when it stands first by a notch,
## and after it when last (m along the line, SHOULDER of its rock let into
## the notch's edge).
static func _lead(r: Dictionary) -> float:
	return maxf((float(r.span.x)+SEA_HALF)*float(r.scale.x)-SHOULDER,0.0)

static func _tail(r: Dictionary) -> float:
	return maxf((SEA_HALF-float(r.span.y))*float(r.scale.x)-SHOULDER,0.0)

static func _turn_round(r: Dictionary) -> void:
	r.flip = not r.flip
	r.span = Vector2(-float(r.span.y),-float(r.span.x))

## The point `along` metres down the crest line from `from` (home).
static func _on_line(from: float, along: float) -> Vector3:
	return crest_point(_walk(from,along))

## Lays a drawn range so its crest's span runs from `a` to `b` (home): its
## scale along the crest set by the distance, its turn and middle by the
## way and the span.
static func _lay(r: Dictionary, a: Vector3, b: Vector3) -> void:
	r.p_lo = a
	r.p_hi = b
	var way := (b-a).normalized()
	var s: Vector3 = r.scale
	s.x = a.distance_to(b)/(float(r.span.y)-float(r.span.x))
	r.scale = s
	var lo: float = r.span.x
	r.at = a-way*lo*s.x
	# Local +x along `way`, or against it for one flipped end for end.
	var x := -way if r.flip else way
	r.turn = atan2(-x.z,x.x)
	r.angle = fposmod(atan2(r.at.z,r.at.x),TAU)

## GORGES of the runs keep their gorge: spread round the ring, none at a
## stretch's end (by a notch).
static func _gorges(ranges: Array, rng: RandomNumberGenerator) -> void:
	var candidates := []
	for i in range(ranges.size()):
		var r: Dictionary = ranges[i]
		if r.kind != "run": continue
		# Not first or last in its stretch: both neighbours are its joints.
		if int(r.order) == 0 or int(r.order) == int(r.of)-1: continue
		candidates.append(r)
	# Too few runs inside the stretches: by the notches too.
	if candidates.size() < GORGES.x:
		for r: Dictionary in ranges:
			if r.kind == "run" and r not in candidates: candidates.append(r)
	var count := mini(rng.randi_range(GORGES.x,GORGES.y),candidates.size())
	var chosen := []
	if candidates.is_empty(): return
	chosen.append(candidates[rng.randi_range(0,candidates.size()-1)])
	while chosen.size() < count:
		var best: Dictionary = {}
		var best_gap := -1.0
		for c: Dictionary in candidates:
			var gap := INF
			for d: Dictionary in chosen: gap = minf(gap,absf(angle_difference(float(c.angle),float(d.angle))))
			if gap > best_gap:
				best_gap = gap
				best = c
		chosen.append(best)
	for c: Dictionary in chosen: c.gorge = true

## The foothills: low ranges in front of the band, two before each massif
## and a few more where the band bulges out enough to have room.
static func _foothills(band: Array, rng: RandomNumberGenerator) -> Array:
	var out := []
	var spots: Array[float] = []
	for r: Dictionary in band:
		if r.kind != "massif": continue
		var a: float = r.angle
		var c := crest(a)
		for side in [-1.0,1.0]: spots.append(a+side*rng.randf_range(450.0,650.0)/c)
	# Where the band bulges, out of the massifs' way.
	var tries := 0
	var more := 0
	while more < FOOT_MORE and tries < 200:
		tries += 1
		var a := rng.randf()*TAU
		if crest(a)-FOOT_IN < SCATTER+GAP+FLANK*FOOT_Z.y+60.0: continue
		var clear := true
		for s in spots:
			if absf(angle_difference(a,s))*crest(a) < 1300.0: clear = false
		if not clear or in_notch(a,1200.0): continue
		spots.append(a)
		more += 1
	for a: float in spots:
		if in_notch(a,1100.0): continue
		var s := Vector3(rng.randf_range(FOOT_X.x,FOOT_X.y),rng.randf_range(FOOT_Y.x,FOOT_Y.y),rng.randf_range(FOOT_Z.x,FOOT_Z.y))
		var r := maxf(crest(a)-FOOT_IN,SCATTER+GAP+FLANK*s.z+60.0)
		var foot := {"kind":"foot","seed":int(rng.randf()*16777216.0),"stature":rng.randf_range(0.85,0.95),"scale":s,"gorge":false,
			"at":Vector3(cos(a)*r,0.0,sin(a)*r),"turn":-a-PI*0.5+rng.randf_range(-0.35,0.35)+(PI if rng.randf() < 0.5 else 0.0),"angle":fposmod(a,TAU)}
		# Its whole footprint GAP past the bounds: out a little if not.
		for k in range(6):
			var near := INF
			for p: Vector2 in box_outline(foot): near = minf(near,p.length())
			if near >= SCATTER+GAP+20.0: break
			foot.at = foot.at*(1.0+(SCATTER+GAP+30.0-near)/Vector2(foot.at.x,foot.at.z).length())
		out.append(foot)
	return out

## The far row: FAR tall ranges out behind the band, clear of the notches.
static func _far_row(rng: RandomNumberGenerator) -> Array:
	var out := []
	var first := rng.randf()*TAU
	for k in range(FAR):
		var a := first+TAU*k/FAR+rng.randf_range(-0.25,0.25)
		var s := Vector3(rng.randf_range(FAR_X.x,FAR_X.y),rng.randf_range(FAR_Y.x,FAR_Y.y),rng.randf_range(FAR_Z.x,FAR_Z.y))
		var r := crest(a)+FAR_OUT
		if in_notch(a,SEA_HALF*s.x*crest(a)/r+200.0): continue
		out.append({"kind":"far","seed":int(rng.randf()*16777216.0),"stature":1.0,"scale":s,"gorge":false,
			"at":Vector3(cos(a)*r,0.0,sin(a)*r),"turn":-a-PI*0.5+rng.randf_range(-0.15,0.15),"angle":fposmod(a,TAU)})
	return out

## The inner ranges: out between the island groups, crests running out
## toward the band, clear of everything laid and kept (see the constants).
static func _inner(band: Array, rng: RandomNumberGenerator) -> Array:
	var out := []
	var heights: Array = INNER_Y.duplicate()
	# The low one laid first, so it always finds room; the rest shuffled.
	for k in range(heights.size()-1,1,-1):
		var m := rng.randi_range(1,k)
		var t: float = heights[k]
		heights[k] = heights[m]
		heights[m] = t
	var home := {"at":SkyHomes.RANGE,"turn":SkyHomes.RANGE_TURN,"scale":Vector3.ONE}
	var air := _air()
	for k in range(INNER):
		for tries in range(800):
			var a := rng.randf()*TAU
			var d := rng.randf_range(INNER_AT.x,INNER_AT.y)
			var r := {"kind":"inner","seed":int(rng.randf()*16777216.0),"stature":rng.randf_range(0.85,1.0),
				"scale":Vector3(rng.randf_range(INNER_X.x,INNER_X.y),float(heights[k]),rng.randf_range(INNER_Z.x,INNER_Z.y)),"gorge":true,
				"at":Vector3(cos(a)*d,0.0,sin(a)*d),"turn":-a-PI*0.5+rng.randf_range(-INNER_TURN,INNER_TURN)+(PI if rng.randf() < 0.5 else 0.0),"angle":fposmod(a,TAU)}
			if _inner_clear(r,out,home,air):
				out.append(r)
				break
	return out

static func _inner_clear(r: Dictionary, laid: Array, home: Dictionary, air: Array) -> bool:
	for p: Vector2 in box_outline(r):
		if p.length() > SCATTER-GAP-CORRIDOR*0.3: return false
	if box_distance(r,Vector2.ZERO) < PLATE_ROOM: return false
	for s: Vector3 in SLOTS:
		if box_distance(r,Vector2(s.x,s.z)) < ISLAND_ROOM: return false
	if box_distance(r,Vector2(SkyHomes.TOWER.x,SkyHomes.TOWER.z)) < SkyHomes.TOWER_KEEP+60.0: return false
	if box_gap(r,home) < CORRIDOR: return false
	for o: Dictionary in laid:
		if box_gap(r,o) < CORRIDOR: return false
	for p: Vector2 in air:
		if box_distance(r,p) < AIR_ROOM: return false
	return true

## The islands' jet streams' line, roughly (scripts/sky_currents.gd
## `build`): round the fixed islands by angle, points every 40 m.
static func _air() -> Array:
	var centre := Vector3.ZERO
	for s: Vector3 in SLOTS: centre += s
	centre /= float(SLOTS.size())
	var order := SLOTS.duplicate()
	order.sort_custom(func(a: Vector3, b: Vector3) -> bool: return atan2(a.z-centre.z,a.x-centre.x) < atan2(b.z-centre.z,b.x-centre.x))
	var out := []
	for i in range(order.size()):
		var a: Vector3 = order[i]
		var b: Vector3 = order[(i+1)%order.size()]
		var n := int(a.distance_to(b)/40.0)+1
		for k in range(n+1):
			var p := a.lerp(b,float(k)/n)
			out.append(Vector2(p.x,p.z))
	return out

# --- Footprints ---------------------------------------------------------------------

## A range's footprint over the sea (home, plate plane), as a box: its
## middle, half extents (along its crest, across) and turn.
static func box_half(r: Dictionary) -> Vector2:
	var s: Vector3 = r.scale
	return Vector2(SEA_HALF*s.x,FLANK*s.z)

## How far a home point (plate plane) stands outside a range's box (0 in it).
static func box_distance(r: Dictionary, p: Vector2) -> float:
	var at: Vector3 = r.at
	var local := Vector3(p.x-at.x,0.0,p.y-at.z).rotated(Vector3.UP,-float(r.turn))
	var half := box_half(r)
	return Vector2(maxf(absf(local.x)-half.x,0.0),maxf(absf(local.z)-half.y,0.0)).length()

## The box's outline, points about every 40 m (home, plate plane).
static func box_outline(r: Dictionary) -> Array:
	var half := box_half(r)
	var out := []
	var at: Vector3 = r.at
	for side in range(4):
		var n := int((half.x if side < 2 else half.y)*2.0/40.0)+1
		for k in range(n+1):
			var t := -1.0+2.0*k/n
			var local := Vector2(t*half.x,half.y if side == 0 else -half.y) if side < 2 else Vector2(half.x if side == 2 else -half.x,t*half.y)
			var g := Vector3(local.x,0.0,local.y).rotated(Vector3.UP,float(r.turn))
			out.append(Vector2(at.x+g.x,at.z+g.z))
	return out

## The gap between two ranges' boxes (m; 0 if they meet).
static func box_gap(a: Dictionary, b: Dictionary) -> float:
	var gap := INF
	for p: Vector2 in box_outline(a): gap = minf(gap,box_distance(b,p))
	for p: Vector2 in box_outline(b): gap = minf(gap,box_distance(a,p))
	return gap

## The islands saved (home), the plate's own among them: those standing
## outside the bounds (only a world saved before the ring can have one) are
## `kept`; the rest change nothing, so a claim inside never moves a range.
static func keep(homes: Array[Vector3]) -> void:
	var out: Array[Vector3] = []
	for h in homes:
		if Vector2(h.x,h.z).length() > SCATTER: out.append(h)
	kept = out
	_kept_changed = true

## True if an angle falls in a notch, widened by `margin` m each side.
static func in_notch(angle: float, margin := 0.0) -> bool:
	for a: float in frame().notches:
		var half := (NOTCH_ARC*0.5+margin)/crest(a)
		if absf(angle_difference(angle,a)) <= half: return true
	return false
