# Ship build: handoff

Branch `iter/ship-build` (loop `ship-build`, spec `spec-ship-build.md`), worktree
`/Users/davidkalina/Documents/Projects/zenscape-ship-build`. Both pirate ships now
carry the concept's redesign (`ship-look-concept.md`, the tar and slate scheme): a
raked, sheered near-black hull with a pointed prow and a tunnel cut through it, a
carved sun on the transom, tall masts with nine square sails and a jib in cool grey
canvas, the wind spiral on the fore course and the sun on the main, pennants and an
ensign. They ride the swell (`ship-rock-handoff.md`). The plane bursts in through the
stern plate, flies the gun deck, bursts the bow plate and leaves through the prow's
tunnel, and her solid is fitted to the model's own shape. Three hull guns a side fire
straight and four modelled deck guns turn and lob (`ship-guns-handoff.md`). There is
no figurehead: the user saw three options and axed it for now.

Play it:

```
cd /Users/davidkalina/Documents/Projects/zenscape-ship-build && python3 tools/play.py -- --no-title --pilot-file=/tmp/ship-build.json --ship-start --full-meter
```

`--ship-start` puts the plane off the first ship's beam, `--full-meter` keeps a surge
roll ready for the plates. `--ship-blocks` swaps the model for the gray box of her
solid, box for box. `--one-ship` leaves the second ship out. `--ship-rock=0` stops the
ride.

Stills (`ship-build-stills/`, rendered on the Mac at 1440x900 in the game's light,
the real ship in the play scene):

- `final_sheet.jpg`: the nine below in one sheet.
- `final_d30.jpg`, `final_d100.jpg`, `final_d300.jpg`: 30 m off her side, 100 m and
  300 m off her bow quarter, on her sunlit side, at the opening hour.
- `final_chase.jpg` (the chase camera 120 m astern, a ball coming past),
  `final_stern_plate.jpg`, `final_gundeck.jpg`, `final_tunnel.jpg` (the camera at
  the bow plate, the plane in the prow's tunnel), `final_lip.jpg` (out under the
  upper lip): one pass by real input, stern to bow, rocking on.
- `final_fly_through.jpg`: the same pass filmed every 4 frames on the play camera,
  from the roll to past her bow.
- `final_golden_hour.jpg`, `final_golden_hour_d100.jpg` (`--hour=17`, the sun 11 deg
  up behind the camera) and `final_sunset.jpg` (`--hour=18`, her against the sun).
- `final_tunnel_slot_before.jpg`: the slot this round closed (below).

## What changed

All of the model is `art/blender/ship/ship_build.py` (same pipeline as before:
strake ribbons, painted maps, the `.tres` materials, the glb's node contract, the
build's self-checks); it writes `assets/models/pirate_ship.glb`, the maps and shaders
in `assets/models/pirate_ship/`, and the solid table `ship_solids.gd`. The game side
is `scripts/endless/pirate_ship.gd` and `scripts/endless/ship_sails.gd`.

- **Hull** (599b7bc1). The concept's section (14.5 m half breadth at 8 m, tumblehome
  to 9.2 at 32), a plan narrowing all along, a raked stem, the keel rising to both
  ends, a small strake wobble (`WOBBLE` 0.12). A continuous sheer (`SHEER`: 17 m
  amidships, 32 at the stern, 25 at the bow) with strakes clipped to it. The transom
  stands at the stern plate (z 56.5), the counter leans out above y 14 and the
  sternpost tucks under 2.6. `STRAKE` 1.2 and `KEEL_Z` -5.8 put strake lines on 2.6 and
  13.4, the corridor cut's edges. Decks: poop 28, quarterdeck 22, forecastle 21, waist
  15. Tar and slate: near-black tar, a step lighter above the waist, a grey boot-top,
  dark iron-grey trims where the oxblood was.
- **The prow** (599b7bc1, b0f1bd60). Forward of the bow plate a tunnel (walls x ±10.4,
  floor 2.6, roof 13.4) runs out under two lips to the stem; framing timbers round the
  cut and along the lips; a round slate boss at the stem's head (7a: it was a square
  box that read as a flat grey face bow on). Over the 6 m in front of the plate
  (`FUNNEL_LEN`) the tunnel's walls, floor and roof close to the gun deck's line (x
  ±9.06, 3.0, 13.0), so no face round the plate looks forward and an off-centre plane
  coming in from the bow glances in.
