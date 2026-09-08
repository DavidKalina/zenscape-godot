# Bigfoot in Fidelity

Launch `run-fidelity-life.command`, or open `studies/fidelity_life.tscn` in Godot.
This inherits the full Fidelity world, including its original terrain, forest,
pond, stream, lighting and native editor.

**Find Bigfoot** (or **B**) frames him. **P** pauses. The walkable-ground button
shows navigation samples. Existing orbit, zoom, sky and editor controls work.

Bigfoot explores between autonomous activities:

- Picks up actual small loose stones, winds up and throws them. Throws can leave
  the diorama. Three loose stones start beside the paths; add more with the editor.
  Small rocks (scale at most 0.5) are throwable; larger boulders attract curiosity.
- Grips and shakes a reachable original tree; its trunk and canopy move together.
- Scoops an available fish from the pond, holds it briefly, and returns the same
  fish to the water. Four explicit fish inhabit the original pond. Empty ponds
  do not create fish, and newly authored ponds do not automatically get stocked.
- Sits, looks around, stands and resumes exploring.
- Settles into a short nap with breathing and drifting Zs. Every second sleep
  opportunity is a longer hibernation, followed by standing and exploring again.

The first activity starts after eight seconds. Activities normally leave nine
seconds for wandering/curiosity afterward; unavailable choices are skipped after
three seconds. Individual targets have a fifty-second cooldown. Sitting lasts
four seconds, a nap eighteen, and hibernation sixty, plus settling/standing clips.
Stones thrown off the world are consumed; undo can restore them.

The editor stays usable. Committed terrain, water and object edits rebuild the
habitat before movement; edits interrupt performances and restore held objects
or tree poses safely. Unsafe footing relocates to nearby safe ground. With no
usable ground, Bigfoot waits until habitat returns. New nearby objects prompt
an excited approach. Pause freezes actors, fish, projectiles and sleep effects.

Navigation uses a 0.35-meter grid for Fidelity, a half-meter body margin, and
fine swept checks across the uneven ground. Smooth resting banks are fitted to
an uphill-facing seated pose with dry toe support; abrupt steps are rejected.
Conservative solid bounds still exclude narrow gaps and the arch opening.
Other creature scenes retain their default grid and pacing.

## Evidence

`actions/autonomous-day.mp4` is four continuous minutes with no manual action
requests or teleports. It completes stone, tree, sit, fish, sleep, a second cycle,
hibernation, waking, and a final stone throw. `actions/animation-review.mp4`
compares the seven new authored clips against Idle with matched camera/light.
Individual world action reels and screenshots are in `actions/`.

Validation uses Metal / Forward+ because headless MultiMesh transform reads do
not match the renderer-backed Fidelity instances:

- `test_bigfoot_routine_day.gd`: 250 simulated seconds, all six activities,
  33.01 meters traveled, zero unsafe frames, no cancelled/stuck approaches.
- `test_bigfoot_routine_ownership.gd`: real stone transfer/undo, airborne cleanup,
  actual tree shaking/restoration, preservation of newer edited tree transforms,
  same-node fish catching/return, and empty/deleted water rejection.
- `test_bigfoot_routine_pause.gd`: paused airborne stone, fish and actor clocks;
  paused Z effects; hibernation interrupted by live editing restores upright pose.
- `test_fidelity_life.gd`: movement/editor baseline, 18.98 meters and 1,541 moving
  frames in one minute; exact new-boulder reaction; lower-tool terrain changes,
  safe footing and movement afterward; navigation overlay.
- Actor, brain, hand-reach, routine-animation lifecycle and navigation regressions
  pass. Navigation includes the narrow hazard that previously stranded him.
- Rendered contact checks measured about 12 mm for the stone and 2.4 mm for fish;
  the stone reel confirms an edge exit. Blender validation keeps feet above
  the authored floor; the fishing hand deliberately reaches below the bank.
- `tools/validate_bigfoot_routine.py` confirms original Idle, Walk, Held, Land
  and Alert exported animation samples are unchanged.

This is the first playable routine pass. The seated sleep is a stylized pose;
there is no cave, fishing inventory, stone replenishment, tree destruction or
seasonal hibernation simulation. Authoring details are in `actions/README.md`.
