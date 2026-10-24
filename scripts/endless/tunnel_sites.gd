extends RefCounted
## Mountain tunnels (docs/design/endless-flight/overgrown-tunnels-brief.md,
## spec-mountain-tunnels.md): a massif raised over a winding bore, the bore
## running from a mouth on one flank to a mouth on the other. A layer over
## the land field, as the ponds and the slot halls' cuts are: LandField
## (land_field.gd) raises the massif and cuts the mouths' trenches after the
## ponds, before the slot halls' cut, so the recipe and the native kernels
## don't change and wilderness (no `tunnels` layer) hashes as before.
##
## The path: alternating straight hall stretches (whole hall bays, `hall`)
## and caverns of bare rock (`cave`), a cavern holding one to three gentle
## bends (arcs of RADIUS m, TURN rad, their turns alternating so the run
## never strays far from its first way) with short straight runs between.
## The floor is level from mouth to mouth. The path is kept as samples
## STEP m apart along it (`pts`, `tans`, `ss`), and as a table over its
## first way (`u`, from mouth A): the path's offset across, its tangent's
## cos and sin and the distance along it, every STEP m of `u`. The path
## never turns past a right angle from its first way, so each `u` has one
## path point, and `local` reads (distance along, offset across) from it.
##
## The massif: a crest along the path, COVER_MOUTH m over the floor at a
## mouth, rising over RISE m to `crest` m over the floor (varied by noise,
## a short range of peaks and saddles), its flanks falling at FLANK with
## gullies of noise, and past the mouths its nose falling at END. It is
## blended into the land with a smooth max (BLEND m), so it has no plinth
## edge and the land past it is the land exactly. Each mouth then has a
## trench cut into the nose, as hall_sites.gd's cut is: flat for APRON m
## at the floor, then climbing at GRADE to the land, with sheer walls
## leaning back.
##
## `--tunnel-test`: one tunnel TEST_AHEAD m ahead of the start, on its
## heading (the world's spawn, `--at=` and `--heading=`). Named
## `<world>/tunnel/test`; a streamed tunnel will be `<world>/tunnel/<cx>_<cz>`.
## Placed through scripts/layout_overrides.gd: a move in the layout file
## moves mouth A (its yaw and place), and the path, the massif and the
## trenches follow.

