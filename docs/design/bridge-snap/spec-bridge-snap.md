# Spec: rope bridges that snap under load (greybox study)

Loop slug `bridge-snap`, branch `iter/bridge-snap`, cut from `iter/bag-brood`
(the loot bag, `docs/design/bag/handoff.md`, and the brood that chases it,
`docs/design/bag-brood/handoff.md`). Cap and budget: the skill's default.

## What it is

A long rope bridge over the void carries a load: the wanderer, his bag's
kg, and every enemy on its deck. Past its limit it strains, and past that
it snaps.

- **Load:** the wanderer's own weight (a named constant), plus the bag's
  kg (worn or dragged), plus each brood guy on the deck (the brood's
  `RIDER_KG`). Make it a **generic contract**: any body can tell the bridge
  "I'm on you, this many kg", so later enemies add weight without bridge
  changes. The bridge sums what's on its deck each frame.
- **Strain:** between a strain threshold and the snap limit the bridge
  warns, rising with the load: deeper sag, creaks and groans, planks
  popping loose and falling, the hand ropes fraying (a few strands
  whipping off), a stronger sway. It should read without a meter (a small
  debug readout is fine). Below the threshold it's the normal bridge.
- **The snap:** held past the limit for a moment, it parts (at the most
  loaded span, or one end). The halves swing down and hang against each
  cliff face. Everything on the deck falls: the brood tumble into the void
  and are gone; loose loot falls too.
- **Surviving it:** as the deck drops he can grab the hanging half (the
  climb from `docs/design/rope/handoff.md` if it's on this branch, else a
  simple hold-and-climb on the hanging planks like a ladder) and climb up
  to the cliff top. If he misses, he falls into the void and respawns at
  the near end (bag and its loot lost to the void, or left where it was:
  next iteration's call, note it). Floating down (the sail) is the full
  moveset's answer; the M toggle turns it on.
- **The tension it's for:** a loaded wanderer crossing near the limit is
  safe alone. Brood swarming onto the deck behind him push it over. He can
  hurry, shed weight (throw the bag ahead to the far side, drop a piece), or
  shake them off the deck.

The game already has living rope bridges: `scripts/rope_bridge.gd` (sag,
bounce, sway) on `scripts/rope_bridge_sim.gd`, built by
`scripts/footbridge.gd`. Build on them. Snapping is **opt-in** per bridge
(a flag); every existing bridge in the isles keeps working as now and never
snaps.

## Where

A new greybox study, `studies/bridge_study.tscn` + `studies/bridge_study.gd`,
launched by `run-bridge-study.command`, built the way `studies/bag_study.gd`
is (numbered stations, `bridge_study/<piece>` names through
`scripts/layout_overrides.gd`, F4 world view, the M full-moveset toggle if
it's on this branch). Two grey cliffs over a void (a kill plane far below),
with:

- a long snapping rope bridge between them (about 25 to 30 m);
- a short one beside it that holds anything (to compare);
- loot on the near cliff to fill the bag with, and a burrow or two on the
  near cliff so the brood wake and follow him onto the bridge;
- a far cliff with somewhere to drop the bag (a target to throw to).

Tune the limit so the wanderer with a full bag (24 kg) crosses safely
alone, but a few brood guys on the deck with him push it past.

## Done looks like

The user launches `run-bridge-study.command` and can:

1. cross the long bridge empty and with a full bag, safely;
2. bring the brood onto the deck behind him, feel and hear it strain;
3. hold it there till it snaps: the brood fall into the void;
4. grab the hanging half and climb up, or fall and respawn;
5. avoid the snap by hurrying, throwing the bag across, or shaking them off.

## Tasks

One trunk, no lanes:

1. The room: cliffs, void, both bridges, loot, burrows; respawn on a fall.
2. The load contract and the strain cues (sag, creak, planks, fraying).
3. The snap: halves swing down, everything on the deck falls, brood lost to
   the void.
4. Surviving it: grabbing the hanging half and climbing up.
5. A light tuning pass, then the handoff (`docs/design/bridge-snap/
   handoff.md`).

## Rules

- Greybox. Cliffs and void plain grey; the bridge as the game draws it.
- Prototype: a smoke check (`tools/smoke.py` on `studies/bridge_study.tscn`,
  plus `studies/bag_study.tscn` and a scene with an existing rope bridge,
  e.g. `studies/aqueduct_isle.tscn`), throwaway drivers in `scratch/`
  through the real play loop (`tools/drive.py`), rendered stills
  (`tools/shot.py`, `-- --no-title`). No committed tests, no full suite.
- Changes to shared files (`rope_bridge.gd`, `rope_bridge_sim.gd`,
  `footbridge.gd`, `brood_*`, `loot_bag.gd`) stay small, additive and
  opt-in.

## The bag on a fall (spec change, decided)

The user: he always comes back with a bag, but it's empty. On any fall
into the void, worn or not, he respawns wearing an empty bag; its loot is
lost with the fall (pieces back on their spots, as now). Replaces task 4's
"worn keeps its loot". Spare bags from the plane are a later idea.

## Task 5: the brood find the bridges (spec change)

The user couldn't test the snap: the brood's pathfinding failed. From the
far side, by the short bridge, they couldn't find their way back onto the
long bridge. This task comes before the tuning (now task 6):

- **Bridges are routes for the brood.** A brood guy heading somewhere
  across the void goes to the nearest bridge end that gets him there,
  walks the deck along its centre line, and steps off the far end. Both
  bridges, from either cliff. They never step off a deck's open sides.
- **They follow him onto the long bridge** from wherever they are (near
  cliff, far cliff, the short bridge), so a crossing with the brood after
  him reliably brings them onto the deck.
- **A test aid:** a key (and a flag) that brings the brood out straight
  away, already coming for him, so the user can try the snap without
  first filling the bag near the burrows. Show it in the hint line.
- Prove it through the real play loop: from each cliff and from the short
  bridge, the brood reach him mid-span on the long bridge; and a snap
  happens in play with them on the deck.

Task 6 is the tuning pass and the handoff (the empty bag on a fall, catch
reach, which half he grabs, a ladder pose, as noted in the trail).
