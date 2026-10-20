# Handoff: hitching the loot bag to the plane

Loop `bag-hitch` (spec: `spec-bag-hitch.md`), branch `iter/bag-hitch`, cut
from `iter/bag-brood`. Trail: `git log --grep='^ITER(bag-hitch)'`.

## Where to play

`./run-bag-hitch.command`: the home base (`studies/wreck_cluster.tscn
-- --home --loot-bag`) on a throwaway ledger in /tmp. Without `--loot-bag`
the home base and the stretch play as before (basket and all).

Loot: 10 pieces (`bag_hitch/loot_NN`, moved in F4), 7 on the home isle
(29 kg, north and south of the strip, off the landing turf; the 12 kg egg
must be dragged) and 3 on islet_b's rims (13 kg). Each glints and sits on
a bare patch of turf. The hugged treasures are on the wreck cluster's
far isles.

## Controls

- E by loot: into the bag. F: set down / shoulder / drag (the bag study's
  controls, `docs/design/bag/handoff.md`).
- **F at the parked plane's rope end:** hitch the bag (worn, lying or
  dragged within reach). The bag becomes the cargo; he's left without one.
  F there again: unhitch onto his back, or onto the ground to drag if it's
  over the 18 kg wear limit. Treasures in it are set out on the turf first.
- E at the rope carrying a hugged treasure: "load it in the bag", or
  "Hitch a bag first" with none hitched.
- Flying: E low and slow over the drop field opens the bag; taxi onto the
  vault's pad to bank it piece by piece.

## What's built

- **The loot bag in the home base** (`studies/wreck_cluster_loot.gd`, with
  small additions to `studies/wreck_cluster.gd`). The bag's keys are off in
  flight; a worn bag is hidden aboard.
- **Hitch and unhitch** (`loot_bag.gd`'s "hitched" state, drawn at the
  sling's basket on a short neck rope; `cargo_sling.gd`, `carry_host.gd`).
  The sling's load, size and strain follow the bag's kg.
- **No basket** with `--loot-bag`: the rope ends in an iron hook
  (`cargo_sling.set_bare`), lying on the turf behind the tail when parked.
- **The hitched bag through the plane's run:** it drags taxiing, swings in
  flight, strains the plane, spills on a hard hit (loose loot tumbles and
  can be bagged again), opens over the drop field, and banks at the vault
  one piece at a time. One hook does it: `carry_host.take_from_bag` takes
  from the hitched bag once the sling's own treasures are gone. Coins (25),
  the bar (50) and the gem (80) have values on the tally board.
- **Hugged treasures** go into the hitched bag (shown at its mouth, its kg
  added via `loot_bag.extra_kg`).
- **The brood** ride the hitched bag (no code needed: they read the sling),
  and loot in the bag wakes them as a hugged treasure does (gated on
  `study.bag_on`). They crowd a worn bag but only cling to a hugged
  treasure.
- **A rope that lives** (`cargo_sling.gd`): a 15-point verlet chain with
  gravity, air drag and turf contact. Parked it lies in a curve; taxiing it
  bows and lags in turns and peels up on takeoff. The dragged bag's look
  wanders, hops, rolls, swings out in turns and catches and jerks free,
  drawn around the unchanged physics point (spills, drop, vault untouched).
  The old basket gets the same rope.
- **No right angle at the bag** (task 5, `cargo_sling.gd`): the drawn sack
  leans its neck along the rope's last stretch (`lean`). On the turf it
  tips onto its side round its belly, neck to the plane (drooping at most
  `LEAN_DROOP` toward the turf), lifted so it rests on its side, and rolls
  round its neck instead of pitching; in the air it hangs under the rope's
  pull, tipped round its neck. The rope's last bit is laid along the neck,
  and on the turf the drawn rope is at most `ROPE_SLACK` longer than the
  gap (its slack lay piled past the bag before). Drawn only: the physics
  point and what reads it are unchanged; the hitched loot bag, its riders
  (via `basket_xform`), the bare hook (now lying along the rope, eye to
  it) and the old basket all follow.
- **Tuning:** the hitched sack drawn 1.6x; the hook 1.7x, pale, with the
  kit-cache glint; level-turf hits spill only past 5.5 m/s (walls and
  slopes still at 3.0), so a normal touchdown keeps the load.

## Knobs

`loot_bag.gd`: `HITCH_LOOK`. `cargo_sling.gd`: `ROPE_*` (the chain,
`ROPE_SLACK`), `LEAN_EASE`, `LEAN_DROOP`,
`D_*` (the dragged look), `HOOK_LOOK`, `HOOK_R`. `carry_weights.gd`:
`SPILL_GROUND`, the `SPILL_*` set. `brood_knobs.gd`: the wake counts.

## Stood in / open

- One bag. Spare bags from the plane are a later idea.
- `--loot-bag` is opt-in; making bags the only way everywhere is a switch
  at lock-in.
- The hitched sack reads very dark in shade.
- A wake brings many guys (40 on the first piece, 50 once the loaded bag
  wakes the rim round the plane): the brood's existing count.
- Rope catches are rare at taxi speed; the takeoff peel-up hops seldom
  fire on the home isle (it rolls off its edge level).
- In flight the sack hangs on the rope's pull while the simulated rope
  lags a little behind it, so the rope curves gently a bit above the neck.
- Riders on a sack lying on its side keep their spots round its tipped
  belly; checked by numbers (14/14), not closely by eye (the crowd hides
  the sack in the still).
- The main checkout had uncommitted work in `carry_host.gd`,
  `wreck_arc.gd` and `wreck_cluster.gd` from another session; this branch
  touches `carry_host.gd` and `wreck_cluster.gd`, so merging after that
  work lands may need a hand.

## Checks run (throwaway, uncommitted)

Smoke on every round: `wreck_cluster.tscn` with `--home --loot-bag`,
`--home`, no flags, and `bag_study.tscn`, all PASS. Drivers
`scratch/hitch_t1..t7.gd` through real input (walking, E, F, boarding,
flying, landing): t2 31/31, t3 vault 17/17 and drop 11/11, t4 27/27,
t5 14/14, t6 10/10, t7 land 16/16 and brood 14/14. Task 5: t8 13/13
(the bend where the rope meets the neck: parked 11 deg, taxiing at most
22, in flight 1; the old basket parked 17), headless and rendered; t3 vault
and drop and t7 brood and land rerun green. Stills:
`captures/shots/bag_hitch_t8_parked.png`, `_offturf.png`, `_air.png`,
`_basket.png`, `_taxi_sheet.png`.
