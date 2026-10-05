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
## SCATTER of it and BAND_CLEAR clear of the band's rock (`inside`, read
## through SkyPeaks `blocks`): out among the band's foothills, so the regions
## out by the band have their own groups; and keep clear of every range
## laid out here (SkyPeaks `blocks`).
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
##   the dividing ridges (kind "ridge", `_ridges`): long walls of ranges
##     laid crest to crest that slice the middle into regions. Three run
##     across the world (`_ridge_plan`): one through the range in sight of
##     the plate, out from its ends, and two more a third of the way round
##     either side, each as near the plate as its open air, the fixed
##     islands and their currents let it stand. Where two cross inside the
##     band they meet at a corner, one running on out to the band. So the
##     plate's region is the middle, walled round, and between each wall and
##     the band lies a long valley region of its own: from above, a
##     triangle in the ring. Each wall's middle is its knot, its tallest; the
##     pieces' heights vary (role): walls over the glide's ceiling, low
##     stretches under it to hop, spurs off the walls into the regions; a
##     few walls keep their gorge (a tight line through). Every wall has a
##     pass, a wide gap open at glide height (PASS_TOP, PASS_OPEN), between
##     two of its pieces or by the end of the range in sight of the plate,
##     and across it a col, a low saddle under the glide's way, so the wall
##     reads whole from above. The plan is judged as laid (`_judge`, on a
##     grid, `basins`): as many regions as it means, every one reached from
##     every other through the passes, the plate's open round it with its
##     range in sight, room and islands in every region; tried again from
##     the seed's own stream, the evenest of those that keep every rule is
##     taken (`_balance`). Each region past the plate's has its own cumulus
##     where one has room (`towers`, SkyTowers `spot`).
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
## Everything scattered stands within SCATTER (m) of the middle, and
## BAND_CLEAR (m) clear of the band's rock (its runs', massifs' and
## foothills' boxes).
const SCATTER := 2700.0
const BAND_CLEAR := 170.0
## The band's rock stands no nearer the middle than BAND_IN (m).
const BAND_IN := 2350.0
## Nor further than WORLD_HALF (m) from the middle along x or z.
const WORLD_HALF := 4390.0
## The band's rock stands at least GAP (m) past the old bounds (2200 m),
## BAND_IN.
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
## The plan's crest is read only CREST_HALF (m, its own x) each side of a
## range's middle: further out its heightfield falls away to its grid's
## ends (SkyPeak HALF) whatever the plan says, so a joint laid there would
## stand low.
const CREST_HALF := 520.0
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
## bulges enough; FOOT_IN (m) in front of the crest line; their scale; how
## far (m) a ridge's box keeps from a foothill's middle, or it goes.
const FOOT_MORE := 3
const FOOT_IN := 650.0
const FOOT_X := Vector2(0.9,1.2)
const FOOT_Z := Vector2(0.7,0.8)
const FOOT_Y := Vector2(0.45,0.6)
const FOOT_ROOM := 150.0
## The far row: how many, how far out past the crest line (m), their scale.
const FAR := 5
const FAR_OUT := 1000.0
const FAR_X := Vector2(1.8,2.1)
const FAR_Z := Vector2(1.2,1.3)
const FAR_Y := Vector2(1.3,1.45)
## The dividing ridges (`_ridges`): CHORDS walls across the world
## (`_ridge_plan`), one through the range in sight of the plate, the others
## turned about a third of the way round from it either way, CHORD_STRAY
## (radians) off, each standing as near the plate as it may (`_chord_reach`)
## and up to CHORD_MORE (m) further, its middle slid up to CHORD_SLIDE (m)
## along it. Each is laid as two arms out from its middle (the knot) each
## way, bowed off its line by BEND of its length (halved), to a corner or
## the band; a root on the band stands ROOT_CLEAR (m) from a notch's edge
## and a kept gorge's mouth, an arm turned NUDGE (radians) at a time, up to
## NUDGE_MOST, till it does, and no two roots closer than ROOT_APART.
const CHORDS := 3
const CHORD_STRAY := 0.3
const CHORD_MORE := Vector2(0.0,200.0)
const CHORD_SLIDE := 350.0
const NUDGE := 0.04
const NUDGE_MOST := 0.32
## The arms off the range in sight of the plate: each leaves its end along
## its crest, turned up to HOME_TURN (radians) either way; each with a col
## by the range's end at HOME_PASS odds (one at least), or its rock lapped
## HOME_LAP (m) over the range's.
const HOME_TURN := 0.4
const HOME_PASS := 0.6
const HOME_LAP := 250.0
const ROOT_CLEAR := 450.0
const BEND := Vector2(0.04,0.16)
## The pieces: their scale along and across (the knot's and the spurs'
## their own), heights by role (the knot's, the walls', the low stretches'
## (crest under the glide's ceiling, to hop over), the spurs'), the height
## each is laid by where it meets the next (m, as placed), and the odds a
## piece after the knot's is a low stretch. A first piece's crest starts
## KNOT_OFF (m) from the knot. A side arm's crest runs INTO (m) past where
## the band's rock starts, so the two are one wall.
const RIDGE_X := Vector2(0.7,1.0)
const RIDGE_Z := Vector2(0.62,0.74)
const KNOT_X := Vector2(0.6,0.75)
const KNOT_Y := Vector2(1.15,1.28)
const WALL_Y := Vector2(0.9,1.12)
const LOW_Y := Vector2(0.41,0.45)
const SPUR_X := Vector2(0.6,0.8)
const SPUR_Z := Vector2(0.5,0.6)
const SPUR_Y := Vector2(0.5,0.66)
const LAY_AT := {"knot":200.0,"wall":170.0,"low":-10.0,"spur":40.0,"col":SkyPeak.SEA+25.0}
## The cols: a low saddle across every pass (`_col`), its crest COL_LAP (m)
## past the pass's ends each way, so a wall reads whole from above; its
## height (COL_Y: nothing in it stands over SkyPeak SEA+(MOST-SEA)*COL_Y.y,
## -40 m, under PASS_TOP) and its width across.
const COL_Y := Vector2(0.125,0.144)
const COL_Z := Vector2(0.55,0.65)
const COL_LAP := 60.0
const LOW_ODDS := 0.3
const KNOT_OFF := 40.0
const INTO := 150.0
const CORNER_INTO := -30.0
## How far along its crest a piece's rock stands over PASS_TOP, and over
## the sea, at most (m, its own x): its heightfield falls away at its
## grid's ends (SkyPeak HALF), whatever the plan's crest says.
const OVER_HALF := 700.0
const ROCK_HALF := 760.0
## The passes: one through every arm, its rock under PASS_TOP (m) for
## PASS_OPEN (m) along it. Through a side arm, between two of its pieces,
## PASS_ALONG of the way from the knot to the band; at an outer arm's root,
## between its last piece and the band's rock: a col at the head of the
## valleys either side.
const PASS_TOP := -25.0
const PASS_OPEN := Vector2(420.0,500.0)
const PASS_ALONG := Vector2(0.25,0.6)
## Spurs off the arms: how many (at least, at most), how far they turn off
## the arm (radians), and how far out from its crest they start (m).
const SPURS := Vector2i(2,4)
const SPUR_TURN := Vector2(0.7,1.15)
const SPUR_FROM := 150.0
## How many of the walls keep their gorge (a tight line through, a treat).
const RIDGE_GORGES := Vector2i(1,2)
## A ridge's box reaches BOX_MORE (m) past its rock's ends along its crest.
const BOX_MORE := 40.0
## The regions (`basins`), on the plan: on a grid GRID (m) apart, GRID_HALF
## each way, inside the band's crest line, a ridge piece's rock is its
## crest over PASS_TOP (`over`) PROXY_HALF (m, times its scale across) each
## side; the band's, along its rock (SEA_HALF less BAND_SHORT) its own
## FLANK (times BAND_FLANK) each side. A region is a basin holding an open
## disc CORE (m) round its heart; a pass is open PASS_HALF (m) each side of
## the way through; a basin with less than CORE_AREA (km^2) of such heart is
## a nook, not a region. The plate stands PLATE_OPEN (m) from any rock; each
## region has ROOM (km^2) of open ground ROOM_CLEAR (m) from rock within the
## bounds for its islands.
const PROXY_HALF := 300.0
const BAND_SHORT := 60.0
const BAND_FLANK := 0.65
const GRID := 50.0
const GRID_HALF := 3650.0
const CORE := 380.0
const CORE_AREA := 0.05
const PASS_HALF := 110.0
const PLATE_OPEN := 700.0
const ROOM := 0.3
const ROOM_CLEAR := 220.0
## Tries at a layout that keeps every rule before the best is taken; of
## those that keep every rule, the evenest (`_balance`) is taken, once one
## is BALANCED or EVEN_TRIES are made.
const RIDGE_TRIES := 150
const BALANCED := 0.45
const EVEN_TRIES := 60
## The ridges keep PLATE_ROOM (m) from the plate, ISLAND_ROOM from a fixed
## island, AIR_ROOM from the islands' jet streams, CORRIDOR from the range
## in sight of the plate.
const CORRIDOR := 150.0
const PLATE_ROOM := 650.0
const ISLAND_ROOM := 250.0
const AIR_ROOM := 120.0
## The range in sight of the plate's seed (SkyPeaks `seed_of` the plate's
## cell: its SALT+4).
const HOME_SALT := 3004
## Nothing scattered stands within RIDGE_CLEAR (m) of a ridge's box
## (SkyPeaks `blocks`); the cumulus's cells (SkyTowers CELL, m).
const RIDGE_CLEAR := 120.0
const TOWER_CELL := 2000.0
## A region's cumulus stands TOWER_IN (m) inside the bounds, its middle
## TOWER_ROOM (m) more than a tower's keep from any ridge's box.
const TOWER_IN := 150.0
const TOWER_ROOM := 40.0
## Every region holds an island at least (SkyCells), and ISLANDS if any
## try can.
const ISLANDS := 4
## The arms' roots stand ROOT_APART (m, round the crest line) from each
## other's, so no two close a pocket against the band.
const ROOT_APART := 1500.0
## The notches: how many, how wide (m along the crest line), and how far
## each may stray (radians) from an even share of the ring.
const NOTCHES := 3
const NOTCH_ARC := 600.0
const NOTCH_STRAY := 0.35
## The ranges either side stand this far back from a notch's edge (m).
const NOTCH_INSET := 80.0
## A range's low end beside a notch may run this far (m) into the inset and
## the notch's edge, falling into the sea: the notch's shoulders.
const SHOULDER := 100.0
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
## The band's haze: the rock takes the band's curve from HAZE_FROM (m) in
## from where its rock starts round the middle (`haze_inner`, HAZE_ANGLES
## a turn) to HAZE_TO past it, so nothing scattered (BAND_CLEAR off it)
## ever does; its reach and where it is whole (m).
const HAZE_FROM := 40.0
const HAZE_TO := 250.0
const HAZE_ANGLES := 128
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
## Which wonders stood (SkyHomes `stone`, `isles`): the ridges keep clear of
## them.
static var _layout_wonders := 0
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
	var flat := Vector2(home.x,home.z)
	if flat.length() > SCATTER-margin: return false
	# Quick: well inside the band's rock everywhere.
	if flat.length() < BAND_IN-BAND_CLEAR-margin: return true
	return clear_of_band(flat,layout().ranges,margin) and haze_share(flat) == 0.0

