---
name: motif-turf
description: Dress a motif the user picked into its finished form (growth, wear, life, budget), or remake an old grey-box motif as a place on the real terrain and look (KitLand, RuinKit). Use when the user asks to turf, promote, dress or make real a motif.
---

# Motif dressing pass

Stage 3 of the motif pipeline (docs/design/motifs/motif-brief.md, "From
card to isle"). Two inputs, two jobs:

- **A place motif** (from `/motif-greybox`, already on KitLand with its
  card's "Place" section): dress it. Growth, wear, life, the model budget.
  Its land, routes and threat stay.
- **An old grey-box motif** (boxes tuned so chains land to the
  centimetre): remake it on KitLand. Give it a landform, and let tier
  heights, edges and hazards move to suit it. Its routes are re-walked.

Either way the motif lives in one data table, in `studies/greybox/<slug>.gd`
(a round 1 study only) or as `scripts/kit_isle/greybox/gb_<slug>.gd` on
`motif_greybox.gd`. If it is a `gb_` motif, work **in place** in
`gb_<slug>.gd` and answer the base's turf hooks: `turf_seed()`,
`turf_islands()` (KitLand specs plus `name`), `turf_paths()`,
`turf_cost()`, `dress(root)` for the stone and water, and `grey_flag()`
(`--giant-grey` style) for the A/B grey path. The base then builds the
islands with their sides collided, adds their keels to the occupancy and
answers `warm`, `flora_site`, `flora_seed`, `life_script` and
`build_cost` (gb_plumb_well.gd is the small example). Override `build`
only where the land diverges, and ask KitLand for `"collide_sides": true`
there. Keep `parts()`/LAYOUT as the data the occupancy is computed from.
Never change `motif_greybox.gd` for one motif.

1. One agent per motif. **Opus** for a remake (terrain and routes move
   under the real motor) or when it needs a new kit piece, collision or
   motor/trap change; **Sonnet** for dressing a place motif whose land,
   routes and threat stay (looks; AGENTS.md, Subagent models). Brief it to
   shoot the arrival view (`python tools/shot.py studies/motif_yard.tscn
   --frame Motif_gb_<slug> --view three -- --motif=<slug> --sky`) before
   and after, and to iterate on what it sees.
   A pass that spans several stages runs as an `/iterate` loop: this
   skill's steps are its spec's rules.
2. Split a grey-box motif into **ground** and **body**:
   - Ground (walked tiers: pads, terraces, ledges, decks, catches) becomes
     `KitLand.island(spec)` islands: an outline (one simple polygon each;
     a gap between tiers means a separate island), a ground function that
     shapes the landform (a remake may tilt, slope and merge the greybox
     tiers; keep flat what is walked flat on purpose), a
     `cliffs` box over the steps, `hang` true, a keel. Steps of a set-off
     (1.6 m) or so stay terrain: the kit's prisms make the lips grabbable.
   - Body (anything the climb kicks off or needs plumb: shafts, chimneys,
     walls that are wall-kicked, columns used as cover) stays a **walk
     box**, drawn as stone; as little of it as the routes need. Where terrain meets
     a plumb stone wall, step the terrain up *inside* the stone (about 1 m
     behind its face) so the kit's leaning cliff face is hidden in it.
   - Stone: RuinKit pieces first.
     `scripts/kit_isle/greybox/giant_stone.gd` draws plain blocks in the
     Olmec basalt (vertex colour as the head's, rest place in UV/UV2, a lit
     rune band via CUSTOM0/1). Pieces the kit lacks stay labelled
     stand-ins.
   - Build from the kit, not motif-local geometry. GDScript runs one thread
     at a time across the process, so isles only build in parallel where
     the work is in the kit's shared paths (RuinKit, KitLand, ruin_lod,
     late_shapes), which `perf/native-isles` moves into C++ kernels for
     every motif at once. A motif's own script stays light: layout and
     placement. Heavy bespoke geometry (long loops over vertices, strands,
     scatter) becomes a new kit piece any motif can reuse, or gets its own
     kernel. Don't leave it in the motif. No work per shader parameter on a
     worker either: each one waits a rendered frame.
3. Size the routes from the pilot's numbers (AGENTS.md, Sizes). Measure,
   don't assume: a throwaway probe
   (build the motif alone, raycast) for tier heights and edges. What the
   kit moves: the outline is resampled with ±0.35 m wobble, so an island's
   walked edge sits within about ±0.25 m of the outline; a cliff face
   leans out 0.15-0.25 m at its foot (1.6 m step) to 0.5-0.75 m (6 m), its
   lip stays put; the sides push out up to 0.4 m under the lip. Rays that
   start inside a walk box pass through it (Jolt): probe from above.
4. The occupancy: the islands' keels come from `turf_islands()` (at the
   spurs' reach, 1.4 x depth under the top); add any other body hanging
   under its greybox base in `_solids` (`super._solids()` first).
5. Flora and life come almost free: `turf(land)` each island, a
   `flora_site` with worn paths, and `life_script` the plain
   `scripts/kit_isle/kit_life.gd` (undergrowth, butterflies, fireflies,
   wind; no birds or tokens until the isle has perches and moves).
6. Prove it headless. Smoke first with `python tools/smoke.py` (it runs
   the import if needed). The checks are drivers on
   `tools/harness/drive.gd` (tools/README.md), with seeds and grey/turf as
   `tools/sweep.py` axes. Then the routes, **in the motif yard** (`studies/motif_yard.tscn
   --motif=<slug>`, tools/README.md "The motif yard"): a driver on
   `tools/harness/drive.gd` that walks each route rim in to rim out through
   the input (`tools/harness/chain.gd`'s trials and jitter help: ±0.5 m
   start), and checks every trap and enemy builds and ticks (helpers:
   `route()` / `walk_motif_paths()`, `watch()`, `ray()` / `what_is_at()`; `python tools/drive.py --api WORD`). Long runs go
   through `tools/bg.py`, one heavy run at a time. Rendered stills to judge the
   look: `python tools/shot.py` (one
   window, watchdog-closed; AGENTS.md, Test execution).
7. Assess docs/art/model-budget.md for the new geometry (AGENTS.md,
   Models): count triangles per part from the built node, collision shapes,
   build ms (and how much of it is the motif's own GDScript rather than the
   kit's). Uncommitted until the user locks it in.
