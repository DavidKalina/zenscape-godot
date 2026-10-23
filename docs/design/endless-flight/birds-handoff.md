# Birds round: handoff

## What it does

`scripts/endless/endless_birds.gd`, hooked into `studies/endless_flight.gd`
(built after the trees, stepped after them each frame, a line on F1's numbers).

- **Perched flocks.** Every 0.5 s, if fewer than 2 flocks are waiting and
  the plane is under 80 m over the ground, it samples trees 140 to 280 m
  ahead along the plane's way and 5 to 38 m off its line. It reads the
  trees from the forests' own stood cells (new `LandTrees.cell_trees(ck)`,
  additive; no physics), puts 9 to 17 birds on the top third of the crown,
  and then waits `PERCH_GAP` s before putting the next. A flock the plane
  has passed, or one far off its way, is dropped unflushed.
- **Flush.** The plane within `FLUSH_SPANS` (16) of its span (WorldScale.span,
  about 45 m), and closing, flushes the flock. The birds go in a ripple,
  nearest the plane first (0 to 0.35 s). Each one crouches for 0.1 s (squat,
  wings eased off the back), then bursts up and out from the tree with its
  wings flung up for the first stroke, a stretch on the body and 19 beats a
  second. The flock's anchor climbs toward the plane's height and heads the
  plane's way.
- **Ride along.** For 6 s (`--bird-ride=`), the anchor holds a slot 6 to 9 m
  out on the tree's side and 0 to 2.5 m over the plane. The slot slides from
  16 m ahead to level with the plane, and the birds top out at 1.08 times
  the plane's cruise. At cruise they start ahead and drift back to beside
  it; on a boost they fall more than 25 m behind and peel early.
- **Peel.** They turn 1 rad away over 3 s, at 0.78 times cruise, climbing
  or dropping a little and gliding for longer. They are dropped once more
  than 200 m from the eye, more than 50 m away and behind the camera, or
  after 20 s.
- **Far flocks.** Up to 2 flocks of 16 to 26 birds, drawn at 2 times the
  size, wheel 130 to 300 m ahead of the eye. Each wheels on a 35 to 75 m
  circle 28 to 70 m over the higher of two sampled spots (so along ridges
  more often), and its spread breathes. They are dropped past 650 m and put
  again ahead. They fly every other frame.
- **Flocking.** Each bird keeps station on the flock's anchor at its own
  drifting place in the flock's frame (cohesion), with alignment to the
  flock's mean velocity, separation from 3 neighbours, a hard push off the
  plane (1.5 spans) and the ground clamp. Facing lags velocity (follow-through)
  and they roll into turns. The wings flap and glide in bounds (0.3 to 0.65 s
  of flapping, 0.18 to 0.5 s of gliding at a small dihedral, longer when
  relaxed), and they beat when climbing or working hard. The downstroke is
  fast and the recovery slow, the hand lags the arm, and the body bobs on
  the stroke.
- **Body.** One MultiMesh of a small faceted dove-like bird (80 triangles:
  6-sided body rings, beak, tail fan, two-segment wings), 1.05 m span at the
  size knobs (0.38 times the plane's span). The bird is pale grey with a
  buff belly and dark wingtips, which reads over dark forest and against
  the sky. `shaders/endless_birds.gdshader` poses the wings from instance
  custom data (inner angle, outer bend, spread/tuck, warm tint). It casts
  no shadow, is visual only and never touches the plane.
  `songbird_body.gd` was not used: six nodes and a material per bird cost
  too much here. Its isle code is untouched.

## Model budget (docs/art/model-budget.md)

The bird is 80 triangles in one MultiMesh, posed in its vertex shader.
Vertex colours carry the colour, and flat facets carry the silhouette.
None of the tricks saves anything worth doing here:

- **Sculpt and bake:** no use; the bird is too small on screen.
- **Import LODs and visibility ranges:** they would save under 80
  triangles times about 100 birds, which is nothing.
- **Rigid parts on bones:** the wings are already bent in the shader with
  no skeleton.
- **Parallax:** no use.
- **Vertex-colour grime:** the vertex colours are already used for the
  belly and the dark hands.

## Flags

`--birds=0` (or `--no-birds`) off; `--birds=X` how many perched flocks wait
(1); `--bird-range=X` flush reach (1); `--bird-size=X` (1); `--bird-ride=S`
(6); `--ambient-birds=X` far flocks (1; 0 none).

## Cost

These figures are from an RTX 4070 Super at 1440p, uncapped, on a low pass
over forest. The numbers are 20 s averages from the scratch driver
`scratch/birds_cost.gd`.

| | birds on | `--birds=0` |
|---|---|---|
| birds alive | ~58 (peak ~105) | 0 |
| birds CPU (GDScript) | 0.29 ms | 0 |
| GPU | 11.63 ms | 11.64 ms |
| frame | 12.81 ms | 12.85 ms |
| draw calls | 764 | 746 (noise between runs; the birds are 1 MultiMesh) |

In headless runs with ~90 to 105 birds alive the step is 0.5 to 0.7 ms on
a loaded machine, and drawing is about 0.25 ms of it. F1 shows birds
flying and perched, flushes and the step's ms.

## Proof

- Smoke: `studies/endless_flight.tscn`, both default and `--birds=0`, pass
  400 frames with 0 errors.
- Scratch driver `scratch/birds_pass.gd` (uncommitted): it flies the plane
  low past the densest forest near the start through the real loop. Three
  flocks flush, ride, peel and are dropped. The closest bird came 4.3 m from
  the plane, there are no errors, and `--shots=N` / `--film` give stills.
- Sheets: `captures/shots/birds_pass_play_crops.png` (play view: the burst,
  the ride, the peel), `captures/shots/birds_flush_sheet.png` and
  `birds_flush_crops.png` (a side camera on the burst).

## Weak

- At the chase camera's distance the riding flock is small (roughly 25 to
  60 px at 1440p) and often flies among the crowns, not against the sky. A
  slot higher over the plane reads better but sits at the frame's top edge.
- The burst starts about 45 m ahead, so most of the "alongside" is the plane
  catching a flock that is slowing down. It reads at cruise; on a hard turn
  the slot swings with the plane, and the flock can cut across.
- Birds fly through neighbouring crowns while bursting (they have no tree
  avoidance), and perched birds sit on a guessed crown cone (0.19 times
  the tree's height), so on some trees they float off or sit inside.
- Far flocks are 2 to 3 px specks past about 250 m and pop in at 130 m and
  up. They pick ridges only crudely (the higher of two spots), not meadows
  or ridgelines.
- GDScript CPU of 0.3 to 0.7 ms at peak. If it's needed, the next step is
  fewer far birds, or moving the steering into a compute pass or the
  native kernels.
- No walker flushes, gust flushes or calls, and there's no sound.

## Next

Judge the size and ride slot by playing (`--bird-size=`, `--bird-ride=`,
`--bird-range=`). Try a slot over the plane's far wing at a slower bank.
Add a sound of wings on the flush. Flush on the walker too. Give the far
flocks a murmuration squeeze or seabirds over the coast.

No existing test touches these files (`grep endless_flight|land_trees tests/`
finds none); `test_world_scale_guard` passes.
