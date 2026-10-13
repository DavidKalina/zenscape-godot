# The generated layer, round 3: neighbourhoods and gulfs (2026-10-12)

> Branch `worktree-agent-ac91fde3495352c01`, cut from `roguelike` at
> 4bec5bd8. Round 2 is layer-round2.md (the generated layer this builds
> on); the motif contract is motif-families.md.

The user, after round 2: the layers were "really close together", and the
Sky Snake and the blimp were what made it read as sky islands. "I like the
idea of having more motifs in the single scene, in clusters. Maybe you
have two or three. Then having them spread apart. And I'm also not opposed
to having multiple sky serpents on a kind of routine, and the blimp."

## Run it

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --seed=15
```

Seed 15 has three neighbourhoods: a ferry gulf (156 m, with a cannon) and
a serpent gulf (123 m, with a cannon). Seed 1 is a 175 m serpent gulf,
seed 2 a 113 m ferry gulf. Without `--seed=` a seed is drawn.

| Key | Does |
|---|---|
| N / Shift+N | the next / previous seed's layer |
| Backspace | this layer again (same seed) |
| everything else | the aqueduct isle's: walk, jump, sail, telescope, R back to the start |

Knobs (`--knob=key=value`, kept from layer to layer):

| Knob | Values | Default |
|---|---|---|
| `gulf` | the gulf's width rim to rim in metres, clamped 60-400 | each gulf rolled 110-220 |
| `hoods` | 2 or 3 neighbourhoods (1 works too: no gulf) | rolled 2 or 3 per draw |
| `ride` | `serpent` or `ferry`: every gulf's honest ride | the first gulf rolled, the next the other one |

As before, the gate (glowing posts and a beam on the last neighbourhood's
highest isle) or the void under every isle starts the next seed's layer.
A fall into a gulf is the void. A fall onto a lower isle is a fall, and
past 6 m a fall stun. The card at top left shows the seed, the runes, how
long the layer took to stand, each neighbourhood's isles with its gulf
between (`~ 156 m gulf: ferry, cannon ~`), and, near a pier, the ride's
schedule: "Serpent by this pier in 12 s", "Ferry here: it leaves in 9 s",
"Ferry here in 40 s (every 146 s)", or "The far isles are still rising: no
ride yet".

## What a layer is now

`LayerPlan.make(seed, knobs)` (scripts/roguelike/layer_plan.gd):

- **Neighbourhoods** (`plan.hoods`, isle indices). The first holds the
  aqueduct base and 1-2 motif isles. Each later one holds 2 motif isles,
  3 three times in ten. The greed branch hangs off any route isle and
  joins its neighbourhood. Inside a neighbourhood, edges are round 2's
  (stones, rope bridges, the Loose Voussoirs, the greed branch's hard
  stones and cannon, the Ram). The exit gate stands on the last
  neighbourhood's highest isle. One voussoirs trap per layer, as before.
  A step may now leave from any isle of its neighbourhood, so the one
  before becomes a side isle. A motif that won't stand anywhere is swapped
  for another draw (`SUBS`). Families (the colonnade, the ring) may come
  more than once a layer with their own seeds and knobs. The others come
  at most once, and a neighbourhood has at most one hero.
- **Gulfs** (`plan.gulfs`, edge kind `gulf`). Each joins a rim of one
  neighbourhood to a rim of the next, across `width` m of open sky (lip to
  lip, flat), rising 2-9 m. Every isle of another neighbourhood keeps 60 m
  off (`HOOD_APART`, solid cell to cell). The straight line between the
  rims (the walker's corridor and the sight line, `edge.sight`) is clear
  of every isle. Each gulf rim wants a 4.5 m run-up for its pier's steps.
- **The honest ride** (`edge.ride`), laid per gulf by the plan and checked
  against every isle's occupancy, then kept clear of later isles
  (`plan.tubes`):
  - **The serpent** (`edge.serpent`: points, marks, spots). It is a closed
    B-spline loop in rune_serpent.gd's ROUTE grammar. Past each pier it
    runs straight and level along the rim's edge: three control points in
    a line, its slither held to 0.1, three-quarters pace. It comes in and
    leaves at 45 degrees off open sky, with a lane out over the gulf on
    one side and back on the other, 52 m to the sides, 6 m higher
    mid-gulf. The loops are 280-490 m long, so a lap takes about 35-45 s
    (estimated from its pace; not timed lap by lap). The heave by each
    pier is taken out of the way there, so the pier's top stands 1.12 m
    (4 steps) over its rim on every seed.
  - **The ferry** (`edge.ferry`: route, piers). The sky folk's ship at
    1.8x scale (airship_ferry.gd) on its own Catmull-Rom loop. It rests 14
    s at each pier's end, square to the rim's edge, deck level with the
    pier, and comes in and leaves at 45 degrees. Its lap is about 150 s,
    about 60 s of that the crossing.
  - **Piers.** Both rides board from a pier: serpent_route.gd's ledge
    (`SerpentRoute.make_ledge`, now static), made longer. Its end is 7 m
    past the lip and its back 1.5 m over the turf, with a flight of the
    kit's steps up to it. Piers keep the rides 6 m+ off a coastline that
    bulges. Without them most loops met the base's ragged coast.
- **The fast, risky way:** a cannon behind the near rim of a gulf 170 m
  or narrower (`edge.cannon`). It is the same cannon at more speed: the
  least whose top notch carries the gulf, 12-14 of his runs, against the
  greed cannon's 6.6. It stands aside of the pier's line, 5 m by a
  serpent's pier and 19 m by a ferry's, clear of its envelope. Its kegs
  stand on its far side. Its shot lands 8-14 m inland, past the far pier.
  A miss is the void. Over 16 seeds, 6 of 18 gulfs got one.
- The plan is the same for the same seed and knobs. Over seeds 1-16 it
  took 0.4-8.3 s (mean 2.8 s; 0-16 redraws).

## What was built

- `scripts/roguelike/layer_plan.gd`: neighbourhoods, gulfs, the two
  rides' loops and their tube checks, gulf cannons, knobs
  (`knobs_from`, `KNOBS`), motif swaps, `warm()` (the caches, before a
  worker plans).
- `scripts/roguelike/layer_rides.gd` (new, a child of the stage):
  - each gulf's SerpentRoute (its serpent, rider and piers) or ferry (a
    SkyAirship ship, its AirshipFerry, two piers);
  - a gulf **opens** only once the isles at both its ends stand: its piers
    are built and its cannon set. Until then the serpent flies past out of
    reach and the ferry waits at the near pier;
  - `schedule(feet)` for the card.
- `scripts/kit_isle/serpent_route.gd`: the route, marks, start and spots
  can be set before `setup` (the authored loop by default). A spot can
  give its side. The serpent's parent (`holder`), the isle lookup,
  `auto_build` and `ledge_deep` are now settable. `make_ledge`,
  `flank_of` and `crest_of` are static. The authored route is unchanged
  (test_serpent_route passes).
- `scripts/kit_isle/airship_ferry.gd`: an instance `route` (ROUTE by
  default) with a side per stop, `envelope_parts`, and a start without a
  "home" stop. The authored ferry is unchanged (test_airship_ferry
  passes).
- `scripts/kit_isle/kit_audio_beasts.gd`: a freed serpent, rider or dragon
  is dropped without the typed-array errors. A layer's serpents now go
  with their layer.
- `studies/run_layer.gd`:
  - `--knob=`;
  - the card's neighbourhoods, gulfs and schedule;
  - windowed play lays each plan on a WorkerThreadPool task. The first
    plan is laid while the aqueduct isle builds. On N, Backspace, the gate
    or the void, the old layer stays up until the new plan is ready (on a
    void fall he waits at the old spawn). Headless or scripted it plans at
    once, as before. `--plan-away` forces the worker headless.

## Checks

- `tests/test_run_layer.gd` (slow, 109 s headless) on seeds 15, 1 and 2,
  which cover both rides and both kinds of gulf cannon. Everything round 2
  checked still runs. New:
  - the same plan twice;
  - 2-3 neighbourhoods of 2+ isles, the exit in the last, a gulf between
    each two, `GULF` wide, with an honest ride, other neighbourhoods 60 m
    off;
  - `--knob=gulf=240` pins the width and the plan repeats;
  - `--knob=hoods=3` gives three neighbourhoods and two gulfs;
  - **from the near rim a physics ray reaches the far rim** (the sight
    line);
  - the ride is open once the isles stand, with a pier at each rim;
  - **each gulf is crossed through the study's own `tick`**, the ride's
    own frame stepped round it:
    - walked from the turf up the pier's steps;
    - the serpent waited for and boarded with a running jump as its middle
      passes, kept to its spine across, jumped off with a twirl onto the
      far pier as it passes;
    - or the ferry waited for, walked aboard as it rests, carried 56-62 s,
      walked off onto the far pier;
    - then walked down the far pier's steps onto the far isle;
  - each gulf cannon at its found aim lands him on the far isle, 0.1-1.6 m
    off its mark.
  - The gate and the void each start the next layer.
  - `RL_SEEDS=`, `RL_TRACE=` as before. `RL_TRACE=1` also prints the pier
    walks.
- Also run, all passing: test_serpent_route, test_serpent_ride,
  test_serpent_hops, test_rune_serpent, test_airship_ferry,
  test_sky_airship, test_motif_families, test_kit_audio,
  test_world_scale_guard and test_world_scale_fit. The full suite was not
  run.

## How long a layer takes (headless, this Mac)

| What | Time |
|---|---|
| The scene to walking (the aqueduct isle's own build) | 10.5 s |
| Planning, seeds 1-16 | 0.4-8.3 s (mean 2.8 s) |
| Planning on a worker while the aqueduct isle builds (`--plan-away`, seed 3) | 11 s (it competes with the build) |
| Motif isles built and stood on the main thread (`flush`), 5 isles (seed 2) | 9.8 s |
| The same, 6-7 isles (seeds 1, 8, 15) | 17.8-19.1 s |

Windowed (not measured: no windows this round), the isles build on a
worker one at a time, nearest the camera first, at round 2's costs per
motif (gorge 1.9 s, stair 2.5 s, colonnade 3.2-3.4 s, ring 1.3 s, spires
1.2 s). So a 6-7 isle layer should take some 12-16 s. A far
neighbourhood's ride stays closed until its isles stand. The player first
walks through his own neighbourhood (one edge or more), then waits for
the ride (up to a serpent's lap or the ferry's rest), then crosses
(11-16 s on the serpent's back, about 60 s on the ferry). A gulf cannon
is the fastest way: its target isle must stand before the cannon is even
placed. The card says "still rising" until then. No silhouette was built.

## Unverified (headless can't see it)

- **The look of it all.** Whether the neighbourhoods read as sky islands
  across real gulfs. The piers (7 m jetties of kit stone on two courses,
  hanging past the rim). Whether the serpent's loop reads as a routine
  you can learn: lanes 52 m to the sides, 45-degree turns in and out by
  the piers. The ferry docking at a pier's end. The cannon standing 19 m
  aside on a ferry gulf.
- **The worker plan, windowed.** The plan task builds kit pieces
  (`KitMotif.piece_block`) off the main thread. Headless with
  `--plan-away`, the dummy renderer logged mesh errors from that (the
  flow itself worked). The windowed renderer should take meshes from
  threads (the motif isles already build on workers), but it has never
  been run. If it misbehaves, drop the worker: `_planning_away()`
  returning false brings back round 2's synchronous plan, a 1-8 s hitch
  on N.
- The windowed build order against a player rushing for a cannon.
- The camera on the serpent and the ferry over a 200 m gulf, and the
  serpents' sound (kit_audio_beasts finds them as they're added).
- Playing it by hand: the test's bot jumps at exact moments.

## Weak spots, honestly

- **The ferry wins more gulfs than the serpent** (11 of 18 over seeds
  1-16). The serpent's loop is tried first on half the gulfs, but its
  tube (girth plus slither) fails near ragged coasts more often, and
  then the ferry is laid. `--knob=ride=serpent` pins it, at a little more
  planning.
- **Three neighbourhoods come up less than half the time.** A three-draw
  fails more, and each redraw rolls the count again. `--knob=hoods=3`
  pins it.
- Planning got slower (mean 2.8 s, worst 8.3 s over 16 seeds), hence the
  worker. The time goes into the in-neighbourhood steps (240 tries each,
  clash checks against more isles) and the redraws.
- The sight line is checked from the gulf's near rim to its far rim, not
  from each neighbourhood's highest point.
- **The ferry and the cannon share the sky.** Resting at either pier or
  passing, the ferry can stand in a gulf cannon's arc: a real risk in
  play. The test fires the cannon while the ferry is mid-gulf.
- **Piers stand straight out from the rim, on the gulf's line.** Round 2's
  stones never use gulf rims, so they don't collide. The pier masonry is
  not part of any isle's occupancy.
- The layer's band is now 520 m round the base (round 2's: 240 m), and
  the clouds keep off all of it (run_layer_sky `places`). The gulfs are
  open sky, but the near sky may look bare.
- Not used: the Sky Ray as a ride, and a long glide with the pocket sail
  (every gulf rises 2-9 m, so a glide across can't make it).

## For the next round

- **The dragon in the gulfs.** The open sky is his airspace. The layer
  knows each gulf's line, width, rise and both rides' loops (`edge.serpent
  .points`, `edge.ferry.route`, `plan.tubes`). His circuit could run the
  gulf lanes, off the rides' tubes, with the riders as his marks (the
  stun's `knock(v, source)` with the dragon as source). Cover sockets
  exist only on the families.
- The serpent's and the ferry's laps are learnable but unseen. A pier
  could show its next pass (a bell, a lamp), not only the card.
- A silhouette for a far neighbourhood still building, if the windowed
  times turn out longer than estimated.
- The Sky Ray could be a third ride: its decks are piers, its path a gulf
  loop. trap_ray.gd's own `path` is local, so it would need a generated
  one.
- Re-bake (`tools/bake_layer_pieces.gd`) whenever a pool isle's art
  changes. The gulf rims want the bake's `run_up`.