const SEA_Y := -40.0
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const Sites = preload("res://scripts/endless/hall_sites.gd")
const Sundered = preload("res://scripts/sundered_hall.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The bore's cross-section (m): its half width and its vault's crown over
## the floor, in the hall stretches (the slot halls' walls' outer faces)
## and in the caverns (wider and taller; wider still on a bend's inside).
static var HALL_HALF: float = Sites.HALF
const HALL_VAULT := 18.0
static var CAVE_HALF: float = Sites.HALF+5.0
const CAVE_VAULT := 22.0
const CAVE_INSIDE := 6.0

## The caverns' carved rock (knobs): its cross-section a superellipse from
## the floor's edge on one side over the crown to the other, |x|^n + |y|^n
## = 1 (n: CAVE_ROUND, rolled along the path; lower is rounder), so the
## walls rise steeply from the floor and curve into the vault. A hall
## stretch's tube is the same shape at HALL_ROUND (all but square). The
## walls swell in and out by ROCK_SWELL m (the vault by VAULT_SWELL) over
## ROCK_WAVE m along the path; the inside of a bend gets up to CAVE_INSIDE
## m more room (full where the path turns INSIDE_TURN rad over
## 2*BEND_LOOK m). The mesh lumps outward only, into the rock (ROCK_LUMP m,
## noise ROCK_GRAIN m), so the solid (`bore_at`) is never outside what is
## seen.
const CAVE_ROUND := Vector2(2.6,3.6)
const HALL_ROUND := 24.0
const ROCK_SWELL := 1.8
const VAULT_SWELL := 2.0
const ROCK_WAVE := 34.0
const INSIDE_TURN := 0.1
const BEND_LOOK := 20.0
const ROCK_LUMP := 1.4
const ROCK_GRAIN := 9.0

## The path: its length (m, rolled), the bends over the run, a bend's
## radius (m) and turn (rad), a cavern's straight runs between its bends
## and at its ends (m), a hall stretch's fewest bays, the samples' spacing.
const LENGTH := Vector2(1400.0,2100.0)
const BENDS := Vector2i(3,5)
const RADIUS := Vector2(130.0,220.0)
const TURN := Vector2(deg_to_rad(22.0),deg_to_rad(34.0))
const CAVE_RUN := Vector2(20.0,60.0)
const CAVE_END := 16.0
const HALL_BAYS_MIN := 10
const STEP := 4.0

## The massif: its crest over the floor (m, rolled), at least CREST_OVER m
## over the highest land on the path; over the floor at a mouth (m); the
## rise from a mouth to the crest (m along); how much the crest dips in its
## saddles (0..1) and the noise's wavelength (m); the flanks' fall (rise
## over run) and the crest's rounding (m across); the nose's fall past a
## mouth; the blend into the land (m); the gullies' depth (m) and
## wavelength (m), and from how far off the path they start (m).
const CREST := Vector2(280.0,380.0)
const CREST_OVER := 150.0
const COVER_MOUTH := 34.0
const RISE := 650.0
const CREST_VARY := 0.34
const CREST_WAVE := 380.0
const FLANK := 0.62
## How much each flank's fall varies along the path (0..1): shoulders and
## steeper faces, each side its own.
const FLANK_VARY := 0.3
const CREST_R := 45.0
const END := 0.7
const BLEND := 30.0
const GULLY := 70.0
const GULLY_WAVE := 240.0
const GULLY_FROM := Vector2(35.0,170.0)
## The meadow fades over this much lift (m), and no river runs on lifted land.
const MEADOW_LIFT := Vector2(4.0,30.0)

## The mouths' trenches (hall_sites.gd's cut): the walls' rise, sheer
## height and lean, the floor's sink, the flat, the climb and its most.
const EDGE := Sites.EDGE
const SHEER := Sites.SHEER
const LEAN := Sites.LEAN
const SINK := Sites.SINK
const APRON := 24.0
const GRADE := Sites.GRADE
const RAMP_MOST := 100.0
static var TRENCH_WIDE: float = HALL_HALF+EDGE+60.0
const TRENCH_REACH := APRON+RAMP_MOST

## `--tunnel-test`: mouth A this far ahead of the start (m).
const TEST_AHEAD := 450.0

## The box (Site `box`): the path grown, every BOX_EVERY samples, by the
## reach of its flanks down to LOW m under the floor (times BOX_SLACK, and
## the samples' spacing); where the land falls lower still the massif's
## lift fades out over EDGE_FADE m inside the box's edge, so a point past
## the box never needs it.
const LOW := 60.0
const BOX_EVERY := 6
const BOX_SLACK := 1.1
const EDGE_FADE := 160.0

## Streamed tunnels (knobs): at most one per CELL m square, from the seed
## and the square alone, as hall_sites.gd's are. A square rolls (CHANCE
## times the density, up to CHANCE_MAX), then makes TRIES tries: a path
## turned to YAWS headings, each put near the square's middle (its box
## moved up to JITTER of the room the square leaves it), the floor at the
## lower mouth's land. A heading stands when its box lies CELL_MARGIN m
## inside the square (so a point asks only its own square), both mouths
## are DRY m over the sea with their land within MOUTH_SPREAD m, no river
## lies within MOUTH_DRY m of a mouth under the lifted land (`_wet`), and a
## flat lies within FLAT_REACH m of each mouth (FLAT_RUN m of land within
## FLAT_RISE m, dry, read every FLAT_STEP m on FLAT_FAN rays out of it). Of
## those, the one whose path runs under the most land already standing
## over the floor (a ridge or a hill), less RIVER_COST m for each sample of
## river it buries, wins: the massif eats the fewest flats and rivers.
## Ponds are left as they are: the massif's flanks rise out of any under it.
const CELL := 4096.0
const CHANCE := 0.85
const CHANCE_MAX := 0.95
const TRIES := 6
const YAWS := 8
const JITTER := 0.8
const CELL_MARGIN := 32.0
const DRY := 6.0
const MOUTH_SPREAD := 24.0
const RIVER_OFF := 40.0
const RIVER_LIFT := 2.0
const MOUTH_DRY := 300.0
const RIVER_COST := 3.0
const SCAN := 128.0
const FLAT_REACH := 1100.0
const FLAT_RUN := 192.0
const FLAT_RISE := 4.0
const FLAT_STEP := 16.0
const FLAT_FAN := [-0.6,-0.3,0.0,0.3,0.6]

static var _cache := {}
static var _lock := Mutex.new()
## Why tries fell (a count by reason, for the drivers).
static var why := {}

static func _why(k: String) -> void:
	_lock.lock()
	why[k] = int(why.get(k,0))+1
	_lock.unlock()

## The shafts to the sky (sundered_hall.gd's MAX_SHUT: a long shut run needs
## a way out, and a glimpse of daylight partway through), knobs: in up to
## SHAFT_MOST caverns (`--tunnel-shafts=N`), the deepest first, over the
## middle of the cavern's longest bend, a round shaft SHAFT_R m in radius
## rises from the vault's crown through SHAFT_ROCK m of rock to the floor
## of a sinkhole sunk into the massif: flat PIT_FLOOR m round the shaft,
## its walls rising at PIT_WALL (rise over run), ragged by up to PIT_RAGGED
## m, into the massif with a smooth min of PIT_BLEND m. No shaft where the
## massif stands less than SHAFT_DEEP m over the shaft's top. The land mesh
## drops its triangles within SHAFT_R+HOLE_PAD m of the axis (portal_mask);
## land_tunnels.gd's curb covers the hole's edge.
const SHAFT_MOST := 2
const SHAFT_R := 7.0
const SHAFT_ROCK := 28.0
const SHAFT_DEEP := 30.0
const PIT_FLOOR := 26.0
const PIT_WALL := 1.7
const PIT_RAGGED := 7.0
const PIT_BLEND := 14.0
const HOLE_PAD := 3.0

## The shelves (knobs; AGENTS.md's meadows and flats: a landing flat in
## reach on a massif's top too): along the crest where it stands high
## enough, the crest planed off flat at SHELF_CUT m under its lowest over
## runs of up to SHELF_LEN m (at least SHELF_MIN, SHELF_GAP m of crest
## between them), the flat as wide as the massif stands over it, open to
## both flanks, its ends rising back to the crest at
## SHELF_WALL (rise over run, ragged by SHELF_RAGGED m) with a smooth min of
## SHELF_BLEND m. A shelf leaves SHELF_ROCK m of rock over the vault, keeps
## SHELF_SHAFT m along the path from a shaft's sinkhole's rim, and has no gullies within
## SHELF_SPAN m of the path (fading out over SHELF_FADE m); its floor is a
## meadow (SHELF_MEADOW). Only the massif is planed: land standing higher
## stays. `--tunnel-shelves=0` turns them off.
const SHELF_LEN := 320.0
const SHELF_MIN := 180.0
const SHELF_GAP := 220.0
const SHELF_CUT := 75.0
const SHELF_WALL := 0.9
const SHELF_RAGGED := 6.0
const SHELF_BLEND := 10.0
const SHELF_ROCK := 60.0
const SHELF_SHAFT := 15.0
const SHELF_SPAN := 220.0
const SHELF_FADE := 80.0
const SHELF_MEADOW := 0.9

## One tunnel. Built once (on whichever thread asks first), then only read.
class Site extends RefCounted:
	var name := ""
	## Mouth A on the floor, the way in along +X (the hall frame's way).
	var frame := Transform3D()
	var coded := Transform3D()
	var seed := 0
	var floor_y := 0.0
	## The crest over the floor at its highest (m).
	var crest := 0.0
	var length := 0.0
	## The pieces in order: {kind ("hall"/"cave"), s0, s1, and for a hall
	## its bays, for a cave its bends}; the segments: {piece, type
	## ("line"/"arc"), s0, s1, turn, radius}.
	var pieces: Array = []
	var segs: Array = []
	## The samples along the path (world xz), their tangents and distances.
	var pts := PackedVector2Array()
	var tans := PackedVector2Array()
	var ss := PackedFloat32Array()
	## Mouth A (xz) and the first way; mouth B and its way out.
	var origin := Vector2.ZERO
	var way := Vector2.RIGHT
	var mouth_b := Vector2.ZERO
	var out_b := Vector2.RIGHT
	## The table over u (every STEP m from mouth A along `way`).
	var u_end := 0.0
	var tv := PackedFloat32Array()
	var tc := PackedFloat32Array()
	var tsn := PackedFloat32Array()
	var ts := PackedFloat32Array()
	## Everything the massif and the trenches touch (world xz).
	var box := Rect2()
	var crest_noise: FastNoiseLite
	var gully: FastNoiseLite
	## The bore's carved profile at each sample (`ss`): the half width on
	## the -d and the +d side, the crown over the floor, the roundness
	## (`profile`); `rock` swells the walls along the path and lumps the
	## carved rock's mesh.
	var wn := PackedFloat32Array()
	var wp := PackedFloat32Array()
	var vt := PackedFloat32Array()
	var rn := PackedFloat32Array()
	var rock: FastNoiseLite
	## The shafts: {s (along the path), at (the axis, world xz), top (the
	## pit's floor, world y), crown (the vault's crown under it, world y)}.
	var shafts: Array = []
	## The shelves: {a, b (the flat's run along the path), y (its floor,
	## world y)}, the crest planed off over a hall stretch's middle.
	var shelves: Array = []

## The tunnels' density: the world's `tunnels` layer (0: none), then
## `--tunnels=X` or `--no-tunnels`.
static func wanted(default := 0.0) -> float:
	var out := default
	for a: String in LaunchArgs.user_args():
		if a == "--no-tunnels": out = 0.0
		elif a.begins_with("--tunnels="): out = maxf(0.0,float(a.get_slice("=",1)))
	return out

## Whether `--tunnel-test` asks for the one tunnel ahead of the start.
static func test_wanted() -> bool:
	return "--tunnel-test" in LaunchArgs.user_args()

## How many caverns get a shaft: SHAFT_MOST, or `--tunnel-shafts=N`.
static func shelves_wanted() -> bool:
	return not ("--tunnel-shelves=0" in LaunchArgs.user_args())

static func shafts_wanted() -> int:
	var out := SHAFT_MOST
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--tunnel-shafts="): out = maxi(0,int(a.get_slice("=",1)))
	return out

## The test tunnel: mouth A TEST_AHEAD m ahead of the start on its heading,
## the floor at the land there (read from `impl`, the field doing the work,
## at full detail). `world` the WorldProfile (its spawn).
static func test_site(impl: Object, seed: int, world: RefCounted) -> Site:
	var at: Vector2 = world.spawn.get("at",Vector2.ZERO)
	var deg := float(world.spawn.get("heading",0.0))
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--at="):
			var p := a.get_slice("=",1).split(",")
			if p.size() >= 2: at = Vector2(float(p[0]),float(p[1]))
		elif a.begins_with("--heading=") and a != "--heading=sun": deg = float(a.get_slice("=",1))
	# Clockwise from -z.
	var fwd := Vector2(sin(deg_to_rad(deg)),-cos(deg_to_rad(deg)))
	var mouth := at+fwd*TEST_AHEAD
	var was: float = impl.detail
	impl.detail = 0.0
	var floor_y := maxf(_h(impl,mouth.x,mouth.y),SEA_Y+3.0)
	var name := "%s/tunnel/test" % _world_id()
	var coded := Transform3D(Basis(Vector3.UP,atan2(-fwd.y,fwd.x)),Vector3(mouth.x,floor_y,mouth.y))
	var xf := LayoutOverrides.xform(name,coded)
	var frame := Transform3D(Basis(Vector3.UP,atan2(-xf.basis.x.z,xf.basis.x.x)),xf.origin)
	var t := _build(impl,hash([seed,"tunnel_test"]),frame,true)
	impl.detail = was
	t.name = name
	t.coded = coded
	return t

static func _h(impl: Object, x: float, z: float) -> float:
	return (impl.sample(x,z) as Vector2).x

# --- Streamed sites ------------------------------------------------------------------

## The tunnels (none or one Site) of the CELL square `key`, as hall_sites.gd
## `cell_site`: `impl` the field doing the work (its last sample is
## overwritten when the square is first looked at, read at full detail);
## `local` the asking LandField's own cache.
static func cell_sites(impl: Object, seed: int, density: float, key: Vector2i, local: Dictionary) -> Array:
	var got: Variant = local.get(key)
	if got != null: return got
	var k4 := Vector4i(key.x,key.y,seed,int(density*1000.0))
	_lock.lock()
	got = _cache.get(k4)
	_lock.unlock()
	if got == null:
		var was: float = impl.detail
		impl.detail = 0.0
		var t := _make(impl,seed,density,key.x,key.y)
		impl.detail = was
		got = [] if t == null else [t]
		_lock.lock()
		# Whichever thread made it first, every field shares one Site.
		if _cache.has(k4): got = _cache[k4]
		else: _cache[k4] = got
		_lock.unlock()
	local[key] = got
	return got

## The square key holding (x, z).
static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x/CELL),floori(z/CELL))

