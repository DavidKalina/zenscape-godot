extends Node3D
## The gray box pirate ship (docs/design/endless-flight/pirate-ship-handoff.md):
## plain blocks sailing an oval over the deep water west of the Horn. Its
## broadsides fire on the plane; a surge roll breaks the crack in either end and
## the plane flies the gun deck down the ship's length and bursts out of the other.
## A hazard, not an enemy: no health, no damage, no crash from a ball.
##
## Its frame: origin at the waterline amidships, -z the bow, +z the stern, x
## starboard. Its solid is three records in LandArches `loose`, whose pos, cos and
## sin are rewritten each frame (`before`), so plane_ground, _blocked, the camera
## and SurgeSmash `_strike` all read the ship where it is now, and the plane is
## neither carried nor pushed: the ship's move is about 0.15 m a frame, inside
## the pad the solids are grown by. The wing rays get a StaticBody on layer 1
## that goes with the node.
##
## She rides the swell (`rock`, ROCK_*, `_ride_step`): the sea under her fitted to
## a heave, pitch and roll, eased through heavy springs, on the node itself, so
## the model, guns, plates, shards, StaticBody and `local` all go with it, and
## her records carry her whole frame (`xf`, `inv`) for LandArches to read.
##
## A record's `strike` is what SurgeSmash `_hit` calls for a plate. The other
## plate stays stone, but the surge is held hot while the plane is in the
## corridor, so it breaks too on the way out. Both plates come back once the
## plane is RESEAL_FAR m off (nothing is saved: fly it again).
##
## Both plates open with no ring left aboard sinks her (`state`, `_sink`): the
## ring taken, or a ship that never had it. A miss of the ring leaves her to
## reseal. She settles by the end broken last, lists away from the plane and goes
## under in SINK_S s (`sink_pose`). Her guns stop at once. In a sink the `loose`
## record is off and `wreck_ground`, `wreck_inside` and the StaticBody follow her
## true tilt, and a touch of her is a glance (`deck_way_off`), never a crash.
## RETURN_S s after she's gone a fresh ship comes up on the route where the eye
## can't see it happen (`_return_spot`). The ring is one find in the book: ships
## after it carry none, and sinking one pays SINK_POINTS (NearMiss `prize`).
##
## Her look is assets/models/pirate_ship.glb on the moving node (`_dress`), or the
## gray box's blocks with --ship-blocks. Either way `solids()` alone is what she
## collides by. Hull guns fire from the glb's `Gun_*` empties, deck guns lob from
## its `DeckGun_*` (stand-ins while it has none; ship-guns-handoff.md), and a burst
## throws the plate's `CrackPlug_*` shards (`_throw`), which a reseal puts back.
##
## Two sail at once (CoastSites `ships`), each one of these on its own route, with
## its own guns, plates, sink and return. They share meshes and materials (`twin`),
## and each keeps its own BALLS. What only one may set is CoastSites' to pick: the
## near miss's `skim_scale` (`skim`, the most of them) and the eye (`watch`, newest
## sink).
##
## The lesson's temper (`lesson`; tutorial_land.gd at PARRY, docs/ship/spec-ship.md
## round 3): at anchor on a lake in the meadow (`speed` 0, `sea_y` the lake's,
## `rock` 0), hull guns only, one ball in the air at a time with LESSON_GAP s
## between, slower (LESSON_BALL m/s) and turning onto the plane as it comes
## (LESSON_HOME), only at a plane coming her way, a softer knock on a hit, no
## skim bonus near her (it filled the gauge before GAUGE); `quiet` holds her
## fire; sunk she stays gone.
##
## Handles: `coast/ship` (the ship, moved by its route), `coast/ship-route` (the
## oval's middle; a move in the layout file carries the whole route); the second's
## are `coast/ship2` and `coast/ship2-route`. The relic is the finds row `ship-hold`,
## anchored to `coast/ship`, so she alone carries it (`carries`).

