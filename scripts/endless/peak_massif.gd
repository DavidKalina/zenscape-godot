## The Peak's massif (docs/design/endless-flight/spec-peak.md, Shape): one
## stamp over the land, applied by the land-field wrapper (LandField
## `sample`, `shape`, `height`, `build_chunk` and `grid`) after the ponds,
## tunnels, halls and splits, so chunk meshes, `height()` and collision
## agree.
##
## The profile is built in the massif's own frame from its centre (the
## plateau's middle) and its facing (the way out of the horseshoe's
## opening): `a` metres along the facing, `v` across it. The horseshoe's
## crest is a ring of RING_R round a point O_ALONG ahead of the plateau;
## `th` is the angle round it from the back (0, the saddle) toward the arms'
## tips (ARM_END). Each piece is a height over the sea (SEA_Y), and the land
## gets the higher of its own and the massif's, except where the massif cuts
## (`c`: inside the horseshoe, the valley, the plateau), where the massif's
## height stands alone. Along the axis, from the opening in:
##
##   glacier valley  a 3100..2050  100..300 m, bulged ice crossed by crevasse
##                                 bands, between lateral moraines and side
##                                 ridges; the valley bends (GL_BEND)
##   the split       a 1985..345   300..830 m: a prow of rock from its nose, an
##                                 ice gorge round the -v side and a rock gorge
##                                 up the +v, meeting at a saddle under the
##                                 towers (scripts/endless/peak_split.gd)
##   crest           th 0..40      925 m at most, broken into teeth and cols,
##                                 falling away far faster on the +v side
##   plateau, tarn   a 160..-270   880 m, a broken floor falling to the lake
##   the crown       three towers (scripts/endless/rocks/peak_towers.gd) round
##                                 the lake, each on its own plinth of rock, the
##                                 back ones joined by aretes; tips to 1480 m
##   back face       a -350..-2200 895 m down to the sea, spurs down it
##
## Everything outside a circle of BOUND round O pays one distance check
## (`reaches`, `meets`). Placed through LayoutOverrides "peak/massif": the
## transform's origin the plateau's centre, its +z the facing.
extends RefCounted

