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

- **Drag** paints. **Shift-drag** or **right-drag** works the other way:
  land lowers, a meadow lifts, forest clears, and a path grows back.
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