const WorldScale = preload("res://scripts/world_scale.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const SmashBreaks = preload("res://scripts/breaks/smash_breaks.gd")
const LandHalls = preload("res://scripts/endless/land_halls.gd")
const Parry = preload("res://scripts/endless/parry.gd")

## A plate broken (`stern` or `bow`).
signal broke(part: String)
## She has started down / a fresh ship is back on the route.
signal sinking
signal returned

const MODEL := "res://assets/models/pirate_ship.glb"
const ShipSails = preload("res://scripts/endless/ship_sails.gd")
## The cast ball (art/blender/ship/ball_build.py), and how fast it tumbles (rad/s):
## look only, so the iron's marks turn over in flight.
const BALL_MODEL := "res://assets/models/pirate_ball.glb"
const BALL_TUMBLE := 3.0
## The guns' look: the muzzle blast, a ball's trail of smoke, the splash, the cut
## guns (ship_guns.gd, docs/design/endless-flight/ship-guns-handoff.md).
const ShipGuns = preload("res://scripts/endless/ship_guns.gd")
## A gun's tell before it fires, and the sink's mist (look only): their shader,
## and the tell's core radius (m, readable from 300 m).
const PUFF_SHADER := "res://assets/models/pirate_ship/muzzle_puff.gdshader"
const FLASH_R := 3.8
## Where the rigging stops drawing (m); the glb can't carry it.
const RIGGING_FAR := 450.0
## Where what can't be told from outside stops drawing (m): the gun deck's inside and
## guns, a plate's shards. 111 draw calls at 2 km on a ship 40 px long, most of them
## these (handoff, What it costs).
const INNER_FAR := 700.0
## The gun deck's inside casts shadows only while the eye is within this of her middle
## (m): from farther out they fall where the hull's own already do, at 24k triangles a
## shadow pass.
const INNER_SHADE := 120.0
## The model's sway, for the eye only: roll, pitch (rad), each one's period (s).
const SWAY := Vector2(0.014,0.005)
const SWAY_S := Vector2(9.0,13.0)
## Her ride on the swell (`rock`, --ship-rock=K; 0 is the fixed height and the
## SWAY above). The sea is read at ROCK_X across by ROCK_Z along her (her frame,
## m; the body's long waves are 52 to 118 m, she's 130) every ROCK_EVERY frames,
## the two ships on turns, and fitted to a heave, a pitch and a roll. Each goes
## through a damped spring of its own: natural period (s), damping ratio
## (heave, pitch, roll). Her whole frame rides it, solids and all.
const ROCK_X := [-11.0,11.0]
const ROCK_Z := [-60.0,-40.0,-20.0,0.0,20.0,40.0,60.0]
const ROCK_EVERY := 2
const ROCK_T := Vector3(8.0,8.5,11.0)
const ROCK_DAMP := Vector3(0.7,0.5,0.32)
## At `rock` 1: her pitch and roll past the sea's own slope under her, so it reads
## from the air (the heave is the sea's, at most); her lean out of the route's
## turns (rad).
const ROCK_GAIN := Vector2(3.0,3.0)
const ROCK_LEAN := 0.03
## A thrown shard: fall (m/s²), what a bounce keeps, how fast the floor stops it
## (1/s), its room from the gun deck's walls (m), still under this (m/s).
const SHARD_DROP := 16.0
const SHARD_BOUNCE := 0.35
const SHARD_RUB := 4.0
const SHARD_ROOM := 0.6
const SHARD_STILL := 1.0

const SEA_Y := -40.0
## The route: the oval's middle (world XZ), its straights' length and its ends'
## radius (m), the speed along it (m/s).
const ROUTE_AT := Vector2(2050.0,3850.0)
const ROUTE_LEG := 900.0
const ROUTE_R := 200.0
const SPEED := 9.0
## The second ship's oval: its middle, its straights' length (m), its turn (rad) off
## the first's: the deep basin south-east of her past the isles off the Horn, which
## the first's length doesn't fit.
const ROUTE2_AT := Vector2(3500.0,4700.0)
const ROUTE2_LEG := 500.0
const ROUTE2_TURN := -PI*0.25
## The gun deck, in toy widths (WorldScale `opening`): wide, high; long is by the
## clock, about 2 s at Boost's 57 m/s. Toy 7 by 4.5 is a cracked wall's room.
const TOY_WIDE := 9.0
const TOY_HIGH := 5.0
const LONG := 110.0
## Over the waterline: the gun deck's floor; the hull's draught; the plates' and
## the top deck's thickness (m).
const FLOOR_Y := 3.0
const DRAUGHT := 6.0
const PLATE := 1.5
## How far from a shut plate a touch stops being a glance.
const END_ROOM := 2.0
## The most the plane is held off a corridor wall in a frame (`_keep_off_walls`, m).
const KEEP_MOST := 0.8
const DECK := 2.0
## The hull's half breadth at its widest, by the guns (ship_build.py BEAM), and at
## the waterline amidships.
const BEAM := 14.5
const BEAM_WET := 12.9
## Her solid but the plates: the model's own boxes, fitted to its shape by
## ship_build.py (`fit_solids`), the gun deck cut at its 18 m (a corridor sized
## otherwise keeps the model's walls).
const SOLIDS := preload("res://assets/models/pirate_ship/ship_solids.gd")
## The prow's tunnel past the bow's plate (ship_build.py TUNNEL_*): its walls' half
## width, where they end by the lips and at their longest (the mouth's edge, half
## way up), its floor on the lower lip and roof under the upper, and where each lip
## ends at the stem (m, her frame's -z). Over FUNNEL m forward of the plate
## (ship_build.py FUNNEL_LEN) walls, floor and roof close in to the gun deck's at the
## plate (`_way_at`), so no face there looks forward and an off-centre plane from the
## bow glances in.
const TUNNEL_X := 10.4
const TUNNEL_MOUTH := 61.3
const TUNNEL_END := 62.5
const FUNNEL := 6.0
const TUNNEL_LO := 2.6
const TUNNEL_HI := 13.4
const LIP_LO := 72.65
const LIP_HI := 75.35
## Over the stern's exit, the lower balcony's underside, out to how far aft.
const BALCONY := Vector2(15.8,59.4)
## The hull guns' ports along her (z), for the gray box (the glb's `Gun_*` are at
## ship_build.py PORTS, Godot z = -y).
const GUNS_Z := [-32.0,0.0,32.0]
## Hull guns a side (`Gun_L_01..03`, 01 the sternmost).
const HULL_GUNS := 3
## Hull guns: over the waterline (m); firing from MIN to MAX m off, within ARC rad
## of abeam; a shot every EVERY s; TELL s of flash before it; a gun rests REST s.
const GUN_Y := 8.0
## The hull guns' muzzles off her middle (ship_build.py GUN_X), for the gray box.
const GUN_X := 16.25
const RANGE := Vector2(60.0,520.0)
const ARC := 1.05
const EVERY := 1.4
const TELL := 0.85
const REST := 3.0
## Hull balls: m/s, drop (m/s²), radius (m), the most at once, seconds aloft.
const BALL_SPEED := 110.0
const BALL_DROP := 6.0
const BALL_R := 1.5
const BALLS := 24
const BALL_LIFE := 7.0
## Deck guns, two a side on the top deck, lob: the glb's `DeckGun_*` (ship_build.py
## DECK_GUN_*, each on a dais). Where it has none (the gray box), stand-ins at these
## pivots (starboard x, z; port mirrored; on the top deck), their trunnions
## DECK_LIFT m over the pivot and the muzzle DECK_MUZZLE m on from them, the hull
## gun's barrel DECK_SIZE times over so they read over the rail from off her beam;
## laid DECK_REST rad up at rest.
const DECK_GUNS := [Vector2(7.6,14.0),Vector2(7.6,-11.0)]
const DECK_LIFT := 3.1
const DECK_MUZZLE := 5.6
const DECK_SIZE := 1.45
const DECK_REST := 0.22
## How far a deck gun swings off abeam, how low and high it lays (rad), how fast
## it swings and lays (rad/s), and how close to its lay it fires (rad). The build
## checks the barrel clear of her rails and rigging over this swing and lay (a lob
## never lays under about 0.25).
const DECK_SWING := 1.05
const DECK_RAISE := Vector2(0.2,0.95)
const DECK_TURN := Vector2(1.4,1.0)
const DECK_AIMED := 0.12
## Lobs: from MIN to MAX m off; one every LOB_EVERY s; a deck gun rests LOB_REST s;
## the fall (m/s², the hull's is BALL_DROP) and the time aloft to the plane at MIN
## and at MAX m (s). Thrown to meet the plane where it'll be if it holds its line.
const LOB_RANGE := Vector2(110.0,560.0)
const LOB_EVERY := 2.6
const LOB_REST := 5.0
const LOB_DROP := 28.0
const LOB_T := Vector2(2.3,4.0)
## A gun's kick (look only): how far back it goes (m, hull and deck), how long it
## takes, holds, then runs out again (s).
const KICK := Vector2(1.4,1.1)
const KICK_S := Vector3(0.06,0.25,1.4)
## Shots heard: how far a boom and a splash carry (m to half as loud). A lob
## whistles coming down inside WHISTLE_NEAR m of the plane, high to low.
const BOOM_HEARD := 260.0
const SPLASH_HEARD := 140.0
const WHISTLE := "res://assets/audio/kit/air-whistle-loop.wav"
const WHISTLE_NEAR := 170.0
const WHISTLE_PITCH := Vector2(2.1,1.2)
const WHISTLE_GAIN := 0.55
## How far past a touch of the plane (WorldScale.span*0.5 off its middle) a pass
## still scores (NearMiss `shot_pass`).
const PASS_REACH := 14.0
## A ball's hit: speed kept, the shove (m/s), the turn off line (rad), the view's
## shake and punch.
const HIT_KEEP := 0.8
const HIT_SHOVE := 11.0
const HIT_YAW := 0.3
const HIT_FEEL := Vector2(0.03,9.0)
## Skimming within SKIM_NEAR m of the ship pays this many times the rate.
const SKIM_NEAR := 500.0
const SKIM_SCALE := 8.0
## Past this far (m) the plates are back.
const RESEAL_FAR := 300.0
## The finds row aboard her.
const RELIC := "ship-hold"
## Paid for sinking a ship with no ring: a line of its own, no multiplier, past
## the corridor's own line (about 15,000); METER_FULL is 4000, so it fills the meter.
const SINK_POINTS := 25000.0
## When the points land (s into the sink): the corridor's line has banked by then.
const SINK_PAY_AT := 4.0
## The toast at the start of a sink, with the ring just taken and without.
const SINK_WORDS := "The ring is yours. She's going down"
const SINK_WORDS_BARE := "She's going down"
## The prize's name on the read-out.
const SINK_LINE := "Ship sunk"
## The sink, seconds: the least till she's gone (she's gone when she's under, about
## 20 s), how long she keeps any way on.
const SINK_S := 19.0
const SINK_WAY_S := 9.0
## Her pose: [t s, m down, pitch, roll (degrees)], eased through (`sink_pose`). A
## lurch and a recovery, a slow settle by one end, the list growing, then the plunge.
const SINK_KEYS := [
	[-4.0,0.0,0.0,0.0],[0.0,0.0,0.0,0.0],[0.8,0.7,0.7,1.8],[2.4,0.5,0.9,0.7],[6.0,3.0,2.8,4.5],
	[10.5,8.5,6.5,10.0],[14.5,16.0,11.5,17.0],[18.0,31.0,19.0,25.0],[20.5,50.0,27.0,31.0],[22.5,78.0,33.0,36.0],[26.0,120.0,38.0,40.0],
]
## Her shudder on the lurch: rad, rad/s, how fast it dies (1/s).
const SHUDDER := Vector3(0.006,27.0,0.7)
## Water and wreckage: seconds between beats; how far off (m) the wash is bothered with.
const SINK_BEAT := 0.35
const SINK_NEAR := 1500.0
## What breaks in her as she goes: [t s, sound, gain, pitch].
const SINK_CUES := [
	[1.2,"creak",1.0,0.5],[3.4,"thump",1.0,0.5],[5.6,"creak",1.0,0.42],[8.2,"crash",0.6,0.5],[9.8,"creak",1.1,0.38],
	[12.6,"thump",1.1,0.45],[14.2,"crash",0.8,0.42],[16.0,"creak",1.2,0.34],[18.2,"crash",1.0,0.36],[20.0,"thump",1.3,0.36],
]
## Sound's reach: flat gain at 0 m, halved every this far (m).
const SINK_HEARD := 350.0
## Mist off her waterline: how many at once; radius (m), rise (m/s), life (s).
const MISTS := 16
const MIST_R := Vector2(0.9,2.4)
const MIST_RISE := 5.0
const MIST_LIFE := 4.5
## A mist's discs thin as the eye comes in (muzzle_puff `near`, in disc radii): the
## sink's first mist stands on the plane's way out of the bow.
const MIST_NEAR := Vector2(0.7,2.2)
## Planks left afloat: how many, how long they stay (s), how fast they go down (m/s).
const PLANKS := 22
const PLANK_LIFE := 40.0
const PLANK_SINK := 0.5
const PLANK_TURNS := 5
## The wreck's reach from her middle (m): past it nothing of her is met.
const WRECK_REACH := 125.0
## Her far points (her frame), the mast tops, poop, bow and the ensign staff's head, for "all under".
const HIGH_POINTS := [Vector3(0.0,104.0,2.0),Vector3(0.0,92.0,-30.0),Vector3(0.0,80.0,33.0),Vector3(0.0,32.0,56.0),Vector3(0.0,25.0,-56.0),Vector3(0.0,50.5,60.0)]
## Her return: least seconds after she's gone (--ship-return=S), how often it's tried
## (s), how many spots round the route. A spot is good at RETURN_ANY m off the eye,
## or at RETURN_NEAR m off and outside the view (RETURN_CONE: the cosine off its axis).
const RETURN_S := 60.0
const RETURN_POLL := 0.5
const RETURN_SPOTS := 24
const RETURN_ANY := 4000.0
const RETURN_NEAR := 600.0
const RETURN_CONE := 0.17
## Nor within this far (m) of the other ship: past both broadsides' reach.
const RETURN_APART := 1050.0
## The eye in a sink (`watch`): from when (s), how slowly it eases over and back (s),
## how far off her axis she sits so the plane doesn't hide her (rad), past how far
## off (m) it gives up, how far ahead it checks the plane's way (s).
const WATCH_FROM := 1.0
const WATCH_EASE := 1.3
const WATCH_OFF := 0.16
const WATCH_FAR := 1300.0
const WATCH_AHEAD: Array[float] = [1.5,3.0,4.5]
const WATCH_ROOM := 10.0
## The lesson's temper: a ball's speed (m/s); the wait from one ball's end to
## the next gun's tell (s); how far off abeam she fires (rad), from how near
## to how far (m) and at a plane heading how far off her at most (rad); a hit's speed kept, shove (m/s) and turn (rad).
const LESSON_BALL := 60.0
const LESSON_GAP := 2.2
const LESSON_ARC := 1.3
const LESSON_RANGE := Vector2(70.0,480.0)
const LESSON_FACING := deg_to_rad(60.0)
const LESSON_HIT := Vector3(0.95,4.0,0.08)
## A lesson ball turns onto the plane as it comes, at most this fast (rad/s),
## so a turn after the shot doesn't leave it wide: the lesson is the roll's
## timing.
const LESSON_HOME := 0.6
## Where --ship-start puts the plane: off the beam (m), over the sea (m).
const START_OFF := 240.0
const START_ALT := 16.0

const HULL_C := Color(0.27,0.24,0.22)
const DECK_C := Color(0.42,0.38,0.33)
const GUNDECK_C := Color(0.5,0.47,0.42)
const RIB_C := Color(0.2,0.18,0.17)
const PLATE_C := Color(0.72,0.67,0.56)
const CRACK_C := Color(1.0,0.45,0.1)
const SAIL_C := Color(0.82,0.8,0.74)
const PLANK_C := Color(0.56,0.43,0.3)
const GUN_C := Color(0.09,0.09,0.1)
const LAMP_C := Color(1.0,0.75,0.4)
const PORT_C := Color(0.65,0.8,1.0)

enum {AFLOAT,SINKING,GONE}

var game: Node3D
## Her name in the layout file, the way her route's is `handle`-route.
var handle := "coast/ship"
## The lesson's temper (see the top), and her fire held; set before `setup`.
var lesson := false
var quiet := false
## The water she floats on (m) and her way along the route (m/s); set before `setup`.
var sea_y := SEA_Y
var speed := SPEED
## The other ship, or null: its meshes are hers, and she comes back clear of it.
var twin: Node3D
## What she'd have the near miss's skim rate at this frame (CoastSites `before`).
var skim := 1.0
## AFLOAT, SINKING (`sink_t` s in) or GONE (`gone_t` s since).
var state := AFLOAT
var sink_t := -1.0
var gone_t := 0.0
## The least wait in GONE (s).
var return_wait := RETURN_S
## The way along the route (m), and the frame now.
var along := 0.0
var way := Vector2.RIGHT
var yaw := 0.0
var _route := Transform3D.IDENTITY
var _leg := ROUTE_LEG
var _inv := Transform3D.IDENTITY
var wide := 18.0
var high := 10.0
## Counted, for the drivers: shots (lobs among them), hits, passes, ...
var fired := 0
var lobs := 0
var hits := 0
var passes := 0
## Parried balls that came home onto her (scripts/endless/parry.gd).
var shot_back := 0
var bursts := 0
var sinks := 0
var returns := 0
var paid := 0.0
## --full-meter: the meter filled again each time the plates come back, and once
## when the plane leaves a sinking ship, whose plates won't.
var refill := false
var _refilled := false
## Live balls: {node, at, v, drop (m/s²), lob, age, least, near (world, the plane
## there), done, trail (m to its next puff)}.
var balls: Array[Dictionary] = []
var _pool: Array[Node3D] = []
var _chunks: Array[Dictionary] = []
var _chunk_pool: Array[MeshInstance3D] = []
var _hull: Dictionary
## The glb's instance, null with --ship-blocks.
var _model: Node3D
## The one mesh every ball draws, its material on it; null with --ship-blocks.
var _ball_mesh: Mesh
## Thrown shards: {node, off (its plug in her frame), v (her frame), spin}.
var _shards: Array[Dictionary] = []
## part ("stern", "bow") -> {record, body, shape, look (blocks), plug and shards
## (model: {node, home}), open}.
var plates := {}
## Every gun: {kind ("hull", "deck"), side, z, flash (its tell), rest (s to ready),
## kick (s since it fired, -1 still), kick_node and kick_home (what recoils, and
## its rest)}; a hull gun's `at` (its muzzle, her frame) and `out` (its bore);
## a deck gun's `pivot` (her frame), `yaw_node` and `yaw_home`, `barrel` and
## `barrel_home`, `muzzle` (in the barrel's frame), `yaw`, `pitch`, `err` (rad
## off its lay).
var _guns: Array[Dictionary] = []
var _tells: Array[Dictionary] = []
## The one tell every gun draws; null with --ship-blocks.
var _flash_mesh: Mesh
var _every := 0.0
var _lob_every := 0.0
## The guns' look (ship_guns.gd), and a lob's whistle (null when muted).
var _fx: RefCounted
var _whistle: AudioStreamPlayer3D
var _plane_was := Vector3.INF
## The hull's StaticBody, off while she's gone.
var _hull_body: StaticBody3D
## This run: the ring aboard when its first plate broke; the plate broken last.
var _carried := false
var _last := "bow"
## The sink: bow (1) or stern (-1) down, the side she lists to (1 starboard), the
## next wash and cue, the plane past her solids (the deck flooded round it), the
## points yet to land, the moment's news for the frame's events.
var _end := 1.0
var _list := 1.0
var _beat := 0.0
var _cue := 0
var _ghost := false
var _pay := false
var _poll := 0.0
## The eye: looking on her now; the player has turned it (right stick, or the right
## mouse button) in this sink; it's handed back for the rest of this sink.
var watching := false
var _panned := false
var _handed_back := false
## What's left on the water, beside her so it stays when she's gone.
var _wake: Node3D
var _mist_mesh: Mesh
var _plank_mat: Material
## Hands the sails her way (null with --ship-blocks).
var _sails: RefCounted
## The model's `Interior` (null with --ship-blocks), its shadows on near (INNER_SHADE).
var _inner: GeometryInstance3D
var _mists: Array[Dictionary] = []
var _planks: Array[Dictionary] = []
## Her ride (ROCK_*): how much (0 off); Vector3(heave m, pitch, roll rad) now, its
## rate, where the sea would have it; the sea read afresh next step (a return); the
## frames counted for ROCK_EVERY; her yaw a step ago, for the lean.
var rock := 1.0
var ride := Vector3.ZERO
var _ride_v := Vector3.ZERO
var _ride_to := Vector3.ZERO
var _ride_fresh := true
var _ride_n := 0
var _yaw_was := NAN

## The oval at `s` m along: [Vector2 place (from its middle), Vector2 way]. 0 is
## the middle of the north straight, going +x. `a` is the straights' length.
static func route_pose(s: float, a := ROUTE_LEG) -> Array:
	var r := ROUTE_R
	var t := fposmod(s+a*0.5,2.0*a+TAU*r)
	if t < a: return [Vector2(t-a*0.5,-r),Vector2.RIGHT]
	t -= a
	if t < PI*r:
		var q := t/r
		return [Vector2(a*0.5+r*sin(q),-r*cos(q)),Vector2(cos(q),sin(q))]
	t -= PI*r
	if t < a: return [Vector2(a*0.5-t,r),Vector2.LEFT]
	t -= a
	var q := t/r
	return [Vector2(-a*0.5-r*sin(q),r*cos(q)),Vector2(-cos(q),-sin(q))]

## --ship-start: {at (XZ), heading, alt}, off the ship's beam, flying her way.
static func start_pose() -> Dictionary:
	var at := ROUTE_AT+(route_pose(0.0)[0] as Vector2)+Vector2(0.0,START_OFF)
	return {"at":at,"heading":atan2(-1.0,0.0),"alt":START_ALT}

## The ship's solids, in her frame: the hull's (the model's, SOLIDS: the hull in
## bands round the gun deck and the prow's tunnel, the castles, bulwarks, masts,
## the staff and the stern's dress), then each plate's.
static func solids(w: float, h: float) -> Dictionary:
	var half := w*0.5
	var roof := FLOOR_Y+h
	var end := LONG*0.5+PLATE
	if _hull_boxes.is_empty():
		for b: Array in SOLIDS.BOXES: _hull_boxes.append(_box(b[0],b[1],b[2],b[3],b[4],b[5]))
	return {"hull":_hull_boxes,"stern":[_box(-half,FLOOR_Y,LONG*0.5, half,roof,end)],"bow":[_box(-half,FLOOR_Y,-end, half,roof,-LONG*0.5)]}

static var _hull_boxes: Array[AABB] = []

static func _box(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> AABB:
	return AABB(Vector3(x0,y0,z0),Vector3(x1-x0,y1-y0,z1-z0))

## `at`, `leg` and `turn` are her route's middle, straights and turn; `first`, the
## ship built before her, if any.
func setup(g: Node3D, at := ROUTE_AT, label := "coast/ship", first: Node3D = null, leg := ROUTE_LEG, turn := 0.0) -> void:
	game = g
	name = "PirateShip"
	handle = label
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--ship-rock="): rock = maxf(a.trim_prefix("--ship-rock=").to_float(),0.0)
	twin = first
	_leg = leg
	if first != null: first.twin = self
	wide = WorldScale.opening(TOY_WIDE)
	high = WorldScale.opening(TOY_HIGH)
	var middle := Transform3D(Basis(Vector3.UP,turn),Vector3(at.x,sea_y,at.y))
	_route = LayoutOverrides.xform(handle+"-route",middle)
	var marker := Node3D.new()
	marker.name = "Route"
	marker.transform = _route
	get_parent().add_child(marker)
	LayoutOverrides.track(handle+"-route",marker,"coast",middle)
	_pose()
	LayoutOverrides.track(handle,self,"coast",transform)
	_build()
	_pose()
	var args: PackedStringArray = preload("res://scripts/launch_args.gd").user_args()
	refill = "--full-meter" in args
	for a: String in args:
		if a.begins_with("--ship-return="): return_wait = a.trim_prefix("--ship-return=").to_float()
	_ride_n = 0 if first == null else 1
	add_to_group(Parry.GROUP)

## The middle of the gun deck (her frame's y): the relic hangs here.
static func deck_mid(h: float) -> float:
	return FLOOR_Y+h*0.5

func _pose() -> void:
	var pose := route_pose(along,_leg)
	var p: Vector2 = pose[0]
	var d: Vector2 = pose[1]
	var wd: Vector3 = _route.basis*Vector3(d.x,0.0,d.y)
	way = Vector2(wd.x,wd.z)
	yaw = atan2(-wd.x,-wd.z)
	transform = Transform3D(Basis(Vector3.UP,yaw),_route*Vector3(p.x,0.0,p.y))
	if rock > 0.0:
		transform.basis = transform.basis*Basis.from_euler(Vector3(ride.y,0.0,ride.z))
		transform.origin.y += ride.x
	var shake := 0.0
	if sink_t >= 0.0:
		var s := sink_pose(sink_t)
		transform.basis = transform.basis*Basis.from_euler(Vector3(deg_to_rad(s.y)*-_end,0.0,deg_to_rad(s.z)*-_list))
		transform.origin.y -= s.x
		shake = SHUDDER.x*exp(-sink_t*SHUDDER.z)*sin(sink_t*SHUDDER.y)
	_inv = transform.affine_inverse()
	if _model != null:
		var t := along/SPEED
		if rock > 0.0: _model.rotation = Vector3(shake,0.0,shake*0.6)
		else: _model.rotation = Vector3(SWAY.y*sin(TAU*t/SWAY_S.y)+shake,0.0,SWAY.x*sin(TAU*t/SWAY_S.x)+shake*0.6)
	if _hull.is_empty(): return
	_place(_hull)
	for part: String in plates: _place(plates[part].record)

## Her record in `loose` where she is now; riding the swell, her whole frame too
## (LandArches reads `xf` and `inv` over `cos` and `sin`).
func _place(r: Dictionary) -> void:
	r.pos = position
	r.cos = cos(yaw)
	r.sin = sin(yaw)
	if rock > 0.0:
		r.xf = transform
		r.inv = _inv
	elif r.has("inv"):
		r.erase("xf")
		r.erase("inv")
	GroundNative.bump_loose()

## One step of her ride: the sea under her read (every ROCK_EVERY frames) and
## fitted, her lean from how fast she's turning, and the springs eased toward them.
func _ride_step(delta: float) -> void:
	if rock <= 0.0 or delta <= 0.0: return
	var turn := 0.0 if is_nan(_yaw_was) else wrapf(yaw-_yaw_was,-PI,PI)/delta
	_yaw_was = yaw
	_ride_n += 1
	if _ride_fresh or _ride_n%ROCK_EVERY == 0:
		_ride_to = sea_under()
		_ride_to = Vector3(_ride_to.x*minf(rock,1.0),_ride_to.y*ROCK_GAIN.x*rock,_ride_to.z*ROCK_GAIN.y*rock)
	# Turning to port (yaw growing) she leans out, to starboard: roll down that side.
	var to := _ride_to+Vector3(0.0,0.0,-ROCK_LEAN*rock*clampf(turn*ROUTE_R/SPEED,-1.5,1.5))
	if _ride_fresh:
		_ride_fresh = false
		ride = to
		_ride_v = Vector3.ZERO
		return
	var left := minf(delta,0.25)
	while left > 0.0:
		var dt := minf(left,1.0/30.0)
		left -= dt
		for i in 3:
			var w := TAU/ROCK_T[i]
			_ride_v[i] += (w*w*(to[i]-ride[i])-2.0*ROCK_DAMP[i]*w*_ride_v[i])*dt
			ride[i] += _ride_v[i]*dt

## The sea under her, level in her frame: Vector3(its mean height over the rest
## level, m; the pitch and roll (rad) of the plane fitted through it), read at
## ROCK_X by ROCK_Z. ZERO with no sea.
func sea_under() -> Vector3:
	var look: Variant = game.get("look")
	if look == null or look.water == null: return Vector3.ZERO
	var water: RefCounted = look.water
	var right := Vector3(cos(yaw),0.0,-sin(yaw))
	var back := Vector3(sin(yaw),0.0,cos(yaw))
	var sum := 0.0
	var sx := 0.0
	var sz := 0.0
	var xx := 0.0
	var zz := 0.0
	for z: float in ROCK_Z:
		for x: float in ROCK_X:
			var q := position+right*x+back*z
			var h: float = water.height_at(q.x,q.z)
			sum += h
			sx += x*h
			sz += z*h
			xx += x*x
			zz += z*z
	# Higher to starboard rolls her up that side (+z turn); higher astern, bow down.
	return Vector3(sum/float(ROCK_X.size()*ROCK_Z.size()),-atan(sz/zz),atan(sx/xx))

## The world's moment in her frame.
func local(p: Vector3) -> Vector3:
	return _inv*p

## Within the gun deck's walls, and between its ends (`pad` m past the stern's),
## or forward of it in the prow's tunnel and under its lips (`pad` m past the upper
## lip's solid, `lip_solid`).
func in_corridor(p: Vector3, pad := 0.0) -> bool:
	var l := local(p)
	if l.z > -LONG*0.5: return l.z < LONG*0.5+pad and absf(l.x) < wide*0.5 and l.y > FLOOR_Y-1.0 and l.y < FLOOR_Y+high+1.0
	return l.z > -lip_solid()-pad and absf(l.x) < TUNNEL_X and l.y > TUNNEL_LO-1.0 and l.y < TUNNEL_HI+1.0

## How far forward her upper lip's solid runs (m, her frame's -z): the last of
## SOLIDS' steps under TUNNEL_HI, which fit_solids takes past the model's LIP_HI.
static func lip_solid() -> float:
	if _lip_solid < 0.0:
		_lip_solid = LIP_HI
		for b: Array in SOLIDS.BOXES:
			if absf(float(b[1])-TUNNEL_HI) < 0.05: _lip_solid = maxf(_lip_solid,-float(b[2]))
	return _lip_solid

static var _lip_solid := -1.0

## The way through at `z` (her frame): Vector3(the walls' half width, the floor, the
## roof); the gun deck's, or the prow's tunnel's (in the funnel, closing in to the gun
## deck's at the plate), open at the sides past its mouth and underneath past the
## lower lip.
func _way_at(z: float) -> Vector3:
	if z > -LONG*0.5: return Vector3(wide*0.5,FLOOR_Y,FLOOR_Y+high)
	var t := _funnel(z)
	return Vector3(lerpf(wide*0.5,TUNNEL_X,t) if z > -TUNNEL_END else INF,lerpf(FLOOR_Y,TUNNEL_LO,t) if z > -LIP_LO else -INF,lerpf(FLOOR_Y+high,TUNNEL_HI,t))

## How open the prow's funnel is at `z` (her frame): 0 at the bow plate's face and
## aft of it, 1 from FUNNEL m forward of it on.
static func _funnel(z: float) -> float:
	return clampf((-z-LONG*0.5-PLATE)/FUNNEL,0.0,1.0)

## The way off the gun deck's (or the prow tunnel's) nearest wall, roof or floor,
## in the world, for FlightContact: a touch in there is glanced off, never a
## crash. In the funnel its faces lean to the bow, so the way off them leans that
## way too and a plane coming in is turned in along them. ZERO outside it, or within
## END_ROOM of a plate still shut, which stops the plane.
func deck_way_off(p: Vector3, what := "") -> Vector3:
	var l := local(p)
	if state == SINKING and not in_corridor(p): return _wreck_way_off(p,l,what)
	if state == GONE: return Vector3.ZERO
	# At the stem, as far forward as the lip's solid is grown round the plane (the
	# study's `solid_pad`): riding out under it, the plane still touches it there.
	var bow_reach := float(game.get("solid_pad")) if l.z < -LONG*0.5 and game.get("solid_pad") != null else 0.0
	if not in_corridor(p,bow_reach) or (state == AFLOAT and _by_shut_plate(l)): return Vector3.ZERO
	var w := _way_at(l.z)
	var wall := _wall_off(l)
	var side := wall.x
	var roof := w.z-l.y
	var floor_gap := l.y-w.y
	var t := _funnel(l.z)
	var lean := 1.0/FUNNEL if t > 0.0 and t < 1.0 else 0.0
	var off := Vector3(wall.y,0.0,wall.z)
	if roof < side and roof <= floor_gap: off = Vector3(0.0,-1.0,-(TUNNEL_HI-FLOOR_Y-high)*lean)
	elif floor_gap < side: off = Vector3(0.0,1.0,-(FLOOR_Y-TUNNEL_LO)*lean)
	return (transform.basis*off).normalized()

## The nearest wall to `l` (her frame) across the floor: Vector3(the gap from it, the
## way off it in x, in z): the gun deck's walls, the funnel's leaning in, the
## tunnel's to their end, then just past it the mouth's edge itself; INF where none.
func _wall_off(l: Vector3) -> Vector3:
	var s := signf(l.x)
	if l.z > -TUNNEL_END:
		var t := _funnel(l.z)
		var k := (TUNNEL_X-wide*0.5)/FUNNEL if t > 0.0 and t < 1.0 else 0.0
		var n := sqrt(1.0+k*k)
		return Vector3((_way_at(l.z).x-absf(l.x))/n,-s/n,-k/n)
	var c := Vector2(l.x-s*TUNNEL_X,l.z+TUNNEL_END)
	if c.length() < 0.01: return Vector3(0.0,-s,0.0)
	return Vector3(c.length(),c.x/c.length(),c.y/c.length())

## Within END_ROOM of a plate still shut (her frame): a touch there is the plate's,
## graded as anywhere. Open, it leaves the gun deck's walls and the funnel to glance.
func _by_shut_plate(l: Vector3) -> bool:
	if absf(absf(l.z)-LONG*0.5-PLATE*0.5) >= END_ROOM+PLATE*0.5: return false
	return not bool(plates["bow" if l.z < 0.0 else "stern"].open)

## One frame, before the surge and the plane's: she sails, the plates come back,
## the guns aim and fire.
func before(delta: float) -> void:
	if state == GONE:
		skim = 1.0
		_wait(delta)
		return
	if state == SINKING: sink_t += delta
	along += speed*delta*(1.0 if state == AFLOAT else clampf(1.0-sink_t/SINK_WAY_S,0.0,1.0))
	_ride_step(delta)
	_pose()
	if _sails != null: _sails.step(delta,position,way,state == SINKING)
	if _inner != null:
		var shade := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if game.camera.global_position.distance_to(position) < INNER_SHADE else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _inner.cast_shadow != shade: _inner.cast_shadow = shade
	_keep_off_walls()
	var p: Vector3 = game.plane.position
	var d := p.distance_to(position)
	skim = SKIM_SCALE if state == AFLOAT and d < SKIM_NEAR and not lesson else 1.0
	if state == AFLOAT:
		if _all_open() and not carries(): _sink()
		elif d > RESEAL_FAR: _reseal()
	elif refill and not _refilled and d > RESEAL_FAR:
		_refilled = true
		game.near.meter = 1.0
	if bool(game.smash.hot) and in_corridor(p,12.0): game.smash.keep_hot(0.3)
	_guns_step(delta,p,d)
	if state == SINKING: _sink_step(delta,p,d)

## The plane's middle held off the gun deck's and the tunnel's walls (the funnel's by
## the plate, the mouth's edge past their end; `_wall_off`) by the reach its roll
## gives it this frame (the study's `solid_pad`): a roll that widens it by a wall, or
## her own roll bringing a wall to it, would start its move inside her solid, which
## SkyGlide can only lift it out of, onto her deck. Only ever off the wall, and only
## a little (a plane deeper in is the move's to put back). Likewise under her roof.
func _keep_off_walls() -> void:
	var plane = game.plane
	var p: Vector3 = plane.position
	# Out through the stern's plate too, under the exit's head.
	if state != AFLOAT or not in_corridor(p,PLATE+0.5): return
	var l := local(p)
	if _by_shut_plate(l): return
	var was := l
	var wall := _wall_off(l)
	var short := WorldScale.reach_rolled(float(plane.bank)+float(plane.spin))+0.02-wall.x
	if short > 0.0 and short <= KEEP_MOST: l += Vector3(wall.y,0.0,wall.z)*short
	# Riding under the roof (SkyGlide `_under`), held CLEAR under it as she pitches or
	# heaves down onto it: a roof come nearer than that lifts the plane onto her deck.
	# The funnel's solid keeps the gun deck's roof to half way along it (ship_build.py
	# steps that band there), under its leaning line.
	if l.z > -TUNNEL_END:
		var lid := (FLOOR_Y+high if _funnel(l.z) < 0.5 else _way_at(l.z).z)-SkyGlide.CLEAR-0.05
		if l.y > lid and l.y < lid+KEEP_MOST: l.y = lid
	if l != was: plane.position = transform*l

## One frame, after the plane's: the balls fly and meet it. `events` as the
## study's: "scrape", "lost".
func after(delta: float, events: Dictionary) -> void:
	var p: Vector3 = game.plane.position
	var was := p if _plane_was == Vector3.INF or _plane_was.distance_to(p) > 40.0 else _plane_was
	_plane_was = p
	_balls_step(delta,was,p,events)
	_bits_step(delta)
	_wake_step(delta)

# --- The guns ----------------------------------------------------------------

func _guns_step(delta: float, p: Vector3, d: float) -> void:
	for g: Dictionary in _guns:
		g.rest = maxf(float(g.rest)-delta,0.0)
		_kick_step(g,delta)
	var l := local(p)
	_lay(delta,p,d,l)
	if state != AFLOAT: return
	var left: Array[Dictionary] = []
	for t: Dictionary in _tells:
		t.t = float(t.t)-delta
		var g: Dictionary = t.gun
		(g.flash as Node3D).scale = Vector3.ONE*(1.0+1.2*(1.0-float(t.t)/TELL))
		if float(t.t) > 0.0:
			left.append(t)
			continue
		(g.flash as Node3D).visible = false
		_fire(g)
	_tells = left
	_every = maxf(_every-delta,0.0)
	_lob_every = maxf(_lob_every-delta,0.0)
	if lesson:
		_lesson_guns(p,d,l)
		return
	if not game.plane.weighted or not bool(game.hand_landing.flying()) or game.stage != null: return
	if absf(l.z) > absf(l.x)*tan(ARC): return
	var side := signf(l.x)
	if _every <= 0.0 and d >= RANGE.x and d <= RANGE.y:
		var best := _pick("hull",side,l.z)
		if not best.is_empty():
			_every = EVERY
			best.rest = REST
			_tell(best)
	if _lob_every <= 0.0 and d >= LOB_RANGE.x and d <= LOB_RANGE.y:
		var best := _pick("deck",side,l.z)
		if not best.is_empty():
			_lob_every = LOB_EVERY
			best.rest = LOB_REST
			_tell(best)

## The lesson's fire: a hull gun's tell once no ball of hers is still coming at
## the plane (LESSON_GAP s after the last passed it, met it or fell), the
## plane flying within LESSON_ARC of abeam and LESSON_RANGE.
func _lesson_guns(p: Vector3, d: float, l: Vector3) -> void:
	var coming := not _tells.is_empty()
	var pv: Vector3 = game.plane.velocity
	for b: Dictionary in balls:
		if not bool(b.done) and ((b.at as Vector3)-p).dot((b.v as Vector3)-pv) < 0.0: coming = true
	if coming:
		_every = LESSON_GAP
		return
	if quiet or _every > 0.0: return
	if not game.plane.weighted or not bool(game.hand_landing.flying()) or game.stage != null: return
	if absf(l.z) > absf(l.x)*tan(LESSON_ARC): return
	if d < LESSON_RANGE.x or d > LESSON_RANGE.y: return
	# Only at a plane coming her way (within LESSON_FACING of her), so the ball
	# comes from ahead of it, where it can be seen.
	var to := position-p
	if pv.dot(to) < cos(LESSON_FACING)*pv.length()*to.length(): return
	var best := _pick("hull",signf(l.x),l.z)
	if best.is_empty(): return
	_every = LESSON_GAP
	best.rest = REST
	_tell(best)

## The ready gun of `kind` on `side` nearest `z` along her (a deck gun only once
## it's laid), or {}.
func _pick(kind: String, side: float, z: float) -> Dictionary:
	var best: Dictionary = {}
	for g: Dictionary in _guns:
		if str(g.kind) != kind or float(g.side) != side or float(g.rest) > 0.0: continue
		if kind == "deck" and float(g.err) > DECK_AIMED: continue
		if best.is_empty() or absf(float(g.z)-z) < absf(float(best.z)-z): best = g
	return best

func _tell(g: Dictionary) -> void:
	(g.flash as Node3D).visible = true
	_tells.append({"gun":g,"t":TELL})

## The deck guns swing and lay onto the lob that would meet the plane now while
## it's on their side and near enough; else back to rest. Look, and the lay a gun
## must have to fire: the ball itself is thrown by `_lob`, from where its muzzle is.
func _lay(delta: float, p: Vector3, d: float, l: Vector3) -> void:
	var live := state == AFLOAT and not lesson and d <= LOB_RANGE.y*1.15 and bool(game.hand_landing.flying())
	for g: Dictionary in _guns:
		if str(g.kind) != "deck": continue
		var want := Vector2(0.0,DECK_REST)
		if live and float(g.side) == signf(l.x):
			var gv: Vector3 = (g.pivot as Transform3D).basis.inverse()*(_inv.basis*_lob(g,p,d))
			want = Vector2(clampf(atan2(-gv.x,-gv.z),-DECK_SWING,DECK_SWING),clampf(atan2(gv.y,Vector2(gv.x,gv.z).length()),DECK_RAISE.x,DECK_RAISE.y))
		g.yaw = move_toward(float(g.yaw),want.x,DECK_TURN.x*delta)
		g.pitch = move_toward(float(g.pitch),want.y,DECK_TURN.y*delta)
		g.err = absf(want.x-float(g.yaw))+absf(want.y-float(g.pitch)) if live else INF
		(g.yaw_node as Node3D).transform = _yaw_frame(g)
		var kick := Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,KICK.y*_kick_share(float(g.kick))))
		(g.barrel as Node3D).transform = _barrel_frame(g)*kick

