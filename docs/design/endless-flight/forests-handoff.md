# Endless flight, forests round

The ask: spruce forests in the endless land. Some areas forested, not all;
open plains stay, there are just fewer of them. The woods should be real
but easy to fly through, so they need good spacing. A mix of dense
forests, scattered groves and the occasional lone tree. Spruce only.

## Launch

- Mac: `./run-endless-flight.command [--seed=1]`
- Any: `godot --path . res://studies/endless_flight.tscn -- --no-title [flags]`
- Places on seed 1:
  - the mix from the air (woods, groves, lone trees, meadows, a river):
    `--at=-1500,-2900 --heading=0 --alt=160`
  - into the densest wood near the start, low: `--at=-704,-2700 --heading=0 --alt=8`
  - over woods by a river at cruise height: `--at=-700,-1900 --heading=0 --alt=45`
- F1's numbers now have a trees line.

## What was built

- `scripts/endless/tree_plan.gd` decides where the trees stand. Like
  `arch_plan.gd`, it is a pure function of the seed and a square of land.
  - **The mask** (`mask`) reads `LandField.shape` and the slope. It gives
    three kinds of place:
    - **dense**: a broad forest noise (1.5 km) past `DENSE_AT`;
    - **grove**: clumps (a 75 m noise) in a band under that;
    - **lone**: one big tree a slot at `LONE_P` out on the open land.
  - **The land's bias.** Gentle slopes, valley sides, river banks
    (6 to 70 m off the water) and higher ground are more wooded. The coast
    is less.
  - **None** on the beach (under 5 m over the sea), within 4 m of a river's
    water, on ground steeper than up 0.8 (thinning from 0.88), over the
    tree line (60 to 82 m over the sea), on a valley's floor, or in an
    arch's opening and its approach (the arch plan is read, cached and
    shared across workers).
  - **Meadows and flats.**
    - A 1.1 km noise marks about half the land **kept**. There every meadow
      and every flat stays open. Flat means a slope of 0.06 or less across
      64 m, the flats check's own measure, on a 16 m grid.
    - In the rest (**wild**), groves only may come onto a meadow's edges.
      The meadow's heart (over 0.75 to 0.92) stays open. Dense woods may
      cover flats that are not meadow.
    - The meadows are about two fifths of the land, and this is what makes
      the plains fewer. `--forest-meadows=0` keeps them all open.
  - **Spacing** (`area`) follows the plane, through `WorldScale`.
    - Candidates sit on a 6 m lattice, one per slot, jittered across the
      whole slot so no grid shows.
    - They are placed in the order of a hashed rank. Each one stands unless
      a tree already standing is closer than both crowns' reach plus a gap.
    - The gap is `opening(TOY_GAP 2.6)`, which is 5.2 m at plane 2 (1.2 m
      past each wingtip). It is multiplied by 1.0 to 1.5 in dense woods and
      1.5 to 3.2 in groves, and is measured where each crown is half its
      widest (`SPACE_AT 0.5`, about halfway up a spruce). Lower down the
      gaps narrow toward the skirts; higher up they open.
    - Lanes come from a 320 m noise's zero lines and are `opening(TOY_LANE 8)`
      wide (16 m). Clearings come from a 140 m noise.
    - A square is thinned with twice the reach past its edge, so
      neighbouring squares agree on their shared edge.
  - **Variety.**
    - All six spruce variants, by `HeroTrees.SPRUCE`'s weights.
    - Sizes: dense 3.0 to 4.4 times the model (13 to 19 m tall for the
      mature), groves 2.4 to 4.0, lone 3.6 to 4.6.
    - Crowns stretched 1.35 to 1.7 wide; random yaw; a tint spread.
  - **The far plan** (`far_cell`, 1 km squares) uses the same mask on a
    24 m lattice. It keeps about a quarter of the trees, each grown 1.9
    times wider and 1.25 times taller to cover for the rest. It also
    returns its grid for the forest floor.
