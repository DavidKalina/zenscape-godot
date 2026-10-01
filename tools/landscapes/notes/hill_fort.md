# Hill fort (takes 1 and 2)

**Intent:** a round hill with its top sliced flat for a fort, a ring ditch
round its foot filled with water as a moat.

**Recipe:** `tools/landscapes/hill_fort.gd`. Paddle at size 2: hold-swell to
4.2 m at (0,0). Wire at size 2: hold on the crown and pull down until the
crown is 2.6 m (the slice). Wire drag round a closed 24-point ring. Take 1:
ring r 5.0, full depth. Take 2 (in the script now): ring r 6.3 with Shift
(shallow gorge). Water poured into the ring (2 pours take 1, 3 pours take 2),
25 s at 4x.

**Stills:** /private/tmp/zs-landscapes/hill_fort-take1/ and hill_fort-take2/
(01-sliced, 02-ringed, 03-moat, 04-moat-low).

## What came out
- **The slice works exactly.** Crown 4.21 -> 2.56 m after a 24 px pull, a
  dead-level disc ~3 m in radius (`2.56 2.56 2.56 2.48 1.78 ...`). It reads
  at once, but as a **bare brown dirt disc** (a stump top or a quarry),
  never as turf. Nothing marks the cut edge as a rampart.
- **The closed ring works.** One drag round a closed path cut a continuous
  ring; the ends joined with no gap.
  - Take 1 (full depth) hit the land's -1.5 m floor all the way round: a
    4 m-deep chasm 2 m wide, rock-walled both sides. The hill became a
    butte on a pedestal in a canyon. Water 0.55-0.66 m deep, even all the way
    round (40 m³ plate). Impressive, but not a fort.
  - Take 2 (Shift, further out) reads as a **fort**: the hill keeps its green
    flanks, the ditch is a rocky ring at its foot. The bed's built-in fall
    (BED_FALL) shows on a loop: ring floor `-0.65 -0.75 ... -1.25 -1.32`, a
    0.67 m **step at the seam** where the drag closed. Water level is one
    surface, so the moat is 0.15 m deep at one side and 0.80 m at the other.
- **The moat barely reads.** Water at the bottom of a 1-2 m rock trench, under
  the balanced preset's ground fog, is a grey haze. From the overview you see
  a dark ring, not water.
- **A pour on the far side is lost behind the hill.** Take 1's second pour,
  aimed at the far moat, landed on the fort top (the hill hid the moat from
  the camera) and became a pond up there.

## How the tools felt
- Wire slice (hold) is the most precise verb in the set: it does one thing,
  the plane follows the pointer, release and it is done.
- Wire gorge on a closed path is great as a gesture; the bed's downhill
  fall is right for rivers and wrong for a ring.
- Full-depth Wire is too deep for most landscape uses at this scale; Shift
  is the useful default for a ditch.

## Gaps
- A **level** gorge option (no BED_FALL) for moats, canals and rings.
- The slice should leave **ground**, not bare dirt, or regrow; a sliced top
  reads as a wound.
- No way to raise a **rampart** round the cut edge (a line-raising verb again).
- Water in deep narrow cuts needs to read as water under fog.

## Scores
Buildable 4/5 · Looks 3/5 · Matched intent 3/5 (take 2)
