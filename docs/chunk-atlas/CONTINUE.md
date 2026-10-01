# Continue: a new chunk completes the land beside it

Status: prototype on `feature/atlas-continue`, 2026-09-30. Checked headless with
numbers and shaded height maps. Not yet judged on screen.

## The idea

Your chunk's edge is a mountain range. You grow the chunk beside it, and the
new chunk forms the other side of the range. A ridge that crossed the border
runs on along its heading. Then you sculpt the rest. Nothing is locked: the
continued land is ordinary live terrain. Undo removes it in one step and leaves
the old carry-in ramp. Any brush can reshape it or flatten the range away.

## Why carry-in was not enough

`ChunkAtlas.carry_in` (DESIGN.md, round 2) carries the border's *height
offset* inward over a band of up to 16.8 m. It knows nothing about slope or
heading. A range on the seam became a spur that faded into the plain.
Electron got its ranges across differently: it detected a ridge on the stored
strip and rooted its own ridge spine there (`genome.js:1035`). Godot stores the
whole neighbour document, not just strips, so it can read more than Electron
could: the neighbour's slope and the direction its ridges run near the seam.

## How it works (`scripts/chunk_atlas_continue.gd`)

The new chunk is a **sheared mirror** of each stored neighbour, read from a
0.5 m raster of the neighbour's heights.

- **Reading the band.** The reading covers the neighbour's first 8 m in from
  the seam, taken every metre along it. It measures:
  - the low ground: the 20th percentile of heights within 12 m;
  - the slope at the border, toward the new chunk;
  - a structure tensor of the gradient, which gives the ridge heading k and
    how much of the slope runs across the seam (`across`).
- **Ridges crossing the seam** (`across` near 0).
  - The new chunk at depth u samples the neighbour at depth u, along
    `t − 2k·u`, so an oblique ridge runs on straight instead of folding back
    into a chevron.
  - The height is capped near the height where the ridge met the border, so a
    hill deep inside the neighbour is not copied over.
- **Ranges along the seam** (`across` near 1).
  - **Still climbing at the border** (slope m > 0). A parabolic cap carries the
    climb to a crest c = 1.5·m metres past the border (at most 3 m), then
    mirrors the flank down the far side.
  - **Already falling at the border.** The slope eases down to the low ground.
  - Past the crest the mirror only descends (a running minimum), so no twin
    ridge appears.
- **Fade.** The continued relief fades over a reach of 14 to 34 m. The reach
  comes from the world's mountain country (value noise about seven chunks
  across, after Electron's `macro.js`) and the range's height. It varies along
  the seam so the range ends raggedly.
- **Variation.** Past the seam, world noise warps the copy by up to 1.4 m and
  scales it by ±28 %, so it does not read as a mirror image.
- **Several neighbours.** Rises take the maximum across sides and hollows the
  minimum (at most 2 m deep). The atlas pin still makes every seam exact.

### Where it runs

In `chunk_atlas_controller.move`, only when a chunk is *grown* (not when a
stored one is revisited):

1. form the plain;
2. carry in, then pin;
3. continue, as one undo stroke;
4. pin again.

`--no-continue` turns it off for A/B.

## Try it

```
godot --headless --path . --script tools/make_atlas_continue_demo.gd
./run-cozy-flow.command --atlas --atlas-file=user://cozy-worlds/atlas-continue-demo.json
```

The demo chunk has a ridged range climbing to its east border and a spur
leaving north-west through its north border. Press → to grow east (the far
flank) or ↑ to grow north (the range and spur run on). The demo uses its own
file, so your `atlas.json` is untouched. Add `--map=PATH.png` to the tool for a
shaded height map of the grown chunks, and `--carry-only` to compare with
the old ramp.

## Checks

`tests/test_chunk_atlas_continue.gd`, headless:

| Case | Result |
| --- | --- |
| Climbing flank | crest 8.6 m within 4 m of the seam, 0.02 m left at 10 m |
| Fallen crest | no twin ridge |
| Hill 10 m inside the neighbour | 0.09 m carried over |
| Oblique ridge | z 3.5 m at 6 m in (straight-line 3), z 5.5 m at 10 m, still 5.8 m tall |
| Plain neighbour | untouched |
| Undo | one step back to the carry-in state |
| Seams | shut |

## Open

- **Rendered look.** Rock and grass at the new slopes, and whether the crest
  reads as one range in motion.
- **Regenerate and New plain** still use carry-in only. They could run
  Continue on their plain too.
- **Trees.** The plain's wild tree can land on the new slope.
- **Run-through.** A range does not yet head for the far border on purpose,
  as Electron's `RANGE_THROUGH` does. That needs the world's ridge heading
  (macro `phi`).
- **Rivers and lakes** are not continued. That is the `w` strip work in
  DESIGN.md's tea lake section.
- **Sculpting across the seam** into a frozen neighbour is still not possible.
- **Steering the new chunk** (continue, fall to a valley, surprise) is not
  offered yet. It always continues.
