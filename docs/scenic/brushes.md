# Creation brushes: meadow, forest and path

Phase 3, slice 4 (`feature/land-brushes`). The brushes write intent, and the
world picks the details. None of them places a plant under the pointer.

## In hand

`scripts/genesis_canvas.gd` keeps the ordered brush list (`BRUSHES`). The keys
are 1 land, 2 water (slice 2), 3 meadow, 4 forest and 5 path. The editor's
`"land"` tool paints with whichever brush is in hand: `NativeChunkEditor.brush_id`,
`select_brush(id)`, and the `brush_changed` signal for a shell to follow.

- **Drag** paints. **Shift-drag** or **right-drag** works the other way:
  land lowers, a meadow lifts, forest clears, and a path grows back.
- **`[ ]`** sets the size of the brush in hand, and **Shift+`[ ]`** sets its
  strength. Land keeps `land_radius` and `land_strength` as editor settings.
  The others keep `radius` and `strength` on the brush and report changes as
  `setting_changed("brush_radius" | "brush_strength", value)`.

Each brush is its own script and extends `scripts/creation_brush.gd`. That
script documents the interface the editor drives: `activate`, `deactivate`,
`prepare`, `begin`, `dab`, and `finish`, which returns the rect that emergence
should answer.

## Provenance

| Brush | Cover cells | Objects |
|---|---|---|
| Meadow | Marked hand. Emergence never thins or plants in them, so a meadow painted inside a forest stays an open glade. | Untouched. |
| Path | Marked hand, tread and margin. Nothing emerges on a path. | At release, clears emerged records from the tread, plus generated undergrowth (`PathBrush.UNDERGROWTH`). Lays stones, which are tagged hand like every record minted in a stroke. |
| Forest | Left as they are, so emergence can plant. The floor tint skips hand cells. | A clearing stroke withdraws emerged plants where it left the wish at `CLEAR_BELOW` or lower. |

Hand-placed and pinned records are never removed. Generated trees and rocks
stay on a path too.

## Forest

`scripts/forest_brush.gd` writes the **forest wish** in `scripts/land_intent.gd`.
This is one float per cover cell, from -1 (keep clear) through 0 (the biome
decides) to 1 (the heart of a forest). It rides the undo history through
`history_captured` and `state_restored`, the same way the fire field does, so
one undo removes the wish and its painted floor together. It is not saved;
trees that have already grown are.

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
| `radius` | 3.6 (1.5–9) | Brush radius in metres. |

## Meadow

`scripts/meadow_brush.gd` produces ground colour only, never blades
(the Fidelity look; standing grass was rejected on 2026-09-26). Each cell
settles on a target:

- **Most cells** get a lighter, warmer meadow green, with a patch-noise weight
  in `GREEN_WEIGHT`.
- **Some cells** inside flower drifts get one of the world's three flower
  colours at `FLOWER_WEIGHT`. The drifts come from noise at
  `DRIFT_FREQUENCY`. Up to `FLOWER_SHARE` of the cells in a full drift bloom.
  The three colours are picked per world seed from `FLOWERS`.

Cover eases to `COVER`. Dabs move each cell toward its target, so repeated
strokes settle instead of saturating. Lifting a meadow fades the tint and
leaves the cover.

| Tunable | Default |
|---|---|
| `RATE` | 1.6 |
| `GREEN_WEIGHT` | 0.26–0.44 |
| `GREEN_SHIFT` | (−0.022, 0.02, 0.045) from the lightest grass |
| `FLOWER_SHARE`, `FLOWER_WEIGHT` | 0.2, 0.62 |
| `DRIFT_FREQUENCY` | 0.32 /m |
| `radius` | 3.2 (1–9) |

## Path

`scripts/path_brush.gd` wears a tread and gives it stony margins.

- **Tread** (inside `TREAD` of the radius). Cover eases down to `WORN_COVER`,
  and the ground takes a packed-earth colour (the palette's sand and gravel)
  at `EARTH_WEIGHT`.
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
| `WORN_COVER`, `EARTH_WEIGHT` | 0.12, 0.8 |
| `TREAD`, `MARGIN` | 0.7, 1.15 radii |
| `STONY_SHARE`, `STONY_WEIGHT` | 0.45, 0.6 |
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