- `scripts/endless/land_trees.gd` streams the trees in three rings.
  - **near**: the real spruce family, in the islets' pine materials
    (`SkyIslets._tree_parts`). There is one MultiMesh per 256 m block,
    variant and part, drawn while the block's middle is within 430 m.
  - **mid**: FarTrees' faceted crown (20 triangles), one MultiMesh per
    block. Each tree shows from 190 to 1500 m by its own distance
    (`shaders/endless_tree_far.gdshader` squashes it outside its band), so
    it stands inside its near tree where both draw.
  - **far**: the far plan's crowns, one MultiMesh per 1 km cell, out to
    6.2 km (fading from 5.3 km).
  - **Shadows.** The near trees' shadows are cast by the faceted crowns, as
    one shadow-only batch per block. The full crowns' shadows cost about
    6 ms a frame.
  - **The forest floor** (`shaders/endless_forest_floor.gdshader`).
    - A sheet over the land where the woods stand: needle-litter shade, so
      a wood reads as one mass from the air. It is the dense mask after
      lanes and clearings, plus 0.7 of a grove clump, softened.
    - Its grid is 16 m in the blocks and 24 m in the far cells. It is
      pulled toward the eye, more with distance, so coarser land chunks
      don't cover it.
    - It is its own transparent sheet. The ground and grass shaders are
      untouched.
  - **Building.** Blocks and far cells are planned on WorkerThreadPool tasks
    (3 at once, near blocks first, then blocks and far cells taking turns).
    They are stood on the main thread within 1.5 ms a frame. `prime`
    stands those within 420 m at the start.
  - **The flight's solid**, as the arches do it.
    - `ground(p, under)` raises the land under the plane to a tree's
      cone: from its crown's foot to its top, its reach the crown's ×
      `CROWN_SOLID` 0.85, plus `WING_SOLID` 0.5 of the plane's half span.
      Trees are looked up in 16 m buckets.
    - SkyGlide treats a tree like the arches' legs: flown into, the side
      turns the plane aside; from above, it rides over the top.
    - `inside(p)` is for the rolling plane.
  - **Colliders.** Plan cells (128 m) within 70 m of the plane each stand
    a StaticBody3D on layer 1. Each tree gets a convex "spinning top":
    trunk foot, crown ring, top. One cell a frame, about 1 ms.
- `studies/endless_flight.gd` (small edits):
  - builds, primes and steps the trees;
  - `plane_ground` goes through `trees.ground`;
  - the hand landing's `blocked` checks the trees too;
  - the HUD has a trees line.

## Flags

| Flag | What it does |
|---|---|
| `--no-trees` | No trees. |
| `--forest=X` | The woods' share. Default 1; 0 none. It shifts the forest noise. On seed 1, the dense / grove-zone share of land is 11.5 / 13.4 % at 0.5, 23.6 / 11.3 at 1, 29.4 / 8.4 at 1.5 and 31.0 / 7.1 at 2. Over about 1.5 the meadows and flats cap it. |
| `--forest-meadows=X` | How far the woods come onto the meadows. Default 1. 0 keeps every meadow and every flat open; over 1 makes more of the land wild. |
| `--no-forest-floor` | No shade sheet under the woods. |
| `--no-tree-shadows` | Trees cast no shadows. |

The knobs are at the top of `tree_plan.gd` and `land_trees.gd`.

## Numbers (this Mac)

**Share.** Seeds 1, 3, 7 and 42, an 8 km square each, measured by
`scratch/forest/map.gd`:

- **Dense woods:** 20 to 24 % of the land, about 42 trees a hectare in
  them.
- **Grove zone:** 11 to 13 %, about 15 trees a hectare across it.
- **Open:** 65 to 68 %. This includes the kept meadows and flats, the high
  ground, the beaches and the rivers.
- **Lone trees:** 41 to 65 per seed, about 1 to 1.6 a km².
- **Overall:** 12 to 14 trees a hectare of land, 49k to 55k a seed.

**The flats check.** This is the earlier rounds' check, with every tree's
crown plus 4 m counted as not flat. Blocks are 256 m; a strip is 192 m.

| seed | strips % of land, before / after | blocks > 400 m from a strip | blocks > 600 m | worst block |
|---|---|---|---|---|
| 1 | 22.7 / 20.6 | 17 / 21 | 2 / 2 | 916 m / 916 m |
| 3 | 17.9 / 16.2 | 26 / 27 | 6 / 6 | 1280 / 1280 |
| 7 | 22.0 / 19.9 | 26 / 29 | 5 / 5 | 802 / 802 |
| 42 | 25.1 / 22.9 | 15 / 19 | 2 / 4 | 1664 / 1664 |

That is about 600 blocks a seed. No worst block moved. The two new
far-off blocks on seed 42 are on the square's edge, where strips are cut
off. Before the "kept flats" rule, the woods took more of the flats
(seed 3 went from 6 to 10 blocks over 600 m). That rule is what holds it.

**Flying through** (`scratch/forest/fly.gd`, real stick input through the
play loop):

- The corridor is 60 × 300 m through seed 1's densest wood near the start:
  48 trees a hectare in its densest cell, 38 across the corridor.
- **At 5 m over the ground:**
  - 16.6 % of the corridor is inside a tree's solid;
  - a line exists, with 1.8 m to spare past the solid at its narrowest;
  - flown, the plane got through with no tree touched.
- **At 8 m:** 11.7 % is solid, 3.0 m to spare, flown clean.
- **Straight down the corridor at 5 m:** the plane brushed trees for 124
  frames and was turned aside each time. Collision works where it should.
