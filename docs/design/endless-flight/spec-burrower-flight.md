# Spec: the burrower in endless flight (`burrower-flight`)

Loop slug `burrower-flight`, trail prefix `ITER(burrower-flight):`, branch
`claude/timed-challenges-redesign-fa3049`. Model: Opus for every agent.
Cap and budget: the iterate skill's defaults. A prototype round
(AGENTS.md, Prototyping): smoke checks, throwaway checks in `scratch/`,
no committed tests, no full suite. The round's handoff lists any existing
test the change breaks.

## Why

The burrower was built and tuned in its study (`spec-burrower.md`,
`burrower-handoff.md`, loop `burrower`). The user wants to see it in
context in endless flight now, and will make changes after playing it.
It replaces the timed challenges (beat routes).

## What done looks like (what the user plays)

`.\run-endless-flight.cmd`, with no flags:

1. **Beat routes are gone from play.** No timed challenges spawn by
   default (today they're behind `--beats=0`; flip the default so they're
   off, keeping the code and a `--beats=1` way back in). Their HUD and
   prompts don't show.
2. **The burrower wakes on a skim, opt-in.** It comes only when all hold:
   - the camera is roughly forward: free-look offset within about 10°
     (a player panning the camera never gets it);
   - the plane has skimmed for a sustained stretch (as in the study: under
     one span, at speed, over land or water; NearMiss's skim);
   - there is open space ahead: flat enough, open ground or water for a
     run (no cliff, ruin, forest or steep slope right ahead), using the
     land's own height and kind queries;
   - a rest has passed since the last run.
   Then it enters as in the study: from off screen at the side with room,
   across ahead, then off to be chased for up to 40 s, pushing up orbs,
   bells and gongs on the plane's line ahead. Climbing off sends it down.
3. **On the real land and water.** The trail, spouts, clods and scar sit on
   the game's terrain (its height and normal), part and press the game's
   own grass where there is grass, and turn into the wake on the game's
   water (sea, lakes, rivers). It steers round what the land holds there
   (rocks, sea stacks, ruins, trees, steep ground) and dives at an edge it
   can't run (a cliff, a ruin wall, deep slope), resurfacing ahead if lost.
   Trees it passes near shudder if the game's trees allow it cheaply;
   otherwise note it as open.
4. **Push-ups feed the chain.** Hitting an orb, ringing a bell or rolling
   through a gong counts as a move in the near-miss chain / combo (it adds
   to the chain and its score like the other moves, with its own glyph or
   name in the tag if the tag names moves). The climbing tune and the
   Freesound bell and gong play as in the study.
5. **The one-press roll.** A barrel roll on its own button (keyboard and
   the pad's south face button, matching the study unless the game already
   uses them; if Space is boost in the game, find the study's choice
   (F boost, Space roll) a home that doesn't break the game's keys, and
   say what was chosen). The double-tap roll can stay alongside.
6. **Frame rate holds.** The burrower and push-ups cost little when
   asleep (nothing per frame beyond the gate check) and stay modest while
   running. Measure in a rendered window (the user's PC is CPU-bound).

The study stays as it is and keeps working (its smoke check passes);
shared burrower scripts may change for the game, but the study is the
place to judge the creature on its own.

## Through the forest (the user, during iteration 3)

The user wants the run to go through forests so the trees shudder as it
passes: "such a cool moment". Forest is ground it **can** run, not an
obstacle to dive at:

- A run may lead into a forest and through it, weaving between trunks
  (as it bobs round trees in the study), every tree it passes near
  shuddering (sway that rings out, leaf burst), so its line reads from
  above as a wave of shaking crowns moving through the wood.
- The plane can't skim under the canopy, so the chase goes on over the
  treetops: while it's under trees, the run doesn't end for the plane
  being high above the ground, as long as it's skimming the canopy
  (about a span or two over the crowns). Push-ups in a forest rise above
  the crowns on the plane's line, or wait for a clearing.
- The wake gate's open-space check can count a forest ahead as open (the
  wake itself still needs the skim over open ground or water to start).
  Cliffs, ruins and steep ground stay things it routes round or dives at.
- Cost: shudder only the trees near its head, from a pool, so a dense
  wood costs no more than a meadow's few. Measure it in the frame-time
  read.

Its own task, after steering and edges, before water and grass.

## Sightings (the user, after playing it)

He doesn't need a skim to appear. "You're flying up around and you see
these trees wake, or something skid in the water, so you dive down and
check it out." Replaces the skim wake and the camera-forward gate.

- **A sighting:** every so often, at any height, he's already out there, a
  few hundred metres off and where the plane can see him, moving at his own
  pace, not reacting to it. Mostly in woods (the gust, crowns going over and
  springing back) and on water (the wake), where he reads from altitude. Rare:
  a rest between sightings, and he never comes up on the plane's nose as a
  surprise. Ignored for 20-30 s, he sinks away.
- **Noticed:** when the plane comes down near him, he notices and the run
  starts from there. The study's entrance from off screen goes in the game:
  you came to him.
- **The run is short:** up to 3 orbs, then he dives. No bell, no gong in the
  game (their code stays; the study keeps them).
- **Orbs come from him:** at his head or just behind it in his trail, not on
  the plane's predicted line, so what he throws up reads as his. He crosses
  the plane's line before one so it stays takeable.

Later, not this round: his speed and catching him (orbs as bursts that
close the gap), the reward for a catch, his body, the calmer turns.

## Proof

- Smoke: `studies/endless_flight.tscn` and `studies/burrower_study.tscn`.
- Through the real play loop (`tools/drive.py`, throwaway in `scratch/`):
  a bot skimming over meadow wakes it; the same skim with the camera
  panned 30° does not; a skim toward a cliff or into a forest does not;
  hits add to the chain; a run on a lake turns into the wake.
- Rendered stills from the chase camera at a few seeds and places
  (meadow, coast or lake, near ruins), looked at before each commit.
- A rendered frame-time read asleep and during a run, against the same
  flight with it off.

## Out of scope this loop

Climbing landforms (canyon walls, mountaintops: queued), the serpent's
body, toppling trees, money and logbook beyond feeding the existing chain,
removing beat routes' code, a lock-in with committed tests.
