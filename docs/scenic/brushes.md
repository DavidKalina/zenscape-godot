# Creation brushes: meadow, forest and path

Phase 3, slice 4 (`feature/land-brushes`). The brushes write intent, and the
world picks the details. None of them places a plant under the pointer.

## In hand

`scripts/genesis_canvas.gd` keeps the ordered brush list (`BRUSHES`): one
entry per brush with its `brush_id`, palette `title`, how-to `hint` and
`script`. The keys are 1 land, 2 water (slice 2), 3 meadow, 4 forest and 5
path; the creation shell (`studies/cozy_worlds.gd`, `_creation_key`) is the one
handler for them, and the palette (`scripts/creation_palette.gd`) shows the same
list. The editor's `"land"` tool paints with whichever brush is in hand, water
included: `NativeChunkEditor.brush_id`, `select_brush(id)`, `held_brush()`,
and the `brush_changed` signal for a shell to follow. Stroke signals carry the
brush id as their mode.

- **1 again** with land in hand steps through its forms (Hill, Alpine,
  Ridge, Mesa, Volcano, Tors); **Shift+1** steps back. See "Mountain forms".
- **Drag** paints. **Shift-drag** works the other way: land lowers, a meadow
  lifts, forest clears, and a path grows back. Right drags belong to the
  camera in the creation shell ([camera](camera.md));
  `NativeChunkEditor.right_works_other_way` keeps the old right-drag lowering
  for the classic build.
- **`[ ]`** sets the size of the brush in hand, and **Shift+`[ ]`** sets its
  strength. Land keeps `land_radius` and `land_strength` as editor settings.
  The others, water included, keep `radius` and `strength` on the brush and
  report changes as `setting_changed("brush_radius" | "brush_strength", value)`.
  `NativeChunkEditor.brush_setting(id, "size" | "strength")` gives a shell the
  value and range for its meters.

Each brush is its own script and extends `scripts/creation_brush.gd`. That
script documents the interface the editor drives: `activate`, `deactivate`,
`prepare`, `begin`, `dab`, and `finish`, which returns the rect that emergence
should answer. The water brush extends it too, as a **settling** brush
(`settles = true`): its dabs only record, the editor opens no undo step while
it is held, and the pour is planned and applied after release
(`docs/scenic/water-brush.md`).

## Provenance

| Brush | Cover cells | Objects |
|---|---|---|
| Meadow | Marked hand. Emergence never thins or plants in them, so a meadow painted inside a forest stays an open glade. | Untouched. |
| Path | Marked hand, tread and margin. Nothing emerges on a path. | At release, clears emerged records from the tread, plus generated undergrowth (`PathBrush.UNDERGROWTH`). Lays stones, which are tagged hand like every record minted in a stroke. |
| Forest | Left as they are, so emergence can plant. The floor tint skips hand cells. | A clearing stroke withdraws emerged plants where it left the wish at `CLEAR_BELOW` or lower. A firm pass takes its cells there at release (`FIRM_PASS`). |

Hand-placed and pinned records are never removed. Generated trees and rocks
stay on a path too.

## Forest

`scripts/forest_brush.gd` writes the **forest wish** in `scripts/land_intent.gd`.
This is one float per cover cell, from -1 (keep clear) through 0 (the biome
decides) to 1 (the heart of a forest). It rides the undo history through
`history_captured` and `state_restored`, the same way the fire field does, so
one undo removes the wish and its painted floor together.

The wish is saved with the place, so a stroke after a load still honours it
(a clearing stays clear, a forest keeps its core and frayed edge).
`NativeTerrainData.to_document` emits `document_captured`, and the intent adds
an optional `intent_forest` field whenever any cell carries a wish:
`{"cells": 3136, "deflate": <base64 of the deflated float32 cells>}`.
`load_document` checks it (cell count, finite values in -1..1) and hands it
back through `state_restored`. The document version stays 10; saves without
the field load with no wish anywhere, and a malformed field fails the load
like any other bad field.

When the stroke is released, its bounds go to emergence as a `"forest"`
region. A forest region:

- plans only candidates whose frayed wish is above the margin;
- leaves cover alone;
- does not replan other strokes' pending work. A candidate that is planned
  twice lands once, because the crowding check stops the second.

A later land stroke replans its ground as usual and still honours the wish,
taking the higher of the biome's chance and the wish's chance.

At arrival (`emergence.gd`, `_arrive` and `_frayed`):

- **Frayed wish.** This is the wish, plus a per-candidate scatter
  (`FOREST_RAGGED`), plus slow lobes (`FOREST_LOBES` at
  `FOREST_LOBE_FREQUENCY`). The outline comes out ragged, and its edge trees
  stand apart.
