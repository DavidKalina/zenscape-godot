# Ship look: concept blockout

Concept stills of a redesigned pirate ship, for picking a scheme. This is a rough
blockout, not the build: `art/blender/ship/ship_concept_build.py` writes one glb per
scheme to `scratch/ship_concept/`, and a scratch driver loaded them on the game's sea,
in its light, one at a time (Mac window, 1440x900, `--no-clouds`). The shipped
`assets/models/pirate_ship.glb` and `pirate_ship.gd` are untouched.

Stills and sheets: `ship-look-concept/`. Every image has the scheme's name burned in.

- `sheet_all_schemes.jpg`: the three schemes side by side, broadside at 300 m (top) and
  three-quarter bow at 150 m (bottom).
- `sheet_<scheme>.jpg`: broadside 300 m, three-quarter bow 150 m, three-quarter stern
  150 m, chase camera low astern, figurehead, main sails.
- `<scheme>_<view>.jpg`: each still at full size.
- `before_painted_stone.jpg`: the first palette (grey, saturated red and teal), from
  before the colour notes below.
- `before_brick_head.jpg`: tar and slate with the first, box-built head and a glyph or
  fret bands on every sail, before the last notes.

## The shape (the same in every scheme)

- **Sheer:** the rail rises from 17 m amidships to 32 m at the stern and 25 m at the
  bow (was 1.8 and 1.3 m of sheer). Decks: main 15 m, quarterdeck 22, poop 28,
  forecastle 21. Stern galleries overhang the transom above the corridor's exit.
- **Hull:** a round belly, half breadth 14.5 m at 8 m up (beam about 29 m, was
  24.75), tumblehome to about 12 at the rail. Wide over the corridor at both ends,
  fine under it. The strake lines and box edges wobble a little.
- **The head:** the bow is a carved face 29 m wide, its crown 50 m up. Its open jaws
  are the exit: the mouth is 21 x 13.2 m round the 18 x 10 corridor, and jaws, teeth
  and fangs run 13.5 m forward of the bow plate (to z -70) without entering the exit's
  rectangle. It is carved from one mass: the blocks are voxel remeshed into one skin,
  then swollen, chipped, gouged and cracked by noise, with its value in vertex colour,
  no tile grid. Heavy lidded eyes under a heavy brow, swollen cheeks, ear spools, a
  broad nose, a fan crown, uneven worn teeth and fangs (cones, not posts). Above the lip it leans out over the sea; the jaws stay square
  to the exit.
- **Rig:** masts 92, 104 and 80 m (fore, main, mizzen), nine square sails, the main
  course 47 to 53 m wide and 20 m deep, yards braced 34 degrees so the sails show
  from abeam. Pennants at every truck, an ensign aft. No bowsprit: the crown is
  where it would go, so the forestay runs to the crown.
- **Guns:** three hull guns a side at y 8 (z -32, 0, 32) and two deck guns a side on
  the main deck (z -12, 16), with the empties named for them; shut ports between.

## The schemes

All are dark brown wood with grey stone and iron, and no yellow.

1. **Tar and slate:** the darkest. Tarred near-black hull, grey stone head, grey
   canvas with dark brown glyphs, no colour at all.
2. **Umber and verdigris:** dark brown hull, brown canvas with light grey glyphs,
   a little faded teal in the frieze, the glyphs and one pennant colour.
