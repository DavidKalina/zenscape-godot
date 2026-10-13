# The generated layer, round 5: the dragon's roost (2026-10-12)

> Branch `worktree-agent-a6e8f8e9d11b5beb6`, cut from `roguelike` at
> d7eb317b. The sprawl is layer-round4-sprawl.md (its "4B-2" section is
> the shape this builds on).

The user, after 4B-2: "It actually reads pretty damn good. I like this a
lot. Only thing I would change is I would like to see the dragon's roost
somewhere in the level. Kind of isolated from everything else. Definitely
high up. Not... kind of apart from everything."

## Run it

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11
```

Good seeds:

| Seed | Where the roost stands from the spawn | Why |
|---|---|---|
| 11 | south-east, 492 m off, turf 125 m up, peak 243 m up | 33 degrees off the spawn's facing, so it is in the first frame beside the trail to the next region. You see its front (the dragon's neck round the tower, the hoard on the ledge). Seen from both neighbourhoods. Plans in 1-6 s. |
| 2 | south, 474 m off, turf 168 m up | 27 degrees off the facing, the closest to straight ahead. A ferry gulf. |
| 4 | south-east, 533 m off, turf 114 m up | 33 degrees off the facing, front on. Slow to plan (15 redraws, 4-20 s). |
| 13 | south-east, 606 m off, turf 115 m up | 33 degrees off, front on, further off. |
| 1 | south, 523 m off, turf 215 m up, peak 333 m up | Three neighbourhoods, all three see it. The tallest layer, so the roost is very high: its peak may sit at the top of the frame. |

Without `--shape=sprawl` nothing changes (round 3's shape has no roost).

The card gains a line: `The dragon's roost: south-east, 492 m off, its
turf 125 m up (its peak 243 m)`.

## What was built

- **The roost in every sprawl plan** (`plan.roost`,
  `scripts/roguelike/layer_sprawl.gd` `_roost`). It is laid after the exit
  chain and the spawn's view, before the next region. It is not one of
  `plan.isles`, so nothing that walks, rides or routes over the isles sees
  it.
  - **Apart.** Its footprint (a circle round its middle that holds every
    cell of it, about 90 m) keeps `ROOST_GAP` = 150 m flat from every
    isle's bounds, every edge's path (the route, the greed branch, the
    climbs, the gulfs' lines, the exit chain), every sample of the rides'
    tubes (the serpents' loops and the ferries' routes), and every cannon,
    its kegs and its mark. Over seeds 1-16 the least gap found was
    151-162 m. No route, stones or ride reaches it.
  - **High.** Its turf stands `ROOST_OVER` = 15 m over the highest solid
    of every isle in the layer, so the whole mountain is over the skyline.
    Its peak is 118 m higher still (133 m over the layer's top). From the
    spawn that comes to turf 98-215 m up and the peak 216-333 m up.
  - **Its side** (how it is chosen). Round the layer's middle (the mean of
    its isles' middles), 36 bearings are tried. Each is taken outward to
    the first spot that is clear by the gap, within `ROOST_RING` = 680 m of
    the base's middle. A spot is kept only if all of these hold:
    - it stands at least `ROOST_OFF_EXIT` = 55 degrees off the exit
      heading, seen from the gate, so the chain and the gate look past it
      at the next region;
    - it stands at least `ROOST_OFF_NEXT` = 25 degrees off the spawn's line
      to where the next region will stand;
    - from the spawn's eye, its tower is in sight over this layer's isles
      (by occupancy).

    The kept spots are scored, and the best wins. Points go to:
    - being seen from more neighbourhoods (from any isle's highest rim or
      spot);
    - standing within `ROOST_VIEW` = 35 degrees of the spawn's facing, so
      it shares the first frame with the next region, with points falling
      off over the next 40 degrees;
    - its front facing the spawn. The motif was laid out to be seen from
      the north-west (Roost `V`): the dragon's neck round the tower, the
      ledge and the hoard;
    - standing nearer.

    In practice the roost lands to one side of the trail, level with the
    clusters or beside the last one: 26-60 degrees off the spawn's facing
    (mostly 33-41) and 406-670 m off. Every seed from 1 to 16 is seen from
    every neighbourhood.
  - **Moved, never turned.** The motif, its dragon's pose and its air
    read the mountain's own ground (`Roost.ground`) in its own frame, so
    the roost stands with an offset only. Its front always faces
    north-west. The scoring prefers spots where that front faces the
    spawn, but it can't force it.
  - **Next region.** Its sight line and its distance from this layer now
    count the roost too (`sight_clear`, `_apart_dist`). No seed's next
    region moved because of it: over seeds 1-24 no draw failed for want of
    a roost, so every layout is 4B-2's.
- **Its occupancy** (data/layer/pieces.json, `dragon_roost`). It was
  baked with the new `--only=` flag of tools/bake_layer_pieces.gd, which
  appends one entry and leaves the others byte for byte:
  ```sh
  godot --headless --path . --script tools/bake_layer_pieces.gd -- --no-sky --no-life --no-flora --no-lode --no-chain --no-dragon-roost --only=dragon_roost
  ```
  The roost's keel has no collision, so the bake only sees its turf and
  crags (lowest solid 29 m). `LayerSprawl.roost_occ()` adds the hanging
  keel as a cone, `Roost.DEPTH` (70 m) under the turf at its middle, for
  the planner and the silhouette.
- **On the stage** (`studies/run_layer.gd`):
  - The roost motif goes into the sky's isles with the rest
    (`layer_entries`). The sky builds the nearest isle first, so **the
    roost is built last**, after every isle he can walk. That is the cheap
    choice: the isles he walks on stand first, and the roost is a far view
    that can come up a few seconds later.
  - **The dragon** is the aqueduct isle's own sleeping dragon
    (scripts/dragon_roost.gd on scripts/sky_dragon.gd), curled on the
    ledge with his neck round the tower, his breath and haze, his tail
    twitch and his night glow. The air round the mountain comes with him
    (scripts/roost_air.gd: the wreath, the cold, the carrion birds, the
    crashed plane).
    - Both now take an `offset` (where the mountain stands) and have a
      `move_to`. He is laid once, on the first sprawl layer (1.35 s on
      the main thread). After that, each new layer moves him and his air
      by the offset (0 ms), since the pose and its settling read the
      mountain's own frame.
    - He shows once his mountain stands (the study's `_roost_frame`).
  - **His wake is left off.** In the aqueduct scene he wakes once a world
    day and flies `DragonWake.CIRCUIT`. That is a list of world points
    threaded between the aqueduct sky's authored isles, and its landing
    reads `Roost.AT`. Over a generated layer it would fly through empty
    sky or through isles, and land on the wrong mountain. It needs a
    circuit laid from the plan (see the notes below), so the layer's
    dragon gets no `wake` and never wakes.
  - **The clouds** (`studies/run_layer_sky.gd` `keep_roost`). The drifting
    puffs thin away over the roost as they do over the layer's band (the
    cloud host's `keep`, per layer). The cumulus towers stand 340 m or
    more off anywhere inside `ROOST_RING`.
- **The next region's silhouette has its roost too** (the optional part).
  `_place_next` adds the next plan's roost to the silhouette (merged
  cells, not the landmark) if it stands `APART` (120 m) from this layer's
  isles and roost and off the spawn's sight line to the landmark. On all
  six test seeds it did. The landmark is still the highest of the next
  region's isles. Its roost stands 130-135 m higher, so from afar the
  mountain is what you see first over there too. It costs about 4-5k
  triangles more: the silhouette is now 18.9k-24.2k triangles, built in
  24-31 ms (budget 40k, 80 ms).
- `tools/layer_sprawl_map.gd` prints the roost's line and maps it as `R`
  (`overview`). The next region's roost shows as `#`.