- **Trees.** The chance runs from `FOREST_EDGE_CHANCE` at `FOREST_EDGE.x` up to
  `FOREST_CORE_CHANCE` at `FOREST_EDGE.y`. It is zero below the edge.
- **Shrubs.** `FOREST_MARGIN_SHRUBS` applies in the margin band, `FOREST_MARGIN`
  (the rising edge `.x`–`.y`, the falling edge `.z`–`.w`).
  `FOREST_UNDER_SHRUBS` applies under the canopy. A meadow habitat takes
  woodland undergrowth (fern, shrub, tuft, mushroom).
- **The unchanged rules still apply.** Nothing grows on water, bare rock or
  snow, or above the treeline. Trees thin as the slope climbs from 0.45 to
  `rock_slope`. Crowding gaps apply.
- **A negative wish** scales both chances by `1 + wish`.
- **Timing.** Where the wish is above 0.05, shrubs arrive at
  `FOREST_SHRUB_DELAY` + `FOREST_SHRUB_SPREAD`·(0.6·(1−wish)+0.4·hash), and trees
  at `FOREST_TREE_DELAY` + `FOREST_TREE_SPREAD`·(…). With the defaults that is
  9–23 s for shrubs and 5–23 s for trees, core first. Trees claim the ground
  before the undergrowth crowds it. Each arrival grows in at its own birth, as
  before.
- **Defaults:** edge chance 0.1, core chance 0.9, edge band 0.1–0.6. Scatter
  0.45 and lobes 0.35 at 0.28 /m. Margin shrubs 0.45, under-canopy shrubs 0.12.

| Tunable (`forest_brush.gd`) | Default | Meaning |
|---|---|---|
| `RATE` | 2.2 | Wish per second at the centre, at strength 1. The falloff is `(1−t²)^1.5`. |
| `FLOOR_WEIGHT` | 0.42 | Weight of the darker forest-floor tint at a full wish. |
| `FLOOR_SHIFT` | (0.015, −0.04, −0.07) | Hue, saturation and lightness shift from the palette's darkest grass. |
| `CLEAR_BELOW` | −0.25 | A clearing stroke withdraws emerged plants at or below this wish. |
| `FIRM_PASS`, `FIRM_MIN`, `FIRM_EMPTY` | 0.7, 0.3, 0.1 | A firm clearing pass. A cell the stroke pushed down by `FIRM_PASS` of wish (the sum of its dabs, before clamping), or by `FIRM_MIN` that left it at `FIRM_EMPTY` or less, drops to `CLEAR_BELOW` at release, so one deliberate Shift pass clears a young forest. A steady pass at strength 1 pushes about 1 at its centre; a light pass only thins the wish. |
| `radius` | 3.6 (1.5–9) | Brush radius in metres. |

## Pollen

`feature/seed-handful`, 2026-09-27. Forest is a veil of pollen and seed-fluff, swept into the air and let go: **you release something; the world decides what becomes of it** (`docs/scenic/handful.md`). Three earlier tries were turned down the same day: a gathered handful of winged seeds, a seed sprinkle that poured while the button was down, and a single released cloud that a drag only moved (all in the branch history). Of the sprinkle the user said: "I just don't like it as a paintbrush." Of the cloud, they asked for this instead: "you kind of drag around and then you release a bunch of pollen that starts in the air, and then that area that you dragged descends from the air, and then the wind kind of arranges it." `--paint-forest` brings back drag-to-paint (`NativeChunkEditor.seed_handful`), and Shift-drag still clears as before.

- **The sweep** (`scripts/pollen_cloud.gd`). With forest in hand, holding the button lays pollen in the air `HEIGHT` (2.2 m) up along the pointer's way. A line, a curve or a loop round an area can be swept. Nothing lands while it is held, and nothing is written.
  - The veil's head follows the pointer on a soft spring (`FOLLOW` 30, `FOLLOW_DAMP` 9). Knots are laid along the head's way every `KNOT_STEP` (0.45 m × brush size), never off the land. New motes start at the head and ease into their place (`SETTLE_RATE` 3.5/s), so the veil trails the pointer a little and settles as it is laid.
  - Each knot holds `KNOT_MOTES` (16) motes within its half-width `r` (`CLOUD` 0.6 m, up to 1.3 m thickened). A click lays one knot of `MOTES.x` (120) motes, a small puff. As a sweep goes on, the first knot's extra motes stream out along it.
  - Holding still (head slower than `STILL`, 0.5 m/s) thickens the knot under the head over `HOLD_SECONDS` (1.4 s at strength 1): up to `MOTES.y` (260) motes and 1.3 m wide.
  - Counts scale by √strength × brush size² (radius / 3.6 m, kept within `SIZE` 0.6–1.6). A veil holds at most `VEIL_MOTES` (560) at size 1. At the cap, the part of the veil densest for what it wants gives motes up to the new part, so a long sweep thins out rather than growing. Past `KNOTS` (64) knots, they merge in pairs, each kept knot widening to cover its partner's motes.
  - While held, the motes churn slowly round their knot and billow, and a ripple runs along the veil (`BOB`, `BILLOW`).
  - Up to `CLOUDS` (4) veils may be in the air at once. Pressing any other brush settles them first; the wind tool does not.
