# Motif editor, round 3: the old game's UI (handoff)

> 2026-10-14. Round 3 of docs/design/motif-editor/level-editor.md ("Round 3:
> the old game's UI"). Nothing committed.

## Run it

```
godot --path . res://studies/motif_editor.tscn -- --no-title [--load=editor_tarn_peak]
godot --path . res://studies/motif_yard.tscn -- --no-title --motif=editor_tarn_peak   # the motif form, in the yard
```

## Controls

| | |
|---|---|
| **Tool roll** (left edge, linen) | click a pocket to take its tool; click the held pocket again to put it down (Select). The fan beside a pocket picks its mode. The three pips set the size (brush radius 3 / 5 / 8.5 m) |
| Modeller pocket | modes Pinch = Raise, Groove = Lower (round 2's brushes) |
| Paddle pocket | Plane = Smooth, Pat = Flatten |
| Hills, Mountain, Crater, Chisel (mesa), Island (Spread) | **stamps**: click the ground, drag out to size, let go. Strength sets how tall (a crater: how deep). An island stamp can start past the edge: the outline grows round it |
| Island, Draw mode | **new land**: draw a loop out past the edge. The isle grows to it, built up to the old land's height |
| Ravine pocket (the old "wire") | draw a **line**: a ravine, cut behind a running head after you let go. Draw a **loop** (ends within 5 m): a **lake**, dug and filled in one go. Strength is depth |
| Watering can | click a hollow to pour a pond (Shift+click takes one away), as in round 2 |
| Trash can | click a piece, a stamp's middle, a pond (and its basin) or a lake's or new land's loop to take it away |
| Feather, Brush pockets | not in the editor yet (they refuse, with the old "not yet" cue) |
| **Cmd/Ctrl+K** or `/` | the palette. Type to search; Tab or the pockets switch between All, Land, Kit, Trees, Landforms and World; Enter or click takes it |
| palette piece row | **drag it out into the world**: its ghost follows the ground and is set down where you let go. A plain click takes it instead (then click the ground; Shift keeps placing) |
| palette World | Undo, Redo, Save, Play, Dress, Re-roll, Frame, and "Open <slug>" for each saved motif |
| **Landform panel** (top left) | the name field and Save, the landform list, its sliders, the seed, Re-roll and Dress |
| bottom strip | the hint for the tool in hand, what just happened, and the Strength slider |
| keys from rounds 1 and 2 | 1-8 (select raise lower smooth flatten ravine water outline), P / Shift+P, Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y, Ctrl+S, G, Z X turn, Delete, `[ ]` and wheel for radius, Esc (now also puts the tool down), RMB look, WASD QE fly |

## Reused, re-pointed, left

**Reused as-is (one small edit):**

- `scripts/tool_roll.gd` (the HUD 4c linen roll): its pockets, mode fans, size pips, hover and reach, and sound cues. The editor reads `tool_at`, `mode_at` and `pip_at` as `hand_materials` did. It's placed under the panel by sizing its rect.
- `scripts/command_palette.gd` (the linen palette): its search, pockets, rows, keys and look. One edit: the pockets come from `tabs()` / `tab_icons()` (it was the `TABS` const), so a subclass can have its own. The game behaves the same, and `test_hand_flowers.gd` passes. `studies/motif_editor_palette.gd` subclasses it. It adds editor items, a thumbnail per piece row and the drag-out.
- `scripts/hud_linen.gd` (cloth shader, stitches, fonts) and `scripts/hud_icons.gd` (every pocket, mode and pocket icon).
- `scripts/clay_sound.gd` and `scripts/clay_tremor.gd` over `scripts/reference_tremor.gd`, unchanged. `studies/motif_editor_feel.gd` stands in for the clay they listen to (its `state`, `tool_id`, `tool.lift`, the wire's `busy` / `cut_share`, and `sounded`).
- The thumbnail renderer is copied from `native_build_palette.gd` `_render`: a small lit world per piece, rendered once from the real mesh.

**Re-pointed (each old clay tool's effect is now a recipe entry):**

- Mountain, Hills and Crater become `stamp` strokes. Chisel's Mesa becomes a `stamp` with a level top. Island's Spread becomes a `stamp` plus an outline union. Island's Draw becomes a `fill` loop plus an outline union.
- Ravine/wire: a line becomes a round-2 `ravine` stroke. A loop becomes a `basin` stroke plus a `waters` entry. The old wire's "watch the cut run" is kept: the stroke's points are fed in behind a head (0.45-1.6 s) with live rebuilds, and the grind sound and tremor run while it goes.
- Can becomes round 2's pour. Trash becomes take-away. Modeller and Paddle become round 2's brushes.

**Left:**

- NativeBuildPalette's tile grid, sky tab and tool rail. They are tied to NativeChunkEditor; the linen palette replaces them. The palette rows carry the thumbnails and the drag.
- The god hand, `hand_materials`, the materials tray and the almanac.
- `stroke_feedback.gd`. It's wired to the chunk editor's stroke signals and the plants' `zs_growth_wave` slots, which KitLand flora doesn't use. A placed piece pops in instead (scale 0.55 to 1 with an overshoot, plus a knock or a rustle).
- Not mapped yet: Feather, Brush (paint), Hammer, Chisel's shelf/notch/slice, Mountain's and Crater's draw (range) modes, and Bowl and Sculpt's hills (the stamps cover them).

## What works (proven)

**`scratch/r3_drive.gd`** passed 23/23 headless. Everything went through real `Input.parse_input_event` mouse and key events:

- Ctrl+K opens the palette. Typing "mountain" and Enter takes the Mountain stamp.
- A drag stamps a mountain and sizes it: r 11.3 m, the ground rose 5.0 to 11.4 m, with 4 live rebuilds while sizing.
- Clicking the roll's Ravine pocket takes the tool.
- A drawn loop becomes a lake: 3.2 m deep, holding water.
- A drawn line carves a ravine.
- Dragging the "pier" row out of the palette shows its ghost, and letting go places it.
- Ctrl+Z / Ctrl+Shift+Z undo and redo it.
- Save, then reload, gives equal data (compared through JSON).
- Keys 5 and 1 still pick Flatten and Select.
- P plays and he walks 4.0 m. P goes back.

**`scratch/r3_make.gd`** built **`editor_tarn_peak`** through the same input path: a mountain stamp, a hills stamp, an island stamp off the south edge (the outline grew to 34 points), a tarn loop, a ravine, a crater stamped and then trashed, and 5 pieces. It's registered as `scripts/kit_isle/greybox/au_editor_tarn_peak.gd`, with one line in `registry.gd`.

**Smoke checks** all PASS:

- `motif_editor.tscn`
- `motif_editor.tscn --load=editor_mountain`
- `motif_yard --motif=editor_tarn_peak`, `editor_mountain`, `editor_hill`

**Rendered stills** in `scratch/shots/`:

- `r3_ui.png`
- `r3_palette.png`
- `r3_palette_search.png`
- `r3_roll_modes.png` (editor_tarn_peak with the Modeller's fan out)
- `r3_yard_three.png`

The UI reads as the game's linen: the roll, the top strip, the palette, the panel and the bottom strip. None of it is Godot's grey.

**Cursor:** in a real window (`scratch/ui_shots.gd`, `--rendered`), `Input.mouse_mode` was VISIBLE in edit mode after walk-ready and after the palette opened and closed. Round 2's `_hold_mouse` still holds. The pointer moves were script warps, not a hand on the mouse (macOS drops synthetic OS clicks, as round 2 found).

## Timings (headless, this Mac)

| | |
|---|---|
| live rebuild while sizing a stamp or running a cut | 19-25 ms |
| dress after a stamp, lake and ravine (whale-back 64 x 40) | ~540 ms |
| lake (basin + pour + dress) | one step, ~0.6 s |
| thumbnails | 3 per frame once the palette is first open (none headless) |

## Format changes (format 3; format 1 and 2 files still load)

New entries in `strokes`, applied in order with the brushes:

```json
{"tool":"stamp","form":"mountain|hills|crater|mesa|island","at":[x,z],"r":11.31,"h":7.92,"seed":3587,"y":6.1}
{"tool":"basin","pts":[[x,z],...],"depth":3.2,"bank":3.0}
{"tool":"fill","pts":[[x,z],...],"y":4.2,"bank":2.0}
```

- `y` is only on mesa and island stamps (the level top).
- A lake is a `basin` plus an ordinary `waters` entry.
- The island stamp and new land also write `outline`, as a hand-dragged outline is written.
- An older reader would ignore the new tools (Sculpt's `match` falls through).
- `format` now writes 3.

## Missing or stood in

- **Thumbnails read small and dark.** The stone shader is lit in its own world with no global look parameters, and the arch is thin at 48 px. It needs the scene's look (or a lighter material pass) and a bigger tile. NativeBuildPalette's tile grid would show them better than rows.
- **Stamps on a terraced landform terrace too.** Whale-back's Cliff step (1.6) bands every height, so a mountain stamp reads as a stepped cone (see the still). Set the step to 0 for smooth peaks. A per-stamp "no terrace" flag would fix it.
- **Mountain and Crater "draw" (range) modes aren't mapped.** Neither is a stamp's own shape after placement: drag the middle to move it, or re-size it. You can only trash it and stamp again.
- **The trash leaves an island stamp's outline grown.** Pull it back with the Outline tool.
- **Mode fan with no modes.** Hills, Mountain and Crater show their name tag. The Chisel shows "Chisel" while it is a mesa stamp.
- **Not proven headless:** the panel's sliders by mouse (round 1 proved them; the panel is new controls on the same calls) and the roll's pips.
- **Sound** plays only where `assets/audio/foley` has takes. The tremor is the old feel. Neither can be judged headless.
- **Round 2's drivers** (`scratch/terrain_drive.gd`, `editor_drive.gd`) reach for the old panel's `_preset_pick` and `_palette`. They're scratch, so they're left broken. No committed test covers the editor.

## Round 4 (pieces that know how to fit), first

1. **Connectors as kit data** next to `RuinKit.piece`: an aqueduct span's two ends, an arch's springers, a wall's ends, a rope bridge's anchors. Put them in the kit, not the editor.
2. **Snap the dragged ghost** (already in place: `ghost_to`) to a free connector under the cursor, turned to match, and seat it on the higher of the ground and the piece below. The ghost is the natural place to preview the snap.
3. **Fill a run** between two clicked points with spans that follow the ground. Store it as one recipe entry (`{"run":"aqueduct","from":..,"to":..}`) so it re-fits when the land changes.
4. **Snap to cliff lips**: ravine walls and the lake's banks are real lips now.
5. **Give the palette a tile grid view** for Kit and Trees (larger thumbnails, lit with the scene's look), so pieces are picked by eye.

## Follow-up: stamps changed the whole isle (fixed)

**The user's report:** "If I use the mountain tool, it doesn't actually create a mountain there... it just kind of does stuff to the entire thing."

**The cause:** a stamp's radius came from how far the pointer ran over the ground plane while dragging. The natural gesture, pressing and pulling up the screen (the old Mountain's pull), runs far over the ground at a three-quarter view. About 200 px of pull made a 25 m-radius mountain on a 64 x 40 isle, and longer pulls hit the 60 m cap. So the change stayed inside its own footprint, but that footprint was the whole isle, and it was bigger than the 10 m ring shown before the click.

A second bug: the mesa and island stamps read their level off the live land, which already held the stamp. Each drag frame stacked another height on top (+40 m).

**The fix:**

- The footprint is the ring you see (twice the brush radius: the pips, the wheel, `[ ]`). It never follows the pointer, and is capped at 40 m.
- Dragging only sets the height: pull up for taller, and for a crater drag down to dig deeper (160 px doubles it, between 0.25x and 3x).
- The ring stays on the footprint while you size it.
- A mesa's or island's level is read once, before the stamp.

**Proof:** `scratch/r3_local.gd` uses real mouse input, the stamps pulled up the screen. It samples the ground on a 2 m grid (~860 points) two ways: the recipe, and rays on the built land. It runs before and after each tool, then undoes.

Change outside the footprint and its falloff (stamp: r x 1.3 + 2 m; lake: the loop + 2 m; ravine: its walls' reach from the line), and the peak change inside:

| tool | outside, recipe | outside, built land | inside peak |
|---|---|---|---|
| mountain | 0.00 | <= 0.23 m, at 3-5 cells | +12.4 to +13.1 m (a peak) |
| hills | 0.00 | <= 0.17 m | +4.1 to +9.6 m |
| crater | 0.00 | <= 0.17 m | -0.9 to -1.5 m (pulled up, so shallow; drag down digs) |
| mesa | 0.00 | <= 0.12 m | +9.5 to +10.1 m |
| island | 0.00 | <= 0.11 m | +1.6 to +2.3 m |
| lake | 0.00 | <= 0.15 m | -4.6 to -4.8 m, holding water |
| ravine | 0.00 | <= 0.21 m | -8.0 to -8.5 m |

These numbers hold on cliff step 1.6 (whale-back's default) and on step 0. On step 0, every tool except the ravine changes the built land by exactly 0.00 outside. A ravine switches the whole isle to its finer crisp-cliff grid, so the built land shifts by up to 0.15 m at 72 cells. On step 1.6, the built land moves up to about 0.2 m at a few far cells: the mesh is rebuilt and resampled.

Stills: `scratch/shots/r3_local_sheet.png` (before, one mountain, then a lake, from above).

**Still off:**

- On a terraced landform (cliff step > 0) a mountain reads as a stepped cone, because the step bands every height.
- A placed stamp can't be moved or resized.

## Follow-up 2: the look re-rolled everywhere (fixed)

**The user's report:** "It doesn't draw just the spot that I mean it to draw. It's like it does a reroll." The heights were local, but the look wasn't.

**The cause:** one sequential rng in `KitLand.island` fed, in turn:

- the outline's resample
- the cliff points
- the grid jitter
- each face's shimmer
- the hanging sides and keel

A stamp adds cliff points, so it uses up extra draws and every later draw shifts. That re-rolled the whole isle's triangulation, turf colour and underside.

The flora (`KitFlora.Grow` and `Undergrow`) drew its candidates the same way, so one refused plant moved every plant after it. The undergrowth also stopped once enough were placed, which moved the tail.

The keel and sides also hung from `crest_top()`, so a mountain moved the whole underside.

**The fix** is opt-in, and off by default:

- **`KitLand`, spec key `stable`:** `KitLand.pin(rng, p, salt)` reseeds the rng from the isle's seed and the point's position before that point's draws. It's applied to resample points, cliff points, grid cells (on a world-aligned lattice), face shimmer, side rings, rock facets and the keel. Without the flag `pin` returns at once, so existing isles build as before.
- **`KitFlora.Site.stable`:** each candidate is seeded from the seed, the phase and its index. In stable mode the undergrowth runs a fixed number of candidates per kind (3 tries for each plant wanted) instead of "until placed". The total plant count is within about 2% of the old one. `MotifIsle.placed_site` now copies `stable` (it was dropping it).
- **`motif_authored.gd`:**
  - turns both flags on;
  - the keel and sides hang from `keel_top()` and `depth()`, read off the landform's raw ground (no strokes);
  - a ravine no longer changes the whole isle's grid cell (it was 1.8 m whenever a ravine existed, else 2 m);
  - `ravine_box()` is tightened to where the ravines really lowered the ground, plus 1.5 m. It was the wall's worst case, about 16 m out from the line.

**Proof:** `scratch/r3_seen.gd`, real mouse input. It looks at the land meshes' vertices (position and colour) and every plant record (asset, position, angle, scale) before and after each edit. "Outside" means beyond footprint + falloff. Then it undoes.

| edit | cliff step | land vertices outside: moved / new | recoloured | plants outside: gone / new |
|---|---|---|---|---|
| mountain stamp | 1.6 | 0 / 0 of 4,024 | 0 | 0 / 7 of 3,342 |
| lake | 1.6 | 0 / 0 of 5,378 | 0 | 0 / 1 of 4,672 |
| ravine | 1.6 | 0 / 0 of 4,278 | 5 | 0 / 0 of 3,842 |
| mountain stamp | 0 | 0 / 0 of 824 | 0 | 7 / 0 of 3,910 |
| lake | 0 | 0 / 0 of 957 | 0 | 12 / 3 of 5,413 |
| ravine | 0 | 1 / 13 of 844 (all within 0.3 m of the ring) | 27 | 9 / 0 of 4,402 |

Before this fix, about 600-780 plants outside changed on every edit, and the land's grid, colours and underside re-rolled.

The plants that still change are undergrowth at feet and rims just past the ring: `_at_foot` probes the new slope's foot.

Stills: `scratch/shots/r3_stable_sheet.png` (one camera, before and after one mountain stamp). Outside the ring the terraces, edge, colours and underside match.

**Existing motifs:**

- The yard smoke passes for `rootbound_cut`, `bell_spires`, `editor_mountain`, `editor_hill` and `editor_tarn_peak`.
- `test_cluster_motifs` and `test_kit_isle_landing` pass.
- `test_motif_families` (the fingerprints of colonnade_spine and broken_ring) and `test_motif_sky` (dragon_roost, a Nil `tokens`) fail. `test_motif_families` fails the same way with the committed `kit_land`, `kit_flora` and `motif_isle` swapped in, so it predates this round. `test_motif_sky` wasn't re-run against the committed files; its Nil is in the dragon roost, which this round's changes don't touch.

**Changes to the saved motifs' look:**

- The authored motifs' keels are now sized from the landform alone.
- Their jitter is now pinned, so `editor_hill`, `editor_mountain` and `editor_tarn_peak` look slightly different from before (the same land, re-rolled once).

## Live editing: an edit looks like an edit (fixed)

**The user's report:** "Every click just makes the scene unrecognizable." While a Hills stamp was being dragged, the whole isle turned into a coarse, flat-shaded mesh with grey rock splattered over it. After the release the hill came back as a stack of terraced rings, and the sky had gone dusky brown.

**1. The live preview swapped the whole isle.**
- *Cause:* every drag frame ran `rebuild_bare(true)`, which freed the dressed stand and built the whole isle again on a 1.5 m grid with no crisp cliffs and no plants. On that coarse grid the noisy faces went over the rock slope, which made the grey shards. The release then dressed the isle again from nothing.
- *Fix (`studies/motif_editor.gd`):* the dressed isle is left alone while a stamp, brush stroke or ravine cut runs. The edit shows as a **ghost** (`update_ghost`): the new ground sampled on a 0.5 m lattice over the edit's box, wherever it differs from the land on screen. It is smooth-shaded with a contour line every metre, and it fades in with the size of the change. Raised ground is a sand-coloured ghost drawn on the land. Lowered ground (crater, ravine) is a blue ghost seen through it. On release, `dress()` builds the new stand hidden and keeps the old one on screen with its collision off (`_retire`), so the pilot, rays and new plants only find the new land. `_swap_step` swaps the two once the new stand's plants have grown. No undressed or coarse frame is ever shown. An outline handle drag now moves only the handles and their line, then dresses on release. Slider drags still use the full-quality bare rebuild, since a slider changes the whole isle anyway.

**2. Stamps came out as wedding cakes.**
- *Cause:* `ground_of` applied the landform's terrace to raw ground plus the strokes, so every stamp was banded by the cliff step.
- *Fix (`motif_authored.gd`):* Mountain, hills, crater and lake-basin stamps write a **smooth mask** (`Sculpt.smooth`: 1 inside, fading out from 1.05 to 1.25 r, or across a basin's bank). Under the mask the terrace gives way to the stamp's own slope, and no terrace cliff is laid there (KitLand's new opt-in `cliff_skip`). Mesa and island stamps keep the steps, so their sides stay cliffs. Ravine walls are untouched. Two more changes:
  - Under the mask, turf holds up to 1.45x the rock slope (KitLand's new opt-in `rocky`), so a hill on the landform's fall stays green. A mountain's flanks still go to rock.
  - Each hill bump is now capped at 0.28 x its radius, 0.4 to 0.6 r wide. These make rolling hills, not spikes.
- Without the new spec keys, KitLand builds exactly as before.

**3. The sky turned while editing.**
- *Cause:* the yard's base starts the live sky (`KitWeather`: the day turning, the weather drifting), and nothing held it in edit mode.
- *Fix:* `enter_edit` holds a look preset: `alpine_morning`, or `--look=<preset>`. `play` gives the live sky back, and returning to edit holds it again.

**Proof:** `scratch/le_drive.gd` uses real mouse input from one fixed camera, on cliff step 1.6 and on 0. It stamps hills, stamps a mountain, lassoes a lake and draws a ravine, with a shot before, mid-drag and after each edit (`--rendered`, one window).
- Sheet: **`scratch/shots/le_live_sheet.png`**. Rows 1-3 are step 0 and rows 4-6 are step 1.6. Read each set of three frames left to right.
- Outside each edit, the land, plants and colours match the frame before it.
- The sky strip's mean colour held to within 0.005 across all 18 frames, at hour 11.04 and not live.

**Timings (headless, this Mac):**

| | step 0 | step 1.6 |
|---|---|---|
| ghost update (each drag frame) | 9-14 ms (ravine 18-26) | 15-19 ms (ravine 17-25) |
| worst drag frame, stamps | 33-36 ms | 32-36 ms |
| release: the hidden dress (the one hitch) | 21-33 ms (ravine ~330) | 195-215 ms (ravine ~350) |
| release until the swap (old land and ghost still shown) | 0.55-0.85 s | 0.7-0.9 s |

**Checks:**
- Smoke PASS: `motif_editor.tscn`, `motif_editor.tscn --load=editor_tarn_peak`, and the yard with `sundered_gorge`, `rootbound_cut` and `editor_tarn_peak`.

**Still off:**
- **A ravine cuts what is near it.** Its stepped walls clip a mountain within their reach (the sheet's last frame of each step). This is the ravine's reach, not the preview.
- **The ghost is a ghost.** Plants and pieces inside the footprint stand at their old height until the swap.
- **The swap takes most of a second.** The old land and ghost show for 0.5-0.9 s after release, while the plants regrow out of sight.
- **Lake banks on step 1.6 are steep rock walls.** The bank is narrow for its depth.
- **Saved motifs with hills stamps change look.** `editor_tarn_peak` now has lower, rolling hills and no terraces under its smooth stamps.
- Slider drags still show the plant-less bare rebuild.
