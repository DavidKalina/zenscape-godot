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

## Seed sprinkle

`feature/seed-handful`, 2026-09-27. The user first asked for forest to work like the water ball: "you're actually putting seeds or spores in, kind of like they're drifting towards the ground and then they land and then they start to grow." A gathered handful of seeds was built (hold to gather, release to sow). The user tried it and said: "I actually don't like the hold and release. I think it makes more sense to have it be like... you're sprinkling kind of onto the map." So Forest is now a sprinkle. The words are in `docs/scenic/handful.md`. `--paint-forest` brings back drag-to-paint (`NativeChunkEditor.seed_handful`), and Shift-drag still clears as before.

- **Pour** (`scripts/seed_handful.gd`). While the left button is down with forest in hand, seeds pour from a spout `KINDS.forest.drop` (0.8 m) above the pointer's ground point. The rate is `KINDS.forest.rate` (9 a second) × strength × (brush radius / `REFERENCE_RADIUS` 3.6 m)². The first seed leaves on the press, so a tap still sows one. At most `AIR_MAX` (48) seeds are in the air; the spout waits for room. The spout follows the pointer on a stiff spring (`FOLLOW` 900, `FOLLOW_DAMP` 55, stepped at most 1/240 s at a time), about 0.06 m behind per m/s of pointer speed, and jiggles `SHAKE` (3 cm at 5 Hz) as it pours. Holding still sprinkles one spot densely; a drag lays a trail.
- **The promise.** Each seed is given a landing point as it leaves, inside the mark under the spout at `INSIDE` (0.85) of its radius. The mark's radius is `KINDS.forest.mark` (0.3) × the brush radius, at least `MARK_MIN` (0.5 m): 1.08 m at the default brush. A new mark is laid when the spout has moved `MARK_STEP` (0.5) of a radius from the last one. At most `MARKS` (24) stand at once; past that, the newest serves. A mark stays while any of its seeds is in the air, then shrinks away over `MARK_FADE` (0.3 s). Holding still shows one mark. A drag shows a short trail of marks behind the spout, one pool where they overlap. The marks (`shaders/seed_handful_mark.gdshader`) are drawn like the water ball's (`shaders/water_ball_ground.gdshader`): a slowly turning 12-gon pooled shadow in two tones with a pale rim, straight below, never along the sun. The rim is warm seed light and is brighter while seeds pour. The terrain's brush ring hides while a sprinkle is out.
- **Drift.** Each seed takes 0.38–0.58 s to come down (`KINDS.forest.fall`). It gets a small toss (`TOSS` 0.12 m) and a scatter at the spout (`SCATTER` 0.08 m). It spins on its wing at 10–16 rad/s, rocks as it flutters and sways up to 0.12 m, plus `BREEZE` (0.08 m) along the world's wind (`_atmosphere._air_angle`). Sway and breeze are scaled by sin(πu), so they die out at the landing and each seed lands on its own point.
- **Land and take.** Each landing rings out on the mark and throws `MOTES` (4) dust motes. Where the ground will take it (`Emergence.takes`: ground, not water, not a hand-laid path, below the rock slope, the snow and the treeline) and no other young sprout stands within `SPROUT_ROOM` (0.35 m), a two-leafed sprout pops up. The sprout overshoots, sways, settles and sinks after `SPROUT_SECONDS` (9 s). A dense spot shows a patch of sprouts, not a heap.
- **One stroke, one undo step.** The press opens the step. Each landing raises the forest wish round it (`ForestBrush.sow`) by up to `SEED_WISH` (0.3), with the dab's falloff over `SEED_REACH` (1.2 m). The wish fades from the edge of the seed's own mark to `SEED_EDGE` (0.8 m) past it, and the landing darkens the floor as a dab does. The wish shows through the light refresh, at most once a frame. When the button is up and the last seed is down, the step closes (`_handful_sown`) and the view settles. The seeds are then thinned to one per `TREE_GAP` (1.1 m) and handed to emergence as a `"forest"` region with the stroke's bounds. The extra seeds of a dense spot only sprouted and asked for forest; they are not sent to emergence to be crowded out. A new press, or an undo while seeds are in the air, lands them at once where they were promised, and the undo then takes the whole stroke back. An undo, a load or a new world also clears the sprouts (`withdraw`).
- **Growth starts from the seeds** (`emergence.gd`, `SOWN_*`, unchanged from the handful). Each planted seed is a tree candidate at its landing point. It arrives first, at `SOWN_DELAY` (1.2 s) plus up to `SOWN_STAGGER` (2 s), and takes at `SOWN_TAKE` (0.8), thinned on steep ground as any tree is. It skips quiet guidance's sightline and lone-tree drops, and never comes up as dead wood. The region's lattice candidates then arrive by distance from the nearest seed: `SOWN_TREE_DELAY` (4 s) or `SOWN_SHRUB_DELAY` (7 s), plus distance / `SOWN_SPREAD` (0.4 m/s), plus up to `SOWN_JITTER` (5 s). Species come by stand; water, snow, steep rock and crowding rules are unchanged.
- **What the seeds look like.** A samara: a dark faceted nut at the root of one creased, veined wing, 0.22 m long, lit as the scene is with a small glow on the wing (`glow` 0.3, `shaders/seed_handful.gdshader`). Seeds pop out of the spout over 0.08 s. The wing colour follows the dominant tree of the stand under the press (`Emergence.seed_family`, `LOOKS`): pine tan, maple green-gold, birch pale, desert dust. It is the default broadleaf look until the live blend is built.
- **Other kinds later.** `begin(point, kind, …)` takes a `kind` from `KINDS`. A meadow sprinkle of seed or pollen would be another entry, with a higher rate, lighter seeds, a longer drift and a wider mark. Only forest is built.

