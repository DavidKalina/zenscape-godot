# Mesa badlands (takes 1 and 2)

**Intent:** a dry badlands of flat-topped mesas at several sizes and heights,
their tops and lips knocked about by the Hammer, scree spilling down.

**Recipe:** `tools/landscapes/mesa_badlands.gd`. Chisel hold-then-drag up
(hold_to) for five mesas: size 3 to 4.5 m, size 2 to 3 m, size 1 to 3.5 m,
size 2 Shift to 2 m, size 1 Shift to 1.5 m. Hammer at size 2: a tap in the
middle of A's top, two taps on A's lip, a row of four lip taps (take 2), a
drag of blows across B, a drag along B's lip (take 2), two Shift taps on C's
lip, a held blow on D. Then 20 s at 4x for life.

**Stills:** /private/tmp/zs-landscapes/mesa_badlands-take1/ and
mesa_badlands-take2/ (02-mesas-low, 03-hammered, 04-hammered-A,
05-hammered-B, 07-life-low).

## What came out
- **Mesas are the best thing in this group.** Crisp polygonal buttes, flat
  tops (`4.37 4.63 4.63 4.63 4.63 4.63 4.63 4.63 0.96`), sheer granite walls,
  heights within 0.1 m of the target. Sizes read clearly different. Shift
  gives the same footprint at half the climb rate. That makes it a finer
  control, not a smaller mesa, which a player may not expect.
- **Hammer: middle of a mesa = nothing visible.** The top is ground, not
  rock, so the blow is a "knock" (4.63 -> 4.59). Two lip taps: one knock,
  one crack.
- **A row of four lip blows does real work:** lip 4.12 -> 3.34, foot 0.30 ->
  0.63, profile toward the camera went `4.63 4.51 0.18` -> `4.59 4.00 3.29
  1.03 0.68`. The cliff became a cliff-plus-talus slope, with paler scree at
  the foot. In 04-hammered-A it reads as a notched lip and a pale apron.
  Subtle from the overview.
- **Drag of blows across B** ("strikes"): B broke into a lumpy, broken ruin
  (`2.30 2.74 3.08 2.53 1.98 0.54`). This is the one hammer result that reads
  at a glance (05-hammered-B, 03-hammered): a crumbled butte.
- **No dry look at all.** Grass on every mesa top, ~110-190 plants after 20 s
  at 4x (birch, spruce, broadleaf, shrubs), and in take 1 a rainstorm rolled
  in. Badlands are not reachable: nothing makes ground dry or keeps life off.

## How the tools felt
- **Chisel mesa:** excellent. Immediate and legible.
- **The Hammer is distinct** in result (it is the only verb that makes talus,
  breaks an edge, or makes ruins), but it is **invisible on the tops**, where
  a player will hit first, and a single blow is too small to see from the
  default camera. You need 3-4 blows in a row before it reads.
- **Dead presses (bug or design?).**
  1. Take 1, mesa C at (-4, 4.5), size 1: the hold did nothing. 400 px of
     pull, no verb reported. Take 2 at (-3, 5.5) worked. The island_lake
     take 3 diagnosis shows why: a tree or shrub under the press swallows a
     shaping press with no feedback.
  2. Hammer drags right after another hammer gesture were lost: take 1's
     drag across B came straight after two taps and reported a single
     "knock", changing nothing. Take 2's drag along B's lip came right after
     the B drag and reported nothing. After a 1 s pause the same drag worked
     ("strikes"). It looks like a press during the hammer's recoil animation
     (RECOIL_SECONDS) is eaten. The harness's settle() does not wait for
     `tool.busy()`, but a player strikes quickly too.

## Gaps
- **Dry/bare ground** (badlands, desert, salt flat): no material or verb.
- The Hammer needs to **crack flat rock tops** too (or make the chisel top
  rock), else mesas are hammer-proof except at the edge.
- Scree is a tint and a slope, with no loose boulders. The header says that
  is deliberate, but the result is hard to see.

## Scores
Buildable 4/5 · Looks 4/5 (mesas) · Matched intent 2/5 (mesas yes, badlands no)
