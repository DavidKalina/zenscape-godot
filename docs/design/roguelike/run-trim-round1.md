# Run trim, round 1 (2026-10-15)

> Cut from `roguelike` at cedeba08. A prototype round: smoke checks and
> throwaway drivers in `scratch/`, no new tests.

The user played `run-game.command` and asked for four changes: cut the
flyer, cut the Sun-Keepers, move the merchant off the beaten path, and make
layers about 5 minutes instead of 10.

## Play

```sh
./run-game.command                                   # the trimmed run
<godot> --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --world=under --under-look=torch --seed=1
```

| Flag | Does |
|---|---|
| `--flyer` (or `--flyers=N`) | brings the guácharo back (off by default now) |
| `--sun-keepers` | brings the Sun-Keepers back beside the Hollow Child (`--inhabitant=` still wins) |
| `--merchant=start` | the stall beside the spawn, as before (test knob) |
| `--merchant=always` | a stall on every layer (on its nook) |
| `--knob=city_size=full` | round 14's layer size (2-3 neighbourhoods of 2 places, about 10 min) |
| `--knob=city_hood=N` | pins the places in each neighbourhood (`--knob=hoods=N` pins how many neighbourhoods) |

## What changed

1. **The flyer is cut.** `RunFeatures.opted(&"flyer")` (new, in
   `run_features.gd`) is true only when `--flyer` is given. `LayerFlyers.lay`
   lays no bird unless you pass `--flyer` or `--flyers=N`, or the plan
   carries its own `flyers` (the flyer yard's, which still works).
   `--loot=off` still wins. The code is untouched otherwise.
2. **The Sun-Keepers are cut.** `LayerInhabitants.counts()` now defaults
   `--inhabitant` to `child`, or to `both` with `--sun-keepers`. With the
   Keepers off, the slots planned are only the children's (1 + danger), so
   there's no hole: the sleeper and household slots aren't made at all.
   The torch key and the tells still run; they find no Keepers.
3. **The merchant's nook.** New `scripts/roguelike/merchant_nook.gd` (data
   only). On a layer with a stall (odd regions, as before), the sprawl plan
   (`layer_sprawl.core`, after the exit chain and before the hazards and
   heads, so they keep clear of it) lays a short side spur:
   - It leaves a free rim of a place on the main line first. If none fits,
     it tries a side place, then a free face of the landing (seen from the
     start). It never leaves the greed isle, and it keeps 24 m off the exit
     chain's rim and the gate.
   - It is one crossing from the city family, sized from the motor like
     every edge: the staggered piers at 0.4 of the layer's meanness, with
     their step drums (the slow, safe line). If the piers won't stand
     there, it is a run of column tops. There is no hard piers and no
     broken causeway (its slumped climb and gone spans stay on the route).
     In the sky it is floating stones.
   - It ends on an 8.5 m square slab (`landing`) where the stall stands,
     facing back toward the rim.
   - It is checked clear the way the exit chain is: corridor, other edges,
     ride tubes, gulf piers, cannons and kegs.
   - It is an edge of branch `"nook"` in `plan.edges`, so CityCrossings
     builds it with the rest, and collectibles lay a safe rune trail along
     it. `plan.nook` = {at, face, side, edge, isle, rim, kind, main, base}.
   - `Merchant.lay` uses it, else falls back to round 1's cover/perch spot.
     `Merchant.lays` now calls `MerchantNook.wanted`, which is the same rule
     as before. A nook's stall stands from 140 m (`NEAR_NOOK`, was 70), so
     its lamp is up as you come onto the place.
