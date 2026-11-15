extends Node3D
## The endless land's grass carpet (docs/design/endless-flight/grass-round-handoff.md):
## the aqueduct isle's own carpet (scripts/shared/aqueduct_isle_flora.gd `carpeted`
## and `calm`: KitFlora's Grow, scripts/shared/kit_flora.gd, drawing the
## game's shader grass tufts, scripts/grass_tuft_mesh.gd, and its meadow
## flowers) grown over the streamed land round the eye, a CELL m square at a
## time, and freed as the eye leaves it.
##
## Each cell grows on a WorkerThreadPool task from the land's own field
## (scripts/endless/land_field.gd), with no physics: its probe reads a 1 m
## height grid of the cell made on the task and interpolated as the land's
## finest chunks draw it (scripts/endless/land_stream.gd), so a tuft stands
## on the drawn turf. Grass grows on open turf only: over the beach
## (BEACH_CLEAR m over the sea), on ground no steeper than SLOPE allows, and
## thinning out over the tundra (ALPINE); none on rock, sand, snow or seabed.
## The tufts are drawn, no collision: the meadows land as before. Each tuft
## takes the painted ground's patches under it (scripts/endless/
## endless_patch.gd) as its instance colour, so the carpet sits in its field.
##
## Three layers of cells, in KitFlora's distance rings (Site `lod`, LOD m from
## the eye). The ring distance (shaders/endless_ring.gdshaderinc, `ring_lead`)
## is measured along the ground, so flying low doesn't put the turf under
## the eye in a band; past FLAT_UP m over the ground the eye's height counts,
## RISE times over (from high up each ring is a smaller disc below, and the
## near carpet is gone a little past where the 3D rings had it). It is led out ahead
## along the view (LEAD): a ring R m out stands R(1+LEAD) ahead and
## R(1-LEAD) behind, as many tufts in it as unled; the cells streamed
## follow the same discs, the ones ahead grown first:
##   near  the isle's carpet with its own tuft material (sway, light,
##         colour), drawn as a finer tuft (FINE, FINE_TUFTS of the isle's
##         density) that reads soft from a plane skimming over it, out to
##         LOD.x, each tuft shrinking into the ground at its own distance by
##         LOD.y; its roots take the painted ground's colour, and the paint
##         under it the tufts' own ground (ROOT_PAINT), so tuft and turf are
##         one surface; a cloud's shadow takes their sun as it takes the
##         turf's (CLOUD_SUN); the stray wildflowers and the seed heads with
##         it, thinning out over STRAY_FADE.
##   bloom the drifts' own flowers alone (no grass grown), far out ahead:
##         thinning to FLOWER_KEEP over FLOWER_FADE, heads grown, the last
##         gone by FLOWER_END.
##   far   FAR_TUFTS a square metre of the cheaper tuft (GrassTuft.build_lite),
##         drawn plainly (shaders/endless_tuft_far.gdshader): each comes up
##         at its own distance over LOD.x..LOD.y as the near ring's go at
##         theirs, at FAR_NEAR (wide, tall) where it comes up, growing
##         slowly to FAR_GROW by LOD.z; thinning out over LOD.z..LOD.w. Its
##         tufts in a drift's colour come up as the last drawn flowers go
##         (wash_fade), the colour on their upper blades.
## Past that the painted ground (shaders/endless_ground.gdshader) alone, which
## takes the carpet's tone and grain past LOD.z (told here), so the tufts
## give way to it with no ring.
##
## The main thread only stands the finished batches (KitFlora's tiles, one
## multimesh a tile and part), within STAND_BUDGET ms a frame, a cell over
## as many frames as that takes.
##
## Flags: --no-grass (none; G turns it off and on in flight), --grass=X (the
## carpet's density, a share of the isle's, 1), --grass-range=M (where the
## far ring ends, LOD.w; the rest of the rings scaled with it),
## --grass-lod=x,y,z,w (the four ring distances), --no-flowers,
## --flower-head=X (the heads' growth, FLOWER_HEAD),
## --grass-fine=X (the near ring's FINE tuft at X of the isle's density;
## 0: the isle's own tuft at its own), --grass-patches=X (how much of the
## ground's patches the tufts carry, 1), --grass-set=, --far-set=,
## --ground-set= (name=value: a shader setting, for tuning by hand),
## --flower-drifts=X (how many flower drifts and patches, 1; 0 or
## --no-drifts: round 4's drifts, no wash), --grass-regions=X (how strongly
## the grass's colour regions show, 1; 0 or --no-regions: one palette),
## --grass-areas=X (how strongly the kilometre grass areas show, lush,
## lime, emerald, sage and amber meadows, 1; 0 or --no-grass-areas: none, round 5's),
## --grass-lead=X (LEAD, 0.45), --no-grass-lead (no lead: rings round the
## eye), --grass-flat-up=M (FLAT_UP, 20), --grass-ring=3d (round 5's
## rings: 3D from the eye, no lead), --grass-silver=X (the silvery
## undersides the wind flips, SILVER 0.8), --no-grass-silver,
## --grass-slope=a,b (SLOPE), --grass-cover=old (the bare-patches round's
## masks off: none on turf steeper than OLD_SLOPE or HIGH m over the sea).
## Frame rate (docs/design/endless-flight/frame-rate-handoff.md):
## --grass-cull=0 (no tile culling by the rings: every tile drawn to its
## visibility range, as before), --grass-sub=M (the near grass's tiles, SUB m;
## 24: KitFlora's own), --grass-far-lod=M (the far ring's tiles wholly past M m
## draw the far lod tuft, one triangle a blade, FAR_LOD; 0: off, the lite
## tuft throughout).
## Native placement (docs/design/endless-flight/native-grass-handoff.md): a
## cell's tufts are placed by ZenScapeGrass (native/terrain_kernels/
## grass_cell.h) when the library is built, the same tufts bit for bit;
## --grass-native=0 (or --gdscript-kernels) places them in GDScript.
## --grass-prefetch=S (PREFETCH, 1: the cells round where the eye will be S s
## on asked for too; 0 off).
##
## Look round 5 (docs/design/endless-flight/flowers-colour-handoff.md): the
## grass's colour regions and the flower drifts are endless_patch.gd
## `region` and `bloom`, the same hash as the ground's ep_region and
## ep_bloom, so the tufts' tint, the flowers grown and the painted ground
## agree. Each drift is one kind (its colour), with a few of the meadow's
## own among them; past the flowers' reach the ground (and the far ring's
## tufts, FAR_WASH) take the drift's wash, so it reads from cruise height.