- **The look.** Glinting motes of fluff (tiny faceted specks that twinkle, glowing a little) under a soft additive haze (`shaders/pollen_haze.gdshader`): 8 puffs round a click's middle, or up to `HAZE_VEIL` (12) spaced along a sweep. The haze thins as the veil spreads and settles. The colour follows the dominant tree of the stand under the press (`Emergence.seed_family`, `LOOKS`): pine gold, broadleaf cream, birch pale, desert dust.
- **Release.** The whole veil goes together.
  - It takes a breath first: over `LIFT` (0.4 s) it lifts `LIFT_HEIGHT` (0.22 m) and gathers in by `GATHER` (12 %) of its width.
  - Then it sinks as one sheet, peeling down from where it was let go back to where the sweep began, over up to `WAVE` (0.6 s; the whole of it for sweeps of `WAVE_LENGTH` 8 m or more). Each mote starts within `JITTER` (0.3 s) of its part.
  - Each mote falls for 3.2–5.2 s (`FALL`), the lightest the longest. It sinks softly, then steadily, and lands gently. It drifts apart from the others early, to a spread `sigma` (a puff 1.8 m, thickened 2.8 m; a sweep of `SWEEP` 2 m or more `VEIL_SPREAD` 0.7 m, so it comes down close to its shape). It wanders `WANDER` (0.35 m) on the curl of the air. Near the ground it looks ahead to where it will land.
- **Drift** (`scripts/pollen_wind.gd` `at()`, the one place pollen asks the wind). The wind is read every frame at up to `GROUPS` (8) places along the veil, one per `KNOT_GROUP` (6) knots, and each part rides its own drift. So a gust pushes only the part it passes.
  - The world's wind: the atmosphere's strength (air strength + swell, times the gust envelope `gust_at`) and its direction, and the gust parcels it has sent, through `wind_puffs.gd` `sample_at`, the CPU mirror of `zs_gust_pulse_at`. The noise field is taken at its mean. Drift is `DRIFT` (1.4 m/s) × strength × (0.45 + 1.1 × min(1, 0.5 + pulse)), so still air gives no drift.
  - The wind tool: `WindGust.wind_at` (`scripts/wind_gust.gd`, through the editor's `gust` node) at `GUST_CARRY` (0.25) of its speed. At its full speed (8–22 m/s at the head) one swipe threw a veil 12 m and 160 of 248 motes off the land.
- **The promise.** A soft footprint (`shaders/pollen_footprint.gdshader`) shows where the veil will settle.
  - While aiming it shows a click's puff under the pointer. While sweeping it follows the swept shape, shifted and stretched downwind by the wind as it blows now. After release it moves with the veil until it has settled.
  - It is the union of one capsule per knot (up to 64 in the shader). Each capsule has radius r + sigma and runs from the knot plus its part's drift so far, carried on by that part's present wind for the least and the most time its motes have left in the air. It is round and right under the sweep in still air.
  - A mote lands at its knot, plus its place in the veil (within r), plus its spread (within sigma), plus its part's drift by then. So every mote lands inside the footprint as it stands when that mote lands. In steady air that is the footprint shown at release. A gust moves the part it passes, and its footprint, downwind.
  - It is drawn like the water ball's mark (a slowly turning 12-sided pooled shadow in two tones with a rim, faceted round the nearest capsule), but softer and lighter, with a warm rim and faint twinkling specks. The terrain's brush ring hides while pollen is in hand.
- **Land.** A landed mote glints for `GLINT` (0.8 s). A mote at least `SEED_GAP` (1.1 m, Emergence TREE_GAP) from the veil's other seeds is a seed; the rest is dust. Where a seed lands on ground that could take it (`Emergence.takes`: ground, no water, not a path, below the rock slope, the snow and the treeline), a two-leafed sprout pops up and sinks after 9 s. Motes that drift off the land are lost.
- **The land decides.** When a veil's last mote is down (`_pollen_settled`, `_write_cloud`), its seeds raise the forest wish round them (`ForestBrush.sow`: up to `SEED_WISH` 0.45 over `SEED_REACH` 1.6 m) and darken the floor, as one undo step. The seeds then go to emergence as a `"forest"` region.
  - Each seed is a tree candidate at its point. It comes up first, at `SOWN_DELAY` (1.2 s) + up to `SOWN_STAGGER` (2 s), and takes at `SOWN_TAKE` (0.9) × `_fertility`.
  - `_fertility` is the habitat's share (`SOWN_FERTILITY`: woodland and redwood 1, wetland 0.8, alpine and meadow 0.75, arid 0.3). It is leaned down on dry ground (to `SOWN_DRY` 0.75 at no moisture; moisture is the blend's, which water nearby raises) and on exposed heights (to `SOWN_EXPOSED` 0.65 at the top of the altitude range).
  - The ordinary rules refuse water, bare rock, snow and above the treeline, thin trees on steep ground, and crowd seeds out of existing forest.
  - The region's lattice candidates follow by distance from the nearest seed (`SOWN_TREE_DELAY` 4 s, `SOWN_SHRUB_DELAY` 7 s, `SOWN_SPREAD` 0.4 m/s, `SOWN_JITTER` 5 s). Their trees take at the fertility too. Only ground the seeds wished for grows, so a loop grows a ring, not a filled disc.
  - Species come by stand (scripts/tree_stands.gd), and sown trees never come up as dead wood. `Emergence.sown_outcomes` tallies what became of every seed, by habitat.
