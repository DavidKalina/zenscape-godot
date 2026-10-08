# Ruin kit: handoff

Branch `look/ruin-kit-hall-2` (from `look/ruin-kit-ext`, with `feature/knife-edge` merged in). Not merged to main.

The user's verdict so far: the aqueducts are "amazing" (their look is left alone). The halls "have potential" and should become long halls you weave through. Flying the first fly mode was "freaking awesome", but the inside was too dark. No glowing ornaments on the ruins. What the kit is for: big lower-world landforms dense with halls and aqueducts woven through terrain, flown in and out of and climbed on foot.

## What changed this round

- **Curved halls.** A hall's plan is a list of straight and curved stretches (`layout`). Bays on an arc are wedges: columns, beams, walls and roof follow the curve.
- **Roof in stretches.** Each bay's roof is `whole` (the dark nave), `broken` (half the nave's slabs gone, slabs tipped, fallen slabs on the floor) or `open` (no slabs, some beams and architraves kept, walls torn lower). Plans cycle whole → broken → open → broken.
- **Wall breaches.** These are `door` (walked through), `low` (wall torn down to 1.2–1.6 m: one jump onto it, flown over), `arch` (a wide pointed opening 5.2 m wide, springing at 5.4 m) and `collapse` (stumps and rubble). Every flyable breach gives a corridor from the lane out past the wall. Plans guarantee at least two flyable breaches on the right, one on the left and a door.
- **Skyline.**
  - Under a roof, side walls stand on past it as ragged parapets (0.6–1.8 m).
  - Gables rise 6.5 m over the roof beam across the whole section, at the mouths and where a roof meets the open sky.
  - Each roof strip is laid as two settled slabs.
- **Interior light.**
  - Each face now carries a shelter amount (0 open air, 1 deep under the roof) in its vertex alpha.
  - `shaders/ruin_stone.gdshader` (via `ZS_SHELTER_BOUNCE` in `folk_surface.gdshaderinc`) adds a warm, sky-and-floor bounce fill to sheltered faces. It is strongest on faces that look down or across.
  - Paving under an open sky is paler, so light pools there.
  - No lamps, no haze. Shaft fog now fills only roofed and broken bays: one box per bay, turned along the path.
- **Cost.**
  - `Build.lean` gives cheap stone: a box's arrises are chamfered only along its length and on top. Lean stone also has a sixth of the chips, keeps its tops level, uses bigger stones and courses and cheaper ivy, leaves and cushions.
  - `Build.cull` drops hidden faces: course joints, stacked drums and faces buried under the ground or below `Build.ground`. A face is dropped when all its probes, stood 3 cm off it, lie in other blocks.
  - Columns have 12 sides. Lean columns have 6 niches and 7 single-disc roundels, and beams carry no roundels.