- **Upperworks** (514bad8d). Quarter galleries of framed six-pane lights on the raked
  counter; a carved slate sun on the transom (`build_sun`, the main course's glyph in
  relief); balustrades across the castles' breaks; timberheads along the waist; a
  stepped fret painted on strake 17 in dull slate ink, toned down so it fades into the
  hull by 150 m. Rule found: vertex colours are linear, so a vertex-coloured trim wants
  about a third of a painted map's number for the same look.
- **Rig and sails** (ed45134e, a375e9c7). Masts to 92, 104 and 80 m (fore, main,
  mizzen), each lower mast, topmast and pole with tops, crosstrees and trucks; nine
  square sails (`Sail_1a..1c`, `Sail_2a..2d`, `Sail_3a..3b`) braced 34 degrees and the
  jib (`Sail_0a`) on the fore topmast stay; rigging re-led to the new masts. The cloth's
  shader takes a skew so the jib hangs as a jib (it bellies to port on every heading:
  the shader has no tacks). `SAIL_CELL` 2.0 x 1.2 keeps ten sails twice the area at
  5.1k triangles; `ship_sails.gd` `REACH` 22. The two glyphs are brushed into the sail
  map at their own aspect, near-black and worn; the rest is plain bordered grey canvas,
  painted a little blue so the sun doesn't warm it to beige. Pennants at the trucks
  (`Flag_1..3`) and an ensign aft (`Flag_E`) in their own shader (`ship_flag.gdshader`)
  stream down the same air the sails take and droop as it drops.
- **Collision** (268f116b, b0f1bd60, fb374066). `fit_solids` in the build steps the
  hull's shape into horizontal bands and writes 427 boxes to
  `assets/models/pirate_ship/ship_solids.gd` (Godot frame); `solids()` reads them plus
  the two plates. Hollow where the gun deck, the tunnel and the open decks are; the
  masts, the ensign staff, galleries, channels, rudder and bowsprit are in it. Not in
  it: deck furniture, timberheads, the lips' framing timbers, the tops, yards, sails,
  flags and rigging, the deck guns. `in_corridor` and the bow pad count the tunnel;
  `_way_at` and `_wall_off` give the glances off the tunnel's walls, the funnel's lean
  and the lips; `lip_solid()` reads the upper lip's end from the solid so a rebuild
  can't move it out from under the corridor. `_keep_off_walls` holds the plane's middle
  off the corridor's walls by the reach its roll gives it (a surge roll by a wall used
  to start the move inside her and SkyGlide put the plane on her deck). The bow plate's
  shards bounce off the funnel, the tunnel's walls and the upper lip and lie on the
  lower lip till the reseal. The funnel's glance costs speed (75 to 50 m/s at Boost).
- **Guns** (afef0160, after the ship-guns merge 4b9e5dcd). Three hull guns a side at
  z 32, 0, -32, each its own node `Cannon_<side>_<nn>` with its origin at the muzzle;
  four deck guns to the guns handoff's contract (`DeckGun_<side>_<nn>` with `_Mount`,
  `_Barrel`, `_Muzzle`) on a raised dais, the rigging re-led clear of their swing. The
  build sweeps each barrel through its swing and lay against the rest of her and fails
  on a clip.
- **Finish** (0b259a94, 90f365dd). The gun deck's plank seams backed (they showed slits
  of sky, as the tunnel's did before 4b). The white haze in the gun deck and the "bow
  burst's dust" over the camera were both the sink's mist, not fog or dust: its discs
  now fade as the eye comes in (`muzzle_puff.gdshader` `near`) and a return hides any
  mist left. Each shut plate is drawn as one merged mesh (`Whole_Stern`, `Whole_Bow`,
  built at runtime and shared by both ships) and swapped for its shards on a burst; the
  gun deck's inside casts shadows only within `INNER_SHADE` 120 m.

## Look items from the fly-through films (spec task 7)

- The gun deck's seams showing sky: fixed (backed, 7a).
- The white haze in the gun deck flying toward the sun: fixed. It was the sink's mist
  (7a), only on a ship's second pass in the drivers; in play only the exit mist showed.
- The bow burst's dust over the camera: fixed, the same mist.
- "The spritsail as a flat grey square above the tunnel, bow on": there is no
  spritsail; it was the stone boss at the stem's head, now a round, darker knob (7a).
