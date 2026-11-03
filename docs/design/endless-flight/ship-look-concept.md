# Ship look: concept blockout

Concept stills of a redesigned pirate ship, for picking a look. This is a rough
blockout, not the build: `art/blender/ship/ship_concept_build.py` writes one glb per
scheme to `scratch/ship_concept/`, and a scratch driver loaded them on the game's sea,
in its light (Mac window, 1440x900, `--no-clouds`, the sun on her starboard bow). The
shipped `assets/models/pirate_ship.glb` and `pirate_ship.gd` are untouched.

Stills and sheets: `ship-look-concept/` (force-added past the docs image ignore, as
`pirate-ship-stills/` is, with a `.gdignore`). Every image has its scheme burned in.

- `sheet_all_schemes.jpg`: the three schemes side by side; broadside at 300 m,
  three-quarter bow at 150 m, chase camera low astern.
- `sheet_<scheme>.jpg`: those three, the three-quarter stern, the bow close and the
  fore course close.
- `glyph_options.jpg`: the fore course in tar and slate with each glyph option: wind
  spiral, serpent, sun with curved rays.
- `<scheme>_<view>.jpg`: each still at full size.
- Earlier passes, for the record: `before_painted_stone.jpg` (the first palette),
  `before_brick_head.jpg` (the box-built head, a glyph on every sail),
  `parked_head.jpg` (the crude carved head, now parked).

## The shape (the same in every scheme)

- **Sheer:** the rail rises from 17 m amidships to 32 m at the stern and 25 m at the
  bow (was 1.8 and 1.3 m of sheer). Decks: main 15 m, quarterdeck 22, poop 28,
  forecastle 21.
- **Hull:** half breadth 14.5 m at 8 m up (beam about 29, was 24.75), a round turn
  of the bilge, tumblehome to 11.8 at 17 m and 9.2 at 32 m. The plan narrows all along
  (no parallel middle body), and the keel rises toward both ends. Strake lines and
  upperworks edges wobble a little, and upperworks corners are beveled.
- **Stern:** raked. Above 14 m the counter and galleries lean out aft (about 0.32 m a
  metre up), and below 2.6 m the sternpost tucks forward. Between them, round the exit,
  the transom stays upright at z 58.
- **Bow:** no figurehead. The prow closes to a raked stem (z -72.7 at 2.6 m up,
  -75.3 at 13.4, -78 at the rail). The exit is cut through it: the corridor runs on
  past the bow plate (z -57) in a short tunnel lined in dark wood, walls at x +-10.4,
  floor 2.6, ceiling 13.4. It comes out where the prow's sides close in to x +-10.4,
  at z -60.5 to -62.6. Over the opening the prow overhangs to the stem as an upper
  lip, and under it the forefoot runs on as a lower lip. Timbers frame the cut, with
  a stone boss at the stem's head. Catheads, a bowsprit to z -100 and a jib.
- **The head:** parked behind `--head` (off). The carved face with its jaws round the
  exit is still in the script (`head`, `crude`, `figurehead`).