const Field = preload("res://scripts/endless/land_field.gd")
const WorldProfile = preload("res://scripts/endless/world/world_profile.gd")
const Carpet = preload("res://scripts/shared/aqueduct_isle_flora.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Patch = preload("res://scripts/endless/endless_patch.gd")

## A cell's side (m; the land's finest chunk), its height grid's border
## (samples past each edge, for the growers' probes round a root).
const CELL := 64.0
## The band's per-tuft dither reads the regions' weights on this many nodes a
## side over a cell (_cell_mix).
const DITHER_GRID := 3
const PAD := 4
## The rings (m from the eye): the near carpet out to x, thinned by y; the
## far ring grown in over x..y, out to z, thinned by w. A tuft goes over SOFT m.
const LOD := Vector4(16.0,30.0,150.0,230.0)
const SOFT := 8.0
## The far ring: tufts a square metre (a share of the near carpet's 7.8),
## grown this much (wide, tall) over the near ring's band.
const FAR_TUFTS := 1.8
const FAR_GROW := Vector2(2.0,1.8)
## The grass's height, a multiple of the isles' blade (--grass-tall=X; 1.0:
## the old grass). Height only: the near FINE tuft's mesh, the far ring's
## sizes (FAR_NEAR/FAR_GROW tall) and the near sway's arm scale with it.
const TALL := 4.0
## The flowers' stem lift as a share of the grass's growth (x..y, by a hash
## of where each stands): 1.0 stands level with the extra grass.
const FLOWER_LIFT := Vector2(0.8,1.3)
## The flowers' heads: kept their own shape on the lifted stems (the lift
## stretched them tall, so spikes and cups read as painted blades) and drawn
## this much larger, to read among blades TALL times the isles'
## (--flower-head=X; 0 the old stretched heads).
const FLOWER_HEAD := 2.4
var flower_head := FLOWER_HEAD
## A far tuft's size (wide, tall) where it comes up (LOD.x..y): the near
## tuft's look there (as tall; wider, its tufts fewer).
const FAR_NEAR := Vector2(1.5,1.0)
## The rings led ahead along the view: k of the ring's distance (0: none).
## The lead follows the view's level direction at LEAD_RATE (1/s), none
## while looking down steeply (the view's level share LEAD_LEVEL.x..y).
const LEAD := 0.45
const LEAD_RATE := 3.0
const LEAD_LEVEL := Vector2(0.2,0.55)
## The rings are measured along the ground up to this height over it (m);
## past it the height counts, RISE times over (the discs shrink as the eye
## rises: the near tufts gone from FLAT_UP+LOD.y/RISE m up, 39). With
## TUFT_TOP on, its own rate stands in for RISE.
const FLAT_UP := 20.0
const RISE := 1.6
## The height over the ground (m) above which no tuft grows (--tuft-top=H; 0
## off): the rise runs at the rate that closes the far ring's whole reach
## (LOD.w) by then, LOD.w/(TUFT_TOP-FLAT_UP) (1.05 at 240: the near tufts gone
## by about 48 m up, the far ones thinning from about 160), so tufts thin and
## pull in with altitude and the painted ground (endless_ground.gdshader)
## carries the look from there.
const TUFT_TOP := 240.0
## Wildflower drifts in the near carpet (KitFlora Site `flower_drift`): where
## a value noise of DRIFT_SCALE m rises from DRIFT.x to .y, the flowers are
## kept up to DRIFT.z times as often (1 elsewhere), so the meadows have
## patches thick with flowers among the sparse strays.
const DRIFT_SCALE := 55.0
const DRIFT := Vector3(0.68,0.82,6.0)
## Round 5's drifts (endless_patch.gd `bloom`): the flowers kept up to
## BLOOM_PEAK times as often at a drift's heart, its own kind all but
## BLOOM_COMPANION of them (the meadow's own there), from BLOOM_KIND of its
## weight in; up to FAR_WASH of the far ring's tufts are in its colour
## (the ground's painted heads, `bloom_wash`, past the flowers).
const BLOOM_PEAK := 16.0
## Flower candidates a square metre with them on (KitFlora Site
## `flower_tries`; its own FLOWER_TRIES is 2.2): thicker drifts, more strays.
const BLOOM_TRIES := 3.4
const BLOOM_COMPANION := 0.12
const BLOOM_KIND := 0.12
const FAR_WASH := 0.35
## The silvery undersides the wind flips into view (shaders/
## grass_silver.gdshaderinc): their strength (0: off), on the near tufts,
## the far ring and the paint alike. With them on, the bowed blades' old
## paling (the tufts' `grass_wave_sheen`, the paint's `wind_sheen`) is cut to
## these, so the gusts don't brighten twice. --grass-silver=S, --no-grass-silver.
const SILVER := 0.8
## The drive (grass_silver zs_silver_drive) over which the underside
## turns into view, and how much brighter it reads on the near tufts, the
## far ones and the paint (each tier's own tone, so they meet as one).
const SILVER_BOW := Vector2(0.25,1.25)
const SILVER_LIFT := Vector3(1.9,1.5,1.25)
## How much of each tier's own colour the underside keeps (the paint more,
## or its bright turf goes to frost).
const SILVER_KEEP := Vector3(0.45,0.55,0.7)
const SILVER_SHEEN := 0.2
const SILVER_WIND_SHEEN := 0.45
var silver := SILVER
## How many drifts (--flower-drifts=), how strong the regions
## (--grass-regions=).
var drifts := 1.0
var regions := 1.0
## How strong the kilometre grass areas (--grass-areas=; EndlessPatch.area).
var areas := 1.0
## The far ring's colours at the root and the tip (linear; endless_tuft_far
## `root_colour`, `tip_colour`), matched to the near ring's tufts.
const FAR_ROOT := Vector3(0.093,0.27,0.13)
const FAR_TIP := Vector3(0.28,0.55,0.22)
## The drifts' flowers (those a drift gave its kind: the bloom layer, grown
## apart from the near carpet, flowers alone, so they reach far ahead with no
## grass grown under them): all of them out to FLOWER_FADE.x ring m; from there
## to .y each kind keeps down to FLOWER_KEEP of its plants, the kept heads
## growing by keep^-FLOWER_GROW so a drift keeps its cover; the kept ones go
## between .y and FLOWER_END, each at its own distance. Each comes and goes by
## growing up out of the grass (or sinking into it) over FLOWER_SOFT of the
## share (reference_surface `flower_far`, `flower_end`). Looking level, the
## lead 0.45 puts a ring R m out 1.45 R ahead: a drift ahead stands from about
## 145 m out, FLOWER_KEEP of it from 116 m, all of it by 58 (Boost, 57 m/s:
## two seconds out). Past FLOWER_SWAP each is its far plant (below).
## The cost is the GPU's, and it follows the reach, not the plants' triangles
## or the heads' size: on the PC's low meadow FLOWER_END 120 cost 0.2 ms more
## than 80 with the far plants, 100 about 0.1 (handoff-polish-flower-reach.md).
## --flower-fade=a,b[,end[,keep]] (two: every flower gone over a..b, the old
## shape); --flower-fade=old: the round before this (every flower in the near
## carpet, gone over STRAY_FADE). --flower-grow=X: FLOWER_GROW.
const FLOWER_FADE := Vector2(40.0,80.0)
const FLOWER_KEEP := 0.4
const FLOWER_GROW := 0.5
var flower_grow := FLOWER_GROW
const FLOWER_END := 100.0
const FLOWER_SOFT := 0.2
var flower_fade := FLOWER_FADE
var flower_keep := FLOWER_KEEP
var flower_end := FLOWER_END
## Whether the drifts' flowers grow in the bloom layer (off: --flower-fade=old,
## --no-flowers or no drifts).
var bloom_on := true
## The other flowers (strays, a drift's companions) and the seed heads, in the
## near carpet as before: thinned out between these distances (m), each at
## its own.
const STRAY_FADE := Vector2(22.0,55.0)
## The flowers' leaves and buds (reference_surface `flower_lod`) shrink
## away between these ring distances (m).
const FLOWER_DETAIL := Vector2(14.0,30.0)
## The drifts' far plants (MeadowFlowerMesh build_far: the same heads and
## colours in a tenth of the triangles): each drift flower is the plant out
## to FLOWER_SWAP.x ring m, give or take half of .y (each at its own
## distance), and its far plant past it (reference_surface `flower_swap`).
## The plant's batches are FLOWER_SWAP_SUB m squares, so few are drawn past
## the swap; the far plant's are the cell's, drawn out to flower_end. The swap
## ends before FLOWER_FADE.x, where every plant still stands whole, and starts
## where its leaves and buds are all but gone (FLOWER_DETAIL), so the two meet
## with nothing to fade. Looking level the plants stand to about 45 m ahead.
## --flower-swap=D,band[,sub]; --flower-swap=0: the plant all the way (the
## round before this); --flower-far-stems=0: far plants without stems.
const FLOWER_SWAP := Vector2(30.0,10.0)
const FLOWER_SWAP_SUB := 16.0
var flower_swap := FLOWER_SWAP
var flower_swap_sub := FLOWER_SWAP_SUB
## Whether the far plants are parted into the kept share and the rest
## (`_rank_split`), as the plants are without the swap (--flower-cheap-split=1):
## off, one batch a kind a cell (fewer draws for a few more vertices).
var flower_cheap_split := false
const MeadowFlowers = preload("res://scripts/meadow_flower_mesh.gd")
## A cell is freed this far (m) past where it is wanted.
const KEEP := 24.0
## Open turf: from this far over the sea (m), thin at first and full
## BEACH_RAMP higher, so the tufts reach down to the sand's own edge (the
## ground's, about 1.5 m over the sea, swung by its noise) with a few on
## the sand: at 2.55 a band of bare painted turf lay between. On ground whose normal's up is over SLOPE.x (full past .y), up to
## the rock's edge (the ground's `rock_up`, 0.80), thinning to none as the
## paint turns to tundra (its `alpine`, from ALPINE.x to .y), so every slope
## and hill the paint draws as turf carries the carpet.
const BEACH_CLEAR := 1.3
const BEACH_RAMP := 0.9
const SLOPE := Vector2(0.83,0.88)
## Under this up the rock's ragged edge is read (it swings the edge 0.13 at
## most, so past this it never reaches SLOPE.x).
const ROCK_NEAR := 0.95
const ALPINE := Vector2(0.3,0.7)
## Over the sea (m) past which ALPINE leaves no tuft anywhere (the paint's
## alpine reaches ALPINE.y by then whatever its broad patch).
const ALPINE_TOP := 84.0
## The masks before the bare-patches round (--grass-cover=old): none on
## turf steeper than OLD_SLOPE, none HIGH.x..HIGH.y m over the sea, which
## left bare, dark hillsides and hollow sides in the carpet.
const OLD_SLOPE := Vector2(0.905,0.95)
const HIGH := Vector2(36.0,58.0)
## The alpine tufts (native placement, ZenScapeGrass 3): short, sparser tufts
## on the high turf where the carpet's thin out (ALPINE's complement), so the
## high ground is grass too and not bare paint. ALP_SHARE of the carpet's
## tufts a square metre, ALP_TALL their height and ALP_WIDE their spread (of a
## carpet tuft's), on ground whose up is over ALP_SLOPE.x (full past .y: short
## of the high ground's broken rock), thinning out under the snow: from
## ALP_TOP.x to .y m under the snow line, on the Peak (its zone) from
## ALP_ZONE_TOP.x to .y m over the sea (its granite from 170). None on the
## Peak's ice, rubble or scree, nor on a proud crown's snow cap.
## --grass-alpine=X sets the share (0 none); the GDScript placement grows none.
const ALP_SHARE := 0.5
const ALP_TALL := 0.5
## Their colour over the carpet tuft's (linear; the ground's patches under
## them as on the carpet's): toward the paint's dry olive up there.
const ALP_TONE := Color(0.62,0.76,0.6)
const ALP_WIDE := 1.1
const ALP_SLOPE := Vector2(0.84,0.92)
const ALP_TOP := Vector2(46.0,30.0)
const ALP_ZONE_TOP := Vector2(140.0,170.0)
var alp_share := ALP_SHARE
## (--grass-alpine-tall=X, --grass-alpine-tone=r,g,b: by hand.)
var alp_tall := ALP_TALL
var alp_tone := ALP_TONE
## The far ring's alpine tufts, a share of ALP_SHARE (--grass-alpine-far=X).
const ALP_FAR := 0.6
var alp_far := ALP_FAR
## Whether the alpine tufts grow (the native placement takes them).
var alp_on := false
## The masks as flown: SLOPE (--grass-slope=a,b), and ALPINE or (zero, old)
## HIGH.
var slope := SLOPE
var alpine := ALPINE
## The tufts' roots sink this much (m), so none stands on air where a
## coarser chunk draws the turf a hair lower.
const SINK := 0.04
## The ground's patches are read onto the tufts off a grid this fine (m),
## and the tufts' colour scaled by TUFT_TONE over them.
const TINT_STEP := 2.0
const TUFT_TONE := Color(1.0,1.0,1.0)
## The painted grass's tone past the tufts (linear, over its own colour),
## as the carpet reads from afar: seen from above, and at a glance.
const TONE_TOP := Vector3(0.76,0.82,0.86)
const TONE_LOW := Vector3(0.56,0.66,0.68)
## Cells growing at once (the near layer's first), ms a frame for standing
## their batches (a cell's batches stood over as many frames as that takes).
const MAX_TASKS := 8
const STAND_BUDGET := 1.5
## Prefetch (`lead_with`): each layer's cells are also asked for round where
## the eye will be PREFETCH s on along the flight's level velocity, at most
## PREFETCH_MOST m ahead, so at boost the rings ahead are grown before
## they're in view (--grass-prefetch=S; 0 off).
const PREFETCH := 1.0
const PREFETCH_MOST := 64.0
## How far the near tufts' roots take the painted ground's colour under them
## (reference_surface `grass_root_paint`; 0: the isles' ground_look colour),
## the paint under them taking the tufts' own ground (endless_ground
## `carpet_near`).
const ROOT_PAINT := 1.0
## The share of the sun a cloud's shadow takes off the tufts and flowers, the
## sky's light left (reference_surface `cloud_sun_shade`, endless_tuft_far
## `cloud_shade`), as the painted ground's (endless_ground `cloud_shade`), so
## a shadowed meadow goes soft as one surface.
const CLOUD_SUN := 0.85
## The near ring's tuft (FINE, --grass-fine=0 for the isles' own): finer than
## the isles' (scripts/grass_tuft_mesh.gd, made to read from 20-26 m, whose
## ten broad blades read as leafy clumps from a plane skimming at 3-10 m):
## more, narrower blades of one bend each, the same height, root and lean,
## so the same material lights it alike, in fewer triangles (54 against 80).
## blades, rows up the blade, their taper, the width (a share of the isles'),
## the satellites [blades, distance, size].
const FINE := {"blades":12,"rows":[0.0,0.6],"taper":[1.0,0.55],"width":0.6,"satellites":[[3,0.27,0.62],[3,0.24,0.55]]}
## The near ring's tufts a square metre with the FINE tuft, a share of
## the isle's (its blades are narrower: more of them cover the turf alike).
const FINE_TUFTS := 1.2
const GrassTuft = preload("res://scripts/grass_tuft_mesh.gd")
## Frame rate: each frame a tile is drawn only while the rings could show a
## tuft of it (its roots' box meets the ring's disc, CULL_SLACK m to spare; a
## tile past them runs every tuft's vertices at zero size). The near grass in
## SUB m tiles, so the tiles at the ring's edge are small. Past FAR_LOD m the
## far ring's tiles draw a tuft of one triangle a blade (GrassTuft
## build_far), switching back FAR_LOD_BACK m nearer; nearer, each tuft eases
## into that shape over FAR_MORPH m, done FAR_LOD_SAFE m short of FAR_LOD
## (endless_tuft_far `far_morph`), so the swap changes no pixel.
const CULL_SLACK := 2.0
const CULL_SPREAD := 4
const CULL_SPREAD_NEAR := 2
const SUB := 8.0
const FAR_LOD := 100.0
const FAR_LOD_BACK := 6.0
const FAR_MORPH := 30.0
const FAR_LOD_SAFE := 5.0
## The second far lod: the far ring's tiles wholly past FAR_LOD2 m draw the
## sparse tuft (GrassTuft build_sparse: 5 triangles for the far lod's 11, out
## where a tuft is a few pixels and the ring's ground is widest), each tuft
## easing into it over FAR_MORPH2 m as into the first (endless_tuft_far
## `far_morph2`). --grass-far-lod2=M (0: off).
const FAR_LOD2 := 125.0
const FAR_MORPH2 := 25.0
var far_lod2 := FAR_LOD2
var cull := true
var sub := SUB
var prefetch := PREFETCH
## The prefetch's offset now (world, level; `lead_with`), and the climb or
## descent over it (m: a descent asks for the near ring before it shows).
var ahead := Vector3.ZERO
var ahead_y := 0.0
## The cell being stood over several frames: [result, node, groups, count,
## next part], or empty.
var _standing: Array = []
var far_lod := FAR_LOD
var _far_meshes := {}
var _cull_frame := 0
## The tiles' pass in C++ (ZenScapeGrass `cull_tiles`) where the library has
## it, looked for once; null: `cull_tiles` here (--grass-cull-native=0, or
## --grass-native=0, --gdscript-kernels).
var _cull_native: Object = null
var _cull_native_looked := false

var seed := 0
var enabled := true
## The lead's share (--grass-lead=, --no-grass-lead), the height the rings
## stay flat to (--grass-flat-up=), round 5's 3D rings (--grass-ring=3d).
var lead := LEAD
var flat_up := FLAT_UP
var tuft_top := TUFT_TOP
var rings_3d := false
## The lead now (world x, z; damped), the eye's height past flat_up, as
## the shaders were told (`ring_lead`).
var lead_now := Vector2.ZERO
var rise := 0.0
var _lead_planned := Vector2.ZERO
var _ring_mats := {}
var share := 1.0
var lod := LOD
## The wildflowers in the near carpet (--no-flowers leaves them out).
var flowers := true
## How much of the painted ground's patches the tufts carry (--grass-patches=X).
var patches := 1.0
## The near ring draws the FINE tuft (--grass-fine=0: the isles' own).
var fine := true
var _fine_meshes := {}
var _fine_share := FINE_TUFTS
var tall := TALL
## Cells grown and freed, their grow times, the slowest stand, for the HUD
## and drivers.
var stats := {"grown":0,"freed":0,"grow_ms":0.0,"slowest_grow_ms":0.0,"slowest_stand_ms":0.0}
var field: RefCounted
## The world profile (scripts/endless/world/world_profile.gd): its flora at
## setup, and per cell whether the grass grows there (`layer_at`, asked only
## in a world of regions).
var world: RefCounted
## The land's ground (shaders/endless_ground.gdshader), told where the
## tufts grow and how far they reach, so its paint takes over past them.
var ground: ShaderMaterial
## Shader settings asked for on the command line, for tuning by hand:
## --grass-set=name=value (the near tufts' material, reference_surface),
## --far-set= (the far ring's, endless_tuft_far), --ground-set= (the
## painted ground's, endless_ground); a value is a number or numbers
## joined by commas (a vector), each flag repeatable.
var _sets := {"grass":{},"far":{},"ground":{}}

## One layer of cells: how far (3D, m) it is wanted, its grower's settings
## and its cells.
class Layer extends RefCounted:
	var far := false
	## The bloom layer: the drifts' flowers alone (FLOWER_FADE).
	var bloom := false
	var reach := 0.0
	var site := {}
	var share := 0.0
	var cells := {}       # Vector2i -> Node3D
	var pending := {}     # Vector2i -> task id
	var wanted := {}
	var queue: Array = []
	## The native placement (ZenScapeGrass, native/terrain_kernels/
	## grass_cell.h) set up for this layer's site, or null: GDScript.
	var native: Object
	## A world of regions: each region's [site, native, grows grass, group]
	## by region index (its tufts' share, flowers and flower height; the
	## group: the first region with the same carpet); empty in a one-profile world.
	var regional: Array = []

var near_layer := Layer.new()
var far_layer := Layer.new()
var bloom_layer := Layer.new()
## The layers grown (the bloom layer while bloom_on), in the order their
## cells are asked for: near, bloom, far.
var layers: Array[Layer] = [near_layer,far_layer]
var _done: Array = []
var _lock := Mutex.new()
var _quit := false
var _eye := Vector3.ZERO
var _planned_at := Vector3.INF
var _calmed := {}
var _fars := {}
var _since_plan := 0

## The kilometre grass areas (EndlessPatch.area), before any worker reads
## them: the wilderness's alone. None in the Amberlands' own world, and in
## the doors world they fade out short of the border band half way to the
## Amberlands' side (x = its offset / 2). A native library older than 5
## can't tint its tufts by them, so then there are none on the ground either
## (the near and far rings and the paint must agree).
func _set_areas() -> void:
	Patch.area_amount = areas
	Patch.area_edge = Vector2.ZERO
	if world != null and world.id == "amberlands": Patch.area_amount = 0.0
	elif world != null and world.is_doors() and "offset" in world:
		var half: float = (world.offset as Vector2).x*0.5
		Patch.area_edge = Vector2(half-6000.0,half-3000.0)
	if Patch.area_amount > 0.0 and native_wanted() and int((ClassDB.instantiate(NATIVE_CLASS) as Object).version()) < 5:
		push_warning("EndlessGrass: the native kernels predate the grass areas (ZenScapeGrass version < 5); areas off. Rebuild the kernels (tools/build_native_kernels.py).")
		Patch.area_amount = 0.0

## Whether the grass is asked for (the world's layer, and not --no-grass).
static func wanted() -> bool:
	return bool(WorldProfile.current().layer("grass",true)) and not "--no-grass" in LaunchArgs.user_args()

func setup(land_seed: int, ground_material: ShaderMaterial = null) -> void:
	name = "Grass"
	seed = land_seed
	ground = ground_material
	field = Field.new(seed)
	# The world's flora first (its tufts' share, its flowers), the flags over it.
	world = field.world
	var stock := {"share":share,"tall":tall,"flowers":flowers}
	share = float(world.flora_value("grass",share))
	flowers = bool(world.flora_value("flowers",flowers))
	tall = clampf(float(world.flora_value("grass_tall",tall)),0.25,6.0)
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--grass="): share = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--grass-range="):
			var w := maxf(a.get_slice("=",1).to_float(),20.0)
			lod = LOD*(w/LOD.w)
		elif a == "--no-flowers": flowers = false
		elif a.begins_with("--grass-fine="):
			fine = a.get_slice("=",1) != "0"
			if fine and a.get_slice("=",1).to_float() > 0.0: _fine_share = a.get_slice("=",1).to_float()
		elif a.begins_with("--grass-tall="): tall = clampf(a.get_slice("=",1).to_float(),0.25,6.0)
		elif a == "--grass-cover=old":
			slope = OLD_SLOPE
			alpine = Vector2.ZERO
		elif a.begins_with("--grass-slope="):
			var sp := a.get_slice("=",1).split(",")
			if sp.size() >= 2: slope = Vector2(float(sp[0]),float(sp[1]))
		elif a.begins_with("--grass-patches="): patches = clampf(a.get_slice("=",1).to_float(),0.0,1.0)
		elif a.begins_with("--flower-drifts="): drifts = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--no-drifts": drifts = 0.0
		elif a.begins_with("--flower-head="): flower_head = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--flower-fade=old":
			bloom_on = false
			flower_fade = STRAY_FADE
			flower_end = STRAY_FADE.y
			flower_keep = 0.0
		elif a.begins_with("--flower-fade="):
			var ff := a.get_slice("=",1).split_floats(",")
			if ff.size() >= 2:
				flower_fade = Vector2(ff[0],maxf(ff[1],ff[0]+1.0))
				flower_end = maxf(ff[2],flower_fade.y) if ff.size() >= 3 else flower_fade.y
				flower_keep = clampf(ff[3],0.05,1.0) if ff.size() >= 4 else (FLOWER_KEEP if ff.size() >= 3 else 0.0)
		elif a.begins_with("--flower-swap="):
			var fs := a.get_slice("=",1).split_floats(",")
			flower_swap = Vector2(fs[0],fs[1] if fs.size() >= 2 else FLOWER_SWAP.y)
			if fs.size() >= 3: flower_swap_sub = clampf(fs[2],4.0,CELL)
		elif a.begins_with("--flower-cheap-split="): flower_cheap_split = a.get_slice("=",1) != "0"
		elif a == "--flower-far-stems=0": MeadowFlowers.far_stems = false
		elif a.begins_with("--flower-grow="): flower_grow = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--grass-regions="): regions = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--no-regions": regions = 0.0
		elif a.begins_with("--grass-areas="): areas = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--no-grass-areas": areas = 0.0
		elif a.begins_with("--grass-silver="): silver = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--no-grass-silver": silver = 0.0
		elif a.begins_with("--grass-lead="): lead = clampf(a.get_slice("=",1).to_float(),0.0,0.85)
		elif a == "--no-grass-lead": lead = 0.0
		elif a.begins_with("--grass-flat-up="): flat_up = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--tuft-top="): tuft_top = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--grass-ring=3d": rings_3d = true
		elif a.begins_with("--grass-set=") or a.begins_with("--far-set=") or a.begins_with("--ground-set="):
			var which := a.get_slice("-",2).get_slice("-",0)
			var kv := a.substr(a.find("=")+1)
			if kv.contains("="): _sets[which][kv.get_slice("=",0)] = _value(kv.get_slice("=",1))
		elif a.begins_with("--grass-lod="):
			var p := a.get_slice("=",1).split(",")
			if p.size() >= 4: lod = Vector4(float(p[0]),float(p[1]),float(p[2]),float(p[3]))
		elif a.begins_with("--grass-cull="): cull = a.get_slice("=",1) != "0"
		elif a.begins_with("--grass-sub="): sub = clampf(a.get_slice("=",1).to_float(),0.0,64.0)
		elif a.begins_with("--grass-far-lod="): far_lod = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--grass-far-lod2="): far_lod2 = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--grass-prefetch="): prefetch = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--grass-alpine="): alp_share = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--grass-alpine-far="): alp_far = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--grass-alpine-tall="): alp_tall = clampf(a.get_slice("=",1).to_float(),0.1,2.0)
		elif a.begins_with("--grass-alpine-tone="):
			var t := a.get_slice("=",1).split_floats(",")
			if t.size() >= 3: alp_tone = Color(t[0],t[1],t[2])
	# The regions and drifts, set before any worker reads them.
	Patch.offset = Patch.seed_offset(seed)
	Patch.region_amount = regions
	_set_areas()
	Patch.bloom_amount = drifts if flowers else 0.0
	# The isle's carpet settings, read here once (the workers copy them).
	var s := KitFlora.Site.new()
	Carpet.carpeted(s)
	var site := {"carpet":s.carpet,"tufts":s.tufts*share,"grass_range":lod.w,"tuft_bump":s.tuft_bump,"shag":s.shag,
		"variety":s.variety,"contact":s.contact,"height_field":s.height_field,"tilt":s.tilt}
	# A native library older than 6 can't keep the drifts' flowers apart (the
	# near carpet would grow them too): then every flower stays in the near
	# carpet, as the round before this.
	if bloom_on and native_wanted() and int((ClassDB.instantiate(NATIVE_CLASS) as Object).version()) < 6:
		push_warning("EndlessGrass: the native kernels predate flower_part (ZenScapeGrass version < 6); the flowers reach as before. Rebuild the kernels (tools/build_native_kernels.py).")
		bloom_on = false
	bloom_on = bloom_on and flowers and Patch.bloom_amount > 0.0
	if not bloom_on:
		flower_fade = STRAY_FADE
		flower_end = STRAY_FADE.y
	if flower_end <= flower_fade.y: flower_keep = 0.0
	# The swap ends where every plant still stands whole (see FLOWER_SWAP).
	if flower_swap.x > 0.0:
		flower_swap.x = minf(flower_swap.x,flower_fade.x-flower_swap.y*0.5)
		if not bloom_on or flower_swap.x <= 0.0: flower_swap = Vector2.ZERO
	near_layer.site = site
	near_layer.reach = maxf(lod.y,STRAY_FADE.y)
	near_layer.share = 0.0
	near_layer.site.flowers = flowers
	# (The drifts' own flowers are the bloom layer's.)
	near_layer.site.flower_part = 2 if bloom_on else 0
	near_layer.site.patches = patches
	near_layer.site.flower_tall = tall
	near_layer.site.slope = slope
	near_layer.site.alpine = alpine
	near_layer.site.sub = sub if cull and sub < KitFlora.TILE else 0.0
	far_layer.far = true
	far_layer.site = site.duplicate()
	far_layer.site.slope = slope
	far_layer.site.alpine = alpine
	far_layer.site.tufts = FAR_TUFTS*share
	# No wild grass or tussocks a few pixels across (their probes cost the
	# most of a cell's grow).
	far_layer.site.shag = 0.0
	far_layer.site.variety = false
	far_layer.reach = lod.w
	if fine: near_layer.site.tufts = s.tufts*share*_fine_share
	far_layer.share = 1.0
	far_layer.site.erase("flower_part")
	if bloom_on:
		bloom_layer.bloom = true
		bloom_layer.site = _bloom_site(near_layer.site)
		bloom_layer.reach = flower_end
		bloom_layer.share = 0.0
		layers = [near_layer,bloom_layer,far_layer]
	# The alpine tufts: on the native placement only (ZenScapeGrass 3).
	alp_on = alp_share > 0.0 and native_wanted() and int((ClassDB.instantiate(NATIVE_CLASS) as Object).version()) >= 3
	if alp_on:
		var alp := _alp_config()
		near_layer.site.alp = alp
		var far_alp := alp.duplicate()
		far_alp.share = alp_share*alp_far
		far_layer.site.alp = far_alp
	if not world.uniform:
		# Each region's carpet: its tufts' share, flowers and flower height, the flags over each.
		for p: RefCounted in world.regions:
			var rf := _flora_of(p,stock)
			var near_r: Dictionary = near_layer.site.duplicate()
			near_r.tufts = s.tufts*float(rf.share)*(_fine_share if fine else 1.0)
			near_r.flowers = rf.flowers
			near_r.flower_tall = rf.tall
			var far_r: Dictionary = far_layer.site.duplicate()
			far_r.tufts = FAR_TUFTS*float(rf.share)
			# [site, native, grows grass, group]: the group is the first region
			# with the same carpet (a band cell between two of one group grows once).
			var lv: Variant = p.layers.get("grass",true)
			var on: bool = lv if lv is bool else float(lv) > 0.0
			var pairs: Array = [[near_layer,near_r],[far_layer,far_r]]
			if bloom_on: pairs.append([bloom_layer,_bloom_site(near_r)])
			for pair: Array in pairs:
				var layer: Layer = pair[0]
				var group := layer.regional.size()
				for q in layer.regional.size():
					if layer.regional[q][2] == on and (layer.regional[q][0] as Dictionary).recursive_equal(pair[1],2):
						group = int(layer.regional[q][3])
						break
				layer.regional.append([pair[1],null,on,group])
	# The plant catalog made on the main thread before any worker reads it.
	SkyIslets.catalog()
	if ground != null:
		ground.set_shader_parameter("turf_beach",Vector2(BEACH_CLEAR,BEACH_CLEAR+BEACH_RAMP))
		ground.set_shader_parameter("turf_slope",slope)
		ground.set_shader_parameter("turf_high",HIGH)
		ground.set_shader_parameter("turf_alpine",alpine)
		# Where the alpine tufts stand (none: the paint as before).
		if alp_on:
			var alp: Dictionary = near_layer.site.alp
			ground.set_shader_parameter("turf_alp",Vector4(ALP_SLOPE.x,ALP_SLOPE.y,1.0,0.0))
			ground.set_shader_parameter("turf_alp_top",Vector4(alp.top.x,alp.top.y,ALP_ZONE_TOP.x,ALP_ZONE_TOP.y))
		ground.set_shader_parameter("carpet_tone_top",TONE_TOP)
		ground.set_shader_parameter("carpet_tone_low",TONE_LOW)
		ground.set_shader_parameter("region_offset",Patch.offset)
		ground.set_shader_parameter("region_amount",Patch.region_amount)
		ground.set_shader_parameter("area_amount",Patch.area_amount)
		ground.set_shader_parameter("area_edge",Patch.area_edge)
		ground.set_shader_parameter("bloom_amount",Patch.bloom_amount)
		ground.set_shader_parameter("bloom_fade",wash_fade())
		_silver(ground,"wind_sheen",SILVER_WIND_SHEEN)
		GrassSheen.apply(ground)
		world.apply_ground(ground)
		for k: String in _sets.ground: ground.set_shader_parameter(k,_sets.ground[k])
	if rings_3d: lead = 0.0
	if ground != null: _ring_mats[ground.get_instance_id()] = ground
	_reach()
	if warm: _warm()
	if native_wanted():
		for layer: Layer in layers:
			layer.native = ClassDB.instantiate(NATIVE_CLASS)
			layer.native.configure(native_config(layer.site,layer.share,lod))
			for one: Array in layer.regional:
				one[1] = ClassDB.instantiate(NATIVE_CLASS)
				(one[1] as Object).configure(native_config(one[0],layer.share,lod))