- Found in the final stills and fixed (7c): just after the bow burst, the chase camera
  (at the plate, about 11 m up) looked up through a slot over the plate's hole, between
  the funnel's roof (13.0 at the plate) and the gun deck's ceiling (14.8), into the
  void over the tunnel: sky between the bow's inner sides for 3 or 4 frames
  (`final_tunnel_slot_before.jpg`). A dark backing facing aft (`build_interior`,
  `BOW_BACK`), 13.01 to 16.0 just aft of the plate, closes it; while the plate is shut
  it lies inside the plug. +2 triangles, no new draw call.
- Left: the tunnel reads near black from inside in bare-glb stills (it reads on the
  chase camera in the game); white wash patches on the sea after a driver forces a
  sink (`_gone`), not seen in play.

## What she draws

Measured rendered at 1440x900 on the Mac, the play loop held, one ship, she shown
minus hidden (`RenderingServer` render info), after 7b. No frame times (other agents
shared the GPU then).

| View | Triangles | Shadow triangles | Draw calls | Shadow draws |
|---|---|---|---|---|
| In the gun deck | 74.4k | 286k | 69 | 218 |
| Chase, 95 m astern | 79.9k | 233k | 87 | 241 |
| 30 m off her side | 63.2k | 249k | 77 | 265 |
| 100 m | 80.5k | 236k | 87 | 236 |
| 300 m | 77.3k | 107k | 87 | 158 |
| Bow on, 465 m | 68.9k | 85k | 86 | 136 |
| 600 m | 67.9k | 45k | 86 | 78 |
| 1 km | 31.4k | 0 (past the shadows) | 45 | 0 |

Two ships draw twice that when both are in view. 7b cut about 50 draw calls a pass
at every range to 700 m (the plates as one mesh) and 24-47k shadow triangles past
120 m (the gun deck's shadows).

## Triangles (80,552 in the glb)

| Node group | Triangles | Range |
|---|---|---|
| Interior | 23,790 | hidden past `INNER_FAR` 700 m; shadows only within 120 m |
| Hull | 17,926 | always |
| Upperworks | 14,272 | always |
| DeckGun_* (4 guns, 8 meshes) | 5,760 | past 910 m |
| Shard_* (52) | 5,128 | 700 m; drawn as `Whole_*` while shut |
| Sail_* (10) | 5,124 | always |
| Cannon_* (6) | 3,216 | 700 m |
| Mast_* (3) | 2,904 | always |
| Rigging | 1,368 | 450 m (`RIGGING_FAR`) |
| Flag_* (4) | 456 | always |
| Stays | 356 | always |
| Bowsprit | 188 | always |
| PortLid_* (5) | 60 | always |
| Cover_* (2) | 4 | always |

Against the concept's guess of about 60k: the gun deck's inside is 23.8k (it guessed
17.6k, as before the build), the upperworks 14.3k with the galleries and rails, and
the deck guns are modelled (5.8k).

## Geometry tricks (`docs/art/model-budget.md`)

| Trick | Used | Saving (measured where it says so) |
|---|---|---|
| Sculpt high, bake low | No: planks, rails and timbers are real geometry, grain and grime are painted maps | None; a bake pipeline would buy perhaps 5k hull triangles |
| Import LODs | On (`generate_lods`), but they hardly thin her | Measured: 4% fewer triangles at 300 m, 13% at 465 m, 14% at 600 m, 24% at 1 km. Only the hull's plank skin gets a LOD that shows (from about 260 m); every other surface's first LOD is 1.2-10 m off, so it shows only past 1.2-10 km. She is built of many small pieces each near its fewest triangles |
| Visibility ranges | Yes: Rigging 450 m, Interior, hull guns and shards 700 m, deck guns 910 m. Not done: the prow's framing timbers and tunnel lining past 400 m (about 2.5k triangles, 4% of her there; split out they'd add a draw call to every pass, and hidden they'd open the tunnel's sides bow on) | Measured, 7b: Interior's shadows off past 120 m, 24-47k shadow triangles a frame at 150-600 m |
| Silhouette geometry | Yes: the raked ends, the prow's lips and tunnel, rails and galleries are real outline; the glyphs and the fret are paint | Glyph sails at one sheet each, against about 2k triangles a sail cut out |
| Rigid parts on bones | Not applicable: nothing is rigged (the deck guns turn and lay as node transforms) | None |
| Parallax depth | No: the fret is painted with its ground cut back in the normal map | 2-4k triangles against modelled frets |
| Vertex-colour grime | Yes: the gun deck's light and shade, plank tints, the deck barrels' soot | Replaces real interior lights, about 1-2 ms while inside (estimate) |
| Merged meshes | Yes (7b): each shut plate's 26 shards drawn as one mesh | Measured: about 50 draw calls a pass at every range to 700 m |