func _yaw_frame(g: Dictionary) -> Transform3D:
	var home: Transform3D = g.yaw_home
	return Transform3D(home.basis*Basis(Vector3.UP,float(g.yaw)),home.origin)

func _barrel_frame(g: Dictionary) -> Transform3D:
	var home: Transform3D = g.barrel_home
	return Transform3D(home.basis*Basis(Vector3.RIGHT,float(g.pitch)),home.origin)

## Deck gun `g`'s muzzle as it's laid now, in her frame, -z its bore.
func _deck_muzzle(g: Dictionary) -> Transform3D:
	return (g.pivot as Transform3D)*_yaw_frame(g)*_barrel_frame(g)*Transform3D(Basis.IDENTITY,g.muzzle as Vector3)

## The throw (m/s, the world's) from deck gun `g`'s muzzle that comes down on the
## plane where it'll be after the lob's time aloft at `d` m, if it holds its line.
func _lob(g: Dictionary, p: Vector3, d: float) -> Vector3:
	var from: Vector3 = transform*_deck_muzzle(g).origin
	var t := lob_time(d)
	var at: Vector3 = p+(game.plane.velocity as Vector3)*t
	return (at-from)/t+Vector3.UP*0.5*LOB_DROP*t

## A lob's time aloft to a plane `d` m off.
static func lob_time(d: float) -> float:
	return lerpf(LOB_T.x,LOB_T.y,clampf((d-LOB_RANGE.x)/(LOB_RANGE.y-LOB_RANGE.x),0.0,1.0))

