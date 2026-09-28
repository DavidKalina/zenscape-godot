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

`feature/seed-handful`, 2026-09-27. Forest is a released cloud of pollen and seed-fluff: **you release something; the world decides what becomes of it** (`docs/scenic/handful.md`). Two earlier tries were turned down the same day: a gathered handful of winged seeds, and a seed sprinkle that poured while the button was down (both in the branch history). Of the sprinkle the user said: "I just don't like it as a paintbrush... the seeds need to be affected by the wind, and if there's no wind, it just kind of floats down." `--paint-forest` brings back drag-to-paint (`NativeChunkEditor.seed_handful`), and Shift-drag still clears as before.

- **Release** (`scripts/pollen_cloud.gd`). With forest in hand, a press gathers a cloud `HEIGHT` (2.2 m) above the pointer's ground point. A click lets a puff go. Holding swells it to a full cloud over `HOLD_SECONDS` (1.4 s at strength 1).
  - A puff has `MOTES` 120 motes and a full cloud 260, scaled by √strength and by the brush's size (radius / 3.6 m, kept within `SIZE` 0.6–1.6). The cloud's radius runs `CLOUD` 0.6–1.3 m, puff to full.
  - While held the cloud floats after the pointer on a soft spring (`FOLLOW` 30, `FOLLOW_DAMP` 9), bobbing and billowing. Nothing is written while it is held, and dragging paints nothing.
  - Up to `CLOUDS` (4) may be in the air at once. Pressing any other brush settles them first.
- **The look.** Glinting motes of fluff (tiny faceted specks that twinkle, glowing a little) under a soft additive haze (`shaders/pollen_haze.gdshader`, `HAZE` 8 camera-facing puffs per cloud). The haze thins as the cloud spreads and settles. The colour follows the dominant tree of the stand under the press (`Emergence.seed_family`, `LOOKS`): pine gold, broadleaf cream, birch pale, desert dust.
- **Drift** (`scripts/pollen_wind.gd`, the one place pollen asks the wind). The wind is read every frame from the same state the shaders' wind reads:
  - the atmosphere's strength (air strength + swell, times the gust envelope `gust_at`) and its direction;
  - the gust parcels it has sent, through `wind_puffs.gd` `sample_at`, the CPU mirror of `zs_gust_pulse_at`. The noise field is taken at its mean.

  Drift is `DRIFT` (1.4 m/s) × strength × (0.45 + 1.1 × min(1, 0.5 + pulse)), so still air gives no drift. When the editor has the wind tool (`gust`, on `feature/wind-gust`), its `wind_at` push is added; without it, only the world's wind counts.

  Each mote falls for 3.2–5.2 s (`FALL`), the lightest the longest. It sinks at a steady rate after a soft start, drifts apart from the others to a spread within `SPREAD` (1.8–2.8 m, puff to full), wanders `WANDER` (0.35 m) on the curl of the air, and rides the cloud's drift, which the air adds to every mote still aloft. Near the ground each mote looks ahead to where it will land, so it comes down onto the ground there.
- **The promise.** While aiming, a soft footprint (`shaders/pollen_footprint.gdshader`) shows where a click would settle. It follows the held cloud and moves with the released one until the cloud has settled.
  - It is a capsule of radius r0 + sigma. It runs from the cloud's drift so far, carried on by the present wind for the least and the most fall time left: round and centred in still air, shifted and stretched downwind in wind.
  - A mote lands at its place in the cloud at release (within r0), plus its spread (within sigma), plus the cloud's drift by then. So every mote lands inside the footprint as it stands when that mote lands. In steady air that is the footprint shown at release. A gust moves the footprint, and the cloud, downwind.
  - It is drawn like the water ball's mark (a slowly turning 12-sided pooled shadow in two tones with a rim), but softer and lighter, with a warm rim and faint twinkling specks. The terrain's brush ring hides while pollen is in hand.
- **Land.** A landed mote glints for `GLINT` (0.8 s). A mote at least `SEED_GAP` (1.1 m, Emergence TREE_GAP) from the cloud's other seeds is a seed; the rest is dust. Where a seed lands on ground that could take it (`Emergence.takes`: ground, no water, not a path, below the rock slope, the snow and the treeline), a two-leafed sprout pops up and sinks after 9 s. Motes that drift off the land are lost.
- **The land decides.** When a cloud's last mote is down (`_pollen_settled`, `_write_cloud`), its seeds raise the forest wish round them (`ForestBrush.sow`: up to `SEED_WISH` 0.45 over `SEED_REACH` 1.6 m) and darken the floor, as one undo step. The seeds then go to emergence as a `"forest"` region.
  - Each seed is a tree candidate at its point. It comes up first, at `SOWN_DELAY` (1.2 s) + up to `SOWN_STAGGER` (2 s), and takes at `SOWN_TAKE` (0.9) × `_fertility`.
  - `_fertility` is the habitat's share (`SOWN_FERTILITY`: woodland and redwood 1, wetland 0.8, alpine and meadow 0.75, arid 0.3). It is leaned down on dry ground (to `SOWN_DRY` 0.75 at no moisture; moisture is the blend's, which water nearby raises) and on exposed heights (to `SOWN_EXPOSED` 0.65 at the top of the altitude range).
  - The ordinary rules refuse water, bare rock, snow and above the treeline, thin trees on steep ground, and crowd seeds out of existing forest.
  - The region's lattice candidates follow by distance from the nearest seed (`SOWN_TREE_DELAY` 4 s, `SOWN_SHRUB_DELAY` 7 s, `SOWN_SPREAD` 0.4 m/s, `SOWN_JITTER` 5 s). Their trees take at the fertility too.
  - Species come by stand (scripts/tree_stands.gd), and sown trees never come up as dead wood. `Emergence.sown_outcomes` tallies what became of every seed, by habitat.