## Seed 11 from the side (`tools/layer_sprawl_map.gd -- --seeds=11`)

```
From the side along the exit side (south to the right, up is up; a character 11 m across and 19 m up):
|                                                                                            ####              |
|                                                                                       #   ########           |
|                                                                                      ################ #@     |
|                                              RRR                                      ############# ######## |
|                                              RRRR                                      '#####################|
|                                          RR RRRRRRRR                             '' ' '   #############  ####|
|                                         RRRRRRRRRRRR       ######  ##    '####''            ############     |
|                                        RRRRRRRRRRRRR       ####################               ##########     |
|                                      RRRRRRRRRRRRRRRR    ' ##############                          ###       |
|                                  55 RRRRRRRRRRRRRRRRR ''   ########### ##                                    |
|                             44  555555RRRRRRRRRRRRR                                                          |
|                      333466...44....5:::::::GRRRR                                                            |
|                     3333....664455 555     RRRR                                                              |
|         11       ~~~~33334444444                                                                             |
|0 00000011.2~~~~~~~ 3333333                                                                                   |
|000000111S~~~.22222   333                                                                                     |
```

The roost (`R`) stands off to the side of the last neighbourhood. Seen
from above it is 162 m clear of everything, south-east of the gate. Its
turf is over every isle's top and its peak over everything in the layer.
Its keel hangs down past the clusters' tops, beside them, not over them.
The next region (`#`, landmark `@`) and its own roost stand beyond.

