# Endless flight: ponds and leaping fish (handoff)

Prototype round, no committed tests.

## What

- **Ponds** (`scripts/endless/land_ponds.gd`). Still water in hollows on open,
  near-level ground: 11 to 25 m radius before lobes, an irregular outline
  (lobes 2, 3 and 5), 1.5 to 2.4 m deep in the middle. The bed shelves in from
  the edge, so the outer few metres are a wading ring. The bank is cut down to
  the water at 0.14 rise over run, and a low lip fills dips by the edge. One
  pond at most per 400 m square, set from the seed. A square rolls (0.75 x
  `--ponds`) and then tries 6 spots. A spot needs: 4 m or more over the sea,
  mountain under 0.25, a river 45 m past its widest, the ground round it level
  within 0.06, and not a valley floor narrower than 55 m half-width. If a
  landing strip runs through the spot, a parallel strip must lie 30 m clear of
  the edge. That gives about 45 to 60 ponds over 8x8 km, roughly one per km² of
  land.
- **A layer, not native.** `LandField` (`land_field.gd`) cuts the pond in after
  either field (native or GDScript) in `sample`, `shape`, `height`,
  `river_y`, `river_drawn`, `grid` and `build_chunk`. `build_chunk` gets a
  post-pass that fixes heights, normals, colours, CUSTOM0/1 and the skirt.
  The native kernels are untouched, and both fields give the same ponds
  (checked). The pond cache is static and keyed by square, behind a mutex.
- **Downstream, a pond reads as a still river.** `last_river` is the distance
  outside the edge, `_r` the distance from the centre, `_w` the radius that
  way, `_y` the level, and the flow is 0. So with no changes elsewhere:
  - the ground shader paints the river's water, bank and edge line;
  - grass, flowers, trees and arches keep off the water and its bank (trees
    gather near the bank, as along rivers);
  - the plane skims the water (`water_at`) and the hand landing treats it as
    an edge (`floor_at` NAN);
  - the walker reads its depth through `water_at`.
- **Ground shader.** On still water (flow under about 0.3 m/s) the river
  streaks turn off, and lily pads grow in clusters through the shallow ring:
  notched, a few with a flower, a mean green far off, kept out of the mirror
  and glint. Knobs: `river_pads` (amount, cell m, radius share) and
  `river_pad_colour`. Rivers' still pools get pads too.
- **Fish** (`scripts/endless/endless_fish.gd`, `shaders/endless_fish.gdshader`,
  `shaders/endless_splash.gdshader`). A pond is watched when:
  - the plane is within 240 m of its edge, under 90 m over it, and flying
    toward it: first leap in 0.15 to 0.6 s, then one every 0.9 to 2.2 s;
  - he stands within 45 m on foot: one every 1.8 to 4.5 s;
  - it is merely in sight, within 700 m: one every 3 to 7 s.

  At most 4 fish are in the air at once.

  A leap:
  - a 0.42 s boil ring;
  - a ballistic arc under real gravity, peaking 0.65 to 1.5 m (about 1 s in
    the air), side-on to the viewer 70% of the time;
  - the nose follows the velocity. The body is stretched and its tail beats
    hard as it breaks out, it arches over the top (sideways and over the back),
    a last flick going in, squashed a touch at entry; 35% flop onto their side;
  - drops on the way out. Going back in: a crown of drops, spray puffs, a foam
    burst and 3 rings spreading out. A plop (`fish-plop-1/2`, 3D, heard within
    140 m).

  Kinds and drawn lengths: carp (0.62 to 0.9 m), rudd, tench and perch, from
  `life_models.gd`.
- **Study** (`studies/endless_flight.gd`, small edits): `fish` is built in
  `_ready` and stepped in `tick` and `_foot_tick`; `fish.note()` is on the
  `--numbers` HUD.

## Flags

`--ponds=0` none (the land as before), `--ponds=X` density (scales the roll,
capped at 0.95 of squares), `--fish=0` no fish. `--old-land` has no ponds.

## Cost (Windows, native field)

- **Fish:** 0.04 ms a frame on average, 0.2 to 0.3 ms at worst (`--numbers`
  shows it), measured in a 1300-frame flight over a pond.
- **Level-0 chunk by a pond:** 3.5 rising to 6 to 6.5 ms (on a worker).
  Level 2 and 4 chunks show no clear change.