## Square (ci, cj)'s tunnel, or null.
static func _make(impl: Object, seed: int, density: float, ci: int, cj: int) -> Site:
	if density <= 0.0: return null
	if float(hash([seed,ci,cj,"tunnel_roll"]) & 0xffffff)/16777216.0 >= minf(CHANCE*density,CHANCE_MAX): return null
	var name := "%s/tunnel/%d_%d" % [_world_id(),ci,cj]
	if LayoutOverrides.deleted(name): return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed,ci,cj,"tunnel_place"])
	var sq := Rect2(ci*CELL,cj*CELL,CELL,CELL).grow(-CELL_MARGIN)
	var best: Site = null
	var best_score := -INF
	for k in TRIES:
		var tseed := hash([seed,ci,cj,"tunnel",k])
		var jit := Vector2(rng.randf_range(-1.0,1.0),rng.randf_range(-1.0,1.0))
		var yaw0 := rng.randf()*TAU
		# The path's shape (a dry run at the origin along +X), turned to each
		# of YAWS headings: its box centred in the room the square leaves it,
		# its mouths on land, scored by the land over its floor.
		var dry := _build(null,tseed,Transform3D.IDENTITY,false)
		var reach := _box_reach(dry)
		for w in YAWS:
			var yaw := yaw0+w*TAU/YAWS
			var box := Rect2(dry.pts[0].rotated(-yaw),Vector2.ZERO)
			for i in reach.size(): box = box.merge(Rect2(dry.pts[_box_i(dry,i)].rotated(-yaw)-Vector2(reach[i],reach[i]),Vector2(reach[i],reach[i])*2.0))
			if box.size.x > sq.size.x or box.size.y > sq.size.y:
				_why("box")
				continue
			var room := (sq.size-box.size)*0.5*JITTER
			var a := sq.get_center()+jit*room-box.get_center()
			var b := a+dry.mouth_b.rotated(-yaw)
			# The floor: the lower mouth's land (the higher one's trench cuts down).
			var ha := _h(impl,a.x,a.y)
			var hb := _h(impl,b.x,b.y)
			if minf(ha,hb) < SEA_Y+DRY:
				_why("sea")
				continue
			if absf(ha-hb) > MOUTH_SPREAD:
				_why("mouths")
				continue
			var floor_y := minf(ha,hb)
			var score := _hill(impl,dry,a,yaw,floor_y)
			if score <= best_score: continue
			var t := _build(impl,tseed,Transform3D(Basis(Vector3.UP,yaw),Vector3(a.x,floor_y,a.y)),false)
			if not sq.encloses(t.box):
				_why("box")
				continue
			var wet := _wet(impl,t)
			if wet < 0:
				_why("wet")
				continue
			score -= RIVER_COST*wet
			if score <= best_score: continue
			if not (_flat_near(impl,t,0) and _flat_near(impl,t,1)):
				_why("flat")
				continue
			best = t
			best_score = score
	if best == null: return null
	# Placed through the layout file, as the test tunnel is.
	var coded := best.frame
	var xf := LayoutOverrides.xform(name,coded)
	if not xf.is_equal_approx(coded):
		var frame := Transform3D(Basis(Vector3.UP,atan2(-xf.basis.x.z,xf.basis.x.x)),xf.origin)
		best = _build(impl,best.seed,frame,false)
	best.name = name
	best.coded = coded
	return best

## The box's samples along the path (every BOX_EVERY, and the last) and
## each one's reach (m, Site `box`).
static func _box_i(t: Site, i: int) -> int:
	return mini(i*BOX_EVERY,t.pts.size()-1)

static func _box_reach(t: Site) -> PackedFloat32Array:
	var slope := FLANK*(1.0-FLANK_VARY)
	var out := PackedFloat32Array()
	for i in ceili(float(t.pts.size()-1)/BOX_EVERY)+1:
		out.append(((top(t,t.ss[_box_i(t,i)])-t.floor_y+LOW+GULLY+BLEND)/slope+CREST_R)*BOX_SLACK+STEP*BOX_EVERY)
	return out

## How much land already stands over `floor_y` along path `t` (m, the
## mean), turned by `yaw` and moved to mouth A at `a`: a ridge or a hill
## the bore runs under scores high.
static func _hill(impl: Object, t: Site, a: Vector2, yaw: float, floor_y: float) -> float:
	var sum := 0.0
	var n := 0
	var k := 0
	while k < t.pts.size():
		var p := a+(t.pts[k]-t.origin).rotated(-yaw)
		sum += maxf(_h(impl,p.x,p.y)-floor_y,0.0)
		n += 1
		k += 8
	return sum/maxi(n,1)

## The rivers the massif would bury: how many samples (every SCAN m over
## the box) where it lifts the land RIVER_LIFT m or more lie within
## RIVER_OFF m of a river, or -1 where one lies within MOUTH_DRY m of a
## mouth (no river runs into a mouth). The field clears a buried river's
## water (LandField `last_river`, apply_chunk), so it ends at the flank.
## The sea may lie under the far flanks: they rise out of it as a coast.
static func _wet(impl: Object, t: Site) -> int:
	var out := 0
	var z := t.box.position.y+SCAN*0.5
	while z < t.box.end.y:
		var x := t.box.position.x+SCAN*0.5
		while x < t.box.end.x:
			var h := _h(impl,x,z)
			if h > SEA_Y and float(impl.last_river) < RIVER_OFF and massif(t,x,z) > h+RIVER_LIFT:
				if Vector2(x,z).distance_to(t.origin) < MOUTH_DRY or Vector2(x,z).distance_to(t.mouth_b) < MOUTH_DRY: return -1
				out += 1
			x += SCAN
		z += SCAN
	return out

## Whether a flat lies within FLAT_REACH m out of mouth `m` (past its
## trench): FLAT_RUN m of dry land within FLAT_RISE m on one of the rays.
static func _flat_near(impl: Object, t: Site, m: int) -> bool:
	var at: Vector2 = t.origin if m == 0 else t.mouth_b
	var o: Vector2 = -t.way if m == 0 else t.out_b
	var need := ceili(FLAT_RUN/FLAT_STEP)+1
	for turn: float in FLAT_FAN:
		var d := o.rotated(turn)
		var run := PackedFloat32Array()
		var a := TRENCH_REACH
		while a < FLAT_REACH:
			var p := at+d*a
			var h := _h(impl,p.x,p.y)
			if h < SEA_Y+DRY or float(impl.last_river) < 20.0: run.clear()
			else:
				run.append(h)
				# Drop from the front till the run lies within FLAT_RISE.
				while run.size() > 1:
					var lo := INF
					var hi := -INF
					for v: float in run:
						lo = minf(lo,v)
						hi = maxf(hi,v)
					if hi-lo <= FLAT_RISE: break
					run.remove_at(0)
				if run.size() >= need: return true
			a += FLAT_STEP
	return false

static func _world_id() -> String:
	return String(preload("res://scripts/endless/world/world_profile.gd").current().id)

# --- The path ----------------------------------------------------------------------

