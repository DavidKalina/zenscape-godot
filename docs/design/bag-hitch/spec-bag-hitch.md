# Spec: hitching the loot bag to the plane

Loop slug `bag-hitch`, branch `iter/bag-hitch`, cut from `iter/bag-brood`
(the loot bag, `docs/design/bag/handoff.md`; the brood after it,
`docs/design/bag-brood/handoff.md`). Cap and budget: the skill's default.

## What it is

The wanderer's loot bag (`scripts/carry/loot_bag.gd`) is what goes to the
plane. He brings it to the parked plane (worn, dragged, rolled, thrown)
and **hitches the whole bag** onto the plane's cargo rope, instead of
loading treasures into the plane's own sack one by one. For now there is
**one bag**: hitched, it's the plane's cargo; he goes without until he
unhitches it.

- **Hitch:** at the parked plane's rope end (the cargo sling,
  `scripts/carry/cargo_sling.gd`, lying on the turf behind it), a press
  (F by the bag's neck or the rope end; a clear prompt) ties the loot bag
  on. The bag he's wearing, or one lying or dragged within reach.
- **The hitched bag is the cargo:** it takes the sling sack's place on the
  rope (its look: the tattered loot sack, swollen by its kg), and
  everything the sling does now goes by its kg: it lies on the turf parked,
  drags taxiing, swings under the plane in flight, the plane's strain
  (`scripts/carry/plane_strain.gd`) from its weight, spills on a hard hit
  (pieces tumble loose), the drop field opening it, the home vault taking
  its loot out one by one and banking it (`scripts/home/`). Reuse those
  paths; don't build parallel ones.
- **Unhitch:** at the parked plane, the same press takes the bag back off
  the rope onto his back (or onto the ground if it's over the wear limit,
  to drag). Empty after banking, it's just his bag again.
- **Hand-carried treasures** (the big ones he hugs) still go onto the rope
  as now: into the hitched bag if one's on, else into the plane's own sack.
- **The brood** still ride the hitched bag and add kg (as they ride the
  sling now).

## Where

The scene where the plane and its cargo sling live: `studies/
wreck_cluster.tscn` with `--home` (`run-home-base.command`: the home isle,
the vault, the drop field). The loot bag and its loot are added there
**opt-in** (a flag, e.g. `--loot-bag`, and a launcher `run-bag-hitch.command`
that passes it with `--home`), so the home base and the stretch play as
before without it. Place a few loot pieces on the home isle and the next
islets for a short test run: fill the bag, bring it to the plane, hitch,
fly, bank at the vault.

The main checkout has uncommitted work in `carry_host.gd`,
`wreck_arc.gd` and `wreck_cluster.gd` from another session; this branch
doesn't have it. Keep changes to those files small and additive so a later
merge is easy.

## Done looks like

The user launches `run-bag-hitch.command` and can:

1. fill the loot bag on the home isle and walk, drag or roll it to the
   parked plane;
2. hitch it (the plane's sack becomes his bag) and be left without a bag;
3. taxi and fly with it hanging under the plane, its weight felt;
4. land and bank it at the vault (the pieces come out one by one), or drop
   it on the drop field;
5. unhitch the bag and carry on with it.

## Tasks

One trunk, no lanes:

1. The loot bag and its loot in the home scene, opt-in, with the launcher.
2. Hitch and unhitch at the parked plane; the hitched bag on the rope.
3. The hitched bag through the sling's whole life: taxi, flight, strain,
   spills, the drop field, the vault's banking.
4. A light tuning pass, then the handoff (`docs/design/bag-hitch/
   handoff.md`).

## Rules

- Prototype: smoke checks (`tools/smoke.py` on `studies/wreck_cluster.tscn`
  with and without the flag, and `studies/bag_study.tscn`), throwaway
  drivers in `scratch/` through the real play loop (`tools/drive.py`;
  flying and landing through real input), rendered stills (`tools/shot.py`,
  `-- --no-title`). No committed tests, no full suite.
- Play builds use a throwaway save (`--ledger=/tmp/...`); never write the
  user's real ledger or layouts.
- Landing turf on the home isle stays clear (AGENTS.md).

## No basket, only bags (spec change)

The user: the plane's own net sack goes. With `--loot-bag` on:

- **No basket.** With nothing hitched, the plane trails a bare rope with a
  hook at its end (parked, it lies on the turf behind the plane). Hitch a
  bag and that bag is the cargo.
- **Hand-carried treasures** (the hugged ones) go into the hitched bag
  (drawn in it, its kg added). With no bag hitched, the press at the rope
  is refused with "hitch a bag first".
- Spills, the drop field and the vault go by what's in the hitched bag
  (already so). The brood ride the hitched bag (task 3's second half).
- Without `--loot-bag`, the home base plays as before (basket and all).
  Making bags the only way everywhere is a later switch, at lock-in.