- **Fly mode** (gallery):
  - **Start:** G starts in daylight at the first mouth, flying in, with the chase camera behind the plane. R or the pad's Back/View restarts the run.
  - **Knife edge** (the game's): hold Q/E or LB/RB to knife-edge. A double tap within `WandererEye.DOUBLE_TAP`, or a click, is a barrel roll.
  - **Bump:** the bump probe is a wing-wide slab (`PlaneFigure.SPAN` × 0.3 × 1.2 m) turned with heading, pitch, bank and roll. A level plane bumps in a knife slit; a knife-edged one passes (checked with physics queries on both slits of a 12-bay hall).
  - **Autopilot:** it follows the curve in path space. `--fly=N` captures at N seconds, mid-flight; `--lean=` and `--height=` steer the autopilot.
  - **Scale figures:** the scale planes in the hall hide while flying.
- **Gallery.**
  - The centrepiece is a 16-bay hall: 4 straight bays, 6 curving 0.85 rad left, 6 straight. It mixes whole, broken and open roof, has breaches on both sides, and an aqueduct run (head and 4 spans) is chained onto its first mouth.
  - The terrain demos slope down to the plate in rough facets (`TERRAIN_FADE`) instead of sheer blocks.
  - `--hall-at=` and `--hall-look=` place the capture camera in the long hall's path space.
- **Fixes.**
  - Course rows now break at a hole's sill, so no stone straddles a sill and juts into a slit or window.
  - Snapped spires keep crockets well under the break (no floating crockets).
  - Hall buttresses are never snapped.
  - The autopilot frame that ended "over the clouds at night" was the plane leaving the hall at the curve after a fixed 4 s wait. The capture now waits for `--fly` seconds, and the autopilot follows the path.
- **Found while fixing:** the hall's pair pieces in the rows overlapped the old centred hall placement and caused phantom bumps. The hall is now placed with its front where the straight hall's stood.

## Triangle counts (12-bay hall, seed 20)

| Build | Before (`look/ruin-kit-ext`) | Now |
|---|---|---|
| Detail 1, weathered 0.6 | 829k | 121k |
| Detail 1, weathered 0 | 607k | 91k |
| In-world detail 0.25, weathered 0.6 | (n/a; ~470k+) | 94k |
| In-world detail 0.25, weathered 0 | | 82k |
| Detail 0, weathered 0.6 | 466k | 84k |
| Detail 0, weathered 0 | 481k | 79k |
| Collision hulls | ~5.3–5.6k | ~2.5k |
| Gallery 16-bay curved hall, detail 1 / 0.25 / 0 | | 160k / 124k / 111k |
| One weathered bay (piece), detail 1 / 0 | ~100k / 48k | 13k / 9.8k |
| One weathered column (piece), detail 1 / 0 | 25k / 3k | 2.8k / 950 |

- The budget is `Hall.BUDGET` (100k) at `Hall.IN_WORLD` (0.25). The test checks it for seed 12. The margin is thin: seed 20 at weathered 0.6 is 94k.
- A 12-bay hall builds in ~0.4–0.7 s.

## Contracts (for a layout pass)

- **`Hall.hall(seed, weathered, bays, ground, merged, layout)`.**
  - `layout` is `[{bays, turn}]`. `turn` is in radians over the stretch, + to the left looking down the nave (toward −Z). The stretches' bays sum to `bays`. Empty means straight along +X.
  - Keep the radius ≥ ~40 m (bays × 8 / turn). The inner wall compresses by (1 − 13.6/R).
- **Path space.** x runs along the nave's middle line from the first mouth, y is up, z is across (+Z the right).
  - `root.get_meta("path")` is a `HallPath` with `xform(s)`, `point(p)` (path space → hall frame), `locate(p)` (hall frame → path space), `tangent(s)`, `curved()` and `length`.
  - On a straight hall, path space and the hall frame are the same.
- **Metadata.**
  - In the hall frame: `bounds`, `feet`, `ends` (`at`, `heading` along the path's tangent, `height`, `open`).
  - In path space: `weave`, `walk` and each corridor's `box`.
  - `corridors` is an Array of `{kind: "lane"|"breach", box: AABB (path space), points: PackedVector3Array (hall frame, the middle line of its floor; along the nave for the lane, across for a breach), width, height}`. The aqueduct's corridors are still plain AABBs in its own frame.
  - `weave` adds `breaches` (`{box, side: -1|1, kind}`), `doors` (`{at, side}`) and `open` (an AABB per open bay: open to the sky over the nave).
  - `plans`: each bay's plan carries `roof`, `breach` (a Vector2i of `Hall.BREACHES` indices, left and right), `beam`, `architraves`, `gable` and `last_gable` (see `bay`'s doc comment).
- **`ground`** is as before: a Callable(x, z) → y in the hall frame. Open stretches tear their walls lower over their own ground.
- **Build** (scripts/ruin_kit.gd):
  - New fields: `lean`, `cull`, `path` and `rigid` (a block carried whole by the frame at its middle; columns and fallen beams use it), and `shelter` (Callable(middle, normal) → 0..1, written into vertex alpha).
  - Faces are now drawn at `finish` (`pending`), not as each block is cut.
  - The gothic and aqueduct families use none of these, so their geometry is unchanged apart from the sill-split and crocket fixes.
- **Vertex alpha** on ruin stone is now the shelter amount (1 means open air). Don't use it for transparency.

## Scale and clearance

These are unchanged (see `tests/test_ruin_kit.gd` `_scale`), plus:

| Constant | Value | Use |
|---|---|---|
| `Hall.COURSE` | 1.25 | Hall wall course |
| `Hall.BREACH_HALF` | 1.8 | Half-width of a flyable breach's corridor |
| `BREACH_FLOOR` / `BREACH_TOP` | per kind | Floor and top of a flyable breach's corridor |
| `Hall.OPEN_SKY` | 4.6 | Height over an open bay from which it is clear to the sky |
| `Hall.LOW_WALL` | 1.2–1.6 | Height of a torn-low wall (under GRAB_TOP 1.875: one jump) |
| `Hall.ARCH` | 5.2 wide, springing 5.4 | Arch breach |
| `Hall.DOOR` | 2.4 wide, springing 2.2 | Door: walked, not flown (under THREAD) |
| `Hall.PARAPET` | 0.6–1.8 | Parapet over the roof |
| `Hall.GABLE_RISE` | 6.5 | Gable over the roof beam's top |

## Gallery

```
./run-ruin-kit.command [--family=hall] [--centre] [--fly[=seconds]] [--lean=-1..1] [--height=m] [--night] [--no-shafts]
godot --path . res://studies/ruin_kit_gallery.tscn -- --no-title --capture=out.png [--at=x,y,z --look=x,y,z | --hall-at=s,y,z --hall-look=s,y,z]
```

- Keys are as before: F1, F2, F3, 1–9, C, Space, W, R, N, L, G.
- In fly mode:
  - A/D bank, W/S pitch, the mouse steers, Space boosts, Shift brakes.
  - Hold Q/E or LB/RB to knife-edge. Double-tap or click to barrel roll.
  - Hold right mouse to look round. R or pad Back restarts. G or Esc exits.

## Checks

- `tests/test_ruin_kit.gd` passes headless.
  - New: `_breaks` (stretches of all three roofs; each open bay clear to the sky; each flyable breach a clear corridor from the lane to outside, both sides; a door; corridor count).
  - New: `_curved_hall` (curved lanes clear in path space for turns of 0.9 and −0.7; breaches and open bays on curves; ends at the path's ends heading round the curve with outer columns there; the lane's corridor line along the lane's middle).
  - New: `_budget`.
- `tests/test_sky_plane.gd` (from the knife-edge merge) passes headless.
- The headless import is clean.

## Known issues

- **The roof still reads as a patchwork from above:** big flat slab tops, some fully mossed (green), next to grey and brown ones. It is better with the split, settled slabs and parapets, but it is still the weakest view.
- **Shade faces facing away from the sun read very dark outside**, e.g. gable faces and breach jambs on the shaded side. That is the kit's normal outdoor shade, not a bug, but it is stark on big flat faces.
- **Interior light is judged from stills of the fly camera only**, not by hand at speed.
  - The bounce (`shelter_fill` 4.5, warm tint) makes columns and beams readable.
  - The roofed paving still reads fairly dark.
- **The budget margin is thin** (94k of 100k for seed 20 at in-world detail). There is no near/far LOD swap. The detail-0 build (~80–85k) is the cheap version, and a far LOD (8-sided plain columns, no carving, merged courses) is the next lever.
- **Curves:**
  - Lean wall stones on the outside of a curve are stretched by (1 + 13.6/R), and course stones are chords.
  - The fog boxes per bay leave thin wedge gaps on the outside of a curve.
  - `locate` picks the nearest stretch's middle line, so it is ambiguous only for very tight or self-crossing plans.
- **Aqueducts don't curve yet.**
- **Untested in play:**
  - Bump feel against walls, columns and beams is checked only by physics queries and autopilot runs (it bumps and recovers along the face, never crashes).
  - Knife-edge through the slits by hand.
  - On-foot routes over low breaches and up the buttress stairs.
- **The gallery's tag label** for the long hall can be seen through a door breach from inside.

## Next steps (prioritised)

1. Fly it by hand: bump feel, curve radius, breach sizes, how fast the light changes between stretches. Tune `shelter_fill` live if still dark.
2. The roof from above: less whole-slab moss, more broken edges and fallen runs, maybe a raised clerestory over the nave in whole stretches.
3. A far LOD for landforms (plain 8-sided columns, single-block courses, no growth), swapped by distance.
4. Curved aqueduct runs (the same HallPath bend on the run's spans, piers rigid).
5. The layout pass: feed the corridors (lane and breaches), ends and feet to scripts/landforms.gd and chain hall → aqueduct → hall over real terrain.
