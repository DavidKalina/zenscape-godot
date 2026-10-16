# Handoff: The Pilgrim's Ladder (loop `pilgrims-ladder`)

Card m1 of round 3, built as a playable place by 15 iterations on branch
`iter/pilgrims-ladder`. Each iteration was a fresh agent with a 150k
context budget; none reached it (49k-119k). The plan, with real numbers and
its Corrections, is in `docs/design/motifs/plans/pilgrims-ladder/`.

## Play it

```
~/Applications/Godot.app/Contents/MacOS/Godot --path . --windowed --resolution 1440x900 \
  res://studies/motif_yard.tscn -- --no-title --motif=pilgrims_ladder --sky
```

R resets. The layout lives in one table:
`scripts/kit_isle/greybox/gb_pilgrims_ladder.gd`.

## What's built

**Four isles** stepped up and east, on real terrain: Threshold (0), Halo (7),
Crown (20) and Cellar (10). There's a 30 m landing strip on Threshold.

**The route, every leg driven with real input:**
1. **Ropes:** `relic_torana`'s ropes lift you off Threshold. The slow way is
   the offering steps.
2. **The ring:** a hop takes you to the Halo, then `relic_nimbus` carries you
   up: trough, ledges, spoke, brackets, low horn, twirl to the high horn.
3. **The Crown:** a run-up jump, then a sail across.
4. **Cover:** `pent_hood` on the north rim hides you from the guacharo.
5. **The way down:** jump off the south lip and slam the boss.
   `keel_hung_stair` turns on its built plinth; drop through the hatch and
   run down to the Cellar inside 12 s.
6. **Home:** sail to the Halo, then sail to Threshold.

**The guacharo** lives over the Crown, range 22. Its edge band is widened
for this place, and its floor is 15, so the Cellar is safe.

**Collectibles:** five tokens on foot.

**Dressing:**
- 25 ruin pieces;
- a 14 m arch and a buttress as landmarks;
- 13 trees in clumps;
- vines on the plinth;
- 17 songbirds.

The merchant and the beetle are off for this place only.

## Changes outside the place (additive)

- `studies/motif_yard.gd`: it stands up a motif's own birds.
- `scripts/roguelike/layer_flyers.gd`:
  - a place-set range is honoured;
  - a place can set its own bird's knobs;
  - a flyer `floor`.
- `scripts/roguelike/run_features.gd`, `merchant.gd` and `layer_beetles.gd`:
  the per-motif opt-out, `without()`.

## Open

- **The turf is gold** because the season follows the real date (autumn),
  everywhere. With `--season=summer` it's green. The hero trees don't follow
  the season.
- **The plinth's west face** reads dark in the Crown's shadow.
- **The Crown's birch** is thin.
- **The strip's clearance** from the trees was checked by numbers only, not
  flown.
- **No plane tokens:** there's no token the plane can take, so the gate and
  ring threads have none.
- **The tokens aren't counted:** they aren't in `data/ledger`, so the game
  keeps them but doesn't count them.
- **The guacharo here is the old bird.** The guacharo remake (branch
  `iter/guacharo`, lanes body and hunt) will touch `layer_flyers.gd` too.
  Its roof-gap rule needs a drive in this hood's real gap once it's merged.
- **Breaks no existing tests that we know of.** The full suite wasn't run
  (prototyping).