## A tunnel from frame `frame` (mouth A on the floor, the way in along +X),
## its path rolled from `seed`. `test`: 2 or 3 hall stretches, else 3 to 5.
static func _build(impl: Object, seed: int, frame: Transform3D, test: bool) -> Site:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var t := Site.new()
	t.seed = seed
	t.frame = frame
	t.floor_y = frame.origin.y
	t.origin = Vector2(frame.origin.x,frame.origin.z)
	t.way = Vector2(frame.basis.x.x,frame.basis.x.z).normalized()
	var halls := rng.randi_range(2,3) if test else rng.randi_range(3,5)
	var caves := halls-1
	var bends := rng.randi_range(BENDS.x,BENDS.y)
	bends = clampi(bends,caves,caves*3)
	var per: Array = []
	for c in caves: per.append(1)
	for b in bends-caves: per[b % caves] += 1
	# The caverns' segments, their bends alternating.
	var sign := 1.0 if rng.randf() < 0.5 else -1.0
	var cave_segs: Array = []
	var cave_len := 0.0
	for c in caves:
		var list: Array = [{"type":"line","len":CAVE_END,"turn":0.0,"radius":0.0}]
		for b in int(per[c]):
			if b > 0: list.append({"type":"line","len":rng.randf_range(CAVE_RUN.x,CAVE_RUN.y),"turn":0.0,"radius":0.0})
			var r := rng.randf_range(RADIUS.x,RADIUS.y)
			var a := rng.randf_range(TURN.x,TURN.y)
			list.append({"type":"arc","len":r*a,"turn":a*sign,"radius":r})
			sign = -sign
		list.append({"type":"line","len":CAVE_END,"turn":0.0,"radius":0.0})
		for sg: Dictionary in list: cave_len += float(sg.len)
		cave_segs.append(list)
	# The hall stretches share the rest, in whole bays.
	var want := rng.randf_range(LENGTH.x,LENGTH.y)
	var weights: Array = []
	var wsum := 0.0
	for h in halls:
		var w := rng.randf_range(0.8,1.2)
		weights.append(w)
		wsum += w
	var hall_bays: Array = []
	for h in halls:
		hall_bays.append(maxi(HALL_BAYS_MIN,roundi((want-cave_len)*float(weights[h])/wsum/Hall.BAY)))
	# Lay the pieces out.
	var s := 0.0
	for h in halls:
		var hl := int(hall_bays[h])*Hall.BAY
		t.pieces.append({"kind":"hall","s0":s,"s1":s+hl,"bays":int(hall_bays[h])})
		t.segs.append({"piece":t.pieces.size()-1,"type":"line","s0":s,"s1":s+hl,"turn":0.0,"radius":0.0})
		s += hl
		if h == halls-1: break
		var c0 := s
		for sg: Dictionary in cave_segs[h]:
			t.segs.append({"piece":t.pieces.size(),"type":sg.type,"s0":s,"s1":s+float(sg.len),"turn":sg.turn,"radius":sg.radius})
			s += float(sg.len)
		t.pieces.append({"kind":"cave","s0":c0,"s1":s,"bends":int(per[h])})
	t.length = s
	_sample_path(t)
	_table(t)
	_carve_profile(t)
	# The crest: over the highest land on the path by CREST_OVER at least
	# (without a field, a dry run for the path's shape: the rolled crest).
	var land_top := t.floor_y
	var k := 0
	while impl != null and k < t.pts.size():
		land_top = maxf(land_top,_h(impl,t.pts[k].x,t.pts[k].y))
		k += 12
	t.crest = maxf(rng.randf_range(CREST.x,CREST.y),land_top-t.floor_y+CREST_OVER)
	t.crest_noise = FastNoiseLite.new()
	t.crest_noise.seed = seed & 0x7fffffff
	t.crest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	t.crest_noise.frequency = 1.0/CREST_WAVE
	t.crest_noise.fractal_octaves = 3
	t.gully = FastNoiseLite.new()
	t.gully.seed = (seed >> 3) & 0x7fffffff
	t.gully.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	t.gully.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	t.gully.frequency = 1.0/GULLY_WAVE
	t.gully.fractal_octaves = 4
	# The box: each stretch of the path grown by its flanks' reach (where
	# the massif falls LOW m under the floor), so it hugs the low noses at
	# the mouths and swells round the crest.
	var reach := _box_reach(t)
	t.box = Rect2(t.pts[0],Vector2.ZERO)
	for i in reach.size():
		var p := t.pts[_box_i(t,i)]
		t.box = t.box.merge(Rect2(p-Vector2(reach[i],reach[i]),Vector2(reach[i],reach[i])*2.0))
	_place_shafts(t)
	_place_shelves(t)
	return t

## The shafts (SHAFT_MOST): over the middle of each cavern's longest bend,
## the deepest from the mouths first, where the massif stands SHAFT_DEEP m
## over the shaft's top.
static func _place_shafts(t: Site) -> void:
	var picks: Array = []
	for pi in t.pieces.size():
		if t.pieces[pi].kind != "cave": continue
		var best := -1.0
		var at_s_mid := 0.0
		for sg: Dictionary in t.segs:
			if int(sg.piece) != pi or sg.type != "arc": continue
			if float(sg.s1)-float(sg.s0) > best:
				best = float(sg.s1)-float(sg.s0)
				at_s_mid = (float(sg.s0)+float(sg.s1))*0.5
		if best > 0.0: picks.append(at_s_mid)
	picks.sort_custom(func(a: float, b: float) -> bool: return minf(a,t.length-a) > minf(b,t.length-b))
	for s: float in picks:
		if t.shafts.size() >= shafts_wanted(): break
		var pr := profile(t,s)
		var at: Array = at_s(t,s)
		var tg: Vector2 = at[1]
		var axis: Vector2 = (at[0] as Vector2)+Vector2(-tg.y,tg.x)*(pr.y-pr.x)*0.5
		var crown := t.floor_y+pr.z
		var top_y := crown+SHAFT_ROCK
		if massif(t,axis.x,axis.y) < top_y+SHAFT_DEEP: continue
		t.shafts.append({"s":s,"at":axis,"top":top_y,"crown":crown})

## The shelves: along the crest where it stands high enough over the
## vault, clear of the shafts' sinkholes (as wide as they are at the
## shelf's height), in runs of up to SHELF_LEN m, SHELF_GAP m of crest
## between them.
static func _place_shelves(t: Site) -> void:
	if not shelves_wanted(): return
	var need := t.floor_y+CAVE_VAULT+CAVE_INSIDE+SHELF_ROCK+SHELF_CUT
	# Where the crest is high enough, every STEP*2 m.
	var free: Array = []
	var s := 0.0
	var from := -1.0
	while s <= t.length:
		var ok := top(t,s) >= need
		if ok:
			for sh: Dictionary in t.shafts:
				var r := (top(t,float(sh.s))-SHELF_CUT-float(sh.top))/PIT_WALL+PIT_FLOOR+SHELF_SHAFT
				if absf(s-float(sh.s)) < r: ok = false
		if ok and from < 0.0: from = s
		if not ok and from >= 0.0:
			free.append(Vector2(from,s-STEP*2.0))
			from = -1.0
		s += STEP*2.0
	if from >= 0.0: free.append(Vector2(from,t.length))
	for iv: Vector2 in free:
		var span := iv.y-iv.x
		if span < SHELF_MIN: continue
		var k := maxi(1,floori((span+SHELF_GAP)/(SHELF_LEN+SHELF_GAP)))
		var run := minf(SHELF_LEN,(span-(k-1)*SHELF_GAP)/k)
		if run < SHELF_MIN:
			k = 1
			run = minf(SHELF_LEN,span)
		var gap := (span-k*run)/maxi(k-1,1) if k > 1 else 0.0
		var a := iv.x if k > 1 else (iv.x+iv.y-run)*0.5
		for n in k:
			var b := a+run
			var lo := INF
			var q := a
			while q <= b:
				lo = minf(lo,top(t,q))
				q += STEP*2.0
			lo = minf(lo,top(t,b))
			t.shelves.append({"a":a,"b":b,"y":lo-SHELF_CUT})
			a = b+gap

## The path's samples every STEP m (and its end), from its segments.
static func _sample_path(t: Site) -> void:
	var p := t.origin
	var d := t.way
	t.pts.append(p)
	t.tans.append(d)
	t.ss.append(0.0)
	for sg: Dictionary in t.segs:
		var s0 := float(sg.s0)
		var s1 := float(sg.s1)
		var n := maxi(1,ceili((s1-s0)/STEP))
		var ds := (s1-s0)/n
		var turn := float(sg.turn)/n
		for i in n:
			# Exact on an arc: the chord at the half-turn.
			if turn != 0.0:
				var chord := 2.0*float(sg.radius)*sin(absf(turn)*0.5)
				p += d.rotated(turn*0.5)*chord
				d = d.rotated(turn)
			else:
				p += d*ds
			t.pts.append(p)
			t.tans.append(d)
			t.ss.append(s0+ds*(i+1))
	t.mouth_b = p
	t.out_b = d

## The table over u, every STEP m from mouth A (the path continued past
## mouth B along its way out, so the last step reads right).
static func _table(t: Site) -> void:
	var us := PackedFloat32Array()
	var vs := PackedFloat32Array()
	var cs := PackedFloat32Array()
	var sns := PackedFloat32Array()
	var sl := PackedFloat32Array()
	var n := Vector2(-t.way.y,t.way.x)
	for i in t.pts.size():
		var q := t.pts[i]-t.origin
		us.append(q.dot(t.way))
		vs.append(q.dot(n))
		cs.append(t.tans[i].dot(t.way))
		sns.append(t.tans[i].dot(n))
		sl.append(t.ss[i])
	for e in 3:
		var q := t.mouth_b+t.out_b*STEP*(e+1)-t.origin
		us.append(q.dot(t.way))
		vs.append(q.dot(n))
		cs.append(t.out_b.dot(t.way))
		sns.append(t.out_b.dot(n))
		sl.append(t.length+STEP*(e+1))
	t.u_end = us[t.pts.size()-1]
	var count := ceili(t.u_end/STEP)+1
	var j := 0
	for k in count+1:
		var u := k*STEP
		while j < us.size()-2 and us[j+1] < u: j += 1
		var a := clampf((u-us[j])/maxf(us[j+1]-us[j],0.0001),0.0,1.0)
		t.tv.append(lerpf(vs[j],vs[j+1],a))
		t.tc.append(lerpf(cs[j],cs[j+1],a))
		t.tsn.append(lerpf(sns[j],sns[j+1],a))
		t.ts.append(lerpf(sl[j],sl[j+1],a))