const SEA_Y := -40.0
const PeakIce = preload("res://scripts/endless/peak_ice.gd")
const Split = preload("res://scripts/endless/peak_split.gd")
const Rock = preload("res://scripts/endless/peak_rock.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Sites = preload("res://scripts/endless/hall_sites.gd")
const Ponds = preload("res://scripts/endless/land_ponds.gd")

const HANDLE := "peak/massif"
## The tarn's water (its centre, at its level): origin moves it on the
## plateau and lifts or drops its level within the bowl; the bowl follows.
const TARN_HANDLE := "peak/tarn"
## The coded spot: the plateau's centre AWAY m from the origin, facing it
## (the horseshoe open toward the start). The worlds spawn at the origin and
## the start meadow is found within 900 m of it (MenuSpot REACH), so the
## glacier's toe (TOE.y) ends at about the origin, and the bounding circle
## takes in the start (the start's chunks pay the massif's pass). Which way from the origin: of YAWS
## ways round, the one with the land's own ground lowest in the eye from
## the origin out to SIGHT m (its steepest angle, degrees) and the most sea
## behind the plateau (BEHIND m past it, ACROSS m either side), scored
## sea share x SEA_WORTH less the angle. `--peak-at=x,z` and `--peak-yaw=deg`
## (0 faces +z) set it by hand.
const AWAY := 3500.0
## The distance `_way` scores the sea behind at: its own, so bringing the massif
## nearer doesn't turn it round the start.
const WAY_AWAY := 4500.0
const YAWS := 36
const SIGHT := 2000.0
const SIGHT_STEP := 25.0
const BEHIND := [2200.0,2600.0,3000.0,3400.0]
const ACROSS := 600.0
const SEA_WORTH := 4.0

# --- The ring: crest, wall, flanks -------------------------------------------------

## The horseshoe's middle, ahead of the plateau along the facing, and the
## crest's radius round it.
const O_ALONG := 1600.0
const RING_R := 1350.0
## The crest's height over the sea by `th` (degrees from the back), pairs,
## on the +v side and the -v side. Teeth
## on the highs (the tower bases, TOWER_POS, TOWER_NEG) and cols between, so it
## is broken, never a level line. The -v side is the long shoulder, the +v side
## the one that falls away: down to 600 m by th 32, where the -v side still
## stands at 800. The front is held to the plateau's height and under, so the
## towers' bodies show over it from the meadow and the glacier; the crown's tips
## stand 400 m and more over all of it.
const CREST_POS := [0.0,880.0, 3.0,862.0, 6.0,900.0, 9.0,835.0, 12.0,866.0, 15.0,770.0, 19.0,790.0,
	23.0,690.0, 27.0,705.0, 32.0,600.0, 38.0,570.0, 46.0,510.0, 60.0,440.0, 80.0,380.0, 100.0,340.0,
	120.0,285.0, 140.0,215.0, 155.0,135.0, 168.0,40.0]
const CREST_NEG := [0.0,880.0, 4.0,902.0, 7.0,925.0, 10.0,868.0, 12.0,840.0, 14.0,862.0, 16.0,890.0,
	19.0,835.0, 23.0,862.0, 27.0,780.0, 31.0,800.0, 36.0,720.0, 42.0,680.0, 60.0,590.0, 80.0,500.0,
	100.0,430.0, 120.0,350.0, 140.0,270.0, 155.0,170.0, 168.0,40.0]
## Spurs and gullies down every flank, each one its own: laid round the
## ring from the back at load (`_ribs`), one rib every RIB_P degrees or so
## (inner, outer), pushing the flank out (a spur line, at RIB_SPUR) or in
## (a gully, up to 1) by up to RIB_IN m on the wall, RIB_ARM m on the arms'
## inner flank, RIB_OUT m on the outer falls (grown over RIB_GROW m down
## from the crest). Each rib draws its width (RIB_P x RIB_WIDTH, low end
## likelier), strength (RIB_AMP; RIB_FAINT of them barely show), where its
## gully runs across it (RIB_SKEW of its width off the middle), its
## gully's shape (RIB_SHARP: low a V, high a round trough between sharp
## spurs), and where it starts and dies down the flank (RIB_START,
## RIB_END inner, RIB_END_OUT outer, m from the crest). The lines wander
## sideways by up to RIB_WANDER degrees down the flank, so they bend.
const RIB_P := Vector2(5.5,8.5)
const RIB_WIDTH := Vector2(0.4,2.0)
const RIB_AMP := Vector2(0.2,1.0)
const RIB_FAINT := 0.18
const RIB_SPUR := -0.7
const RIB_SKEW := 0.28
const RIB_SHARP := Vector2(1.2,3.5)
const RIB_START := 220.0
const RIB_END := Vector2(260.0,700.0)
const RIB_END_OUT := Vector2(350.0,1500.0)
const RIB_WANDER := 3.0
const RIB_IN := 55.0
const RIB_ARM := 60.0
const RIB_OUT := 115.0
const RIB_GROW := 380.0
## The wider ribs over the fine ones: their width (times the fine one's
## period, times RIB_WIDTH) and share. The inner ribs fade out over
## RIB_FOOT m (from the crest) toward the flank's foot.
const RIB_WIDE := 2.7
const RIB_WIDE_SHARE := 0.45
const RIB_FOOT := Vector2(300.0,560.0)
## A rib's entry in `_ribs`: start (deg), width (deg), strength, gully at
## (share of the width), gully power, start and end down the flank (m).
const RIB_STRIDE := 7
## Where the arms end (degrees); past it the ring sinks under the land.
const ARM_END := 168.0
## The wall at the back (th under 30, gone by 60): its foot's height, its
## run from the crest inward, the talus's fall past the foot (m per m).
const WALL_FOOT := 520.0
const WALL_RUN := 600.0
const TALUS_FALL := 0.4
## The wall's rise from foot to crest: a talus share up to TALUS_TOP of the
## run, the rest a cliff from CLIFF.x to CLIFF.y (shares of the run from the
## foot).
const TALUS_SHARE := 0.22
const TALUS_TOP := 0.6
const CLIFF := Vector2(0.45,0.97)
## The arms' inner flank: its fall per metre at the crest and 500 m in.
const ARM_IN := Vector2(0.8,0.42)
## The back's outer side (th under 35, gone by 70): the shoulder that holds
## the plateau (th under 5, gone by 16): from the crest down to PLATEAU_Y over
## SHOULDER.x m, flat to SHOULDER.y, up to LIP_Y by SHOULDER.z, then the back
## face; elsewhere a knife ridge straight into the face. PLATEAU_Y: the crown's
## shortest tower stands 400 m over it.
const SHOULDER := Vector3(90.0,520.0,600.0)
const PLATEAU_Y := 880.0
const LIP_Y := 895.0
const BACK_RUN := 2000.0
const BACK_BOW := 1.8
const KNIFE_BOW := 2.6
## The arms' outer flank.
const ARM_OUT_RUN := 1100.0
const ARM_OUT_BOW := 1.5
## Where every fall ends (over the sea, below the sea's face) and how fast
## it drops past its run, so the massif always sinks under the land before
## BOUND.
const FALL_END := -60.0
const PAST_END := 1.0

# --- The approach valley ------------------------------------------------------------

## The floor's stretches along `a`: icefall, boulders, glacier, toe. The first
## two lie under the prow now: the floor between the glacier's head and the
## nose is the boulders' stretch, the rest is the mass's to cover.
const ICEFALL := Vector2(850.0,1250.0)
const ICEFALL_Y := Vector2(520.0,400.0)
const ICEFALL_STEPS := 3
const ICEFALL_RISER := 0.35
const BOULDERS := Vector2(1250.0,2050.0)
const BOULDERS_Y := Vector2(400.0,300.0)
const GLACIER := Vector2(2050.0,3100.0)
const GLACIER_Y := Vector2(300.0,100.0)
const TOE := Vector2(3100.0,3500.0)
## The floor's half-width: icefall, boulders, glacier's head and mouth.
const FLOOR_HALF := Vector4(200.0,240.0,260.0,330.0)
## The valley bends: its middle swings GL_BEND m across, from the boulders'
## head (a 1250) to the toe, in GL_TURNS half waves. The axis (v 0) stays on
## the floor.
const GL_BEND := 170.0
const GL_TURNS := 1.6
## The ice bulges ICE_BULGE m up in its middle.
const ICE_BULGE := 6.0
## The side ridges: their rise over the floor, the run to their top (from
## SIDE_GAP m past the floor's edge), their outer fall (m per m).
const SIDE_UP := 80.0
const SIDE_RUN := 170.0
const SIDE_GAP := 70.0
const SIDE_FALL := 0.4
const SIDE_DIP := 15.0
const SIDE_DIP_TO := 2200.0
const SHELF_FALL := 1.0
## The lateral moraines along the boulders and the glacier: a sharp-crested
## bank MOR_UP m over the floor, its crest MOR_AT m past the floor's edge,
## MOR_W m each side of it, a trough between it and the side ridge.
const MOR_UP := 30.0
const MOR_AT := 30.0
const MOR_W := 48.0
## Crevasse bands across the glacier: a band every CREV_BAND m along the ice
## over CREV_SHARE of it, crevasses CREV_SP m apart in a band, CREV_W wide,
## CREV_DEEP deep, bowed CREV_ARC m downstream in the middle.
const CREV_BAND := 430.0
const CREV_SHARE := 0.35
const CREV_SP := 26.0
const CREV_W := 9.0
const CREV_DEEP := 5.0
const CREV_ARC := 60.0
## Boulder-field lumps (m, and their scale against the rock noise's).
const LUMPS := 2.5
const LUMP_SCALE := 3.7

# --- Plateau, tarn, crown ----------------------------------------------

## The plateau: flat out to PLATEAU_FLAT from its centre, blended out by
## PLATEAU_BLEND (with --cirque=0; `on_plateau`, and the spires, read the blend).
const PLATEAU_FLAT := 150.0
const PLATEAU_BLEND := 300.0
## The tarn's bowl: its centre TARN_BACK m behind the plateau's, its radius,
## its depth under the shore, and the water level the bowl is cut for (over the
## sea). The shore lies SHORE_DROP m under the strip, the floor easing down to it
## over SHORE_RUN of the bowl's radius, so the water shows from where you land.
## The water's edge lies where the bowl meets the level (`tarn().wet`, about 105
## m). The water is TARN_DEEP-1 m deep in the middle: the ground shader lifts its
## grid to a water's level only up to 6.6 m, so a deeper bowl would show a hole
## in the drawn water.
const TARN_BACK := 90.0
const TARN_BOWL := 130.0
const TARN_DEEP := 5.0
const SHORE_DROP := 18.0
const SHORE_RUN := 1.55
## The strip's side of the lake falls to the shore whole, between these a, so
## no swell of the outline's lobes stands between the strip and the water;
## ACROSS the |v| it fades out over.
const SHORE_FALL := Vector2(30.0,90.0)
const SHORE_ACROSS := Vector2(130.0,200.0)
const SHORE_Y := PLATEAU_Y-SHORE_DROP
const TARN_LEVEL := SHORE_Y-1.0
## The tarn's outline (and its bowl's, which follows it): lobes 2, 3 and 5
## as shares of its radius, their phases from the land's seed.
const TARN_LOBES := Vector3(0.2,0.1,0.05)
## The cirque, the plateau's floor (`--cirque=0`: the flat disc it was): an
## outline lobed round the plateau's centre (CIRQUE_R, lobes 2, 3 and 5 as
## shares, phases from the seed), `s` a point's distance over the outline's
## radius that way. The floor at PLATEAU_Y, rising FLOOR_RISE toward the
## outline away from the tarn, broken by KNOBS (rise, scale m, the noise from
## which they stand; fewer toward the tarn), swells under them (SWELL: rise,
## scale m), and a rock rim on it (RIM: least and most rise, its half-width in
## `s`) whose height wanders round it, none on the crest's side and a gap where
## the strip runs out through it. Blended out to the land over CIRQUE_OUT (in
## `s`), and over CIRQUE_FRONT (a) toward the crest, whose back runs down to it.
const CIRQUE_R := 250.0
const CIRQUE_LOBES := Vector3(0.07,0.09,0.04)
const CIRQUE_OUT := Vector2(1.08,1.3)
const CIRQUE_FRONT := Vector2(165.0,215.0)
const FLOOR_RISE := 14.0
const KNOBS := Vector3(9.0,60.0,0.05)
const SWELL := Vector2(9.0,150.0)
const RIM := Vector3(14.0,34.0,0.16)
## The floor's breaks and swells fade in from the lake over these (its bowl's
## radii), so the ground from the strip to the water lies open.
const QUIET := Vector2(1.5,2.3)
## The flat shore: one strip across the plateau, between the tarn and the
## crest, as long as a hand landing needs (land_ponds.gd STRIP is 208):
## Vector4(its a, half its length along v, half its width, the ease to the
## broken ground round it), flat at PLATEAU_Y, no knob or rim on it.
const STRIP := Vector4(120.0,118.0,22.0,16.0)
## The apron: the flat from the ramp's top (Split.APRON_BACK) down to the strip,
## APRON.x m to each side of the axis, eased out over APRON.y, flat at PLATEAU_Y.
## A plane out of either gorge lands on it straight on: it flies along a, and the
## strip runs across its way.
const APRON := Vector2(88.0,16.0)
## The crown: three towers round the lake, a, v in the frame, tip (m over the
## sea), how far the tip leans in toward CROWN_MID, half the width at the base
## (m), seed. Uneven, the tallest off centre. Their places go through
## `peak/tower/<n>` (scripts/layout_overrides.gd).
const CROWN := [[-260.0,-400.0,1480.0,110.0,82.0,71],[-440.0,90.0,1395.0,90.0,70.0,23],[-70.0,460.0,1335.0,70.0,60.0,58]]
const CROWN_MID := Vector2(-200.0,60.0)
## Each tower's plinth, the rock it grows from: its top over the sea, flat
## out to PLINTH_R of the girth, falling PLINTH_FALL m per m, more along its
## gullies than its ribs (the lobes share PLINTH_LOBE either way).
const PLINTH_TOPS := [985.0,955.0,930.0]
const PLINTH_R := 1.5
const PLINTH_FALL := 1.25
const PLINTH_LOBE := 0.45
## Each plinth falls faster the farther out, PLINTH_SINK m per m squared, so it
## is gone well inside CROWN_REACH.
const PLINTH_SINK := 0.004
## The aretes joining the towers behind the lake: pairs of towers and how far
## each sags under the line between the plinths, its fall to each side (m per
## m), and the height its broken crest loses and gains along the way.
const ARETES := [[0,1,90.0],[1,2,70.0]]
const ARETE_FALL := 1.6
const ARETE_BREAK := 34.0
## Past this far from the plateau's centre nothing of the crown stands.
const CROWN_REACH := 1140.0
## A tower's base: the lowest ground this many girths round it, so its feet
## are buried on every side however the plinth falls.
const FOOT_RING := 1.8
## Past this from the plateau's centre the cirque cannot reach (m, squared).
const CIRQUE_REACH2 := 202500.0
## Tower bases on the crest: their angles on the +v side and the -v side
## (degrees; on the CREST tables' highs), a flat top TOWER_UP over the crest
## of TOWER_R, falling TOWER_FALL m per m.
const TOWER_POS := [6.0,12.0,19.0,27.0]
const TOWER_NEG := [7.0,16.0,23.0,31.0]
const TOWER_R := 18.0
const TOWER_UP := 22.0
## Each tower base's share of TOWER_UP, in turn.
const TOWER_UPS := [1.0,0.55,1.3,0.7,1.15,0.6,0.9,1.25]
const TOWER_FALL := 2.5

## The rock's noise: its height (m) and scale (m).
const ROUGH := 12.0
const ROUGH_SCALE := 90.0
## The bounding circle round O: everything outside is the land's own.
## The rock's relief (PeakRock, `_rock_keep`): the steepness (off the fall map)
## it starts and is whole at; how far past a gorge's floor's edge the hollows
## start and the ribs start and are whole, the plane's air (m); the cirque's radius
## it starts and is whole at (m); a tower's foot's radii it starts and is whole
## at; the paint's whole depth (m).
const ROCK_STEEP := Vector2(0.14,0.45)
const ROCK_FOOT := Vector2(6.0,44.0)
const ROCK_CIRQUE := Vector2(190.0,260.0)
const ROCK_TOWER := Vector2(0.9,1.5)
const ROCK_PAINT := 5.0
## How much of the small relief also lifts the ground straight: a shoulder lies
## too far back for a walk along its fall line to move it.
const ROCK_LIFT := 0.8

const BOUND := 4050.0
const CLEAR_PAST := 1150.0
## The snow line on the massif, over the sea (the ground shader's
## `peak_snow`, ragged by about 100 m either way): the glacier's ice and
## the valley's sides below it, snow and granite above.
const SNOW_LINE := 580.0

## The stretches along the axis, for drivers and the trunk: name, a from,
## a to, height over the sea from, to.
const STRETCHES := [
	["glacier",3100.0,2050.0,100.0,300.0],
	["split",1985.0,345.0,Split.NOSE_Y,Split.SADDLE_Y],
	["plateau",160.0,-270.0,PLATEAU_Y,PLATEAU_Y],
	["back",-350.0,-2200.0,LIP_Y,FALL_END],
]

var centre := Vector2.ZERO
var facing := Vector2(0.0,1.0)
var side := Vector2(1.0,0.0)
var _o := Vector2.ZERO
var _noise := FastNoiseLite.new()
var _rock: RefCounted
## The ribs (see RIB_STRIDE), per side and flank: [fine, wide] for the
## -v inner, -v outer, +v inner, +v outer flanks.
var _ribs: Array[PackedFloat32Array] = []
## Tower bases, local (a, v), and their tops over the sea.
var _towers := PackedVector2Array()
var _tower_tops := PackedFloat32Array()
## The last `apply`'s change to the land's height (m).
var last_lift := 0.0
## The tarn's centre in the frame (a, v), its level over the sea (both from
## TARN_HANDLE), its water's radius, and the water as a pond (land_ponds.gd's
## array: a round one, no bed of its own, the bowl is the massif's), which
## LandField lays over the massif after its pass, so it reads and draws as
## a pond does.
var _tarn_c := Vector2(-TARN_BACK,0.0)
var _tarn_level := TARN_LEVEL
var _tarn_wet := 0.0
var pond := PackedFloat32Array()
## The cirque's outline phases (lobes 2, 3, 5) and whether it is on.
var _cq_ph := Vector3.ZERO
var _cirque := true
## The crown's towers, (a, v), moved by their handles; their phases.
var _crown := PackedVector2Array()
var _crown_ph := PackedFloat32Array()

## The massif for this land, or null: `--peak=0` turns it off. `ground`:
## the land's own height (world y) at (x, z), for its way from the origin.
static func make(land_seed: int, ground := Callable()) -> RefCounted:
	var at := Vector2.INF
	var yaw := INF
	for a: String in LaunchArgs.user_args():
		if a == "--peak=0" or a == "--no-peak": return null
		if a.begins_with("--peak-at="):
			var xz := a.get_slice("=",1).split(",")
			if xz.size() == 2: at = Vector2(float(xz[0]),float(xz[1]))
		elif a.begins_with("--peak-yaw="): yaw = float(a.get_slice("=",1))
	if not at.is_finite():
		var way := _way_cached(land_seed,ground) if ground.is_valid() else 0.0
		at = Vector2(sin(way),-cos(way))*AWAY
	# Unless given, it faces the origin.
	if not is_finite(yaw): yaw = rad_to_deg(atan2(-at.x,-at.y))
	var coded := Transform3D(Basis(Vector3.UP,deg_to_rad(yaw)),Vector3(at.x,0.0,at.y))
	var m: RefCounted = new(land_seed,LayoutOverrides.xform(HANDLE,coded))
	if ground.is_valid() and not LaunchArgs.user_args().has("--peak-mask=0"): m._mask(land_seed,ground)
	return m

# --- Cost: the way and the live cells, once per land --------------------------------
#
# Every chunk build on a worker makes its own LandField, and with it its own
# massif; what doesn't change between them is worked out once per land (its
# seed and a few of its heights, so another world's land gets its own) and
# shared: the way it faces (`_way`, thousands of height samples) and which
# cells of the bounding circle the massif can change at all (`_mask`).

## The live grid's cell (m), and how far under the land the massif's height
## may come at every corner of a cell and its neighbours before the cell is
## dead (the land and the massif move less than this between corners).
const MASK_CELL := 64.0
const MASK_MARGIN := 80.0
static var _shared := {}
static var _shared_lock := Mutex.new()

## `ground`'s land told apart from another's: its seed and a few heights.
static func _land_key(land_seed: int, ground: Callable) -> Array:
	var key: Array = [land_seed]
	for p: Vector2 in [Vector2(0.0,0.0),Vector2(1730.0,-2210.0),Vector2(-3170.0,1290.0),Vector2(4410.0,3030.0),Vector2(-2050.0,-4470.0)]:
		key.append(snappedf(float(ground.call(p.x,p.y)),0.001))
	return key

static func _way_cached(land_seed: int, ground: Callable) -> float:
	var key := ["way"]+_land_key(land_seed,ground)
	_shared_lock.lock()
	var got: Variant = _shared.get(key)
	if got == null:
		got = _way(ground)
		_shared[key] = got
	_shared_lock.unlock()
	return float(got)

## The live cells: a grid of MASK_CELL over the bounding square round O,
## 1 where the massif may change the land (its cut or meadow above 0, or
## its height within MASK_MARGIN of the land's at a corner of the cell or of
## a neighbour), 0 where it changes nothing. `reaches` and `meets` read it,
## so the land's samples, the chunks and the native readers there are the
## land's own. Baked once per land and frame (about 16k samples).
var _live := PackedByteArray()
var _live_n := 0
var _live_at := Vector2.ZERO
var _fall_map := PackedFloat32Array()

func _mask(land_seed: int, ground: Callable) -> void:
	var key := ["mask",centre,facing]+_land_key(land_seed,ground)
	_shared_lock.lock()
	var got: Variant = _shared.get(key)
	if got == null:
		got = _bake_mask(ground)
		_shared[key] = got
	_shared_lock.unlock()
	_live = got[0]
	_live_n = got[1]
	_live_at = got[2]
	_fall_map = got[3]

func _bake_mask(ground: Callable) -> Array:
	var n := int(ceil(2.0*BOUND/MASK_CELL))
	var at := _o-Vector2.ONE*(n*MASK_CELL*0.5)
	var pts := PackedByteArray()
	pts.resize((n+1)*(n+1))
	var tall := PackedFloat32Array()
	tall.resize((n+1)*(n+1))
	var r2 := (BOUND+MASK_CELL*1.5)*(BOUND+MASK_CELL*1.5)
	for j in n+1:
		for i in n+1:
			var x := at.x+i*MASK_CELL
			var z := at.y+j*MASK_CELL
			if (x-_o.x)*(x-_o.x)+(z-_o.y)*(z-_o.y) >= r2: continue
			var q := Vector2(x,z)-centre
			var hm := _h0(q.dot(facing),q.dot(side))
			if is_finite(hm.x): tall[j*(n+1)+i] = hm.x
			if hm.y > 0.0 or hm.z > 0.0 or not is_finite(hm.x) or hm.x+SEA_Y > float(ground.call(x,z))-MASK_MARGIN: pts[j*(n+1)+i] = 1
	var cells := PackedByteArray()
	cells.resize(n*n)
	for j in n:
		for i in n:
			# A cell's corners and its neighbours' (so a point in it is never
			# farther than a cell from a corner that saw the massif).
			var live := 0
			for jj in range(maxi(j-1,0),mini(j+2,n)+1):
				for ii in range(maxi(i-1,0),mini(i+2,n)+1):
					live |= pts[jj*(n+1)+ii]
			cells[j*n+i] = live
	return [cells,n,at,_lay_falls(tall,n)]

## The fall map: at each corner of the mask's grid, three floats: how steep the
## massif is over two cells, and which way is up (a, v, unit). Rock.move walks
## along it; a smooth 128 m read, so it says "wall here", not what the wall does.
func _lay_falls(tall: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var m := n+1
	var out := PackedFloat32Array()
	out.resize(m*m*3)
	for j in range(1,n):
		for i in range(1,n):
			var k := j*m+i
			var gx := (tall[k+1]-tall[k-1])/(2.0*MASK_CELL)
			var gz := (tall[k+m]-tall[k-m])/(2.0*MASK_CELL)
			var g := Vector2(gx,gz)
			var s := g.length()
			if s < 0.001: continue
			g /= s
			out[k*3] = s
			out[k*3+1] = g.dot(facing)
			out[k*3+2] = g.dot(side)
	return out

## Vector3(steepness, up along a, up along v) at (a, v) off the fall map.
func _falls(a: float, v: float) -> Vector3:
	if _fall_map.is_empty(): return Vector3.ZERO
	var fi := (centre.x+facing.x*a+side.x*v-_live_at.x)/MASK_CELL
	var fj := (centre.y+facing.y*a+side.y*v-_live_at.y)/MASK_CELL
	var i := int(fi)
	var j := int(fj)
	if fi < 0.0 or fj < 0.0 or i >= _live_n or j >= _live_n: return Vector3.ZERO
	fi -= i
	fj -= j
	var m := _live_n+1
	var k0 := (j*m+i)*3
	var k1 := k0+3
	var k2 := k0+m*3
	var k3 := k2+3
	var w0 := (1.0-fi)*(1.0-fj)
	var w1 := fi*(1.0-fj)
	var w2 := (1.0-fi)*fj
	var w3 := fi*fj
	var t := _fall_map
	return Vector3(t[k0]*w0+t[k1]*w1+t[k2]*w2+t[k3]*w3,t[k0+1]*w0+t[k1+1]*w1+t[k2+1]*w2+t[k3+1]*w3,t[k0+2]*w0+t[k1+2]*w1+t[k2+2]*w2+t[k3+2]*w3)

## How much of the rock's relief (PeakRock) stands at (a, v), steepness `s`:
## only on walls; none on the cirque's floor or the strip, little where a tower
## stands on its plinth. (A gorge's floor and foot: see _h_rock.)
func _rock_keep(a: float, v: float, s: float) -> float:
	var k := smoothstep(ROCK_STEEP.x,ROCK_STEEP.y,s)
	if k <= 0.0: return 0.0
	var rho2 := a*a+v*v
	if rho2 < CIRQUE_REACH2: k *= smoothstep(ROCK_CIRQUE.x,ROCK_CIRQUE.y,sqrt(rho2))
	if rho2 < CROWN_REACH*CROWN_REACH:
		for t in _crown.size():
			var row: Array = CROWN[t]
			k *= smoothstep(float(row[4])*ROCK_TOWER.x,float(row[4])*ROCK_TOWER.y,Vector2(a,v).distance_to(_crown[t]))
	return k

## Whether the live cell under world (x, z) is live (true off the grid).
func _live_cell(x: float, z: float) -> bool:
	if _live_n == 0: return true
	var i := floori((x-_live_at.x)/MASK_CELL)
	var j := floori((z-_live_at.y)/MASK_CELL)
	if i < 0 or j < 0 or i >= _live_n or j >= _live_n: return false
	return _live[j*_live_n+i] == 1

## The share of the bounding circle's cells that are live (for the cost
## drivers).
func live_share() -> float:
	if _live_n == 0: return 1.0
	var live := 0
	var inside := 0
	for j in _live_n:
		for i in _live_n:
			var c := _live_at+Vector2(i+0.5,j+0.5)*MASK_CELL
			if c.distance_to(_o) < BOUND:
				inside += 1
				live += _live[j*_live_n+i]
	return float(live)/maxf(float(inside),1.0)

## The way from the origin (radians: 0 toward -z, PI/2 toward +x) the
## plateau stands (see AWAY).
static func _way(ground: Callable) -> float:
	var eye := maxf(float(ground.call(0.0,0.0)),SEA_Y)+3.0
	var best := 0.0
	var best_score := -INF
	for k in YAWS:
		var way := TAU*k/YAWS
		var dir := Vector2(sin(way),-cos(way))
		var steep := -90.0
		var d := SIGHT_STEP*2.0
		while d <= SIGHT:
			var p := dir*d
			steep = maxf(steep,rad_to_deg(atan2(maxf(float(ground.call(p.x,p.y)),SEA_Y)-eye,d)))
			d += SIGHT_STEP
		var sea := 0
		for b: float in BEHIND:
			for v: float in [-ACROSS,0.0,ACROSS]:
				var q := dir*(WAY_AWAY+b)+Vector2(-dir.y,dir.x)*v
				if float(ground.call(q.x,q.y)) < SEA_Y: sea += 1
		var score := SEA_WORTH*float(sea)/(BEHIND.size()*3)-steep
		if score > best_score+0.001:
			best_score = score
			best = way
	return best

func _init(land_seed: int, frame: Transform3D) -> void:
	centre = Vector2(frame.origin.x,frame.origin.z)
	var f := frame.basis.z
	facing = Vector2(f.x,f.z).normalized()
	side = Vector2(-facing.y,facing.x)
	_o = centre+facing*O_ALONG
	Split.bake()
	_noise.seed = hash([land_seed,"peak"]) & 0x7fffffff
	_rock = Rock.new(land_seed)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0/ROUGH_SCALE
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	for s: float in [-1.0,1.0]:
		for t: float in (TOWER_POS if s > 0.0 else TOWER_NEG):
			var r := deg_to_rad(t)
			_towers.append(Vector2(O_ALONG-RING_R*cos(r),s*RING_R*sin(r)))
			# Each its own height over the crest.
			_tower_tops.append(_crest(t,s)+TOWER_UP*TOWER_UPS[_towers.size()%TOWER_UPS.size()])
	# The tarn, through its handle (its centre on the plateau, its level kept
	# inside the bowl).
	var tw := world(_tarn_c.x,_tarn_c.y)
	var tt := LayoutOverrides.xform(TARN_HANDLE,Transform3D(frame.basis,Vector3(tw.x,TARN_LEVEL+SEA_Y,tw.y)))
	var tq := Vector2(tt.origin.x,tt.origin.z)-centre
	_tarn_c = Vector2(tq.dot(facing),tq.dot(side))
	_tarn_level = clampf(tt.origin.y-SEA_Y,SHORE_Y-TARN_DEEP+0.5,SHORE_Y-0.25)
	_tarn_wet = TARN_BOWL*sqrt(1.0-pow((SHORE_Y-_tarn_level)/TARN_DEEP,2.0/3.0))
	var tc := world(_tarn_c.x,_tarn_c.y)
	_cirque = not LaunchArgs.user_args().has("--cirque=0")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([land_seed,"cirque"])
	var lb := TARN_LOBES if _cirque else Vector3.ZERO
	var ph := Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU)
	_cq_ph = Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU)
	for k in CROWN.size():
		var row: Array = CROWN[k]
		var cw := world(float(row[0]),float(row[1]))
		var moved := LayoutOverrides.xform("peak/tower/%d" % k,Transform3D(Basis.IDENTITY,Vector3(cw.x,0.0,cw.y))).origin
		var cq := Vector2(moved.x,moved.z)-centre
		_crown.append(Vector2(cq.dot(facing),cq.dot(side)))
		_crown_ph.append(rng.randf()*TAU)
	_lay_ribs(land_seed)
	pond = PackedFloat32Array([tc.x,tc.y,_tarn_wet,_tarn_level+SEA_Y,0.0,lb.x,ph.x,lb.y,ph.y,lb.z,ph.z,_tarn_wet*(1.0+lb.x+lb.y+lb.z)])