## True if a home point (plate plane) stands BAND_CLEAR (and `margin`) clear
## of the band's rock among `ranges` (its runs', massifs' and foothills'
## boxes).
static func clear_of_band(p: Vector2, ranges: Array, margin := 0.0) -> bool:
	for r: Dictionary in ranges:
		if r.kind != "run" and r.kind != "massif" and r.kind != "foot": continue
		if box_distance(r,p) < BAND_CLEAR+margin: return false
	return true

## Where the band's rock starts round the middle (m), HAZE_ANGLES a turn
## from +x toward +z: the nearest any of its boxes (the far row's too)
## comes along each way out, for its haze (SkyHaze `ring_spot`).
static func _haze_inner(ranges: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var band: Array = ranges.filter(func(r: Dictionary) -> bool: return in_band(r.kind))
	for k in range(HAZE_ANGLES):
		var a := TAU*k/HAZE_ANGLES
		var way := Vector2(cos(a),sin(a))
		var near: Array = band.filter(func(q: Dictionary) -> bool: return absf(angle_difference(float(q.angle),a)) < 0.9)
		var r := BAND_IN-200.0
		while r < crest(a)+400.0:
			if near.any(func(q: Dictionary) -> bool: return box_distance(q,way*r) < 1.0): break
			r += 60.0
		r -= 60.0
		while r < crest(a)+400.0:
			if near.any(func(q: Dictionary) -> bool: return box_distance(q,way*r) < 1.0): break
			r += 10.0
		out.append(r)
	# Each way the nearest of it and the two either side: the curve never
	# reaches in past the rock between them.
	var eased := out.duplicate()
	for k in range(HAZE_ANGLES):
		for m in range(-2,3): eased[k] = minf(eased[k],out[(k+m+HAZE_ANGLES)%HAZE_ANGLES])
	return eased

## How far onto the band's haze curve a home point is (0 to 1): as the
## shader has it (shaders/reference_surface_haze.gdshaderinc zs_glide_ring).
static func haze_share(p: Vector2) -> float:
	if not ring_on(): return 0.0
	return _share(p,layout().get("haze_inner",PackedFloat32Array()))

static func _share(p: Vector2, inner: PackedFloat32Array) -> float:
	if inner.size() != HAZE_ANGLES: return 0.0
	var f := fposmod(atan2(p.y,p.x)/TAU,1.0)*HAZE_ANGLES
	var i := int(f)
	var at := lerpf(inner[i%HAZE_ANGLES],inner[(i+1)%HAZE_ANGLES],f-i)
	return smoothstep(at-HAZE_FROM,at+HAZE_TO,p.length())

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
## row), false for the dividing ridges.
static func in_band(kind: String) -> bool:
	return kind != "ridge"

## The whole world's ranges for its seed (and its saved islands), worked
## out once: {ranges: [{index, kind, at (home), turn, seed, stature, scale
## (Vector3), gorge (bool), angle; a ridge's role, its box (`box_at`,
## `half`) and whether its skyline is `coarse`}], notches: [{angle, arc (m),
## at (home, on the crest line)}], massifs: [angles], and the ridges'
## (`_ridges`): regions, passes, towers, knot, islands (each region's),
## kept_rules (false only if no try kept every rule), tries}. A range's
## index stays its own when one before it is left out for a saved island.
##
## Worked out on a worker when asked ahead (`prepare`, from SkyIslands
## `load_state`: as a world starts), so the main thread never waits on it in
## play; asked for before that worker is done, it is waited for, and asked
## for with none started, worked out here and now (tests, tools). Either way
## the same seed lays the same world.
static func layout() -> Dictionary:
	var wonders := int(SkyHomes.stone)+2*int(SkyHomes.isles)
	if _layout_seed == seed and not _kept_changed and _layout_wonders == wonders: return _layout
	var key := _key_now()
	var began := Time.get_ticks_usec()
	# The one being worked out on a worker: waited for, and taken if it is
	# this one.
	if key != _layout_key and _task >= 0: settle()
	_layout_seed = seed
	_layout_wonders = wonders
	_kept_changed = false
	if key == _layout_key: return _layout
	frame()
	_layout = _compute()
	_layout_key = key
	main_ms += (Time.get_ticks_usec()-began)/1000.0
	return _layout

## The layout's key: the seed, the islands kept and the wonders standing.
static func _key_now() -> String:
	return "%d|%s|%s%s" % [seed,str(kept),SkyHomes.stone,SkyHomes.isles]

## The worker working out a layout ahead (`prepare`), its key and its result.
static var _task := -1
static var _task_key := ""
static var _task_out := {}
## Main-thread milliseconds `prepare` and the waits on its worker took, for
## the record (tests/test_sky_world.gd).
static var main_ms := 0.0

## Sets a worker working out the layout for the world as it stands (its
## seed, kept islands and wonders), unless it is worked out or being worked
## out already. The seed and the kept islands are not changed while it works
## (`settle` first: SkyIslands `load_state`, `keep`).
static func prepare() -> void:
	var began := Time.get_ticks_usec()
	read_flags()
	if not ring_on(): return
	var key := _key_now()
	if key == _layout_key or (_task >= 0 and key == _task_key):
		return
	settle()
	# The crest line's frame cached here, so the worker only reads it; the
	# cells' script loaded here, so the worker only finds it.
	frame()
	load("res://scripts/sky_cells.gd")
	_task_key = key
	_task_out = {}
	_task = WorkerThreadPool.add_task(_work.bind(_task_out),false,"Sky world layout")
	main_ms += (Time.get_ticks_usec()-began)/1000.0

static func _work(out: Dictionary) -> void:
	out.layout = _compute()

## True once the layout for the world as it stands is worked out (taking a
## worker's if it is done): nothing then waits on it.
static func ready() -> bool:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task): settle()
	return _key_now() == _layout_key