## (x, z) in tunnel `t`'s path frame: Vector2(distance along the path from
## mouth A, offset across it); straight on past either mouth.
static func local(t: Site, x: float, z: float) -> Vector2:
	var dx := x-t.origin.x
	var dz := z-t.origin.y
	var u := dx*t.way.x+dz*t.way.y
	var v := -dx*t.way.y+dz*t.way.x
	if u <= 0.0: return Vector2(u,v)
	if u >= t.u_end:
		var q := Vector2(x,z)-t.mouth_b
		return Vector2(t.length+q.dot(t.out_b),t.out_b.x*q.y-t.out_b.y*q.x)
	var f := u/STEP
	var k := mini(int(f),t.tv.size()-2)
	var a := f-k
	var dv := v-lerpf(t.tv[k],t.tv[k+1],a)
	return Vector2(lerpf(t.ts[k],t.ts[k+1],a)+dv*lerpf(t.tsn[k],t.tsn[k+1],a),dv*lerpf(t.tc[k],t.tc[k+1],a))

## The path's point (world xz) at distance `s` along it, and its tangent.
static func at_s(t: Site, s: float) -> Array:
	if s <= 0.0: return [t.origin+t.way*s,t.way]
	if s >= t.length: return [t.mouth_b+t.out_b*(s-t.length),t.out_b]
	var i := clampi(int(s/STEP),0,t.ss.size()-2)
	while i < t.ss.size()-2 and t.ss[i+1] < s: i += 1
	while i > 0 and t.ss[i] > s: i -= 1
	var a := clampf((s-t.ss[i])/maxf(t.ss[i+1]-t.ss[i],0.0001),0.0,1.0)
	return [t.pts[i].lerp(t.pts[i+1],a),t.tans[i].slerp(t.tans[i+1],a)]

# --- The massif and the trenches ------------------------------------------------------

## The crest's height (world y) at distance `s` along the path.
static func top(t: Site, s: float) -> float:
	var c := t.floor_y+COVER_MOUTH
	if s <= 0.0: return c+s*END
	if s >= t.length: return c-(s-t.length)*END
	var q := clampf(minf(s,t.length-s)/RISE,0.0,1.0)
	var r := 1.0-(1.0-q)*(1.0-q)
	var vary := 1.0-CREST_VARY*(0.5+0.5*t.crest_noise.get_noise_1d(s))
	return c+(t.crest-COVER_MOUTH)*r*vary

## The massif's surface (world y) at (x, z), before it meets the land.
static func massif(t: Site, x: float, z: float) -> float:
	return _massif_q(t,local(t,x,z),x,z)

static func _massif_q(t: Site, q: Vector2, x: float, z: float) -> float:
	var a := absf(q.y)
	# Each side's fall varies along the path (the crest noise, read apart).
	var fall := FLANK*(1.0+FLANK_VARY*t.crest_noise.get_noise_2d(q.x*0.7,7000.0 if q.y > 0.0 else -7000.0))
	var y := top(t,q.x)-fall*(a*a/(2.0*CREST_R) if a < CREST_R else a-CREST_R*0.5)
	var w := smoothstep(GULLY_FROM.x,GULLY_FROM.y,a)
	if w > 0.0 and not t.shelves.is_empty():
		# No gully on a shelf's flat or its edges.
		for sv: Dictionary in t.shelves:
			var along := maxf(maxf(float(sv.a)-q.x,q.x-float(sv.b)),0.0)
			w *= smoothstep(0.0,SHELF_FADE,maxf(along,a-SHELF_SPAN))
	if w > 0.0: y += GULLY*w*t.gully.get_noise_2d(x,z)
	return y

## The shelves over the massif's surface `y` at path frame `q` (x, z):
## Vector2(the surface, how much of a shelf's meadow it stands on 0..1).
static func _shelve(t: Site, y: float, q: Vector2, x: float, z: float) -> Vector2:
	var m := 0.0
	for sv: Dictionary in t.shelves:
		var along := maxf(maxf(float(sv.a)-q.x,q.x-float(sv.b)),0.0)
		var floor_y := float(sv.y)
		var wall := floor_y+along*SHELF_WALL
		if wall-SHELF_BLEND >= y: continue
		if along > 0.0: wall += SHELF_RAGGED*(t.rock.get_noise_2d(x*1.5,z*1.5)*0.5+0.5)*smoothstep(0.0,20.0,along)
		y = -_smax(-y,-wall,SHELF_BLEND)
		m = maxf(m,(1.0-smoothstep(1.0,6.0,absf(y-floor_y)))*(1.0-smoothstep(0.0,30.0,along)))
	return Vector2(y,m)

## A smooth max: exactly the larger where they're `k` or more apart.
static func _smax(a: float, b: float, k: float) -> float:
	var h := clampf(0.5+0.5*(a-b)/k,0.0,1.0)
	return lerpf(b,a,h)+k*h*(1.0-h)

## The land's height `base` with tunnel `t`'s massif raised and its mouths'
## trenches cut, at (x, z).
static func carve(t: Site, base: float, x: float, z: float) -> float:
	return carve_m(t,base,x,z).x

## carve's height, and how much of a shelf's meadow (x, z) stands on (0..1).
static func carve_m(t: Site, base: float, x: float, z: float) -> Vector2:
	if not t.box.has_point(Vector2(x,z)): return Vector2(base,0.0)
	var q := local(t,x,z)
	var sm := Vector2(_massif_q(t,q,x,z),0.0)
	if not t.shelves.is_empty(): sm = _shelve(t,sm.x,q,x,z)
	var y := _smax(sm.x,base,BLEND)
	# A shelf's meadow only where the massif stands (not the land under it).
	var meadow := sm.y*smoothstep(0.0,BLEND,sm.x-base)
	if y != base:
		# Land lower than the box allows for: the lift fades out at its edge.
		var e := minf(minf(x-t.box.position.x,t.box.end.x-x),minf(z-t.box.position.y,t.box.end.y-z))
		if e < EDGE_FADE: y = base+(y-base)*smoothstep(0.0,EDGE_FADE,e)
	y = _trench(t,y,t.origin,-t.way,x,z)
	y = _trench(t,y,t.mouth_b,t.out_b,x,z)
	return Vector2(_pit(t,y,x,z),meadow)

## The shafts' sinkholes over `y` at (x, z): flat at the shaft's top within
## PIT_FLOOR, the walls rising at PIT_WALL (ragged) into the land above.
static func _pit(t: Site, y: float, x: float, z: float) -> float:
	for sh: Dictionary in t.shafts:
		var d := Vector2(x,z).distance_to(sh.at)
		var wall: float = float(sh.top)+maxf(d-PIT_FLOOR,0.0)*PIT_WALL
		if wall-PIT_BLEND >= y: continue
		if d > PIT_FLOOR: wall += PIT_RAGGED*(t.rock.get_noise_2d(x*2.0,z*2.0)*0.5+0.5)*smoothstep(PIT_FLOOR,PIT_FLOOR+12.0,d)
		y = -_smax(-y,-wall,PIT_BLEND)
	return y

## Which shaft (x, z) is in (within SHAFT_R-`grow` of its axis), or -1.
static func shaft_at(t: Site, x: float, z: float, grow := 0.0) -> int:
	for i in t.shafts.size():
		if Vector2(x,z).distance_to(t.shafts[i].at) < SHAFT_R-grow: return i
	return -1

## The trench out of the mouth at `m` (xz), facing out along `o`.
static func _trench(t: Site, y: float, m: Vector2, o: Vector2, x: float, z: float) -> float:
	var qx := x-m.x
	var qz := z-m.y
	var a := qx*o.x+qz*o.y
	if a < 0.0 or a > TRENCH_REACH: return y
	var b := absf(o.x*qz-o.y*qx)
	if b > TRENCH_WIDE: return y
	var lid := t.floor_y-SINK
	if a > APRON: lid += (a-APRON)*GRADE
	if y <= lid: return y
	if b <= HALL_HALF: return lid
	if b <= HALL_HALF+EDGE: return minf(y,lid+SHEER*(b-HALL_HALF)/EDGE)
	return minf(y,lid+SHEER+(b-HALL_HALF-EDGE)/LEAN)

