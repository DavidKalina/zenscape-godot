# Spec: home base (loop `home`)

The haul now has somewhere to go. A home isle sits at the west end of the
wreck cluster's 700 m stretch. You start there beside a working plane, fly
the stretch east to the wreck cluster, gather treasure (lift, carry, dig;
the brood wakes as it does now), load the bag, fly the stretch back heavy and
bank the haul at home. Banking works two ways: land and unload (safe), or cut
the load over a drop field on a low pass (fast and risky).

Built on main's carry, dig and brood (handoffs: `docs/design/carry/`,
`docs/design/dig/`, `docs/design/brood/`). Trunk only, no lanes. Model:
Opus. Cap and budget: the skill's defaults.

## Done looks like

Launch `./run-home-base.command` (new; the wreck cluster study with
`--home`, plus `--no-title`):

1. **Start at home.** You stand on foot beside the parked plane on the home
   isle's strip. The plane works (as with `--plane-fixed`). The stretch runs
   east toward the wreck cluster, which you can see far off.
2. **The home isle.** A compact isle west of the stretch's last piece
   (`rocks_e`, line ends near x -700), built from the landform first
   (KitLand, the cluster's look and grass carpet), not a flat disc. Its strip
   is long enough to land a fully loaded plane (20 kg) by hand with room to
   spare, and lines up with the stretch so the flight home ends in a
   straight-in approach. World-view names: `island/home`, pieces `home/<piece>`.
3. **The vault.** A small stone store (existing RuinKit pieces) beside the
   strip. In front of it, a **deposit pad** marked on the ground at the
   strip's side, where the plane can roll to a stop.
4. **Land and unload.** Stop the plane on the pad (slow enough and on the
   wheels), and the bag gives up its treasures one by one, each with a short
   beat (lift out, set into the vault, a sound) and added to the tally.
   Carrying a treasure by hand into the vault also banks it. The brood's
   riders still on the bag are shed before the pad (or count as nothing).
5. **Drop pass.** A marked **drop field** (soft ground: straw, nets, sand)
   off the strip's other side. In flight, one action (keyboard and pad)
   opens the bag and lets its load fall; the bag stays on its rope. Below
   a height and speed the field forgives, the treasures land safe and
   bank. Too high or fast, some break: they shatter and their value is lost.
   Off the field they land where they fall and are fetched by hand like any
   spill. Tune it so a careful low, slow pass is safe and a hurried one costs.
6. **The tally.** Each treasure kind has a value (one table; the four
   kinds: idol, urn, dragon egg, chalice). A board at the vault shows the
   banked total and the count per kind. A deposit flashes what it added.
   Banked treasures stand on display in or around the vault. The total is
   kept in the ledger (`scripts/ledger/ledger.gd`), so it lasts across runs.
   Drivers and play builds use `--ledger=/tmp/...`, never the player's save.
7. **Round trip.** A banked treasure is gone from the wreck cluster's
   deal. N re-deals the cluster's treasures as now; the bank keeps its tally.
   The full loop plays: home → stretch → cluster → load → stretch → bank.

Not in this loop: upgrades and spending, insurance, co-op, a growing
danger clock, new enemies, new treasure kinds. Dig finds (tokens, parts)
stay as they are, not banked.

## Keep working

- The wreck cluster study without `--home` starts and plays as before
  (carry, dig and brood drivers rely on it).
- Turf rule (AGENTS.md): every isle keeps a strip you can land on by hand.
- Sizes from `scripts/world_scale.gd`; handles named and stable.
- `--no-stretch` without `--home` works as before. `--home` needs the stretch.

## Checks

- Smoke: `studies/wreck_cluster.tscn` plain, and with `--home`.
- Through the real play loop (scratch drivers, uncommitted): start at home
  and fly the stretch to the cluster; with a loaded bag, fly home, land and
  roll onto the pad, and see the tally rise; a low, slow drop pass banks all;
  a fast or high one breaks some; a carried treasure walked into the vault
  banks; the total survives a restart with the same `--ledger`.
- Rendered stills: the home isle from the approach, the vault and board, the
  drop field from the air, a deposit in progress.

## Suggested order

1. Home isle, its strip, the start there with `--home`, the launcher.
2. Vault, pad, land-and-unload, the tally and its board (in memory).
3. Ledger save for the total; banked treasures on display; banked ones
   leave the deal.
4. Drop field and the drop pass.
5. A look pass on the vault, board and field; stills; the handoff's open
   items for tuning.
