# Isle lodestone: handoff

Branch `study/isle-lodestone`, from `study/aqueduct-isle-plane` (c498dfa6) with `look/lodestone` (9fd567f0) merged in. This is a study scene only. The game's own plane (`scripts/plane_figure.gd`, `scripts/wanderer_eye.gd`) is untouched.

The flow: find the lodestone on the aqueduct isle, pick it up and look at it, board the new stone plane, and fly by the wing-seam compass to a shard floating far off.

## How to play

```
./run-aqueduct-isle.command                       # the whole flow, from on foot
./run-aqueduct-isle.command --carry               # start with the stone already carried
./run-aqueduct-isle.command --carry --fly         # start in the plane, stone seated
./run-aqueduct-isle.command --wood-plane          # the game's wooden biplane instead
```

1. You start at the rubble slope's foot. The lodestone hums on the floating stone east of the heel stone (platform `east_1`, about 30 m east). Jump onto the grounded block (`east_0`), then onto the floating one.
2. Standing on it, press **E** or **pad A** to pick the stone up. The pilot raises his mitts, the stone floats down into the air over them, and the camera pushes in. **Drag the mouse** or use the **right stick** to turn it. Press **E, Enter, pad A or pad B** to keep it. It then rides at his right side as a small glow.
3. Press **F** or **pad Y** to board. The stone flies into the chamber in front of the pilot. A sync pulse runs through the slabs from nose to tail, and the seams wake.
4. Follow the seams:
   - The brighter wing is the way to turn. Both wings even and faint means you are on course.
   - The top fin lit means climb; the bottom fin lit means dive.
   - The tailplane lit means the target is behind you.
   - The prow glyphs and the deck runes flare when you are dead ahead.

   Soft wisps also stream from the nose toward the target. The hint shows the distance.
5. Within 30 m of the shard you get a chime, a pop and a flash, on the plane and on the shard. Fly 90 m away and come back to see it again.
6. Press **F** to get out. He keeps the stone, and boarding again seats it again.

The flight controls are unchanged (see the on-screen hint).

### Flags added

| Flag | Does |
|---|---|
| `--stone-plane` / `--wood-plane` | which plane to fly (stone is the default here) |
| `--carry` | start carrying the stone |
| `--lode-at=<platform>` | rest it on another floating stone (`studies/aqueduct_isle_art.gd` `platforms()`, e.g. `drift_6`, `ring_sarsen`) |
| `--target=x,y,z` | move the shard (default `250,54,-230`, about 290 m north-east of the start, a little up) |
| `--no-lode` | leave the stone and the shard out |
| `--pickup` | pick the stone up at once if he stands by it (captures) |
| `--plane-eye=x,y,z` | the capture eye in the plane's frame instead of the chase camera |

## What's built

### The stone plane, "A Swift" (`scripts/stone_plane_figure.gd`)

It is a procedural port of `art/blender/plane/stone_build.py` `build_A`. It uses the same coordinates, the same `section`, `keel_section`, `keel_trough`, slab and gap lofts, and the same cockpit coaming. It has the wooden figure's calls (`reset`, `update`, `shift`, `show_pilot`, `park`, static `pose`, `SPAN`, a hidden `_mark`), so `studies/aqueduct_isle.gd` swaps it in with one line.

