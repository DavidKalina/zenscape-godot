# Motif editor, round 2: terrain (handoff)

> 2026-10-14. Round 2 of docs/design/roguelike/level-editor.md ("What the
> user put first", item 1). Nothing committed.

## Run it

```
godot --path . res://studies/motif_editor.tscn -- --no-title [--load=editor_mountain]
godot --path . res://studies/motif_yard.tscn -- --no-title --motif=editor_mountain   # the generator form, in the yard
```

## The mouse fix (it was locked in round 1)

`kit_isle._ready` resumes inside the `ready_to_walk` emit. That means the
editor's `_first_stand` ran (and set the cursor VISIBLE) before
`character_study._ready` captured the mouse right after that emit. By then
`walk_ready` was already true, so round 1's one-shot fix never connected.
Now `_hold_mouse()` runs every frame in edit mode. It keeps the cursor
VISIBLE, and captures it only while the right mouse button is held to look
round. When you let go, the cursor comes back where it was. The headless
driver could not catch this, because headless ignores mouse mode.

**The check in a real window** (`scratch/mouse_real.gd`, `--rendered`):

- After walk-ready, `Input.mouse_mode` was VISIBLE in six samples over two
  seconds.
- A click on the panel's Dress button landed, and the mouse was still
  VISIBLE afterwards.
- **What the click really was:** macOS dropped the true OS-level click
  (CGEvent through osascript). The cursor never moved, which points to no
  Accessibility permission. So the click that landed was the real cursor
  warped onto the button and the press fed through the window's input
  pipeline.

## Controls (new)

| | |
|---|---|
| 1-8 or the Tools grid | Select, Raise, Lower, Smooth, Flatten, Ravine, Water, Outline |
| Brush tools: LMB drag | stroke; hold still to keep stamping (a dwell piles up a mountain) |
| wheel or `[` `]` (brush tools) | radius (Shift+wheel still sets fly speed) |
| Strength slider | brush strength; for a ravine, its depth (2-12 m); for water, how full |
| Flatten | to the height under the stroke's first point |
| Ravine | carves a channel along the stroke. Its floor never climbs from the first point to the last, and its walls step up 1.6 m (`RuinKit.SET_OFF`) on 1 m ledges until they meet the ground |
| Water: click | pours a pond into the hollow under the click; Shift+click takes the pond there away |
| Outline: drag a handle | moves an outline point; Shift+click the ground adds a point on the nearest edge; Alt+click a handle or Delete removes one (5 points at least) |
| "Outline back to the landform's" | drops the hand-made outline |
| Landform list | whale-back hill, mesa, mountain, split gorge, crater bowl (each with its own sliders) |
| Ctrl+Z / Ctrl+Shift+Z (Cmd too, Ctrl+Y) | undo / redo: strokes, pours, outline edits, sliders, landform, re-roll, piece and marker edits |

Round 1's controls are unchanged.

## What works

All of this was proven through real input by `scratch/terrain_drive.gd`
(headless, events paced to real time), 22/22 checks:

- picking the mountain from the landform list;
- a raise stroke with a dwell (5.35 m to 7.59 m, 10 live rebuilds while dragging);
- a ravine stroke (3 m deep, its walls about 4,000 grab prisms);
- a pond poured into the ravine's low end (a KitWater sheet);
- an outline handle dragged 6 m;
- Ctrl+Z twice and Ctrl+Shift+Z twice;
- Ctrl+S, then a reload that matched both the data and the land;
- P, walking down into the ravine, then catching a lip, hanging and
  climbing out (holds seen: hang, climb), and P back.

The yard stands the saved motif: `editor_mountain`, registered as
`scripts/kit_isle/greybox/au_editor_mountain.gd`. The pond is registered as
a pool (`pools()`), so he wades in it, and the flora keeps out of the
water (`Site.wet`).

Smoke checks: `motif_editor.tscn`, `--load=editor_mountain`,
`motif_yard --motif=editor_mountain` and `editor_hill` all PASS.

Rendered stills are in `scratch/shots/`:

- `r2_mountain_panel.png` (panel and handles)
- `r2_ravine_close.png`
- `r2_crater.png` (a tarn)
- `r2_gorge.png`
- `r2_mesa.png`
- `r2_yard_three.png` (the yard)

## How it's built

- **Recipe, not a baked heightmap.** The land is built in this order:
  1. the preset's raw ground;
  2. the brush strokes, applied in order on a 0.5 m grid of soft changes
     (`Sculpt`, bilinear, built fresh each time: about 3 ms);
  3. the terraces (`step`);
  4. the ravines (`Ravine.cut`: crisp stepped walls found analytically, so
     KitLand finds their lips as cliffs).

  Recipe data is fast enough, so a stored height grid wasn't needed. Ponds
  store where they were poured and how full (`fill`), not a level: the
  level is found on each build (`pour`, a 2 cm priority flood to the
  lowest pass), so a pond follows later sculpting.
- **The kit, unforked.** Everything still goes through `KitLand.island`.
  One small kit change: an optional `cliff_drop` spec key (default 0.3,
  so existing isles are unchanged), passed to `cliff_points(min_drop)`.
  Authored land asks for 0.8 m, so a mountain's steep flank isn't read as
  thousands of cliff points (21k prisms became 4k, and the dress went from
  819 to 229 ms).
- **What's heavy.** Editor-local code stays light: tools, handles and
  undo. `motif_authored.gd` holds the land recipe (presets, sculpt,
  ravine, pour), which is GDScript.

## Timings (headless, this Mac)

| | |
|---|---|
| live stroke rebuild (coarse 1.5 m grid, no crisp cliffs, every ≥30 ms) | 15-30 ms |
| full bare land, preset alone | 8-290 ms (the gorge is slowest: its crisp walls) |
| full bare land with a ravine | 270-670 ms |
| dressed (land + water + pieces; flora follows over frames) | ~230 ms on `editor_mountain` |
| pour (find the level) | ~20 ms; water sheet 25-150 ms |

A stroke rebuilds coarse land while you drag (its ravine walls show as
slopes). On release, the full land, water, turf and flora follow 250 ms
later.

## File format (format 2; format-1 files are read and upgraded by `normalise`)

```json
{"format": 2, "slug": "editor_mountain", "name": "Editor Mountain", "preset": "mountain",
 "sliders": {"length": 60.0, "width": 52.0, "relief": 22.0, "step": 0.0, "jag": 0.45, "sharp": 1.6, "ridges": 0.5},
 "seed": 1,
 "outline": [[38.457, -0.451], [30.115, 6.607], ...],
 "strokes": [{"tool": "raise", "r": 5.0, "s": 0.8, "pts": [[-14.392, 3.393], ...]},
             {"tool": "ravine", "r": 6.0, "s": 0.12, "pts": [[...], ...]}],
 "waters": [{"at": [20.727, 2.163], "fill": 0.7}],
 "pieces": [], "markers": {"spawn": [22.0, 3.188, -6.0], "rim_in": [...], "rim_out": [...]}}
```

`outline: []` means the preset's outline. A held brush repeats its last
point in `pts`, so a long dwell grows the file a little.

## Stood in or missing

- **The split gorge isn't split.** Its ravine stops short of the rim (run
  out through the outline, the hanging sides dropped dark shards into the
  gap), so it's a deep cleft with closed ends. Some dark side shards still
  show at its near mouth. A true split wants two lands, or sides that
  don't hang where the rim is inside a ravine.