## How far back a gun is `t` s after it fired (0 to 1; -1 is still).
static func _kick_share(t: float) -> float:
	if t < 0.0: return 0.0
	if t < KICK_S.x: return t/KICK_S.x
	if t < KICK_S.x+KICK_S.y: return 1.0
	return 1.0-smoothstep(0.0,KICK_S.z,t-KICK_S.x-KICK_S.y)

## A gun's kick on: a hull gun's piece moves back along its bore (a deck gun's
## barrel is laid in `_lay`, its kick with it).
func _kick_step(g: Dictionary, delta: float) -> void:
	if float(g.kick) < 0.0: return
	g.kick = float(g.kick)+delta
	if float(g.kick) > KICK_S.x+KICK_S.y+KICK_S.z: g.kick = -1.0
	if str(g.kind) == "hull" and g.kick_node != null:
		var home: Transform3D = g.kick_home
		(g.kick_node as Node3D).transform = Transform3D(home.basis,home.origin+(g.kick_way as Vector3)*KICK.x*_kick_share(float(g.kick)))

## Gun `g` fires. A hull gun at where the plane is headed: straight on its line
## now, the ball meeting it there, the drop allowed for. A deck gun lobs onto
## where it'll be (`_lob`). A dodge after the shot is what saves it.
func _fire(g: Dictionary) -> void:
	var deck := str(g.kind) == "deck"
	var from: Vector3
	var out: Vector3
	if deck:
		var m := _deck_muzzle(g)
		from = transform*m.origin
		out = transform.basis*(m.basis*Vector3.FORWARD)
	else:
		from = transform*(g.at as Vector3)
		out = transform.basis*(g.out as Vector3)
	g.kick = 0.0
	if _fx != null: _fx.blast(from,out)
	var d: float = from.distance_to(game.plane.position)
	game.sound.shot("thump",1.2/(1.0+d/BOOM_HEARD),0.75 if deck else 0.6,from,&"SFX",true)
	if balls.size() >= BALLS: return
	var to: Vector3 = (game.plane.position as Vector3)-from
	var shot: Vector3
	if deck:
		shot = _lob(g,game.plane.position,(game.plane.position as Vector3).distance_to(position))
	else:
		var v: Vector3 = game.plane.velocity
		var speed_of := LESSON_BALL if lesson else BALL_SPEED
		var a := v.length_squared()-speed_of*speed_of
		var b := 2.0*to.dot(v)
		var c := to.length_squared()
		var root := b*b-4.0*a*c
		if root < 0.0 or absf(a) < 0.01: return
		var t := (-b-sqrt(root))/(2.0*a)
		if t <= 0.0: return
		var at: Vector3 = to+v*t
		shot = at/t+Vector3.UP*BALL_DROP*t*0.5
	var ball := _ball()
	ball.position = from
	ball.visible = true
	balls.append({"node":ball,"at":from,"v":shot,"drop":LOB_DROP if deck else BALL_DROP,"lob":deck,"age":0.0,"least":INF,"near":from,"done":false,"trail":0.0,"parry":true,"r":BALL_R})
	fired += 1
	if deck: lobs += 1

func _ball() -> Node3D:
	if not _pool.is_empty(): return _pool.pop_back()
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	var body := MeshInstance3D.new()
	if _ball_mesh != null:
		body.mesh = _ball_mesh
	else:
		var s := SphereMesh.new()
		s.radius = BALL_R
		s.height = BALL_R*2.0
		s.radial_segments = 12
		s.rings = 6
		body.mesh = s
		body.material_override = _mat(Color(0.12,0.1,0.09),Color(1.0,0.35,0.05),1.4)
	n.add_child(body)
	return n

