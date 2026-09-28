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

## Seed handful

`feature/seed-handful`, 2026-09-27. The user asked for the forest to work like the water ball: "you're actually putting seeds or spores in, kind of like they're drifting towards the ground and then they land and then they start to grow," instead of mousing over the terrain and waiting. The handful is now the Forest brush's default. `--paint-forest` brings back drag-to-paint (`NativeChunkEditor.seed_handful`), and Shift-drag still clears as before. The shared handful vocabulary (shaping tools stay brushes, sowing tools carry handfuls, the shadow is the promise) is written up in `docs/scenic/handful.md` on `feature/handful-shadow`.

- **Gather** (`scripts/seed_handful.gd`). A left press with forest in hand gathers a cloud of winged seeds `HOVER` (1.5 m) above the ground point. It grows while held, reaching full after `GATHER_SECONDS` (2.4 s) at strength 1. `KINDS.forest.seeds` gives 4 seeds empty and 18 full at `REFERENCE_RADIUS` (3.6 m). A wider brush carries more by area, up to `SEEDS_MAX` (64). New seeds are drawn in from `DRAW_FROM` (0.7–1.5 m) out, with a curl. The cloud's radius runs from `CLOUD` 0.2 m to 0.55 m and breathes (`BREATHE`: 7 % at 0.6 Hz). It bobs, churns (`CHURN` 1.1 rad/s, faster with speed) and gathers in with an ease-out-back overshoot over `GATHER_IN` (0.3 s).
- **Carry.** The cloud follows the pointer on an underdamped spring (`FOLLOW` 55, `FOLLOW_DAMP` 10). Each seed chases its own place in the cloud on a looser spring (`SEED_FOLLOW` 70, `SEED_DAMP` 7, damping ratio about 0.42), and the cloud stretches along its motion (`STRETCH`). A quick pull trails the seeds, and a stop sloshes them past and back.
- **The mark is the promise** (`shaders/seed_handful_mark.gdshader`, a depth-reading decal like the water ball's ground). It lies straight below the cloud, never along the sun. It is a softly darkened disc inside a bright warm ring with slowly turning dashes, and a dark outline outside the ring, so it reads on pale and dark ground and at night (the ring keeps a constant glow on top of the key light). While the handful is held, faint rings draw in toward the middle. Its radius is `KINDS.forest.mark` × the brush radius: 0.35 empty to 1.0 full, never under `MARK_MIN` (0.9 m). The terrain's brush ring hides while a handful is out (`preview_wanted`).
- **Release.** The mark freezes where the cloud is. Every seed's landing point is drawn then, inside the mark at `INSIDE` (0.88) of its radius. The points are laid on a sunflower spiral with jitter, and seeds pair with points round the circle in order, so the cloud fans outward instead of crossing over. The cloud squeezes to `SQUEEZE` (0.55) and dips `DIP` (0.12 m) over `WIND_UP` (0.12 s). The seeds then spill over `SPILL` (0.3 s), lowest first.
- **Fall.** Each seed takes 1.1–1.8 s (`KINDS.forest.fall`) to come down. It is tossed up to `TOSS` (0.3 m) first, fans out early, and settles into a steady fall. It spins on its wing at 9–15 rad/s, rocks as it flutters, and sways up to 0.3 m sideways plus `BREEZE` (0.2 m) along the world's wind (`_atmosphere._air_angle`). Sway and breeze are both scaled by sin(πu), so they die out at the landing, and each seed lands on its own point.
- **Land and take.** Each landing rings out on the mark, throws `MOTES` (5) dust motes and, where the ground will take it (`Emergence.takes`: ground, not water, not a hand-laid path, below the rock slope, the snow and the treeline), pops up a two-leafed sprout. The sprout overshoots, sways, settles and sinks after `SPROUT_SECONDS` (9 s) as the forest's own saplings take over.
- **What it asks of the ground.** The first landing opens one undo step (`_seed_landed`). Each landing raises the forest wish round its point (`ForestBrush.sow`) by up to `SEED_WISH` (0.55), with the dab's falloff over `SEED_REACH` (1.5 m). The wish fades to nothing from the mark's edge to `SEED_EDGE` (0.3 m) past it, and darkens the floor as a dab does. Overlapping seeds build a core, and the edge frays toward the rim. The landed wish shows through the light refresh, at most once a frame. The last landing closes the step (`_handful_sown`), settles the view, and hands the bounds and the seed points to emergence as a `"forest"` region. One handful is one undo step. A new press, or an undo while seeds are in the air, lands them at once where they were promised, and the undo then takes the whole handful back. An undo, a load or a new world also clears the sprouts (`withdraw`).
- **Growth starts from the seeds** (`emergence.gd`, `SOWN_*`). Each landed seed is a tree candidate of its own at its landing point. It arrives first, at `SOWN_DELAY` (1.2 s) plus up to `SOWN_STAGGER` (2 s), and takes at `SOWN_TAKE` (0.8), thinned on steep ground as any tree is. It skips quiet guidance's sightline and lone-tree drops, and never comes up as dead wood. The region's lattice candidates then arrive by their distance from the nearest seed: `SOWN_TREE_DELAY` (4 s) for trees or `SOWN_SHRUB_DELAY` (7 s) for shrubs, plus distance / `SOWN_SPREAD` (0.4 m/s), plus up to `SOWN_JITTER` (5 s). The forest spreads out from where the seeds fell. Species still come by stand (scripts/tree_stands.gd). All the old rules still apply: nothing grows on water or snow, trees thin on steep rock, and crowding gaps hold.
- **What the seeds look like.** A samara: a dark faceted nut at the root of one creased, veined wing, `KINDS.forest.size` (0.22 m) long, lit as the scene is with a small glow on the wing (`glow` 0.3) so the cloud reads as specks at the diorama's distance (`shaders/seed_handful.gdshader`). The wing colour follows the dominant tree of the stand under the press (`Emergence.seed_family`, `LOOKS`): pine tan for conifers, maple green-gold for broadleaves, pale for birch, dust for the desert. It is the default broadleaf look until the live blend is built.
- **Other kinds later.** `gather(point, kind, …)` takes a `kind` from `KINDS`. A meadow's seed or pollen would be another entry with more, lighter seeds, a longer drift and a wider, softer mark. The landing hook would write the meadow's ground instead. Only forest is built.

`tools/probe_seed_handful.gd` drives the real input path on the plain (press, the editor's own `_process` following the pointer, release). It reports each handful, then an undo while seeds are in the air, a Shift press and a press with the handful off. Headless (`--headless --script tools/probe_seed_handful.gd`), one run:

| Handful | Held | Seeds | Mark | Seeds inside | Farthest (share of radius) | Trees / shrubs | Saplings on seed points | First on a seed / others (median) |
|---|---|---|---|---|---|---|---|---|
| Tap (-3, 2) | 0.1 s | 5 | 1.76 m | 5 of 5 | 0.87 | 4 / 1 | 4 | 2.0 s / – |
| Short (2.5, -1.5) | 1 s | 10 | 2.78 m | 10 of 10 | 0.86 | 8 / 8 | 7 | 2.1 s / 10.3 s |
| Full (0.5, 1) | 3.5 s | 18 | 3.6 m | 18 of 18 | 0.88 | 14 / 7 | 13 | 2.0 s / 10.6 s |
| Moving (-5, -4) to (3, -4.5) | 2 s | 16 | 3.4 m | 16 of 16 | 0.87 | 12 / 9 | 7 | 2.1 s / 8.1 s |
| Wide (brush 6 m) | 3 s | 50 | 6.0 m | 50 of 50 | 0.88 | 35 / 18 | 26 | 2.0 s / 9.5 s |

Results:

- **Mark and landings.** No seed ever landed outside its mark. In the air a seed strayed at most 0.91 of the radius from the centre. The forest wish changed in no cell past the mark's edge + `SEED_EDGE` + one cell.
- **What grew.** Across the runs, at most one tree stood past the mark, 0.1 m out (the guided edge's warp). Roughly half to three quarters of the seeds grew a sapling on their point. The rest were refused as crowded (seeds about 1.3 m apart against `TREE_GAP` 1.1 m) or thinned, and their sprouts sink.
- **Undo.** Each handful added one undo step. One undo restored the wish, the floor tint and the objects exactly, and cleared the sprouts. An undo with 5 seeds still in the air landed them and took the handful back.
- **Shift and `--paint-forest`.** A Shift press made no handful and painted (cleared), and with the handful off a press painted as before.
- **Frame cost.** Under the dummy renderer, the handful's own step takes 0.03–0.2 ms a frame (median), 0.3 ms at p95. Its worst frame is about 3.5 ms, when the first or last seed lands and the undo step opens or closes. Release takes 0.2–1.3 ms, and main-loop frames stayed under 12.5 ms throughout.

Unverified (nothing was rendered):

- Whether the seeds read at the diorama's camera distance: 0.22 m samaras with a 0.3 glow may be too small or too faint. `size` and `glow` are the knobs.
- Whether the mark reads clearly on every ground, sky and mood (the user missed the water ball's shadow), and whether the dashes and drawing-in rings read as alive or as noise.
- Whether the gather, carry and spill motion has the polish asked for (anticipation, overlap, follow-through, moving holds). It was tuned by numbers only.
- Whether a lit, glowing seed fits the painted, faceted look, and whether the decal tints seeds that come within 0.9 m of the ground over the mark (it paints anything below its `ceiling`).
- Whether sprouts that sink without a sapling read as seeds failing to take, or as a glitch.

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
