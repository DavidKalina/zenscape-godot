# Pirate ship model: handoff

Scripted Blender build of the pirate ship, retuned to "Contract for the model"
in the gray box's `pirate-ship-handoff.md`. Not wired into the world.

Stills, in the game's sea and light (rendered on the Mac):
`docs/design/endless-flight/pirate-ship-stills/`.

## Cannonball pass

The ball in the game was never gray: it was a flat sphere with orange emission 1.4,
which read as molten. It is now polished dark iron with a mirror highlight, no
glow and no orange, trailing a pale wisp of powder smoke in place of the gray box.
Radius, speed, pool, collision and tuning are unchanged. `--ship-blocks` keeps the
old sphere and box.

- **Ball:** `art/blender/ship/ball_build.py` writes `assets/models/pirate_ball.glb`
  (288 triangles, a 16 x 10 UV sphere), `ship_ball.jpg` (1024 x 512),
  `ship_ball_n.jpg` (512 x 256) and `ball.tres`. Maps are painted in numpy on the
  sphere, so nothing seams: faint pits, a trace of rust, two mould seams, sprue scars
  over the poles. No roughness map: one value (0.2) gives the shine, and the marks
  are too small in flight to earn one.
- **Material:** `ball.tres` uses the ship's `surface` shader, so no new shader
  there. Metallic 0.9, roughness 0.2. On metal the albedo tints the reflection, so
  it is painted light (about 0.72 sRGB); at 0.5 the ball went black in the play
  view. Dark pit paint turned to black holes for the same reason, so pits and rust
  are only a little under the iron. `fill` 2.5 and `rim` 2.5 hold the shade.
- **Shared:** `_ball_mesh` and `_smoke` are one mesh each through the 24-ball pool,
  read when she is dressed, so no load at the first shot. The ball's material is on
  the mesh. The old build made a mesh and two materials per ball.
- **Tumble:** 3 rad/s on the body only (`BALL_TUMBLE`). The tail stays on the line.
- **Smoke:** `PirateShip._smoke_mesh` strings soft discs back along the ball, 18 m,
  radius 0.45 to 3.6 m, and `ball_smoke.gdshader` turns each to the eye about its own
  centre, so no view shows a flat side. Unshaded pale gray, blended, no shadow. Head
  on the discs stack into a faint pale ring round the ball. Knobs `SMOKE_*`.

Tricks for this pass:

| Trick | Used | Estimated saving |
|---|---|---|
| Sculpt high, bake low | No: height is painted straight into the normal map | None; the marks are too small in flight to pay for a sculpt |
| Import LODs | Yes (`meshes/generate_lods`), unmeasured | At most 150 triangles a ball at range, under 0.01 ms |
| Visibility ranges | No: the ball must read at 300 m, and balls live 7 s | None |
| Silhouette geometry | No: the seam stands under a pixel proud of the outline at 30 m, so it is normal map only | About 2k triangles a ball against a real ridge |
| Rigid parts on bones | Not applicable | None |
| Parallax depth | No: pits are faint now | None |
| Vertex-colour grime | No: the map carries it | None |

The wisp is 34 triangles (17 discs), so a full pool is 7,728 triangles.

- **Frame time** (Mac window, 1440x900, uncapped, 180 m off the stern): 24 balls
  all in view, old look and new in turns, 480 frames each, three runs. The ball
  alone, with the box still on: 12.11 against 12.15 ms median, within noise. With
  the wisp: 12.13 against 12.32 ms median, so about 0.2 ms, and p95 is level
  (12.63 to 13.08 against 12.74 to 12.95). That is the worst case: the guns rarely
  have 24 up at once. The cost is the wisp's overlapping transparent discs.