## A coarse chunk's vertex (quads `step` m) at (x, z) by a mouth: no
## higher than the trench's cut `step` m nearer its floor and its mouth, so
## the coarse mesh never stands over the trench's floor (a heightmap's quads
## wider than the trench would fill it and bury the gate); the notch it
## leaves is the trench widened by a quad each side, and a quad (at most
## FACE_REACH) into the mouth's face (under the portal; the land then crosses the tube behind
## the gate, which land_tunnels.gd's far door hides). INF elsewhere.
## Only the chunk mesh's vertices (apply_chunk); the field, the collider
## (level 0) and everything sampling the height are untouched.
## Into the face only FACE_REACH m: past that (32 m quads, from ~2.7 km) the
## coarse land behind the portal would fall farther than its skirts reach.
const FACE_REACH := 16.0
static func trench_under(t: Site, x: float, z: float, step: float) -> float:
	if not t.box.has_point(Vector2(x,z)): return INF
	var out := INF
	for mm in 2:
		var at: Vector2 = t.origin if mm == 0 else t.mouth_b
		var o: Vector2 = -t.way if mm == 0 else t.out_b
		var q := Vector2(x,z)-at
		var a := q.dot(o)
		if a < -minf(step,FACE_REACH) or a > TRENCH_REACH+step: continue
		var b := maxf(absf(o.cross(q))-step,0.0)
		if b > TRENCH_WIDE: continue
		var lid := t.floor_y-SINK+maxf(clampf(a-step,0.0,TRENCH_REACH)-APRON,0.0)*GRADE
		if b > HALL_HALF+EDGE: lid += SHEER+(b-HALL_HALF-EDGE)/LEAN
		elif b > HALL_HALF: lid += SHEER*(b-HALL_HALF)/EDGE
		out = minf(out,lid)
	return out

## True where (x, z) is on a trench's floor (no grass there).
static func on_trench(t: Site, x: float, z: float) -> bool:
	for m in 2:
		var at: Vector2 = t.origin if m == 0 else t.mouth_b
		var o: Vector2 = -t.way if m == 0 else t.out_b
		var q := Vector2(x,z)-at
		var a := q.dot(o)
		if a >= 0.0 and a <= TRENCH_REACH and absf(o.cross(q)) <= HALL_HALF+EDGE+1.0: return true
	return false

## The tunnels whose box meets the box (x0, z0)..(x1, z1).
static func sites_in(sites: Array, x0: float, z0: float, x1: float, z1: float) -> Array:
	var out: Array = []
	var r := Rect2(x0,z0,x1-x0,z1-z0)
	for t: Site in sites:
		if t.box.intersects(r,true): out.append(t)
	return out

## Whether slot hall site `s` (hall_sites.gd's array) meets a tunnel's box.
static func blocks_hall(sites: Array, s: PackedFloat32Array) -> bool:
	if s.is_empty(): return false
	var r := s[7]+s[8]
	var hb := Rect2(s[0]-r,s[1]-r,r*2.0,r*2.0)
	for t: Site in sites:
		if t.box.intersects(hb,true): return true
	return false

# --- The bore and its portals ------------------------------------------------------

## A portal: a mass of carved rock set into the flank at each mouth, the
## bore's tube running through it and a dressed gate on its sheer front
## (land_tunnels.gd builds it, its top over the land). Its footprint (m
## along the way in from the mouth: PORTAL_OUT out, PORTAL_IN in;
## PORTAL_HALF across) is where the land mesh drops its triangles, so the
## plug of rock a heightmap leaves at the mouth is gone at every LOD up to
## 16 m quads, and the mass hides the hole's ragged edge.
const PORTAL_OUT := 20.0
const PORTAL_IN := 24.0
static var PORTAL_HALF: float = HALL_HALF+EDGE+20.0

## A cavern's ease at distance `s`: 0 in the hall stretches and past the
## mouths, rising to 1 over CAVE_END inside each cavern's ends.
static func cave_ease(t: Site, s: float) -> float:
	for p: Dictionary in t.pieces:
		if p.kind != "cave" or s <= float(p.s0) or s >= float(p.s1): continue
		return smoothstep(0.0,CAVE_END,minf(s-float(p.s0),float(p.s1)-s))
	return 0.0

## The carved profile at every sample of the path (Site wn, wp, vt, rn).
static func _carve_profile(t: Site) -> void:
	t.rock = FastNoiseLite.new()
	t.rock.seed = hash([t.seed,"rock"]) & 0x7fffffff
	t.rock.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	t.rock.frequency = 1.0/ROCK_WAVE
	t.rock.fractal_octaves = 2
	for i in t.ss.size():
		var s := t.ss[i]
		var e := cave_ease(t,s)
		var n := Vector2(-t.tans[i].y,t.tans[i].x)
		# Turning toward +d: the bend's inside is the +d side.
		var turn: float = ((at_s(t,minf(s+BEND_LOOK,t.length))[1] as Vector2)-(at_s(t,maxf(s-BEND_LOOK,0.0))[1] as Vector2)).dot(n)
		var room := CAVE_INSIDE*clampf(absf(turn)/INSIDE_TURN,0.0,1.0)
		var half := lerpf(HALL_HALF,CAVE_HALF,e)
		t.wn.append(half+e*(ROCK_SWELL*t.rock.get_noise_2d(s,0.0)+(room if turn < 0.0 else 0.0)))
		t.wp.append(half+e*(ROCK_SWELL*t.rock.get_noise_2d(s,400.0)+(room if turn > 0.0 else 0.0)))
		t.vt.append(lerpf(HALL_VAULT,CAVE_VAULT+VAULT_SWELL*t.rock.get_noise_2d(s,800.0),e))
		t.rn.append(lerpf(HALL_ROUND,lerpf(CAVE_ROUND.x,CAVE_ROUND.y,t.rock.get_noise_2d(s,1200.0)*0.5+0.5),e))

## The bore's carved profile at distance `s`: Vector4(half width on the -d
## side, on the +d side, the crown over the floor, the roundness n); a
## hall's past the mouths.
static func profile(t: Site, s: float) -> Vector4:
	if s <= 0.0 or s >= t.length or t.wn.is_empty(): return Vector4(HALL_HALF,HALL_HALF,HALL_VAULT,HALL_ROUND)
	var i := clampi(int(s/STEP),0,t.ss.size()-2)
	while i < t.ss.size()-2 and t.ss[i+1] < s: i += 1
	while i > 0 and t.ss[i] > s: i -= 1
	var a := clampf((s-t.ss[i])/maxf(t.ss[i+1]-t.ss[i],0.0001),0.0,1.0)
	return Vector4(lerpf(t.wn[i],t.wn[i+1],a),lerpf(t.wp[i],t.wp[i+1],a),lerpf(t.vt[i],t.vt[i+1],a),lerpf(t.rn[i],t.rn[i+1],a))

## The carved rock's height over the floor at offset `d` across, for the
## profile `pr`: the superellipse's top, or NAN past either wall.
static func roof_over(pr: Vector4, d: float) -> float:
	var hw := (pr.x+pr.y)*0.5
	var x := absf((d-(pr.y-pr.x)*0.5)/hw)
	if x >= 1.0: return NAN
	return pr.z*pow(1.0-pow(x,pr.w),1.0/pr.w)

## The profile's point at `th` (0: the +d wall's foot, PI/2 the crown, PI
## the -d wall's foot): Vector2(offset across, height over the floor), on
## the superellipse exactly (roof_over agrees there).
static func profile_point(pr: Vector4, th: float) -> Vector2:
	var c := cos(th)
	# The feet exactly on the floor (sin(PI)'s 1e-16 is 0.05 at n 24).
	var sn := sin(th) if sin(th) > 1e-5 else 0.0
	var hw := (pr.x+pr.y)*0.5
	return Vector2((pr.y-pr.x)*0.5+hw*signf(c)*pow(absf(c),2.0/pr.w),pr.z*pow(sn,2.0/pr.w))

## The bore's cross-section at distance `s`: Vector2(the wider side's half
## width, the crown over the floor).
static func section(t: Site, s: float) -> Vector2:
	var pr := profile(t,s)
	return Vector2(maxf(pr.x,pr.y),pr.z)