## Where the drifts' painted heads take over from their drawn flowers (ring
## m; the ground's `bloom_fade`, the far tufts' `wash_in`): from where the
## flowers start thinning to where the last go, so the drift's colour builds
## under them as they thin (a thin kind, lupine, reads by its wash from up high).
func wash_fade() -> Vector2:
	return Vector2(flower_fade.x,flower_end) if flower_end > flower_fade.y else flower_fade

## The bloom layer's settings from a near carpet's (`near`): its flowers
## alone, only the drifts' (KitFlora Site `flower_part` 1), no tufts.
static func _bloom_site(near: Dictionary) -> Dictionary:
	var b := near.duplicate()
	b.tufts = 0.0
	b.shag = 0.0
	b.variety = false
	b.sub = 0.0
	b.flower_part = 1
	b.erase("alp")
	return b

## A profile's carpet {share, tall, flowers} from `stock` (the engine's), the
## flags over it (each region's, in a world of regions).
static func _flora_of(p: RefCounted, stock: Dictionary) -> Dictionary:
	var out := {"share":float(p.flora_value("grass",stock.share)),"flowers":bool(p.flora_value("flowers",stock.flowers)),
		"tall":clampf(float(p.flora_value("grass_tall",stock.tall)),0.25,6.0)}
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--grass="): out.share = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--no-flowers": out.flowers = false
		elif a.begins_with("--grass-tall="): out.tall = clampf(a.get_slice("=",1).to_float(),0.25,6.0)
	return out

## How a cell grows in a world of regions: {"groups": [[site, native, grows
## grass]...], "w": the groups' land weights on a DITHER_GRID x DITHER_GRID
## grid over the cell (node-major, a weight per group)}. A cell wholly in one
## region, or whose regions all grow the same carpet (one group), has one
## group; in the band each tuft and flower is kept from the group a hash at
## its root picks by the weights there (_dither), so the carpet changes
## tuft by tuft over the band, never by cell.
func _cell_mix(layer: Layer, key: Vector2i) -> Dictionary:
	var x0 := key.x*CELL
	var z0 := key.y*CELL
	var step := CELL/(DITHER_GRID-1)
	var nodes: Array = []
	var order: Array = []
	for j in DITHER_GRID:
		for i in DITHER_GRID:
			var w: PackedFloat32Array = field.region_weights(x0+i*step,z0+j*step)
			nodes.append(w)
			for r in w.size():
				if w[r] <= 0.0: continue
				var gp := int(layer.regional[r][3])
				if not gp in order: order.append(gp)
	if order.size() <= 1:
		var one: Array = layer.regional[order[0] if not order.is_empty() else _cell_region(key)]
		return {"groups":[[one[0],one[1],one[2]]],"w":PackedFloat32Array()}
	var groups: Array = []
	for gp: int in order:
		var one: Array = layer.regional[gp]
		groups.append([one[0],one[1],one[2]])
	var ws := PackedFloat32Array()
	ws.resize(DITHER_GRID*DITHER_GRID*order.size())
	for n in nodes.size():
		var w: PackedFloat32Array = nodes[n]
		for r in w.size():
			if w[r] > 0.0: ws[n*order.size()+order.find(int(layer.regional[r][3]))] += w[r]
	return {"groups":groups,"w":ws}

## The region a cell wholly in one region grows as (by a hash against the
## weights at its middle; a band cell is dithered per tuft, _cell_mix).
func _cell_region(key: Vector2i) -> int:
	var u := float(hash([seed,key.x,key.y,"grass region"]) & 0xffffff)/16777216.0
	return field.region_pick((key.x+0.5)*CELL,(key.y+0.5)*CELL,u)

## The parts of group `g`'s grow kept where the dither picks g: a hash of each
## instance's root against the groups' weights there (`ws`, _cell_mix's
## grid, bilinear: the land's weights are bilinear over its 64 m lattice, so
## this is the land's own weight). Worker-safe.
static func _dither(parts: Array, key: Vector2i, ws: PackedFloat32Array, count: int, g: int) -> Array:
	var x0 := key.x*CELL
	var z0 := key.y*CELL
	var step := CELL/(DITHER_GRID-1)
	var out := []
	for part: Dictionary in parts:
		var buffer: PackedFloat32Array = part.buffer
		var kept := PackedFloat32Array()
		for k in range(0,buffer.size(),16):
			var x := buffer[k+3]
			var z := buffer[k+11]
			var u := clampf((x-x0)/step,0.0,DITHER_GRID-1.001)
			var v := clampf((z-z0)/step,0.0,DITHER_GRID-1.001)
			var i := int(u)
			var j := int(v)
			var fu := u-i
			var fv := v-j
			var n00 := (j*DITHER_GRID+i)*count
			var n10 := n00+count
			var n01 := n00+DITHER_GRID*count
			var n11 := n01+count
			var d := float(hash(Vector3i(roundi(x*113.0),roundi(z*113.0),7919)) & 0xffffff)/16777216.0
			var acc := 0.0
			var pick := count-1
			var total := 0.0
			for q in count: total += lerpf(lerpf(ws[n00+q],ws[n10+q],fu),lerpf(ws[n01+q],ws[n11+q],fu),fv)
			d *= total
			for q in count:
				acc += lerpf(lerpf(ws[n00+q],ws[n10+q],fu),lerpf(ws[n01+q],ws[n11+q],fu),fv)
				if d < acc:
					pick = q
					break
			if pick == g: kept.append_array(buffer.slice(k,k+16))
		if kept.is_empty(): continue
		var p := part.duplicate()
		p.buffer = kept
		p.count = kept.size()/16
		p.box = _roots_box(kept)
		out.append(p)
	return out