## Waits for a worker still working out a layout, and takes its result.
static func settle() -> void:
	if _task < 0: return
	var began := Time.get_ticks_usec()
	WorkerThreadPool.wait_for_task_completion(_task)
	_take()
	main_ms += (Time.get_ticks_usec()-began)/1000.0

static func _take() -> void:
	_task = -1
	if not _task_out.has("layout"): return
	_layout = _task_out.layout
	_layout_key = _task_key
	# Read through the quick check again on the next ask.
	_layout_seed = -1
	_task_out = {}

## The whole layout, worked out from the statics as they stand: only read
## here, never written, so a worker may run it.
static func _compute() -> Dictionary:
	var f := frame()
	var out := {"ranges":[],"notches":[],"massifs":f.massifs,"regions":[],"passes":[],"towers":[],"knot":Vector3.ZERO,"kept_rules":true}
	for a: float in f.notches: out.notches.append({"angle":a,"arc":NOTCH_ARC,"at":crest_point(a)})
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
	var feet := _foothills(ranges,rng)
	ranges.append_array(_far_row(rng))
	# The ridges through the middle, from a stream of their own; a foothill
	# whose middle a ridge would stand on (FOOT_ROOM) left out.
	# Where the band's rock starts round the middle, for its haze and the
	# islands' bounds (the foothills a ridge will put out counted all the
	# same: the nearer for it).
	var inner := _haze_inner(ranges+feet)
	var ridges := _ridges(ranges,feet,inner)
	for foot: Dictionary in feet:
		if not ridges.ranges.any(func(q: Dictionary) -> bool: return box_distance(q,Vector2(foot.at.x,foot.at.z)) < FOOT_ROOM): ranges.append(foot)
	ranges.append_array(ridges.ranges)
	for part in ["regions","passes","towers","knot"]: out[part] = ridges[part]
	out.chords = ridges.get("chords",[])
	out.islands = ridges.get("islands",[])
	out.tries = ridges.get("tries",0)
	out.balance = ridges.get("balance",0.0)
	out.kept_rules = ridges.ok
	# None on a saved island.
	for i in range(ranges.size()):
		var r: Dictionary = ranges[i]
		r.index = i
		for h: Vector3 in kept:
			if box_distance(r,Vector2(h.x,h.z)) < 250.0: r.index = -1
	for r: Dictionary in ranges:
		if r.index >= 0: out.ranges.append(r)
	out.haze_inner = inner
	return out

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
		span = Vector2(maxf(span.x,-CREST_HALF),minf(span.y,CREST_HALF))
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
		s.z = clampf((_nearest(r)-BAND_IN)/FLANK,0.8,s.z)
		r.scale = s
		# And its footprint within WORLD_HALF of the middle each way (x and
		# z): the world stays its size, a range by a corner narrower across.
		for k in range(8):
			var far := 0.0
			for p: Vector2 in box_outline(r): far = maxf(far,maxf(absf(p.x),absf(p.y)))
			if far <= WORLD_HALF or float(r.scale.z) <= 0.8: break
			s = r.scale
			s.z = maxf(s.z-0.05,0.8)
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
		if crest(a)-FOOT_IN < BAND_IN+FLANK*FOOT_Z.y+60.0: continue
		var clear := true
		for s in spots:
			if absf(angle_difference(a,s))*crest(a) < 1300.0: clear = false
		if not clear or in_notch(a,1200.0): continue
		spots.append(a)
		more += 1
	for a: float in spots:
		if in_notch(a,1100.0): continue
		var s := Vector3(rng.randf_range(FOOT_X.x,FOOT_X.y),rng.randf_range(FOOT_Y.x,FOOT_Y.y),rng.randf_range(FOOT_Z.x,FOOT_Z.y))
		var r := maxf(crest(a)-FOOT_IN,BAND_IN+FLANK*s.z+60.0)
		var foot := {"kind":"foot","seed":int(rng.randf()*16777216.0),"stature":rng.randf_range(0.85,0.95),"scale":s,"gorge":false,
			"at":Vector3(cos(a)*r,0.0,sin(a)*r),"turn":-a-PI*0.5+rng.randf_range(-0.35,0.35)+(PI if rng.randf() < 0.5 else 0.0),"angle":fposmod(a,TAU)}
		# Its whole footprint GAP past the bounds: out a little if not.
		for k in range(6):
			var near := INF
			for p: Vector2 in box_outline(foot): near = minf(near,p.length())
			if near >= BAND_IN+20.0: break
			foot.at = foot.at*(1.0+(BAND_IN+30.0-near)/Vector2(foot.at.x,foot.at.z).length())
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

# --- The dividing ridges -------------------------------------------------------------