The far form (a low shell swapped in at range) is task 8 of the spec: measured first
(below), built only if hiding both ships at range saves enough.

## The far form: what it could save (task 8, measured)

The most a far form could save is what both ships cost at range, so this is both
ships shown against both hidden (`visible` off on each ship's node; her wake stays).
Rendered in the play scene at 1440x900 on the Mac (Apple M5 Pro, the 3D drawn at 0.8
scale), `--ship-start` (two ships, 1833 m apart), the play loop held, fov 70. Six held
views: on ship 1's sunlit side at 450 m, 600 m and 1 km (`side`; ship 2 is out of
view, 1.0-1.4 km off), and on the line from ship 2 through ship 1, 450 m, 600 m and
1 km past her (`both`; ship 2 in the frame behind her at 2.3-2.8 km). Each A/B ran
ABBA over 10 rounds, 40 frames a state after 10 to settle. Each run held the window
lock; other agents' windows were open on the Mac between runs (two runs waited for
one to close), so the GPU was not this loop's alone all session.

`viewport_get_measured_render_time_gpu` reads 0 on Metal, so the GPU times are from
the same build on Vulkan (MoltenVK, `--rendering-driver vulkan`), run twice. On
Metal, the game's backend, the wall time from frame to frame (vsync off) and the
viewport's render CPU time. The wall time holds the GPU's while the GPU is the
bottleneck, as it is on Vulkan here (its GPU time within 0.05 ms of the wall).

| View | Draw calls, shown / hidden (visible + shadow) | Saved, of the frame's | GPU saved, Vulkan run 1 / run 2 (frame) | Metal wall saved (frame) | Render CPU saved, Vulkan 1 / 2 / Metal |
|---|---|---|---|---|---|
| side 450 m | 676 / 510 | 165, 24.4% | -0.37 / -0.24 ms (18.6 / 13.3) | -0.46 / -0.26 ms (16.0 / 14.0) | 0.09 / 0.07 / 0.07, 0.06 ms |
| side 600 m | 713 / 548 | 165, 23.1% | -0.26 / -0.20 ms (18.2 / 14.4) | -0.24 ms (16.6) | 0.18 / 0.05 / 0.15 ms |
| side 1 km | 498 / 453 | 45, 9.0% | -0.19 / -0.11 ms (17.1 / 13.6) | -0.20 ms (15.4) | 0.04 / 0.03 / 0.06 ms |
| both 450 m | 628 / 416 | 212, 33.8% | -0.10 / -0.03 ms (15.8 / 15.5) | -0.25 ms (14.3) | 0.16 / 0.07 / 0.05 ms |
| both 600 m | 599 / 392 | 207, 34.6% | +0.10 / 0.00 ms (16.0 / 15.3) | +0.06 ms (15.2) | 0.18 / 0.08 / 0.19 ms |
| both 1 km | 463 / 373 | 90, 19.4% | -0.04 / -0.13 ms (15.9 / 14.5) | +0.01 ms (15.4) | 0.08 / 0.03 / 0.10 ms |

A negative saving is a frame that ran faster with the ships shown. The first Metal
run's 450 m lines were cut from its printout, so those two views ran again: side
twice, both once (a third run's `both` view is dropped: its window stopped drawing,
0.3 ms frames and no change in draws). Triangles: at side 450 m both ships are 68k of
1.30M visible and 45k of 653k shadow triangles; at both 450 m, 94k and 45k. At 1 km
she is past the shadows (no shadow draws change). The 450 m views:
`ship-build-stills/far_cost_side_450.jpg`, `far_cost_both_450.jpg` (ship 2 behind her).

