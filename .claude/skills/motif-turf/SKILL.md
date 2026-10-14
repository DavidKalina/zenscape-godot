---
name: motif-turf
description: Turn a greyboxed motif the user picked into a real kit motif on the real terrain and look (KitLand, RuinKit, the kit-isle study), the form the generator places. Use when the user asks to turf, promote, dress or make real a greybox motif.
---

# Motif turf pass

Stage 3 of the motif pipeline (docs/design/roguelike/motif-brief.md, "From
card to isle"). Draft, refined after the first turf round (the Sunken
Giant, 2026-10-13: its card's "Turf pass" section is the worked example).

Input: a greybox whose layout lives in one data table, plus its card (with
the "Greybox" section saying what worked). It lives in one of two places:
`studies/greybox/<slug>.gd` (a study only) or already in the generator as
`scripts/kit_isle/greybox/gb_<slug>.gd` on `motif_greybox.gd`
(docs/design/roguelike/greybox-in-generator.md). If it is in the generator,
turf it **in place**: override `build` (and `warm`, `flora_site`,
`flora_seed`, `life_script`, `build_cost`, `_solids`) in `gb_<slug>.gd`,
keep `parts()`/LAYOUT as the data the occupancy is computed from, and keep
the grey path behind a flag (`--giant-grey` style) for A/B checks. Never
change `motif_greybox.gd` for one motif.

1. One agent per motif, on **Opus** when the motif has chains to keep
   working on the new terrain (nearly all do; AGENTS.md, combos) or needs a
   new kit piece, collision or motor/trap change; **Sonnet** only for a
   motif with no chains that just assembles terrain and RuinKit pieces.
2. Split the greybox into **ground** and **body**:
   - Ground (walked tiers: pads, terraces, ledges, decks, catches) becomes
     `KitLand.island(spec)` islands: an outline (one simple polygon each;
     a gap between tiers means a separate island), a ground function that
     returns the greybox tier heights exactly (flat tiers stay exactly
     flat: heads, skids and landings are checked to the centimetre), a
     `cliffs` box over the steps, `hang` true, a keel. Steps of a set-off
     (1.6 m) or so stay terrain: the kit's prisms make the lips grabbable.
   - Body (anything the climb kicks off or needs plumb: shafts, chimneys,
     walls that are wall-kicked, columns used as cover) stays a **walk
     box** with the greybox's numbers, drawn as stone. Where terrain meets
     a plumb stone wall, step the terrain up *inside* the stone (about 1 m
     behind its face) so the kit's leaning cliff face is hidden in it.
   - Stone: plain chamfered blocks and cylinders are enough for a first
     turf; `scripts/kit_isle/greybox/giant_stone.gd` draws them in the
     Olmec basalt (vertex colour as the head's, rest place in UV/UV2, a lit
     rune band via CUSTOM0/1). RuinKit pieces where the kit has the right
     size (a tomb chest); pieces it lacks stay labelled stand-ins.
   - Build from the kit, not motif-local geometry. GDScript runs one thread
     at a time across the process, so isles only build in parallel where
     the work is in the kit's shared paths (RuinKit, KitLand, ruin_lod,
     late_shapes), which `perf/native-isles` moves into C++ kernels for
     every motif at once. A motif's own script stays light: layout and
     placement. Heavy bespoke geometry (long loops over vertices, strands,
     scatter) becomes a new kit piece any motif can reuse, or gets its own
     kernel. Don't leave it in the motif. No work per shader parameter on a
     worker either: each one waits a rendered frame.
3. Keep the greybox's distances. Measure, don't assume: a throwaway probe
   (build the motif alone, raycast) for tier heights and edges. What the
   kit moves: the outline is resampled with ±0.35 m wobble, so an island's
   walked edge sits within about ±0.25 m of the greybox edge; a cliff face
   leans out 0.15-0.25 m at its foot (1.6 m step) to 0.5-0.75 m (6 m), its
   lip stays put; the sides push out up to 0.4 m under the lip. Rays that
   start inside a walk box pass through it (Jolt): probe from above.
4. The occupancy: add the keels (and any body hanging under its greybox
   base) to `_solids`, at the spurs' reach (about 1.4 x depth under the
   datum). That changes the generator's plans *with the knob* (the next
   crossing can move); default plans must stay byte-identical (diff
   `LayerPlan.describe` with and without the knob, before and after).
5. Flora and life come almost free: `turf(land)` each island, a
   `flora_site` with worn paths, and `life_script` the plain
   `scripts/kit_isle/kit_life.gd` (undergrowth, butterflies, fireflies,
   wind; no birds or tokens until the isle has perches and moves).
6. Prove, headless, through the generator's own tick. Smoke first with
   `python tools/smoke.py` (it runs the import if needed). For the plan
   over seeds, use `python tools/sweep.py tools/layer_dump.gd --seed 1..10
   --shape sprawl,ring`. The checks are drivers on `tools/harness/drive.gd`
   (tools/README.md), with seeds and grey/turf as `tools/sweep.py` axes.
   Then the chain harness (greybox-in-generator.md's `check_layer.gd`), **one
   check per process** and both grey (`--giant-grey`) and turf in the same
   tree, so other sessions' changes hit both. On sprawl the run loop's void
   card lays a new layer when a trial falls: the harness must drop
   `study.run_loop` and set `plan.void_y` far down, or every trial after
   the first fall reads another layer. 10 trials a chain, ±0.5 m / ±0.2 s.
   Rendered stills to judge the look: `python tools/shot.py` (one window,
   watchdog-closed; AGENTS.md, Test execution).
7. Assess docs/art/model-budget.md for the new geometry (AGENTS.md,
   Models): count triangles per part from the built node, collision shapes,
   build ms (and how much of it is the motif's own GDScript rather than the
   kit's). Adding it to the generator's baked POOL is a separate step the
   user asks for. Uncommitted until the user locks it in.
