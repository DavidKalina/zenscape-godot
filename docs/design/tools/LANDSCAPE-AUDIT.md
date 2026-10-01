# Landscape audit: what players will try to build

On 2026-09-30 we asked how much variety the current kit gives, and whether the
tools are powerful and differentiated enough. To find out, we built 13
landscapes a player would plausibly try. Each was scripted through the real
tools: clicks on the tool roll and materials bar, and drags, holds, taps,
Shift and the size pips sent as mouse input. Each was rendered, then judged
from its stills and measurements.

- Harness: `tools/landscapes/harness.gd`. Runner: `tools/landscapes/run.sh <name>`.
- One build script per landscape: `tools/landscapes/<name>.gd`.
- Notes per landscape: `tools/landscapes/notes/<name>.md`, holding the
  recipe, measurements, what fought the builder, and scores.
- Stills: `/private/tmp/zs-landscapes/<name>/` (not in Git).

Scripted builds judge results, not feel: a script always knows where to
press. The hand-built shortlist at the end covers feel.

## Scores

Each is scored 1-5 on three questions: could it be built, does it look good,
and did it come out as intended.

| Landscape | Built | Looks | Intent | One line |
|---|---|---|---|---|
| Mesa badlands | 4 | 4 | 2 | Chisel mesas are crisp buttes within 0.1 m of target; nothing makes it dry |
| Hill fort | 4 | 3 | 3 | Wire slice exact, closed ring cuts; moat uneven from the gorge's fall |
| Rice terraces | 4 | 3 | 2 | Crisp shelves, but no lip: water cascades, never pools; reads as a ziggurat |
| Pastoral downs | 4 | 3 | 2 | Swells hit height exactly, but gentle hills don't read and forest takes over |
| Infinity edge | 3 | 5 | 3 | Edge fall looks excellent; pond drains to a stream; fall dies with the pour |
| Mountain tarn | 3 | 4 | 3 | Best image (summit tarn spilling a tall fall), but only by luck of the rim |
| River valley (take 2) | 3 | 4 | 3 | Water follows the S only once the cut is deeper than the land's fall; reads as an S-shaped lake |
| River valley (take 1) | 3 | 4 | 2 | Spring fell as a waterfall and made a frog pond; ignored the sweep |
| Crater lake | 3 | 3 | 2 | Pit reads as a quarry; no way to raise a rim |
| Island lake | 3 | 2 | 2 | Good basin; pinch island is a spike; oak won't land on the island |
| Plunge pool | 2 | 3 | 3 | Got it on take 3; the "cliff" is a 1 m jagged band, so the fall reads as a chute |
| Marsh delta | 2 | 3 | 1 | Braids never read; shallow water is a faint sheet under mist |
| Zen garden | 2 | 2 | 1 | Clay can't rake; ribs are 0.5 m ploughed furrows; trees and deer overrun it |

Average intent: 2.2 of 5. The kit makes things that look good more easily
than it makes what you meant.

## What's strong

- **The Chisel mesa** is the most distinct, most controllable verb in the kit.
- **The Paddle swell** is predictable and hits its height every time.
- **The Wire slice** is exact, and one closed Wire drag cuts a clean ring.
- **Water as a system** keeps rescuing builds with falls nobody planned. The
  edge falls and the spring falls are the best images in the audit.
- **Life arriving** reads as a surprise: frogspawn, lily pads, frogs, deer.
- **Raising vs cutting** is well differentiated across tools.

## Findings, by priority

### 1. Bugs
- **A shaping press that lands on a tree or shrub does nothing.** There is no
  feedback, and it broke three builds. It gets worse the more a world grows.
- **A Hammer gesture straight after another is eaten,** or read as a single
  knock. It works after a 1 s pause.
- **A hold pressed just after the camera moves close sometimes does nothing**
  (seen twice).
- **A slow drag can be read as a hold:** under 6 px in the first 0.3 s. That
  is about 20 px/s, so a careful real stroke can trip it. A slow Shift drag
  became a fine pinch.
- **A Chisel pit reports its verb as `mesa`.**
- **Thousands of `!v.is_finite()` errors** from land_clay `_place_prop` →
  cursor_motion `advance` normalize while the scripted pointer drives the
  tools. Not yet checked with a real mouse.

### 2. You can't tell water where to go
Every water build fought this.
- **No verb raises a line,** so there is no levee, dam, bund, rampart or
  crater rim. A Chisel drag above the ground makes a level causeway that holds
  water, but it always cuts a face on its downhill side, so it reads as a
  trench.
