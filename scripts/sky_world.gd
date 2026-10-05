extends RefCounted
## The sky world's shape: one seed every placement in the sky reads, a
## bounded world laid out as a whole, and the mountain ring at its edge.
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
## SCATTER of it (`inside`, read through SkyPeaks `blocks`), and the
## mountain ring stands round them, well clear.
##
## The ring: real ranges (scripts/sky_peak.gd, made as any other, by seed)
## stood end to end round a crest line RADIUS out, wobbling in and out
## (`crest`) so the ring is no circle, each turned with its crest along the
## line, a little in or out of it and a little askew, so the ring runs
## broken and staggered. Where two meet their ends overlap, falling away
## into a saddle between them. NOTCHES clear gaps, NOTCH_ARC wide, stay
## open round it, spread about the ring: the spots kept for valleys to be
## carved later for fly-throughs (`layout` notches). Each range keeps its
## gorge, a slot through the ring at glide height. The layout is worked out
## once per seed for the whole ring (`layout`), so nothing lands on anything
## else, and kept clear of every island the world has saved (`kept`): a
## world saved before the ring might have one out where the ring would
## stand, and that range is left out.
##
## The edge: no wall. Past the ring's outer flank (OUTSIDE past the crest
## line) an edge wind rises over RAMP metres, blowing back toward the
## middle harder than the glide cruises, and turns an unsteered glide home
## (`edge_air`, read by SkyIslands `air`). Never a hard stop, and never
## past a saved island: the wind starts KEPT_ROOM past the farthest one.
##
## Seen from afar: the ring's rock takes a haze curve of its own (HAZE_REACH,
## HAZE_WHOLE: shaders/glide_haze.gdshaderinc zs_glide_fog_ring), so it
## stands as a pale skyline right across the world, and the glide's view
## reaches VIEW_FAR. Every range stands as a coarse skyline far off
## (scripts/sky_ring.gd) and as the full range near (SkyPeaks).
##
## `ring` (on unless `--no-ring`) turns the ring, the bounds and the edge
## wind on together; off, the sky is the old open one, endless, its ranges
## scattered through the cells. The ring is made of the peaks, so it stands
## only while they do (SkyHomes `peaks`).

const SkyHomes = preload("res://scripts/sky_homes.gd")

## The seed every hash used before there was one; and the world's.
const LEGACY_SEED := 7
static var seed := LEGACY_SEED
## The ring, the bounds and the edge wind.
static var ring := true
## The homes of every island the world has saved, and the plate's own (home
## coordinates): the ring keeps clear of them and the edge wind holds them.
static var kept: Array[Vector3] = []

## The crest line: its mean radius (m) and its wobble, two slow waves (share
## of the radius, twice and three times round).
const RADIUS := 3100.0
const WOBBLE := Vector2(0.045,0.03)
## Everything scattered stands within SCATTER (m) of the middle.
const SCATTER := 2200.0
## A range's crest stands over the sea about this far each side of its
## middle (m, before its spread: SkyPeak's ends fall under the sea within
## END_RUN of its outer summits), and its flanks this far out across it.
const CREST_HALF := 700.0
const FLANK := 420.0
## Each range's spread (its frame scaled in x and z) and stature.
const SPREAD := Vector2(1.05,1.3)
const STATURE := Vector2(0.85,1.0)
## Where two ranges meet, their crests overlap this much (m), give or take
## OVERLAP_JITTER; each stands up to SHIFT (m) in or out of the line, turned
## up to SKEW (radians) off it.
const OVERLAP := 300.0
const OVERLAP_JITTER := 110.0
const SHIFT := 110.0
const SKEW := 0.1
## The notches: how many, how wide (m along the crest line), and how far
## each may stray (radians) from an even share of the ring.
const NOTCHES := 3
const NOTCH_ARC := 700.0
const NOTCH_STRAY := 0.35
## The ranges either side stand this far back from a notch's edge (m), so
## one turned askew never swings its end into it.
const NOTCH_INSET := 80.0
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
## The ring's haze: the rock past HAZE_FROM (m from the middle) takes the
## ring's curve, fully by HAZE_TO; its reach and where it is whole (m).
const HAZE_FROM := SCATTER+60.0
const HAZE_TO := SCATTER+460.0
const HAZE_REACH := 3500.0
const HAZE_WHOLE := 8500.0
## How far the glide's view reaches with the ring (m), and without.
const VIEW_FAR := 9000.0
const VIEW_OPEN := 3000.0
## The salt for the ring's hashes.
const SALT := 9100

static var _layout := {}
## The seed and saved islands the layout was worked out for, and whether
## `kept` has changed since.
static var _layout_key := ""
static var _layout_seed := -1
static var _kept_changed := true
## The crest line's phases, and the seed they are for.
static var _phase := Vector2.ZERO
static var _phase_seed := -1

## True while the ring, the bounds and the edge wind stand.
static func ring_on() -> bool:
	return ring and (SkyHomes.peaks or SkyHomes.stone)

## Reads `--no-ring` from the command line (SkyIslands `setup`).
static func read_flags() -> void:
	var args := OS.get_cmdline_user_args()
	if "--no-ring" in args: ring = false

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

## The crest line's radius (m) at an angle round the middle (radians, from
## +x toward +z).
static func crest(angle: float) -> float:
	if _phase_seed != seed:
		_phase_seed = seed
		_phase = Vector2(noise(Vector2i(seed,1),SALT),noise(Vector2i(seed,2),SALT))*TAU
	return RADIUS*(1.0+WOBBLE.x*sin(2.0*angle+_phase.x)+WOBBLE.y*sin(3.0*angle+_phase.y))