- **Rig:** masts 92, 104 and 80 m (fore, main, mizzen), nine square sails, the main
  course 47 to 53 m wide and 20 m deep, yards braced 34 degrees so the sails show from
  abeam, with more belly than before (the build's cloth shader fills them on the wind).
  Pennants at every truck, an ensign aft.
- **Guns:** three hull guns a side at y 8 (z -32, 0, 32) and two deck guns a side on
  the main deck (z -12, 16), with the empties named for them; shut ports between.

## The schemes

All are dark brown wood with grey stone and iron, and no yellow.

1. **Tar and slate:** the lead. Near-black tarred hull, blue-grey canvas with
   near-black glyphs, no colour at all.
2. **Umber and verdigris:** dark brown hull, brown canvas with light grey glyphs, a
   little faded teal in the frieze, the glyphs and one pennant colour.
3. **Ash and rust:** weathered grey-brown hull, grey canvas with dark glyphs, red only
   in small touches (glyph centres, pennants).

Sails: two glyphs, on the fore course (the option) and the main course (the sun with
curved rays); plain bordered canvas on the rest. Each glyph keeps its own aspect,
centred, whatever the sail's shape. They are brush-painted strokes, uneven and
worn into the canvas. The fore course's options build with
`--fore spiral|serpent|sun`.

## Notes the stills went through

- The first palette (grey with saturated teal and fire-engine red) read as toy paint.
  Then the direction changed to dark brown and grey with no yellow and minimal red.
- The first head read as bricks. A crude carved one replaced it, and then the head
  was parked: the user has no vision for it yet.
- Sails went from a glyph or fret bands on every sail to two glyphs. The first glyphs
  were stretched to the sail, and the box face read as an emoji; now they are round
  brush forms at their own aspect.
- Boxy: the flat stem and transom, the squared bow and the constant-section hull gave
  way to the raked ends, the pointed prow with the cut, the rounder section and the
  rising keel.
- Values: the sun and the sky's fill lift dark albedo about two stops, so the tar
  hull reads dark brown, not black. Grey canvas warms toward beige in direct sun, which
  is why it was cooled to blue-grey. The build should set values by eye in the game.
- The chase view looks into the shade with the sun on the bow quarter, so her stern
  reads near black there.

## What the build round must change

**Collision (`pirate_ship.gd` `solids()`)**

- `beam` grows to about 14.5 (from 12.4), tapering toward the ends.
- Castles: a stern castle box (z 30 to 58, up to y 32) and the raked counter's
  overhang above y 14 (out to about z 64 at the top). A forecastle box (z -57 to -40,
  up to y 25).
- The prow: past the bow plate, the tunnel walls (|x| 10.4 and out, y 2.6 to 13.4, z
  -57 to about -62); the lower lip and forefoot under y 2.6 out to the stem (about
  z -73); the upper lip over y 13.4 out to the stem (about z -75 to -78), narrowing as
  it goes. The old beak boxes (`-end-8`, `-end-16`) give way to these.
- The sternpost tucks forward under y 2.6: the stern's hull box can come in a little
  there.
- The plane flies about 4 to 6 m of tunnel past the bow plate, then 13 to 18 m under
  the upper lip. `inside()` and the bow pad (`LONG*0.5+pad`) should count the tunnel
  as inside. Under the lip the roof gap check reads the lip, not open sky.

**The plugs**

- `CrackPlug_Bow` stays at z -56.5, now at the back of a short tunnel. Its shards fly
  out down the tunnel and under the lip, so the throw arc must clear a roof at
  y 13.4 for about 20 m. `Cover_B` can be the tunnel's dark lining.
- `CrackPlug_Stern` stays at z 56.5, under the counter's overhang.

**The build script's checks (`ship_build.py`)**

- The corridor check (the `CRACK_W` x `CRACK_H` rectangle 30 m past each end, 4 cm
  grace) now runs through the prow's tunnel and under its lips. The margins are 0.4 m
  at the lips (y 2.6 and 13.4 against 3 and 13) and 1.4 m at the walls. The framing
  timbers sit just outside the lips. Keep `KEEL_Z`/`STRAKE` lines on 2.6 and 13.4 so
  the cut has clean edges.
- Nodes: `Bowsprit` and `Sail_0a` (the jib) stay. With the head parked there is no
  `Figurehead`. Square sails are `Sail_1a..1c`, `Sail_2a..2d`, `Sail_3a..3b` (the
  main gets a fourth). Add the `DeckGun_*_01..02` empties at about x +-16.3, y 17.6.
- Muzzles: hull guns three a side (`Gun_*_01..03`), now at x +-16.25, not +-15.375.
- Sails: much bigger, so `SAIL_CELL`, the cloth shader's size in vertex colour and
  `ship_sails.gd`'s cull margin need retuning. The glyph goes in the cloth's albedo at
  the sail's aspect.
- Masts are taller (to y 104); `Mast_*` origins stay at the deck.

## Geometry tricks for the build (`docs/art/model-budget.md`)

The blockout is 42k triangles. Estimates for the build:

| Trick | Use | Estimated saving |
|---|---|---|
| Sculpt high, bake low | Not now; for the head if it comes back (a field as `giant_head_build.py` carves the giants, baked onto about 8k) | None now; about 40-80k triangles then |
| Import LODs | Yes on hull, upperworks and prow | 30-50% at 300 m and past |
| Visibility ranges | `Interior` and `Cannons` past 300 m as now; the prow's framing timbers and the tunnel lining past 400 m; rigging past 450 m | About 20k triangles at range, about 0.3 ms |
| Silhouette geometry | Yes: the raked ends, the prow's lips and the rails are real outline; glyphs are paint | Glyph sails stay at a sheet each, against about 2k triangles a sail for cut-out shapes |
| Rigid parts on bones | Not applicable | None |
| Parallax depth | Maybe, for the frieze's relief | About 2-4k triangles against modelled frets |
| Vertex-colour grime | Yes, light: value variation and crevices | Replaces a second map on hull and stone |

Rough build total: about 60k triangles (hull and upperworks 20k, interior 17.6k as
now, prow and tunnel 2k, guns 5k, sails 6k, masts 2k, rigging 1.5k, plugs 3.3k, flags
0.5k), against 54k today.

## Unproved

Stills only: nothing moving, no sails filling on the wind, no flight through the
prow, PC fidelity unseen, one hour of the day. The prow's lip timbers were nudged
0.6 m clear of the exit after the stills were taken (not visible at these ranges).

## Rebuilding the stills

```
python3 tools/blender.py run art/blender/ship/ship_concept_build.py [-- --schemes tar_slate] [--fore serpent] [--head]
```

The driver that took the stills is in `scratch/` (uncommitted). It loads each glb at
runtime with `GLTFDocument`, swaps the materials for a copy of the ship's surface
shader with a tint (and vertex colour), and places the camera in her frame.