3. **Ash and rust:** weathered grey-brown hull, ash canvas with dark glyphs, red
   only in small touches (glyph centres, pennants, the head's cheek bars).

Tar and slate reads strongest to me: the darkest, the clearest glyphs at 300 m, and
the grey head and canvas sit together.

Sails: one bold glyph each on the fore and main courses (a sun, a face), plain
bordered canvas on the rest. The glyphs hold at 300 m in all three.

## Notes the stills went through

- The first palette (grey hull with saturated teal and fire-engine red) read as toy
  paint (`before_painted_stone.jpg`). Then the direction changed to dark brown and
  grey with no yellow and minimal red; the gold-and-basalt and wildcard schemes went.
- The first head was axis-aligned boxes with a stone block grid and read as bricks
  (`before_brick_head.jpg`). It is now one crude carved mass, the teeth uneven cones,
  the straight bars gone, and the stone has no grid.
- Every sail carried a glyph or fret bands; now two do.
- The hull's values: the sun and the sky's fill lift dark albedo about two stops in
  these stills, so the tar hull still reads dark brown, not black. The build should
  set values by eye in the game.

## What the build round must change

**Collision (`pirate_ship.gd` `solids()`)**

- `beam` grows to about 14.5 (from 12.4): the hull box and the gun deck walls' outer
  faces.
- The deck boxes stop at the corridor's roof; the castles need their own: a stern
  castle box (z 30 to 61, up to y 32, galleries overhanging to z 61 above y 15) and a
  forecastle box (z -57 to -38, up to y 25).
- The head: boxes round the mouth, outside the extended exit rectangle: lower jaw
  (y -3 to 1.4, z -57 to -70), upper jaw and face (y 14.6 up to the crown, about
  y 50), cheeks (|x| 10.4 to 16). The beak boxes under the floor (`-end-8`, `-end-16`)
  already cover the lower jaw roughly.
- The plane now flies 13.5 m of jaw tunnel past the bow plate: `inside()` and the
  bow pad (`LONG*0.5+pad`) should count it as still inside, or the roof and floor
  gap checks will read the open sea there.

**The plugs**

- `CrackPlug_Bow` stays at z -56.5 and now sits at the back of the throat. Its shards
  must fly out between the teeth: upper teeth hang to y 13.4, lower teeth stand to
  y 2.6, fangs at |x| 9.3. `SHARD_ROOM` and the throw arc need checking against them.
- `Cover_B` can be the throat's dark lining.
- The stern plate stays at z 56.5; the transom is now at z 58 with galleries over it,
  so recess the transom round the plate.

**The build script's checks (`ship_build.py`)**

- The corridor check (the `CRACK_W` x `CRACK_H` rectangle 30 m past each end, 4 cm
  grace) passes on paper, but the jaws' margins are thin: about 0.4 m at the teeth and
  0.3 m at the fangs. The crude carving's displacement must stay inside them. Widen the
  mouth about 1 m for room.
- Required nodes: add `Figurehead` (and its carving); `Bowsprit` and `Sail_0a` go
  (or the check and `pirate_ship.gd`'s uses of them change).
- Muzzles: hull guns three a side (`Gun_*_01..03`), now at x +-16.25, not +-15.375.
  Add `DeckGun_*_01..02` at about x +-16.3, y 17.6.
- Sails: nine (`Sail_1a..1c`, `Sail_2a..2d`, `Sail_3a..3b`, not `2a..2c` and `0a`),
  much bigger, so `SAIL_CELL` and the cloth shader's size in vertex colour need retuning,
  and `ship_sails.gd`'s cull margin too. The glyph goes in the cloth's albedo.
- Masts are taller (to y 104); `Mast_*` origins stay at the deck.

## Geometry tricks for the build (`docs/art/model-budget.md`)

The blockout is 55k triangles, most of it the head's remeshed skin (about 30k after
a 0.3 decimate). Estimates for the build:

| Trick | Use | Estimated saving |
|---|---|---|
| Sculpt high, bake low | Yes, for the head: carve it as a field (as `giant_head_build.py` does for the giants), bake normal and AO onto a low mesh of about 8k | About 40-80k triangles against real carving, about 0.3-0.5 ms |
| Import LODs | Yes on hull, head and upperworks | 30-50% at 300 m and past |
| Visibility ranges | `Interior` and `Cannons` past 300 m as now; the head's small carving (teeth, slits) past 400 m; rigging past 450 m | About 20k triangles at range, about 0.3 ms |
| Silhouette geometry | Yes: the crown, the jaws and teeth, the sheer's rails are real outline; glyphs are paint | Glyph sails stay at a sheet each, against about 2k triangles a sail for cut-out shapes |
| Rigid parts on bones | Not applicable (unless the jaw should move) | None |
| Parallax depth | Maybe, for the head's cracks and the frieze's relief | About 5-10k triangles against modelled grooves |
| Vertex-colour grime | Yes, light: the carving's value and the crevices, as in the blockout | Replaces a second map on the head |

Rough build total: about 70k triangles (hull and upperworks 18k, interior 17.6k as
now, head 8k low plus 4k carving, guns 5k, sails 6k, masts 2k, rigging 1.5k, plugs
3.3k, flags 0.5k), against 54k today.

## Unproved

Stills only: nothing moving, no sails filling on the wind, no flight through the
jaws, PC fidelity unseen, one hour of the day.

## Rebuilding the stills

```
python3 tools/blender.py run art/blender/ship/ship_concept_build.py [-- --schemes tar_slate]
```

The driver that took the stills is in `scratch/` (uncommitted): it loads each glb at
runtime with `GLTFDocument`, swaps the materials for the ship's surface shader with a
tint, and places the camera in her frame.