What it says: at these ranges the ships cost the GPU nothing measurable. No view
saved more than 0.1 ms in either Vulkan run or on Metal, and most ran a little faster
with them shown (their pixels likely cost less than the sea and sky behind them; at
450 m she covers about 2% of the frame). What hiding them does save is draw calls: 165-212
a frame from 450 m to 600 m (23-35% of the frame's), 45-90 at 1 km (9-19%). The CPU
pays for those: 0.03-0.26 ms of render CPU time a frame here.

The call, by the spec's rule (build only if hiding both saves 0.5 ms of GPU time a
frame or 10% of the frame's draw calls): the GPU test fails at every view; the draw
call test passes at 450 m and 600 m (and at 1 km with both in view). So the rule says
build, and the build's saving would be draw calls and a few tenths of a millisecond
of render CPU, not GPU time. A far form of 3-4 materials would draw about 4 calls a
pass a ship in place of about 87.

## Rebuilding and retuning

```
python3 tools/blender.py run art/blender/ship/ship_build.py
python3 tools/godot.py --headless --editor --import
```

The build exits 1 on a failed self-check: the stern and bow mouths (the 18 x 10
rectangle 30 m past each plate, 4 cm grace, through the prow's tunnel), the corridor,
the nodes and muzzles, the gun chain's parenting, the deck guns' swing. It rewrites
`ship_solids.gd` after the export; commit it with the glb. Keep `KEEL_Z`/`STRAKE` on
2.6 and 13.4. Keep pirate_ship.gd's `DECK_GUNS`, `DECK_LIFT`, `DECK_MUZZLE` (used by
`--ship-blocks` only now) in step with the build's `DECK_GUN_X/Y`; `DECK_SWING` and
`DECK_RAISE` are in both files. Paint colours: maps are sRGB-ish, vertex colours
linear (a third of the number). The sun and the sky's fill lift dark albedo about two
stops in the game, so set values by eye in the game.

What in `pirate-ship-model-handoff.md` no longer holds: the triangle table, six guns a
side and a merged `Cannons`, `Sail_2a..2c` (now to `2d`), the 59 m masts, the beak and
spritsail. The pipeline, the plugs' names and `CorridorStart`/`CorridorEnd` hold.

## Proved

Through the real play loop (uncommitted drivers in `scratch/ship_build/`):

- The fly-through, stern to bow on the chase camera, by real input with rocking on
  (`finish/final.gd --part=fly`, rendered): no crash, both plates burst, out past
  her bow, twice in a run (the stills and the film).
- `--one-ship`: one ship (`ships 1`), the same pass headless: no crash, both plates
  burst.
- Ship 2 (`col/fly_film.gd --second --case=out`, headless): no crash, both plates
  burst, no bow shard in her solid, the eye kept out of her solid.
- Earlier rounds, on this model's shape: bow to stern and off-centre from the bow
  through the funnel (`col/fly_film.gd`, `col/funnel.gd`, `col/tunnel.gd`), the
  wall and roof glances (`ship_rock/ship_wall.gd` 10/10), sinking
  (`ship_rock/ship_sink.gd` 22/23, see below), two ships (`col/ship_two.gd`: tour,
  both, skim, apart all passing), the plates as one mesh and the gun deck's shadows
  (`finish/whole_check.gd`, 36/36 a ship), the deck guns' swing (the build's own
  check).
- Smoke: `studies/endless_flight.tscn` plain and with `--ship-blocks` pass; with
  `--ship-start --full-meter` it runs clean and then hangs on quit (below).

## Not proved

- PC fidelity: every still is from the Mac.
- Frame times in play: task 8's are held views (above), not a flight. The GPU times
  are from Vulkan on the Mac; Metal reports none. Nothing measured on the PC, where a
  CPU-bound frame would feel the draw calls more.
- The jib always bellies to port; the lower shrouds pass through a slack course's aft
  half (braced 34 degrees, as on a real ship; with wind the belly carries it forward).
- Seen once in a sequenced driver run and not since: a hands-off plane drifting into
  the gun deck's wall-and-roof corner near the stern was put on her poop.
- `ship_rock/ship_sink.gd` has failed one check since the rig round (3a): "ring mark
  up on the first ship". Not traced.
- With `--ship-start`, Godot sometimes hangs on quit after a clean run (before this
  loop too); the smoke check of those flags times out on it.

## Tests

No committed test references `pirate_ship.gd`, `ship_sails.gd` or the ship's files.
`test_world_scale_guard.gd` (scans every script) passes. The one test that opens
endless flight, `test_cloud_shade_steady.gd`, is `suite: gpu` and wasn't run. No test
is known to break.