## Whether the native placement takes a band cell's dither (ZenScapeGrass
## version 2; an older library is dithered here, `_dither`).
static func _native_dithers(native: Object) -> bool:
	return int(native.version()) >= 2

## The drifts' flowers parted by a hash of where each stands: the `keep`
## share of them kept out to flower_end ("rest" false) and the rest, gone by
## about flower_fade.y ("rest" true), each its own batch, so the far band
## draws only the kept ones (the material's `flower_rank` puts each set's
## shader rank in its own share, _bloom_material).
static func _rank_split(parts: Array, keep: float) -> Array:
	var out := []
	for part: Dictionary in parts:
		var src: PackedFloat32Array = part.buffer
		var kept := PackedFloat32Array()
		var rest := PackedFloat32Array()
		for k in range(0,src.size(),16):
			var h := float(hash(Vector2i(roundi(src[k+3]*13.0),roundi(src[k+11]*13.0)))%10007)/10007.0
			if h < keep: kept.append_array(src.slice(k,k+16))
			else: rest.append_array(src.slice(k,k+16))
		var bufs := [kept,rest]
		for r in 2:
			var b: PackedFloat32Array = bufs[r]
			if b.is_empty(): continue
			var p := part.duplicate()
			p.buffer = b
			p.count = b.size()/16
			p.box = _roots_box(b)
			p.rest = r == 1
			out.append(p)
	return out

## The drifts' plants of cell `key` parted into `sub` m squares by where each
## stands ("near" true, "sub" the square), each its own batch, for the plants
## drawn out to the swap (FLOWER_SWAP).
static func _sub_split(parts: Array, key: Vector2i, sub: float) -> Array:
	var out := []
	var n := maxi(ceili(CELL/sub),1)
	var x0 := key.x*CELL
	var z0 := key.y*CELL
	for part: Dictionary in parts:
		var src: PackedFloat32Array = part.buffer
		var at := {}
		for k in range(0,src.size(),16):
			var id := clampi(floori((src[k+11]-z0)/sub),0,n-1)*n+clampi(floori((src[k+3]-x0)/sub),0,n-1)
			if not at.has(id): at[id] = []
			(at[id] as Array).append(k)
		for id: int in at:
			var b := PackedFloat32Array()
			for k: int in at[id]: b.append_array(src.slice(k,k+16))
			var p := part.duplicate()
			p.buffer = b
			p.count = b.size()/16
			p.box = _roots_box(b)
			p.sub = Vector3i(key.x,key.y,id)
			p.near = true
			out.append(p)
	return out

## Parts of the same batch (key, tile, sub-tile, ring) joined into one.
static func _join(parts: Array) -> Array:
	var by := {}
	var out := []
	for part: Dictionary in parts:
		var id := [str(part.key),part.tile,part.get("sub",null),int((part.get("ring",{}) as Dictionary).get("ring",-1))]
		if not by.has(id):
			by[id] = part
			out.append(part)
			continue
		var into: Dictionary = by[id]
		var b: PackedFloat32Array = into.buffer
		b.append_array(part.buffer)
		into.buffer = b
		into.count = b.size()/16
		into.box = (into.box as Rect2).merge(part.box)
	return out

## The native placement (native/terrain_kernels/grass_cell.h): each cell's
## tufts placed by ZenScapeGrass, the same tufts in the same places as
## `grow_cell` in GDScript, when the library is built and current
## (--grass-native=0 or --gdscript-kernels: GDScript).
const NATIVE_CLASS := &"ZenScapeGrass"
## The newest library this script knows (2: grow_cell takes a band cell's
## dither; 3: the alpine tufts, ALP_*; 4: the grass areas, area_amount;
## 5: their retune; 6: flower_part, the bloom layer's drifts); any from 1
## places the tufts.
const NATIVE_VERSION := 6
static func native_wanted() -> bool:
	var args := LaunchArgs.user_args()
	if "--grass-native=0" in args or "--gdscript-kernels" in args: return false
	Field.native_available()
	if not ClassDB.class_exists(NATIVE_CLASS): return false
	var probe: Object = ClassDB.instantiate(NATIVE_CLASS)
	return probe.has_method("version") and probe.has_method("assets") and int(probe.version()) >= 1 and int(probe.version()) <= NATIVE_VERSION

## The alpine tufts' settings for the native placement (Config `alp_*`): the
## top under the ground's snow line, the Peak's zone and the ground they keep
## off it, as capsules round the lines the ground paints its ice, rubble and
## scree by (endless_ground peak_paint, peak_ice.gdshaderinc), wide enough for
## their ragged edges.
func _alp_config() -> Dictionary:
	var g := ground
	var snow := float(field.snow_line()) if field != null and field.has_method("snow_line") else 125.0
	if g != null and g.get_shader_parameter("snow_line") != null: snow = float(g.get_shader_parameter("snow_line"))
	var out := {"share":alp_share,"tall":alp_tall,"wide":ALP_WIDE,"tone":alp_tone,"slope":ALP_SLOPE,
		"top":Vector2(snow-ALP_TOP.x,snow-ALP_TOP.y),"zone_top":ALP_ZONE_TOP,
		"proud":"--summits=old" not in LaunchArgs.user_args()}
	if g == null: return out
	# Off the Peak the high ground's stone and scree (the ground's `bare`, with
	# summit_mode on, as its snow caps).
	var summits: Variant = g.get_shader_parameter("summit_mode")
	var on := summits == null or float(summits) > 0.5
	out.proud = out.proud and on
	var from: Variant = g.get_shader_parameter("alpine_from")
	if on: out.bare = from if from is Vector2 else Vector2(0.25,0.95)
	var zone: Variant = g.get_shader_parameter("peak_zone")
	if not zone is Vector4 or (zone as Vector4).w < 0.5: return out
	out.zone = zone
	var off := PackedFloat32Array()
	var add := func(a: Vector2, b: Vector2, ra: float, rb: float) -> void:
		off.append_array(PackedFloat32Array([a.x,a.y,b.x,b.y,ra,rb]))
	var ice_on: Variant = g.get_shader_parameter("peak_ice_on")
	var ice_count: Variant = g.get_shader_parameter("peak_ice_count")
	if ice_on != null and float(ice_on) > 0.5 and ice_count != null and int(ice_count) > 1:
		# The ice (half-width, a ragged edge to 1.45 of it) and its rubble
		# (11 m past it, 80 on the tongue, its rag to 1.4 of that).
		var line: Array = Array(g.get_shader_parameter("peak_ice_line"))
		var more: Array = Array(g.get_shader_parameter("peak_ice_more"))
		var r := func(i: int) -> float:
			var tongue := smoothstep(0.16,0.24,float((more[i] as Vector2).y))
			return float((line[i] as Vector4).z)*1.45+lerpf(11.0,80.0,tongue)*1.4
		for i in mini(int(ice_count),line.size())-1:
			add.call(Vector2(line[i].x,line[i].y),Vector2(line[i+1].x,line[i+1].y),r.call(i),r.call(i+1))
	elif g.get_shader_parameter("peak_frame") is Vector4:
		# The older ice: the valley's floor (peak_paint) from the icefall to the
		# glacier's end, its ragged edge to 1.15 of its half-width.
		var vs := func(k: String, fallback: Vector4) -> Vector4:
			var v: Variant = g.get_shader_parameter(k)
			return v if v is Vector4 else fallback
		var fr: Vector4 = g.get_shader_parameter("peak_frame")
		var st: Vector4 = vs.call("peak_stretch",Vector4(850.0,1250.0,2050.0,4050.0))
		var hw: Vector4 = vs.call("peak_half",Vector4(200.0,240.0,260.0,330.0))
		var bd: Vector4 = vs.call("peak_bend",Vector4(170.0,2.2,1250.0,4500.0))
		var f := Vector2(fr.z,fr.w)
		var side := Vector2(-f.y,f.x)
		var at := func(a: float) -> Array:
			var t := clampf((a-bd.z)/(bd.w-bd.z),0.0,1.0)
			var mid := bd.x*sin(PI*bd.y*t)*smoothstep(0.0,0.25,t)
			var half := hw.x
			if a > st.y and a < st.z: half = lerpf(hw.x,hw.y,smoothstep(0.0,0.3,(a-st.y)/(st.z-st.y)))
			elif a >= st.z: half = lerpf(hw.z,hw.w,clampf((a-st.z)/(st.w-st.z),0.0,1.0))
			return [Vector2(fr.x,fr.y)+f*a+side*mid,half*1.15+8.0]
		var a0 := st.x-60.0
		var prev: Array = at.call(a0)
		var a := a0
		while a < st.w+60.0:
			a = minf(a+50.0,st.w+60.0)
			var next: Array = at.call(a)
			add.call(prev[0],next[0],prev[1],next[1])
			prev = next
	var rock_count: Variant = g.get_shader_parameter("peak_rock_count")
	if rock_count != null and int(rock_count) > 1:
		# The rock gorge's scree (to 1.2 of its width, its rag to 1.45).
		var rl: Array = Array(g.get_shader_parameter("peak_rock_line"))
		for i in mini(int(rock_count),rl.size())-1:
			add.call(Vector2(rl[i].x,rl[i].y),Vector2(rl[i+1].x,rl[i+1].y),float(rl[i].z)*1.45,float(rl[i+1].z)*1.45)
	if off.is_empty(): return out
	var box := Vector4(INF,INF,-INF,-INF)
	for s in range(0,off.size(),6):
		var reach := maxf(off[s+4],off[s+5])*1.15+4.0
		box = Vector4(minf(box.x,minf(off[s],off[s+2])-reach),minf(box.y,minf(off[s+1],off[s+3])-reach),
			maxf(box.z,maxf(off[s],off[s+2])+reach),maxf(box.w,maxf(off[s+1],off[s+3])+reach))
	out.off = off
	out.off_box = box
	return out

## The native placement's settings for a layer: its site (`site_values`),
## its far share and rings, and every table grow_cell's Grow reads (the
## catalog's grass tuft, the meadow type's and the drifts' flower kinds).
static func native_config(site_values: Dictionary, far_share: float, rings: Vector4) -> Dictionary:
	const MeadowTypes = preload("res://scripts/meadow_types.gd")
	var data: Dictionary = SkyIslets.catalog().data
	var c := {}
	for k: String in ["tufts","tuft_bump","shag","contact","height_field","tilt","rim","variety","patches","flower_tall","slope","alpine","alp","flower_part"]:
		if site_values.has(k): c[k] = site_values[k]
	c.sub = site_values.get("sub",0.0)
	c.flowers = bool(site_values.get("flowers",true)) and far_share < 1.0
	c.flower_tries = (BLOOM_TRIES if c.flowers else 0.0001) if Patch.bloom_amount > 0.0 else KitFlora.FLOWER_TRIES
	c.high = HIGH
	c.lod = rings
	c.lod_grow = FAR_GROW
	c.lod_soft = SOFT
	c.far_share = far_share
	c.patch_offset = Patch.offset
	c.region_amount = Patch.region_amount
	c.area_amount = Patch.area_amount
	c.area_edge = Patch.area_edge
	c.bloom_amount = Patch.bloom_amount
	c.plain = Patch.plain()
	c.tint_step = TINT_STEP
	c.sink = SINK
	c.sea_y = Field.SEA_Y
	c.beach_clear = BEACH_CLEAR
	c.beach_ramp = BEACH_RAMP
	c.rock_near = ROCK_NEAR
	c.alpine_top = ALPINE_TOP
	c.tuft_tone = TUFT_TONE
	c.thatch_straw = KitFlora.THATCH_STRAW.srgb_to_linear()
	c.bloom_peak = BLOOM_PEAK
	c.bloom_companion = BLOOM_COMPANION
	c.bloom_kind = BLOOM_KIND
	c.far_wash = FAR_WASH
	c.drift = DRIFT
	c.drift_scale = DRIFT_SCALE
	c.flower_lift = FLOWER_LIFT
	var parts := []
	var grass_keys: Array = data.parts.get("grass_tuft",[])
	for key: String in grass_keys:
		parts.append({"key":key,"pose":data.poses.get(key,Transform3D.IDENTITY),"tint":data.tints.get(key,Color.WHITE),"ringed":KitFlora.ringed(key)})
	c.grass_parts = parts
	# The flower kinds: the meadow type's, the drifts' and the seed heads'.
	var meadow: Dictionary = MeadowTypes.TYPES[KitFlora.MEADOW]
	var names := []
	for fl: Array in meadow.flowers: if not str(fl[0]) in names: names.append(str(fl[0]))
	for k: Array in Patch.KINDS: if not str(k[0]) in names: names.append(str(k[0]))
	if not "wheat" in names: names.append("wheat")
	var assets := PackedStringArray()
	var kinds := []
	for kind: String in names:
		var asset := MeadowTypes.asset(kind)
		if not asset in assets: assets.append(asset)
		var range_of: Array = meadow.sizes.get(kind,[0.85,1.1])
		var row := {"asset":assets.find(asset),"packing":MeadowTypes.packing(kind),"sizes":Vector2(float(range_of[0]),float(range_of[1])),"standing_in":MeadowTypes.standing_in(kind)}
		if MeadowTypes.standing_in(kind):
			var entry: Dictionary = MeadowTypes.FLOWER_KEYS[kind]
			var stand_in: Array = MeadowTypes.FALLBACK_FORMS[entry.fallback]
			row.head = float(entry.head)
			row.height = float(entry.height)
			row.fb_top = float(stand_in[0])
			row.fb_head = float(stand_in[1])
		var tints := PackedColorArray()
		if MeadowTypes.tint(kind,0.0) != "":
			var count: int = (MeadowTypes.FLOWER_KEYS[kind].tints as Array).size()
			for i in count: tints.append(NativeObjectPose.decode_tint(MeadowTypes.tint(kind,(i+0.5)/count)))
		row.tints = tints
		kinds.append(row)
	c.assets = assets
	c.kinds = kinds
	var mk := PackedInt32Array()
	var mw := PackedFloat64Array()
	for fl: Array in meadow.flowers:
		mk.append(names.find(str(fl[0])))
		mw.append(float(fl[1]))
	c.meadow_kinds = mk
	c.meadow_weights = mw
	c.meadow_cover = float(meadow.drift.cover)
	c.meadow_frequency = float(meadow.drift.frequency)
	c.meadow_mix = float(meadow.drift.mix)
	var bk := PackedInt32Array()
	var bv := PackedFloat64Array()
	for k: Array in Patch.KINDS:
		bk.append(names.find(str(k[0])))
		bv.append(float(k[1]))
	c.bloom_kinds = bk
	c.bloom_variants = bv
	c.wheat = names.find("wheat")
	return c

## Frame rate: the materials and tufts the cells draw made at setup (about
## 0.15 s), not by the first cell stood in flight (an 85 ms hitch: each
## plant material folds its shader, scripts/shader_fold.gd). --grass-warm=0:
## made on first use, as before.
var warm := not "--grass-warm=0" in LaunchArgs.user_args()
func _warm() -> void:
	for key: String in (SkyIslets.catalog().meshes as Dictionary).keys():
		if key.begins_with("grass") or key.contains("meadow-flower"):
			var pm: Material = SkyIslets._plant_material(key)
			if bloom_on and key.contains("meadow-flower"):
				for rest: int in [-1,0,1]: _bloom_material(pm,rest)
		if key.begins_with("grass") and KitFlora.ringed(key):
			if fine: _fine(key)
			KitFlora.lite_tuft(key)
			if far_lod > 0.0:
				_far_mesh(key)
				_lite_morph(key)
				if far_lod2 > 0.0: _sparse_mesh(key)

