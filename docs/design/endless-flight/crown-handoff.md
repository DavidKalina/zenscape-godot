# The crown: handoff

The loop `crown` (spec: `spec-crown.md`) ended here on 2026-10-30 at the user's word,
with step 7's far views not done. Everything is on branch
`claude/mountain-peak-visual-polish-e79633`, 104 commits past main, not pushed and not
merged. The trail: `git log --grep='^ITER(crown)'`.

## The user's verdict, having played it

"Great start", and more time in the oven. In their words and in order of weight:

- **Kept:** "The swirling clouds on the three spires is just incredible." Much of it looks
  really good. Keep the spirals as they are.
- **The silhouette:** they may want to change it a little. Ask what they picture first.
- **The spires don't sit in the mountain:** they feel slightly artificial, not integrated
  into the mountain's design.
- **Colour mismatch:** the dark basalt of the spires doesn't sit well with the lighter
  rock under them.
- **Pop-in is a real problem:** the rock's eroded look arrives late.

## What's built

Fly it with `.\run-endless-flight.cmd`, seed 1. The world is one fixed seed: prove land
work on seed 1 only.

- Three leaning towers with a spiral of cloud each, round a lake at 861 m, on a plateau at
  880 m with a 236 x 44 m landing strip. The massif stands 1000 m nearer the start.
- A prow splits the mouth: the ice gorge on the right, the rock gorge with the stair and
  lift on the left, joined at a saddle. A flat apron lands you straight on out of either.
  Boost off at the saddle, Brake, pull up over the ramp, F for flaps, settle. Heavy needs
  no Boost in the rock gorge.
- Ice: a tongue with a snout, moraine, cracks with blue in them, seracs in the bowls and
  on a spill at the gorge's mouth. Snow with its own surface, furrow and powder. Rock
  relief on the massif. Flags on the climb, spindrift off the tips. The sun turned so it
  rakes the way in.

Debug flags: `--peak=0 --towers=0 --spirals=0 --stair=0 --lift=0 --peak-ice=0 --peak-snow=0
--peak-tarn=0 --peak-rock=0 --peak-flags=0 --spindrift=0 --crest-cut=0`,
`--peak-sun=DEG|off`, `--collar=1`, `--spires=1`.

## Proved, on the final ground, seed 1

- `crown_matrix --seeds 1,2` (the bot's wobble): 24/24 through, 0 crashes, 0 scrapes. Wall
  room 20.6 m, floor 13.1 m, seracs 9.4 m. Landings out of the gorges 6/6. Climb to 880 m:
  43/48/52 s, tops 1339/1169/1097 m. Non-finite heights over the zone: 0 of 68,780. Strip
  880.00 m; the apron falls to 874.35 m at its far corner. Collider on four wall spots: worst
  vertex 6 mm off the field.
- Smoke passes on both worlds. The test suite has not been run. `test_sky_peak_look.gd` and
  `test_sky_sea_peaks.gd` may rest on the old light; not read.

## Cost, measured on a quiet PC

| Against `--peak=0` | Median added | p95 added |
|---|---|---|
| Meadow | about 1.3 ms | about 1.5 ms |
| Gorge | about 2.5 ms | about 6.5 ms |

The added time is CPU; render time is lower with the Peak. Load is 29.5 s against 21.7 s
without the Peak (tree priming was capped, from 40 s). Snow adds about 0.45 ms. Flags and
spindrift didn't show over the noise, though that pass didn't keep them on screen.

**A Peak chunk takes 133-160 ms to build (100-121 with `--peak-rock=0`), GDScript per vertex
in `apply_chunk` and `_h_rock`.** It runs on workers, so it shows as land arriving late and
not as dropped frames. Hitches of 34-92 ms in the first 3 s of a harness launch, 7 or 8 a
flight against 2 without the Peak, are untraced. An older 336 ms hitch was not reproduced.

## Next rounds, in order

1. **Ask the user what they picture** for the silhouette and how the towers should belong to
   the mountain, before building. They've said what's wrong, not yet what's right.
2. **Integrate the towers:** buttresses or rock running up from the massif into each tower,
   and their rock shared with what's under them, so colour and shape answer the same thing.
   Rocks can't lean on a heightfield, which is why the towers are separate meshes; that is the
   likely root of the mismatch. Keep the spirals.
3. **The chunk pass in C++, or baked to a file:** required, not polish. Do it once the shape is
   final, since a shape change would rework it. This is the first thing to look at for the
   pop-in. From reading only: `PeakRock` leaves out scales by a chunk's step, so each level
   likely loses detail. Nothing traced yet.
4. **Then the rest of step 7:** the crown from 2, 4, 8 and 14 km, every side, the back, the
   sea and height, dusk; far towers against near under the new sun; the pale veil at 8-14 km;
   the collar off in those views. None of this has been looked at since the light and rock.

## Known weak, not chased

- Seracs read as white crystals on the ice. An unfinished fix, never looked at, is in the
  git-ignored `scratch/serac_look_wip.patch`, at 107,415 triangles against 64,034. The serac
  LOD's level 1 equals level 0, so that step does nothing yet.
- Walls square to the sun are the smoothest rock. Long thin snow ribbons remain, one about
  200 m on a rock wall. The furrow reads as a broken trough. Ridge spindrift is faint.
- The toothed edge along snow and rock in `ice_reveal` is the snow/rock edge, not a shadow.
- The sun's turn moved its bearing everywhere in the land, and the meadow's left hill is
  darker. `--peak-sun=off` shows the old sun. Coast, river, dusk and night under it are unseen.
- Motion has been judged only by the user's own flight.
- The serac flare's fix rests on stills, and the flare moved between frames. Reopen if a
  white flash shows.
- `zs_noise` jumps at cell borders across the whole land; the Peak moved to `peak_noise`.
  Fixing `zs_noise` reshuffles all the land's paint, so that is the user's call.

## Also on this branch

- `PilotBook.best` refuses a non-finite value and reads past a null record. A NaN height
  wrote `"highest": null` into the user's real save; the old height record is lost.
- Harness runs (`godot.run`) stay out of the player's logbook through `ZENSCAPE_NO_BOOK`.
- `tools/shot.py` shares its one-window lock across worktrees.
