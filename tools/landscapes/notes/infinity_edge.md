# Infinity edge (take 2)

**Intent:** a pond near the plate's rim whose water spills through a notch
in the rim and falls off the plate edge into the void.

**Recipe:** `tools/landscapes/infinity_edge.gd`. Modeller size 3 palm
(Shift+drag) twice round a small ring at (2,9). Modeller size 2 groove
(slow drag) from the pond straight out across the near rim at (2,13.9).
Water held 3 s over the pond. 15 s of world at 4x.

**Stills:** /private/tmp/zs-landscapes/infinity_edge-take2/ (03-overview,
04-edge, 05-edge-low).

## Takes
1. Both palm passes were read as **Shift pinches** and not kept
   (`fine_pinch, false`), and the groove as a **pinch** that sank the pond
   to the -1.2 m floor. No notch, no fall: a deep round pit by the rim.
   Cause: a slow drag that stays under 6 px for 0.3 s is a hold. In a
   windowed run the harness's per-frame steps come slower, so the
   threshold was missed. A real player starting a slow groove could fall
   into the same trap.
2. Same build with a brisk start to each drag (`brisk_drag`). **It worked.**
   Palm pond -0.52 m (0.3 m pan), groove bed -1.17 m, a rim notch logged at
   (1.95, 14.0) with bed -0.49 m, the rim beside it at 0.45 m. The pond
   (4.3 m³, 1 m deep at the notch) drains through the groove. An **edge
   fall** pours from the notch down the block's earth side and breaks into
   droplets below (spill flux 0.083 m³/s).

## What came out
- The edge fall is the strongest image in this group: a clean V notch in
  the plate's side with a white ribbon dropping into the void. It reads at
  once from the overview.
- It is a **stream to the edge, not an infinity pool**. The groove's bed is
  0.4 m under the pond's floor, so the pond drains into the channel and the
  water surface never meets the rim. The palm's 0.3 m pan is shallow, and
  a second pass deepens it only to about 0.6 m.
- The fall is thin, and it will die once the poured water runs out (a fixed
  ball, no spring). In motion it would be a trickle after a minute.

## How the tools felt
- The **Modeller groove is the only tool that can breach the rim**.
  Everything else fades to nothing over the last 2.2 m (`fade`, EDGE 11.4
  to 13.6). That includes the Wire, whose gorge would be the natural
  "spillway" verb, and the Chisel notch. A player would expect the Wire to
  cut through the rim.
- The palm vs the paddle pat vs the paddle swell-down vs the pinch-down:
  four ways to make a pond. The palm is the only one that makes a *level*
  pan, and it's tiny.
- Slow drags turning into holds is a real feel risk, not just a harness
  artefact. A deliberate slow groove has to leave the press point quickly.

## Gaps
- A **weir**: a notch whose bed sits at the pond's surface, not below its
  floor, so the pond stays full and brims over the edge (a true infinity
  edge). The Chisel tap notch at the rim, set level with the pond, would be
  it, if it weren't faded at the edge.
- A lasting source near the rim. A ball runs dry, so the fall needs a
  spring.

## Scores
Buildable 3/5 · Looks 5/5 · Matched intent 3/5