- **Unchanged.** The flight size (1.4 m span), the collision (the isle's bump body uses `SPAN`), the chase camera and `SkyPlane` are all as before.
- **Stone.** It uses the ruin kit's stone shader (`shaders/ruin_stone.gdshader`) at the eroded look's fill and rim. Faces are coloured one by one in the eroded look's basalt (`5a5d63` to `52575f`), with worn tops paler and the odd lichen face.
- **Floating slabs.** There are 14 slab nodes: 6 wing slabs, 2 tailplane slabs, 2 fins, and the prow, chamber, cockpit and boom pieces.
  - Each bobs up and down by up to 6 mm and tilts a little, out of step with its neighbours. The phase follows position plus jitter, so a slow ripple runs through the plane.
  - The hull bobs less.
  - When dormant (no stone seated), the bob drops to a quarter of that.
  - The sync pulse lifts each slab about 1 cm as it passes.
- **Seams.** There are 7 channels (L, R, UP, DN, BK, RING, GAP), each its own glow material (`shaders/stone_plane_glow.gdshader`). Emission is 0.15 + 9 × level^2.5, scaled by `wake`. Levels follow the compass with a 0.18 s ease, so the light flows from wing to wing.
- **`compass()`.** It is a straight copy of `stone_render.py`'s rules (L/R, UP/DN, BK, RING, GAP).
- **Ribbons.** Soft additive ribbons sit behind the trailing edges (`shaders/stone_plane_band.gdshader`). Their strength scales with the eye's distance: 0.08 under 1.5 m, 1.6 at 5 m and beyond.
- **Wisps.** Three camera-facing strands curl from the nose toward the target and are swept back with speed. They also scale with the eye's distance and fade within 15 to 60 m of the target.
- **Heart and needle.** The real lodestone sits in the chamber at 0.4 scale, with its light off. The needle floats 8.5 cm over it and is aimed at the target on an ease. Both appear only once seated.
- **Empty state.** Seams, gaps, ribbons, runes and wisps are all dark, the needle is hidden, and the slabs barely stir.
- **Pilot.** It is the game's `PlanePilot`, sat 0.16 m lower than in the wooden plane, so only the head and scarf show. The scarf is shorter, because a long one lay along the boom and hid the runes. There is no engine buzz.

### Speed cue: runes along the deck, no nose ring

The concept's rune ring sat behind the pilot's head in the chase view, like a halo. I dropped it. Instead, strips of glyphs on the deck (`shaders/stone_plane_runes.gdshader`) run back along the hull:
- two strips on the prow, before the pilot;
- one down the boom, behind him, which is the most visible part from the chase camera.

They run faster with speed (0.06 m per second per m/s, integrated by the script), and the dashes stretch at boost. They also carry the RING channel: they flare dead ahead, together with a small ring of glyphs and a ribbon round the prow. Those sit low and small, below the head in the chase view. I chose this over the spinning stone collar because a collar at the nose would still sit near the head's silhouette, while the boom runes sit in clear view behind him.

### The isle (`studies/aqueduct_isle.gd`)

- **The resting stone.** The lodestone (Sundered hall miniature, 2.2k triangles; the aqueduct miniature's 29k was not used) rests 0.85 m over `east_1` at 1.5× hand size and bobs. It hums from 9 m and fully at 1.6 m.
- **Picking it up.** You can only pick it up standing on its stone, within 1.5 m across. The pad's A is the jump; only there does it pick up instead.
- **Inspect.** This is the lodestone study's pickup: the same arm pose, arc, push-in and turning. On keeping, the camera eases back over 0.5 s.
- **HUD.** The moments HUD (`scripts/moments_hud.gd`) gives the pops, a blip on pickup and keep, and the tokens' flourish as the arrival chime.
- **The target shard.** `Lodestone.keel_mesh` at island scale, veined with the lode, carries a gothic kit arch and pier and collides as a convex hull.
- **Arrival.** A big soft flash on the shard and a lode swell, while the plane's seams flare and the pulse runs again.
- **Hints.** Both the on-foot and flying hints carry a lodestone line.

### Tests

`tests/test_isle_lodestone.gd` (headless, passes) covers:
- the compass rules;
- resting, the hum near against far, and that it can't be picked up from the start or from the ground under its stone;
- pickup: held over him, the camera close, a drag turning it;
- keep and carry;
- boarding: dark until settled, then seated in the chamber with the needle, the pulse waking the seams and the gaps glowing;
- targets left, right and up: the right channel lit, the opposite near dark, and the energy ratio;
- the needle aim;
- the triangle budget;
- arrival;
- leaving and re-boarding.

The existing `test_aqueduct_isle.gd`, `test_aqueduct_isle_plane.gd` (now flying the stone plane), `test_aqueduct_isle_look.gd` and `test_lodestone_study.gd` all pass. The full suite was not run.

## Captures

In `docs/design/isle-lodestone/`. They are gitignored and local only.

| File | Shows |
|---|---|
| `chase_right.png`, `crop_right.png` | chase view, target right: the right wing gold-white, the left dim, the wisp to the shard (visible top right) |
| `chase_left.png`, `crop_left.png` | target left: the left wing lit |
| `chamber_small.png` | over the pilot's shoulder: basalt, glyph channels, the right-hand seams lit |
| `needle_small.png` | front three-quarter of the cockpit and chamber |
| `inspect_small.png` | the pickup: mitts raised, the Sundered miniature in its swirl |
| `found_small.png` | on foot near the floating stone |

The chase and crop captures were taken before the colour change, so their stone reads warmer brown than it does now.

## Cost

- **Stone plane:** 2,588 triangles of its own (the test counts them; the pilot and the stone are not included). The concept estimated about 3.6k with the ring.
- **Draws:** about 40. There are 14 slab nodes with 1 to 3 surfaces each, the gaps, the ribbons (6 surfaces), the needle (3) and the wisps (1).
- **Seated lodestone:** about 3k triangles and about 9 draws (the study's figures).
- **Frame:** the chase captures measured 115 to 139 draws and 67k to 97k primitives on screen at about 16.7 ms. That number is pinned to the refresh rate, so frame time is not really measured.
- **Shader uniforms** are set every frame on about 15 materials.

## Weaknesses (honest)

- **The stone is hard to find from afar.** At 1.5× it is still under half a metre across, about 30 m from the start, with no beacon or sound. The hint tells you where it is. A mote column or a hum you can hear would be better.
- **The pickup can be too easy.** It is two small hops. If you want more, `--lode-at=drift_6` or `ring_sarsen` puts it at the end of a real route, but those were not tried in play.
- **The needle and the seated stone barely read.** Up close, the lodestone at 0.4 scale sits low in the trough, and the needle is a small pale spindle. At cruise both are hidden by the head, as the concept expected. The chamber wants a lift or a bigger needle for the boarding moment.
- **The seams at full glow clip toward white,** even with the deeper gold. On-course faint gold against a full turn side reads well; "gold" itself is weak.
- **Up and down rely on the thin fins** and were checked only headless (levels and energies), not in a rendered capture.
- **The ribbons and wisps are untuned in motion.** The wisp reads clearly in the chase capture; the ribbons are subtle.
- **The slab bob is small (6 mm).** It is visible close up but probably invisible at chase distance. It was deliberately kept small so the gap plates, which don't bob, don't open up.
- **The seating flight is short (0.9 s)** and happens while the chase camera swings in from the walker's view, so you may miss it.
- **The arrival has no rise moment.** It is a flash and a chime only. The shard is a placeholder rock with an arch and a pier, not the Sundered hall that the miniature shows.
- **The inspect camera** ends in front of him looking back at the stone over his raised mitts. It reads, but his face is half under the stone (the study's open issue).
- **The capture frame times** are capped at 16.7 ms and not meaningful.
