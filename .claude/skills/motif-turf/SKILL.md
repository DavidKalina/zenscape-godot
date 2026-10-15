---
name: motif-turf
description: Dress a motif the user picked into its finished form (growth, wear, life, budget), or remake an old grey-box motif as a place on the real terrain and look (KitLand, RuinKit). Use when the user asks to turf, promote, dress or make real a motif.
---

# Motif dressing pass

Stage 3 of the motif pipeline (docs/design/motifs/motif-brief.md, "From
card to isle"; its first pillar, **a place first**: the original kit
motifs are the bar). Two inputs, two jobs:

- **A place motif** (from `/motif-greybox`, already on KitLand with its
  card's "Place" section): dress it. Growth, wear and collapse that tell
  its story, life, the model budget. Its land, routes and threat stay.
- **An old grey-box motif** (round 1: grids of boxes tuned so chains land
  to the centimetre): remake it as a place. The land leads: give it a
  landform and silhouette, break the grid, make it mostly land with stone
  on it, and let tier heights, edges and hazards move to suit the place.
  Its chains are not kept; its hazards and enemies are, set in loosely
  (brief, "anything could chain"). Its routes are re-walked, not its
  chains re-proved. The Sunken Giant's card "Turf pass" section is a worked
  example of the technique, not of the result (it kept the grid).

Either way the motif lives in one data table, in `studies/greybox/<slug>.gd`
(a round 1 study only) or as `scripts/kit_isle/greybox/gb_<slug>.gd` on
`motif_greybox.gd`. If it is a `gb_` motif, work **in place**: override `build` (and `warm`, `flora_site`,
`flora_seed`, `life_script`, `build_cost`, `_solids`) in `gb_<slug>.gd`,
keep `parts()`/LAYOUT as the data the occupancy is computed from, and keep
the grey path behind a flag (`--giant-grey` style) for A/B checks. Never
change `motif_greybox.gd` for one motif.

1. One agent per motif. **Opus** for a remake (terrain and routes move
   under the real motor) or when it needs a new kit piece, collision or
   motor/trap change; **Sonnet** for dressing a place motif whose land,
   routes and threat stay (looks; AGENTS.md, Subagent models). Brief it to
   shoot the arrival view beside an original kit motif (`python
   tools/shot.py studies/motif_yard.tscn --frame Motif_sundered_gorge
   --view three -- --motif=sundered_gorge --sky`) before and after, and to
   iterate until it sits beside it.
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
     box**, drawn as stone; as little of it as the routes need, broken and
     sunk into the land rather than stacked on it. Where terrain meets
     a plumb stone wall, step the terrain up *inside* the stone (about 1 m
     behind its face) so the kit's leaning cliff face is hidden in it.
   - Stone: RuinKit pieces first (the kit motifs' stone language).
     `scripts/kit_isle/greybox/giant_stone.gd` draws plain blocks in the
     Olmec basalt (vertex colour as the head's, rest place in UV/UV2, a lit
     rune band via CUSTOM0/1) where the place is the makers'; weather and
     bury it so it reads as the same world. Pieces the kit lacks stay
     labelled stand-ins.
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
4. The occupancy: add the keels (and any body hanging under its greybox
   base) to `_solids`, at the spurs' reach (about 1.4 x depth under the
   datum).
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
   start), and checks every trap and enemy builds and ticks. Long runs go
   through `tools/bg.py`, one heavy run at a time. Rendered stills to judge the
   look, beside the kit motif's (step 1): `python tools/shot.py` (one
   window, watchdog-closed; AGENTS.md, Test execution).
7. Assess docs/art/model-budget.md for the new geometry (AGENTS.md,
   Models): count triangles per part from the built node, collision shapes,
   build ms (and how much of it is the motif's own GDScript rather than the
   kit's). Uncommitted until the user locks it in.