- **Proved:** clean import; smoke plain, with `--fresh --ship-start --full-meter`
  and with `--ship-blocks`; bot on real input, three passes, six bursts, 346 checks
  passed. Real shots: one ball mesh and one wisp mesh through the pool, the material
  on the mesh, the body tumbling; with `--ship-blocks`, the old sphere and box,
  no tumble. Stills looked at: 30, 100 and 300 m over sky and sea, from the side,
  head on, from behind and quartering, and real shots at 30, 93 and 201 m. `16`
  close-up, `17` a real shot, `18` over dark water, `19` side, `20` head on,
  `21` behind.
- **Unproved:** hand-flown; judged in motion, so the tumble and the wisp are judged
  from stills only; PC fidelity; other hours (the wisp is a fixed pale gray, so it
  may stand out at night). The close-up shot view draws some cloud sprites over the
  ball; that is the harness's camera, not seen in the play view.
- **Readability:** the molten sphere was easier to see at 300 m than any dark ball.
  Now the far ball is a dark dot with a sun glint, and the wisp carries it. It held
  over dark water, but judge it by playing.

## Sails pass

Whole, weathered canvas that fills on the game's wind. Hull, crack, guns, masts and
rigging are untouched: off the glb, only the nine `Sail_*` meshes differ from the last
build, and of the textures only `ship_sail.png`. Names, `--ship-blocks`, no collision.

- **Mesh:** each sail is a flat sheet (`sail_geo`, knobs `SAIL_CELL`, `SAIL_MIN`),
  crowded toward the leeches and foot. Its vertex colour holds its size for the shader.
- **Shape:** all in the vertex shader (`SAIL_CODE`, written to `ship_cloth.gdshader`),
  one material, normals from finite differences. Head pinned at the yard.
- **Wind:** `zs_wind_strength`, `zs_wind_direction` and `zs_gust_distance`, the air
  taken as 20 m/s at strength 1 (`wind_ms`), less her own velocity. It fills once the
  air comes aft of about 123 degrees off the bow (`draws_from`, `draws_full`), judged
  against her bow, not the braced yard, so both tacks fill. Forward of that it flogs,
  and never goes more than 0.5 m aft (`AFT`). Fixed yards can't trim, so this is a
  stand-in for bracing them.
- **Gusts:** `scripts/wind_gust.gd` isn't in the tree, the sea has no parcels, and
  `zs_puff_*` are only the landing's. So `sail_gust` reads the land's gust field at
  sail size (about 60 m parcels), passing mast by mast.
- **Per ship:** `scripts/endless/ship_sails.gd` sends instance uniforms `ship_way` and
  `ship_slack`, and only when they change. It also sets `extra_cull_margin` (the mesh's
  box is flat) and `lod_bias`, because generated LODs would flatten the sheet.
- **Seed 1:** wind 0.968 rad. The +x straight has it on the quarter and fills; the -x
  straight has it forward of the beam and is about a third full; the west turn goes
  slack on the nose. At wind below her 9 m/s she outruns it and goes slack.
- **Sink:** `ship_slack` over 3 s, and the cloth swings to true down about the yard.

Tricks for this pass:

| Trick | Used | Estimated saving |
|---|---|---|
| Sculpt high, bake low | No: flat sheet, painted canvas | None |
| Import LODs | Off on sails: the shader needs the grid | Costs about 2k triangles at range; a coarser sail past 400 m would win back about 3k, under 0.05 ms |
| Visibility ranges | No: the billow must read at 300 m and past | None |
| Silhouette geometry | Yes: outline is real shape from the shader; holes and hem stay alpha | 4,060 triangles against about 40k for cut cloth, about 0.5 ms |
| Rigid parts on bones | Not applicable | None |
| Parallax depth | No | None |
| Vertex-colour grime | No grime; the channel carries the sail's size | Saves a UV2 layer, about 2 KB |

- **Cost at 300 m** (Mac window, 1440x900, uncapped, 3 x 400 frames, sails shown and
  hidden in turns; another session may have been running, so provisional): draws with
  sails against without, +21 to +28, the same before and after. Triangles in the frame
  about +8k to +10k against the old sails on the later runs, the extra 1,540 through
  every pass and no LOD. Shown minus hidden is within noise, 0.4 ms either way, before
  and after. Medians drifted 14.5 to 18 ms between runs with sails hidden too, so that
  drift is not the sails, and the run can't resolve under about 0.5 ms.