## The ridges through the middle, cutting it into regions: {ranges,
## regions [{at (home, its heart), home (bool: the plate's), area (km^2 of
## room for islands), label}], passes [{at (home), along (the arm's way),
## way (across it, from one region to the next), open (m), root (at an
## outer arm's root)}], towers (home), knot (home), islands (each
## region's), ok, tries}. Laid from the seed's own stream, tried again
## until a layout keeps every rule (`_judge`) with ISLANDS islands to every
## region, up to RIDGE_TRIES; failing that, the first that kept every rule;
## failing that, the one that kept the most.
static func _ridges(band: Array, feet: Array, inner: PackedFloat32Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(noise(Vector2i(seed,5),SALT)*2147483647.0)
	var mouths := _gorge_mouths(band)
	var band_open := _band_open(band,feet,inner)
	var keep_off: Array = band.filter(func(r: Dictionary) -> bool: return r.kind != "far")
	keep_off.append_array(feet)
	var best := {}
	var fewer := {}
	var even := {}
	for tries in range(RIDGE_TRIES):
		var plan := _ridge_plan(mouths,band_open,keep_off,inner,rng)
		plan.tries = tries+1
		if plan.ok and plan.islands.min() >= ISLANDS:
			plan.balance = _balance(plan)
			if even.is_empty() or float(plan.balance) > float(even.balance): even = plan
			if float(even.balance) >= BALANCED or tries+1 >= EVEN_TRIES: return even
		if plan.ok and fewer.is_empty(): fewer = plan
		if best.is_empty() or float(plan.score) > float(best.score): best = plan
	if not even.is_empty(): return even
	# Every rule kept but a region with fewer islands than ISLANDS: the
	# first such.
	if not fewer.is_empty(): return fewer
	push_warning("SkyWorld: seed %d's ridges break a rule" % seed)
	for key in ["regions","passes","towers","islands"]:
		if not best.has(key): best[key] = []
	if not best.has("knot"): best.knot = Vector3.ZERO
	for r: Dictionary in best.ranges:
		for key in ["start","end","last","home_arm"]: r.erase(key)
	return best

## How even a plan's regions are (0 to 1): the smallest's room for islands
## over the largest's, or its islands over the most's, whichever is less.
static func _balance(plan: Dictionary) -> float:
	var areas: Array = plan.regions.map(func(g: Dictionary) -> float: return float(g.area))
	var islands: Array = plan.islands
	return minf(float(areas.min())/maxf(float(areas.max()),0.01),float(islands.min())/maxf(float(islands.max()),1.0))

## The angles (round the middle) where the band's kept gorges open inward.
static func _gorge_mouths(band: Array) -> Array[float]:
	var out: Array[float] = []
	for r: Dictionary in band:
		if not (in_band(r.kind) and r.gorge): continue
		var x := SkyPeak.gorge_at(int(r.seed),float(r.stature))
		var s: Vector3 = r.scale
		var p: Vector3 = r.at+Vector3(x*s.x,0.0,0.0).rotated(Vector3.UP,float(r.turn))
		out.append(fposmod(atan2(p.z,p.x),TAU))
	return out

## One try: CHORDS long walls across the world, one through the range in
## sight of the plate (its arms off the range's ends, along its crest), the
## others turned about a third of the way round from it either side, each
## as near the plate as the plate's open air, the fixed islands, the
## cumulus in sight of it and the islands' jet streams let it stand
## (`_chord_reach`), a little further by chance. Where two walls cross
## inside the band they meet at a corner: one runs on out through it to the
## band (a spur of the corner), the other ends in its rock. So the plate's
## region is the middle, walled round, and between each wall and the band
## lies a valley region of its own. Each wall has a pass (a col by the
## range in sight of the plate's end; through the others, between two
## pieces); then the spurs, the gorges kept and the cumulus, one to a
## region; judged as it goes.
static func _ridge_plan(mouths: Array[float], band_open: PackedByteArray, band: Array, inner: PackedFloat32Array, rng: RandomNumberGenerator) -> Dictionary:
	var failed := {"ranges":[],"ok":false,"score":0.0}
	var air := _air()
	var home_at := Vector2(SkyHomes.RANGE.x,SkyHomes.RANGE.z)
	var hway := Vector2(1.0,0.0).rotated(-SkyHomes.RANGE_TURN)
	var hspan := _home_span()
	# The chords: a point on each and its way along.
	var at: Array[Vector2] = [home_at]
	var along: Array[Vector2] = [hway]
	var phi := home_at.angle()
	for side in [1.0,-1.0]:
		var normal := Vector2.from_angle(phi+side*TAU/3.0+rng.randf_range(-CHORD_STRAY,CHORD_STRAY))
		var d := _chord_reach(normal,air)+rng.randf_range(CHORD_MORE.x,CHORD_MORE.y)
		var way := normal.orthogonal()
		at.append(normal*d+way*rng.randf_range(-CHORD_SLIDE,CHORD_SLIDE))
		along.append(way)
	# Each chord's two arms: from its middle (the range in sight of the
	# plate's ends for its own, each turned up to HOME_TURN off its crest's
	# way) each way along it, to a corner or the band.
	var starts := []
	var ways := []
	for k in range(CHORDS):
		if k == 0:
			starts.append([home_at+hway*hspan.x,home_at+hway*hspan.y])
			ways.append([(-hway).rotated(rng.randf_range(-HOME_TURN,HOME_TURN)),hway.rotated(rng.randf_range(-HOME_TURN,HOME_TURN))])
		else:
			starts.append([at[k],at[k]])
			ways.append([-along[k],along[k]])
	# The corners: where two arms of two chords cross in the open inside the
	# band, the nearest along each its own.
	var ends := []
	for k in range(CHORDS): ends.append([{},{}])
	for i in range(CHORDS):
		for j in range(i+1,CHORDS):
			for si in range(2):
				for sj in range(2):
					var a: Vector2 = starts[i][si]
					var b: Vector2 = starts[j][sj]
					var x: Variant = Geometry2D.segment_intersects_segment(a,a+(ways[i][si] as Vector2)*7000.0,b,b+(ways[j][sj] as Vector2)*7000.0)
					if x == null: continue
					var p: Vector2 = x
					if p.length() >= crest(p.angle()) or band_open[_grid_index(p,grid_size())] == 0: continue
					var through := rng.randf() < 0.5
					for pair in [[i,si,through],[j,sj,not through]]:
						var e: Dictionary = ends[pair[0]][pair[1]]
						var from: Vector2 = starts[pair[0]][pair[1]]
						if e.is_empty() or from.distance_to(p) < from.distance_to(e.at): ends[pair[0]][pair[1]] = {"at":p,"through":pair[2]}
	# The roots on the band: no two closer than ROOT_APART, none in a notch
	# or a kept gorge's mouth.
	var lines := []
	var roots: Array[float] = []
	for k in range(CHORDS):
		for s in range(2):
			var from: Vector2 = starts[k][s]
			var way: Vector2 = ways[k][s]
			var e: Dictionary = ends[k][s]
			var line := PackedVector2Array()
			var stop := -1.0
			if e.is_empty():
				# Turned a little at a time, up to NUDGE_MOST, till its root
				# keeps off the notches and the kept gorges' mouths.
				var w := _nudged(from,way.angle(),mouths)
				way = Vector2.from_angle(w)
				line = _arm_line(from,from+way*6000.0,0.0)
				roots.append(_root(from,w))
			else:
				var corner: Vector2 = e.at
				var bend := rng.randf_range(BEND.x,BEND.y)*0.5*(1.0 if rng.randf() < 0.5 else -1.0)
				line = _arm_line(from,corner,bend)
				if e.through:
					# On out of the corner toward the band, likewise turned.
					var w := _nudged(corner,corner.angle(),mouths)
					var out := Vector2.from_angle(w)
					for m in range(1,80): line.append(corner+out*m*50.0)
					roots.append(_root(corner,w))
				else:
					for m in range(1,10): line.append(corner+way*m*50.0)
					stop = _line_length(_arm_line(from,corner,bend))
			lines.append({"line":line,"stop":stop,"chord":k,"side":s,"corner":e.get("at",Vector2.INF)})
	for a in roots:
		if not _root_ok(a,mouths): return failed
	for i in range(roots.size()):
		for j in range(i+1,roots.size()):
			if absf(angle_difference(roots[i],roots[j]))*crest(roots[i]) < ROOT_APART: return failed
	failed.score = 1.0
	# The walls: through each chord but the plate's range's, one arm with a
	# pass between two pieces and one whole; off that range's ends, a col by
	# one end at least.
	var pieces := []
	var passes := []
	var with_pass := [rng.randf() < HOME_PASS,rng.randf() < HOME_PASS]
	if not (with_pass[0] or with_pass[1]): with_pass[rng.randi_range(0,1)] = true
	var open_side := []
	for k in range(CHORDS): open_side.append(rng.randi_range(0,1))
	for l: Dictionary in lines:
		var k: int = l.chord
		var s: int = l.side
		var kind := ("home_pass" if with_pass[s] else "home") if k == 0 else ("side" if s == open_side[k] else "wall")
		var corner: Vector2 = l.corner
		var span := -1.0 if corner == Vector2.INF else (starts[k][s] as Vector2).distance_to(corner)
		var arm := _arm(l.line,band_open,kind,rng,float(l.stop),span)
		if arm.is_empty(): return failed
		if k == 0:
			for r: Dictionary in arm.pieces: r.home_arm = true
		pieces.append_array(arm.pieces)
		if not arm.pass.is_empty():
			arm.pass.chord = k
			passes.append(arm.pass)
	failed.score = 2.0
	var home := {"at":SkyHomes.RANGE,"turn":SkyHomes.RANGE_TURN,"scale":Vector3.ONE}
	for r: Dictionary in pieces:
		if not _clear(r,home,air): return failed
	failed.score = 3.0
	var knot := at[1]
	var regions := CHORDS+1
	var judged := _judge(pieces,regions,band_open)
	var chords := []
	for k in range(CHORDS): chords.append({"at":Vector3(at[k].x,0.0,at[k].y),"along":Vector3(along[k].x,0.0,along[k].y)})
	var plan := {"chords":chords,"ranges":pieces,"passes":passes,"knot":Vector3(knot.x,0.0,knot.y),"ok":false,"score":3.0+float(judged.kept),"towers":[],"regions":judged.regions,"rules":judged.rules}
	if not judged.ok: return plan
	# The spurs, each kept only if the regions keep every rule with it.
	var spurs := rng.randi_range(SPURS.x,SPURS.y)
	var laid := 0
	for tries in range(spurs*6):
		if laid >= spurs: break
		var spur := _spur(pieces,rng)
		if spur.is_empty() or not _clear(spur,home,air): continue
		var with := pieces.duplicate()
		with.append(spur)
		var again := _judge(with,regions,band_open)
		if not again.ok: continue
		pieces.append(spur)
		judged = again
		laid += 1
	# The gorges kept: walls inside the world, not by the band.
	var walls := pieces.filter(func(r: Dictionary) -> bool: return r.role == "wall" and not r.get("last",false))
	for k in range(mini(rng.randi_range(RIDGE_GORGES.x,RIDGE_GORGES.y),walls.size())):
		var r: Dictionary = walls.pop_at(rng.randi_range(0,walls.size()-1))
		r.gorge = true
	for r: Dictionary in pieces:
		for key in ["start","end","last","home_arm"]: r.erase(key)
	plan.ranges = pieces
	plan.regions = judged.regions
	judged.band = band
	judged.inner = inner
	plan.towers = _towers(pieces,judged)
	# ISLANDS islands to every region: a region's cumulus gives way to them.
	var islands := _islands(pieces,judged,plan.towers)
	for t: Vector3 in plan.towers.duplicate():
		var k: int = judged.basins.labels[_grid_index(Vector2(t.x,t.z),grid_size())]
		if k >= 0 and islands[k] < ISLANDS:
			plan.towers.erase(t)
			islands = _islands(pieces,judged,plan.towers)
	plan.islands = islands
	if islands.min() < 1: return plan
	plan.ok = true
	return plan

## How many islands stand in each region of the plan (`judged`), its own
## towers among the cumulus: as SkyCells finds them (`pick`), the fixed
## slots included, none within the bounds' edge, RIDGE_CLEAR of a ridge's
## box, the range in sight of the plate's keep or a cumulus's.
static func _islands(pieces: Array, judged: Dictionary, towers: Array) -> Array:
	var cells: GDScript = load("res://scripts/sky_cells.gd")
	var keeps := [Vector3(SkyHomes.TOWER.x,0.0,SkyHomes.TOWER.z)]
	keeps.append_array(towers)
	var blocked := func(p: Vector3) -> bool:
		var flat := Vector2(p.x,p.z)
		if flat.length() > SCATTER or flat.distance_to(Vector2(SkyHomes.RANGE.x,SkyHomes.RANGE.z)) < SkyHomes.RANGE_KEEP: return true
		if flat.length() > BAND_IN-BAND_CLEAR and (not clear_of_band(flat,judged.band) or _share(flat,judged.inner) > 0.0): return true
		for t: Vector3 in keeps:
			if flat.distance_to(Vector2(t.x,t.z)) < SkyHomes.TOWER_KEEP: return true
		return pieces.any(func(r: Dictionary) -> bool: return box_distance(r,flat) < RIDGE_CLEAR)
	var n := grid_size()
	var labels: PackedInt32Array = judged.basins.labels
	var out := []
	out.resize(int(judged.basins.count))
	out.fill(0)
	var spots: Array = SLOTS.duplicate()
	var size: float = cells.CELL
	for x in range(floori(-SCATTER/size)-1,ceili(SCATTER/size)+1):
		for z in range(floori(-SCATTER/size)-1,ceili(SCATTER/size)+1):
			var found: Variant = cells.pick(Vector2i(x,z),SLOTS,blocked)
			if found != null: spots.append(found)
	for p: Vector3 in spots:
		var k := labels[_grid_index(Vector2(p.x,p.z),n)]
		if k >= 0: out[k] += 1
	return out

## The way (radians) nearest `way` out of `from` whose root on the band
## keeps off the notches and the kept gorges' mouths (`_root_ok`), turned
## NUDGE at a time either side up to NUDGE_MOST; `way` itself if none does.
static func _nudged(from: Vector2, way: float, mouths: Array[float]) -> float:
	for step in range(int(NUDGE_MOST/NUDGE)*2+1):
		var w := way+NUDGE*((step+1)/2)*(1.0 if step%2 == 1 else -1.0)
		if _root_ok(_root(from,w),mouths): return w
	return way

## How near the plate a wall across the world may stand along `normal` (m):
## its rock (a ridge's half across, and a little) its room from the plate,
## the fixed islands, the cumulus in sight of the plate (and the other
## wonders, standing), and the islands' jet streams (`air`).
static func _chord_reach(normal: Vector2, air: Array) -> float:
	var half := FLANK*RIDGE_Z.y+40.0
	var d := PLATE_ROOM+half
	for slot: Vector3 in SLOTS.slice(1): d = maxf(d,Vector2(slot.x,slot.z).dot(normal)+ISLAND_ROOM+half)
	for w: Array in SkyHomes.spots():
		var p: Vector3 = w[0]
		if p == SkyHomes.RANGE: continue
		var keep := SkyHomes.TOWER_KEEP+60.0 if p == SkyHomes.TOWER else float(w[1])
		d = maxf(d,Vector2(p.x,p.z).dot(normal)+keep+half)
	for q: Vector2 in air: d = maxf(d,q.dot(normal)+AIR_ROOM+half)
	return d

## Where an arm leaving the knot along `way` (radians) meets the band's
## crest line: its angle round the middle.
static func _root(knot: Vector2, way: float) -> float:
	var d := Vector2.from_angle(way)
	var t := 0.0
	while t < 8000.0:
		var p := knot+d*t
		if p.length() >= crest(p.angle()): return fposmod(p.angle(),TAU)
		t += 25.0
	return 0.0

## True if a root at angle `a` stands ROOT_CLEAR from a notch's edge and a
## kept gorge's mouth.
static func _root_ok(a: float, mouths: Array[float]) -> bool:
	if in_notch(a,ROOT_CLEAR): return false
	for m in mouths:
		if absf(angle_difference(a,m))*crest(a) < ROOT_CLEAR: return false
	return true

## An arm's line from the knot to its root, bowed `bend` of its length to
## one side: points every 1/64 of the way.
static func _arm_line(from: Vector2, to: Vector2, bend: float) -> PackedVector2Array:
	var mid := (from+to)*0.5+(to-from).orthogonal().normalized()*bend*from.distance_to(to)
	var out := PackedVector2Array()
	for k in range(65):
		var t := k/64.0
		out.append(from.lerp(mid,t).lerp(mid.lerp(to,t),t))
	return out

static func _line_length(line: PackedVector2Array) -> float:
	var total := 0.0
	for k in range(line.size()-1): total += line[k].distance_to(line[k+1])
	return total

## The point `along` metres down a line, on past its end along its last way.
static func _along(line: PackedVector2Array, along: float) -> Vector2:
	var left := along
	for k in range(line.size()-1):
		var piece := line[k].distance_to(line[k+1])
		if left <= piece or k == line.size()-2: return line[k]+(line[k+1]-line[k]).normalized()*left
		left -= piece
	return line[-1]

## A drawn piece's crest's length as placed (m), and how far past its
## crest's ends its rock stands over PASS_TOP (m).
static func _crest_length(r: Dictionary) -> float:
	return (float(r.span.y)-float(r.span.x))*float(r.scale.x)

static func _over_lead(r: Dictionary) -> float:
	return (float(r.span.x)-float(r.over.x))*float(r.scale.x)

static func _over_tail(r: Dictionary) -> float:
	return (float(r.over.y)-float(r.span.y))*float(r.scale.x)

## One arm's pieces down `line` from the knot, laid crest to crest as the
## band's are, a low stretch now and then, and its pass. It runs on until
## its crest stands INTO the band's rock, or, ending at a corner (`stop`, m
## along it), CORNER_INTO the other wall's. Its `kind`: "side", its pass
## between two of its pieces, the next laid PASS_OPEN on from where the
## last's rock falls under PASS_TOP, once the arm has come PASS_ALONG of its
## way (of `span`, to its corner, if given); "wall", whole; "home_pass" and
## "home", off the range in sight of the plate's end, with a col by it or
## lapped over it; "outer", stopping short of the band, its last piece
## stretched so its rock ends PASS_OPEN before the band's. A pass has its
## col (`_col`). {pieces, pass}, or empty if it can't be laid so.
static func _arm(line: PackedVector2Array, band_open: PackedByteArray, kind: String, rng: RandomNumberGenerator, stop := -1.0, span := -1.0) -> Dictionary:
	var outer := kind == "outer"
	var anchored := kind.begins_with("home")
	var total := _line_length(line)
	var n := grid_size()
	# Where the band's rock starts along it, or where it is to end in
	# another wall's rock (`stop`, m along it).
	var band_at := total
	var d := 0.0
	while d < total and stop < 0.0:
		if band_open[_grid_index(_along(line,d),n)] == 0:
			band_at = d
			break
		d += 20.0
	if stop >= 0.0: band_at = stop
	# Into the band's rock INTO; into another wall's at a corner only up to
	# its crest (CORNER_INTO), so the two meet rather than cross.
	var into := CORNER_INTO if stop >= 0.0 else INTO
	var open := rng.randf_range(PASS_OPEN.x,PASS_OPEN.y)
	var pass_at := rng.randf_range(PASS_ALONG.x,PASS_ALONG.y)*(span if span > 0.0 else band_at)
	var pieces := []
	var gap := Vector2.ZERO
	var gap_joint := -1
	var at := KNOT_OFF
	while pieces.size() < 12:
		var role := "wall" if anchored else "knot"
		if not pieces.is_empty(): role = "low" if pieces[-1].role == "wall" and rng.randf() < LOW_ODDS else "wall"
		var r := _ridge_draw(role,rng)
		if r.is_empty(): return {}
		# The first: turned so its crest starts nearest the knot.
		if pieces.is_empty() and r.span.x > -r.span.y: _ridge_turn(r)
		# One reaching the band: turned so its rock ends nearest its crest's
		# end, and none of it stands out past the band.
		if not outer and not pieces.is_empty() and at-JOIN+_crest_length(r) >= band_at+into and float(r.sea.y)-float(r.span.y) > float(r.span.x)-float(r.sea.x): _ridge_turn(r)
		var start := at
		if pieces.is_empty() and anchored:
			# Off the range in sight of the plate: a col by its end, or its
			# rock lapped HOME_LAP over the range's.
			if kind == "home_pass":
				gap = Vector2(0.0,open)
				gap_joint = 0
				start = open+_over_lead(r)
			else: start = -HOME_LAP+_over_lead(r)
		elif not pieces.is_empty():
			start = at-JOIN
			var last: Dictionary = pieces[-1]
			# The pass here, once the arm has come far enough, or if after
			# the next it would be too near the band.
			if kind == "side" and gap_joint < 0 and (at >= pass_at or at-JOIN+_crest_length(r)+_over_tail(last)+open > band_at-500.0):
				var low := float(last.end)+_over_tail(last)
				gap = Vector2(low,low+open)
				gap_joint = pieces.size()
				start = gap.y+_over_lead(r)
		r.start = start
		r.end = start+_crest_length(r)
		if outer and float(r.end)+_over_tail(r) > band_at-open:
			if pieces.is_empty(): return {}
			break
		pieces.append(r)
		at = r.end
		if not outer and at >= band_at+into: break
	var last: Dictionary = pieces[-1]
	if outer:
		# Stretched so its rock ends a pass short of the band's.
		var s: Vector3 = last.scale
		s.x = clampf((band_at-open-float(last.start))/(float(last.over.y)-float(last.span.x)),s.x,s.x*1.3)
		last.scale = s
		last.end = float(last.start)+_crest_length(last)
		gap = Vector2(float(last.end)+_over_tail(last),band_at)
	else:
		if (kind == "side" and gap_joint < 0) or gap.y > band_at-150.0 or at < band_at+into: return {}
		# Into the band's rock, no further.
		if at > band_at+into+200.0:
			var s: Vector3 = last.scale
			s.x = maxf((band_at+into+100.0-float(last.start))/(float(last.span.y)-float(last.span.x)),0.55)
			last.scale = s
			last.end = float(last.start)+_crest_length(last)
	for r: Dictionary in pieces:
		var a := _along(line,float(r.start))
		var b := _along(line,float(r.end))
		_lay(r,Vector3(a.x,0.0,a.y),Vector3(b.x,0.0,b.y))
		_tighten(r)
	last.last = true
	if kind == "home" or kind == "wall": return {"pieces":pieces,"pass":{}}
	# The col: a low saddle across the pass, under it at glide height.
	var col := _col(line,gap,rng)
	if not col.is_empty(): pieces.append(col)
	var mid := _along(line,(gap.x+gap.y)*0.5)
	var along := (_along(line,gap.y)-_along(line,gap.x)).normalized()
	return {"pieces":pieces,"pass":{"at":Vector3(mid.x,0.0,mid.y),"along":Vector3(along.x,0.0,along.y),"way":Vector3(-along.y,0.0,along.x),"open":roundf(gap.y-gap.x),"root":outer}}

## The col across a pass `gap` (m along `line`, from and to), or empty.
static func _col(line: PackedVector2Array, gap: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	if gap.y-gap.x < 100.0: return {}
	var r := _ridge_draw("col",rng)
	if r.is_empty(): return {}
	var a := _along(line,gap.x-COL_LAP)
	var b := _along(line,gap.y+COL_LAP)
	_lay(r,Vector3(a.x,0.0,a.y),Vector3(b.x,0.0,b.y))
	_tighten(r)
	return r

## A ridge piece of `role` drawn from `rng` (as `_draw`): its seed, stature
## and scale, flipped end for end half the time, and its crest's spans as
## placed (its own x, as seen flipped): `span` over the height it is laid by
## (LAY_AT), `over` over PASS_TOP, `sea` over the sea (its rock's reach,
## OVER_HALF and ROCK_HALF at most). Drawn again until its crest stands
## that high for long enough.
static func _ridge_draw(role: String, rng: RandomNumberGenerator) -> Dictionary:
	var ys: Vector2 = {"knot":KNOT_Y,"wall":WALL_Y,"low":LOW_Y,"spur":SPUR_Y,"col":COL_Y}[role]
	var xs: Vector2 = {"knot":KNOT_X,"wall":RIDGE_X,"low":RIDGE_X,"spur":SPUR_X,"col":RIDGE_X}[role]
	var zs: Vector2 = {"spur":SPUR_Z,"col":COL_Z}.get(role,RIDGE_Z)
	for tries in range(40):
		var r := {"kind":"ridge","role":role,"seed":int(rng.randf()*16777216.0),"stature":1.0 if role == "knot" else rng.randf_range(0.85,1.0),
			"scale":Vector3(rng.randf_range(xs.x,xs.y),rng.randf_range(ys.x,ys.y),rng.randf_range(zs.x,zs.y)),"gorge":false,"flip":rng.randf() < 0.5,
			"coarse":role in ["low","spur","col"]}
		var y: float = r.scale.y
		var span := SkyPeak.crest_span(r.seed,r.stature,_unscaled(float(LAY_AT[role]),y))
		span = Vector2(maxf(span.x,-CREST_HALF),minf(span.y,CREST_HALF))
		if span.y-span.x < 250.0: continue
		var over := SkyPeak.crest_span(r.seed,r.stature,_unscaled(PASS_TOP,y))
		var sea := SkyPeak.crest_span(r.seed,r.stature,SkyPeak.SEA)
		r.span = span
		r.over = Vector2(maxf(over.x,-OVER_HALF),minf(over.y,OVER_HALF))
		r.sea = Vector2(maxf(sea.x,-ROCK_HALF),minf(sea.y,ROCK_HALF))
		if r.flip:
			r.flip = false
			_ridge_turn(r)
		return r
	return {}

## A height as placed (m), in a range's own heights before its scale `y`.
static func _unscaled(h: float, y: float) -> float:
	return SkyPeak.SEA+(h-SkyPeak.SEA)/y

static func _ridge_turn(r: Dictionary) -> void:
	r.flip = not r.flip
	for key in ["span","over","sea"]: r[key] = Vector2(-float(r[key].y),-float(r[key].x))

## A laid ridge piece's box drawn tight: from its rock's start along its
## crest to its end (`sea`), BOX_MORE past each.
static func _tighten(r: Dictionary) -> void:
	var way := ((r.p_hi as Vector3)-(r.p_lo as Vector3)).normalized()
	var s: Vector3 = r.scale
	r.box_at = (r.at as Vector3)+way*(float(r.sea.x)+float(r.sea.y))*0.5*s.x
	r.half = Vector2((float(r.sea.y)-float(r.sea.x))*0.5*s.x+BOX_MORE,FLANK*s.z)

## A spur off one of the arms' walls, out into a region: its crest starting
## SPUR_FROM off the arm's, turned SPUR_TURN off the arm's way outward.
static func _spur(pieces: Array, rng: RandomNumberGenerator) -> Dictionary:
	var from: Array = pieces.filter(func(r: Dictionary) -> bool: return r.role == "wall")
	if from.is_empty(): return {}
	var p: Dictionary = from[rng.randi_range(0,from.size()-1)]
	var a: Vector3 = p.p_lo
	var b: Vector3 = p.p_hi
	var mid := Vector2((a.x+b.x)*0.5,(a.z+b.z)*0.5)
	var way := Vector2(b.x-a.x,b.z-a.z).normalized().rotated(rng.randf_range(SPUR_TURN.x,SPUR_TURN.y)*(1.0 if rng.randf() < 0.5 else -1.0))
	var r := _ridge_draw("spur",rng)
	if r.is_empty(): return {}
	if r.span.x > -r.span.y: _ridge_turn(r)
	var start := mid+way*SPUR_FROM
	var end := start+way*_crest_length(r)
	_lay(r,Vector3(start.x,0.0,start.y),Vector3(end.x,0.0,end.y))
	_tighten(r)
	for q: Vector2 in box_outline(r):
		if q.length() > SCATTER: return {}
	return r

## True if a ridge piece stands clear of the plate, the fixed islands, the
## cumulus in sight of the plate (and the other wonders there, if they
## stand), the range in sight of it and the islands' jet streams.
static func _clear(r: Dictionary, home: Dictionary, air: Array) -> bool:
	if box_distance(r,Vector2.ZERO) < PLATE_ROOM: return false
	for s: Vector3 in SLOTS.slice(1):
		if box_distance(r,Vector2(s.x,s.z)) < ISLAND_ROOM: return false
	if box_distance(r,Vector2(SkyHomes.TOWER.x,SkyHomes.TOWER.z)) < SkyHomes.TOWER_KEEP+60.0: return false
	# The other wonders in sight of the plate, those standing (--wonders).
	for w: Array in SkyHomes.spots():
		var at: Vector3 = w[0]
		if at != SkyHomes.TOWER and at != SkyHomes.RANGE and box_distance(r,Vector2(at.x,at.z)) < float(w[1]): return false
	if not r.get("home_arm",false) and box_gap(r,home) < CORRIDOR: return false
	for p: Vector2 in air:
		if box_distance(r,p) < AIR_ROOM: return false
	return true

## The regions the ridges `pieces` cut the middle into, from the plan
## (`plan_open`, `basins`): {ok (every rule kept), kept (how many), rules,
## regions, basins, open}. The rules: as many regions as arms, all reached
## from each other through a pass, the plate's open round it with the range
## in sight of it, every region ROOM for islands, and a low stretch to hop.
static func _judge(pieces: Array, arms: int, band_open: PackedByteArray) -> Dictionary:
	var open := plan_open(pieces,band_open)
	var n := grid_size()
	var b := basins(open,n,GRID,CORE,PASS_HALF)
	var plate := _grid_index(Vector2.ZERO,n)
	var labels: PackedInt32Array = b.labels
	var dist: PackedFloat32Array = b.dist
	var home_label := labels[plate]
	var regions := []
	var rooms := []
	rooms.resize(int(b.count))
	rooms.fill(0)
	for c in range(n*n):
		if labels[c] < 0 or dist[c] < ROOM_CLEAR or open[c] != 2: continue
		rooms[labels[c]] += 1
	var roomy := true
	for k in range(int(b.count)):
		var area: float = rooms[k]*GRID*GRID/1.0e6
		if area < ROOM: roomy = false
		var heart := grid_point(int(b.hearts[k]),n)
		regions.append({"at":Vector3(heart.x,0.0,heart.y),"home":k == home_label,"area":snappedf(area,0.01),"label":k})
	# The range in sight of the plate: open all the way to its foot.
	var sight := true
	for t in range(0,40):
		var p := Vector2(SkyHomes.RANGE.x,SkyHomes.RANGE.z)*t/40.0*0.6
		if open[_grid_index(p,n)] == 0: sight = false
	var lows := pieces.any(func(r: Dictionary) -> bool: return r.role == "low")
	var rules := [int(b.count) == arms,bool(b.connected),home_label >= 0 and dist[plate] >= PLATE_OPEN,roomy,sight,lows]
	var kept := rules.count(true)
	return {"ok":kept == rules.size(),"kept":kept,"rules":rules,"regions":regions,"basins":b,"open":open}

## The plan's grid: points a side, a cell's middle (home, plate plane), the
## cell holding a point.
static func grid_size() -> int:
	return int(ceilf(GRID_HALF*2.0/GRID))+1

static func grid_point(c: int, n: int) -> Vector2:
	return Vector2(-GRID_HALF+(c%n)*GRID,-GRID_HALF+(c/n)*GRID)

static func _grid_index(p: Vector2, n: int) -> int:
	var i := clampi(roundi((p.x+GRID_HALF)/GRID),0,n-1)
	var j := clampi(roundi((p.y+GRID_HALF)/GRID),0,n-1)
	return j*n+i

## The band's open air on the plan's grid: 1 inside its crest line where
## its rock (its foothills aside: laid after the ridges) doesn't stand, along each range's rock
## (SEA_HALF less BAND_SHORT, times its scale) BAND_FLANK of its FLANK
## each side.
##
## 2 where it is open and within the bounds (`inside`: SCATTER, BAND_CLEAR
## off the band's rock and `feet`, its foothills): room for islands.
static func _band_open(band: Array, feet: Array = [], inner := PackedFloat32Array()) -> PackedByteArray:
	var n := grid_size()
	var open := PackedByteArray()
	open.resize(n*n)
	for c in range(n*n):
		var p := grid_point(c,n)
		open[c] = 1 if p.length() < crest(atan2(p.y,p.x)) else 0
	var lines := []
	for r: Dictionary in band:
		if not in_band(r.kind) or r.kind == "far" or r.kind == "foot": continue
		var s: Vector3 = r.scale
		var way := Vector3(1.0,0.0,0.0).rotated(Vector3.UP,float(r.turn))
		var reach := (SEA_HALF-BAND_SHORT)*s.x
		lines.append([(r.at as Vector3)-way*reach,(r.at as Vector3)+way*reach,FLANK*s.z*BAND_FLANK])
	_carve(open,lines)
	var keep_off: Array = band.filter(func(r: Dictionary) -> bool: return r.kind in ["run","massif","foot"])
	keep_off.append_array(feet)
	for c in range(n*n):
		if open[c] == 0: continue
		var p := grid_point(c,n)
		if p.length() > SCATTER: continue
		if p.length() < BAND_IN-BAND_CLEAR or (clear_of_band(p,keep_off) and _share(p,inner) == 0.0): open[c] = 2
	return open

## The plan's open air at glide height: the band's (`band_open`), less
## where a ridge's crest (and the range in sight of the plate's) stands
## over PASS_TOP, PROXY_HALF (times its scale across) each side.
static func plan_open(pieces: Array, band_open: PackedByteArray) -> PackedByteArray:
	var open := band_open.duplicate()
	var lines := []
	for r: Dictionary in pieces:
		if r.get("role","") == "col": continue
		var way := ((r.p_hi as Vector3)-(r.p_lo as Vector3)).normalized()
		var s: Vector3 = r.scale
		var at: Vector3 = r.at
		lines.append([at+way*float(r.over.x)*s.x,at+way*float(r.over.y)*s.x,PROXY_HALF*s.z,true])
	var home := _home_span()
	var home_way := Vector3(1.0,0.0,0.0).rotated(Vector3.UP,SkyHomes.RANGE_TURN)
	lines.append([SkyHomes.RANGE+home_way*home.x,SkyHomes.RANGE+home_way*home.y,PROXY_HALF,true])
	_carve(open,lines)
	return open

## The range in sight of the plate's crest over PASS_TOP (its own x, at
## most OVER_HALF each way).
static func _home_span() -> Vector2:
	var home := SkyPeak.crest_span(int(noise(Vector2i.ZERO,HOME_SALT)*16777216.0),1.0,PASS_TOP)
	return Vector2(maxf(home.x,-OVER_HALF),minf(home.y,OVER_HALF))

## Each [a, b (home), half, square] closed off the grid: rock within
## `half` of the line from a to b; cut square at its ends if `square`.
static func _carve(open: PackedByteArray, lines: Array) -> void:
	var n := grid_size()
	for l: Array in lines:
		var a := Vector2(l[0].x,l[0].z)
		var b := Vector2(l[1].x,l[1].z)
		var half: float = l[2]
		var lo := Vector2(minf(a.x,b.x),minf(a.y,b.y))-Vector2.ONE*half
		var hi := Vector2(maxf(a.x,b.x),maxf(a.y,b.y))+Vector2.ONE*half
		for j in range(maxi(0,floori((lo.y+GRID_HALF)/GRID)),mini(n-1,ceili((hi.y+GRID_HALF)/GRID))+1):
			for i in range(maxi(0,floori((lo.x+GRID_HALF)/GRID)),mini(n-1,ceili((hi.x+GRID_HALF)/GRID))+1):
				var p := Vector2(-GRID_HALF+i*GRID,-GRID_HALF+j*GRID)
				if l.size() > 3 and l[3]:
					var ab := b-a
					var t := (p-a).dot(ab)/maxf(ab.length_squared(),1e-6)
					if t < 0.0 or t > 1.0: continue
				if Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p) < half: open[j*n+i] = 0

## Basins in a grid of open air (`open`: 1 open, 0 rock; n a side, `cell` m
## apart, its edge taken as rock): every open cell's distance to rock
## (`dist`, m); the regions, the basins where an open disc `core` m round
## fits, apart, over `least` (km^2) of such ground (a smaller one is a nook
## of its neighbour's) (`count`, each cell's `labels` by the region nearest
## it through the open, -1 for none; `hearts`, each region's most open cell);
## and whether every region reaches every other through the open a pass
## `pass_half` each side of the way (`connected`). Read by the layout's
## plan and by tests/test_sky_world.gd on the ranges' real shapes.
static func basins(open: PackedByteArray, n: int, cell: float, core: float, pass_half: float, least := CORE_AREA) -> Dictionary:
	var dist := PackedFloat32Array()
	dist.resize(n*n)
	for c in range(n*n):
		var i := c%n
		var j := c/n
		dist[c] = 1.0e9 if open[c] >= 1 and i > 0 and j > 0 and i < n-1 and j < n-1 else 0.0
	var d1 := cell
	var d2 := cell*sqrt(2.0)
	for j in range(1,n-1):
		for i in range(1,n-1):
			var c := j*n+i
			if dist[c] == 0.0: continue
			dist[c] = minf(minf(dist[c],dist[c-1]+d1),minf(minf(dist[c-n]+d1,dist[c-n-1]+d2),dist[c-n+1]+d2))
	for j in range(n-2,0,-1):
		for i in range(n-2,0,-1):
			var c := j*n+i
			if dist[c] == 0.0: continue
			dist[c] = minf(minf(dist[c],dist[c+1]+d1),minf(minf(dist[c+n]+d1,dist[c+n+1]+d2),dist[c+n-1]+d2))
	var cores := _components(dist,n,core)
	var links := _components(dist,n,pass_half)
	# The nooks out, the rest numbered afresh.
	var sizes := {}
	for c in range(n*n):
		if cores[c] >= 0: sizes[cores[c]] = sizes.get(cores[c],0)+1
	var renumber := {}
	for k in range(sizes.size()):
		if sizes[k]*cell*cell/1.0e6 >= least: renumber[k] = renumber.size()
	for c in range(n*n):
		if cores[c] >= 0: cores[c] = renumber.get(cores[c],-1)
	var count := renumber.size()
	var hearts := []
	hearts.resize(count)
	hearts.fill(-1)
	var connected := true
	var link := -1
	var labels := PackedInt32Array()
	labels.resize(n*n)
	labels.fill(-1)
	var queue := PackedInt32Array()
	for c in range(n*n):
		var k := cores[c]
		if k < 0: continue
		if hearts[k] < 0 or dist[c] > dist[hearts[k]]: hearts[k] = c
		if link < 0: link = links[c]
		elif links[c] != link: connected = false
		labels[c] = k
		queue.append(c)
	# Every open cell to the region nearest it through the open.
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d: int in [-1,1,-n,n,-n-1,-n+1,n-1,n+1]:
			var e := c+d
			if e < 0 or e >= n*n or dist[e] == 0.0 or labels[e] >= 0: continue
			labels[e] = labels[c]
			queue.append(e)
	return {"count":count,"dist":dist,"labels":labels,"hearts":hearts,"connected":connected and count > 0}

## The 8-connected pieces of the cells at least `least` from rock: each
## cell's piece, -1 for none.
static func _components(dist: PackedFloat32Array, n: int, least: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(n*n)
	out.fill(-1)
	var count := 0
	var queue := PackedInt32Array()
	for c in range(n*n):
		if out[c] >= 0 or dist[c] < least: continue
		out[c] = count
		queue.clear()
		queue.append(c)
		var head := 0
		while head < queue.size():
			var at := queue[head]
			head += 1
			for d: int in [-1,1,-n,n,-n-1,-n+1,n-1,n+1]:
				var e := at+d
				if e < 0 or e >= n*n or out[e] >= 0 or dist[e] < least: continue
				out[e] = count
				queue.append(e)
		count += 1
	return out

## The cumulus, one in each region but the plate's (which has its own, in
## sight of the plate) where one has room: at its most open spot within
## the bounds, TOWER_IN inside them, that keeps a tower's room (SkyHomes
## TOWER_KEEP) from the home tower's, and TOWER_ROOM from every ridge's box
## and the range in sight of the plate's; one to a tower cell (TOWER_CELL,
## SkyTowers CELL).
static func _towers(pieces: Array, judged: Dictionary) -> Array:
	var out := []
	var b: Dictionary = judged.basins
	var n := grid_size()
	var labels: PackedInt32Array = b.labels
	var dist: PackedFloat32Array = b.dist
	var taken := [Vector2i.ZERO]
	var keep := SkyHomes.TOWER_KEEP
	var room := keep+TOWER_ROOM
	var home := {"at":SkyHomes.RANGE,"turn":SkyHomes.RANGE_TURN,"scale":Vector3.ONE}
	for region: Dictionary in judged.regions:
		if region.home: continue
		var cells := []
		for c in range(n*n):
			if labels[c] == int(region.label) and grid_point(c,n).length() <= SCATTER-TOWER_IN and b.dist[c] > 0.0 and judged.open[c] == 2: cells.append(c)
		cells.sort_custom(func(x: int, y: int) -> bool: return dist[x] > dist[y])
		for c: int in cells.slice(0,400):
			var p := grid_point(c,n)
			var at := Vector3(p.x,0.0,p.y)
			var cell := Vector2i(floori(p.x/TOWER_CELL+0.5),floori(p.y/TOWER_CELL+0.5))
			if cell in taken or p.distance_to(Vector2(SkyHomes.TOWER.x,SkyHomes.TOWER.z)) < keep*2.0 or box_distance(home,p) < room: continue
			if pieces.any(func(r: Dictionary) -> bool: return box_distance(r,p) < room): continue
			if not clear_of_band(p,judged.band,SkyHomes.TOWER_KEEP-BAND_CLEAR+TOWER_IN): continue
			out.append(at)
			taken.append(cell)
			break
	return out

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
## middle, half extents (along its crest, across) and turn. A ridge's is
## drawn tight round its rock (`_tighten`: `box_at`, `half`).
static func box_half(r: Dictionary) -> Vector2:
	if r.has("half"): return r.half
	var s: Vector3 = r.scale
	return Vector2(SEA_HALF*s.x,FLANK*s.z)

static func box_middle(r: Dictionary) -> Vector3:
	return r.get("box_at",r.at)

## How far a home point (plate plane) stands outside a range's box (0 in it).
static func box_distance(r: Dictionary, p: Vector2) -> float:
	var at := box_middle(r)
	var local := Vector3(p.x-at.x,0.0,p.y-at.z).rotated(Vector3.UP,-float(r.turn))
	var half := box_half(r)
	return Vector2(maxf(absf(local.x)-half.x,0.0),maxf(absf(local.z)-half.y,0.0)).length()

## The box's outline, points about every 40 m (home, plate plane).
static func box_outline(r: Dictionary) -> Array:
	var half := box_half(r)
	var out := []
	var at := box_middle(r)
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
	# Never changed under a worker reading it (`prepare`).
	settle()
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