## A cluster of `n` soft discs for muzzle_puff.gdshader: one core disc of radius
## `r` then the rest scattered round it (`spread` x r), tinted from `tints`,
## `opacity` at the core. `fall` thins the outer ones; 0 keeps them as bright.
func _cluster_mesh(r: float, tints: Array, opacity: float, n: int, spread: float, fall: float) -> ArrayMesh:
	var at := PackedVector3Array()
	var uv := PackedVector2Array()
	var size := PackedVector2Array()
	var col := PackedColorArray()
	var index := PackedInt32Array()
	for i in n:
		var core := i == 0
		var dir := Vector3(sin(i*2.4+1.0),cos(i*1.7)*0.8,sin(i*3.1+0.5)*0.9).normalized()
		var centre := Vector3.ZERO if core else dir*r*spread*(0.5+0.5*fmod(i*0.37,1.0))
		var rad := r if core else r*(0.55+0.35*fmod(i*0.61,1.0))
		var o := opacity*(1.0 if core else lerpf(1.0,0.55,fall)*(0.6+0.4*fmod(i*0.43,1.0)))
		var first := at.size()
		for corner: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
			at.append(centre)
			uv.append(corner)
			size.append(Vector2(rad,o))
			col.append(tints[0] if core else tints[1+i%(tints.size()-1)])
		index.append_array([first,first+1,first+2,first,first+2,first+3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = at
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = size
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb = AABB(Vector3.ONE*-r*8.0,Vector3.ONE*r*16.0)
	var mat := ShaderMaterial.new()
	mat.shader = load(PUFF_SHADER)
	mesh.surface_set_material(0,mat)
	return mesh

func _balls_step(delta: float, was: Vector3, p: Vector3, events: Dictionary) -> void:
	var reach := WorldScale.span*0.5+BALL_R
	var hot: bool = game.smash.hot
	var flying: bool = game.hand_landing.flying()
	for i in range(balls.size()-1,-1,-1):
		var b: Dictionary = balls[i]
		var a: Vector3 = b.at
		var v: Vector3 = b.v
		if lesson and not bool(b.done): v = _home(a,v,p,delta)
		v += Vector3.DOWN*float(b.drop)*delta
		var n: Vector3 = a+v*delta
		b.v = v
		b.at = n
		b.age = float(b.age)+delta
		(b.node as Node3D).position = n
		if v.length() > 1.0: (b.node as Node3D).basis = Basis.looking_at(v.normalized(),Vector3.UP if absf(v.normalized().y) < 0.99 else Vector3.RIGHT)
		if _ball_mesh != null: ((b.node as Node3D).get_child(0) as Node3D).basis = Basis(Vector3(0.6,0.8,0.0),float(b.age)*BALL_TUMBLE)
		if _fx != null and (b.node as Node3D).visible: _fx.trail(b,a,n)
		# The closest pass this frame: both moved, so the segment's of the two apart.
		if flying and not bool(b.done):
			var r0 := a-was
			var r1 := n-p
			var k := clampf(-r0.dot(r1-r0)/maxf((r1-r0).length_squared(),0.0001),0.0,1.0)
			var gap := r0.lerp(r1,k).length()
			if gap < float(b.least):
				b.least = gap
				b.near = was.lerp(p,k)
			if float(b.least) <= reach:
				b.done = true
				if not hot: _struck(b,events)
			elif float(b.least) < reach+PASS_REACH and gap > float(b.least)+6.0:
				b.done = true
				_passed(b)
		var land := float(game.field.height(n.x,n.z))
		var water := float(game.water_at(n))
		var ground := maxf(land,water)
		if n.y <= ground or float(b.age) > BALL_LIFE:
			if not bool(b.done) and float(b.least) < reach+PASS_REACH: _passed(b)
			if n.y <= ground and (b.node as Node3D).visible:
				var q := a.lerp(n,clampf((a.y-ground)/maxf(a.y-n.y,0.001),0.0,1.0))
				_splash(Vector3(q.x,ground,q.z),v,water >= land)
			(b.node as Node3D).visible = false
			_pool.append(b.node)
			balls.remove_at(i)
	_whistle_step(p)

## A lesson ball at `a` going `v` turned toward where the plane at `p` will be
## when it gets there (the fall allowed for), at most LESSON_HOME rad/s, while
## it is still closing and ahead of the plane (turned away from, it flies on).
func _home(a: Vector3, v: Vector3, p: Vector3, delta: float) -> Vector3:
	var pv: Vector3 = game.plane.velocity
	if (a-p).dot(v-pv) >= 0.0 or pv.dot(a-p) <= 0.0: return v
	var s := v.length()
	var t := a.distance_to(p)/maxf(s,1.0)
	var want := (p+pv*t-a)/maxf(t,0.01)+Vector3.UP*BALL_DROP*t*0.5
	var turn := v.angle_to(want)
	if turn < 0.0001: return v
	return v.slerp(want.normalized()*s,minf(1.0,LESSON_HOME*delta/turn))

## The whistle on the lob coming down nearest the plane inside WHISTLE_NEAR m,
## higher the farther off, louder the nearer.
func _whistle_step(p: Vector3) -> void:
	if balls.is_empty() and (_whistle == null or not _whistle.playing): return
	var best: Dictionary = {}
	var near := WHISTLE_NEAR
	for b: Dictionary in balls:
		if not bool(b.lob) or (b.v as Vector3).y >= 0.0 or not (b.node as Node3D).visible: continue
		var d := (b.at as Vector3).distance_to(p)
		if d < near:
			near = d
			best = b
	if best.is_empty():
		if _whistle != null and _whistle.playing: _whistle.stop()
		return
	if _whistle == null:
		if not bool(game.sound.audible): return
		var stream := (load(WHISTLE) as AudioStreamWAV).duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
		_whistle = AudioStreamPlayer3D.new()
		_whistle.name = "Whistle"
		_whistle.stream = stream
		_whistle.bus = &"SFX"
		_whistle.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		_whistle.panning_strength = 0.8
		_fx.root.add_child(_whistle)
	var k := near/WHISTLE_NEAR
	_whistle.global_position = best.at
	_whistle.pitch_scale = lerpf(WHISTLE_PITCH.y,WHISTLE_PITCH.x,k)
	_whistle.volume_db = linear_to_db(WHISTLE_GAIN*(1.0-k*k)+0.001)
	if not _whistle.playing: _whistle.play()

func _passed(b: Dictionary) -> void:
	passes += 1
	var clear := maxf(float(b.least)-WorldScale.span*0.5-BALL_R,0.0)
	game.near.shot_pass(clear,PASS_REACH,b.near)
	game.sound.shot("whoosh",0.7,1.3,b.near)

## Ball `b` hit: the unbanked chain gone, the plane off line. No crash, no
## damage, and the banked meter stays.
func _struck(b: Dictionary, events: Dictionary) -> void:
	hits += 1
	var plane = game.plane
	var at: Vector3 = b.near
	var v: Vector3 = b.v
	var flat := Vector3(v.x,0.0,v.z)
	flat = flat.normalized() if flat.length() > 0.1 else Vector3.ZERO
	var fwd: Vector3 = plane.forward()
	var hit := LESSON_HIT if lesson else Vector3(HIT_KEEP,HIT_SHOVE,HIT_YAW)
	var turn := hit.z*(1.0 if fwd.cross(flat).y >= 0.0 else -1.0)
	var speed_was := float(plane.speed)
	plane.knock(hit.x,flat*hit.y+Vector3.UP*(2.0 if not lesson else 0.5),turn)
	var lost: float = game.near.lose()
	if lost > 0.0: events["lost"] = {"points":lost}
	events["scrape"] = {"at":at,"normal":-v.normalized(),"what":"stone","into":hit.y,"angle":0.5,"speed":speed_was,"keep":hit.x}
	game.debris.hit("stone",at,-v.normalized())
	game.feel_hit(HIT_FEEL.x,HIT_FEEL.y)
	game.sound.shot("crash",1.0,0.8)
	(b.node as Node3D).visible = false

# --- Parried (scripts/endless/parry.gd) ----------------------------------------

## Her balls in the air, every one parryable (`parry` true).
func parry_shots() -> Array[Dictionary]:
	return balls

## Ball `b` is the parry's: out of her flight, whistle and hit tests.
func parry_take(b: Dictionary) -> void:
	balls.erase(b)

## Where a parried ball comes home: amidships, up her side by the guns.
func parry_aim(_b: Dictionary) -> Vector3:
	return transform*Vector3(0.0,GUN_Y*0.6,0.0)

## In her hull: inside her beam, between the keel's draught and the top deck,
## along her length.
func parry_inside(p: Vector3) -> bool:
	if state == GONE: return false
	var l := local(p)
	return absf(l.x) < BEAM+1.0 and l.y > -DRAUGHT and l.y < FLOOR_Y+high+DECK+2.0 and absf(l.z) < LONG*0.5+PLATE

func parry_moved(b: Dictionary, a: Vector3, n: Vector3) -> void:
	if _fx != null: _fx.trail(b,a,n)

## A parried ball's end: on her (a burst of splinters, fire and smoke, timber on
## the water), else gone into the sea.
func parry_landed(b: Dictionary, at: Vector3, hit: bool) -> void:
	var node: Node3D = b.node
	node.visible = false
	_pool.append(node)
	if not hit:
		_splash(Vector3(at.x,sea_y,at.z),b.v,true)
		return
	shot_back += 1
	var l := local(at)
	var out := transform.basis*Vector3(signf(l.x) if absf(l.x) > 0.5 else 1.0,0.25,0.0)
	out = out.normalized()
	if _fx != null: _fx.blast(at,out)
	game.debris.hit("wood",at,out,true)
	game.debris.burst("dust",at,out,true)
	for i in 12:
		var c: MeshInstance3D = _chunk_pool.pop_back() if not _chunk_pool.is_empty() else _new_chunk()
		var spread := Vector3(randf_range(-1.0,1.0),randf_range(-0.3,1.0),randf_range(-1.0,1.0))
		c.position = at+spread*1.5
		c.scale = Vector3.ONE*randf_range(0.35,1.0)
		c.visible = true
		_chunks.append({"node":c,"v":out*randf_range(12.0,30.0)+spread*9.0+Vector3.UP*8.0,"t":2.0})
	_plank(Vector3(at.x,sea_y,at.z)+out*4.0)
	_plank(Vector3(at.x,sea_y,at.z)+out*7.0)
	var d := at.distance_to(game.plane.position)
	game.sound.shot("crash",1.4/(1.0+d/BOOM_HEARD),0.7,at,&"SFX",true)
	game.sound.shot("thump",1.3/(1.0+d/BOOM_HEARD),0.55,at,&"SFX",true)

# --- The plates --------------------------------------------------------------

## The plane's breaking `r` (SurgeSmash `_hit`): it's gone till the plates come
## back, and the surge lasts to the far end.
func _strike(r: Dictionary, q: Vector3) -> void:
	var part := str(r.part)
	var plate: Dictionary = plates[part]
	if bool(plate.open): return
	if not bool(plates.stern.open) and not bool(plates.bow.open): _carried = carries()
	_last = part
	plate.open = true
	game.arches.loose.erase(r)
	GroundNative.bump_loose()
	(plate.shape as CollisionShape3D).disabled = true
	game.smash.keep_hot(LONG/maxf(float(game.plane.velocity.length()),30.0)+0.5)
	if _model != null:
		_throw(plate,q)
	else:
		(plate.look as Node3D).visible = false
		_shatter(q)
	bursts += 1
	broke.emit(part)

func _reseal() -> void:
	var was := false
	for part: String in plates:
		var plate: Dictionary = plates[part]
		if not bool(plate.open): continue
		was = true
		plate.open = false
		game.arches.loose.push_front(plate.record)
		GroundNative.bump_loose()
		_place(plate.record)
		(plate.shape as CollisionShape3D).disabled = false
		if _model == null:
			(plate.look as Node3D).visible = true
			continue
		(plate.cover as Node3D).visible = true
		(plate.whole as Node3D).visible = true
		for shard: Dictionary in plate.shards:
			(shard.node as Node3D).transform = shard.home
			(shard.node as Node3D).visible = false
	_shards.clear()
	if was and refill: game.near.meter = 1.0

# --- The sink ------------------------------------------------------------------

## True while she has the ring aboard: its row is in the table, anchored to her, not
## yet found.
func carries() -> bool:
	var finds: Node = game.get("finds")
	if finds == null: return false
	var row: Dictionary = finds.row(RELIC)
	return not row.is_empty() and str(row.get("anchor","")) == handle and not bool(finds.is_found(row))

func _all_open() -> bool:
	return bool(plates.stern.open) and bool(plates.bow.open)

## Her pose `t` s into a sink: Vector3(m down, pitch, roll in degrees).
static func sink_pose(t: float) -> Vector3:
	var n := SINK_KEYS.size()
	var i := 1
	while i < n-2 and t >= float(SINK_KEYS[i+1][0]): i += 1
	var a: Array = SINK_KEYS[i-1]
	var b: Array = SINK_KEYS[i]
	var c: Array = SINK_KEYS[i+1]
	var d: Array = SINK_KEYS[mini(i+2,n-1)]
	var k := clampf((t-float(b[0]))/(float(c[0])-float(b[0])),0.0,1.0)
	var out := Vector3.ZERO
	for j in 3: out[j] = cubic_interpolate(float(b[j+1]),float(c[j+1]),float(a[j+1]),float(d[j+1]),k)
	return out

## She's hit her last: everything stops but her going. The plane may well be in
## her, so the hull's flat record goes and her true tilt takes over.
func _sink() -> void:
	state = SINKING
	sink_t = 0.0
	sinks += 1
	_beat = 0.0
	_cue = 0
	_ghost = false
	_panned = false
	_handed_back = false
	_refilled = false
	_pay = not _carried
	_end = 1.0 if _last == "bow" else -1.0
	var l := local(game.plane.position)
	_list = -1.0 if l.x > 0.0 else 1.0
	game.arches.loose.erase(_hull)
	GroundNative.bump_loose()
	for t: Dictionary in _tells: (t.gun.flash as Node3D).visible = false
	_tells.clear()
	game.feel_hit(0.045,12.0)
	game.sound.shot("thump",1.4,0.42)
	game.sound.shot("crash",1.1,0.55)
	var finds: Node = game.get("finds")
	if finds != null:
		finds.beat.play("landing",position+Vector3.UP*20.0,0.0)
		finds.hud.found({"title":SINK_WORDS if _carried else SINK_WORDS_BARE},int(finds.got()),int(finds.of()))
	for z: float in [LONG*0.5,-LONG*0.5]:
		var at: Vector3 = transform*Vector3(0.0,8.0,z)
		var out: Vector3 = (transform.basis*Vector3(0.0,0.2,signf(z))).normalized()
		game.debris.burst("wood",at,out,true)
		game.debris.burst("dust",at,out,true)
		_mist(at)
	sinking.emit()

## The time-keyed part of a sink: the wash, the groans, the points, the end.
func _sink_step(delta: float, p: Vector3, d: float) -> void:
	if not _ghost and in_corridor(p,2.0) and (transform*Vector3(0.0,deck_mid(high),0.0)).y < float(game.water_at(position)):
		# The gun deck has flooded round the plane: it's let go, not shut in.
		_ghost = true
		_hull_body.collision_layer = 0
	if _pay and sink_t >= SINK_PAY_AT:
		_pay = false
		paid += SINK_POINTS
		game.near.prize(SINK_POINTS,SINK_LINE,position)
	while _cue < SINK_CUES.size() and sink_t >= float(SINK_CUES[_cue][0]):
		var c: Array = SINK_CUES[_cue]
		_cue += 1
		_loud(str(c[1]),float(c[2]),float(c[3]),d)
	_beat -= delta
	if _beat <= 0.0:
		_beat = SINK_BEAT
		if d < SINK_NEAR: _wash(d)
	if sink_t >= SINK_S and _under(): _gone()

## True while she'd have the eye: CoastSites `watch` picks among the ships.
func wants_eye() -> bool:
	return state == SINKING and sink_t >= WATCH_FROM and not _handed_back

## A newer sink has the eye: this one lets it be for the rest of hers, and leaves the
## camera to that one.
func give_up_eye() -> void:
	watching = false
	_handed_back = true

## The chase camera in a sink, each frame (the study's `_frame`): the free look, eased
## round so she's in frame past the plane, which flies on under its own controls. The
## player's turn of it pans on from there, and letting go hands the normal camera
## back after its linger; so does the end of the sink, her being far off, or land or
## sea coming up on the plane's way. Outside a sink it sets nothing but ZERO.
func watch(chase: RefCounted) -> void:
	var on := state == SINKING and sink_t >= WATCH_FROM and not _handed_back
	if on:
		if chase.free_held: _panned = true
		elif _panned: _handed_back = true
		if position.distance_to(game.plane.position) > WATCH_FAR or _way_shut(): _handed_back = true
		if not game.hand_landing.flying(): _handed_back = true
		on = not _handed_back
	if on:
		var v: Vector3 = game.plane.velocity
		var to: Vector3 = position-(game.plane.position as Vector3)
		var ahead := Vector3(v.x,0.0,v.z)
		if ahead.length() < 1.0: ahead = game.plane.forward()
		chase.free_to = Vector2(wrapf(ahead.signed_angle_to(Vector3(to.x,0.0,to.z),Vector3.UP)+WATCH_OFF,-PI,PI),0.0)
		chase.free_ease = WATCH_EASE
	elif watching:
		chase.free_to = Vector2.ZERO
		chase.free_ease = chase.EASE_BACK
	else:
		return
	watching = on

## True with land or sea coming up on the plane's way in the next few seconds: the
## player, looking back, has to see where it's going.
func _way_shut() -> bool:
	var p: Vector3 = game.plane.position
	var v: Vector3 = game.plane.velocity
	for s: float in WATCH_AHEAD:
		var q := p+v*s
		if q.y < maxf(float(game.field.height(q.x,q.z)),sea_y)+WATCH_ROOM*(0.5 if v.y >= 0.0 else 1.0) and float(game.field.height(q.x,q.z)) > sea_y: return true
		if v.y < -1.0 and q.y < sea_y+2.0: return true
	return false

## A flat shot, softer with distance: 3D shots die at 70 m and she's 130 long.
func _loud(kind: String, gain: float, pitch: float, d: float) -> void:
	game.sound.shot(kind,gain/(1.0+d/SINK_HEARD),pitch,position,&"SFX",true)

## True with every high point of her under the sea.
func _under() -> bool:
	var sea := float(game.water_at(position))
	for h: Vector3 in HIGH_POINTS:
		if (transform*h).y > sea-1.0: return false
	return true

## Where a hull side's line at `z` on `side` crosses the sea, or INF.
func _waterline(z: float, side: float) -> Vector3:
	var a: Vector3 = transform*Vector3(side*BEAM_WET,-DRAUGHT,z)
	var b: Vector3 = transform*Vector3(side*BEAM_WET,FLOOR_Y+high+DECK,z)
	var sea := float(game.water_at(a))
	if (a.y-sea)*(b.y-sea) > 0.0: return Vector3.INF
	return a.lerp(b,(sea-a.y)/(b.y-a.y))

## One wash: foam along her waterline, a burst of mist and spray, and something
## let go, strongest where she's going in fastest.
func _wash(d: float) -> void:
	var low := -_end*(LONG*0.5)
	for i in 5:
		var z := lerpf(low,-low,randf()*randf())
		var at := _waterline(z,1.0 if i%2 == 0 else -1.0)
		if at == Vector3.INF: continue
		if game.water != null: game.water.wash(at,1.0,6.0+sink_t*0.25)
		if i == 0: _mist(at)
		if i == 1: game.debris.burst("spray",at,Vector3.UP,true)
		if i == 2 and randf() < 0.5: game.debris.burst("wood",at,Vector3.UP,true)
		if i == 3: _plank(at)
	# The boil as she drives under: over where she was, wide and getting wider.
	if sink_t > 14.0:
		var sea := float(game.water_at(position))
		var r := 25.0+(sink_t-14.0)*7.0
		var at := Vector3(position.x+randf_range(-r,r),sea,position.z+randf_range(-r,r))
		_mist(at)
		_plank(at)
		if game.water != null:
			game.water.wash(at,1.0,16.0)
			if d < SINK_NEAR*0.4 and randf() < 0.3: game.water.splash(at,1.6)

## She's under: hidden and out of the world till her return.
func _gone() -> void:
	var sea := float(game.water_at(position))
	var at := Vector3(position.x,sea,position.z)
	_loud("splash",1.4,0.5,at.distance_to(game.plane.position))
	if game.water != null:
		for i in 12:
			var r := Vector3(randf_range(-1.0,1.0),0.0,randf_range(-1.0,1.0))*70.0
			game.water.wash(at+r,1.0,20.0)
	for i in 6: _mist(at+Vector3(randf_range(-45.0,45.0),0.0,randf_range(-45.0,45.0)))
	for i in 8: _plank(at+Vector3(randf_range(-55.0,55.0),0.0,randf_range(-55.0,55.0)))
	state = GONE
	sink_t = -1.0
	gone_t = 0.0
	_poll = 0.0
	visible = false
	_hull_body.collision_layer = 0
	_plane_was = Vector3.INF

## Gone: the clock, then the route tried for a spot out of sight. Only the wash on
## the water is left to step, and the balls fired before she went are long down.
func _wait(delta: float) -> void:
	if lesson: return
	gone_t += delta
	if gone_t < return_wait: return
	_poll -= delta
	if _poll > 0.0: return
	_poll = RETURN_POLL
	var s := _return_spot()
	if not is_nan(s): _come_back(s)

## The way along the route to come back at, farthest from the eye of those out of
## its sight; NAN if none is. Never within RETURN_NEAR m of the plane either, nor
## RETURN_APART m of the other ship.
func _return_spot() -> float:
	var eye: Vector3 = game.camera.global_position
	var look: Vector3 = -game.camera.global_basis.z
	var plane: Vector3 = game.plane.position
	var lap := 2.0*_leg+TAU*ROUTE_R
	var best := NAN
	var far := -1.0
	for i in RETURN_SPOTS:
		var s := along+lap*float(i)/float(RETURN_SPOTS)
		var q: Vector2 = route_pose(s,_leg)[0]
		var at: Vector3 = _route*Vector3(q.x,0.0,q.y)
		if at.distance_to(plane) < RETURN_NEAR: continue
		if twin != null and twin.state != GONE and at.distance_to(twin.position) < RETURN_APART: continue
		var d := at.distance_to(eye)
		if unseen(at,eye,look) and d > far:
			far = d
			best = s
	return best

## True if a ship at `at` is out of the eye's sight.
static func unseen(at: Vector3, eye: Vector3, look: Vector3) -> bool:
	var d := at.distance_to(eye)
	if d >= RETURN_ANY: return true
	return d >= RETURN_NEAR and look.dot((at-eye)/d) < RETURN_CONE

## A fresh ship at `s` along the route: plates whole, guns live.
func _come_back(s: float) -> void:
	# She comes back to clear air: a mist left from her going would hang in her.
	for m: Dictionary in _mists: (m.node as Node3D).visible = false
	state = AFLOAT
	along = s
	visible = true
	_ghost = false
	_ride_fresh = true
	_yaw_was = NAN
	_every = EVERY
	_lob_every = LOB_EVERY
	for g: Dictionary in _guns: g.rest = 0.0
	_pose()
	_hull_body.collision_layer = game.arches.LAYER
	game.arches.loose.append(_hull)
	GroundNative.bump_loose()
	_place(_hull)
	_reseal()
	returns += 1
	returned.emit()

## SkyGlide's `ground` at `p` over `h`, in a sink: her solid at its true tilt, each
## stretch at the plane's own spot in her frame, so it's exact at the plane's height
## and a little out far above or below it.
func wreck_ground(p: Vector3, h: Variant, pad: float) -> Variant:
	if state != SINKING or _ghost or not h is float: return h
	if p.distance_squared_to(position) > WRECK_REACH*WRECK_REACH: return h
	var l := _inv*p
	var list: Array = []
	BoxSolid.stretches(_hull.solid,l.x,l.z,pad,0.0,list)
	if list.is_empty(): return h
	for i in list.size():
		var s: Vector2 = list[i]
		var a: float = (transform*Vector3(l.x,s.x,l.z)).y
		var b: float = (transform*Vector3(l.x,s.y,l.z)).y
		list[i] = Vector2(minf(a,b),maxf(a,b))
	return LandHalls.over(p,float(h),BoxSolid.joined(list))

## True in her solid, grown by `pad`, in a sink.
func wreck_inside(p: Vector3, pad: float) -> bool:
	if state != SINKING or _ghost: return false
	if p.distance_squared_to(position) > WRECK_REACH*WRECK_REACH: return false
	return BoxSolid.inside(_hull.solid,_inv*p,pad)

## Off the wreck's nearest outside, in the world, for FlightContact: her top if the
## plane is over her, else her side or end, never down (her list would throw it at
## the sea). Up for a touch of the water right beside her; ZERO away from her.
func _wreck_way_off(p: Vector3, l: Vector3, what: String) -> Vector3:
	if _ghost or p.distance_squared_to(position) > WRECK_REACH*WRECK_REACH: return Vector3.ZERO
	var beam := BEAM
	var end := LIP_HI if l.z < 0.0 else LONG*0.5+PLATE
	if absf(l.x) > beam+10.0 or absf(l.z) > end+20.0 or l.y > 70.0 or l.y < -DRAUGHT-4.0: return Vector3.ZERO
	if what == "water": return Vector3.UP
	var off := Vector3.UP
	if l.y < FLOOR_Y+high+DECK:
		off = Vector3(signf(l.x),0.0,0.0) if beam-absf(l.x) < end-absf(l.z) else Vector3(0.0,0.0,signf(l.z))
	var way: Vector3 = transform.basis*off
	way.y = maxf(way.y,0.1)
	return way.normalized()

## A puff of white off the water at `at`.
func _mist(at: Vector3) -> void:
	var m: Dictionary = {}
	if _mists.size() < MISTS:
		var n := MeshInstance3D.new()
		n.mesh = _mist_mesh
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wake.add_child(n)
		m = {"node":n,"t":0.0,"r":1.0}
		_mists.append(m)
	else:
		var oldest := -1.0
		for o: Dictionary in _mists:
			if float(o.t) > oldest:
				oldest = float(o.t)
				m = o
	m.t = 0.0
	m.r = randf_range(MIST_R.x,MIST_R.y)
	(m.node as Node3D).position = at
	(m.node as Node3D).visible = true

## A plank let go on the water at `at`.
func _plank(at: Vector3) -> void:
	if _planks.size() >= PLANKS: return
	var n := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(randf_range(5.0,16.0),0.7,randf_range(0.8,1.8))
	n.mesh = b
	n.material_override = _plank_mat
	_wake.add_child(n)
	n.position = at
	n.rotation.y = randf()*TAU
	_planks.append({"node":n,"t":0.0,"drift":Vector3(randf_range(-1.0,1.0),0.0,randf_range(-1.0,1.0))*1.5,"seed":randf()*TAU})

## What's on the water: the mist lifts and thins, the planks ride the swell, then
## go down. Nothing here costs anything once they're done.
func _wake_step(delta: float) -> void:
	for m: Dictionary in _mists:
		if not (m.node as Node3D).visible: continue
		m.t = float(m.t)+delta
		var k := float(m.t)/MIST_LIFE
		var n: MeshInstance3D = m.node
		if k >= 1.0:
			n.visible = false
			continue
		n.position.y += MIST_RISE*(1.0-k)*delta
		n.scale = Vector3.ONE*float(m.r)*(1.0+k*2.4)
		n.set_instance_shader_parameter("fade",(1.0-k)*smoothstep(0.0,0.08,k))
	for i in range(_planks.size()-1,-1,-1):
		var w: Dictionary = _planks[i]
		w.t = float(w.t)+delta
		var n: MeshInstance3D = w.node
		n.position += (w.drift as Vector3)*delta
		var t := float(w.t)
		var down := maxf(t-PLANK_LIFE,0.0)*PLANK_SINK
		# The swell's read for a few a frame: it's slow, and it isn't free.
		if (i+Engine.get_process_frames())%PLANK_TURNS == 0: n.position.y = sea_y+float(game.sea_height(n.position))-0.05-down
		n.rotation.x = 0.1*sin(t*0.9+float(w.seed))
		n.rotation.z = 0.08*sin(t*0.7+float(w.seed)*2.0)
		if down > 3.0:
			n.queue_free()
			_planks.remove_at(i)

func _shatter(q: Vector3) -> void:
	var v: Vector3 = game.plane.velocity
	var d := v.normalized()
	for i in 14:
		var c: MeshInstance3D = _chunk_pool.pop_back() if not _chunk_pool.is_empty() else _new_chunk()
		var spread := Vector3(randf_range(-1.0,1.0),randf_range(-0.6,1.0),randf_range(-1.0,1.0))
		c.position = q+spread*3.0
		c.scale = Vector3.ONE*randf_range(0.5,1.6)
		c.visible = true
		_chunks.append({"node":c,"v":d*randf_range(20.0,55.0)+spread*14.0,"t":2.2})

## The plate's shards blown off the plane's line, as a smashed ruin's stone flies
## (SmashBreaks): on ahead with the plane, out from its line, up, spinning. So a
## plate hit from outside goes down the gun deck, one hit from inside goes out to
## sea. Drawn only; they stay under their plug, in her frame.
func _throw(plate: Dictionary, q: Vector3) -> void:
	var v: Vector3 = game.plane.velocity
	var d := v.normalized()
	var plug: Node3D = plate.plug
	(plate.cover as Node3D).visible = false
	(plate.whole as Node3D).visible = false
	for shard: Dictionary in plate.shards:
		var n: Node3D = shard.node
		n.visible = true
		var out := (transform*(plug.position+n.position)-q).slide(d)
		out = out.normalized() if out.length() > 0.05 else Vector3.UP
		var lin := v*randf_range(SmashBreaks.KEEP.x,SmashBreaks.KEEP.y)+out*randf_range(SmashBreaks.OUT.x,SmashBreaks.OUT.y)+Vector3.UP*randf_range(SmashBreaks.UP_V.x,SmashBreaks.UP_V.y)
		var spin := Vector3(randf_range(-1.0,1.0),randf_range(-1.0,1.0),randf_range(-1.0,1.0)).normalized()*randf_range(SmashBreaks.SPIN.x,SmashBreaks.SPIN.y)
		_shards.append({"node":n,"off":plug.position,"v":_inv.basis*lin,"spin":spin})

## Thrown shards on: inside the gun deck they're kept in it, and lie where they
## stop till the reseal; past her ends they fall into the sea.
func _shards_step(delta: float) -> void:
	for i in range(_shards.size()-1,-1,-1):
		var s: Dictionary = _shards[i]
		var n: Node3D = s.node
		var v: Vector3 = s.v
		v += Vector3.DOWN*SHARD_DROP*delta
		var at: Vector3 = (s.off as Vector3)+n.position+v*delta
		var low := false
		if absf(at.z) < LONG*0.5:
			var x := wide*0.5-SHARD_ROOM
			if absf(at.x) > x:
				at.x = signf(at.x)*x
				v.x *= -SHARD_BOUNCE
			if at.y > FLOOR_Y+high-SHARD_ROOM:
				at.y = FLOOR_Y+high-SHARD_ROOM
				v.y *= -SHARD_BOUNCE
			if at.y < FLOOR_Y+SHARD_ROOM:
				at.y = FLOOR_Y+SHARD_ROOM
				v.y = absf(v.y)*SHARD_BOUNCE
				v *= maxf(1.0-SHARD_RUB*delta,0.0)
				low = true
		elif at.z < -LONG*0.5 and at.z > -LIP_HI:
			# Out the prow: its tunnel's walls to the mouth (the funnel's, by the plate),
			# its lips over and under, each narrowing to the stem.
			var way := _way_at(at.z)
			if absf(at.x) > way.x-SHARD_ROOM and absf(at.x) < way.x+2.0:
				at.x = signf(at.x)*(way.x-SHARD_ROOM)
				v.x *= -SHARD_BOUNCE
			var lip := TUNNEL_X*sqrt(clampf((LIP_HI+at.z)/(LIP_HI-TUNNEL_MOUTH),0.0,1.0))
			if absf(at.x) < lip and at.y > way.z-SHARD_ROOM and at.y < way.z+3.0:
				at.y = way.z-SHARD_ROOM
				v.y = -absf(v.y)*SHARD_BOUNCE
			lip = TUNNEL_X*sqrt(clampf((LIP_LO+at.z)/(LIP_LO-TUNNEL_MOUTH),0.0,1.0))
			if absf(at.x) < lip and at.y < way.y+SHARD_ROOM and at.y > way.y-3.0:
				at.y = way.y+SHARD_ROOM
				v.y = absf(v.y)*SHARD_BOUNCE
				v *= maxf(1.0-SHARD_RUB*delta,0.0)
				low = true
		elif at.z > LONG*0.5+PLATE and at.z < BALCONY.y and absf(at.x) < wide*0.5 and at.y > BALCONY.x-SHARD_ROOM and at.y < BALCONY.x+2.0:
			# Out the stern, under the balcony over the exit.
			at.y = BALCONY.x-SHARD_ROOM
			v.y = -absf(v.y)*SHARD_BOUNCE
		s.v = v
		n.position = at-(s.off as Vector3)
		var spin: Vector3 = s.spin
		n.rotate(spin.normalized(),spin.length()*delta)
		if low and v.length() < SHARD_STILL:
			_shards.remove_at(i)
		elif at.y < -DRAUGHT:
			n.visible = false
			_shards.remove_at(i)

func _new_chunk() -> MeshInstance3D:
	var c := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.5,0.9,1.1)
	c.mesh = b
	c.material_override = _mat(PLATE_C)
	c.top_level = true
	add_child(c)
	return c

## A ball down at `at` going `v`: a splash on the water (`wet`), else dirt and dust.
func _splash(at: Vector3, v: Vector3, wet: bool) -> void:
	if _fx != null: _fx.splash(at,v,wet)
	var gain := 1.0/(1.0+at.distance_to(game.plane.position)/SPLASH_HEARD)
	if wet:
		game.sound.shot("splash",0.9*gain,0.7,at,&"SFX",true)
	else:
		game.debris.burst("dust",at,Vector3.UP)
		game.sound.shot("debris",0.8*gain,0.75,at,&"SFX",true)

func _bits_step(delta: float) -> void:
	_shards_step(delta)
	if _fx != null: _fx.step(delta)
	for i in range(_chunks.size()-1,-1,-1):
		var c: Dictionary = _chunks[i]
		c.t = float(c.t)-delta
		var v: Vector3 = c.v
		v += Vector3.DOWN*16.0*delta
		c.v = v
		var n: MeshInstance3D = c.node
		n.position += v*delta
		n.rotate_x(delta*5.0)
		if float(c.t) <= 0.0 or n.position.y < sea_y:
			n.visible = false
			_chunk_pool.append(n)
			_chunks.remove_at(i)

# --- Her look and solids -------------------------------------------------------

func _build() -> void:
	_warmed()
	var all := solids(wide,high)
	var blocks: bool = "--ship-blocks" in preload("res://scripts/launch_args.gd").user_args()
	_fx = ShipGuns.new(get_parent(),twin._fx if twin != null else null)
	if blocks: _blocks(all)
	else: _dress()
	_deck_guns()
	# The solids: the plates first in `loose`, so a hit near a jamb finds the plate.
	_hull = _record("hull",all.hull)
	_hull["no_break"] = true
	_hull["adopted"] = 0
	game.arches.loose.append(_hull)
	GroundNative.bump_loose()
	_hull_body = _body("Hull",all.hull)
	_wake = Node3D.new()
	_wake.name = "ShipWake"
	get_parent().add_child(_wake)
	if twin != null: _mist_mesh = twin._mist_mesh
	else:
		_mist_mesh = _cluster_mesh(4.0,[Color(0.96,0.97,0.98),Color(0.88,0.9,0.92),Color(0.8,0.83,0.86)],0.75,9,1.0,1.0)
		(_mist_mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("near",MIST_NEAR)
	_plank_mat = twin._plank_mat if twin != null else _mat(PLANK_C)
	for part: String in ["stern","bow"]:
		var box: AABB = (all[part] as Array)[0]
		var record := _record(part,all[part])
		record["strike"] = Callable(self,"_strike")
		record["part"] = part
		game.arches.loose.push_front(record)
		GroundNative.bump_loose()
		var body := _body(part.capitalize(),[box])
		var plate := {"record":record,"body":body,"shape":body.get_child(0),"open":false}
		if blocks: plate["look"] = _plate(box,part)
		else: _plug(plate,part)
		plates[part] = plate

## Built ahead of a ship (the tutorial asks at its land's setup, before
## PARRY's ship), on a worker: her files loaded (the glb's meshes and textures
## made there), each plate's merged plug (`_wholes`) and the guns' shared
## meshes (ShipGuns `warm_shared`), so the frame she is built in has none of
## it. A build joins it first (`_warmed`). The files loaded off the main
## thread leave their load tokens to Godot's exit (4 "ObjectDB instances
## leaked", RefCounted at count 0); the loader's own threads leave more.
const WARM := [MODEL,BALL_MODEL,"res://assets/models/pirate_ship/wood.tres",PUFF_SHADER,WHISTLE]
static var _warm_task := -1
static var _warm_asked := false
## Held so the cache keeps them (the puff's shader and the whistle are read
## later, at her first shot).
static var _warm_res: Array[Resource] = []

static func warm() -> void:
	if _warm_asked or not _wholes.is_empty(): return
	_warm_asked = true
	_warm_task = WorkerThreadPool.add_task(_warm_build,false,"pirate ship warm")

static func _warm_build() -> void:
	var res: Array[Resource] = []
	for path: String in WARM: res.append(load(path))
	var model: Node = (res[0] as PackedScene).instantiate()
	for part: String in ["stern","bow"]:
		var shards: Array[Dictionary] = []
		for shard: Node in model.find_child("CrackPlug_"+part.capitalize(),true,false).get_children():
			if not shard.name.begins_with("Cover"): shards.append({"node":shard,"home":(shard as Node3D).transform})
		_wholes[part] = _merge(shards)
	model.free()
	ShipGuns.warm_shared = ShipGuns.make_shared()
	_warm_res = res

## A warm build in flight joined (before a ship reads what it made).
static func _warmed() -> void:
	if _warm_task == -1: return
	WorkerThreadPool.wait_for_task_completion(_warm_task)
	_warm_task = -1

## What `warm` holds let go (the tutorial land leaving): its build joined.
static func cool() -> void:
	_warmed()
	_warm_res.clear()
	_wholes.clear()
	ShipGuns.warm_shared = {}
	_warm_asked = false

## The model on the moving node, its guns' muzzles read off its empties.
func _dress() -> void:
	_model = (load(MODEL) as PackedScene).instantiate()
	_model.name = "Model"
	add_child(_model)
	_sails = ShipSails.new(_model)
	if twin != null:
		_ball_mesh = twin._ball_mesh
		_flash_mesh = twin._flash_mesh
	else:
		var ball: Node3D = (load(BALL_MODEL) as PackedScene).instantiate()
		_ball_mesh = (ball.find_child("Ball",true,false) as MeshInstance3D).mesh
		ball.free()
		_flash_mesh = _cluster_mesh(FLASH_R,[Color(1.0,0.95,0.7),Color(1.0,0.72,0.28),Color(1.0,0.5,0.1)],1.0,5,0.5,0.0)
	(_model.find_child("Rigging",true,false) as GeometryInstance3D).visibility_range_end = RIGGING_FAR
	_inner = _model.find_child("Interior",true,false) as GeometryInstance3D
	_inner.visibility_range_end = INNER_FAR
	_hull_guns()

## Plate `part`'s plug in the model, each shard's place kept for the reseal. While
## the plate is shut its shards are hidden and drawn as one mesh (`whole`), a draw
## call a pass instead of one a shard; the burst swaps them back.
func _plug(plate: Dictionary, part: String) -> void:
	var plug: Node3D = _model.find_child("CrackPlug_"+part.capitalize(),true,false)
	var shards: Array[Dictionary] = []
	for shard: Node in plug.get_children():
		if shard.name.begins_with("Cover"):
			plate["cover"] = shard
			(shard as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		shards.append({"node":shard,"home":(shard as Node3D).transform})
		(shard as GeometryInstance3D).visibility_range_end = INNER_FAR
		(shard as Node3D).visible = false
	plate["plug"] = plug
	plate["shards"] = shards
	var whole := MeshInstance3D.new()
	whole.name = "Whole_"+part.capitalize()
	if not _wholes.has(part): _wholes[part] = _merge(shards)
	whole.mesh = _wholes[part]
	whole.visibility_range_end = INNER_FAR
	plug.add_child(whole)
	plate["whole"] = whole

## Each plate's shards as one mesh, in the plug's frame (part -> Mesh), built once
## for both ships.
static var _wholes := {}

## `shards` ({node, home}) merged, a surface a material, with LODs as the import
## makes them.
static func _merge(shards: Array[Dictionary]) -> Mesh:
	var by := {}
	for s: Dictionary in shards:
		var mesh: Mesh = (s.node as MeshInstance3D).mesh
		for k in mesh.get_surface_count():
			var mat := mesh.surface_get_material(k)
			if not by.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				by[mat] = st
			(by[mat] as SurfaceTool).append_from(mesh,k,s.home)
	var im := ImporterMesh.new()
	for mat: Material in by:
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES,(by[mat] as SurfaceTool).commit_to_arrays(),[],{},mat)
	im.generate_lods(25.0,60.0,[])
	return im.get_mesh()

func _blocks(all: Dictionary) -> void:
	var half := wide*0.5
	var beam := GUN_X-3.0
	var roof := FLOOR_Y+high
	var top := roof+DECK
	var end := LONG*0.5+PLATE
	var inside := _mat(GUNDECK_C,GUNDECK_C,0.4)
	# Her solid itself, box for box, in one mesh; the gun deck's own lining so its
	# inside reads.
	var st := SurfaceTool.new()
	var unit := BoxMesh.new()
	for box: AABB in all.hull: st.append_from(unit,0,Transform3D(Basis.from_scale(box.size),box.get_center()))
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = st.commit()
	shell.material_override = _mat(HULL_C)
	add_child(shell)
	var skin := 0.04
	_look(_box(-half,FLOOR_Y,-end, half,FLOOR_Y+skin,end),inside)
	_look(_box(-half,FLOOR_Y,-end, -half+skin,roof,end),inside)
	_look(_box(half-skin,FLOOR_Y,-end, half,roof,end),inside)
	_look(_box(-half,roof-skin,-end, half,roof,end),_mat(RIB_C,RIB_C,0.5))
	# Sails: gray box, drawn only; the plane goes through them.
	var sail := _mat(SAIL_C,SAIL_C,0.15)
	for row: Array in [[-30.0,top+8.0,44.0],[2.0,top+9.0,50.0],[33.0,top+17.0,32.0]]:
		_look(_box(-float(row[2])*0.5,float(row[1]),float(row[0])-0.3, float(row[2])*0.5,float(row[1])+18.0,float(row[0])+0.3),sail)
	_look(_box(-0.4,top+1.0,-end-34.0, 0.4,top+1.8,-end),_mat(RIB_C))
	# Inside: ribs every so often to read the speed by, lamps, the guns at their ports.
	var rib := _mat(RIB_C,RIB_C,0.3)
	var z := -LONG*0.5+5.5
	while z < LONG*0.5:
		_look(_box(-half,FLOOR_Y,z-0.5, -half+0.15,roof,z+0.5),rib)
		_look(_box(half-0.15,FLOOR_Y,z-0.5, half,roof,z+0.5),rib)
		_look(_box(-half,roof-0.3,z-0.5, half,roof,z+0.5),rib)
		z += 11.0
	var lamp := _mat(LAMP_C,LAMP_C,3.0)
	var port := _mat(PORT_C,PORT_C,2.0)
	var gun := _mat(GUN_C)
	for gz: float in GUNS_Z:
		for side: float in [-1.0,1.0]:
			_look(AABB(Vector3(side*(half-0.5)-0.2,roof-1.2,gz-0.5),Vector3(0.4,0.9,1.0)),lamp)
			_look(AABB(Vector3(side*half-0.06,GUN_Y-1.1,gz-1.2),Vector3(0.12,2.2,2.4)),port)
			_look(AABB(Vector3(side*(half-0.5)-0.5,FLOOR_Y,gz-1.0),Vector3(1.0,1.1,2.0)),gun)
			_gun(side,gz,beam,gun)

func _record(part: String, boxes: Array) -> Dictionary:
	return {"name":handle+"/"+part,"kind":"ship","node":self,"pos":position,"cos":cos(yaw),"sin":sin(yaw),
		"solid":BoxSolid.build(boxes),"reach":LONG*0.5+45.0,"spec":{}}

func _body(label: String, boxes: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = game.arches.LAYER
	body.collision_mask = 0
	for box: AABB in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
	add_child(body)
	return body

## A plate's look: pale stone, a glowing crack down it on both faces.
func _plate(box: AABB, part: String) -> Node3D:
	var root := Node3D.new()
	root.name = part.capitalize()+"Look"
	add_child(root)
	_look(box,_mat(PLATE_C,PLATE_C,0.2),root)
	var crack := _mat(CRACK_C,CRACK_C,2.5)
	var c := box.get_center()
	var w := box.size.x
	var h := box.size.y
	var strokes := [[0.0,0.0,0.9,0.25],[-0.05,0.3,0.45,-0.6],[0.06,-0.28,0.5,0.7],[-0.2,-0.12,0.45,1.15],[0.22,0.12,0.5,-1.2],[0.12,0.34,0.3,0.9],[-0.14,-0.36,0.3,-0.9]]
	for z: float in [box.position.z-0.05,box.end.z+0.05]:
		for s: Array in strokes:
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.9,float(s[2])*h,0.1)
			m.mesh = b
			m.material_override = crack
			m.transform = Transform3D(Basis(Vector3.BACK,float(s[3])),Vector3(c.x+float(s[0])*w,c.y+float(s[1])*h,z))
			root.add_child(m)
	return root

## A broadside gun at (`side`, `gz`) in blocks: port, barrel, its muzzle.
func _gun(side: float, gz: float, beam: float, mat: Material) -> void:
	_look(AABB(Vector3(side*beam-(0.1 if side > 0.0 else 0.0),GUN_Y-1.0,gz-1.0),Vector3(0.1,2.0,2.0)),_mat(Color.BLACK))
	var x := side*(beam+1.2)
	var barrel := _look(AABB(Vector3(x-1.2,GUN_Y-0.5,gz-0.5),Vector3(2.4,1.0,1.0)),mat)
	_muzzle(side,gz,Vector3(side*(beam+3.0),GUN_Y,gz),Vector3(side,0.0,0.0),barrel,Vector3(-side,0.0,0.0))

## A hull gun's muzzle at `at` (her frame), its bore `out`: its tell, and the
## record the guns fire by. When it fires `kick` recoils along `way` (its
## parent's frame).
func _muzzle(side: float, gz: float, at: Vector3, out: Vector3, kick: Node3D = null, way := Vector3.ZERO) -> void:
	var flash := _tell_flash()
	flash.position = at
	add_child(flash)
	_guns.append({"kind":"hull","side":side,"z":gz,"at":at,"out":out,"flash":flash,"rest":0.0,"kick":-1.0,"kick_node":kick,"kick_home":kick.transform if kick != null else Transform3D.IDENTITY,"kick_way":way})

## A gun's tell: the glow at its muzzle before it fires.
func _tell_flash() -> MeshInstance3D:
	var flash := MeshInstance3D.new()
	if _flash_mesh != null:
		flash.mesh = _flash_mesh
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var b := BoxMesh.new()
		b.size = Vector3(2.2,2.2,2.2)
		flash.mesh = b
		flash.material_override = _mat(Color(1.0,0.8,0.3),Color(1.0,0.7,0.2),5.0)
	flash.visible = false
	return flash

## The hull guns off the glb's `Gun_<side>_<nn>` empties (muzzle, -z out), HULL_GUNS
## a side. Each recoils as a piece of its own: the glb's `Cannon_<side>_<nn>`, or
## (an older glb) cut out of a merged `Cannons` round the empty (ShipGuns.cut),
## which is then hidden. Hidden past INNER_FAR with the gun deck.
func _hull_guns() -> void:
	var cannons: MeshInstance3D = _model.find_child("Cannons",true,false)
	if cannons != null: cannons.visibility_range_end = INNER_FAR
	var cuts: Dictionary = _fx.shared.cuts
	var into := _model.global_transform.affine_inverse()
	var cut := false
	for n: int in range(1,HULL_GUNS+1):
		for side: float in [-1.0,1.0]:
			var key := "%s_%02d" % ["L" if side < 0.0 else "R",n]
			var empty: Node3D = _model.find_child("Gun_"+key,true,false)
			if empty == null: continue
			var frame: Transform3D = into*empty.global_transform
			var piece: Node3D = _model.find_child("Cannon_"+key,true,false)
			if piece is GeometryInstance3D: (piece as GeometryInstance3D).visibility_range_end = INNER_FAR
			if piece == null and cannons != null:
				if not cuts.has(key):
					var source: Transform3D = into*cannons.global_transform
					cuts[key] = ShipGuns.cut(cannons.mesh,func(q: Vector3) -> bool: return ShipGuns.in_gun(source*q,frame),frame.affine_inverse()*source)
				var m := MeshInstance3D.new()
				m.name = "Cannon_"+key
				m.mesh = cuts[key]
				m.transform = frame
				m.visibility_range_end = INNER_FAR
				_model.add_child(m)
				piece = m
				cut = true
			var way := Vector3.ZERO
			if piece != null: way = ((piece.get_parent() as Node3D).global_basis.inverse()*empty.global_basis.z).normalized()
			_muzzle(side,local(empty.global_position).z,local(empty.global_position),(_inv.basis*-empty.global_basis.z).normalized(),piece,way)
	if cut: cannons.visible = false

## The deck guns: at the glb's `DeckGun_<side>_<nn>` empties (the mount's pivot,
## -z outboard), turned by their `_Mount` child, laid by its `_Barrel`, fired from
## that one's `_Muzzle`; where it has none of those, stand-ins there; where it has
## no empties, stand-ins at DECK_GUNS on the top deck.
func _deck_guns() -> void:
	var top := FLOOR_Y+high+DECK
	var under: Node3D = _model if _model != null else self
	for i in DECK_GUNS.size():
		for side: float in [-1.0,1.0]:
			var key := "%s_%02d" % ["L" if side < 0.0 else "R",i+1]
			var pivot: Node3D = _model.find_child("DeckGun_"+key,true,false) if _model != null else null
			if pivot == null:
				var spot: Vector2 = DECK_GUNS[i]
				pivot = Node3D.new()
				pivot.name = "DeckGun_"+key
				pivot.transform = Transform3D(Basis(Vector3.UP,-side*PI*0.5),Vector3(side*spot.x,top,spot.y))
				under.add_child(pivot)
			var mount := _part(pivot,"_Mount")
			var barrel := _part(mount,"_Barrel") if mount != null else null
			var muzzle := _part(barrel,"_Muzzle") if barrel != null else null
			for part: Node3D in [mount,barrel]:
				if part is GeometryInstance3D: (part as GeometryInstance3D).visibility_range_end = INNER_FAR*1.3
			if muzzle == null:
				var built := _deck_stand_in(pivot)
				mount = built[0]
				barrel = built[1]
				muzzle = built[2]
			var flash := _tell_flash()
			flash.position = muzzle.position
			barrel.add_child(flash)
			var frame: Transform3D = global_transform.affine_inverse()*pivot.global_transform
			_guns.append({"kind":"deck","side":side,"z":frame.origin.z,"pivot":frame,"yaw_node":mount,"yaw_home":mount.transform,"barrel":barrel,"barrel_home":barrel.transform,
				"muzzle":muzzle.position,"yaw":0.0,"pitch":DECK_REST,"err":INF,"flash":flash,"rest":0.0,"kick":-1.0,"kick_node":barrel})

## The child of `n` whose name ends with `end`, or null.
func _part(n: Node, end: String) -> Node3D:
	for c: Node in n.get_children():
		if c is Node3D and str(c.name).ends_with(end): return c
	return null

## A deck gun's stand-in on `pivot` (on the deck, -z outboard): a round base and a
## turning carriage with two cheeks (one mesh), the barrel on its trunnions (the
## glb's hull gun barrel, else a box). [mount, barrel, muzzle].
func _deck_stand_in(pivot: Node3D) -> Array:
	var mount := Node3D.new()
	mount.name = str(pivot.name)+"_Mount"
	pivot.add_child(mount)
	var barrel := Node3D.new()
	barrel.name = str(pivot.name)+"_Barrel"
	barrel.position = Vector3(0.0,DECK_LIFT,0.0)
	mount.add_child(barrel)
	var muzzle := Node3D.new()
	muzzle.name = str(pivot.name)+"_Muzzle"
	muzzle.position = Vector3(0.0,0.0,-DECK_MUZZLE)
	barrel.add_child(muzzle)
	var shared: Dictionary = _fx.shared
	var key := "deck" if _model != null else "deck_blocks"
	if not shared.has(key): shared[key] = _deck_meshes()
	var meshes: Array = shared[key]
	for k in 2:
		var m := MeshInstance3D.new()
		m.mesh = meshes[k]
		m.visibility_range_end = INNER_FAR*1.3
		(mount if k == 0 else barrel).add_child(m)
	return [mount,barrel,muzzle]

## The stand-ins' [mount, barrel] meshes: the mount from boxes and a drum, in the
## ship's wood; the barrel cut from the glb's first starboard hull gun, in the
## outside iron (blocks: boxes in the gray box's colours).
func _deck_meshes() -> Array:
	var wood: Material = load("res://assets/models/pirate_ship/wood.tres") if _model != null else _mat(RIB_C)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var k := DECK_SIZE
	var drum := CylinderMesh.new()
	drum.top_radius = 1.15*k
	drum.bottom_radius = 1.4*k
	drum.height = DECK_LIFT-1.5*k
	drum.radial_segments = 10
	drum.rings = 1
	st.append_from(drum,0,Transform3D(Basis.IDENTITY,Vector3(0.0,drum.height*0.5,0.0)))
	var deck := BoxMesh.new()
	deck.size = Vector3(2.6,0.3,3.0)*k
	st.append_from(deck,0,Transform3D(Basis.IDENTITY,Vector3(0.0,DECK_LIFT-1.35*k,0.1*k)))
	for x: float in [-0.95,0.95]:
		var cheek := BoxMesh.new()
		cheek.size = Vector3(0.4,1.6,1.7)*k
		st.append_from(cheek,0,Transform3D(Basis.IDENTITY,Vector3(x*k,DECK_LIFT-0.4*k,0.1*k)))
	var mount := st.commit()
	mount.surface_set_material(0,wood)
	var barrel: Mesh
	var cannons: MeshInstance3D = null
	if _model != null: cannons = _model.find_child("Cannons",true,false) if _model.find_child("Cannons",true,false) != null else _model.find_child("Cannon_R_01",true,false)
	var empty: Node3D = _model.find_child("Gun_R_01",true,false) if _model != null else null
	if cannons != null and empty != null:
		var into := _model.global_transform.affine_inverse()
		var frame: Transform3D = into*empty.global_transform
		var source: Transform3D = into*cannons.global_transform
		var trunnion := Transform3D(frame.basis,frame.origin+frame.basis.z*DECK_MUZZLE/DECK_SIZE)
		var swap := {}
		for si in cannons.mesh.get_surface_count():
			var mat: Material = cannons.mesh.surface_get_material(si)
			if mat != null and mat.resource_path.ends_with("_in.tres") and ResourceLoader.exists(mat.resource_path.replace("_in.tres",".tres")):
				swap[mat] = load(mat.resource_path.replace("_in.tres",".tres"))
		barrel = ShipGuns.cut(cannons.mesh,func(q: Vector3) -> bool: return ShipGuns.in_gun(source*q,frame,6.5,1.2,0.9,1.2),Transform3D(Basis.from_scale(Vector3.ONE*DECK_SIZE))*trunnion.affine_inverse()*source,
			func(m: Material) -> bool: return m == null or not m.resource_path.get_file().begins_with("wood"),swap)
	if barrel == null or barrel.get_surface_count() == 0:
		var box := BoxMesh.new()
		box.size = Vector3(1.0,1.0,0.0)*DECK_SIZE+Vector3(0.0,0.0,DECK_MUZZLE+1.8)
		barrel = box
		box.material = _mat(GUN_C)
		var shift := ArrayMesh.new()
		var arrays := box.get_mesh_arrays()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in v.size(): v[i] += Vector3(0.0,0.0,0.9-DECK_MUZZLE*0.5)
		arrays[Mesh.ARRAY_VERTEX] = v
		shift.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		shift.surface_set_material(0,_mat(GUN_C))
		barrel = shift
	return [mount,barrel]

func _look(box: AABB, mat: Material, under: Node3D = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = box.size
	m.mesh = b
	m.material_override = mat
	m.position = box.get_center()
	under.add_child(m)
	return m

func _mat(c: Color, glow := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = energy
	return m