# --- Asked by the land field ----------------------------------------------------------

## Whether (x, z) lies inside the bounding circle (one distance check).
func reaches(x: float, z: float) -> bool:
	var dx := x-_o.x
	var dz := z-_o.y
	return dx*dx+dz*dz < BOUND*BOUND and _live_cell(x,z)

## Whether the box (x0, z0)..(x1, z1) meets the bounding circle.
func meets(x0: float, z0: float, x1: float, z1: float) -> bool:
	var dx := _o.x-clampf(_o.x,x0,x1)
	var dz := _o.y-clampf(_o.y,z0,z1)
	if dx*dx+dz*dz >= BOUND*BOUND: return false
	if _live_n == 0: return true
	var i0 := maxi(floori((x0-_live_at.x)/MASK_CELL),0)
	var i1 := mini(floori((x1-_live_at.x)/MASK_CELL),_live_n-1)
	var j0 := maxi(floori((z0-_live_at.y)/MASK_CELL),0)
	var j1 := mini(floori((z1-_live_at.y)/MASK_CELL),_live_n-1)
	for j in range(j0,j1+1):
		for i in range(i0,i1+1):
			if _live[j*_live_n+i] == 1: return true
	return false

## Whether a site of reach `r` at (x, z) stays clear of the massif (the
## ponds, tunnels, halls and splits keep out of it, and through LandField
## `off_peak` the arches, set pieces, rocks and shops). The bounding circle
## runs well past the toe, over the land behind the start, where the massif
## changes nothing: past CLEAR_PAST m beyond the toe a site is clear.
func clear(x: float, z: float, r: float) -> bool:
	if (Vector2(x,z)-centre).dot(facing)-r > TOE.y+CLEAR_PAST: return true
	return Vector2(x,z).distance_to(_o) > BOUND+r

