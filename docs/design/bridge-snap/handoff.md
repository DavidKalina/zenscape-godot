# Handoff: rope bridges that snap under load (greybox study)

Spec: `docs/design/bridge-snap/spec-bridge-snap.md`. Built on branch
`iter/bridge-snap` (cut from `iter/bag-brood`) over six tasks
(`git log --grep='^ITER(bridge-snap)'`). The bag is in
`docs/design/bag/handoff.md`, the brood in `docs/design/bag-brood/handoff.md`.

## Where to play it

`./run-bridge-study.command` (or
`godot --path . res://studies/bridge_study.tscn -- --no-title`).
`--no-brood` leaves the brood out; `--brood-now` starts with the test aid
(below) already pressed.

Two grey cliffs over a void (kill plane at y -30). The long bridge
(`bridge_study/long_bridge`, 28.8 m, z -4) bears a load and snaps; the short
one beside it (`bridge_study/short_bridge`, on two spurs at z 9) holds
anything. 41 kg of loot and two burrows on the near cliff; a green drop pad
on the far cliff (`bridge_study/drop_pad`, a target to throw to, no logic).
Every piece is named for the world view (F4).

## Controls

The bag's and the brood's controls are unchanged. New here:

| Key | What it does |
|---|---|
| B (or `--brood-now`) | test aid: the bag filled to what he can wear (18 kg) from the loot not in it, and the brood woken, coming for him over either bridge |
| stick toward the cliff / away | on a hanging half: climb up / down |
| Space | on a hanging half: jump off into the void |
| C | on a hanging half: let go |
| 1-5 | start, near end, short bridge, far end, drop pad |
| R | start (mends the bridge) |

## The numbers

The long bridge's limit is SNAP_KG 96 (held 0.8 s it snaps); it strains
from STRAIN_KG 80 (`scripts/bridge_load.gd`). On the deck: he weighs 60
(WANDERER_KG), the bag its kg (worn up to 18, dragged up to 24), each brood
guy 6 (`BROOD_BRIDGE_KG` in `studies/bridge_study.gd`; on the bag they still
add RIDER_KG 2.5).

- Him with a full bag dragged (84) alone: holds, with a creak now and then.
- Full bag plus 2 brood (96): snaps. With a worn 18 kg bag (78), 3 brood.
- Empty bag plus 6 brood (96): snaps.

Seen in play (the B aid, 18 kg worn, waiting at mid-span): it snapped with
3 brood on the deck, about 5 s after he stopped.

## How it works

- **The load contract** (`scripts/bridge_load.gd`, opt-in per bridge with
  `BridgeLoad.on(live, ...)`): any body calls
  `BridgeLoad.bear_at(world, kg, who)` each frame; the loaded bridge whose
  deck holds that point takes it, keyed by `who`, forgotten 0.15 s after it
  stops. Later enemies add weight with that one call. Every other rope
  bridge in the game is untouched and never snaps.
- **Strain** between 80 and 96: deeper sag at the load's middle, creaks and
  groans quicker and lower, jolts and sideways pushes, planks popping out
  (past strain 0.3) and hand-rope strands whipping off (past 0.5). A
  readout at the top middle (debug).
- **The snap** parts at the load's middle. The drawn bridge hides; two
  verlet plank chains swing down and hang against each cliff face (read as
  ladders). The deck's walk boxes go, so all on it falls; brood over the
  void are lost.
- **Surviving it** (`scripts/bridge_climb.gd`): falling, his hands or chest
  within 0.8 m of a chain catch it, automatically, like the ledge grab. He
  takes the half on his side of the break (the one under his feet as it
  went), the other only if his is out of reach. With the brood behind him
  the break is usually behind him, so he often rides the far half to the far
  cliff: he made it across. Climbing is the ledge hang held still (no
  ladder clip).
- **The brood's routes** (`scripts/brood/bridge_routes.gd`, opt-in through
  `StoneGuy.route`): floors are the cliff tops, decks are the live bridges;
  a walker heads for the next crossing on the shortest way, files onto the
  deck up a funnel and walks its sagged middle line. A snapped bridge is no
  route. A cliff moved in the world view (or by a saved layout) moves its
  floor (its offset; turns aren't followed). Bridges follow their holders.
- **A fall** into the void, by any way: he comes back at the near end (the
  far end if he last stood on the far cliff), the bridge mended, wearing the
  bag, empty; its loot is back on its spots. That holds if the bag was worn,
  dragged, lying, thrown, or with the brood (hauled or buried).
- **The rip** runs at half pace while he stands on a loaded deck
  (`RIP_ON_DECK`; bag_brood `rip_pace`, 1 elsewhere), so the clingers don't
  empty the bag before the rest come on.

## Shared files touched (all additive)

- `studies/bag_study.gd`: `scene_id`, `_build_floors`, `_loot_rows`,
  `_burrow_rows` hooks.
- `scripts/brood/stone_guy.gd`: `static var route` (null: every other brood
  walks as before).
- `scripts/brood/bag_brood.gd`: `var rip_pace := 1.0`.

## Left open

- Catching is automatic and generous (0.8 m): a miss takes a jump at the
  wrong moment or letting go. A press-to-catch or smaller reach if it should
  be harder.
- No ladder pose or climb clip: the ledge hang is held still while he climbs.
- The "avoid it" options (hurry, throw the bag across to the pad, shake them
  off the deck) work through the existing moves but weren't tuned as
  a set; the drop pad has no logic.
- A haul crew carrying a ripped piece walks the deck; its side carriers
  stand over the void beside it (harmless).
- One unexplained run in task 5 where a guy fell off a deck's side before
  the snap (not seen again in 9 runs).
- scratch/bridge_snap.gd (task 3's driver) still expects him to fall at the
  snap; he catches a half now.