## Vector2(floor, roof) (world y) where (x, z) is over the bore's carved
## tube (through the portals too), else Vector2(NAN, NAN). `grow` reads
## the roof `grow` m farther from the crown (a wingtip's reach): NAN where
## that is past the wall.
static func bore_at(t: Site, x: float, z: float, grow := 0.0) -> Vector2:
	if not t.box.has_point(Vector2(x,z)): return Vector2(NAN,NAN)
	var q := local(t,x,z)
	if q.x < -PORTAL_OUT or q.x > t.length+PORTAL_OUT: return Vector2(NAN,NAN)
	var pr := profile(t,q.x)
	var mid := (pr.y-pr.x)*0.5
	var h := roof_over(pr,q.y+(grow if q.y >= mid else -grow))
	if is_nan(h): return Vector2(NAN,NAN)
	return Vector2(t.floor_y,t.floor_y+h)

## Which mouth's portal footprint (x, z) is on: 0 (A), 1 (B) or -1.
static func portal_at(t: Site, x: float, z: float) -> int:
	for m in 2:
		var q := portal_local(t,m,x,z)
		if q.x >= -PORTAL_OUT and q.x <= PORTAL_IN and absf(q.y) <= PORTAL_HALF: return m
	return -1

## (x, z) in mouth `m`'s frame: Vector2(along the way in, across).
static func portal_local(t: Site, m: int, x: float, z: float) -> Vector2:
	var at: Vector2 = t.origin if m == 0 else t.mouth_b
	var inward: Vector2 = t.way if m == 0 else -t.out_b
	var q := Vector2(x,z)-at
	return Vector2(q.dot(inward),inward.cross(q))

## Mouth `m`'s point (world xz) `a` m in along its way and `d` across.
static func portal_point(t: Site, m: int, a: float, d: float) -> Vector2:
	var at: Vector2 = t.origin if m == 0 else t.mouth_b
	var inward: Vector2 = t.way if m == 0 else -t.out_b
	return at+inward*a+Vector2(-inward.y,inward.x)*d

## Each mouth's trench and portal as an arch for the trees' keep-out
## (tree_plan.gd `_arches_near`): [centre xz, cos, sin, half span across,
## half depth along], the approach running along the trench.
static func tree_keepouts(t: Site) -> Array:
	var out: Array = []
	for m in 2:
		var o: Vector2 = -t.way if m == 0 else t.out_b
		var at: Vector2 = t.origin if m == 0 else t.mouth_b
		var turned := atan2(-o.y,o.x)+PI*0.5
		out.append([at+o*(TRENCH_REACH-PORTAL_IN)*0.5,cos(turned),sin(turned),HALL_HALF+EDGE,(TRENCH_REACH+PORTAL_IN)*0.5])
	# The bore itself, in straight runs of at most KEEP_RUN m: the trees'
	# plan put some on the land's floor inside it.
	var s := 0.0
	while s < t.length:
		var e := minf(s+KEEP_RUN,t.length)
		var mid: Array = at_s(t,(s+e)*0.5)
		var tg: Vector2 = mid[1]
		var turned := atan2(-tg.y,tg.x)+PI*0.5
		out.append([mid[0],cos(turned),sin(turned),CAVE_HALF+CAVE_INSIDE,(e-s)*0.5])
		s = e
	# The shafts' pits' floors.
	for sh: Dictionary in t.shafts: out.append([sh.at,1.0,0.0,PIT_FLOOR+4.0,PIT_FLOOR+4.0])
	return out

const KEEP_RUN := 40.0

## The hall stretches: each hall piece of the path is one straight slot
## piece (scripts/sundered_hall.gd `slot_piece`) standing on the bore's
## floor, its gate at the piece's start; land_tunnels.gd stands them.
## Every one: {n (its index among them), piece (the path's), seed, bays,
## frame (world: the gate's mouth on the floor, the nave along +X, +Z the
## path's left, `local`'s +d)}.
static func stretches(t: Site) -> Array:
	var out: Array = []
	for p: Dictionary in t.pieces:
		if p.kind != "hall": continue
		var s0 := float(p.s0)
		var s1 := float(p.s1)
		var mid: Array = at_s(t,(s0+s1)*0.5)
		var tg: Vector2 = mid[1]
		var c: Vector2 = (mid[0] as Vector2)-tg*(s1-s0)*0.5
		var x := Vector3(tg.x,0.0,tg.y).normalized()
		out.append({"n":out.size(),"piece":p,"seed":hash([t.seed,"stretch",out.size()]) & 0xffffff,"bays":int(p.bays),
			"frame":Transform3D(Basis(x,Vector3.UP,x.cross(Vector3.UP)),Vector3(c.x,t.floor_y,c.y))})
	return out

## The hall stretches' centre column row (knob, the user's to tune): on, a
## stretch keeps its plan's inner columns (and the screens hung off them),
## which split the nave into two lanes; off, the nave stands open between
## the rows. `--tunnel-row=0|1` overrides it.
const CENTRE_ROW := true

static func centre_row() -> bool:
	var out := CENTRE_ROW
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--tunnel-row="): out = a.get_slice("=",1) not in ["0","off","false"]
	return out

## Stretch `h`'s slot piece (Tunnels.stretches), with the centre row as
## `centre_row` sets it: what LandHalls builds and the torches read.
static func stretch_piece(h: Dictionary) -> Dictionary:
	var piece := Sundered.slot_piece(int(h.seed),int(h.bays))
	if not centre_row():
		for p: Dictionary in piece.plans:
			p.inner = []
			p.screen = false
	return piece

## A hall wall's inner face off the stretch's line (m).
static var HALL_INNER: float = Hall.WALL_Z-Hall.WALL_THICK*0.5

## The torch lines: both walls every TORCH_GAP m along the path, staggered
## side to side, closer (TORCH_GAP_OUT) on a bend's outside wall so a bend
## ahead shows as a curve of lights; TORCH_Y over the floor, TORCH_IN off
## the wall. A bigger pair stands MOUTH_TORCH_IN inside each portal's
## front, MOUTH_TORCH_Y up.
const TORCH_GAP := 24.0
const TORCH_GAP_OUT := 14.0
const TORCH_Y := 6.5
const TORCH_IN := 0.35
## A bend counts where the tangent turns more than this over 12 m (rad).
const TORCH_BEND := 0.02
const MOUTH_TORCH_IN := 2.0
const MOUTH_TORCH_Y := 7.5

## Every torch of the bore: {pos (world), into (xz, the wall's normal into
## the bore), s, side (-1, 1: the path's left/right by `local`'s d), kind
## ("wall", "outside", "mouth")}: each side's wall torches in order along
## s, then the mouths'.
static func torch_spots(t: Site) -> Array:
	var out: Array = []
	# In a hall stretch a torch sits on the hall's wall: mid-bay where that
	# bay's wall is whole, else on the jamb at its bay line.
	var halls: Array = stretches(t)
	var plans := {}
	for h: Dictionary in halls: plans[h.n] = stretch_piece(h).plans
	for side: float in [-1.0,1.0]:
		var s := 6.0 if side < 0.0 else 6.0+TORCH_GAP*0.5
		while s < t.length-4.0:
			var hall := {}
			for h: Dictionary in halls:
				if s >= float(h.piece.s0) and s < float(h.piece.s1): hall = h
			var on := s
			if not hall.is_empty():
				var s0 := float(hall.piece.s0)
				var list: Array = plans[hall.n]
				var i := clampi(floori((s-s0)/Hall.BAY),0,list.size()-1)
				var whole := ((list[i] as Dictionary).breach as Vector2i)[0 if side < 0.0 else 1] == 0
				on = s0+(i+(0.5 if whole else 0.0))*Hall.BAY
			var at: Array = at_s(t,on)
			var c: Vector2 = at[0]
			var tg: Vector2 = at[1]
			var n := Vector2(-tg.y,tg.x)
			var t0: Vector2 = at_s(t,maxf(s-6.0,0.0))[1]
			var t1: Vector2 = at_s(t,minf(s+6.0,t.length))[1]
			var turn := (t1-t0).dot(n)
			var outside := absf(turn) > TORCH_BEND and signf(turn) != side
			# In a cavern, on the carved wall where it stands TORCH_Y high.
			var off := side*(HALL_INNER-TORCH_IN)
			if hall.is_empty():
				var pr := profile(t,on)
				var x := pow(1.0-pow(minf(TORCH_Y/pr.z,0.99),pr.w),1.0/pr.w)
				off = (pr.y-pr.x)*0.5+side*((pr.x+pr.y)*0.5*x-TORCH_IN)
			var p := c+n*off
			out.append({"pos":Vector3(p.x,t.floor_y+TORCH_Y,p.y),"into":-n*side,"s":on,"side":side,"kind":"outside" if outside else "wall"})
			s += TORCH_GAP_OUT if outside else TORCH_GAP
	# The mouths: a big pair on the tube's walls just inside each portal's
	# front (the trench's rock hides anything beside the opening).
	for ms: float in [-PORTAL_OUT+MOUTH_TORCH_IN,t.length+PORTAL_OUT-MOUTH_TORCH_IN]:
		var at: Array = at_s(t,ms)
		var c: Vector2 = at[0]
		var tg: Vector2 = at[1]
		var n := Vector2(-tg.y,tg.x)
		for side: float in [-1.0,1.0]:
			var p := c+n*side*(HALL_HALF-TORCH_IN)
			out.append({"pos":Vector3(p.x,t.floor_y+MOUTH_TORCH_Y,p.y),"into":-n*side,"s":ms,"side":side,"kind":"mouth"})
	return out

