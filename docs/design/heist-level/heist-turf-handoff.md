# Heist level: the full turf (branch iter/heist-turf)

## What changed (studies/heist_level.gd only)
- `HEIST_BASE` was `{"grass":0.0}` (greybox, merged into every mass and part
  spec); now `{}`. The masses take crag_reach.gd's `MASS_BASE`/`PART_BASE`
  as they are, so every top grows the kit's grass (growth 0.7, the landing
  0.72) and the finished ground look (turf rim, earth hem, drape), and the
  cliffs stay rock. No new settings; the season is still held at summer.
- `_bare_play()` (after `_add_life`): shrinks the grass within 1.3 m
  (`Greed.BARE`, the same helper the loot and burrows already use) of the two
  rappel posts and each climbing wall's foot. Loot and burrows were already
  bared by `Greed.build_all`. Swing points hang off rock in the air, bridges
  and the vault's stone ramp/ledges are stone; none had grass to clear.

## Stills (worktree captures/shots/heist-turf/, before_* and after_*)
landing (overview with the plane), ground (on foot beside the plane), post
(landing crown by post_01), wayin (terrace_n), vault (the court), wayout
(south mass). Paths: /Users/davidkalina/Documents/Projects/zenscape-heist-turf/captures/shots/heist-turf/.
Before: yellow flat ground; after: green carpet with golden tips and
flowers, grass on rims and terraces, rock on the cliff faces.

## Frame time
Not measurable honestly here: the GPU timer reads 0 on this Mac and
wall-clock per frame in a rendered run is quantized (1.3 / 7.3 / 14.7 ms for
the same scene). Proxy, primitives and draw calls in view (Rendering info):

| spot | before | after | (crag reach / aqueduct isle at their start) |
|---|---|---|---|
| start by the plane | 0.56-0.66 M prims, 384-467 draws | 3.78 M, 521-527 | 2.71 M / 1.74 M |
| the vault court | 0.37-0.40 M, 175 | 1.25-1.28 M, 201-211 | |

So the heist's start looks at more grass than the rest of the game (the
whole landing plus the far masses). Grass already fades at 95 m
(KitFlora.GRASS_RANGE). If it plays heavy, the lever is a lower `growth` on
the far masses (spur, stacks, ford, south) or a per-mass `grass` of 0 on the
unvisited ones; I did not take it.

## Kept bare / not done
- Nothing was kept bare beyond the 1.3 m rings above. No runway strip was
  cleared: grass is visual only, so the plane and walker collide with the
  same turf as before and the landing's length is untouched.
- Grass is waist-high on foot at the landing and rims (as in the rest of the
  game); the bag-throw ledges are stone, so their lips read clear.

## Tests
Smoke passes (heist_level, 400 frames, 0 errors). No committed tests; none
known to break.