- **Proved:** clean import; smoke plain, with `--fresh --ship-start --full-meter` and
  with `--ship-blocks` (that one before the last wrap-up pass, same code); bot 346/346;
  corridor check. Stills looked at: `22` before, `23` low and high wind, fair and foul,
  at 300 and 100 m, `24` consecutive live frames, `25` the yard, `26` a sink (from a
  build before the last shape tune).
- **Unproved:** hand-flown; a gust caught in stills (the swing, 3 m to 7 m of belly on
  the mainsail, is worked out from the shader, not measured); the turn's lean, unseen;
  the -x straight on real wind, only forced headings; PC fidelity; other hours; a
  second ship (the uniforms are per instance, untried). No sheets: the rigging has no
  lines to the clews, so they float.

## Widened 12.5%

The user found the gun deck tight, so beam 22 to 24.75 m, deck and cracks 16 to 18 m,
muzzles x +-14 to +-15.375; length, heights and masts as they were. `WIDEN` scales the
hand-set x numbers (wound frames, lantern reach, the beak's gratings, stairs); plank,
rib and gun sizes stay. Sections below give the old widths where they describe a pass.

## Crack and gun deck pass

Two look fixes; flight, `solids()`, tuning, route and hull shape are untouched.
Off the glb: every node but `Hull`, `Interior`, `Cannons` and the plugs is identical
to the last build, `Hull` is identical away from its ends, and of the textures only
`ship_stern.jpg` changed.

- **The crack:** the plate is now thin broken boards on four snapped frames, about
  43% of the planking left, in `build_plug` (knobs `WOUND_*`, `FRAME_X`, `SPRUNG`,
  `SAG`, `HANGERS`). `plug` is the stern map with more fill (`PLUG_FILL`), so
  planks stand off black gaps. Behind them `Cover_S`/`Cover_B`, a black quad facing
  out only: dark from every range, no far-end daylight through it, and the exit
  still shows through the gaps from inside. Code hides it on a burst, the reseal
  restores it.
- **Shards:** 26 stern, 24 bow, not 12 (`SHARDS` 30, empty cells dropped). Boards
  are 0.24 m thick where the old shards were 1.2 m blocks. Throw numbers unchanged.
- **Why it went near black:** shadow, sway, fog and swaps are not it. Flying with the
  sun cut from the ship gave the same trace frame for frame. The light was only the
  baked vertex pools at each gun port (`inner_light`): 9 m reach on 16 m spacing,
  floor 0.16. So view brightness halved between ports (0.044 down to 0.026 mean,
  peaks at z +-8, 24, 40) and the end bays had a median of 0.005. The one bright
  moment was the relic's pickup light, which made the rest look blacker by contrast.
- **The deck now:** no real lights. `ship_deck.gdshader` works it out on the pixel
  in her frame: lanterns in the bays between the guns, none in the relic's bay,
  sun slats traced back to the gun ports on the real sun line (they move as she
  turns), the hold's fill falling off with distance, all off for an eye out in the
  day (so ports and the wound stay dark from outside). Knobs `DECK_*`, `LAMP_*`.
  Lanterns moved to `LAMP_BAYS`, still at x +-8.4. Mean view brightness holds 0.08 to
  0.13 down the deck on both headings, against 0.026 to 0.047.
- **Frame time** (the `--part=time` method, Mac window, 1440x900, uncapped), inside,
  median / p95, five runs before against three after: 22.5 / 30.3 and 22.5 / 30.4 ms;
  the runs scatter by 3 ms. 180 m off the stern: 15.4 / 20.2 and 14.7 / 19.3.
- **Proved:** bot on real input, stern to bow, bow to stern, stern to bow: six bursts,
  no crash, relic counted, reseal at about 301 m each time, no script errors. Smoke
  passes. Stills looked at: 400, 200, 60 m at both ends on both straights, and the
  deck through a Boost run on both headings. `10`/`11` crack, `12`/`13` deck before
  and after, `14` the ranges, `15` a run.
- **Unproved:** hand-flown; PC fidelity; other hours (slats go at sunset, lanterns
  stay, unseen). On the straights neither end faces the sun: the shaded end's hull
  is near black, so there the wound stands out much less, and bow and stern swap
  roles after each turn.

Tricks for this pass:

| Trick | Used | Estimated saving |
|---|---|---|
| Sculpt high, bake low | No | None |
| Import LODs | Unchanged | None measured |
| Visibility ranges | Unchanged. `Interior` could still hide past 300 m now the cover blocks it | About 18k triangles at range, about 0.3 ms |
| Silhouette geometry | Yes: broken boards are real outline, thin, in slivers | Plugs 4,360 triangles against 3,296, for 50 shards against 24 |
| Rigid parts on bones | Not applicable | None |
| Parallax depth | No: the gaps are real, the cover stops them | None |
| Vertex-colour grime | Yes, now grime only; the light moved to the shader | Replaces 12 lanterns and 12 ports as real lights, roughly 2-4 ms inside |

## What was built

- `art/blender/ship/ship_build.py` writes `assets/models/pirate_ship.glb` and
  `assets/models/pirate_ship/` (painted textures, two shaders, one `.tres` per
  material). `pirate_ship.glb.import` points each material name at its `.tres`,
  so loading the glb gives the right look with no code.
- Stock materials would go black in shade: the world has no ambient light. The
  shaders add the sky's hemisphere as emission, as `folk_surface` does.
- Hull: real strakes in stepped ribbons with wales and shot holes, a unique
  painted side map (tar, an oxblood gun band, soot, tide stains, fouling). Stern:
  two window galleries, quarter galleries, crown, three unlit lanterns.
- Both ends: see the pass above.
- Gun deck: ribs, beams,
  posts along the wall line, floor gratings, a gun ledge at y 5.9 with the guns,
  crates and barrels on and under it, lanterns.
- Sails: see the sails pass. Yards braced 24 degrees (`BRACE`), because square-on
  sails vanish from abeam.

## Where the contract shaped the look

- **Bow:** the 16 x 10 m exit at z -56.5 rules out a rounded bow above y 3. It is
  a flat beakhead bulkhead instead: lower beak and grating under y 3 out to
  z -72.5, an upper beak grating above y 14.3 out to about z -70. The upper beak
  is look only and outside `solids()`. This is the biggest loss: from far off the
  hull reads boxier than a galleon.
- **Tumblehome** survives: half beam 11 at y 4, about 10.3 at y 13, about 9.2 at
  y 24. So the poop and forecastle boxes stand up to about 2 m proud of the
  visible planks.
- **Walls:** collision is at x +-8; the visible shell is at about x 9.6 to 10.3.
  A line of posts at x 8.3 marks the real wall. Nothing stands inside x +-8, so
  the contract's 1 m allowance is unused.
- **Guns at y 8** are 5 m over the floor, hence the ledge. 2.7 m of barrel stands
  out of the hull to reach the x +-14 muzzle.
- **Six shut ports** per side (`DUMMIES`) fill the 16 m gaps. No gun behind them.
- **Masts** stop at the box tops. Tops, yards, sails and rigging are outside the
  boxes.
- No bobstay: it would cross the exit.

## Triangles (54,336)

| Node group | Triangles |
|---|---|
| Interior | 17,618 |
| Hull (with torn ends) | 12,068 |
| Upperworks | 8,496 |
| Cannons | 6,432 |
| Sails | 4,060 (2,520 before the sails pass) |
| Masts | 2,020 |
| CrackPlug_Stern | 1,666 |
| CrackPlug_Bow | 1,630 |
| Rigging | 1,056 |
| Stays | 350 |
| Bowsprit | 204 |
| PortLids | 132 |

## Geometry tricks (`docs/art/model-budget.md`)

Savings are estimates; no frame time was measured.

| Trick | Used | Estimated saving |
|---|---|---|
| Sculpt high, bake low | No. Planks are real geometry, grain and stains are painted maps | A plank-level sculpt would cost a bake pipeline for maybe 5k fewer hull triangles; not worth it |
| Import LODs | Yes (`meshes/generate_lods`); ribbon geometry decimates poorly, effect unmeasured | 30-50% at 300 m+ if it works, under 0.3 ms |
| Visibility ranges | Not in the glb, code must set them: `Rigging` end 450 m (used in the stills), `Interior` and `Cannons` hidden past about 300 m | 19k+ triangles at distance, about 0.3 ms |
| Silhouette geometry | Yes: broken mizzen, shot holes, sprung planks. (The torn sails' alpha is gone: see the sails pass) | Sails then 2.5k against about 40k cut, about 0.5 ms |
| Rigid parts on bones | Not applicable: nothing is rigged | None |
| Parallax depth | No. The splits are real gaps | None |
| Vertex-colour grime | Yes: interior light, shade, plank tints | Replaces real interior lights, about 1-2 ms while inside |

## Retuning

Edit the constants at the top of `ship_build.py`, then:

```
python3 tools/blender.py run art/blender/ship/ship_build.py
python3 tools/godot.py --headless --editor --import
```

The build reads the glb back and exits 1 if anything fails. It checks the corridor
box, the `CRACK_W` x `CRACK_H` rectangle 30 m past each end with plugs out (4 cm grace for
plank edges on the line), required nodes and muzzle positions. `--fast` halves
the textures. Ports, `SAILS`, `MASTS` and the `WOUND_*` knobs are all constants, but plank
lines must keep hitting the corridor's floor and top, so keep `KEEL_Z` and
`STRAKE` in step with `COR_FLOOR` and `COR_H`.

## Nodes as exported

Bow is Godot -Z.

- `Hull`, `Upperworks`, `Interior`, `Cannons`, `Rigging`, `Stays`, `Bowsprit`
- `CrackPlug_Stern` at (0, 8, 56.5), `CrackPlug_Bow` at (0, 8, -56.5): children
  `Shard_S..` and `Shard_B..` (numbers have gaps), origin at each shard's centre, so
  they spin about themselves, and `Cover_S`/`Cover_B`, not a shard
- `Mast_1` (fore), `Mast_2` (main), `Mast_3` (mizzen), origin at the deck
- `Sail_1a..1c`, `Sail_2a..2c`, `Sail_3a..3b` under their masts, `Sail_0a` under
  `Bowsprit`, origin at the yard
- `PortLid_L_01..06` (no `_04`: torn off), `PortLid_R_01..06`, origin at the hinge,
  already open
- Empties: `Gun_L_01..06`, `Gun_R_01..06` at muzzles (x +-15.375, y 8), -Z pointing out;
  01 is z +40, 06 is z -40. `Relic` (0, 8, 0). `CorridorStart` (0, 8, 55, the
  stern), `CorridorEnd` (0, 8, -55, the bow).

Names differ from the first brief: no `ExitPlug`, and the gray box's numbers
replaced mine.

Checked in Godot headless: clean import with 0 errors, node positions and gun
facing, all materials loading as the `.tres`.

## Unproved

- Nothing moving: no flight at speed, no thrown shards, no sway, no bob.
- Rigging flicker: judged in stills with the 450 m cut-off only, never in motion.
- Frame time and the LODs' real effect.
- PC fidelity: all stills are from the Mac at 0.8 3D scale.
- Night and other hours; `fill` values were set at the default hour only.
- Sea contact: the sea paints an aqua band and foam at the hull and shows the
  submerged hull. That is the sea shader, not the model, and I left it; any sailing
  ship will show it. Black speckle on distant water in some stills looks like the
  sea's reflection, and I did not trace it.