- **Colliders:** 38 rays out of 38 at the trees within 50 m of the plane
  hit their colliders (`scratch/forest/rays.gd`).

**Frame time.** Rendered, `--uncapped`, 1500 frames after a 900-frame
settle (`scratch/forest/perf.gd`):

- **From 160 m up, looking over woods:**
  - 22.7 and 22.0 ms with trees, against 18.1 and 18.6 ms with
    `--no-trees`, so about +4 ms;
  - `--no-forest-floor` gave 21.0 ms, so the floor costs about 1.2 ms;
  - `--no-tree-shadows` gave 20.3 ms, so the proxy shadows cost about
    1.8 ms;
  - about 14k near and mid trees and 22k far crowns were standing.
- **At cruise over the woods (no clouds):** 17.75 ms with trees against
  19.2 ms without, the same within noise. The two runs flew slightly
  different paths, because the trees turn the plane.
  - Before the shadows moved to the proxies, this view cost +4.8 ms
    (24.0 ms).

**Building:**

- Single-threaded, a block plans in about 25 ms (+2 ms for its floor)
  and a far cell in about 30 ms. In flight, with the land and grass
  tasks running too, the average is 50 to 95 ms (slowest about 300 ms).
- Standing one takes 0.2 to 2.7 ms. A single 14 ms stand was seen once and
  not reproduced.
- The start is about 0.5 s slower because of `prime`.

## Stills

- `scratch/forest/forests_sheet.png` (in this worktree). Top: from 160 m,
  with and without trees. Bottom left: low inside the dense wood.
  Bottom right: cruise height by a river.
- `scratch/forest/high_eye.png` and `high_notrees_eye.png`: the mix from
  the air.
- `scratch/forest/fly_sheet.png`: four stills from the flight through the
  dense wood.
- `scratch/forest/cruise4_play.png`: cruise height.
- `scratch/forest/map_1_1.0.png`: seed 1's 8 km map. Dense woods are dark
  green, grove zones light green, lone trees red, landing strips yellow.

## Not verified

- **How it feels by hand:** threading the woods, and how hard the gaps are
  at speed.
- **The chase camera** doesn't keep out of the crowns: flying low, it
  passes through needles. `_solid` and `_sight` don't count trees, to keep
  `endless_flight.gd`'s edits small. `trees.inside` would do it.
- **A plane held against a trunk** by the stick brushes along it and
  stays there until steered off. This is SkyGlide's brush, as at the
  arches.
- **The ring hand-overs from the air in motion:** mid to far at 1.4 km,
  the fade at 5.3 to 6.2 km, and the near crowns' block-wise drop at
  430 m. They read fine in the stills.
- **GPU time alone.** Metal reports no GPU timer.
- **Windows** and other GPUs.
- **The walker:** there is no walking in endless flight yet. The layer-1
  colliders exist, are hit by rays, and stand only round the plane.
- **Landing.** A meadow's edge can have groves (wild meadows). The landing
  roll stops at a trunk (`blocked`) but was not driven.
- **The look under other moods and hours.** The far crowns' colour
  (`FAR_ALBEDO`) and the floor's (`FLOOR_COLOUR`) were matched by eye in
  the default morning.
- **Handles.** Trees are scatter, like the grass, so they have no
  `LayoutOverrides` names.
- **The flats check's crowns.** It uses one generic crown size, not each
  variant's own.

## Model budget

No new model. The round reuses the spruce family (about 230 triangles a
tree) and FarTrees' faceted crown.

- **Import LODs / visibility ranges:** apply, and are what is used.
  - The near ring is the full tree to 430 m.
  - Past that, the 20-triangle crown, about 1/11 of the faces.
  - Past 1.4 km, a quarter of the trees, grown to cover.
  - Shadows come from the 20-triangle crowns, which saved about 6 ms over
    casting them from the full crowns.
- **Silhouette geometry, vertex-colour grime:** the spruce meshes carry
  them already. Nothing to add.
- **Sculpt high and bake low, parallax depth, rigid parts on bones:** do
  not apply.

## Tests this breaks

None known. No test covers the endless scripts. The one shared script
used, `far_trees.gd` (`proxy`), is unchanged; a new cache key only. The
full suite was not run.

## Next cues

- The grass and ground shaders could take a forest-floor input from
  `TreePlan.floor_weight`. That would replace the transparent sheet,
  saving about 1.2 ms from the air.
- The camera keeping out of the crowns (`trees.inside` in `_solid` and
  `_sight`).
- If the woods feel too open or too tight by hand:
  - `TOY_GAP`, `GAP_DENSE`, `SPACE_AT` (where the gap is measured);
  - `WIDE_DENSE` and `SIZE_DENSE`;
  - `CROWN_SOLID` and `WING_SOLID` (how forgiving the needles are).