- **No "spill here".** Chisel pits keep a level floor while the downhill rim
  sits lower, so the overflow goes wherever the ground is lowest. Terraces
  have no lip. The Wire gorge always falls downhill, so a ring moat steps by
  0.67 m.
- **A pour is a fixed ball,** so falls die when it runs out. Players want a
  spring that lasts.
- Possible verbs:
  - a Paddle berm (sweep with the blade reversed, or Shift-hold)
  - a Chisel fill that leaves no face below it
  - a pinch dragged along a line to make a ridge
  - a Wire cut with a level bed (no fall) for moats and channels

### 3. Carving only goes 1.5 m down
`MIN_HEIGHT` is -1.5 m, while raising goes to 64 m. Every cut bottoms out:
- rivers become level lakes
- marsh braids merge into one basin
- gorges become canyons with flat floors

Either start the plate higher, giving several metres of dig, or lower the
floor.

### 4. Life buries the landform
- One oak flick plus emergence gave about 70 trees. The downs, the zen
  garden, the crater and the mesas all turned into forest within 15-30 s at
  4x speed.
- Trees grew in standing water.
- There is no way to keep ground open or dry: no sand, gravel or dry soil,
  and nothing in the biome decides "this stays bare".
- You can't plant one specific tree where you want it, because seeds go
  where the wind takes them.

That may be the right call for "you release, the world decides", but it
needs a counterweight. Open ground could be a material: sand or gravel that
emergence respects.

### 5. The fine end is missing
- **Zen garden, the name of the game, can't be built.**
  - The land's points sit 0.45-0.75 m apart, so raking by moving the
    heights is impossible.
  - The size pips scale width, not depth: a size-1 groove is still 0.75 m
    deep.
  - Shift on the Modeller is the palm, not a shallow groove.
  - The pat only flattens to about 0.4 m of spread, and the palm digs a pan
    rather than levelling.
- A rake would have to be a ground-paint or shader pattern (raked gravel),
  not a change to the heights.

### 6. Overlaps
- **Paddle sweep and Modeller groove** look the same on screen: a dark dirt
  trench at two widths. Seen in three builds.
- **Five verbs make "a pond":** swell-down, pinch-down, Chisel pit, palm and
  pat. On screen only the outline differs.
- **Wire gorge and repeated grooves** overlap for rivers.
- **Shift on the Chisel mesa** slows the climb rather than making it smaller.

### 7. Hard to read on screen
- Fog and mist blanket every hollow, so water in basins and moats is hard to
  see, even at noon.
- Shallow water is a faint glassy sheet.
- Gentle hills (1-2.5 m) barely differ from a fresh plate in the building
  view, because the faceted shading doesn't mark crests.
- Flower drifts are invisible at plate scale.
- The Feather leaves nothing behind once released.
- Wire-sliced tops are bare brown dirt.
- Chisel cliffs are about 1 m of jagged blocks, so there's no tall straight
  cliff. Close Chisel rings eat each other into rubble, and arc ends leave
  thin rock fins.

### 8. The Hammer is thin
- It does nothing on flat Chisel tops, because they aren't "rock" (paint,
  slope or snowline).
- One blow is invisible from the building view; it takes four in a row to
  read as talus.
- It is the weakest tool in the roll.

### 9. The plate edge
Only the Modeller groove can cut the rim. The Wire and Chisel fade out over
the last 2.2 m. Edge falls are among the best images in the game, so the
rim should be reachable on purpose.

## Hand-build shortlist (for feel)

1. **Mesa badlands.** The strongest tool. Does aiming a mesa's height by eye
   feel good?
2. **River valley.** The hardest intent. How long before a player gives up on
   steering water?
3. **Infinity edge.** The best look. Will players find the groove-through-
   the-rim trick?
4. **Zen garden.** The one players will expect from the name, and the kit
   can't do it. Do you hit the wall as quickly as the script did?

## Harness notes
Fixed after the agents' runs: drags and holds are paced by the game's frame
delta, the budget timer ignores `time_scale`, stills hide the rig's hover
label and ring, and `run.sh` filters the `is_finite` flood. Each drag logs
the verb the clay decided.

Still open: gestures after a close `view()` can aim off screen, and
`settle()` doesn't wait for a tool's run-on (`busy()`).
