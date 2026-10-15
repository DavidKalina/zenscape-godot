# Motif editor, round 4: pieces that know how to fit (handoff)

> 2026-10-14. Round 4 of docs/design/motif-editor/level-editor.md ("Kit pieces
> that know how to fit"). Nothing committed.

## Run it

```
godot --path . res://studies/motif_editor.tscn -- --no-title [--load=editor_aqueduct_gorge]
godot --path . res://studies/motif_yard.tscn -- --no-title --motif=editor_aqueduct_gorge   # the motif form
```

## Controls (new this round)

| | |
|---|---|
| drag a Kit piece in from the palette | near a **free connector** of a placed piece that it mates with (within 60 px on screen, measured to a 2.5 m upright over a ground connector), the ghost **snaps** onto it, turned to match. It shows a mint ring at the connector and turns gold. Let go to set it there |
| post snaps (an arch onto a pier, a pier under an arch's springer) | the arch turns to reach toward the cursor: move the mouse round the pier to swing it |
| over a placed piece's top | the ghost stands on it (a pier on a wall top), either at its "top" connector or wherever the ray meets an upward face |
| a wall carried near a cliff lip | it seats along the lip, just inland (a parapet) |
| dragging a snapped piece away | it stands on its own again. Z / X on a snapped piece turns it about its parent |
| palette **Aqueduct run / Wall run / Rope bridge** (Land pocket, or search "run", "bridge") | click the start, then the end, or press and drag. A line shows the run, with ticks where the aqueduct's piers will stand. A bridge's ends (and a wall run's) snap to the nearest cliff lip. A bridge takes the bank's top, not a step down a stepped ravine wall |
| Trash on a run | takes the whole run away (one entry) |
| palette **Kit** and **Trees** pockets | now a **tile grid**: 142 x 156 px tiles with the 160 px thumbnail over the name |

## The connector data (kit, not editor)

`scripts/ruin_kit_fit.gd`, beside `RuinKit.piece`. `connectors(id, node = null) -> Array` returns, in the piece's own frame:

```gdscript
{"name": "right", "at": Vector3, "facing": Vector3, "kind": "wall_end", "mode": "end"}
```

- **mode `end`**: two ends meet at the same point with opposite facings (`pose_onto` gives the turn).
- **mode `post`**: a column's axis on the ground. Same x and z, turn free, and the piece seats on its own ground.
- **mode `top`**: any piece's foot (its origin) stands there.

`MATES` pairs the kinds: column with column, wall_end with wall_end, channel with channel, aq_pier with aq_pier, flight_top with flight_foot. `node`, when given, supplies what its seed decided: a broken pier's or worn wall's top, a stump's `height` meta.

| piece | connectors (from the Scale constants) |
|---|---|
| pier | `foot` column (0,0,0); `top` at SPRING (or its broken top) |
| arch | `left_springer`, `right_springer` column at ±(ARCH_SPAN/2 + ORDER), its own two piers |
| wall | `left`, `right` wall_end at ±WALL_LENGTH/2; `top` at WALL_HEIGHT (or its worn top) |
| lancet_wall | `left`, `right` wall_end at ±WINDOW_WALL.x/2 |
| stairs | `foot` flight_foot (0,0,+run/2) facing +Z; `landing` flight_top (0, STEPS*RISER, -run/2) facing -Z |
| aqueduct_span / two_tier | `left`, `right` channel at ±SPAN/2, DECK (two-tier: DECK_HIGH) |
| aqueduct_broken | `left` channel; `fallen_pier` aq_pier at +SPAN/2 (where a stump goes) |
| aqueduct_stump | `foot` aq_pier; `top` at its height |
| aqueduct_end | `channel` at (0, DECK, 0) facing +X |
| tomb_chest | `top` |

The same file also has:

- `lip_near(g, p, reach, outline, highest)`: the nearest cliff lip, where the ground falls at least 1.2 m within 1.2 m. The isle's own edge counts as a lip.
- The run planners and builders: `aqueduct_plan` / `aqueduct_run`, `wall_plan` / `wall_run`, `bridge_run`, `build_run`, `run_box`.

Hall, tower, horn, cloister and belfry pieces have no connectors yet.

## File format (still `format` 3; old files load and build unchanged)

These are additive keys. A file without them builds exactly as before, and `editor_hill`, `editor_mountain` and `editor_tarn_peak` smoke PASS.

```json
"pieces": [{"id":"arch", ..., "on": {"to": 0, "c": "foot", "mine": "left_springer", "at": [0.486,-0.022,4.494], "turn": 276.2, "stand": true}},
           {"id":"aqueduct_span", ..., "fit": true}],
"runs": [{"run":"aqueduct","from":[-21.0,7.0],"to":[24.0,7.0],"seed":6928,"weathered":0.3},
         {"run":"bridge","from":[-4.0,-5.0],"to":[12.01,-9.53],"seed":138}]
```

- **`on`**: the piece follows piece `to` (always an earlier index). `at` and `turn` are in `to`'s frame. With `stand`, it keeps only the x, z and turn from it and seats on its own ground. `motif_authored.gd` `pose_of` resolves this on every build, so a snapped group follows its root when the land under it changes. Deleting a piece frees the pieces on it (they stand where they are) and re-indexes the rest.
- **`fit`**: an aqueduct piece built with the land as its `ground`, so its piers grow down into the ground (`motif_authored.gd` `fitted`). New aqueduct pieces get it.
- **`runs`**: one entry per run. Only the ends' x and z are stored. Every build re-plans the run on the land as it is then (`make_run`, built into Pieces as `Run<k>`), and occupancy counts each run's box (`run_box`).
- **The aqueduct plan:**
  - A head (`aqueduct_end`) at `from`, and spans every SPAN (11.1 m) toward `to`. The far end snaps to a whole number of spans.
  - A second head stands turned round at the far end.
  - The deck is level at DECK over the lowest ground, capped at DECK/2 over the higher end, and always at least 1 m over the ground between the heads.
  - A span whose ground falls more than DECK + 2 m below the deck is two-tier.
  - Each span's piers grow down into the ground under it.

## What works (proven)

**`scratch/r4_drive.gd` passed 31/31 headless.** It uses real `Input.parse_input_event` mouse and key events. The palette's drag-out is entered through `begin_ghost`, the call the palette makes, which round 3 proved by mouse. The checks:

- A pier, then an arch whose ghost snaps onto it (the ring shows). Set down, one of the arch's piers stands on the pier (0.000 m off).
- A second pier snaps under the arch's free springer and stands where the arch's pier stands. All three sit on the land (gaps -0.15 m: sunk, not floating).
- A second wall snaps to the first wall's end, and they meet end to end. A pier stands on the second wall's top at the top's height.
- A ravine drawn across the isle gives the valley: floor -6.3 m, banks 4.9 and 6.5 m.
- An aqueduct run is pressed and dragged across it. It is one recipe entry: 4 spans and 2 heads, deck 10.4 m. Every pier reaches into the ground.
- A mountain stamp under its west half: the run re-plans on the new land (deck 16.6 m, the two deep spans now two-tier) and every pier still reaches the ground.
- A rope bridge, by two clicks, between the ravine's lips. Both ends are on lips.
- Ctrl+Z takes the bridge back and Ctrl+Shift+Z returns it.
- Save, then reload, gives equal data, and both runs stand.
- P plays. He walks the aqueduct's channel end to end on the deck, then across the rope bridge. P goes back to editing.

**`scratch/r4_make.gd`** (same input path) built **`editor_aqueduct_gorge`**: a ravine, an aqueduct run, a rope bridge, and pier + snapped arch + snapped pier. It's registered as `scripts/kit_isle/greybox/au_editor_aqueduct_gorge.gd`, with one line in `registry.gd`.

**Smoke checks**, all PASS:

- `motif_editor.tscn`
- `motif_editor.tscn --load=editor_aqueduct_gorge`
- the yard with `sundered_gorge`, `rootbound_cut`, `editor_tarn_peak`, `editor_aqueduct_gorge`, `editor_hill` and `editor_mountain`

**Rendered**, one window per run, looked at frame by frame:

- **Sheet: `scratch/shots/r4_sheet.png`.** Four fixed cameras: arch group, walls, valley/aqueduct, bridge. Each shows before, mid-drag (the snap ring and gold ghost, or the run's line) and after.
- `scratch/shots/r4_palette_tiles.png` (the tile grid).
- `scratch/shots/r4_yard_three.png` (the new motif in the yard).

What the frames show:

- The arch's foot is on the pier and the second pier is under its far springer.
- The aqueduct deck is level, both heads stand on the banks and the piers go down into the ravine.
- After the stamp, the run is lifted over the mountain with two-tier spans in the middle.
- The bridge hangs anchor to anchor across the ravine.
- Outside each edit, the land and plants match the frame before.

## Timings (headless, this Mac)

| | |
|---|---|
| an aqueduct run of 4 spans + 2 heads, fitted | ~800 ms, one hitch on release (built on the main thread) |
| one fitted aqueduct span | ~190 ms |
| a rope bridge run | ~6 ms |
| snap search per mouse move (6 pieces) | well under a frame, not separately timed |
| dress with the run on the isle | ~1.8 s (was ~0.5 s without it: the run is rebuilt with the land) |

## Missing or stood in

- **The re-fit can be big.** A stamp that rises over the deck lifts the whole deck over it. The re-plan is honest, but the aqueduct becomes a tall wall (the sheet's after-stamp frame), and the stamped mountain still fills the lower arches. A per-run "deck" override, or a break where the land stands over the deck, would read better.
- **Only aqueduct runs show a preview of their pieces** (ticks on the line). No run shows a ghost of the whole run before release; the build hitch (~0.8 s) is why.
- **Runs aren't snap targets.** A loose span can't be snapped to a run's end, although the run carries `ends` meta for it. Runs can't be moved after placing (trash and draw again).
- **The arch's springer connectors are at its feet** (its own piers). An arch set on a pier stands its own pier inside the placed one. That reads as one column, but it is double stone. A weathered (broken) placed pier shows the arch's whole pier.
- **No snap preview of a fitted aqueduct piece.** A free-placed or channel-snapped aqueduct piece is built `fit` on release, so its piers reach the ground then. The ghost shows the plain piece.
- **Lip finding is a grid search** (0.5 m, 12 directions). On stepped ravine walls a wall lip-snaps to the nearest step. Bridges take the highest lip, so they span bank to bank.
- **Thumbnails** are lit brighter and read by eye, but the stone renders lighter than in the world. Its look depends on the scene's global shader parameters, which the thumbnail's own world lacks.
- **Not mapped:** connectors for the hall, tower, horn, cloister and belfry pieces, the floor and grand stair, and the buttress against a wall face. Stacking works for any of them through the ray-to-top fallback.
- **Tests:** no committed test covers the editor. None was run beyond the smokes, so no test is known to break.
- **Scratch tools:** `scratch/r4_drive.gd`, `r4_make.gd`, `r4_tiles.gd`, `r4_pal.gd` (Ctrl+K, typing "aqueduct run" or "bridge", then Enter takes the tool: 2/2) and `r4_probe.gd`.

## Round 5 (load any motif, copy, edit), first

1. **Read a kit or greybox motif into editor data.** Its land becomes a `stamp`/`fill` recipe over a preset, or its KitLand spec stored raw as a new `"land":"spec"` preset. Its RuinKit placements become `pieces` with `on` links where two placements share a connector point (`RuinKitFit.connectors` makes that test cheap). Aqueducts laid with `ruin_kit_aqueduct.gd` `run` become `runs` entries.
2. **Add "Open as copy"** in the palette's World pocket: `--load=<any registry slug>`, a new slug on save, and the original untouched.
3. **Make a run editable after placing:** drag its end handles (re-plans live), a per-run deck height, and snap loose pieces to a run's `ends`.
4. **Add connectors for the hall, tower, cloister and belfry families**, so their motifs load with their links intact.