- **Undo.** One release is one undo step, written when the cloud settles. An undo while clouds are in the air settles them, oldest first, and takes back the last. An undo, a load or a new world clears sprouts and clouds (`withdraw`). No stroke signals start while a cloud is held: the forest brush's feel would swell the very wind the cloud drifts on. The settled cloud reports `stroke_finished`.
- **Other kinds later.** A meadow's seed would be another cloud, lighter and further-drifting, whose settle writes meadow ground.

`tools/probe_seed_handful.gd` drives the real input path on the Genesis plain (press, the editor's own `_process` following the pointer, release), with the wind set on the scene's atmosphere. It checks each landing against the footprint as it stood when the mote landed, and against the footprint shown at release. Headless (`--headless --script tools/probe_seed_handful.gd`), one run:

| Release | Held | Wind (strength, heading) | Drift at release | Motes / seeds | Footprint radius, length | Inside at landing | Outside the release footprint | Settled from pointer | Trees / shrubs | Seeds took |
|---|---|---|---|---|---|---|---|---|---|---|
| Still puff | click | 0 | 0 | 126 / 9 | 2.47 m, 0 | 126 of 126 | 0 | 0.06 m | 7 / 11 | 6 of 9 |
| Still full | 1.5 s | 0 | 0 | 256 / 25 | 4.1 m, 0 | 256 of 256 | 0 | 0.1 m | 21 / 16 | 18 of 25 |
| Wind puff | click | 0.8, 0° | 1.07 m/s | 126 / 8 | 2.47 m, 2.14 m | 126 of 126 | 0 | 4.34 m downwind | 5 / 7 | 3 of 8 |
| Wind full | 1.5 s | 0.8, 0° | 0.61 m/s | 256 / 21 | 4.1 m, 1.22 m | 256 of 256 | 0 | 2.82 m downwind | 16 / 15 | 12 of 21 |
| Gust mid-fall | click | 0.4, 0° + a gust parcel after 1 s | 0.43 m/s | 126 / 11 | 2.47 m, 0.85 m | 126 of 126 | 4 (worst 1.14 radii) | 2.54 m downwind | 7 / 13 | 5 of 11 |
| Peak top (8.9 m) | 1.5 s | 0 | 0 | 256 / 20 | 4.1 m | 256 of 256 | 0 | 0.61 m | 0 / 1 | 0 of 20: all bare rock |
| Flank to pond | 1.5 s | 0.5, 180° | 0.62 m/s | 256 / 22 | 4.1 m, 1.24 m | 256 of 256 | 0 | 1.83 m downwind | 1 / 1 | 1 of 22: 10 rock, 8 crowded by the peak's forest, 1 water, 2 thinned |

- **Wind.** The same strength gives different drifts from one release to the next, because the gust envelope (`gust_at`) swings the wind's strength over time.
- **The gust test.** A gust parcel sent through the falling cloud carried it about 1.2 m further than the release footprint allowed (3.38 m of drift against 2.2 m at the release wind). 4 motes landed outside the release footprint, all inside the footprint as it stood.
- **Growth.** Seeds grew their saplings 2.0–3.5 s after the cloud settled, and the forest round them 9.4–10.7 s after (median).
- **Undo.** Each release added one undo step. One undo restored the wish, the floor tint and the objects, and cleared the sprouts. An undo with 137 motes in the air settled the cloud and took it back.
- **Shift and `--paint-forest`.** A Shift press made no cloud and painted (cleared), and with pollen off a press painted as before.
- **Cost.** The cloud's own step (motes, haze, footprint and wind) is 0.2–0.8 ms a frame (median), at most 1.1 ms while held. Its worst frame is 3–8 ms, the settle frame that writes the cloud's undo step. Release costs 0.2–0.5 ms. Main-loop frames stayed under 15 ms while held and falling. While the forest grew, one frame (25.8 ms) went over 16.7 ms, in emergence's own refresh.

Known and unverified:

- **One habitat only.** The plain is all woodland, so the probe exercised rock, water, crowding and chance, but not the habitat fertility table. A meadow or arid world would show fewer trees from the same cloud; that is the table's intent, untested here.
- **Stand size.** A click puff grows about 5–7 trees and a full cloud 16–21. The number is limited by seeds keeping `TREE_GAP` apart and by the fertility.
- **Steered gusts.** The wind tool's `wind_at` is looked up but was not present on this branch, so steered gusts were not exercised.
- **Unverified (nothing was rendered):**
  - whether the cloud reads as soft, drifting, glinting fluff at the diorama's distance (the motes are 4.5 cm with a glow of 0.9, the haze brightness `HAZE_GLOW` 0.16);
  - whether the additive haze survives the display fog or reads as a smudge;
  - whether the soft footprint is noticeable enough, and whether a moving footprint under a gusting cloud reads as honest or as unreliable;
  - whether the floor darkening all at once when a cloud settles reads well;
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
