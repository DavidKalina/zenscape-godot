# Handoff: wreck cluster round the colonnade spine (loop `wreck-colonnade`)

Spec: `spec-wreck-colonnade.md`. Trail: `git log --grep='^ITER(wreck-colonnade)'`
on branch `iter/wreck-colonnade` (worktree
`/Users/davidkalina/Documents/Projects/zenscape-wreck-colonnade`). Stopped at
iteration 19 by the user; the overgrowth (iteration 19) is reverted.

## Play it

`./run-wreck-cluster.command` (or `studies/wreck_cluster.tscn -- --no-title`),
`--seed=N` repeats a deal. N (or Esc, New deal) re-deals; F4 shows the part
spots as orange discs. The ledger is in memory only.

## What's built

- **Core:** the colonnade spine from its own motif (seed 61), its floating
  tail cut by the study. The strip islet under its south flank (99 m run),
  the plane parked at its east end, a footbridge up to the bench.
- **Tower:** a ruined gothic bell tower on the spine's east pad, base drawn as
  coursed ruin. Two ways up: wall kicks up the shaft, or the belfry's outer
  stair to a mid landing and a wedged stone into the shaft.
- **Coast down:** sail off the lookout to the coast rock (arch, spot 13), on
  to the tower rock's lobe (cache 08, slammed mid-sail).
- **Rope chain:** north shelf, spur, slam-spring slab, swing rope hung from a
  broken flying buttress, landing on the rope rock (spot 14).
- **Slide:** a natural turf-and-rock tongue from under the rope rock's rim
  down to the tilt rock (spot 15), bridge back to the north balcony.
- **Knight:** the rune knight on a broken causeway off the strip's west end
  (spot 16); knocked off by Z, or Q parry then Z.
- **Flank walks:** south terrace (bench west end to the pulpit, a fallen pier
  up from the strip, spot 17); north lower walk (balcony to the cleft shelf,
  under the rope chain, spot 18).
- **Parts:** 18 spots in nooks, each tagged with the holders it could host.
  Each deal hides 1 or 2 of the six parts in breakable caches (spots 01, 07,
  08, 09; slam with about 2.6 m of drop, or side slam), the rest lying.
- **Look:** each land hangs its own deep rock root; the shared grass carpet
  (`IsleFlora.carpeted`) on all turf.

## Deliberate shortcuts (in the spec table)

Crest jump onto the tower podium; a gust carrying a belfry sail to the coast
rock; an updraft charge reaching the rope rock or back up the slide; the
Q-then-Z knight line.

## Open

- **Overgrowth** needs leafy foliage assets (vine curtains, ivy, ferns,
  bushes, small trees) from a Blender asset round or a pack; the procedural
  attempt (a44ff9e6, reverted) kept only its moss shell idea. Reference:
  `look-reference.png` (its overgrowth only; the dark rock stays).
- Not done: architecture on each islet's side, dressing the rope chain's
  spur and slab and the strip's fallen pier, the warm ground between grass
  tufts.
- The knight shatters instead of falling when pushed past the causeway's tip
  (hard line ends in the shared `rune_knight.gd`).
- Unchecked: whether the colonnade's portal crowns can be reached and sailed
  from to the rope or coast rock.
- Moving an island in F4 doesn't move the plane's home spot.
- No committed tests (prototype); route checks are scratch drivers
  (`scratch/wc_*.gd`, uncommitted).