func _exit_tree() -> void:
	_quit = true
	for layer: Layer in layers:
		for key: Vector2i in layer.pending: WorkerThreadPool.wait_for_task_completion(layer.pending[key])
		layer.pending.clear()

## The ground's paint told how far the tufts reach (none while off).
func _reach() -> void:
	if ground == null: return
	ground.set_shader_parameter("carpet_reach",Vector2(lod.z,lod.w) if enabled else Vector2.ZERO)
	ground.set_shader_parameter("carpet_near",Vector2(lod.x,lod.y) if enabled and ROOT_PAINT > 0.0 else Vector2.ZERO)

## A --*-set= value: a float, or a Vector2/3/4 of comma-joined floats.
static func _value(text: String) -> Variant:
	var p := text.split(",")
	match p.size():
		2: return Vector2(float(p[0]),float(p[1]))
		3: return Vector3(float(p[0]),float(p[1]),float(p[2]))
		4: return Vector4(float(p[0]),float(p[1]),float(p[2]),float(p[3]))
	return float(text)

## Turned off (freed) or on again (grown round the eye).
func set_enabled(on: bool) -> void:
	enabled = on
	_reach()
	if not on:
		_drop_standing()
		for layer: Layer in layers:
			for key: Vector2i in layer.cells.keys(): _free(layer,key)
			layer.queue.clear()
			layer.wanted.clear()
		_lock.lock()
		_done.clear()
		_lock.unlock()
	_planned_at = Vector3.INF

## The prefetch from the flight's velocity (m/s): PREFETCH s of its level
## part, at most PREFETCH_MOST m. Before `step`.
func lead_with(velocity: Vector3) -> void:
	ahead = Vector3(velocity.x,0.0,velocity.z)*prefetch
	if ahead.length() > PREFETCH_MOST: ahead = ahead.normalized()*PREFETCH_MOST
	ahead_y = clampf(velocity.y*prefetch,-PREFETCH_MOST,PREFETCH_MOST)

## One frame: the cells round `eye` (the camera that draws) asked for,
## finished ones stood within the budget, far ones freed.
func step(eye: Vector3, forward := Vector3.ZERO) -> void:
	_eye = eye
	_lead_step(forward)
	_reap()
	if not enabled:
		_lock.lock()
		_done.clear()
		_lock.unlock()
		return
	if ground != null and not _fars.is_empty():
		var night: Variant = ground.get_shader_parameter("night_grade")
		for id: Variant in _fars: (_fars[id] as ShaderMaterial).set_shader_parameter("night_grade",night)
	FrameLog.mark(&"g_lead")
	# Replanned as the eye moves, and now and then anyway, so a cell that
	# finished while it wasn't wanted is asked for again once it is.
	_since_plan += 1
	if _planned_at == Vector3.INF or eye.distance_to(_planned_at) > 4.0 or _since_plan > 30 or lead_now.distance_to(_lead_planned) > 0.06: _plan()
	FrameLog.mark(&"g_plan")
	_ask()
	FrameLog.mark(&"g_ask")
	_stand()
	FrameLog.mark(&"g_stand")
	if cull: _cull()

## The lead toward the view's level direction `forward` (damped; at once
## before the first plan), the eye's rise, told to every ring material.
func _lead_step(forward: Vector3) -> void:
	var want := Vector2.ZERO
	var level := Vector2(forward.x,forward.z)
	if lead > 0.0 and level.length() > 0.001:
		want = level.normalized()*lead*smoothstep(LEAD_LEVEL.x,LEAD_LEVEL.y,level.length()/maxf(forward.length(),0.001))
	if _planned_at == Vector3.INF: lead_now = want
	else:
		var dt: float = get_process_delta_time() if is_inside_tree() else 1.0/60.0
		lead_now = lead_now.lerp(want,1.0-exp(-LEAD_RATE*maxf(dt,1.0/240.0)))
	rise = _rise_of(_over(_eye))
	var v := Vector4(lead_now.x,lead_now.y,rise,0.0 if rings_3d else 1.0)
	for id: int in _ring_mats: (_ring_mats[id] as ShaderMaterial).set_shader_parameter("ring_lead",v)

## The rings' rise (`ring_lead`'s z) with the eye `over` m over the ground.
func _rise_of(over: float) -> float:
	var rise_rate := RISE
	if tuft_top > flat_up: rise_rate = lod.w/(tuft_top-flat_up)
	return over if rings_3d else maxf(over-flat_up,0.0)*rise_rate

## The ring distance (m) of ground point `p` from the eye: along the ground,
## led ahead (shaders/endless_ring.gdshaderinc), the rise left out.
func ring_d(p: Vector2) -> float:
	var q := p-Vector2(_eye.x,_eye.z)
	var ll := minf(lead_now.length_squared(),0.81)
	var ql := q.dot(lead_now)
	return (sqrt(ql*ql+(1.0-ll)*q.length_squared())-ql)/(1.0-ll)

## A cell's ring distance, at its point nearest the eye (for the order).
func _cell_d(key: Vector2i) -> float:
	var x0 := key.x*CELL
	var z0 := key.y*CELL
	return ring_d(Vector2(clampf(_eye.x,x0,x0+CELL),clampf(_eye.z,z0,z0+CELL)))

## The disc of ground (centre x, z, radius) within ring distance `reach`
## (the rise taken off).
func _disc(reach: float, at_rise := -1.0) -> Vector3:
	var ri := rise if at_rise < 0.0 else at_rise
	var r := sqrt(maxf(reach*reach-ri*ri,0.0))
	var c := Vector2(_eye.x,_eye.z)+lead_now*r
	return Vector3(c.x,c.y,r)

## A cell's square's flat distance from ground point `c`.
func _square_d(key: Vector2i, c: Vector2) -> float:
	var x0 := key.x*CELL
	var z0 := key.y*CELL
	var dx := maxf(maxf(x0-c.x,c.x-(x0+CELL)),0.0)
	var dz := maxf(maxf(z0-c.y,c.y-(z0+CELL)),0.0)
	return sqrt(dx*dx+dz*dz)

## The near cells under the full carpet (LOD.y), and the far ones within
## PRIME_FAR m, grown before the first frame, the main thread waiting (at most PRIME_WAIT s); the rest grow in
## flight.
const PRIME_WAIT := 4.0
const PRIME_FAR := 90.0
func prime(at: Vector3, forward := Vector3.ZERO) -> void:
	var began := Time.get_ticks_msec()
	step(at,forward)
	while Time.get_ticks_msec()-began < PRIME_WAIT*1000.0:
		var left := false
		for key: Vector2i in near_layer.wanted:
			if not near_layer.cells.has(key) and _cell_d(key) < lod.y: left = true
		for key: Vector2i in far_layer.wanted:
			if not far_layer.cells.has(key) and _cell_d(key) < PRIME_FAR: left = true
		if bloom_on:
			for key: Vector2i in bloom_layer.wanted:
				if not bloom_layer.cells.has(key) and _cell_d(key) < flower_fade.x: left = true
		if not left: break
		OS.delay_msec(4)
		_reap()
		_ask()
		_stand(true)
	# The load's stands aren't flight's.
	stats.slowest_stand_ms = 0.0

## How far the eye stands over the ground under it (m, at least 0).
func _over(eye: Vector3) -> float:
	return maxf(eye.y-maxf(field.height(eye.x,eye.z),Field.SEA_Y),0.0)

func _plan() -> void:
	_planned_at = _eye
	_lead_planned = lead_now
	_since_plan = 0
	# Planned for the lowest of the eye now and where the prefetch has it,
	# half way and all the way (over the ground there: a hill ahead
	# brings the near ring in as a descent does).
	var plan_rise := rise
	if ahead != Vector3.ZERO or ahead_y != 0.0:
		for k: float in [0.5,1.0]:
			plan_rise = minf(plan_rise,_rise_of(_over(_eye+Vector3(ahead.x,ahead_y,ahead.z)*k)))
	for layer: Layer in layers:
		# The disc within the ring's reach (led ahead; smaller as the eye
		# rises past flat_up), and the one past which a cell goes.
		# (The near layer goes with its grass: its flowers alone, past it,
		# would be a pixel across. The drifts' flowers go as their ring does.)
		var disc := _disc(layer.reach if layer.far or layer.bloom or plan_rise < lod.y else 0.0,plan_rise)
		var centre := Vector2(disc.x,disc.y)
		var reach := disc.z
		layer.wanted.clear()
		# Round the eye, and round where it will be (the prefetch).
		var centres := [centre]
		if ahead != Vector3.ZERO: centres.append(centre+Vector2(ahead.x,ahead.z))
		for at: Vector2 in centres:
			if reach <= 0.0: break
			var r := ceili((reach+CELL)/CELL)
			var cx := floori(at.x/CELL)
			var cz := floori(at.y/CELL)
			for dz in range(-r,r+1):
				for dx in range(-r,r+1):
					var key := Vector2i(cx+dx,cz+dz)
					if _square_d(key,at) <= reach: layer.wanted[key] = true
		var keep := _disc(layer.reach+KEEP)
		for key: Vector2i in layer.cells.keys():
			if not layer.wanted.has(key) and _square_d(key,Vector2(keep.x,keep.y)) > keep.z: _free(layer,key)
		if not _standing.is_empty() and _standing[0].layer == layer and not layer.wanted.has(_standing[0].key): _drop_standing()
		layer.queue.clear()
		for key: Vector2i in layer.wanted:
			if not layer.cells.has(key) and not layer.pending.has(key): layer.queue.append(key)
		if StreamLog.on:
			var log_as := _log_as(layer)
			for key: Vector2i in layer.queue: StreamLog.want(log_as,key,_cell_d(key))
			StreamLog.keep(log_as,layer.wanted,layer.pending)
		# Nearest by the ring distance first: ahead before behind.
		layer.queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cell_d(a) < _cell_d(b))

## The layer's name in the stream log.
static func _log_as(layer: Layer) -> StringName:
	return &"grass_far" if layer.far else (&"grass_bloom" if layer.bloom else &"grass")

func _free(layer: Layer, key: Vector2i) -> void:
	(layer.cells[key] as Node).queue_free()
	layer.cells.erase(key)
	stats.freed += 1

## Cells growing now, every layer.
func _tasks() -> int:
	var n := 0
	for layer: Layer in layers: n += layer.pending.size()
	return n

func _ask() -> void:
	for layer: Layer in layers:
		while _tasks() < MAX_TASKS and not layer.queue.is_empty():
			var key: Vector2i = layer.queue.pop_front()
			if layer.cells.has(key) or layer.pending.has(key): continue
			var mix := {}
			if layer.regional.is_empty(): mix = {"groups":[[layer.site,layer.native,true]],"w":PackedFloat32Array()}
			else: mix = _cell_mix(layer,key)
			for one: Array in mix.groups:
				one[0] = (one[0] as Dictionary).duplicate()
				if layer.native == null: one[1] = null
			layer.pending[key] = WorkerThreadPool.add_task(_grow.bind(layer,key,seed,mix,lod),false,"grass cell")
			if StreamLog.on: StreamLog.ask(_log_as(layer),key)

## Finished tasks let go.
func _reap() -> void:
	for layer: Layer in layers:
		for key: Vector2i in layer.pending.keys():
			var id: int = layer.pending[key]
			if WorkerThreadPool.is_task_completed(id):
				WorkerThreadPool.wait_for_task_completion(id)
				layer.pending.erase(key)

## Finished cells' batches stood, nearest first, within the budget (a cell's
## batches over as many frames as that takes, the cell in the tree from its
## first); a cell no longer wanted is dropped.
func _stand(all := false) -> void:
	_lock.lock()
	var ready := _done
	_done = []
	_lock.unlock()
	if ready.is_empty() and _standing.is_empty(): return
	var began := Time.get_ticks_usec()
	ready.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _cell_d(a.key) < _cell_d(b.key))
	while all or (Time.get_ticks_usec()-began)/1000.0 <= STAND_BUDGET:
		if _standing.is_empty():
			if ready.is_empty(): break
			var r: Dictionary = ready.pop_front()
			var layer: Layer = r.layer
			stats.grown += 1
			stats.grow_ms += float(r.ms)
			stats.slowest_grow_ms = maxf(stats.slowest_grow_ms,float(r.ms))
			if StreamLog.on: StreamLog.built(_log_as(layer),r.key,float(r.ms),int(r.ended))
			if layer.cells.has(r.key) or not layer.wanted.has(r.key): continue
			var node := Node3D.new()
			node.name = "%s_%d_%d" % ["Far" if layer.far else "Near",r.key.x,r.key.y]
			add_child(node)
			_standing = [r,node,{},0,0]
		_stand_some(all,began)
	stats.slowest_stand_ms = maxf(stats.slowest_stand_ms,(Time.get_ticks_usec()-began)/1000.0)
	if not ready.is_empty():
		_lock.lock()
		ready.append_array(_done)
		_done = ready
		_lock.unlock()