- **`height()` near a pond:** 1.1 rising to 2.4 µs.
- **Grass `grid` over a pond (131², 1 m):** 11 rising to 24 ms (worker).
- Away from ponds, each call only pays a cached square lookup.
- The first look at a square samples the field about 100 to 300 times, once
  per run.
- GPU: the pads add one cell lookup per still-water pixel. Not measured.

## Meadow check (`scratch/ponds/flats.gd`)

The terrain round's definitions, ponds off / on. The square is 8 km at 16 m.
A flat point has slope 0.06 or less across 64 m. A strip is 192 m of flat
points in a row. Distances are measured from 256 m land blocks.

| seed | ponds | flat % | strip % | blocks >600 m | >400 m | worst block |
|---|---|---|---|---|---|---|
| 1 | 56 | 25.6 / 25.3 | 20.4 / 19.9 | 19 / 19 | 65 / 66 | 1472 / 1472 |
| 3 | 46 | 21.5 / 21.3 | 16.6 / 16.3 | 13 / 13 | 53 / 53 | 1243 / 1243 |
| 7 | 48 | 25.6 / 25.3 | 19.9 / 19.4 | 19 / 19 | 52 / 52 | 1103 / 1103 |
| 42 | 56 | 29.7 / 29.4 | 23.7 / 23.2 | 8 / 8 | 40 / 40 | 1616 / 1616 |

- Seed 1 has one block that went from 393 to 430 m. Nothing else moved.
- Without the strip rule, one pond on seed 1 took a lone strip, and four
  blocks went past 600 m.

## Proof

These are throwaway drivers in `scratch/ponds/`, run through the real loop.
- **`fly.gd`.** Seed 1, `--at=1832,700 --heading=0 --alt=14`, a pass 16 m over
  a pond: 25 leaps, a fish 1.55 m clear of the water, 79 spray at most.
- **`foot.gd`** (`--on-foot`, seeds 1 and 3). Walked to the edge by input.
  Fish leapt while he stood there (3 to 5 in 6 s). Then he walked on toward
  the middle: he waded 440 frames and stopped at 0.45 m deep, 11 to 13 m from
  the centre. 0.04 m under the field at most, no rescue, no swim.
- **`probe.gd`** (counts, native against GDScript) and **`bench.gd`** (cost).
- **Smoke:** passes with no flag and with each of `--on-foot`, `--ponds=0`,
  `--fish=0` and `--land-native=0`, with 0 errors.

Stills (git-ignored), in `captures/shots/ponds/`:
- `ponds_moods_sheet.png`: from the air, low and from beside the pond, in the
  golden meadow (top) and rose dusk (bottom) moods;
- `leap_close_sheet.png` and `leap_close_crops.png`: one leap, side-on;
- `leap_swoop_sheet.png`, `leap_swoop_arc0.png` and `leap_swoop_arc1.png`: a
  low pass, a fish mid-arc.

They come from `views.gd` and `leap_film.gd`, with `sheet.py`.

## Weak spots

- From the plane's chase camera at cruise height, a fish is a few pixels. The
  rings and splash carry it. The leap reads best under about 15 m.
- The spray is lit quads. Up close the crown reads as soft white balls rather
  than sheets of water. There is no splash on the water's surface itself (the
  pond is painted ground).
- The rings are drawn over the water, not in it: they don't bend the mirror.
- The pads sit in a jittered grid. Near the eye a row can still show.
- From the walker camera, the bank's tall grass hides much of the pond (as
  with the meadow grass already).
- The plop has not been listened to. The audio is untested on the Mac.
- The outline is radial: a deep lobe pinches it, but it can never wrap round.
  Near the centre the shader's interpolated radius can wobble on coarse chunks
  (as rivers do).
- The land hash (`tools/land_hash.py`) changes with ponds on. Use
  `--ponds=0` to compare with older hashes.

## Next

Reeds and rocks ringing some ponds (kept as tufts with no colliders?), fish
seen under the surface from the bank, an A/B of fish size against the plane
camera, and swimming in a pond.

## Tests

None run (a prototype round). No test references the endless land, so none is
known to break. `tests/test_world_scale_guard.gd` should be unaffected (no
sizes copied).