## Whether a site of reach `r` at (x, z) stays clear of `field`'s massif
## (any field: one without `off_peak` has none).
static func off(field: RefCounted, x: float, z: float, r := 0.0) -> bool:
	return not field.has_method("off_peak") or bool(field.off_peak(x,z,r))

## The land's Vector2(world height, meadow) `base` at (x, z) with the massif
## on it (the caller checked `reaches`). Sets `last_lift`.
func apply(base: Vector2, x: float, z: float, step := 0.0) -> Vector2:
	var q := Vector2(x,z)-centre
	var hm := _h(q.dot(facing),q.dot(side),step)
	var by := base.x-SEA_Y
	var y := lerpf(maxf(by,hm.x),hm.x,hm.y)
	last_lift = y-by
	var m := maxf(base.y*(1.0-smoothstep(0.5,6.0,absf(last_lift))),hm.z)
	return Vector2(y+SEA_Y,m)

## The massif's pass over a chunk's arrays (LandField.build_chunk; its
## args), after every other layer's: heights, then the normals (central
## differences, as the field's) and colours round what moved, the skirt's
## copies of the edges. The land's heights one step outside the chunk come
## back from its edge normals (each is (left-right, 2 step, down-up)), so
## the edges' normals need no field sample. `field` the LandField (its
## `colours`).
func apply_chunk(field: Object, _impl: Object, made: Dictionary, x0: float, z0: float, step: float, cells: int, skirt_drop: float) -> void:
	var n := cells+1
	var w := n+2
	var heights: PackedFloat32Array = made.heights
	var verts: PackedVector3Array = made.verts
	var normals: PackedVector3Array = made.normals
	var colours: PackedColorArray = made.colours
	var carved: PackedByteArray = made.carved
	var river: PackedFloat32Array = made.river
	# The padded grid's heights (a ring of one step round the chunk, its
	# corners unused) and which moved; which vertices the massif lifted.
	var hs := PackedFloat32Array()
	hs.resize(w*w)
	var mv := PackedByteArray()
	mv.resize(w*w)
	var lifted := PackedByteArray()
	lifted.resize(n*n)
	# The rock's paint, -1 down a gully to 1 up a rib (PeakRock).
	var relief := PackedFloat32Array()
	relief.resize(n*n)
	var any := false
	var r2 := BOUND*BOUND
	var fx := facing.x
	var fz := facing.y
	var sx := side.x
	var sz := side.y
	for jj in w:
		var j := jj-1
		var j_out := j < 0 or j > cells
		for ii in w:
			var i := ii-1
			var i_out := i < 0 or i > cells
			if i_out and j_out: continue
			var base: float
			var v := j*n+i
			if not i_out and not j_out: base = heights[v]
			elif i < 0:
				v = j*n
				base = heights[v+1]+2.0*step*normals[v].x/normals[v].y
			elif i_out:
				v = j*n+cells
				base = heights[v-1]-2.0*step*normals[v].x/normals[v].y
			elif j < 0:
				v = i
				base = heights[v+n]+2.0*step*normals[v].z/normals[v].y
			else:
				v = cells*n+i
				base = heights[v-n]-2.0*step*normals[v].z/normals[v].y
			var k := jj*w+ii
			hs[k] = base
			var x := x0+i*step
			var z := z0+j*step
			var dx := x-_o.x
			var dz := z-_o.y
			if dx*dx+dz*dz >= r2: continue
			if _live_n > 0:
				var ci := floori((x-_live_at.x)/MASK_CELL)
				var cj := floori((z-_live_at.y)/MASK_CELL)
				if ci < 0 or cj < 0 or ci >= _live_n or cj >= _live_n or _live[cj*_live_n+ci] == 0: continue
			var qx := x-centre.x
			var qz := z-centre.y
			var hm := _h_rock(qx*fx+qz*fz,qx*sx+qz*sz,step)
			var by := base-SEA_Y
			var y := lerpf(maxf(by,hm.x),hm.x,hm.y)
			var lift := y-by
			if not i_out and not j_out:
				relief[v] = hm.w
				var c := colours[v]
				var m := maxf(c.a*(1.0-smoothstep(0.5,6.0,absf(lift))),hm.z)
				if absf(lift) <= 0.0005 and absf(m-c.a) <= 0.002: continue
				c.a = m
				colours[v] = c
				if absf(lift) > 1.0: lifted[v] = 1
			elif absf(lift) <= 0.0005: continue
			hs[k] = y+SEA_Y
			mv[k] = 1
			any = true
	if not any: return
	# Normals and colours wherever a height round them moved.
	var redo := PackedInt32Array()
	for j in n:
		for i in n:
			var k := (j+1)*w+i+1
			if mv[k]+mv[k-1]+mv[k+1]+mv[k-w]+mv[k+w] > 0: redo.append(j*n+i)
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	var ys := PackedFloat32Array()
	var ups := PackedFloat32Array()
	var ms := PackedFloat32Array()
	xs.resize(redo.size())
	zs.resize(redo.size())
	ys.resize(redo.size())
	ups.resize(redo.size())
	ms.resize(redo.size())
	for t in redo.size():
		var v := redo[t]
		var i := v%n
		var j := v/n
		var k := (j+1)*w+i+1
		var normal := Vector3(hs[k-1]-hs[k+1],2.0*step,hs[k-w]-hs[k+w]).normalized()
		normals[v] = normal
		heights[v] = hs[k]
		verts[v] = Vector3(verts[v].x,hs[k],verts[v].z)
		xs[t] = x0+i*step
		zs[t] = z0+j*step
		ys[t] = hs[k]
		ups[t] = normal.y
		ms[t] = colours[v].a
		if mv[k] != 0:
			# Off the carve's marks (the field's groove and crest): on the
			# massif they're its rock's relief.
			carved[v*4] = int(clampf(-relief[v],0.0,1.0)*255.0)
			carved[v*4+1] = int(clampf(relief[v],0.0,1.0)*255.0)
		if lifted[v] != 0:
			# No river on the massif: far from any, its flow still.
			carved[v*4+2] = 128
			carved[v*4+3] = 128
			river[v*3] = 1000.0
			river[v*3+1] = 0.0
			river[v*3+2] = SEA_Y-100.0
	var cs: PackedColorArray = field.colours(xs,zs,ys,ups,ms)
	for t in redo.size():
		var c := cs[t]
		c.a = ms[t]
		colours[redo[t]] = c
	# The skirt's copies of the edges.
	for e in 4:
		for t in n:
			var from: int = t if e == 0 else (t*n+cells if e == 1 else (cells*n+t if e == 2 else t*n))
			var k := ((from/n)+1)*w+(from%n)+1
			if mv[k]+mv[k-1]+mv[k+1]+mv[k-w]+mv[k+w] == 0: continue
			var sv := n*n+e*n+t
			verts[sv] = verts[from]-Vector3(0.0,skirt_drop,0.0)
			normals[sv] = normals[from]
			colours[sv] = colours[from]
			for q in 4: carved[sv*4+q] = carved[from*4+q]
			river[sv*3] = river[from*3]
			river[sv*3+1] = -river[from*3+1]
			river[sv*3+2] = river[from*3+2]
	made.heights = heights
	made.verts = verts
	made.normals = normals
	made.colours = colours
	made.carved = carved
	made.river = river

