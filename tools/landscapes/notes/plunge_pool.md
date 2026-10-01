# Plunge pool (take 3)

**Intent:** a cliff across the plate, a notch at its lip, a pool at its foot,
and water above the lip dropping as a waterfall into the pool.

**Recipe:** `tools/landscapes/plunge_pool.gd`. Paddle size 3 swell to 4 m at
the back (0,-7). Chisel size 3 shelf, pressed on the swell's face at (0,-3.5)
and drawn out west, then pressed there again and drawn out east. Paddle size
1 swell pulled down at the foot (0,1.2) for the pool. Wire size 1 Shift
(shallow) gorge from (0,-4.8) to just short of the lip. Water held 3 s on the
shelf behind the notch.

**Stills:** /private/tmp/zs-landscapes/plunge_pool-take3/ (03-cliff, 04-fall,
05-overview, 06-low).

## Takes
1. *(headless)* Shelf drawn left to right from (-9,-2.5) on the flat. The
   shelf's level is the *press* height, so it cut the whole swell front
   down to 1.2 m. Full-depth Wire gorge from the upland crown: it cut 2.6 m
   down and **took the lip lower than the ground below the cliff** (lip
   -1.47 m against -0.21 m below). No cliff was left.
2. *(rendered)* Shelf pressed on the swell's face, drawn out both ways: a 1.5
   m step. Shallow Wire notch. But the pool's paddle hold did nothing (402 px
   pulled, no verb reported), and the slower drags were at risk of being
   read as holds. The pour on the upland crown ran off the swell's back. The
   water did come down through the notch and then crossed the plate to the
   near rim, where it **made an edge fall by itself**.
3. *(rendered)* Drags given a brisk start (my `brisk_drag`), and the pour on
   the shelf just behind the notch. **It worked.** A fall comes out of the
   notch, about 0.7 m down (notch 1.61 m, below lip 0.89 m), into a 1.2 m
   deep pool (11.2 m³ over 16.9 m²) with fish, frogs and frogspawn.

## What came out
- The "cliff" is a **jagged band of broken rock blocks**, not one wall. The
  shelf's downhill face flips side and zigzags along a curved hillside, and
  the size-3 strip leaves wedges. It reads as a rocky scarp, which is
  pleasant but not a cliff.
- The fall is squat: a 1 to 1.5 m drop is all a shelf's FACE_DROP (1 m) plus
  the slope give. It reads as a fat chute, not a plunge.
- The pool overflows and spreads into a shallow sheet (67 m² of water on the
  plate).

## How the tools felt
- **The Chisel shelf's level is the press point.** That's right for
  terraces but a surprise for a cliff: where you start the drag decides
  everything, and starting at the end of a line (as you would) is wrong on
  a hill.
- **The full-depth Wire gorge is too blunt for a notch.** 2.6 m deep, and
  "the bed never climbs" means a gorge started uphill trenches through the
  lip. Shift (1 m) is the notch. The Chisel tap notch (0.6 m) may be the
  better verb; I didn't try it.
- **Paddle swell-down vs Modeller pinch-down vs Chisel pit** all make a
  pool. Three tools, one result at this scale. Only the outline differs
  (round, peaked, faceted).
- A pour on a crown runs whichever way the land falls. You have to pour
  right above the lip.

## Gaps and bugs
- No verb for "a tall straight cliff". A Chisel mesa is tall but small and
  round. A shelf is long but only 1 m tall.
- A paddle swell-down hold sometimes does nothing in a rendered run (take
  2, no verb). It didn't happen headless, and I can't explain it yet.
- Game/harness: in windowed runs, drags at about 1.5 to 3 m/s were read as
  holds (pinches), because the harness moves a fixed step per *frame* and
  the window renders below 60 fps.

## Scores
Buildable 2/5 · Looks 3/5 · Matched intent 3/5