## Knobs (layer_sprawl.gd)

| Knob | Default | Does |
|---|---|---|
| `ROOST_GAP` | 150 m | the clear sky all round, flat, footprint to anything |
| `ROOST_OVER` | 15 m | its turf over the layer's highest solid |
| `ROOST_RING` | 680 m | the furthest its middle stands from the base's middle |
| `ROOST_OFF_EXIT` | 55 deg | how far off the exit heading it stands, from the gate |
| `ROOST_OFF_NEXT` | 25 deg | how far off the spawn's line to the next region |
| `ROOST_VIEW` | 35 deg | off the spawn's facing it scores full |
| `ROOST_BEARINGS`, `ROOST_STEP` | 36, 15 m | the search |
| `ROOST_MARK_UNDER` | 12 m | where "in sight" aims (inside the tower) |

## Cost (headless, this Mac, shared with another agent)

| What | Time |
|---|---|
| Laying the roost in a plan (`_roost`) | 4-10 ms |
| Planning a sprawl layer | unchanged: no seed 1-24 redraws for it |
| The roost's art (`built_ms`, on a worker windowed) | 1.2 s |
| Its plants (flora, grass tufts) | 0.68 s |
| His dragon and air, laid once (main thread, first sprawl layer) | 1.35 s |
| The same, moved for each later layer | 0 ms |
| Standing a whole layer, flushed: seed 6 / seed 3 | 17.3 s / 23.8 s (4B-2: 17-21 s; the roost is about 2 s of it) |
| The next region's silhouette with its roost | 24-31 ms, 18.9k-24.2k triangles |
| tests/test_layer_sprawl.gd | 4 min 7 s |

Windowed (estimated, not run): the roost is built last on the isles'
worker, about 2-4 s after the last walkable isle. The next region's
silhouette waits for the whole layer, roost included
(next_region_loader.gd waits on `layer_up_ms`), so it now comes up those
few seconds later. The dragon's first lay is a 1.35 s main-thread hitch
when the first layer stands (the old aqueduct scene paid the same at
start).

## Checks

