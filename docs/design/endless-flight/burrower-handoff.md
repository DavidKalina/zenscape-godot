# Burrower study: handoff

Loop `burrower` (spec: `spec-burrower.md`), 11 iterations, branch
`claude/timed-challenges-redesign-fa3049`. A prototype: smoke checks and
throwaway drivers in `scratch/`, no committed tests. Endless flight is
untouched.

## Play it

`.\run-burrower-study.cmd` (Mac: `run-burrower-study.command`). The first
launch grows the grass (~20 s), later ones load it from a cache.

- Skim low (under one span, at speed) over the meadow or pond for ~1 s:
  it wakes ahead and to one side and leads. Climb off, leave the meadow,
  or run 24 s and it dives away; 6 s rest before it wakes again.
- **Space** (pad south): barrel roll toward the lean (Q/E), else the
  bank. **F**: boost (moved off Space in the study only).
- **B**: call it up at once (ignores climbs). **C**: watch camera, a slow
  orbit while it roams. **1 / 2 / 3**: the next push-up is an orb, a
  bell or a gong. **R**: respawn.
- Launch flags `--burrow`, `--watch`.

## What's built

- **The study land** (`scripts/burrower/burrower_land.gd`): its own
  640 m heightfield, a ~370 m meadow in a bowl of hills, a pond, a knoll,
  boulders, a ruin stub, 16 greybox trees; the game's carpet grass, plane,
  chase camera and input. Bump `GRASS_VERSION` when the land's shape
  changes, or the cached grass loads over the new land.
- **The trail** (`scripts/burrower/burrower.gd`,
  `shaders/burrower_ridge.gdshader`, `burrower_dust.gdshader`): a ~2.2 m
  bobbing head of bare earth that spouts arcs of earth over the grass, a
  short broken tail that settles to a fading scar, grass parted and
  pressed in stretches, clods and pebbles, dust. It surges and slows and
  steers round rocks, the ruin and the knoll, running beside trees.
- **Trees shudder** (`scripts/burrower/tree_shudder.gd`): a sway that
  rings out, the crown lagging, a burst of leaves.
- **The pond wake** (`shaders/burrower_pond.gdshader`): a mound with a
  white lip, a V of rings, a short froth track; splash in and out.
- **Leading**: it holds 22-46 m ahead, turns hard with the plane, and when
  lost after a long bank it sinks and resurfaces ahead with an earth burst
  (a splash on the pond).
- **Push-ups** (`scripts/burrower/push_ups.gd`,
  `shaders/burrower_halo.gdshader`): every 1.5-2.8 s, at least a beat
  ahead. Each swells, cracks, pushes up with overshoot, hangs, and sinks
  back after 4.5 s if missed.
  - Orb (common): hangs at 3.6 m, so taking one means easing up; bursts
    into motes with a chime; hits within 7 s climb a pentatonic tune.
  - Bell (~20%): bronze with verdigris, rings and swings when clipped,
    tolls as it settles.
  - Gong (~10%, not within 20 s of another): flown into level, the plane
    glances off; rolled through, a deep strike, sparks, the disc swings.
  - Notes are generated placeholder tones.

## After the first play (iterations 12-15)

- **Feel pass** (ff98b486): push-ups come up on the plane's own line a
  beat ahead (offset 0-2 m; none while turning harder than 0.8 rad/s), the
  orb is bigger (1.9 m) with a ~5.5 m hit reach, hits are swept along the
  plane's path, and the meadow is wider (radius 255 m). A natural-line bot
  went from ~11% to 60-80% hits.
- **Gritty dirt** (90b7052e, f8fee513): faceted crumbly clods, a lumpy
  soil dome, grain, crumbs and root bits; clods lighter and larger so the
  head reads from the chase camera.
- **Grass cache** (f8fee513): a headless run grows the study's grass dark;
  headless runs now keep their own cache file. First window launch after
  a `GRASS_VERSION` bump takes ~40 s.
- **Sounds** (369bb1af): Freesound CC0 bell and gong (two takes each in
  `assets/audio/burrower/`, credited in ATTRIBUTION.md; keys **4** and
  **5** switch takes, `--bell=2` / `--gong=2`), pitched to the run's
  notes (`BELL_PITCH`, `GONG_PITCH` in push_ups.gd are guesses to tune by
  ear). Orbs play the archived red-plummet pickup blip, climbing the run.
  Untested by ear: headless audio is a dummy driver.

## Stood in

Greybox trees, rocks, ruin and frame; the trail is the whole creature (no
body). Sound files are Freesound previews; fetch the originals (a free
account) before ship.

## Open

- In a long held bank the head leaves the frame ~1 s before it sinks, so
  the sink itself is never on screen (the resurface is).
- The pressed tail just ahead of the plane can still read as a band on
  long straight runs; shorter and more broken than before.
- Up close the clods read a bit chunky.
- The user finds the wake trigger strict (you must skim under one span)
  but likes that it feels intentional: kept for now, revisit in endless
  flight.
- Pick the winning bell and gong takes and drop the others and keys 4/5.
- `scratch/burrower_feel.gd`'s "most hit" check fails on run-to-run spread
  (~57% in its last runs); the measured gain over before is clear.
- Queued by the user: the burrower climbing landforms (along canyon walls,
  bursting out of a canyon side or a mountaintop). The study needs a steep
  slope or peak for it.
- Into endless flight (its own round): the gate (camera roughly forward
  by free-look offset, sustained skim, open space ahead), beat routes off
  (`--beats=0` today), the one-press roll, push-up hits feeding the
  near-miss chain, the burrower on real land and water.

## Drivers (scratch/, uncommitted)

`burrower_trail.gd`, `burrower_trees.gd`, `burrower_pond_roam.gd`,
`burrower_rouse.gd`, `burrower_orbs.gd`, `burrower_bell_gong.gd`,
`burrower_leadcheck.gd`, and the `*_film.gd` stills drivers
(`python tools/drive.py scratch/<name>.gd --rendered -- --tag=x`).
