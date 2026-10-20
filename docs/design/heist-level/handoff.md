# Handoff: the heist level (greybox, loop `heist-level`)

Spec: `spec-heist-level.md` (with its three spec changes). Branch
`iter/heist-level`, cut from `iter/greed-run` (unmerged) and merged with
main's Olmec reach and Olmec run. Trail:
`git log --grep='^ITER(heist-level)'`.

## Play it

`./run-heist.command` (`studies/heist_level.tscn -- --no-title`, on a
throwaway ledger in /tmp). On foot beside the parked plane, bag on your back,
rope in the other slot (H switches). Held at summer and on the slow day
(1440 s), so a ~4-6 min run stays in daylight; `--season=` /
`--day-length=` still win.

## The run

1. **Way in (calm):** rappel off `post_01` onto `terrace_n` -> swing the
   rock arch `swing_01` to the `ledge` -> hook and climb `wall_01` onto the
   `gate` -> step to the `spur` -> hook and climb `vault_n` -> rappel off
   `post_02` into the court. Light loot `loot_01..04` on the way. ~2 min.
2. **The vault:** the dragon egg (`treasure`, 8 kg) on `vault_chest`, with
   `loot_05..07` around it. Everything together is more than you can wear
   (18 kg), so you choose.
3. **The wake:** bagging the egg, and only the egg, wakes the isle. 12
   brood come out of the court's burrows (`burrow_01..05`, two more on
   vault_s), and 3 s later the Olmec climbs `olmec_wall` (`olmec_up`) over
   the court's west lip.
4. **Out of the court:** up `vault_ramp`, then `vault_step_01..03`. Over
   9 kg you can't climb with the bag on: throw it up each ledge (LMB/T),
   climb, F to shoulder. Shake clingers off (jump) before a throw or it
   falls short.
5. **The way out:**
   - the corner swing, from the arm `swing_02` on `vault_spire` onto
     `vault_sw`; press F on landing to reel the rope in (~7 s)
   - slide the fallen pillar `pillar_out` (crouch at a run) onto `south`;
     the Olmec's staged drop lands beside you
   - the gap, `gap_near` -> `gap_far`: jump it light, throw the bag
     across heavy, or swing the lintel `swing_03` out from under him (he
     holds while you rig it, then leaps onto the lip you left);
     `gap_ramp` leads up to the `ford`
   - the chain: arches `swing_05`, `swing_06` (rings: they always hook
     their middle) over `stack_1`, `stack_2`
   - the rope bridge `bridge_home` onto `landing_s`, which snaps behind
     you; `home_ramp` up to the landing
6. **Home:** F at the plane's rope hook hitches the bag; Space to board,
   fly clear: Banked. Caught or thrown off: Lost, Enter/R restarts.

Every piece above is `heist/<name>` in F4.

## Proved (throwaway drives through real input, `scratch/`, uncommitted)

- Full run from the real start (`scratch/heist_full.gd`): 3/3 banked
  ("Banked 175 (coins, dragon egg)"), ~4:13 on the clock. A 15 s stall at
  the gap or the bridge loses the run.
- Per leg: way in (`heist_wayin.gd -- --s2=11 --s3=8 --a3=13 --rel=4`),
  vault ledges, corner swing at 0-17 kg from six rim spots, chain 30/30 at
  1-15 kg, gap jump/throw/swing, bridge snap and catch, takeoff beat.
- Smoke: `heist_level --no-title`, `crag_reach --no-title --greed-run`,
  `crag_reach --no-title --olmec`, all 0 errors.
- Stills: `scratch/look/sheet_a.png` (way in, vault, wake), `sheet_b.png`
  (wake, staged drop, gap), `sheet_c.png` (gap near miss, bridge,
  takeoff), `01_start_over.png`.

## How the pieces fit (what we learned)

- **Bag x rope:** the heavy bag drives the route choices. Ledges (over 9 kg:
  throw it up), the gap (over ~10 kg: throw it across or swing), swings (a
  heavy bag starts lower and wants a later release, with no cue why; over
  17 kg the aim says "nothing there", not "too heavy").
- **Brood x everything:** clingers broke the corner swing (they slowed you
  until the rope yanked you back onto the rim). Now a swing's takeoff
  shakes them off, as a jump does (`climb_rope.gd`, `brood_host.shake_off`,
  used everywhere). They can't follow over swings, so the bridge can't snap
  under them on this route. On the ledges they can rip the egg and coins
  out with no warning; one driver run banked nothing.
- **Rope reel:** after a swing the rope stays on the swing point; reeling
  takes ~7 s. Not pressing F on landing turns into a stall at the next swing
  and he catches you. Open: shorten the reel, or let the rope come back on
  its own after a swing.
- **Olmec x swings:** he can't follow a swing either, so the chase on the
  way out comes from his leaps and staged moments, not your path.

## The Olmec here: heist-only staging (revisit after his route planning)

Per the user, his part isn't polished. All in `studies/heist_level.gd`:

- **Court hold:** until the drop he's held in the court (he can't follow up
  the ledges), through both the greed run's under-stuck and main's
  never-stuck.
