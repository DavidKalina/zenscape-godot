# Spec: the burrower study (`burrower`)

Loop slug `burrower`, trail prefix `ITER(burrower):`, branch
`claude/timed-challenges-redesign-fa3049`. Model: Opus for every agent.
Cap and budget: the iterate skill's defaults. A prototype round
(AGENTS.md, Prototyping): smoke checks, throwaway checks in `scratch/`,
no committed tests, no full suite.

## Why

Low skimming in endless flight is to wake the world: now and then,
something unseen burrows ahead of the plane, and it pushes up things to
hit. This loop gets the **look and animation of the burrowing** right in a
small study scene before any of it goes into the game. Endless flight is
not touched this loop.

## What done looks like (what the user plays)

`studies/burrower_study.tscn` (and a launcher, `run-burrower-study.cmd`
plus `.command`, like the others) opens a small slice of land: a meadow a
few hundred metres across with grass, scattered trees, a few rocks or a
ruin stub to steer round, and a pond or lake for the water wake. The plane
flies it as in the game (`SkyPlane`, the game's chase camera and input).

1. **The trail.** Something unseen moves under the turf. A ridge of
   heaving ground runs along the surface: grass parts and flattens either
   side, sod clods and pebbles kick up and fall back, dust hangs a moment,
   and the scar it leaves settles slowly behind it. It moves with intent:
   it surges and slows, curves smoothly, sometimes runs alongside the
   plane as if racing. It is never seen itself.
2. **It steers round things.** Its path routes round rocks, the ruin stub
   and steep ground, and passes under or beside trees. Trees it passes
   near **shudder**: a sway that rings out and a burst of leaves.
   (Toppling trees is a later round.)
3. **On water** the same thing is a wake with no boat: a bulge moving
   under the surface, a V of ripples, spray. It can cross from meadow
   into the pond and out again, the trail turning into the wake.
4. **It pushes things up** ahead of the plane, a beat early enough to
   steer for:
   - **glowing orbs** (common): rise out of the turf or water, hang,
     burst into motes when flown into;
   - **an old bronze bell** (now and then): rises, rings when clipped,
     swings;
   - **a gong** (rare): rises on a frame; only a barrel roll through it
     strikes it (a deep note, a shudder); flown into without a roll, the
     plane glances off it and nothing breaks.
   Each rises with weight: the ground bulges, cracks, the thing pushes
   out shedding earth (or water), settles. Unhit, it sinks back after a
   few seconds. Each hit plays a note (placeholder tones are fine: orbs
   high chimes, the bell a ring, the gong low), so a run plays a little
   tune.
5. **It answers the plane.** In the study it wakes on its own when the
   plane skims low (under one span, as `NearMiss` skim) over the meadow
   or pond, starts a little ahead to one side, leads for a while, and
   dives away (the ridge sinks, the trail fades) when the plane climbs
   off or after a run. A key (B) calls it up at once for judging, and a
   watch camera (C) toggles a slow orbit on the trail so its animation
   can be judged without flying.
6. **Barrel roll on its own button** in the study (Space; the pad's south
   face button): one press rolls toward the side you lean, or the way
   you're banked. The double-tap stays as it is in endless flight.

Greybox is fine where the game's own pieces don't lift out cheaply
(greybox trees and rocks, a flat-shaded meadow). The grass is the
exception: the trail is judged by how it parts the grass, so use the
game's grass (or something that reads like it) if at all possible.
Objects (orb, bell, gong) can be simple shapes with good motion.

Judge by eye in rendered stills and short frame sequences (several stills
across one pass of the trail, `tools/shot.py`), from the chase camera and
the watch camera. Motion is the point: surge and settle, the earth's
follow-through, the rise's anticipation and overshoot.

## Out of scope this loop

Anything in endless flight (the gate on camera, skim time and open space,
removing beat routes, the roll button there, the chain's scoring); the
serpent's body; toppling trees; real sound design; money and logbook.

## Checks per iteration

- `tools/smoke.py` on `studies/burrower_study.tscn`: PASS.
- `tools/smoke.py` on `studies/endless_flight.tscn`: PASS (nothing there
  should change, but shared scripts may).
- Played behaviour (the trail waking, routing, the hits, the roll): a
  throwaway check through the real play loop (`tools/drive.py`), left in
  `scratch/`.
- Anything seen: rendered stills, looked at and iterated on before the
  commit.