## The standing cell's next batches, until the budget is spent (`all`: every
## one); the cell is the layer's once its last is stood.
func _stand_some(all: bool, began: int) -> void:
	var r: Dictionary = _standing[0]
	var node: Node3D = _standing[1]
	var groups: Dictionary = _standing[2]
	var layer: Layer = r.layer
	var parts: Array = r.parts
	while int(_standing[4]) < parts.size():
		if not all and (Time.get_ticks_usec()-began)/1000.0 > STAND_BUDGET: return
		var part: Dictionary = parts[_standing[4]]
		_standing[4] = int(_standing[4])+1
		var ring: Dictionary = part.get("ring",{})
		var own: Mesh = _fine(str(part.key)) if fine and not layer.far and str(part.key).begins_with("grass") else null
		if layer.far and far_lod > 0.0: own = _lite_morph(str(part.key))
		var cheap := bool(part.get("cheap",false))
		if cheap: own = _far_flower(str(part.key))
		var batch := KitFlora.batch_node(str(part.key),part.tile,int(part.count),part.buffer,lod.w,ring,own)
		_standing[3] = int(_standing[3])+int(part.count)
		# A tile is drawn out to its ring's reach led ahead, and over
		# the height the rings stay flat to (Godot's range is 3D).
		var past := KitFlora.TILE*0.75+(rise if rings_3d else flat_up)
		if layer.far:
			batch.material_override = _far(str(part.key),ring)
			batch.visibility_range_end = lod.w*(1.0+lead)+past
			# Its buffer kept for the far lod's swap (_swap_mesh).
			if far_lod > 0.0: batch.set_meta("buffer",part.buffer)
		elif ring.is_empty():
			# The flowers thin out each at its own distance (no tile
			# fade, which would draw them in the transparent pass); the
			# drifts' in a material of their own (_bloom_material).
			batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			batch.visibility_range_end_margin = 0.0
			batch.visibility_range_end = _flower_reach(layer,part)*(1.0+lead)+past
			if layer.bloom: batch.material_override = _bloom_material(batch.material_override,int(part.get("rest",-1)),(-1 if cheap else 1) if flower_swap.x > 0.0 else 0)
		else: batch.visibility_range_end = lod.y*(1.0+lead)+past
		_calm(batch,layer.bloom)
		# Culled: the batches under a holder a tile and ring (its roots' box,
		# its ring's reach), [reach, holder, box, shown, far lod].
		if cull and part.has("box"):
			var reach := lod.w if layer.far else (_flower_reach(layer,part) if ring.is_empty() else lod.y)
			var gk := [reach,part.get("sub",part.tile)]
			if not groups.has(gk):
				var holder := Node3D.new()
				holder.name = "Tile_%d" % groups.size()
				node.add_child(holder)
				groups[gk] = [reach,holder,part.box,true,false]
			var g: Array = groups[gk]
			g[2] = (g[2] as Rect2).merge(part.box)
			(g[1] as Node3D).add_child(batch)
		else: node.add_child(batch)
	if cull:
		var stood: Array = groups.values()
		# For _cull: the cell's tiles as flat arrays (CullCell).
		if not stood.is_empty():
			var cc := CullCell.new()
			cc.box = stood[0][2]
			for g: Array in stood:
				var b: Rect2 = g[2]
				cc.box = cc.box.merge(b)
				var ri := cc.reaches.find(g[0])
				if ri < 0:
					ri = cc.reaches.size()
					cc.reaches.append(g[0])
				cc.reach_of.append(ri)
				cc.boxes.append_array(PackedFloat32Array([b.position.x,b.position.y,b.end.x,b.end.y]))
				cc.state.append(1)
				cc.holders.append(g[1])
			node.set_meta("cull",cc)
	node.set_meta("instances",int(_standing[3]))
	layer.cells[r.key] = node
	if StreamLog.on: StreamLog.show(_log_as(layer),r.key,1 if layer.far else 0,_cell_d(r.key))
	_standing = []

## The cell half stood let go.
func _drop_standing() -> void:
	if _standing.is_empty(): return
	(_standing[1] as Node).queue_free()
	_standing = []

## The tiles culled by the rings (see CULL_SLACK): a tile shown while its
## roots' box meets its ring's disc (endless_ring.gdshaderinc: ring distance R
## is a disc of radius r = sqrt(R*R-rise*rise) centred lead*r ahead), the far
## ring's a quarter of its cells a frame (each every CULL_SPREAD frames: at
## boost, 46 m/s, 3 m, inside its 4 m slack), the near's half (1.5 m, inside
## its 2 m); the far ring's lod swapped past far_lod.
func _cull() -> void:
	_cull_frame += 1
	if not _cull_native_looked:
		_cull_native_looked = true
		if native_wanted() and not "--grass-cull-native=0" in LaunchArgs.user_args():
			var probe: Object = ClassDB.instantiate(NATIVE_CLASS)
			if probe.has_method("cull_tiles"): _cull_native = probe
	var discs := {}
	var eye := Vector2(_eye.x,_eye.z)
	for layer: Layer in layers:
		# (The drifts' flowers' edge is far out, as the far ring's.)
		var wide := layer.far or layer.bloom
		var slack := CULL_SLACK*(2.0 if wide else 1.0)
		for key: Vector2i in layer.cells:
			var spread := CULL_SPREAD if wide else CULL_SPREAD_NEAR
			if posmod(key.x+key.y*3,spread) != _cull_frame%spread: continue
			var node: Node3D = layer.cells[key]
			if not node.has_meta("cull"): continue
			var cc: CullCell = node.get_meta("cull")
			# A cell wholly inside or wholly past its rings, as it was the
			# last time its tiles were gone through, has nothing to change.
			var whole := _cull_whole(cc,layer.far,slack,eye,discs)
			if whole >= 0 and whole == cc.whole: continue
			cc.whole = whole
			# Its rings' discs, and the far lods' (each lod's own and its
			# switch back's), for the tiles' pass.
			var show := PackedFloat32Array()
			for reach: float in cc.reaches:
				if not discs.has(reach): discs[reach] = _cull_disc(reach+slack,eye)
				show.append_array(discs[reach])
			var lods := PackedFloat32Array()
			if layer.far and far_lod > 0.0:
				for lod_r: float in ([far_lod,far_lod+FAR_LOD_BACK,far_lod2,far_lod2+FAR_LOD_BACK] if far_lod2 > 0.0 else [far_lod,far_lod+FAR_LOD_BACK]):
					if not discs.has(-lod_r): discs[-lod_r] = _cull_disc(lod_r,eye)
					lods.append_array(discs[-lod_r])
			var changed: PackedInt32Array = _cull_native.cull_tiles(cc.boxes,cc.reach_of,cc.state,show,lods) if _cull_native != null else cull_tiles(cc.boxes,cc.reach_of,cc.state,show,lods)
			for j in range(0,changed.size(),2):
				var i := changed[j]
				var now := changed[j+1]
				var was := cc.state[i]
				cc.state[i] = now
				var holder: Node3D = cc.holders[i]
				if (now&1) != (was&1): holder.visible = (now&1) == 1
				if (now>>1) != (was>>1):
					for b: Node in holder.get_children():
						_swap_mesh(b as MultiMeshInstance3D,_tier_mesh(str(b.get_meta("part","")),now>>1))

## A cell's tiles for _cull, a tile and ring each (the batches under one
## holder): its roots' box (x0, z0, x1, z1), its ring (an index into
## `reaches`), its state (bit 0 shown, the bits over it its far lod: 0 lite,
## 1 far, 2 sparse); the box of them all, and how the cell stood as a whole
## when its tiles were last gone through (_cull_whole).
class CullCell extends RefCounted:
	var boxes := PackedFloat32Array()
	var reach_of := PackedByteArray()
	var reaches: Array[float] = []
	var state := PackedByteArray()
	var holders: Array[Node3D] = []
	var box := Rect2()
	var whole := -1