## A point on the crest line (home, y 0).
static func crest_point(angle: float) -> Vector3:
	var r := crest(angle)
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

## The whole ring for the world's seed (and its saved islands), worked out
## once: {ranges: [{index, at (home), turn, seed, stature, spread, angle}],
## notches: [{angle, arc (m), at (home, on the crest line)}]}. Ranges run
## round the ring from the first notch; a range's index stays its own when
## one before it is left out.
static func layout() -> Dictionary:
	if _layout_seed == seed and not _kept_changed: return _layout
	var key := "%d|%s" % [seed,str(kept)]
	_layout_seed = seed
	_kept_changed = false
	if key == _layout_key: return _layout
	_layout_key = key
	_layout = {"ranges":[],"notches":[]}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(noise(Vector2i(seed,3),SALT)*2147483647.0)
	# The notches: an even share of the ring each, strayed a little.
	var first := rng.randf()*TAU
	var notch_angles: Array[float] = []
	for k in range(NOTCHES): notch_angles.append(first+TAU*k/NOTCHES+rng.randf_range(-NOTCH_STRAY,NOTCH_STRAY))
	for a in notch_angles: _layout.notches.append({"angle":fposmod(a,TAU),"arc":NOTCH_ARC,"at":crest_point(a)})
	# Between each notch and the next, ranges end to end along the line.
	var ranges: Array = []
	for k in range(NOTCHES):
		var start := notch_angles[k]+_half_notch(notch_angles[k])
		var end := notch_angles[(k+1)%NOTCHES]+(TAU if k == NOTCHES-1 else 0.0)-_half_notch(notch_angles[(k+1)%NOTCHES])
		ranges.append_array(_arc(start,end,rng))
	# None on a saved island.
	for i in range(ranges.size()):
		var r: Dictionary = ranges[i]
		r.index = i
		var room := CREST_HALF*float(r.spread)+250.0
		for h: Vector3 in kept:
			if Vector2(h.x-r.at.x,h.z-r.at.z).length() < room: r.index = -1
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

## The ranges along one stretch of the crest line, end to end: as few as
## cover it with their crests overlapping by about OVERLAP, their spreads
## drawn and then scaled together so the first starts at the stretch's start
## and the last ends at its end.
static func _arc(from: float, to: float, rng: RandomNumberGenerator) -> Array:
	var length := _length(from,to)
	var mean_spread := (SPREAD.x+SPREAD.y)*0.5
	var n := maxi(1,ceili((length-OVERLAP)/(2.0*CREST_HALF*mean_spread-OVERLAP)))
	var spreads: Array[float] = []
	var sum := 0.0
	for i in range(n):
		spreads.append(rng.randf_range(SPREAD.x,SPREAD.y))
		sum += spreads[i]
	# The overlaps: OVERLAP each, give or take, adding up to (n-1)*OVERLAP.
	var overlaps: Array[float] = []
	var off := 0.0
	for i in range(n-1):
		overlaps.append(rng.randf_range(-OVERLAP_JITTER,OVERLAP_JITTER))
		off += overlaps[i]
	for i in range(n-1): overlaps[i] = OVERLAP+overlaps[i]-off/(n-1)
	# Scaled so the crests just cover the stretch.
	var scale := (length+OVERLAP*(n-1))/(2.0*CREST_HALF*sum)
	for i in range(n): spreads[i] = clampf(spreads[i]*scale,SPREAD.x*0.9,SPREAD.y*1.1)
	# Any of the spread clamped off goes into the overlaps.
	var covered := 0.0
	for s in spreads: covered += 2.0*CREST_HALF*s
	var spare := covered-length
	for i in range(n-1): overlaps[i] += (spare-OVERLAP*(n-1))/(n-1)
	var out := []
	var along := 0.0
	for i in range(n):
		var half := CREST_HALF*spreads[i]
		var angle := _walk(from,along+half)
		var turn := -angle-PI*0.5+rng.randf_range(-SKEW,SKEW)
		# Half of them turned end for end, so the gorges and steep faces
		# fall either way.
		if rng.randf() < 0.5: turn += PI
		var r := crest(angle)+rng.randf_range(-SHIFT,SHIFT)
		out.append({"at":Vector3(cos(angle)*r,0.0,sin(angle)*r),"turn":turn,"angle":fposmod(angle,TAU),
			"seed":int(rng.randf()*16777216.0),"stature":rng.randf_range(STATURE.x,STATURE.y),"spread":spreads[i]})
		if i < n-1: along += 2.0*half-overlaps[i]
	return out

## The islands saved (home), the plate's own among them: those standing
## outside the bounds (only a world saved before the ring can have one) are
## `kept`; the rest change nothing, so a claim inside never moves the ring.
static func keep(homes: Array[Vector3]) -> void:
	var out: Array[Vector3] = []
	for h in homes:
		if Vector2(h.x,h.z).length() > SCATTER: out.append(h)
	kept = out
	_kept_changed = true

## True if an angle falls in a notch, widened by `margin` m each side.
static func in_notch(angle: float, margin := 0.0) -> bool:
	for n: Dictionary in layout().notches:
		var half := (float(n.arc)*0.5+margin)/crest(n.angle)
		if absf(angle_difference(angle,float(n.angle))) <= half: return true
	return false