4. **Layers about 5 minutes.** `LayerPlan.CITY_HOODS` is now (2,2) and
   `CITY_HOOD` is 1 (it was at least 2 neighbourhoods of 2 places). So a
   city layer is the landing, one place, a serpent gulf, one place, then
   the exit chain, plus the greed isle off to the side. That is 4 isles
   where it used to be 6-8. `--knob=city_size=full` gives round 14's rolls
   (the same rng calls, by reading the code; I didn't diff the plans). The summit's 6 layers are unchanged:
   a run is now about 35 min, not 65.

Also fixed: `gb_stacked_court.gd` `Keeper._refind` looped `for e: Node3D in
field.enemies`. A freed enemy still in the list was a script error ("assign
invalid previously freed instance") on the trimmed seed 5. It now skips
freed entries. I didn't find what frees an enemy without taking it off the
list.

## Layer times (estimated, not driven)

These times are **estimates from the plan**, not runs through the real
loop. The driver is `scratch/estimate.gd`. It follows the main line (from
the spawn along way_lights' `main_line`, then the exit chain) and charges
each part:

- **Each place on the way:** round 14's yard-driver time for the six city
  motifs (court 78 s, face 51, colonnade 80, crossing 80, stair 57, pit
  90). Newer motifs (procession, haulway, weir stair) are charged their
  lip-to-lip distance × 2.6 / run.
- **Crossings:** walked path / run, plus 0.35 s a stone. The slide is
  charged at 9.5 m/s.
- **Serpent gulfs:** half a lap's wait plus the ride.
- **Cannon:** 8 s.
- **Calibration:** crossings and rides × 1.5. Round 14's measured layers
  spent about 140 s off-place, and this model gives about 90 s.

"Good player" means walked and place time × 1.6 plus the rides, as in
round 14.

The live layers measured in the nook driver show the serpent model is
conservative. It runs a 303-497 m lap at 12.5-12.9 m/s, which is a 24-39 s
lap, and the model assumes 30-45 s.

| Size | Layers (seeds 1-10 × regions 1-3) | Good player, mean | Range |
|---|---|---|---|
| full (before, `city_size=full`) | 30 | **11.3 min** | 7.4-18.2 |
| trim (now) | 30 | **5.6 min** | 3.2-8.0 |

The trim is bimodal:

- **12 of 30 layers have one place on the way (3.2-5.7 min).** On these
  the gulf leaves from the landing itself, and the first neighbourhood's
  place becomes an optional side place.
- **18 of 30 have two places on the way (4.7-8.0 min).**

None of this counts detours for pickups beyond the 1.6 factor. The
procession's charge is distance-based and the least sure. The real number
is a playtest.

## Proof

- **Import:** a headless import is clean.
- **Plans:** `tools/sweep.py tools/layer_dump.gd --seed 1..10 --knob
  world=under --knob region=1,2,3` laid 30 of 30 with no problems.
  `scratch/estimate.gd` over seeds 1-12 × regions 1 and 3: a nook laid on
  24 of 24 merchant layers.
  - 9 were on a main-line place, 8 on a side place and 7 on the landing.
  - 21 were piers and 3 were column tops.
- **The nook through the real input** (`scratch/nook_drive.gd`, run_layer
  `--world=under --under-look=torch`, seeds 1, 2, 3, 5, 6, 8 and 12): 7 of
  7 passed all their checks.
  - The stall is laid on the nook and stands as he reaches the rim.
  - The slab stands clear of every isle, with nothing within 8 m under it.
  - Every other crossing is 38-87 m off. The slab is 15-41 m out from its
    lip.
  - He is set down on the rim and crosses with the stick, crouch and jump:
    a long jump where the small hop won't reach, the small hop on column
    tops. That took 4-6 jumps in 3.5-6.2 s.
  - He stands on the slab and walks up to a ware (`_near()` finds it).
- **The cuts** (`scratch/cuts_drive.gd`, seed 1):
  - By default there is no guácharo, the inhabitants want `{children 1,
    sleepers 0, households 0}`, and the only slot is the child's.
  - With `--flyer --sun-keepers`: 1 guácharo, and the slots are a sleeper
    and the child.
- **Smoke** (`tools/smoke.py`, 0 script errors in each):
  - `run_layer --no-title --shape=sprawl --world=under --under-look=torch`:
    - seed 1;
    - seed 2 at `--region=2`;
    - seed 3 at `--region=3`;
    - seed 4 at `--region=3` with `--flyer --sun-keepers`;
    - seed 5, and seed 5 with `--merchant=start`;
    - seed 5 with `--merchant=start --sun-keepers --flyer
      --knob=city_size=full`;
    - seed 6 with `--knob=city_size=full`.
  - Also: the ring underground (seed 3), the sky (`--world=sky`, seed 3),
    `studies/game_title.tscn` with run-game's flags, `studies/flyer_yard.tscn`
    and the motif yard with `--motif=stacked_court`.

## What the smaller layers cost

These counts are from the plan (`scratch/loot_count.gd`, seeds 1-8, region
2, trim against full):

- **Runes laid:** 170-312 a layer, mean 232 (full: 277-493, mean 403).
  That is about 42% fewer runes a layer and about half a run's total. Per
  minute it's about the same (41/min against 36/min). Prices are small (the
  heart is 6), so the purse still buys at every stall, but a thief's
  choice is less forced.
- **Rares:** 3 a layer, unchanged (one an isle first, so they now sit
  closer together).
- **Chests:** 2, and 1 on two of the eight seeds (fewer cover spots).
- **Altars** (pedestals, key, vault, cursed altar): all 5 still lay at
  depth 2. They share 3 isles instead of 4-5, because repeats on an isle
  are only down-weighted.
- **Merchants:** still on odd regions, so 3 stalls a 6-layer run. Each
  stall now has a nook, so they don't lose spots.
- **Hollow Child:** 1 + danger, unchanged. With 2 route places it more
  often sits on the one place you must cross.

## Rough spots

- **The times are estimated.** The real loop can't yet path through a
  place's climbs, as in round 14. A human playtest is the real measure,
  and the one-place layers may feel short.
- **The bimodal length.** When the gulf leaves the landing, the first
  place is optional. If every layer should cross both places, the gulf
  should be made to leave the first neighbourhood's place (a plan change
  in `LayerPlan._gulf`'s from-isles).
- **The nook isn't looked at.** No rendered still was taken: the slab and
  stall in the torch's dark, and whether you see it from the route. The
  stall's own lamp is dim (0.7, 6.5 m), so a far nook may read only up
  close.
- **The nook on the landing** (7 of 24) is seen from the start, but it is
  the least "off a place" of the three cases.
- **The ring** (a first layer with `--shape=ring`) lays no nook. Its stall
  keeps round 1's spot.
- **What freed the enemy** behind the stacked court error is still unknown.
  Another loop over `field.enemies` with a typed iterator would trip the
  same way.

## Tests it likely breaks (not run; no full suite)

- **`tests/test_layer_sprawl.gd` and `tests/test_run_layer.gd`** (both
  slow). Round 14 already noted they break on city layers.
  - Odd-seed plans now carry a `nook` edge in the sky too. Their "every
    edge crossed on foot" and "rim stands on its ground" checks will walk
    it and probe its far rim (the slab's edge).
  - The plans for odd seeds also differ from before from the hazards on,
    because the nook is laid before them.
- **Any test that counts city isles or expects 4+ route places.** I found
  none by grep.
- **A test expecting the flyer or the Sun-Keepers by default.** I found
  none by grep. Such a test should pass `--flyer` / `--sun-keepers`.
