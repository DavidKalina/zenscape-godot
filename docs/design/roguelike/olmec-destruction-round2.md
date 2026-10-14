# Olmec destruction, round 2

The brief, in the user's words: "Terminator vibes, where he's just this
relentless force that cannot be stopped." Masonry doesn't stop him. He
climbs the land and breaks the masonry.

Branch `feature/olmec-destruction`, on top of round 1 (`af2ced65`). It isn't
merged or pushed.

## How to launch it

    ./run-olmec-colonnade.command

This runs the colonnade study with `--olmec`, as in round 1. His head now
heaves in the temple's cella on the podium, behind the rose gable (x 36).
He walks the whole way up the colonnade, the plaza and the grand stair, and
goes through the gable to reach it.

To get to the gable fast:

    ./run-olmec-colonnade.command --olmec-at=60,0

This starts him on the plaza, and he punches through about 6 s in.
`--head-at=58,0` puts his head back on the plaza, as in round 1. F1 shows
the new counts (portals, temple walls, gable, column bursts, pre-cut ms).

## What changed

- **The rose gable punch-through** (`colonnade_breaks.gd` `ahead` and
  `smash`; the body's new `smash` state):
  - **The approach.** The standing gable is left out of his rays, so he
    plans through its door. The grand stair wasn't the blocker: from the
    plaza he climbs it fine.
  - **The trigger.** He is walking (roam, home, chase, return or seek),
    square to the gable's face, with his front within 2.2 m of it.
  - **The beat.** He eases off (he doesn't brake) and raises his fists for
    0.42 s. Then the fists come down. At that moment the game pauses for 7
    frames at 0.06 speed, the camera gets a big shake, and there's dust, a
    `ruin_boom` and stones. 0.18 s later he is back in the state he was in
    and walks straight on through the breach. He doesn't stop to listen
    after it.
  - **How the gable falls.** It comes down in 11 pre-cut slabs, in order:
    1. The door's two halves are blown in off his fists.
    2. The walls over the door slump in (after 0.1 s).
    3. The rose hangs a beat, then comes apart in quarters and tips out over
       him, down the way he came (after 0.3 s).
    4. The rake slabs go over off the flanks, also toward the stair, and the
       apex follows.

    Each slab turns about its foot, not its middle.
  - **The ruin left behind.** Both flanks stand as stepped, ragged stubs
    with their buttresses, and the plinth stays across the breach. The
    north flank is higher. The rubble heap spills over the stair head.
- **The temple's turrets and cella walls break too.** They're pre-cut by
  bands (`masonry_cuts.gd` `piece`). Before this he wedged against the
  north cella wall right behind the breach, for 4 to 12 s. Now his bulk takes
  them down: a ragged stump stays, and the upper halves go over away from
  him.
- **Portals.** The portal piers are breakable piers now. Each arch ring is
  pre-cut at its voussoir joints (`masonry_cuts.gd` `ring`) into two
  springers and five chunks. When a portal pier goes, or his bulk meets
  the ring, the arch comes down in order:
  1. The chunks on that side.
  2. The crown.
  3. The far side's chunks, 0.3 to 0.55 s later.

  The far springer stays on the pier that still stands. In a full walk he
  breaks all three portals. Walked through dead centre, a portal's opening
  is wider than he is, so it stands. It only goes when he's off centre or
  a shockwave reaches it.
- **Weight:**
  - **Piers.** What stood over the snapped joint now goes over as one
    column, about its foot. It starts slowly (0.55 rad/s, plus some from
    his push) and gravity does the rest. Where it hits, it bursts into its
    drums and capital (`_burst`). Round 1 instead threw each drum outward
    at up to 4 m/s.
  - **Ground shake.** There's a ground quake (`breaks.quake`), which the
    study's camera adds to his own.
  - **Dust.** Heavy pieces raise a plume off the ground when they land, and
    slabs also throw stones and a boom. The dust is placed on the ground
    under each piece. A plume in open air rendered as a black blot.
  - **His stride through hits.**
    - Hit-stop on piers: 3 frames at 0.15 speed (was 4 at 0.12).
    - Speed cut on a hit: 10% (was 55%).
    - Stagger slowdown: 20% (was 70%).
  - **Listening.** In this study his searching stops to listen for 1.2 s
    every 12 s (was 2.6 s every 7 s).
- **Slabs are wadeable.** Settled gable, wall and arch slabs are left out of
  his rays, so they're never a heap he plans round or climbs. Drums, the
  capital and lintels are still ground to him. The walker climbs all of
  it.
- **The kit change** (`scripts/ruin_kit.gd`): `Build.keep_only`, a static
  Callable(centre) -> bool. It is set around one piece's build. The piece's
  blocks are laid as ever, so the random draws are the same, and at
  `finish` the blocks it doesn't keep are dropped in the same pass as
  `drop_floating`. That pass was refactored into `_drop_blocks`. With
  `keep_only` unset, every build is unchanged.

## Checks

- **Import:** headless, clean.
- **Smoke:** each passed 400 frames with 0 errors:
  - `colonnade_spine_isle.tscn` with `--olmec` and without
  - `headless_body_isle.tscn`
- **Through the real play loop** (`scratch/olmec_gable_stand.gd`,
  uncommitted; `python3 tools/drive.py scratch/olmec_gable_stand.gd --
  --scene-args --olmec --olmec-at=60,0`). All checks pass headless and
  rendered:
  - He punches through the gable at 6.5 s. He was still walking at 3 m/s
    as the windup began.
  - The slabs come to rest within 615 frames (peak 19 live).
  - He goes on through the breach to his head.
  - A gable slab lies static on the podium.
  - The walker, by real input, stands on gable rubble.
- **The full walk** (`scratch/olmec_watch.gd`): from the default start, he
  breaks about 6 piers, 6 lintels and 3 portals. He punches through the
  gable at about 70 s and is at his head 4 s later.
- **Films** (rendered, `scratch/olmec_gable_film.gd`, with the study's
  camera pinned): `scratch/film/gable_sheet.png` and
  `scratch/film/portal_sheet.png`, both gitignored.
- **Tests:** none run (prototyping). The default build paths are
  unchanged: the colonnade without `breakable`, the temple, and every
  RuinKit piece with `keep_only` unset. The temple's pieces gain a `kit`
  meta. No known test should break, but that is unverified.

## Cost

These are rendered numbers from the same runs as round 1's.

**The gable from the plaza** (`olmec_gable_stand.gd`):

| | Idle | Gable break, then the cella walls |
|---|---|---|
| Draw calls | 403 | up to 471 |
| Process ms | 16.4 | 21.5 average, 44 max |
| Physics ms | 0.64 | 3.9 average, 20.9 max (19 live slabs) |

**A pier break** (round 1's `olmec_stand.gd`, re-run):

| | Idle | During the break |
|---|---|---|
| Draw calls | 367 (round 1: 368) | up to 433 |
| Process ms | 17.0 | 22.3 average, 47.8 max (round 1: 18.4 / 25.7) |
| Physics ms | 1.4 | 0.9 average, 1.3 max |

- **The punch frame:** 23 to 33 ms (`build_ms`). That frame adds the stands
  and makes 11 bodies, and the 7-frame hit-stop covers it. A pier break is
  about 17 ms, as before.
- **Pre-cuts at load:** about 830 ms (`cut_ms`). That's the gable 12 times,
  the 5 temple pieces 5 times each and the 3 rings 8 times each, all built
  once when the study opens with `--olmec`. It's the biggest new cost.
  Building them lazily, or on a worker, is the fix if load time matters.
- **Draw calls.** Idle draws are up about 35 over round 1 in the gable
  view: the portal rings and the 6 portal piers now stand as their own
  meshes. A settled break merges back to one mesh, as before.
- **Peak live bodies:** 19, under the cap of 24. That's the gable's 11
  plus the cella walls he plows through right after.

## What's rough

- **The ruin is mostly rubble.** After the gable, the turret on that side
  and the cella walls, the temple front is a big heap with two flank
  stubs. It's dramatic, but there's little temple left. The heap also
  covers the grand stair's head: the walker climbs over it, and nothing
  checks the climb.
- **The rose goes in quarters.** Whole, it landed on its rim and stood
  like a wheel across the stair head, so it is cut into four.
- **Slabs pass through each other.** Gable slabs don't collide with each
  other, with him, or with the turrets. The rake slabs also pass through
  the cella walls. The pre-cut hulls overlap where they stood, and they
  jammed. Now and then two slabs settle interpenetrating.
- **Slabs can leave the isle.** A slab or chunk sometimes slides off the
  podium or the plaza edge and is freed when it falls past the isle.
- **The smash pose is the swat's.** It's the triumph clip's arms-up and
  fists-down, played over 0.6 s. It reads from a distance, but it isn't
  an authored punch. A Blender clip (plant, cock the arm, drive through)
  is the next step for the Nintendo bar.
- **Dust can still go dark.** A big plume close to shadowed stone can
  read as a dark smudge.
- **Rubble frames can still be dense.** A few dense-dust frames at about
  3 s can fill a close camera.
- **Searching still pauses.** Short `listen` pauses remain when he can't
  sense his head.
- **The colonnade's portals stand if he's centred.** Through the middle he
  clears the arch, so it doesn't break.
- Slab rubble is wadeable to him, so his feet sink up to about 1 m into a
  lying slab.

## Models (`docs/art/model-budget.md`)

The new geometry is the kit's own stones, regrouped:

- The gable's 11 slabs and its stands.
- 4 parts and stands for each turret and cella wall.
- 5 chunks and 2 springers for each portal ring.

Each falling part has no growth. Its hull is its stone's points, thinned
to about 1,500 and drawn in 14% in the wall's plane.

Here's how each trick applies:

- **Import LODs and visibility ranges:** apply.
  - The rose quarters are the densest part: about 15k triangles for the
    whole rose, for spokes, cusps and rings.
  - A coarser stand-in for the falling parts (each slab's stone with the
    chips dropped) would roughly halve their triangles while they fly. That
    would save about 20 to 25k triangles at the punch.
  - A visibility range on merged rubble past about 80 m would win back the
    extra draws, about 0.1 ms.
- **Silhouette geometry:** already used. The broken faces are the kit
  stones' own joints, so there's no new cut geometry.
- **Vertex-colour grime:** already used, and kept.
- **Sculpt high, bake low; parallax depth; rigid parts on bones:** don't
  apply. These are procedural stones, not skinned.

## What the harness lacked

- **A camera override for drivers.** I pinned the study's own camera with
  a node of high `process_priority` that sets its transform after the
  study does (`Pin` in `scratch/olmec_gable_film.gd`). That works where a
  separate Camera3D drew the cloud sea across the frame. A
  `--cam-at`/`--cam-look` in `drive.gd` built on this would save the next
  round the trouble.