- **tests/test_layer_sprawl.gd passes** (driven seeds 6 and 3, planned
  seeds 15, 2, 1 and 12). New checks:
  - every sprawl plan has a roost. Its turf stands `ROOST_OVER` over the
    layer's highest solid and its peak 100 m+ over it. Its reach holds
    every cell of it. It is `ROOST_GAP` clear of every isle's bounds,
    edge path and ride tube. It stands `ROOST_OFF_EXIT` off the exit side
    from the gate. Its tower is in sight from the spawn (by occupancy);
  - built (seeds 6 and 3): every motif isle stands, the roost too. **A
    physics ray from the start's eye to the tower meets the roost first**
    (623 m and 479 m off). The dragon lies on the roost's ledge (18 m from
    its middle on both seeds, the second moved, not laid again);
  - the ray from the start to the next region's landmark still gets
    through, so the roost never blocks it;
  - the landmark check now builds the silhouette without the next roost
    (the landmark is the highest of the region's isles), and reports the
    roost's height;
  - through the gate, the next layer has a roost of its own;
  - every route, greed, climb and chain crossing is still made on foot,
    and the gulfs are ridden on both driven seeds: the layer is still
    crossable.
- **tests/test_run_layer.gd** (round 3's shape, no roost) **passes**,
  1 min 52 s.
- **tests/test_aqueduct_isle_sky.gd passes** (the aqueduct scene's roost,
  with roost_air.gd and dragon_roost.gd changed), and so does
  test_world_scale_guard. The import is clean. The full suite was not run.
- Not from this round: with `SPRAWL_SEEDS=11` the test's ray from the
  start to the next region's landmark hits the parked plane's room on
  the aqueduct isle (`ParkedPlaneRoom`). It is the 4B-2 spawn and
  landmark, unchanged here. The planner's sight check (occupancy only)
  doesn't know about the parked plane.

## Unverified (headless can't see it)

- **The whole look.** Whether a mountain 400-670 m off, 100-200 m up,
  reads as "the dragon's roost over there, apart" or as one more isle;
  whether it dominates; whether its front (it is only moved, never
  turned) faces you well enough on the seeds where it stands south or
  east of you.
- **The frame.** On the tallest layers (seed 1) the peak stands 30+
  degrees up from the spawn, which may be off the top of the walker's
  frame until he looks up. `ROOST_OVER` lower or `ROOST_RING` wider would
  ease it.
- **His dragon at 500 m:** he is 50-odd metres long, so he may read as a
  dark coil on the ledge or not at all. The wreath, the birds and the
  crashed plane are the aqueduct scene's, never seen at these distances.
- **The scene's haze at 400-670 m.** The roost is real geometry in the
  scene's own air. The next region's silhouette is hazed by its own
  shader, so the two may not match.
- **Clouds.** The drifting puffs thin over the roost (`keep_roost`), but
  the cloud field was laid once for the base's band, so puffs that drift
  in may still show at the roost's edge.
- **The far roost in the silhouette** may read as an odd lump at 1.2-1.5
  km.
- **Windowed timing** (above): estimated.

## For the next rounds

- **A route to the roost** (the heist). It stands 150 m+ clear and over
  everything, so a way up needs a ride or a long climb:
  - a serpent loop or a ferry stop at its foot (a pier on its turf strip:
    the motif's turf faces north-west, Roost `V`);
  - a cannon that only reaches from the highest cluster's top;
  - an updraft column the pocket sail can climb from the last cluster.

  Any of these has to keep clear of the exit side's view. The plan
  already knows the roost's middle, reach, turf height and front.
  `ROOST_GAP` is the knob to bring it in. A gulf-style edge (`kind:
  "roost"`) off the nearest neighbourhood's rim that faces it would reuse
  LayerPlan's ride lay and tube checks.
- **The taking.** The hoard (the chest at the ledge's middle, `RUINS`
  "tomb_chest" in motif_dragon_roost.gd) is where an orb would sit.
  Waking him on a theft is the wake's beats (scripts/dragon_wake.gd:
  stir, rise, fly, settle).
- **His wake over a layer.** `DragonWake` needs a circuit from the plan
  instead of `CIRCUIT`, for example round the neighbourhoods' middles
  and the gulfs, clear of the rides' tubes and over the base at
  `HOME_OVER`. It also needs its ledge from the layer's roost (it reads
  `Roost.AT`; `dragon_roost.gd` and `roost_air.gd` now take an `offset`
  and `move_to`, and the wake should too).
- **Turning the roost.** The roost's front is fixed (north-west). To face
  any spawn, the motif, its `ground`, its coil and the pose would all
  need a yaw. That is real work in motif_dragon_roost.gd and
  dragon_roost.gd.
- **The dragon's lay off the main thread.** The first lay (1.35 s:
  building the model, skinning on the CPU, settling) could move to a
  worker or be spread over frames.