- **Undo.** One sweep is one undo step, written when the veil settles. An undo while veils are in the air settles them, oldest first, and takes back the last. An undo, a load or a new world clears sprouts and veils (`withdraw`). No stroke signals start while a veil is held: the forest brush's feel would swell the very wind the veil drifts on. The settled veil reports `stroke_finished`.
- **The settle flicker, fixed.** The user saw "an entire forest drawn for a split second" as a cloud settled. The settle's refresh (`NativeChunkEditor.refresh` with a frame tree) restored the source chunk's own plants to visible in `_lift_anchors`, then yielded on its 2 ms budget before `sync_visibility` hid them again on the blank plate. So one frame drew the source chunk's whole forest: about 5,400 instances over 14 MultiMeshes (`Reference/mesh-8` … `flower-stems`). `sync_visibility` now runs in the same frame. The same probe also caught pond reflection copies (`scripts/planar_water.gd` `_copy_visual`) starting visible when their source was hidden; they now start as visible as their source.
- **Other kinds later.** A meadow's seed would be another veil, lighter and further-drifting, whose settle writes meadow ground.

`tools/probe_seed_handful.gd` drives the real input path on the Genesis plain (press, the pointer swept along a path while the editor's own `_process` lays the veil, release), with the wind set on the scene's atmosphere. It checks each landing against the footprint as it stood when the mote landed, and against the footprint shown at release. It compares what grew with the swept path (shifted by the veil's mean drift): trees within the footprint's radius + 1.6 m of it, and metres of path with a tree within 2.5 m. The flicker check counts every MultiMesh's visible instances every frame from the aim to the end of growth, and fails any node whose count jumps by 20 or more and drops back within three frames. With the refresh fix reverted, it fails the straight sweep on `Reference/mesh-8` and 13 more (0 → 103 → 0 and so on). Headless (`--headless --script tools/probe_seed_handful.gd`, `-- --only=<label part>` for some releases), one run:

| Release | Held (s) | Wind (strength, heading) | Knots / swept | Motes / cap | Seeds | Footprint radius | Inside at landing (worst share) | Outside the release footprint | Drift (m, mean; worst part) | Trees / shrubs | Trees near the path; path covered | Seeds took |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Click puff | click | 0 | 1 / 0 | 123 / 560 | 10 | 2.44 m | 123 of 123 (0.88) | 0 | 0 | 8 / 6 | 8 of 8; 2 of 2 m | 8 of 10 |
| Hold still | 1.5 | 0 | 1 / 0 | 260 / 560 | 20 | 4.1 m | 260 of 260 (0.82) | 0 | 0 | 17 / 12 | 17 of 17 | 15 of 20 |
| Straight sweep | 1.6 | 0 | 22 / 9.45 m | 360 / 560 | 14 | 1.34 m | 360 of 360 (0.91) | 0 | 0 | 13 / 10 | 13 of 13; 11 of 11 m | 11 of 14 |
| Loop (r 3.2 m) | 2.4 | 0 | 36 / 15.75 m | 560 / 560 | 23 | 1.34 m | 560 of 560 (0.93) | 0 | 0 | 11 / 16 | 11 of 11; 17 of 17 m | 9 of 23 |
| Sweep in wind | 1.4 | 0.8, 0° | 20 / 8.55 m | 328 / 560 | 17 | 1.34 m | 328 of 328 (0.87) | 0 | 4.56; 4.56 (3.32 downwind) | 17 / 8 | 17 of 17; 10 of 10 m | 13 of 17 |
| Gust parcel mid-fall | 1.2 | 0.4, 0° + a parcel after 1 s | 15 / 6.3 m | 248 / 560 | 13 | 1.34 m | 248 of 248 (0.79) | 1 | 2.14; 2.25 | 10 / 10 | 10 of 10; 8 of 8 m | 10 of 13 |
| Wind tool mid-fall | 1.2 | 0 + a full swipe across the veil after 1 s | 15 / 6.3 m | 248 / 560 | 10 | 1.34 m | 248 of 248 (0.85) | 65 | 0.79; 1.22 | 10 / 7 | 10 of 10; 8 of 8 m | 4 of 10 |
| Long zigzag | 3.0 | 0 | 42 / 36.9 m | 560 / 560 | 41 | 1.75 m (merged) | 560 of 560 (0.82) | 0 | 0 | 33 / 32 | 33 of 33; 38 of 38 m | 24 of 41 |
| Peak top (8.8 m) | 1.5 | 0 | 1 / 0 | 260 / 560 | 19 | 4.1 m | 260 of 260 (0.9) | 0 | 0 | 0 / 0 | – | 0 of 19: all bare rock |
| Flank to pond | 1.4 | 0.5, 180° | 10 / 4.05 m | 171 / 560 | 8 | 1.36 m | 171 of 171 (0.83) | 0 | 3.21 | 0 / 1 | – | 0 of 8: 6 rock, 1 water, 1 crowded |

- **Every release:** no mote landed while held, every mote came down (none lost), one undo step, and one undo restored the wish, the floor tint and the objects and cleared the sprouts. The breath lifted the veil's middle 0.21 m. The flicker watch saw 3,800–4,300 frames per release and no spikes.
- **Shape.** The swept shape holds in still air: every tree stood within reach of the path, and every metre of the straight sweep, the loop and the zigzag had a tree within 2.5 m. A loop grew a ring. In wind the veil settled 3.3 m downwind of the sweep.
- **Gusts.** A gust parcel carried part of the veil 2.25 m (1 mote outside the release footprint, all inside the moving one). A full wind-tool swipe across the veil's middle (power 0.92) carried the part it passed 1.22 m while the far parts barely moved. 65 motes left the release footprint; all landed inside the footprint as it stood.
- **Growth.** Seeds grew their saplings 2.0–2.5 s after the veil settled, and the forest round them 8–11 s after (median).
- **Undo in the air.** An undo with 137 motes in the air settled the veil and took it back. A Shift press made no veil and painted (cleared), and with pollen off a press painted as before.
- **Cost.** The veil's own step (motes, haze, footprint, wind) while laid is 0.3–1.1 ms a frame (median), at most 2.4 ms (the long zigzag, at its cap). While falling it is 0.3–1.5 ms (median), at most 5 ms. Release costs 0.2–0.8 ms. Main-loop frames stayed at or under 10.2 ms while laid and falling, except the wind tool's first swipe (161 ms, the wind tool's own first use). While the forest grew, two frames went over 16.7 ms (23 and 26 ms), in emergence's own refresh.

Known and unverified:

- **One habitat only.** The plain is all woodland, so the probe exercised rock, water, crowding and chance, but not the habitat fertility table.
- **The wind tool's carry.** `GUST_CARRY` 0.25 was set from one full swipe (1.2 m on the part it passed). Whether that reads as the gust arranging the veil, or too little, needs a look.
- **Unverified (nothing was rendered):**
  - whether the veil reads as a soft, glinting, churning ribbon at the diorama's distance, and trails the pointer with the right lag (motes 4.5 cm with a glow of 0.9, the haze `HAZE_GLOW` 0.16);
  - whether the breath and the peeling descent read as one soft sheet with overlap, or as a hitch;
  - whether the additive haze survives the display fog or reads as a smudge, and whether 12 haze puffs along a long sweep read as a veil or as beads;
  - whether the swept footprint is noticeable enough, and whether it reads as honest when a gust moves part of it;
  - the footprint shader's cost: it loops over up to 64 capsules per pixel of its box, which covers the sweep's whole bounds;
  - whether the floor darkening all at once when a veil settles reads well;
  - whether sprouts that sink without a sapling read as seeds failing to take.

## Meadow

`scripts/meadow_brush.gd` produces ground colour only, never blades
(the Fidelity look; standing grass was rejected on 2026-09-26). Each cell
settles on a target:

- **Most cells** get a lush, warm meadow green, with a patch-noise weight in
  `GREEN_WEIGHT`. The green is the palette's lightest grass shifted by
  `GREEN_SHIFT`, leaned `MEADOW_LEAN` toward `MEADOW_GREEN`, so it reads on
  every family.
- **Flower drifts** come from noise at `DRIFT_FREQUENCY`. Each drift blooms in
  one of the world's three flower colours, picked by a slow noise at
  `HUE_FREQUENCY`, so a drift is one colour rather than confetti. Across the
  drift the green washes toward that colour (`FLOWER_WASH` at its heart), and
  up to `FLOWER_SHARE` of its cells bloom fully at `FLOWER_WEIGHT`. The three
  colours are picked per world seed from `FLOWERS`, which are all warm
  (buttercup, gold, poppy, rose, apricot, coral, cream). The first film's pale
  blues and whites read as cold shards of sky on the faceted ground.

Cover eases to `COVER`. Dabs move each cell toward its target, so repeated
strokes settle instead of saturating. Lifting a meadow fades the tint and
leaves the cover.

| Tunable | Default |
|---|---|
| `RATE` | 1.6 |
| `GREEN_WEIGHT` | 0.6–0.85 |
| `GREEN_SHIFT` | (−0.035, 0.16, 0.035) from the lightest grass |
| `MEADOW_GREEN`, `MEADOW_LEAN` | `a8cc58`, 0.55 |
| `FLOWER_WASH`, `FLOWER_SHARE`, `FLOWER_WEIGHT` | 0.42, 0.26, 0.66 |
| `DRIFT_FREQUENCY`, `HUE_FREQUENCY` | 0.3 /m, 0.12 /m |
| `radius` | 3.2 (1–9) |

## Path

`scripts/path_brush.gd` wears a tread and gives it stony margins.

- **Edges.** Each cell's distance from the stroke wanders by up to
  `EDGE_WANDER` radii on a slow noise (`EDGE_FREQUENCY`) plus a per-cell
  `EDGE_FRAY`, so the tread's sides are irregular rather than a clean strip.
- **Tread** (inside `TREAD` of the radius). Cover eases down to `WORN_COVER`,
  and the ground takes a packed-earth colour (the palette's sand and gravel)
  at `EARTH_WEIGHT`. The worn centre (inside `CENTRE` of the tread) is darker
  packed earth, which turns dusty, lighter and a little green toward the
  shoulders. Each cell's earth varies in lightness by up to `EARTH_JITTER`.
- **Grassy shoulders.** `GRASSY_SHARE` of the shoulder cells keep their green
  cover under a light dusting of earth.
- **Margin** (out to `MARGIN`). A hashed `STONY_SHARE` of the cells take a
  gravel colour at `STONY_WEIGHT`.
- **Settling.** The tread sinks at `SINK_RATE` to at most `MAX_SINK` below
  where the stroke found it, and is smoothed toward its neighbours at
  `SMOOTH`. It follows the land and flattens only the small bumps.
- **At release,** stones are laid along both edges of the stroke's centre
  line. There is a candidate every `STONE_SPACING`, each one lands at
  `STONE_CHANCE`, sizes fall in `STONE_SIZE` ("rock" scale), and a stroke lays
  at most `STONE_CAP`. Stones skip the tread, ponds, the void and anything
  within 0.2 m of another record.

| Tunable | Default |
|---|---|
| `RATE` | 2.2 |
| `WORN_COVER`, `EARTH_WEIGHT` | 0.12, 0.9 |
| `TREAD`, `MARGIN`, `CENTRE` | 0.7, 1.15 radii; 0.45 of the tread |
| `EDGE_WANDER`, `EDGE_FRAY`, `EDGE_FREQUENCY` | 0.22, 0.12 radii; 0.7 /m |
| `GRASSY_SHARE`, `EARTH_JITTER` | 0.35, 0.12 |
| `STONY_SHARE`, `STONY_WEIGHT` | 0.4, 0.55 |
| `SINK_RATE`, `MAX_SINK`, `SMOOTH` | 0.3 m/s, 0.07 m, 4 /s |
| `STONE_SPACING`, `STONE_CHANCE`, `STONE_SIZE`, `STONE_CAP` | 0.32 m, 0.34, 0.1–0.22, 80 |
| `radius` | 1.1 (0.5–3) |

## Mountain forms

`feature/mountain-brush`. The land brush holds a row of forms
(`scripts/mountain_forms.gd` `FORMS`). **Hill** is the everyday brush
(`land_brush.gd`, unchanged, still capped at its dome) and the default. The
others raise one whole mountain per press.

**In hand.** When land is in hand, the palette shows a plain row of form
buttons above its strip. `FORMS` is data only (`id`, `title`, `glyph`, `hint`)
and the glyphs are `form_*` entries in `glass_chrome.gd` `GLYPHS`, so a
restyle only touches `creation_palette.gd` `_form_button`. The row and
**1 / Shift+1** (`studies/cozy_worlds.gd` `_creation_key`) both call
`NativeChunkEditor.select_land_form(id)` or `cycle_land_form(step)`. The
editor keeps `land_form` and emits `land_form_changed`. The hint line shows
the form's hint.

**Gesture.**

- Press where the summit goes.
- Drag out to grow it. The spread is the brush size (times the form's start
  share) plus the drag distance. The height is the spread times the form's
  `aspect`, scaled a little by strength (Shift+`[ ]`).
- A Ridge is centred on the press and runs along the drag, which sets its
  half-length. A click lays it across the view.
- The drag is read on the press's ground plane, not the terrain, so the
  rising flank under the pointer never shrinks it.
- The form rises live while the button is held (`RISE_SECONDS` 2.2 s, eased)
  and reshapes as you drag. After release it finishes rising, then lands.
- Shift-drag still lowers, with the Hill brush, whichever form is in hand. Right drags orbit in the creation shell.

**Landing, undo and weathering.** Landing closes the mountain's undo step at
full height (`_land_mountain`). Weathering and rock colour then run on a
worker through `_weather_async`, as a land stroke's do, and publish together.
So one undo takes the whole mountain, its weathering and its colour, and redo
brings them back.

Anything that opens a new transaction while a mountain is still rising lands
it first, weathered: a second press, a craft tool, undo, or a regrow
(`_mountain_interrupted` on `data.stroke_starting`). The weathering worker is
joined on the main thread in that case, 20-45 ms, as a quick land restroke
already is.

Weathering is a native `erode` pass. It unlocks only the grid cells the form
lifted by more than 8 cm, so the plain around it and any water keep their
shape. The erosion settings are per form (`SHAPES[form].erode` over
`STROKE_EROSION`), and `detail` scales with height.

**Shapes.** The per-vertex noise is built once per world. A tick only scales
the stored lift; the lift is recomputed only when the drag moves it.

| Form | Rock | Shape | Weathering |
|---|---|---|---|
| Alpine | granite | Horn: concave faces to a sharp summit. Three to five arêtes stand proud between hollowed cirques, with crags on the flanks. Tall ones pass the snowline (6.55 m on the plain) and take a snow dusting on their gentler top faces. | Strong: detail 0.55, k 0.013, cut up to 1.2 m. |
| Ridge | granite | Knife-edge crest, serrated by ridged noise, with one flank steeper. It tapers at both ends and has a high point off-centre. | detail 0.45, k 0.012, cut 1.0 m. |
| Mesa | sandstone | The cap and cliffs stand level on the press's ground. From the flat cap: a caprock cliff, a bench, a lower cliff, then a talus apron. The outline wanders. | Gentle, so the cap stays flat: detail 0.1, k 0.006, cut 0.45 m, deposit 0.65. |
| Volcano | basalt | Concave cone, ribbed, with a lipped crater. Tall cones take snow on their upper slopes. | detail 0.2, k 0.012, cut 0.8 m (radial gullies). |
| Tors | slate | Four to six blocky stacks on a low swell, with tops tilted along the bedding. | Light: detail 0.12, k 0.005, cut 0.35 m. |

**Rock type is regional.** The terrain has no per-region rock type. The
mesh builder paints rock from one palette on slope and height, and a world's
rock style (`seeded_variety.gd`) only picks stone meshes. The regional channel
that does exist is the painted-ground tint layer (`data.tint`, per 0.5 m
cell, saved and undoable).

- **Where it paints.** The weathering job paints the form's rock (`ROCKS`)
  on its steeps (gradient `ROCK_SLOPE` 0.45-0.9) and on its upper share
  (`SUMMIT`). Colours are picked per cell. The gentle green foot is left as it
  is.
- **Sandstone** bands by height (`BAND` 0.55 m).
- **Basalt** reddens toward the crater.
- **A mesa's cap** takes pale sandstone at `CAP_WEIGHT`.
- **Snow** still settles over the tint, as it does over any painted ground.
- **Mixed plates.** Two forms of different types on one plate keep their own
  colours.

**Water: the form refuses to bury it.** The lift fades to nothing within
`WATER_GAP` (1.0-2.6 m) of any pond surface or stream course, so a flank parts
around the water and a pond keeps its surface. The erosion also stays locked
there. The plate's last metres (`EDGE`) fade the lift too, so a form never
walls the rim.

We chose this over re-settling the water because it is predictable and cheap.
It needs no replanning of pours, and raising only ever deepens a basin's rim.

**Emergence.** The landed footprint goes to emergence as a `"land"` region.
The usual rules apply: grass stays off steeps, trees thin toward the rock
slope, and emerged plants that end up on rock or near snow are withdrawn.
Nothing emerges on ground steeper than the rock slope the terrain is painted
with (`Emergence._rock_slope`: the habitat's rock slope, or the mesh's when
that is gentler, 0.93 on the plain), and a plant is withdrawn past 1.1 times
it. Before the playtest round emergence used the habitat's slope alone (1.3
for a meadow), so plants could stand on a peak's painted rock; the probe's
`--watch` found 2 of 4 plants on one Alpine peak doing so. After it, three
`--watch` runs found 0 of 2, 4 and 6 (the steepest 0.78). Generated worlds
plant through their own generator and are unchanged.

**Feel.** `NativeChunkEditor._mountain_feel` is the single call site, marked
`REGEN-POLISH SWAP`.

- **Stroke signals.** Mountains always send them as mode `"mountain"`:
  StrokeFeedback's thump, fog reveal, swell and gusts, and GenesisAudio's
  thump and rumble voice. They are sent at press, on every rising tick, and
  at landing, so the rumble lasts through the rise after release.
- **With WorldRumble** (`scene.world_rumble`, `feature/regen-polish`), the
  call site holds `hold(&"mountain")` (0.45-1 by rise speed, weighted by
  height), pours fog over the flanks (`pour_fog`, re-poured if the drag
  outgrows it) and releases at landing. The signals' rumble rate is zeroed
  then, so the tremor is not doubled.
- **Without it,** the signals' rate drives StrokeFeedback's tremor.

**Cost** (`tools/probe_mountain_forms.gd`, headless, CPU main loop; idle
frames are about 8.3 ms):

- **Rise tick:** a median of 0.4 ms, and 3-5 ms at worst, including its
  light refresh. A reshape is under 1.5 ms.
- **Frames:** none over 16.7 ms from press through landing, weathering and
  the settle.
- **Weathering:** 20-45 ms on a worker.
- **Undo and redo** restore the heights and tint exactly.
- **A pond beside an Alpine peak** keeps its surface (the same triangle
  count). The ground under it moves at most 3 cm.

Run it with:
`godot --headless --path . -s res://tools/probe_mountain_forms.gd -- [--forms=alpine,ridge] [--hold=1] [--drag=2.5] [--watch=45]`.

**Unverified.** Headless runs compile no shaders, so the look has not been
checked in a window:

- the rock colours on the faceted ground and under each palette family;
- the snow dusting;
- how the fog pour reads on the flanks;
- the picker's layout beside the Mood drawer.

## Feel

`StrokeFeedback.BRUSH_FEEL` sets, per brush id, the rumble scale, wind swell,
fog reveal, gust interval and grow-in wave:

| Brush | Rumble | Swell | Reveal | Gust interval | Wave |
|---|---|---|---|---|---|
| Land | 1.0 | 0.45 | yes | 0.7 s | yes |
| Meadow | none | 0.28 | yes | 1.2 s | yes |
| Forest | 0.15 | 0.62 | yes | 0.55 s | yes |
| Path | none | 0.1 | yes | none | no |
| Water | none | 0.28 | yes | none | no |

The craft Meadow tool shares the meadow brush's feel. The land brush never
emitted `stroke_started` on `main` (slice 1 wired its press separately), so it
had no tremor, reveal or wave. It does now.

## Stroke pipeline

- **During a stroke,** dabs touch only the cells and vertices under the brush
  and never add or remove records. A held stroke therefore takes the light
  refresh.
- **Cover and tint.** Changes show on the terrain faces during the stroke,
  through the dirty-rect mesh rebuild.
- **At release,** records change (path stones, cleared plants), and the
  yielding settle refresh publishes them.
- **`GardenView` signatures.** The instance signature no longer holds the
  grass mask, and the water signature no longer holds any cover mask. Painted
  cover places no instance and no water. A cover-only settle, including each
  cover step of emergence, used to rebuild every MultiMesh, the streams, the
  falls and the pond, and bumped `content.revision`, which re-set planar water
  and reseeded the leaf litter. It now costs nothing, or an instance rebuild
  alone when meadow or blade tufts change.
- **Face probes.** On recipe worlds, `NativeChunkEditor._warm_face_probes`
  keeps the per-face slope probes resolved on a worker. The first
  height-changing dab (land or path) used to resolve them on the main thread,
  a frame of about 75 ms. It now costs about 2 ms.

## Checking it

Profiling runs headless (the CPU main loop only):
`godot --headless --path . -s res://tools/profile_stroke.gd -- --mode=land --brush=forest --watch=40`.

The look is unverified until the game is launched: the colours of the meadow,
flowers, path and forest floor on each palette family, the stones, the
forest's outline, and the feel.