- **Staged drop** (`stage_drop`/`aim_drop` in `headless_body.gd`,
  `olmec_perch`/`olmec_drop`): as you slide the pillar he throws himself
  down 4.5-6 m beside you, in view. `HEIST_DROP_*`.
- **Swing holds:** at `swing_03` (`HEIST_SWING_*`, then the staged leap
  onto the lip) and at `swing_05/06` (`HEIST_RIGS`, `HEIST_RIG_*`), no
  pounce or suck for up to 8 s while you rig.
- **Weaker suck:** `HEIST_HEAD_K` 0.7 on the head's pull falloff, via a new
  empty hook `tune_olmec` in `crag_reach.gd`.
- **staged_shock:** the staged landings' shockwave at 0.3 (at 0 it threw
  non-finite transforms).
- **Takeoff beat** (`olmec_turf`, `HEIST_TURF_*`): leaps for the turf by the
  plane as you taxi, only if he's within 40 m.

Found, not fixed:

- Kept moving, he trails far by the end. Closest per leg: pillar 7.6 m, gap
  4.1 m, chain 17-40, bridge 30-37, plane 40-48. So only the drop and the gap
  swing are near misses, and the takeoff beat never fires in a real run (he's
  53-63 m off). Once he leapt at the plane after takeoff and fell off the isle.
- A stall always ends in his leap throwing you off the isle, never a grab or
  a swallow.
- In play view the staged drop sometimes shows only the pillar, and his
  landing behind the gap swing is a dark bulk at the frame's edge: the
  camera looks ahead.
- He climbs swing points (stood on the lintel to suck); they aren't marked
  unclimbable for him.

## Where the kit, KitLand or generation fell short

- **Undercut faces:** KitLand masses are undercut below the rim. A hung rope
  swings in under the lip and tops out short; the Olmec's climb goes in
  under and sticks. Twice a plain stone block stood in as a sheer face
  (`wall_01`, `olmec_wall`). A sheer-face (or flat-sided) option in KitLand
  would serve the rope and the Olmec both.
- **No dished ground:** a crag unit can't be sunk, so the vault's court is a
  low unit ringed by higher masses.
- **Ragged rims:** small units have rims that catch a landing a metre low
  or leave 1 m tips (stack_2 grew from 7 to 9, vault_sw from 7 to 9).
- **Swing points are greybox** (`scripts/rope/swing_point.gd`, four kinds:
  arch, arm, branch, lintel; `ring` hooks the middle). As kit pieces they'd
  need real rough meshes, footings that fit the face they grow from (the
  arm's root hangs in air under an undercut lip), connectors in
  `ruin_kit_fit.gd`, the hook line as their contract, and a no-climb mark
  for the Olmec. Only an arch can stand in open air, so chains over gaps are
  all arches.
- **Swing geometry is tight:** a swing can't climb, so every far side sits
  at or below the near one; the hook only aims at lines over your head, so
  an arm just under a rim can't be reached from it.
- **Bridge grade:** the rope bridge climbs at most ~7 m over its 20 m span,
  so the way home needed a lower terrace and a ramp.

## Shared code touched (small, opt-in; other scenes play as before)

- `studies/crag_reach.gd`: host hooks (`place_root`, `bridge_list`,
  `pillar_list`, `ruin_list`, `tune_olmec`); the greed run's under-stuck
  timer renamed `_below_t`/`_below_best` at the merge.
- `studies/crag_reach_greed.gd`: `Greed.build_all(host)` shared by both, with
  host hooks for root, loot, posts, burrows, `greed_marks`, `greed_place`.
- `scripts/greed/greed_meter.gd`: `greed_wake_on()` (loot ids that wake all).
- `scripts/carry/loot_bag.gd`: `throw_kg` (default 8; the heist sets 16).
- `scripts/enemies/headless_body.gd`: `stage_drop`, `aim_drop`,
  `staged_shock`.
- `scripts/rope/climb_rope.gd`, `hook_line.gd`: `ring` hook lines; the swing
  takeoff shakes clingers off. `scripts/brood/brood_host.gd`: `shake_off`.
- New: `scripts/rope/swing_point.gd`, `studies/heist_level.gd/.tscn`,
  `run-heist.command`.

Tests: none run (prototype). `iter/greed-run` noted that `scripts/pad.gd`'s
pad-up action may trip a key-clash test.

## Open

- The reel after a swing (~7 s): keep, shorten, or auto-return.
- A cue for the heavy-bag swing (lower start, later release) and "too heavy"
  for the aim over 17 kg.
- A warning before the brood rip loot; whether they should reach you on the
  way out at all.
- The swing_01 landing is marginal: a slightly different start lands on a low
  shelf at the ledge's west lip, and the walk on falls off the isle.
- The Olmec's pace home and the takeoff beat, after his route planning.
- Stale drivers: `scratch/heist_out.gd` (old pillar top), `heist_wayin.gd`'s
  defaults and loot count, `heist_vault.gd`/`heist_greed.gd` (old marks).