## Which of a chunk's grid vertices stand on a portal's footprint (1), for
## land_stream.gd to drop the triangles wholly on one; empty if none do.
static func portal_mask(ts: Array, x0: float, z0: float, step: float, cells: int) -> PackedByteArray:
	var n := cells+1
	var out := PackedByteArray()
	var any := false
	for t: Site in ts:
		for m in 2:
			var at: Vector2 = t.origin if m == 0 else t.mouth_b
			var r := PORTAL_HALF+PORTAL_IN+PORTAL_OUT
			var i0 := clampi(floori((at.x-r-x0)/step),0,cells)
			var i1 := clampi(ceili((at.x+r-x0)/step),0,cells)
			var j0 := clampi(floori((at.y-r-z0)/step),0,cells)
			var j1 := clampi(ceili((at.y+r-z0)/step),0,cells)
			if i0 >= i1 or j0 >= j1: continue
			for j in range(j0,j1+1):
				for i in range(i0,i1+1):
					var q := portal_local(t,m,x0+i*step,z0+j*step)
					if q.x < -PORTAL_OUT or q.x > PORTAL_IN or absf(q.y) > PORTAL_HALF: continue
					if not any:
						out.resize(n*n)
						any = true
					out[j*n+i] = 1
		for sh: Dictionary in t.shafts:
			var at: Vector2 = sh.at
			var r := SHAFT_R+HOLE_PAD
			var i0 := clampi(floori((at.x-r-x0)/step),0,cells)
			var i1 := clampi(ceili((at.x+r-x0)/step),0,cells)
			var j0 := clampi(floori((at.y-r-z0)/step),0,cells)
			var j1 := clampi(ceili((at.y+r-z0)/step),0,cells)
			if i0 >= i1 or j0 >= j1: continue
			for j in range(j0,j1+1):
				for i in range(i0,i1+1):
					if Vector2(x0+i*step,z0+j*step).distance_to(at) > r: continue
					if not any:
						out.resize(n*n)
						any = true
					out[j*n+i] = 1
	return out

# --- Over a chunk's and a grid's arrays ---------------------------------------------

## The tunnels' pass over a chunk's arrays (LandField.build_chunk; its
## args), after the ponds', before the slot halls'. `field` the LandField.
static func apply_chunk(field: Object, impl: Object, made: Dictionary, ts: Array, x0: float, z0: float, step: float, cells: int, skirt_drop: float) -> void:
	var n := cells+1
	var heights: PackedFloat32Array = made.heights
	var verts: PackedVector3Array = made.verts
	var normals: PackedVector3Array = made.normals
	var colours: PackedColorArray = made.colours
	var carved: PackedByteArray = made.carved
	var river: PackedFloat32Array = made.river
	var lift := PackedFloat32Array()
	lift.resize(n*n)
	var moved := PackedByteArray()
	moved.resize(n*n)
	var shelf := PackedFloat32Array()
	var any_moved := false
	for t: Site in ts:
		var i0 := clampi(floori((t.box.position.x-x0)/step),0,cells)
		var i1 := clampi(ceili((t.box.end.x-x0)/step),0,cells)
		var j0 := clampi(floori((t.box.position.y-z0)/step),0,cells)
		var j1 := clampi(ceili((t.box.end.y-z0)/step),0,cells)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var v := j*n+i
				var ym := carve_m(t,heights[v],x0+i*step,z0+j*step)
				var y := ym.x
				if step > 1.0: y = minf(y,trench_under(t,x0+i*step,z0+j*step,step))
				if ym.y > 0.0:
					if shelf.is_empty(): shelf.resize(n*n)
					shelf[v] = maxf(shelf[v],ym.y)
				if absf(y-heights[v]) > 0.0005:
					lift[v] += y-heights[v]
					heights[v] = y
					verts[v] = Vector3(verts[v].x,y,verts[v].z)
					moved[v] = 1
					any_moved = true
	if not any_moved: return
	var redo := PackedByteArray()
	redo.resize(n*n)
	for j in n:
		for i in n:
			if moved[j*n+i] == 0: continue
			for d: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var ii := i+d.x
				var jj := j+d.y
				if ii >= 0 and ii < n and jj >= 0 and jj < n: redo[jj*n+ii] = 1
	for j in n:
		for i in n:
			var v := j*n+i
			if redo[v] == 0: continue
			var x := x0+i*step
			var z := z0+j*step
			var hl: float = heights[v-1] if i > 0 else field.height(x-step,z)
			var hr: float = heights[v+1] if i < cells else field.height(x+step,z)
			var hd: float = heights[v-n] if j > 0 else field.height(x,z-step)
			var hu: float = heights[v+n] if j < cells else field.height(x,z+step)
			var normal := Vector3(hl-hr,2.0*step,hd-hu).normalized()
			normals[v] = normal
			var meadow := colours[v].a
			if moved[v] != 0: meadow *= _meadow_keep(lift[v])
			if not shelf.is_empty(): meadow = maxf(meadow,SHELF_MEADOW*shelf[v])
			var c: Color = impl.colour(x,z,heights[v],normal.y,meadow)
			c.a = meadow
			colours[v] = c
			if moved[v] != 0:
				carved[v*4] = 0
				carved[v*4+1] = 0
				if lift[v] > 1.0:
					# No river on the mountain: far from any, its flow still.
					carved[v*4+2] = 128
					carved[v*4+3] = 128
					river[v*3] = 1000.0
					river[v*3+1] = 0.0
					river[v*3+2] = SEA_Y-100.0
	var edges := [[],[],[],[]]
	for t in n:
		edges[0].append(t)
		edges[1].append(t*n+cells)
		edges[2].append(cells*n+t)
		edges[3].append(t*n)
	for e in 4:
		for t in n:
			var from: int = edges[e][t]
			if redo[from] == 0: continue
			var v := n*n+e*n+t
			verts[v] = verts[from]-Vector3(0.0,skirt_drop,0.0)
			normals[v] = normals[from]
			colours[v] = colours[from]
			for q in 4: carved[v*4+q] = carved[from*4+q]
			river[v*3] = river[from*3]
			river[v*3+1] = -river[from*3+1]
			river[v*3+2] = river[from*3+2]
	made.heights = heights
	made.verts = verts
	made.normals = normals
	made.colours = colours
	made.carved = carved
	made.river = river

## How much of the meadow stays where the land was lifted `lift` m (none
## where it was cut down: a trench).
static func _meadow_keep(lift: float) -> float:
	if lift < 0.0: return 0.0
	return 1.0-smoothstep(MEADOW_LIFT.x,MEADOW_LIFT.y,lift)

## The tunnels' pass over LandField.grid's arrays (the grass's): the
## massif's heights, its meadows faded with the lift, no river on it, and
## the trenches' floors read as a river's water (`river` -1).
static func apply_grid(got: Dictionary, ts: Array, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var hs: PackedFloat32Array = got.heights
	var ms: PackedFloat32Array = got.meadows
	var rs: PackedFloat32Array = got.river
	for t: Site in ts:
		var i0 := clampi(floori((t.box.position.x-x0)/step)+pad,0,nx-1)
		var i1 := clampi(ceili((t.box.end.x-x0)/step)+pad,0,nx-1)
		var j0 := clampi(floori((t.box.position.y-z0)/step)+pad,0,nz-1)
		var j1 := clampi(ceili((t.box.end.y-z0)/step)+pad,0,nz-1)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var x := x0+(i-pad)*step
				var z := z0+(j-pad)*step
				var k := j*nx+i
				var ym := carve_m(t,hs[k],x,z)
				var y := ym.x
				var d := y-hs[k]
				if absf(d) <= 0.0005: continue
				hs[k] = y
				ms[k] = maxf(ms[k]*_meadow_keep(d),SHELF_MEADOW*ym.y)
				if d > 1.0: rs[k] = maxf(rs[k],1000.0)
				if d < 0.0 and on_trench(t,x,z): rs[k] = minf(rs[k],-1.0)
	got.heights = hs
	got.meadows = ms
	got.river = rs