`tools/probe_seed_handful.gd` drives the real input path on the plain (press, the editor's own `_process` following the pointer, release). It reports each stroke, then an undo while seeds are in the air, a Shift press and a press with the sprinkle off. Headless (`--headless --script tools/probe_seed_handful.gd`), one run, default brush unless noted:

| Stroke | Held | Seeds dropped / landed | Most in air | Inside their marks | Farthest (share of radius) | Spout lag | Landing to pointer (median) | Sent to emergence | Trees / shrubs | Saplings on seeds |
|---|---|---|---|---|---|---|---|---|---|---|
| Tap | 0.06 s | 1 / 1 | 1 | 1 of 1 | 0.55 | 0 m | – | 1 | 1 / 0 | 1 |
| Linger 3 s | 3 s | 28 / 28 | 5 | 28 of 28 | 0.85 | 0 m | 0.61 m | 2 | 3 / 1 | 2 |
| Slow drag, 1.7 m/s | 3 s | 28 / 28 | 5 | 28 of 28 | 0.85 | 0.11 m | 1.15 m | 7 | 7 / 3 | 7 |
| Fast drag, 8.3 m/s | 1.2 s | 11 / 11 | 5 | 11 of 11 | 0.85 | 0.53 m | 4.98 m | 7 | 8 / 2 | 5 |
| Wide drag, brush 6 m, 4 m/s | 2 s | 51 / 51 | 15 | 51 of 51 | 0.85 | 0.25 m | 2.7 m | 13 | 14 / 4 | 11 |

Results:

- **Growth.** Planted seeds grew their saplings 2.1–3.7 s after the stroke closed, and the forest round them mostly about 8.5–10.7 s after. No grown tree stood more than 1.5 m from a landed seed.
- **Undo.** Each stroke added one undo step. One undo restored the wish, the floor tint and the objects exactly, and cleared the sprouts. An undo with 3 seeds still in the air landed them and took the stroke back.
- **Shift and `--paint-forest`.** A Shift press made no sprinkle and painted (cleared). With the sprinkle off, a press painted as before.
- **Frame cost.** The sprinkle's own step is 0.04–0.15 ms a frame (median) and at most 0.5 ms while pouring. Its worst frame is 4–6 ms, when the stroke's undo step closes and its settle starts. Release costs under 0.2 ms. Main-loop frames stayed under 13.3 ms while pouring and settling. While the forest grew, one frame each in the fast and wide drags went over 16.7 ms (40 ms and 16.7 ms), in emergence's own arrival refreshes.

Known and unverified:

- **A linger grows a small clump.** A linger's forest is small: 28 seeds in one spot send 2 to emergence and grow about 3 trees, because trees keep `TREE_GAP` apart. Lingering longer darkens the floor and raises the wish, but it cannot pack trees closer.
- **Fast drags land behind the pointer.** A fast drag lands its seeds about 5 m behind the pointer, where the spout was when they left. The trail of marks shows this, but whether it reads as right or as lag is untested.
- **Unverified (nothing was rendered):**
  - whether the seeds read at the diorama's distance (`size`, `glow`);
  - whether the small marks are clear on every ground, sky and mood;
  - whether the trail of marks on a drag reads as a promise or as clutter;
  - whether the pour looks like shaken seed;
  - whether lit, glowing seeds fit the painted look;
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
