# Bigfoot's daily routine

Goal: a player can watch the full Fidelity world and see Bigfoot do varied,
legible things without commanding each action. Preserve the cozy tone and the
existing live editor, grounded walking and interruption behavior.

## Actions and acceptance

- Sit: lower into a seated pose, linger, then stand and resume exploring.
- Sleep: settle, breathe and nod with drifting Zs, wake naturally or when nearby
  activity interrupts. Long hibernation is the extended form of this state.
- Stones: approach an actual small stone, grasp it, lift, wind up and release.
  A thrown stone follows a ballistic arc and can leave the diorama. Big boulders
  remain scenery. Object ownership changes at grasp and release, with live-edit
  cancellation preventing duplicated or vanished stones.
- Tree: approach a reachable trunk, plant feet, grip and shake; the selected
  tree visibly responds and returns to its original transform afterward.
- Fish: approach a pond containing a real available fish, scoop and briefly
  inspect it, then return it to the water. Empty ponds never conjure fish.
  A small explicit fish population inhabits the original Fidelity pond.

## Rhythm

Walking remains the default. Action selection favors variety, observes per-action
and per-target cooldowns, and requires a safe reachable performance spot. Sitting
and sleeping provide occasional rests, not the majority of the session. New
nearby objects or terrain edits can interrupt safely. Pause freezes all action
clocks, carried items, projectiles and sleep effects.

## Delivery sequence

1. Extend a copy of the Blender interaction rig with Sit, Sleep, StoneThrow,
   TreeShake and FishCatch clips. Preserve existing animation samples.
2. Add an action lifecycle separate from navigation: approach, perform, complete
   or cancel. Bind hand contact and effect events to explicit clip times.
3. Connect real stone and tree targets, then explicit fish habitats, and add
   autonomous scheduling and interruption cleanup.
4. Verify each action visually and run lifecycle/live-edit regressions. Film
   deterministic action/control reels so motion and contact can be assessed.