- **Streams** aren't moving water. Water is only still ponds: a ravine
  running off the isle drains, and nothing flows down it.
- **Water and lips.** If a pond fills a ravine whose first lip stands
  about 0.9 m over the surface, a swimmer can't climb out (seen in the
  driver). A pond pours to just under its spill, so pour it lower (lower
  strength) or where a bank shelves.
- **Mesa sides** are one sheer face. They aren't climbable unless Cliff
  step is set, and they're drawn in big facets.
- **Faceting.** The mountain's steep rock reads faceted, as all kit rock
  does at the 2 m grid. A finer grid on steep land would cost build time.
- **Size sliders and a hand-made outline.** Changing the landform clears
  a hand-made outline; changing a size slider doesn't scale it.
- **The old tools' feedback** (rumble, fog part, grow-in pop:
  `scripts/stroke_feedback.gd`) isn't carried over. Only the brush ring
  and the live land show.
- **Native kernels.** None serve this yet (they work on the plate's
  heightfield chunks).
- **What the driver set up by hand.** The landform list was driven by its
  signal (OptionButton popups are awkward headless), and the camera was
  placed by script. Everything else went through the input path.

## What the old tools gave (step 0 survey)

- **NativeChunkEditor** brushes (raise, lower, smooth, flatten): radius and
  strength settings with keys, a soft falloff, and the stroke written
  into a heightfield at once. The radius on keys and the stamp's soft
  falloff carried over. The heightfield didn't: KitLand isles build from
  a ground function, so here the strokes are recipe data on a grid of
  changes.
- **The Ravine "wire" tool** (`scripts/clay_tools/wire.gd`): draw a line,
  and a gorge is carved along it. Its bed never climbs, so water runs it,
  and its walls are as steep as the points allow. Both ideas carried over,
  plus stepped, grabbable walls.
- **The Mountain tool's dwell/pull.** A held brush keeps stamping here.
- **`stroke_feedback.gd`**: the rumble, wind swell and grow-in pop per
  brush were the "feel". They're not here yet; they would be cheap to add
  on release (a growth pop over the stroke's box).

## Round 3 (pieces that know how to fit), first

1. Give each RuinKit piece **connectors** as data next to `RuinKit.piece`:
   an aqueduct span's two ends, an arch's springers, a wall's ends, a rope
   bridge's anchors. Put them in the kit, not the editor.
2. **Snap a new piece onto a free connector** under the cursor, turned to
   match, and seat it on the higher of the ground and the piece below
   (stacking).
3. **Fill a run** between two clicked points with spans that follow the
   ground (aqueduct, wall).
4. **Snap to cliff lips.** Ravine walls are now real lips, a natural place
   for bridges and piers.
5. Treat piece edits as undo steps (already in place) and **redress the
   flora under a moved piece**.