## The massif's pass over LandField.grid's arrays (the grass's, the
## horizon's): heights, meadows, and no river where it lifts the land.
func apply_grid(got: Dictionary, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var hs: PackedFloat32Array = got.heights
	var ms: PackedFloat32Array = got.meadows
	var rs: PackedFloat32Array = got.river
	var i0 := clampi(floori((_o.x-BOUND-x0)/step)+pad,0,nx-1)
	var i1 := clampi(ceili((_o.x+BOUND-x0)/step)+pad,0,nx-1)
	var j0 := clampi(floori((_o.y-BOUND-z0)/step)+pad,0,nz-1)
	var j1 := clampi(ceili((_o.y+BOUND-z0)/step)+pad,0,nz-1)
	for j in range(j0,j1+1):
		for i in range(i0,i1+1):
			var x := x0+(i-pad)*step
			var z := z0+(j-pad)*step
			if not reaches(x,z): continue
			var k := j*nx+i
			var m := ms[k] if not ms.is_empty() else 0.0
			var y := apply(Vector2(hs[k],m),x,z,step)
			hs[k] = y.x
			if not ms.is_empty(): ms[k] = y.y
			if absf(last_lift) > 1.0 and not rs.is_empty(): rs[k] = 1000.0
	got.heights = hs
	if not ms.is_empty(): got.meadows = ms
	if not rs.is_empty(): got.river = rs

# --- For the trunk and the lanes -----------------------------------------------------

## A world XZ point at (a, v) in the massif's frame.
func world(a: float, v := 0.0) -> Vector2:
	return centre+facing*a+side*v

## The ground shader's Peak uniforms (shaders/endless_ground.gdshader
## `peak_paint`): the frame, the zone, the snow line and the valley.
func paint() -> Dictionary:
	return {"peak_frame":Vector4(centre.x,centre.y,facing.x,facing.y),"peak_zone":Vector4(_o.x,_o.y,BOUND,1.0),
		"peak_snow":SNOW_LINE,"peak_stretch":Vector4(ICEFALL.x,ICEFALL.y,GLACIER.x,GLACIER.y),"peak_half":FLOOR_HALF,
		"peak_bend":Vector4(GL_BEND,GL_TURNS,BOULDERS.x,TOE.y),
		"peak_cirque":Vector4(CIRQUE_R,_cq_ph.x,_cq_ph.y,_cq_ph.z),"peak_cirque_lobes":Vector4(CIRQUE_LOBES.x,CIRQUE_LOBES.y,CIRQUE_LOBES.z,RIM.z),
		"peak_cirque_strip":Vector4(STRIP.x,STRIP.z+10.0,STRIP.z+40.0,1.0 if _cirque else 0.0)}.merged(PeakIce.uniforms(PeakIce.gorge(self))).merged(PeakIce.rock_uniforms(self))

## The tarn's bowl: {centre (world, at the water level), level (world y),
## wet (the water's radius at that level), bowl (the bowl's radius), shore
## (the flat shore's reach from the plateau's centre, the old flat disc's),
## plateau (world XZ), widest (the lobed water's), strip (the flat shore's
## two ends, world, at PLATEAU_Y), strip_half (its half-width)}.
func tarn() -> Dictionary:
	var c := world(_tarn_c.x,_tarn_c.y)
	var s0 := world(STRIP.x,-STRIP.y)
	var s1 := world(STRIP.x,STRIP.y)
	var ly := PLATEAU_Y+SEA_Y
	return {"centre":Vector3(c.x,_tarn_level+SEA_Y,c.y),"level":_tarn_level+SEA_Y,"wet":_tarn_wet,"bowl":TARN_BOWL,
		"shore":PLATEAU_FLAT,"plateau":centre,"widest":float(pond[11]),
		"strip":[Vector3(s0.x,ly,s0.y),Vector3(s1.x,ly,s1.y)],"strip_half":STRIP.z}

## Whether the box (x0, z0)..(x1, z1) meets the tarn's reach (its water and
## the REACH round it that its reads carry).
func tarn_meets(x0: float, z0: float, x1: float, z1: float) -> bool:
	var far := _tarn_wet+Ponds.REACH
	return pond[0]+far >= x0 and pond[0]-far <= x1 and pond[1]+far >= z0 and pond[1]-far <= z1

## Where world XZ (x, z) lies on the cirque: Vector4(s, tn, a, v): its
## distance over the cirque's lobed outline (1 on the rim's line), over the
## tarn's bowl's (1 at the bowl's edge), and its (a, v) in the massif's
## frame. --cirque=0: s and tn are INF (no cirque to dress).
func cirque_at(x: float, z: float) -> Vector4:
	var rel := Vector2(x,z)-centre
	var a := rel.dot(facing)
	var v := rel.dot(side)
	if not _cirque: return Vector4(INF,INF,a,v)
	return Vector4(sqrt(a*a+v*v)/_cq_r(atan2(v,a)),_tarn_n(a,v),a,v)

## Whether a world point stands on the summit plateau (inside its blend, no
## lower than PLATEAU_UNDER m under its flat): where a landing is on the Peak.
const PLATEAU_UNDER := 25.0
func on_plateau(p: Vector3) -> bool:
	return Vector2(p.x,p.z).distance_to(centre) < PLATEAU_BLEND and p.y-SEA_Y > PLATEAU_Y-PLATEAU_UNDER

## Gorge `g` (Split.ICE, Split.ROCK): {line (world points on its floor's middle,
## every Split.STRIDE m, nose to the plateau's edge), half (its floor's half-width
## at each), saddle (the index of the saddle's point), side (each point's
## unit normal in world XZ), length (m, nose to saddle)}.
func gorge(g: int) -> Dictionary:
	var pts: PackedVector3Array = Split.line(g)
	var line: Array[Vector3] = []
	var normal: Array[Vector2] = []
	for k in pts.size():
		var p := world(pts[k].x,pts[k].y)
		line.append(Vector3(p.x,pts[k].z+SEA_Y,p.y))
		var o := pts[mini(k+1,pts.size()-1)]-pts[maxi(k-1,0)]
		var t := world(o.x,o.y)-world(0.0,0.0)
		normal.append(Vector2(-t.y,t.x).normalized())
	return {"line":line,"half":Split.halves(g),"saddle":Split.saddle(g),"side":normal,"length":Split.length(g)}

## The tower bases' tops (world), for the spires.
func tower_bases() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in _towers.size():
		var p := world(_towers[k].x,_towers[k].y)
		out.append(Vector3(p.x,_tower_tops[k]+SEA_Y,p.y))
	return out

## The crown's highest tip (world).
func summit() -> Vector3:
	var best := 0
	for k in CROWN.size():
		if float(CROWN[k][2]) > float(CROWN[best][2]): best = k
	var p := world(_crown[best].x,_crown[best].y)+_lean(best)
	return Vector3(p.x,float(CROWN[best][2])+SEA_Y,p.y)

## Tower `k`'s lean: world XZ, the way its tip stands off its base.
func _lean(k: int) -> Vector2:
	var a := _crown[k]
	return (world(CROWN_MID.x,CROWN_MID.y)-world(a.x,a.y)).normalized()*float(CROWN[k][3])

## The crown's table for PeakTowers.setup: `entry`'s entry for each tower at its
## coded place, on the land's own height (`height`: world y at (x, z)).
func crown(height: Callable, entry: Callable) -> Array:
	var out: Array = []
	for k in CROWN.size():
		var row: Array = CROWN[k]
		var at := world(float(row[0]),float(row[1]))
		var low := float(height.call(at.x,at.y))
		for q in 16:
			var p := at+Vector2.from_angle(TAU*q/16.0)*float(row[4])*FOOT_RING
			low = minf(low,float(height.call(p.x,p.y)))
		out.append(entry.call(at,low-SEA_Y,float(row[2]),_lean(k),float(row[4]),int(row[5])))
	return out

# --- The profile -------------------------------------------------------------------

## The crest's height over the sea at `th` degrees from the back, on the
## +v side (s > 0) or the -v side.
static func _crest(th: float, s: float) -> float:
	var cr: Array = CREST_POS if s > 0.0 else CREST_NEG
	var k := 0
	while k+4 < cr.size() and th > float(cr[k+2]): k += 2
	var t0: float = cr[k]
	var t1: float = cr[k+2]
	return lerpf(float(cr[k+1]),float(cr[k+3]),clampf((th-t0)/(t1-t0),0.0,1.0))

## Lays the ribs round the ring (see RIB_P), from a little behind the back
## to past the arms' ends, for each side and flank.
func _lay_ribs(land_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([land_seed,"ribs"])
	_ribs.clear()
	for k in 4:
		var outer := k%2 == 1
		var p := RIB_P.y if outer else RIB_P.x
		for wide: bool in [false,true]:
			var t := PackedFloat32Array()
			var unit := p*(RIB_WIDE if wide else 1.0)
			var th := -rng.randf()*unit*RIB_WIDTH.y
			while th < ARM_END+20.0:
				var w := unit*lerpf(RIB_WIDTH.x,RIB_WIDTH.y,pow(rng.randf(),1.6))
				var amp := lerpf(RIB_AMP.x,RIB_AMP.y,rng.randf())
				if rng.randf() < RIB_FAINT: amp *= 0.25
				var end := RIB_END_OUT if outer else RIB_END
				t.append_array(PackedFloat32Array([th,w,amp,0.5+RIB_SKEW*rng.randf_range(-1.0,1.0),
					lerpf(RIB_SHARP.x,RIB_SHARP.y,rng.randf()),RIB_START*rng.randf()*rng.randf(),
					lerpf(end.x,end.y,rng.randf())]))
				th += w
			_ribs.append(t)

## The rib pattern at `th` on side `s` (outer flank or inner), `e` m down
## the flank from the crest: RIB_SPUR on a spur's line and where no rib
## runs, up to 1 in a gully's bottom; 0 at the back (th 0).
func _rib(th: float, s: float, outer: bool, e: float) -> float:
	var k := (2 if s > 0.0 else 0)+(1 if outer else 0)
	var tw := th+RIB_WANDER*_noise.get_noise_2d(th*2.5+600.0*k,e*0.35+3000.0)*smoothstep(0.0,300.0,e)
	var r := _rib_in(_ribs[k*2],tw,e)*(1.0-RIB_WIDE_SHARE)+_rib_in(_ribs[k*2+1],tw,e)*RIB_WIDE_SHARE
	# Both sides meet at the back with no ribs, so they agree there.
	return lerpf(0.0,r,smoothstep(0.0,3.0,th))

## One table's rib at `th`, `e` m down the flank (see _rib).
static func _rib_in(t: PackedFloat32Array, th: float, e: float) -> float:
	var lo := 0
	var hi := t.size()/RIB_STRIDE-1
	while lo < hi:
		var mid := (lo+hi+1) >> 1
		if t[mid*RIB_STRIDE] <= th: lo = mid
		else: hi = mid-1
	var i := lo*RIB_STRIDE
	var f := clampf((th-t[i])/t[i+1],0.0,1.0)
	var c := t[i+3]
	var g := (c-f)/c if f < c else (f-c)/(1.0-c)
	var amp := t[i+2]*smoothstep(t[i+5],t[i+5]+90.0,e)*(1.0-smoothstep(t[i+6]-150.0,t[i+6],e))
	return RIB_SPUR+(1.0-RIB_SPUR)*amp*(1.0-pow(g,t[i+4]))

## The valley's middle (v) at `a`.
static func _valley_mid(a: float) -> float:
	var t := clampf((a-BOULDERS.x)/(TOE.y-BOULDERS.x),0.0,1.0)
	return GL_BEND*sin(PI*GL_TURNS*t)*smoothstep(0.0,0.25,t)

## The crown's rock at (a, v): the plinths and the aretes between them, height
## over the sea.
func _crown_rock(a: float, v: float, n: float) -> float:
	var h := -INF
	var at := Vector2(a,v)
	for k in _crown.size():
		var d := at-_crown[k]
		var phi := atan2(d.y,d.x)+_crown_ph[k]
		var lobe := 1.0+PLINTH_LOBE*(0.6*sin(3.0*phi)+0.4*sin(5.0*phi+1.3))
		var out := maxf(d.length()-PLINTH_R*float(CROWN[k][4]),0.0)
		var top := float(PLINTH_TOPS[k])-out*PLINTH_FALL*lobe-out*out*PLINTH_SINK+n*ROUGH*1.6
		if top > h: h = top
	for e: Array in ARETES:
		var p := _crown[int(e[0])]
		var pq := _crown[int(e[1])]-p
		var t := clampf((at-p).dot(pq)/pq.length_squared(),0.0,1.0)
		var off := (at-(p+pq*t)).length()
		if off > 300.0: continue
		var sag := 4.0*t*(1.0-t)
		var y := lerpf(float(PLINTH_TOPS[int(e[0])]),float(PLINTH_TOPS[int(e[1])]),t)-float(e[2])*sag
		y += ARETE_BREAK*_noise.get_noise_2d(t*pq.length()*2.5+float(e[0])*900.0,5000.0)*sag
		var top := y-off*ARETE_FALL+n*ROUGH*1.2
		if top > h: h = top
	return h

## The wall `e` m in from a crest at `hc`: talus, then a cliff.
static func _wall(e: float, hc: float) -> float:
	if e >= WALL_RUN: return WALL_FOOT-(e-WALL_RUN)*TALUS_FALL
	var t := 1.0-maxf(e,0.0)/WALL_RUN
	return WALL_FOOT+(hc-WALL_FOOT)*(TALUS_SHARE*smoothstep(0.0,TALUS_TOP,t)+(1.0-TALUS_SHARE)*smoothstep(CLIFF.x,CLIFF.y,t))

## A fall from `top` over `run` m to FALL_END, steep first (`bow` > 1), on
## past its run at PAST_END.
static func _fall(top: float, d: float, run: float, bow: float) -> float:
	if d >= run: return FALL_END-(d-run)*PAST_END
	return top-(top-FALL_END)*(1.0-pow(1.0-d/run,bow))

## Vector3(height over the sea, cut 0..1, meadow) at (a, v) in the frame.
## The massif at (a, v) with its rock's relief on the walls: Vector3(height, cut,
## meadow). `step` the asker's quad (0: every scale; see PeakRock).
func _h(a: float, v: float, step := 0.0) -> Vector3:
	var hm := _h_rock(a,v,step)
	return Vector3(hm.x,hm.y,hm.z)

## `_h` with the rock's paint in w, -1 down a gully to 1 up a rib. Near a gorge's
## floor only the hollows move: back from the flown air, down to the floor's edge
## and never past it, so the floor stands and no wall comes nearer the plane.
func _h_rock(a: float, v: float, step: float) -> Vector4:
	var hm: Vector3
	var f := _falls(a,v) if Rock.wanted else Vector3.ZERO
	var keep := _rock_keep(a,v,f.x) if f.x > ROCK_STEEP.x else 0.0
	if keep <= 0.0:
		hm = _h0(a,v)
		return Vector4(hm.x,hm.y,hm.z,0.0)
	var m: Vector2 = _rock.move(a,v,step)
	var e: float = Split.near(a,v)
	var air := smoothstep(ROCK_FOOT.x,ROCK_FOOT.y,e)
	var w := lerpf(minf(m.x,0.0)*smoothstep(0.0,ROCK_FOOT.x,e),m.x,air)*keep
	hm = _h0(a+f.y*w,v+f.z*w)
	hm.x = _rock.ledge(hm.x,centre.x+facing.x*a+side.x*v,centre.y+facing.y*a+side.y*v,a,v,keep*air,step)+m.y*ROCK_LIFT*keep*air
	return Vector4(hm.x,hm.y,hm.z,clampf(m.y/ROCK_PAINT,-1.0,1.0)*keep*smoothstep(0.0,ROCK_FOOT.x,e))

## The massif's own shapes at (a, v).
func _h0(a: float, v: float) -> Vector3:
	var n := _noise.get_noise_2d(a,v)
	var av := absf(v)
	var sg := 1.0 if v >= 0.0 else -1.0
	var oa := a-O_ALONG
	var r := sqrt(oa*oa+v*v)
	var th := rad_to_deg(atan2(av,-oa))
	var h := -INF
	var c := 0.0
	var meadow := 0.0
	# The ring.
	if th < ARM_END+10.0:
		var hc := _crest(th,sg)
		var d := r-RING_R
		var rough := 1.0
		var hr: float
		if d < 0.0:
			var e := -d
			# Buttresses and gullies down the wall and the arms' inner flank.
			var rib := _rib(th,sg,false,e)
			var foot := 1.0-smoothstep(RIB_FOOT.x,RIB_FOOT.y,e)
			var hw := _wall(e+RIB_IN*rib*smoothstep(0.0,120.0,e)*foot,hc)
			var ea := e+RIB_ARM*rib*smoothstep(0.0,150.0,e)*foot
			var ha := hc-ea*lerpf(ARM_IN.x,ARM_IN.y,smoothstep(0.0,500.0,ea))
			hr = lerpf(ha,hw,1.0-smoothstep(30.0,60.0,th))
		else:
			# Spurs and gullies down the outer falls.
			var rib := RIB_OUT*_rib(th,sg,true,d)
			var dr := d+rib*smoothstep(20.0,RIB_GROW,d)
			var ws := 1.0-smoothstep(5.0,16.0,th)
			var hs: float
			if d < SHOULDER.x: hs = lerpf(hc,PLATEAU_Y,smoothstep(0.0,SHOULDER.x,d))
			elif d < SHOULDER.y: hs = PLATEAU_Y
			elif d < SHOULDER.z: hs = lerpf(PLATEAU_Y,LIP_Y,smoothstep(SHOULDER.y,SHOULDER.z,d))
			else:
				var db := d-SHOULDER.z
				hs = _fall(LIP_Y,db+rib*smoothstep(20.0,RIB_GROW,db),BACK_RUN,BACK_BOW)
			var hb := lerpf(_fall(hc,dr,BACK_RUN,KNIFE_BOW),hs,ws)
			hr = lerpf(_fall(hc,dr,ARM_OUT_RUN,ARM_OUT_BOW),hb,1.0-smoothstep(35.0,70.0,th))
			rough = lerpf(1.0,0.15,ws*smoothstep(40.0,SHOULDER.x,d)*(1.0-smoothstep(SHOULDER.y+20.0,SHOULDER.z+60.0,d)))
		# The arms' tips sink under the land.
		hr -= 400.0*smoothstep(160.0,ARM_END+8.0,th)
		h = hr+n*ROUGH*rough
		c = (1.0-smoothstep(RING_R,RING_R+150.0,r))*(1.0-smoothstep(130.0,160.0,th))
	# The approach valley.
	var vl := _valley(a,v,n)
	if vl.x > h: h = vl.x
	c = maxf(c,vl.y)
	# The tower bases on the crest.
	if th < 42.0 and absf(r-RING_R) < 70.0:
		for k in _towers.size():
			var dt := Vector2(a,v).distance_to(_towers[k])
			if dt > TOWER_R+60.0: continue
			var ht := _tower_tops[k]-maxf(dt-TOWER_R,0.0)*TOWER_FALL+n*ROUGH*0.2
			if ht > h: h = ht
	# The split: the prow and the gorges' ridges stand on all of it, the gorges
	# cut through.
	h = Split.carve(a,v,h,n,ROUGH,_noise)
	# The plateau: the cirque, the tarn's bowl in it.
	var rho2 := a*a+v*v
	if _cirque:
		if rho2 < CIRQUE_REACH2:
			var cq := _cirq(a,v,h)
			h = cq.x
			c = maxf(c,cq.y)
	elif rho2 < PLATEAU_BLEND*PLATEAU_BLEND:
		var wf := 1.0-smoothstep(PLATEAU_FLAT,PLATEAU_BLEND,sqrt(rho2))
		var ta := a-_tarn_c.x
		var tv := v-_tarn_c.y
		var rt := sqrt(ta*ta+tv*tv)
		var hp := PLATEAU_Y-SHORE_DROP*(1.0-smoothstep(TARN_BOWL,TARN_BOWL*SHORE_RUN,rt))
		if rt < TARN_BOWL: hp -= TARN_DEEP*pow(1.0-(rt/TARN_BOWL)*(rt/TARN_BOWL),1.5)
		h = lerpf(h,hp,wf)
		c = maxf(c,wf)
		meadow = wf*smoothstep(_tarn_wet,_tarn_wet+6.0,rt)
	# The crown's rock stands on all of it.
	if rho2 < CROWN_REACH*CROWN_REACH:
		var cr := _crown_rock(a,v,n)
		if cr > h: h = cr
	return Vector3(h,c,meadow)

## The cirque at (a, v) over the land's `h` there (see CIRQUE_R):
## Vector2(height over the sea, cut). No meadow on it: it is over the snow.
func _cirq(a: float, v: float, h: float) -> Vector2:
	var rho := sqrt(a*a+v*v)
	var phi := atan2(v,a)
	var s := rho/_cq_r(phi)
	# The crest's side: 1 on the axis toward it, 0 square across.
	var hd := smoothstep(0.25,0.75,a/maxf(rho,1.0))
	var wf := (1.0-smoothstep(CIRQUE_OUT.x,CIRQUE_OUT.y,s))*(1.0-smoothstep(CIRQUE_FRONT.x,CIRQUE_FRONT.y,a))
	if wf <= 0.0: return Vector2(h,0.0)
	# The tarn's bowl, on the water's lobed outline.
	var tn := _tarn_n(a,v)
	# The strip: its distance from the strip's line, and its runout lane.
	var sd := Vector2(a-STRIP.x,maxf(absf(v)-STRIP.y,0.0)).length()
	var flat := 1.0-smoothstep(STRIP.z,STRIP.z+(STRIP.w if a > STRIP.x else STRIP.w*0.5),sd)
	flat = maxf(flat,1.0-smoothstep(0.0,APRON.y,Vector2(maxf(STRIP.x-a,0.0),maxf(absf(v)-APRON.x,0.0)).length()))
	var lane := 1.0-smoothstep(STRIP.z+10.0,STRIP.z+40.0,absf(a-STRIP.x))
	var quiet := smoothstep(QUIET.x,QUIET.y,tn)
	# The floor, broken, and down to the lake's shore.
	var kn := _noise.get_noise_2d(a*ROUGH_SCALE/KNOBS.y+7000.0,v*ROUGH_SCALE/KNOBS.y)
	var broken := smoothstep(KNOBS.z,KNOBS.z+0.4,kn)*lerpf(0.45,1.0,smoothstep(0.3,0.9,s))
	var swell := _noise.get_noise_2d(a*ROUGH_SCALE/SWELL.y-4000.0,v*ROUGH_SCALE/SWELL.y)
	var fall := sqrt(1.0-smoothstep(SHORE_FALL.x,SHORE_FALL.y,a))*(1.0-smoothstep(SHORE_ACROSS.x,SHORE_ACROSS.y,absf(v)))*smoothstep(_tarn_c.x-40.0,_tarn_c.x+40.0,a)
	var calm := (1.0-smoothstep(SHORE_FALL.y,STRIP.x,a))*(1.0-smoothstep(SHORE_ACROSS.x,SHORE_ACROSS.y,absf(v)))
	var hp := PLATEAU_Y+(FLOOR_RISE*smoothstep(0.5,1.0,s)+KNOBS.x*broken+SWELL.x*swell)*quiet*(1.0-calm)
	hp -= SHORE_DROP*maxf(1.0-smoothstep(1.0,SHORE_RUN,tn),fall)
	# The rim, its height wandering round it, broken.
	var rn := _noise.get_noise_2d(cos(phi)*CIRQUE_R*0.7+3000.0,sin(phi)*CIRQUE_R*0.7)*0.5+0.5
	var rim := lerpf(RIM.x,RIM.y,smoothstep(0.15,0.85,rn))*(1.0+0.2*kn)
	var bump := maxf(1.0-absf(s-1.0)/RIM.z,0.0)
	hp += rim*bump*bump*(3.0-2.0*bump)*(1.0-hd)*(1.0-lane)
	if tn < 1.0: hp -= TARN_DEEP*pow(1.0-tn*tn,1.5)
	hp = lerpf(hp,PLATEAU_Y,flat)
	return Vector2(lerpf(h,hp,wf),wf)

## The cirque's lobed outline's radius at angle `phi` round the plateau's
## centre (atan2(v, a)).
func _cq_r(phi: float) -> float:
	return CIRQUE_R*(1.0+CIRQUE_LOBES.x*sin(2.0*phi+_cq_ph.x)+CIRQUE_LOBES.y*sin(3.0*phi+_cq_ph.y)+CIRQUE_LOBES.z*sin(5.0*phi+_cq_ph.z))

## (a, v)'s distance from the tarn's centre over its bowl's lobed outline
## (1 at the bowl's edge).
func _tarn_n(a: float, v: float) -> float:
	var ta := a-_tarn_c.x
	var tv := v-_tarn_c.y
	var tw := facing*ta+side*tv
	return sqrt(ta*ta+tv*tv)/(TARN_BOWL*Ponds.edge_at(pond,atan2(tw.y,tw.x))/pond[2])

## The approach valley at (a, v): Vector2(height over the sea, cut).
func _valley(a: float, v: float, n: float) -> Vector2:
	var vr := v-_valley_mid(a)
	var av := absf(vr)
	var fl: float
	var half: float
	var rough := 0.0
	if a < ICEFALL.x:
		fl = ICEFALL_Y.x-(ICEFALL.x-a)
		half = FLOOR_HALF.x
		rough = 0.6
	elif a < ICEFALL.y:
		var s := (a-ICEFALL.x)/(ICEFALL.y-ICEFALL.x)*ICEFALL_STEPS
		var k := floorf(s)
		var g := (k+smoothstep(0.0,ICEFALL_RISER,s-k))/ICEFALL_STEPS
		fl = lerpf(ICEFALL_Y.x,ICEFALL_Y.y,g)
		half = FLOOR_HALF.x
		rough = 0.5
	elif a < BOULDERS.y:
		var t := (a-BOULDERS.x)/(BOULDERS.y-BOULDERS.x)
		fl = lerpf(BOULDERS_Y.x,BOULDERS_Y.y,t)+_noise.get_noise_2d(a*LUMP_SCALE,av*LUMP_SCALE)*LUMPS
		half = lerpf(FLOOR_HALF.x,FLOOR_HALF.y,smoothstep(0.0,0.3,t))
		rough = 0.35
	elif a < GLACIER.y:
		var t := (a-GLACIER.x)/(GLACIER.y-GLACIER.x)
		fl = lerpf(GLACIER_Y.x,GLACIER_Y.y,pow(t,0.9))
		half = lerpf(FLOOR_HALF.z,FLOOR_HALF.w,t)
		# The boulders' lumps fade out onto the ice.
		fl += _noise.get_noise_2d(a*LUMP_SCALE,av*LUMP_SCALE)*LUMPS*(1.0-smoothstep(0.0,0.06,t))
		rough = 0.35*(1.0-smoothstep(0.0,0.06,t))
	else:
		fl = _fall(GLACIER_Y.y,a-TOE.x,TOE.y-TOE.x,1.0)
		half = FLOOR_HALF.w
		rough = 0.2
	var e := av-half
	var q := av/half
	# The ice: bulged in the middle, crossed by bands of crevasses bowed
	# downstream, on the glacier stretch only.
	var ice := smoothstep(GLACIER.x,GLACIER.x+200.0,a)*(1.0-smoothstep(GLACIER.y-250.0,GLACIER.y,a))
	if ice > 0.0 and e < 0.0:
		fl += ICE_BULGE*(1.0-q*q)*ice
		var ac := a-GLACIER.x+CREV_ARC*(1.0-q*q)
		var band := ac/CREV_BAND-floorf(ac/CREV_BAND)
		var on := smoothstep(0.0,0.06,band)*(1.0-smoothstep(CREV_SHARE-0.06,CREV_SHARE,band))
		if on > 0.0:
			var dc := absf(ac/CREV_SP-floorf(ac/CREV_SP)-0.5)*CREV_SP
			fl -= CREV_DEEP*(1.0-smoothstep(0.0,CREV_W*0.5,dc))*on*ice*(1.0-smoothstep(0.7,0.95,q))
	# The lateral moraines, along the boulders and the glacier.
	var mor := smoothstep(BOULDERS.x+100.0,BOULDERS.x+400.0,a)*(1.0-smoothstep(TOE.x,TOE.x+300.0,a))
	var h: float
	if e <= 0.0:
		h = fl+MOR_UP*mor*pow(maxf(1.0-absf(e-MOR_AT)/MOR_W,0.0),1.6)
	else:
		var es := e-SIDE_GAP*mor
		var hm := MOR_UP*mor*pow(maxf(1.0-absf(e-MOR_AT)/MOR_W,0.0),1.6)
		if es <= SIDE_RUN:
			h = fl+maxf(SIDE_UP*smoothstep(0.0,SIDE_RUN,es),hm)
			rough = lerpf(rough,0.6,smoothstep(0.0,60.0,e))
		else:
			# Inside the horseshoe the side ridges' outer fall stops a little
			# under the floor; out on the glacier, and past the ring, it falls to
			# the land.
			var past := maxf(sqrt((a-O_ALONG)*(a-O_ALONG)+v*v)-RING_R,0.0)
			h = maxf(fl+SIDE_UP-(es-SIDE_RUN)*SIDE_FALL,fl-SIDE_DIP-maxf(0.0,a-SIDE_DIP_TO)*0.5-past*SHELF_FALL)
			rough = 0.6
	var cut_e := e-SIDE_GAP*mor
	var c := (1.0-smoothstep(SIDE_RUN,SIDE_RUN+90.0,cut_e))*(1.0-smoothstep(TOE.x,TOE.x+400.0,a))
	return Vector2(h+n*ROUGH*rough,c)