## One cell's tiles against the discs: each tile shown while its box meets its
## ring's disc (`show`: a disc a ring, [centre x, z, radius squared]); a far
## tile shown takes its lod from `lods` (empty: none; the first lod's disc and
## its switch back's, then the second's two: up once wholly past a lod's
## distance and the way back more, down once not). The tiles whose state
## changed, [index, new state] each. ZenScapeGrass `cull_tiles` is this in
## C++ (native/terrain_kernels/grass_cell.h), the same answers.
static func cull_tiles(boxes: PackedFloat32Array, reach_of: PackedByteArray, state: PackedByteArray, show: PackedFloat32Array, lods: PackedFloat32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var has_lod := lods.size() >= 6
	var has_lod2 := lods.size() >= 12
	for i in state.size():
		var o := i*4
		var was := state[i]
		var tier := was>>1
		var shown := _tile_meets(boxes,o,show,reach_of[i]*3)
		if has_lod and shown:
			var up := tier
			tier = 0 if _tile_meets(boxes,o,lods,0 if up >= 1 else 3) else 1
			if tier == 1 and has_lod2 and not _tile_meets(boxes,o,lods,6 if up >= 2 else 9): tier = 2
		var now := (1 if shown else 0)|(tier<<1)
		if now != was:
			out.append(i)
			out.append(now)
	return out

## Whether the box at `boxes[o]` meets the disc at `discs[d]`.
static func _tile_meets(boxes: PackedFloat32Array, o: int, discs: PackedFloat32Array, d: int) -> bool:
	if discs[d+2] < 0.0: return false
	var dx := maxf(maxf(boxes[o]-discs[d],discs[d]-boxes[o+2]),0.0)
	var dz := maxf(maxf(boxes[o+1]-discs[d+1],discs[d+1]-boxes[o+3]),0.0)
	return dx*dx+dz*dz <= discs[d+2]

## How cell `cc` stands to its rings as a whole: a code that is the same
## while every tile of it would be culled the same way (each ring's disc holds
## the cell's whole box or misses it; a far cell shown is wholly at one lod, nearer than
## the far lod or wholly past its switch back), or -1 where a disc's edge
## crosses the cell and its tiles differ.
func _cull_whole(cc: CullCell, far: bool, slack: float, eye: Vector2, discs: Dictionary) -> int:
	var box := cc.box
	var code := 0
	for reach: float in cc.reaches:
		if not discs.has(reach): discs[reach] = _cull_disc(reach+slack,eye)
		var disc: PackedFloat32Array = discs[reach]
		if not _box_meets(box,disc):
			code = code*3+2
			continue
		if not _box_within(box,disc): return -1
		code = code*3+1
		if far and far_lod > 0.0:
			var back := far_lod+FAR_LOD_BACK
			if not discs.has(-far_lod): discs[-far_lod] = _cull_disc(far_lod,eye)
			if not discs.has(-back): discs[-back] = _cull_disc(back,eye)
			var back2 := far_lod2+FAR_LOD_BACK
			if far_lod2 > 0.0:
				if not discs.has(-far_lod2): discs[-far_lod2] = _cull_disc(far_lod2,eye)
				if not discs.has(-back2): discs[-back2] = _cull_disc(back2,eye)
			if far_lod2 > 0.0 and not _box_meets(box,discs[-back2]): code = code*4+3
			elif not _box_meets(box,discs[-back]) and (far_lod2 <= 0.0 or _box_within(box,discs[-far_lod2])): code = code*4+2
			elif _box_within(box,discs[-far_lod]): code = code*4+1
			else: return -1
	return code

## Whether `disc` holds the whole of `box`.
static func _box_within(box: Rect2, disc: PackedFloat32Array) -> bool:
	if disc[2] < 0.0: return false
	var dx := maxf(absf(box.position.x-disc[0]),absf(box.end.x-disc[0]))
	var dz := maxf(absf(box.position.y-disc[1]),absf(box.end.y-disc[1]))
	return dx*dx+dz*dz <= disc[2]

## Batch `b` drawing `mesh`: a new multimesh of its kept buffer. Setting a
## standing multimesh's mesh makes the renderer work its bounds out again
## from the instances, reading the buffer back off the GPU: about 10 ms a
## frame at boost, with every far tile there.
static func _swap_mesh(b: MultiMeshInstance3D, mesh: Mesh) -> void:
	var old := b.multimesh
	if not b.has_meta("buffer"):
		old.mesh = mesh
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = old.instance_count
	mm.buffer = b.get_meta("buffer")
	b.multimesh = mm

## The ground disc within ring distance `reach` [centre x, z, radius squared]
## (radius squared below zero: none).
func _cull_disc(reach: float, eye: Vector2) -> PackedFloat32Array:
	var rr := reach*reach-rise*rise
	if rr <= 0.0: return PackedFloat32Array([0.0,0.0,-1.0])
	var r := sqrt(rr)
	return PackedFloat32Array([eye.x+lead_now.x*r,eye.y+lead_now.y*r,rr])

static func _box_meets(box: Rect2, disc: PackedFloat32Array) -> bool:
	if disc[2] < 0.0: return false
	var dx := maxf(maxf(box.position.x-disc[0],disc[0]-box.end.x),0.0)
	var dz := maxf(maxf(box.position.y-disc[1],disc[1]-box.end.y),0.0)
	return dx*dx+dz*dz <= disc[2]

## The far lod's tuft for catalog part `key` (GrassTuft.build_far in the lite
## tuft's colours), made once.
func _far_mesh(key: String) -> Mesh:
	if _far_meshes.has(key): return _far_meshes[key]
	var lite: Mesh = KitFlora.lite_tuft(key)
	var mesh: Mesh = GrassTuft.build_far(lite.get_meta("grass_root"),lite.get_meta("grass_tip"))
	_far_meshes[key] = mesh
	return mesh

## The second far lod's tuft for catalog part `key` (GrassTuft build_sparse).
func _sparse_mesh(key: String) -> Mesh:
	var id := "sparse:"+key
	if _far_meshes.has(id): return _far_meshes[id]
	var lite: Mesh = KitFlora.lite_tuft(key)
	var mesh: Mesh = GrassTuft.build_sparse(lite.get_meta("grass_root"),lite.get_meta("grass_tip"))
	_far_meshes[id] = mesh
	return mesh

## The far ring's tuft for part `key` at lod `tier` (0 lite, 1 far, 2 sparse).
func _tier_mesh(key: String, tier: int) -> Mesh:
	return _lite_morph(key) if tier == 0 else (_far_mesh(key) if tier == 1 else _sparse_mesh(key))

## The lite tuft that eases into the far lod's shape (GrassTuft
## build_lite_morph), drawn by the far ring while the far lod is on.
func _lite_morph(key: String) -> Mesh:
	var id := "morph:"+key
	if _far_meshes.has(id): return _far_meshes[id]
	var lite: Mesh = KitFlora.lite_tuft(key)
	var mesh: Mesh = GrassTuft.build_lite_morph(lite.get_meta("grass_root"),lite.get_meta("grass_tip"))
	_far_meshes[id] = mesh
	return mesh

## The far plant (MeadowFlowerMesh build_far) of catalog flower `key`, or the
## part's own mesh for a kind without one.
func _far_flower(key: String) -> Mesh:
	var kind := MeadowFlowers.kind_of_part(key)
	return MeadowFlowers.far_mesh(kind) if kind != "" else SkyIslets.catalog().meshes[key]

## How far (ring m) a part's flowers are drawn: the drifts' kept share to
## flower_end, their rest (_rank_split) till the last of them has sunk (its
## shader rank is over flower_keep: gone once the share kept falls to
## flower_keep/(1+FLOWER_SOFT), a few metres past flower_fade.y), the near
## carpet's to STRAY_FADE.y.
func _flower_reach(layer: Layer, part: Dictionary) -> float:
	if not layer.bloom: return STRAY_FADE.y
	if bool(part.get("near",false)): return flower_swap.x+flower_swap.y*0.5+1.0
	if not bool(part.get("rest",false)): return flower_end
	return flower_end-(flower_end-flower_fade.y)/(1.0+FLOWER_SOFT)+2.0

## The drifts' flowers' own copy of a plant material (their fade is theirs,
## FLOWER_FADE; the near carpet's flowers of the kind keep STRAY_FADE), made
## once a `rest` (-1 all of them, 0 the kept share, 1 the rest: meta "rank")
## and `swap` (1 the plants, -1 the far plants, 0 no swap: meta "swap").
var _bloom_mats := {}
func _bloom_material(m: Material, rest := -1, swap := 0) -> Material:
	if m == null: return m
	var id := [m.get_instance_id(),rest,swap]
	if not _bloom_mats.has(id):
		var d := m.duplicate()
		d.set_meta("swap",swap)
		d.set_meta("rank",Vector2(0.0,1.0) if rest < 0 else (Vector2(0.0,flower_keep) if rest == 0 else Vector2(flower_keep,1.0)))
		_bloom_mats[id] = d
	return _bloom_mats[id]

## The isle's carpet calm (Carpet `calm`) on a batch's material, once a
## material; the flowers thinned by distance (`bloom`: the drifts' own, out
## to flower_end, else the near carpet's, STRAY_FADE).
func _calm(batch: MultiMeshInstance3D, bloom := false) -> void:
	var m := batch.material_override as ShaderMaterial
	if m == null or _calmed.has(m.get_instance_id()) or _fars.values().has(m): return
	_calmed[m.get_instance_id()] = true
	_ring_mats[m.get_instance_id()] = m
	m.set_shader_parameter("ring_lead",Vector4(lead_now.x,lead_now.y,rise,0.0 if rings_3d else 1.0))
	m.set_shader_parameter("cloud_sun_shade",CLOUD_SUN)
	if str(batch.get_meta("part","")).begins_with("grass"):
		m.set_shader_parameter("grass_dry",Carpet.CARPET_GRASS_DRY)
		m.set_shader_parameter("grass_mute",Carpet.CARPET_MUTE)
		m.set_shader_parameter("grass_wave_sheen",Carpet.CARPET_SHEEN)
		var plain := Patch.plain()
		m.set_shader_parameter("grass_root_paint",Vector4(plain.x,plain.y,plain.z,ROOT_PAINT))
		_silver(m,"grass_wave_sheen",SILVER_SHEEN)
		for k: String in _sets.grass: m.set_shader_parameter(k,_sets.grass[k])
		# The sway's arm is the blade's height: taller blades bend as far.
		var sway = m.get_shader_parameter("sway_shape")
		if sway is Vector4 and fine: m.set_shader_parameter("sway_shape",Vector4(sway.x,sway.y*tall,sway.z,sway.w))
	elif bloom:
		# All there to flower_fade.x, flower_keep of them (their heads grown)
		# by .y, the last gone by flower_end, each growing in over FLOWER_SOFT.
		m.set_shader_parameter("flower_far",Vector4(flower_fade.x,flower_fade.y,flower_keep,flower_grow if flower_keep > 0.0 else 0.0))
		m.set_shader_parameter("flower_end",Vector2(flower_end if flower_keep > 0.0 else 0.0,FLOWER_SOFT))
		m.set_shader_parameter("flower_rank",m.get_meta("rank",Vector2(0.0,1.0)))
		m.set_shader_parameter("flower_swap",Vector3(flower_swap.x,flower_swap.y,float(m.get_meta("swap",0))))
	else:
		m.set_shader_parameter("flower_far",Vector4(STRAY_FADE.x,STRAY_FADE.y,0.0,0.0))
	if not str(batch.get_meta("part","")).begins_with("grass"):
		# The heads keep their shape on the lifted stems, and grow to suit
		# the taller grass (reference_surface `flower_head_grow`).
		m.set_shader_parameter("flower_head_grow",flower_head)
		# Their leaves and buds gone before the heads (FLOWER_DETAIL; led
		# out ahead, they would glint a pixel across).
		m.set_shader_parameter("flower_lod",FLOWER_DETAIL)

## The FINE tuft for catalog part `key`, its root and tip colours the
## part's own (so the material divides them out alike), made once.
func _fine(key: String) -> Mesh:
	if _fine_meshes.has(key): return _fine_meshes[key]
	var source: Mesh = SkyIslets.catalog().meshes[key]
	var root: Color = source.get_meta("grass_root",Color("38663a").srgb_to_linear())
	var tip: Color = source.get_meta("grass_tip",Color("93c05f").srgb_to_linear())
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	GrassTuft._clump(surface,rng,root,tip,int(FINE.blades),Vector2.ZERO,1.0,FINE.rows,FINE.taper,float(FINE.width))
	var turn := rng.randf()*TAU
	for satellite: Array in FINE.satellites:
		turn += rng.randf_range(2.0,3.6)
		GrassTuft._clump(surface,rng,root,tip,int(satellite[0]),Vector2.from_angle(turn)*float(satellite[1]),float(satellite[2]),FINE.rows,FINE.taper,float(FINE.width))
	surface.index()
	var mesh := surface.commit()
	# Without the second UV (all zero, as a mesh without one reads). (Godot's
	# compressed vertex, GrassTuft.compressed, was tried here: no faster, the
	# near ring's cost being its material's work a vertex, and 3% of a low
	# meadow's pixels moved.)
	var arrays := mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_TEX_UV2] = null
	if not is_equal_approx(tall,1.0):
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in v.size(): v[i].y *= tall
		arrays[Mesh.ARRAY_VERTEX] = v
	mesh = ArrayMesh.new()
	(mesh as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.set_meta("grass_root",root)
	mesh.set_meta("grass_tip",tip)
	_fine_meshes[key] = mesh
	return mesh

## The far ring's material (shaders/endless_tuft_far.gdshader): KitFlora's
## mid ring (its `ring_material`'s grass_ring and grass_ring_grow) drawn
## plainly, its tufts growing in from nothing as the near ring thins. The
## isles' tuft material works out its sway, ground colour and light at every
## vertex and pixel, which over a field to the horizon cost 10 to 20 ms a
## frame.
func _far(key: String, ring: Dictionary) -> Material:
	var lod_v: Vector4 = ring.lod
	var id := [key,lod_v,ring.grow,ring.soft]
	if _fars.has(id): return _fars[id]
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/endless_tuft_far.gdshader")
	var grow: Vector2 = ring.grow
	var soft := float(ring.soft)
	m.set_shader_parameter("grass_ring",Vector4(lod_v.z,lod_v.w,soft,0.0))
	# Each comes up over the soft metres where a near tuft at its rank goes.
	m.set_shader_parameter("grass_ring_in",Vector4(lod_v.x-soft,lod_v.y-soft,soft,0.0))
	m.set_shader_parameter("grow_near",Vector2(FAR_NEAR.x,FAR_NEAR.y*tall))
	m.set_shader_parameter("grass_ring_grow",Vector4(lod_v.y,lod_v.z,grow.x,grow.y*tall))
	# The drift's tufts come up as the flowers go (reference_surface
	# `flower_far`: over wash_fade, as the last kept go).
	var wf := wash_fade()
	m.set_shader_parameter("wash_in",Vector4(wf.x-soft*0.5,wf.y-soft*0.5,soft*0.5,0.0))
	var washes := PackedVector3Array()
	for k: Array in Patch.KINDS: washes.append(k[2])
	washes.resize(8)
	m.set_shader_parameter("wash_colours",washes)
	m.set_shader_parameter("ring_lead",Vector4(lead_now.x,lead_now.y,rise,0.0 if rings_3d else 1.0))
	m.set_shader_parameter("root_colour",FAR_ROOT)
	m.set_shader_parameter("tip_colour",FAR_TIP)
	var mesh: Mesh = KitFlora.lite_tuft(key)
	if mesh.has_meta("grass_root"):
		var root: Color = mesh.get_meta("grass_root")
		var tip: Color = mesh.get_meta("grass_tip")
		m.set_shader_parameter("grass_source_root",Vector3(root.r,root.g,root.b))
		m.set_shader_parameter("grass_source_tip",Vector3(tip.r,tip.g,tip.b))
	m.set_shader_parameter("cloud_shade",CLOUD_SUN)
	# The far lod: each tuft in its shape by FAR_LOD_SAFE m short of it, so a
	# tile swapping there (its nearest root past it) changes no pixel.
	if far_lod > 0.0: m.set_shader_parameter("far_morph",Vector2(far_lod-FAR_MORPH,far_lod-FAR_LOD_SAFE))
	if far_lod > 0.0 and far_lod2 > 0.0: m.set_shader_parameter("far_morph2",Vector2(maxf(far_lod2-FAR_MORPH2,far_lod-FAR_LOD_SAFE),far_lod2-FAR_LOD_SAFE))
	_silver(m,"",0.0,true)
	GrassSheen.apply(m,true)
	world.apply_far(m)
	for k: String in _sets.far: m.set_shader_parameter(k,_sets.far[k])
	_fars[id] = m
	_ring_mats[m.get_instance_id()] = m
	return m

## The silvery undersides on material `m` (none while `silver` is 0), and
## its old wind paling `sheen` cut to `cut` while they show.
func _silver(m: ShaderMaterial, sheen := "", cut := 0.0, far := false) -> void:
	if silver <= 0.0: return
	_silver_tier(m,far)
	if sheen != "": m.set_shader_parameter(sheen,cut)

## grass_silver on material `m`, with its tier's lift and keep.
func _silver_tier(m: ShaderMaterial, far := false) -> void:
	var tier := 2 if m == ground else (1 if far or _fars.values().has(m) else 0)
	m.set_shader_parameter("grass_silver",Vector4(silver,SILVER_BOW.x,SILVER_BOW.y,SILVER_LIFT[tier]))
	m.set_shader_parameter("grass_silver_keep",SILVER_KEEP[tier])
	# The world's own underside hue (paint.silver_colour; absent: the shader's sage).
	if world != null: world.apply_silver(m)

## The undersides turned to strength `s` on every grass material now
## standing (0 off: the old paling back), for A/B in one run.
func set_silver(s: float) -> void:
	silver = maxf(s,0.0)
	for m: ShaderMaterial in _ring_mats.values():
		var on := silver > 0.0
		_silver_tier(m)
		if m == ground: m.set_shader_parameter("wind_sheen",SILVER_WIND_SHEEN if on else 1.0)
		elif not _fars.values().has(m): m.set_shader_parameter("grass_wave_sheen",SILVER_SHEEN if on else Carpet.CARPET_SHEEN)

## Cells standing, building and queued, and the instances drawn, both layers.
func counts() -> Dictionary:
	var out := {"cells":0,"building":0,"queued":0,"instances":0}
	for layer: Layer in layers:
		out.cells += layer.cells.size()
		out.building += layer.pending.size()
		out.queued += layer.queue.size()
		for key: Vector2i in layer.cells: out.instances += int((layer.cells[key] as Node).get_meta("instances",0))
	out.near_cells = near_layer.cells.size()
	out.far_cells = far_layer.cells.size()
	out.bloom_cells = bloom_layer.cells.size()
	return out

# --- On a worker ----------------------------------------------------------------------

## How many times the flowers' share is kept at p (DRIFT).
## (Round 4's drifts: with round 5's on, grow_cell reads them off its grid.)
static func flower_drift(p: Vector2) -> float:
	var n := Patch.noise(p.x/DRIFT_SCALE+17.3,p.y/DRIFT_SCALE-5.1)
	return 1.0+(DRIFT.z-1.0)*smoothstep(DRIFT.x,DRIFT.y,n)

## One cell grown on a worker: `mix` (_cell_mix) its groups' carpets, one
## grown whole, or in the band each grown and dithered per tuft by the
## groups' weights (a group that grows no grass keeps its share bare).
func _grow(layer: Layer, key: Vector2i, land_seed: int, mix: Dictionary, rings: Vector4) -> void:
	if _quit: return
	var began := Time.get_ticks_usec()
	var parts := []
	var groups: Array = mix.groups
	if groups.size() == 1:
		if groups[0][2]: parts = grow_cell(land_seed,key,groups[0][0],rings,layer.share,groups[0][1])
	else:
		# One grid (and one ground colour) for every group's grow; a native
		# grow that takes the dither skips the other groups' tufts itself.
		var got := {}
		for g in groups.size():
			if _quit: return
			if not groups[g][2]: continue
			var native: Object = groups[g][1]
			if native != null and _native_dithers(native):
				got.dither = {"dither":mix.w,"dither_grid":DITHER_GRID,"dither_count":groups.size(),"dither_group":g}
				parts.append_array(grow_cell(land_seed,key,groups[g][0],rings,layer.share,native,got))
				continue
			var grown := grow_cell(land_seed,key,groups[g][0],rings,layer.share,native,got)
			parts.append_array(_dither(grown,key,mix.w,groups.size(),g))
		parts = _join(parts)
	# The drifts' flowers a batch a kind for the whole cell, not a KitFlora
	# tile (a few hundred a cell, out to flower_end: the draws, not the
	# vertices, are what they cost).
	if layer.bloom:
		for part: Dictionary in parts: part.tile = key
		parts = _join(parts)
		# The plants in FLOWER_SWAP_SUB squares out to the swap, the far
		# plants (all of them, thinned as before) the cell's.
		var near: Array = _sub_split(parts,key,flower_swap_sub) if flower_swap.x > 0.0 else []
		if flower_keep > 0.0 and flower_end > flower_fade.y and (flower_swap.x <= 0.0 or flower_cheap_split): parts = _rank_split(parts,flower_keep)
		if flower_swap.x > 0.0:
			for part: Dictionary in parts: part.cheap = true
			near.append_array(parts)
			parts = near
	var took := (Time.get_ticks_usec()-began)/1000.0
	_lock.lock()
	_done.append({"layer":layer,"key":key,"parts":parts,"ms":took,"ended":Time.get_ticks_usec()})
	_lock.unlock()

## One cell's grass (and, for the near layer, flowers) as plain batches, one
## a KitFlora tile, part and ring ([{key, tile, count, buffer, ring}]):
## KitFlora's Grow at the carpet's settings (`site_values`), its rings `rings`
## with `far_share` of the tufts in the far one (0: all near, with the
## flowers; 1: all far, the grass alone), its probe the cell's own height
## grid. Worker-safe. `native` (ZenScapeGrass, set up by native_config for
## these settings): the same cell placed natively (_grow_native). `got`: the
## cell's grid kept between calls for the same cell (filled by the first).
static func grow_cell(land_seed: int, key: Vector2i, site_values: Dictionary, rings: Vector4, far_share := 0.0, native: Object = null, got := {}) -> Array:
	var f: RefCounted = Field.new(land_seed)
	var sl: Vector2 = site_values.get("slope",SLOPE)
	var alp: Vector2 = site_values.get("alpine",ALPINE)
	var top := ALPINE_TOP if alp.y > 0.0 else HIGH.y
	var x0 := key.x*CELL
	var z0 := key.y*CELL
	var n := int(CELL)+1+PAD*2
	# The cell's 1 m grid in one call (LandField.grid; native when built):
	# heights, meadows and how far outside a river's water each node is
	# (land_field `last_river`): no tuft or flower on its bank.
	if not got.has("heights"): got.merge(f.grid(x0,z0,1.0,n,n,PAD))
	var hs: PackedFloat32Array = got.heights
	var ms: PackedFloat32Array = got.meadows
	var rs: PackedFloat32Array = got.river
	if native != null: return _grow_native(native,f,land_seed,key,got,site_values,far_share)
	# No turf in it at all (the sea, the peaks): nothing to grow.
	var any := false
	for h: float in hs:
		var over := h-Field.SEA_Y
		if over >= BEACH_CLEAR and over < top:
			any = true
			break
	if not any: return []
	var ragged := {}
	var lattice := {}
	# The paint's broad patch (260 m across) at the cell's corners, for its
	# alpine (EndlessPatch.alpine) eased across the cell.
	var b00 := Patch.broad(x0,z0)
	var b10 := Patch.broad(x0+CELL,z0)
	var b01 := Patch.broad(x0,z0+CELL)
	var b11 := Patch.broad(x0+CELL,z0+CELL)
	var probe := func(p: Vector2, _reach: float) -> float:
		var u := p.x-x0+PAD
		var v := p.y-z0+PAD
		var i := clampi(floori(u),1,n-3)
		var j := clampi(floori(v),1,n-3)
		var fx := clampf(u-i,0.0,1.0)
		var fz := clampf(v-j,0.0,1.0)
		var k := j*n+i
		var h00 := hs[k]
		var h10 := hs[k+1]
		var h01 := hs[k+n]
		var h11 := hs[k+n+1]
		# As the land's mesh splits each quad: (00, 10, 01) and (10, 11, 01).
		var h := h00+fx*(h10-h00)+fz*(h01-h00) if fx+fz <= 1.0 else h11+(1.0-fx)*(h01-h11)+(1.0-fz)*(h10-h11)
		var over := h-Field.SEA_Y
		if over < BEACH_CLEAR: return NAN
		# The slope as the land's normals have it (central differences),
		# at the nearer node.
		var c := (j+roundi(fz))*n+i+roundi(fx)
		# By a river: none on its bank's stones (EndlessPatch.river_bank, as
		# the ground paints them), a tuft or two leaning out over their edge.
		if rs[c] < 12.0 and rs[c] < Patch.river_bank(p.x,p.y)*0.85: return NAN
		var up := 2.0/Vector3(hs[c-1]-hs[c+1],2.0,hs[c-n]-hs[c+n]).length()
		var high := 1.0
		if alp.y <= 0.0: high = 1.0-smoothstep(HIGH.x,HIGH.y,over)
		elif over > Patch.ALPINE_FROM:
			var bx := clampf((p.x-x0)/CELL,0.0,1.0)
			var bz := clampf((p.y-z0)/CELL,0.0,1.0)
			var broad := lerpf(lerpf(b00,b10,bx),lerpf(b01,b11,bx),bz)
			high = 1.0-smoothstep(alp.x,alp.y,Patch.alpine_of(over,broad))
			if high <= 0.0: return NAN
		# Near the rock (not with --grass-cover=old): its edge as the ground
		# paints it, ragged (EndlessPatch.rock_ragged, kept per node), so the
		# tufts stop where its tongues start.
		if alp.y > 0.0 and up < ROCK_NEAR:
			if up < sl.x-Patch.RAGGED_MOST: return NAN
			if not ragged.has(c):
				ragged[c] = Patch.rock_ragged(Vector3(x0+c%n-PAD,hs[c],z0+c/n-PAD),lattice)
			up += ragged[c]
		var keep := smoothstep(sl.x,sl.y,up)*high*smoothstep(BEACH_CLEAR,BEACH_CLEAR+BEACH_RAMP,over)
		if keep <= 0.0: return NAN
		if keep < 1.0 and float(hash(Vector2i(roundi(p.x*7.0),roundi(p.y*7.0)))%10007)/10007.0 > keep: return NAN
		return h-SINK
	var site := KitFlora.Site.new()
	var flowers: bool = site_values.get("flowers",true) and far_share < 1.0
	var patches: float = site_values.get("patches",1.0)
	for k: String in site_values:
		if not k in ["flowers","patches","flower_tall","slope","alpine","sub","alp"]: site.set(k,site_values[k])
	site.plain = true
	site.probe = probe
	# The drifts (Patch `bloom`) read off a TINT_STEP m grid of the cell,
	# for the flowers and the far ring's tufts.
	var tg := int(CELL/TINT_STEP)+1
	var blooms := PackedVector2Array()
	if Patch.bloom_amount > 0.0:
		blooms.resize(tg*tg)
		for tj in tg:
			for ti in tg: blooms[tj*tg+ti] = Patch.bloom(x0+ti*TINT_STEP,z0+tj*TINT_STEP)
	var bloom_at := func(p: Vector2) -> Vector2:
		var u := clampf((p.x-x0)/TINT_STEP,0.0,tg-1.001)
		var v := clampf((p.y-z0)/TINT_STEP,0.0,tg-1.001)
		var i := int(u)
		var j := int(v)
		var fu := u-i
		var fv := v-j
		var w := lerpf(lerpf(blooms[j*tg+i].x,blooms[j*tg+i+1].x,fu),lerpf(blooms[(j+1)*tg+i].x,blooms[(j+1)*tg+i+1].x,fu),fv)
		return Vector2(w,blooms[(j+roundi(fv))*tg+i+roundi(fu)].y)
	if blooms.is_empty():
		site.flower_drift = flower_drift
	else:
		# (The far layer's flowers are dropped: none sown there.)
		site.flower_tries = BLOOM_TRIES if flowers else 0.0001
		site.flower_drift = func(p: Vector2) -> float: return 1.0+(BLOOM_PEAK-1.0)*float(bloom_at.call(p).x)
		site.flower_kind = func(p: Vector2, _kind: String) -> Array:
			var b: Vector2 = bloom_at.call(p)
			if b.x < BLOOM_KIND: return []
			if float(hash(Vector2i(roundi(p.x*53.0),roundi(p.y*53.0)))%10007)/10007.0 < BLOOM_COMPANION: return []
			var k: Array = Patch.KINDS[int(b.y)]
			return [k[0],k[1]]
	# The flowers stand above the taller grass (a little height variety).
	var lift_by: float = site_values.get("flower_tall",1.0)
	if not is_equal_approx(lift_by,1.0):
		site.flower_lift = func(p: Vector2) -> float:
			var h := float(hash(Vector2i(roundi(p.x*31.0),roundi(p.y*31.0)))%10007)/10007.0
			return 1.0+(lift_by-1.0)*(FLOWER_LIFT.x+(FLOWER_LIFT.y-FLOWER_LIFT.x)*h)
	site.box = Rect2(x0,z0,CELL,CELL)
	site.rim = 0.0
	site.lod = rings
	site.lod_share = far_share
	site.lod_grow = FAR_GROW
	site.lod_soft = SOFT
	# The outline well round the cell, so no rim (wild grass, the rim's
	# keep) falls inside it: the carpet runs on across cells.
	var g := 16.0
	var outline := PackedVector2Array([Vector2(x0-g,z0-g),Vector2(x0+CELL+g,z0-g),Vector2(x0+CELL+g,z0+CELL+g),Vector2(x0-g,z0+CELL+g)])
	var job := KitFlora.Grow.new(hash([land_seed,"endless_grass",far_share,key]) & 0xffffff,null,[],[outline],site)
	while not job.step(-1): pass
	# The draw's node: unused for plain batches, and never in a tree, so
	# freed here (each cell left one leaked at exit).
	if job.node != null: job.node.free()
	# The painted ground's patches on each tuft (Patch `tint`), read off a
	# TINT_STEP m grid of the cell.
	var tints := PackedColorArray()
	tints.resize(tg*tg)
	for tj in tg:
		for ti in tg:
			var c := (int(tj*TINT_STEP)+PAD)*n+int(ti*TINT_STEP)+PAD
			var x := x0+ti*TINT_STEP
			var z := z0+tj*TINT_STEP
			var y := hs[c]
			var normal := Vector3(hs[c-1]-hs[c+1],2.0,hs[c-n]-hs[c+n]).normalized()
			var vc: Color = f.colour(x,z,y,normal.y,ms[c])
			var hue := Vector3(pow(vc.r,2.2),pow(vc.g,2.2),pow(vc.b,2.2))
			tints[tj*tg+ti] = Color.WHITE.lerp(Patch.tint(x,z,ms[c],y-Field.SEA_Y,normal.y,hue),patches)*TUFT_TONE
	# Each of KitFlora's tile batches kept (KitFlora.TILE m), so each
	# culls on its own by the view and its ring's reach.
	var out := []
	for part: Dictionary in job.parts:
		var grass := str(part.key).begins_with("grass")
		# The far layer is the grass alone (its flowers are the near's).
		if far_share >= 1.0 and (not grass or int((part.get("ring",{}) as Dictionary).get("ring",0)) != 2): continue
		if not grass and not flowers: continue
		var buffer: PackedFloat32Array = part.buffer
		if grass:
			for k in range(0,buffer.size(),16):
				var u := clampf((buffer[k+3]-x0)/TINT_STEP,0.0,tg-1.001)
				var v := clampf((buffer[k+11]-z0)/TINT_STEP,0.0,tg-1.001)
				var i := int(u)
				var j := int(v)
				var a := tints[j*tg+i].lerp(tints[j*tg+i+1],u-i)
				var b := tints[(j+1)*tg+i].lerp(tints[(j+1)*tg+i+1],u-i)
				var t := a.lerp(b,v-j)
				# In a drift some of the far ring's tufts are in flower:
				# its colour (the near ring's flowers are drawn).
				if far_share >= 1.0 and not blooms.is_empty():
					var bl: Vector2 = bloom_at.call(Vector2(buffer[k+3],buffer[k+11]))
					# (Marked by its alpha, (kind+1)/16: the far material
					# puts the colour on its upper blades, endless_tuft_far.)
					if bl.x > 0.0 and float(hash(Vector2i(roundi(buffer[k+3]*37.0),roundi(buffer[k+11]*37.0)))%10007)/10007.0 < bl.x*FAR_WASH:
						buffer[k+15] = (int(bl.y)+1)/16.0
				buffer[k+12] *= t.r
				buffer[k+13] *= t.g
				buffer[k+14] *= t.b
		var sub_m: float = site_values.get("sub",0.0)
		if grass and far_share < 1.0 and sub_m > 0.0:
			out.append_array(_split(part.key,part.tile,buffer,part.get("ring",{}),sub_m))
		else:
			out.append({"key":part.key,"tile":part.tile,"count":part.count,"buffer":buffer,"ring":part.get("ring",{}),"box":_roots_box(buffer)})
	return out

## grow_cell placed natively (ZenScapeGrass `grow_cell`, native/terrain_kernels/
## grass_cell.h): the grass parts as grow_cell makes them; the flowers and seed
## heads it keeps come back as records, drawn here by KitFlora's Draw.
static func _grow_native(native: Object, f: RefCounted, land_seed: int, key: Vector2i, got: Dictionary, site_values: Dictionary, far_share: float) -> Array:
	var x0 := key.x*CELL
	var z0 := key.y*CELL
	var n := int(CELL)+1+PAD*2
	var cell := {"x0":x0,"z0":z0,"n":n,"pad":PAD,"seed":hash([land_seed,"endless_grass",far_share,key]) & 0xffffff,
		"heights":got.heights,"river":got.river,"meadows":got.meadows}
	cell.merge(got.get("dither",{}))
	# The native field (in the regions world, the region's own where the cell
	# lies wholly in one; in the band the blend's colours, below).
	var nf: Object = f.native_impl_in(x0-PAD,z0-PAD,x0+CELL+PAD,z0+CELL+PAD)
	if nf != null: cell.field = nf
	elif site_values.has("alp") and bool((site_values.alp as Dictionary).get("proud",false)):
		# The alpine tufts' proud crowns read the land 40 m round the cell
		# (Cell ALP_PROUD_*), here off the field; none needed well inside the
		# Peak's zone (no snow caps there).
		var zone: Vector4 = (site_values.alp as Dictionary).get("zone",Vector4.ZERO)
		var inside := zone.w > 0.5 and Vector2(x0+CELL*0.5-zone.x,z0+CELL*0.5-zone.y).length() < zone.z-650.0
		if not inside:
			if not got.has("ring"): got.ring = f.grid(x0-40.0,z0-40.0,8.0,19,19,0).heights
			cell.ring = got.ring
	if nf != null: pass
	elif got.has("colours"): cell.colours = got.colours
	else:
		# The ground's colour on the tint grid (the native field reads it itself).
		var hs: PackedFloat32Array = got.heights
		var ms: PackedFloat32Array = got.meadows
		var tg := int(CELL/TINT_STEP)+1
		var xs := PackedFloat64Array()
		var zs := PackedFloat64Array()
		var ys := PackedFloat32Array()
		var ups := PackedFloat32Array()
		var mds := PackedFloat32Array()
		xs.resize(tg*tg)
		zs.resize(tg*tg)
		ys.resize(tg*tg)
		ups.resize(tg*tg)
		mds.resize(tg*tg)
		for tj in tg:
			for ti in tg:
				var c := (int(tj*TINT_STEP)+PAD)*n+int(ti*TINT_STEP)+PAD
				var normal := Vector3(hs[c-1]-hs[c+1],2.0,hs[c-n]-hs[c+n]).normalized()
				var t := tj*tg+ti
				xs[t] = x0+ti*TINT_STEP
				zs[t] = z0+tj*TINT_STEP
				ys[t] = hs[c]
				ups[t] = normal.y
				mds[t] = ms[c]
		var cols: PackedColorArray = f.colours(xs,zs,ys,ups,mds)
		cell.colours = cols
		got.colours = cols
	var r: Dictionary = native.grow_cell(cell)
	var out: Array = r.parts
	var recs: PackedFloat64Array = r.records
	var flowers: bool = site_values.get("flowers",true) and far_share < 1.0
	if recs.is_empty() or not flowers: return out
	var assets: PackedStringArray = native.assets()
	var records := []
	var ground := KitFlora.Ground.new()
	for i in range(0,recs.size(),20):
		var item := {"id":records.size()+1,"asset":assets[int(recs[i])],"x":recs[i+1],"z":recs[i+2],"angle":recs[i+3],"scale":recs[i+4]}
		if recs[i+6] > 0.5: item.tint = NativeObjectPose.encode_tint(Color(recs[i+7],recs[i+8],recs[i+9]))
		if recs[i+10] > 0.5: item.pose = NativeObjectPose.make(Basis(Vector3(recs[i+11],recs[i+12],recs[i+13]),Vector3(recs[i+14],recs[i+15],recs[i+16]),Vector3(recs[i+17],recs[i+18],recs[i+19])),0.0)
		ground.heights[item.id] = recs[i+5]
		records.append(item)
	var draw := KitFlora.Draw.new(records,ground,0.0)
	draw.plain = true
	draw.step(-1)
	draw.node.free()
	for part: Dictionary in draw.parts:
		var buffer: PackedFloat32Array = part.buffer
		out.append({"key":part.key,"tile":part.tile,"count":part.count,"buffer":buffer,"ring":part.get("ring",{}),"box":_roots_box(buffer)})
	return out

## The box (world x, z) round a batch buffer's roots.
static func _roots_box(buffer: PackedFloat32Array) -> Rect2:
	if buffer.size() < 16: return Rect2()
	var x0 := buffer[3]
	var x1 := x0
	var z0 := buffer[11]
	var z1 := z0
	for k in range(16,buffer.size(),16):
		x0 = minf(x0,buffer[k+3])
		x1 = maxf(x1,buffer[k+3])
		z0 = minf(z0,buffer[k+11])
		z1 = maxf(z1,buffer[k+11])
	return Rect2(x0,z0,x1-x0,z1-z0)

## A batch split into `size` m tiles by its roots, each a part with its box
## and its tile ("sub").
static func _split(key: String, tile: Vector2i, buffer: PackedFloat32Array, ring: Dictionary, size: float) -> Array:
	var by := {}
	for k in range(0,buffer.size(),16):
		var t := Vector2i(floori(buffer[k+3]/size),floori(buffer[k+11]/size))
		if not by.has(t): by[t] = []
		(by[t] as Array).append(k)
	var out := []
	for t: Vector2i in by:
		var at: Array = by[t]
		var b := PackedFloat32Array()
		for k: int in at: b.append_array(buffer.slice(k,k+16))
		out.append({"key":key,"tile":tile,"count":at.size(),"buffer":b,"ring":ring,"box":_roots_box(b),"sub":t})
	return out
