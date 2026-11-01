# Pirate ship model: handoff

Scripted Blender build of the pirate ship, retuned to "Contract for the model"
in the gray box's `pirate-ship-handoff.md`. Not wired into the world.

Stills, in the game's sea and light (rendered on the Mac):
`docs/design/endless-flight/pirate-ship-stills/`.

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
- Both ends: a dark jagged split with pale torn plank ends and sprung planks,
  drawn by `SPLIT`. Same drawing at each end.
- Gun deck: dark by baked vertex colours, pooling at the ports. Ribs, beams,
  posts along the wall line, floor gratings, a gun ledge at y 5.9 with the guns,
  crates and barrels on and under it, unlit lanterns.
- Sails: alpha cut-out torn cloth, four atlas cells. Yards braced 24 degrees
  (`BRACE`), because square-on sails vanish from abeam.

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
| Hull (with torn ends) | 12,212 |
| Upperworks | 8,496 |
| Cannons | 6,432 |
| Sails | 2,520 |
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
| Silhouette geometry | Yes: torn sails by alpha rather than cut mesh; broken mizzen, shot holes, sprung planks | Sails 2.5k against about 40k cut, about 0.5 ms |
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
box, the 16 x 10 m rectangle 30 m past each end with plugs out (4 cm grace for
plank edges on the line), required nodes and muzzle positions. `--fast` halves
the textures. Ports, `SAILS`, `MASTS` and `SPLIT` are all constants, but plank
lines must keep hitting the corridor's floor and top, so keep `KEEL_Z` and
`STRAKE` in step with `COR_FLOOR` and `COR_H`.

## Nodes as exported

Bow is Godot -Z.

- `Hull`, `Upperworks`, `Interior`, `Cannons`, `Rigging`, `Stays`, `Bowsprit`
- `CrackPlug_Stern` at (0, 8, 56.5), `CrackPlug_Bow` at (0, 8, -56.5): 12 children
  each, `Shard_S01..12` and `Shard_B01..12`, origin at each shard's centre, so they
  spin about themselves
- `Mast_1` (fore), `Mast_2` (main), `Mast_3` (mizzen), origin at the deck
- `Sail_1a..1c`, `Sail_2a..2c`, `Sail_3a..3b` under their masts, `Sail_0a` under
  `Bowsprit`, origin at the yard
- `PortLid_L_01..06` (no `_04`: torn off), `PortLid_R_01..06`, origin at the hinge,
  already open
- Empties: `Gun_L_01..06`, `Gun_R_01..06` at muzzles (x +-14, y 8), -Z pointing out;
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
