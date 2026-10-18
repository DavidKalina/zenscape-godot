# Terrace rock: a shared stepped-rock builder, and the Stair to the Clouds rebuilt on it

Loop `terrace-rock`, branch `iter/terrace-rock`. Model: Opus. Cap and budget:
the iterate skill's defaults.

## Why

The Stair to the Clouds mesa (`studies/stair_clouds_isle_art.gd`, `mesa`,
`dress_walls`, `facade`, `skirt`) is a hollow shell of separately built faces:
a KitLand heightfield turf, faceted wall facades hung along its steps, a skirt
under the rim, and grand stairs set in a 6.4 m strip beside the walls. Where
those faces don't meet you see into the hollow (orange turf triangles between
the rock slabs, sky through slits) and the walker falls into it. A patch round
(dropped, not merged) fixed corner slots, foot and lip slits, the apex hole at
O and invisible collision. The user still found gaps, including a 1 m slot
along the wall side of every flight. Its handoff and throwaway probes are in
the main checkout at
`/Users/davidkalina/Documents/Projects/zenscape-godot/scratch/stair-gaps-r1/`
(`stair-clouds-gaps-handoff.md`, `sc_probe.gd`, `sc_bump.gd`, `sc_flights.gd`
and the rest). Read the handoff before designing: it lists every fault class
that the new build must make impossible by construction.

## Done looks like

1. **A shared terraced-rock builder** in its own new file beside KitLand
   (`scripts/kit_isle/`). Its input is a footprint and a set of tiers, each an
   outline (or a region) at a height, plus cuts or channels where stairs and
   ramps run between tiers. Its output is **one closed solid**: turf on every
   flat top, faceted rock on every riser and down the sides to a keel. The
   collision is built from the same geometry that is drawn. Stairs sit in a
   cut in the rock whose walls meet the stair's sides, so there is no slot
   beside a flight. Every edge between tops and risers is shared, so there is
   nothing to fail to meet. Any isle can call it. KitLand changes stay
   additive or opt-in (AGENTS.md, The motif editor), so existing motifs build
   as before.
2. **A built-in check** that comes with the builder: a function or a tool in
   `tools/` that sweeps a built solid for gaps you can see into (sight rays
   from walker eye height and a high camera over the walkable area hitting
   back faces or passing through rock), holes in the floor collision, and
   collision that stands off the drawn surface. It reports counts and
   positions, so any isle on the builder can be proved the same way. List it
   in tools/README.md.
3. **The Stair to the Clouds mesa rebuilt on the builder.** The rebuild may
   take liberties (the user said so): keep the idea of a tall stepped mesa
   with a grand stair winding up it in flights, landings at the turns,
   terraces, a summit with its gate, the pinnacle on its rope bridge and the
   lawn the plane lands on. Sizes, the number of flights or terraces, and
   stair widths may change if it makes a cleaner, better-playing place. The
   old mesa code goes once the new one replaces it. Keep the motif's id
   (`stair_clouds`) and its public surface as far as other files use it
   (`scripts/kit_isle/motif_stair_clouds.gd`, `studies/stair_clouds_isle.gd`,
   `_sky.gd`, `_life.gd`, `scripts/interactables/stair_clouds_foot_route.gd`,
   the lodestone and token spots). Update those callers where the layout
   changes.
4. **Proof.** The check from point 2 reports zero see-in gaps and zero floor
   holes on the rebuilt isle. A walk/jump/slide/climb sweep by real input
   into the walls and up every flight puts the walker inside rock or through
   the floor nowhere. The plane still lands on the lawn by hand (AGENTS.md:
   the clear landing stretch). Rendered stills from the walker's eye up every
   flight and round every terrace, judged by eye (the look should read as the
   same dark faceted rock and turf, not dark flat bands).

## Order (the trunk; no lanes: each step needs the last)

1. Builder: the closed solid for tiers with no stairs, its collision, and the
   check. Prove it on a small test shape in a scratch scene.
2. Stair cuts and channels in the builder, with the grand stair (RuinKit)
   seated in them. Prove it on the test shape.
3. The Stair to the Clouds rebuilt on the builder. The old mesa is removed and
   the callers are updated.
4. Dressing: facets, turf edges, weathering, flora and paths so it reads as
   finished. Proof sweep, stills, the plane landing.

Split a step further if it won't fit one iteration.

## Checks every iteration

- Smoke: `studies/stair_clouds_isle.tscn` and `studies/zenscape.tscn -- --no-title`
  (from step 3 on; before that, whatever scene the step builds).
- Stills with `tools/shot.py`, always `-- --no-title`.
- Prototyping rules: no new committed tests, no full suite. List in Notes the
  existing tests and fingerprints the change breaks (`tests/test_stair_clouds_isle.gd`,
  the mesa fingerprint in `tools/kit_isle_fingerprint.gd`, `tests/motif_fingerprint.gd`).
  Don't re-record them.

## Out of scope

Other isles. If the builder suits them, say so in Notes; moving them onto it is
a later round.
