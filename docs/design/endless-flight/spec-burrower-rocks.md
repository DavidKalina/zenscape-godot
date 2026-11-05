# Spec: the burrower spits rocks (ITER(burrower-rocks))

The tunnel chase (`scripts/endless/burrower_bore.gd`, spurs in `bore_spurs.gd`,
plugs in `bore_plug.gd`) gets a third attack: the burrower, running ahead of
the plane, kicks rocks back down the tunnel at it. The plane dodges them
(bob and weave) or parries them; a parried rock flies home and hits him.

This is the shared part of two directions the user hasn't chosen between yet
(a forced boss fight in a looping tunnel, or an encounter you survive to the
exit). Build only what both need: no tunnel loop, no boss stages, no health,
no new win condition. The chase still ends as it does now.

## Done looks like (what the user flies)

- In the tunnel chase, every so often he spits a rock back at the plane. A
  clear tell first (he rears or flicks, and a rising whistle like the pirate
  ship's balls), then the rock comes down the tunnel toward the plane, fast
  enough to need a real dodge, slow enough to read and to parry.
- **Dodge:** the rock misses, flies past and is gone (shatters on the tunnel
  or fades behind).
- **Hit:** a rock that hits the plane is not a crash. It jolts the plane (a
  shove and camera shake, a crack sound) and loses the unbanked chain, like a
  scrape (`near_miss.gd` `lose()`). Only walls, spurs and plugs crash, as now.
- **Parry:** the roll's start in the window knocks the rock home onto him,
  through the existing parry (`scripts/endless/parry.gd`: join `parry_source`,
  the five methods, shot dicts; the pirate ship in `pirate_ship.gd` is the
  example). The parry pays the meter as it does for the ship, and never spends
  the gauge (already on this branch: cherry-picked a452d30b).
- **He's hit:** the rock lands on him and he staggers: a visible flinch, a
  sound, and he slows for a moment so his lead shrinks (his pace is
  `_pace()`, `LEAD_S`). Repeated hits keep closing the gap a little; nothing
  more yet (no stages, no defeat).
- Rocks are planned so they never pile on the same stretch as a spur or a
  plug firing: place them in the same plan (by the tunnel seed, so the same
  seed gives the same run) or fire them only in clear stretches.
- Seed 1, the main scene. Placeholder sounds are fine (bake like
  `assets/audio/parry`); placeholder rock look is fine (a stylised lump,
  rock-coloured, no photo texture).

## Tasks

The first iteration splits this; likely one or two tasks:
1. The rock: tell, flight, dodge, hit jolt, parry hook, him staggering.
2. If left over: tuning numbers by a driven run, the plan's spacing against
   spurs and plugs.

The loop stops after the rock spit is playable, so the user can fly it.

## Checks

- Smoke `studies/endless_flight.tscn`: PASS.
- A throwaway driver through the real play loop (`tools/drive.py`) that
  enters the tunnel chase, and reports rocks fired, dodged, hit and parried,
  and his lead before and after a parried hit.
- A rendered still of a rock in flight in the tunnel (`tools/shot.py`,
  `-- --no-title`).

Cap: the skill's default. Budget per agent: 150000 tokens.

## Look at

`cd /Users/davidkalina/Documents/Projects/zenscape-burrower-rocks && python3 tools/play.py --no-pull -- --pilot-file=/tmp/rocks_pilot.json`
plus any flag that starts near a burrower cave (find or add one).

## Spec change (after the user flew task 1, 2026-11-04)

The user: "Not bad. I like it." They want a parry to break some spurs, but
not make dodging pointless: the run stays a mix of flying, bobbing and
weaving, and parrying.

- **Cracked spurs:** about 1 in 4 spurs is cracked (seeded, same seed same
  run): reads at a glance at speed, paler stone with a seam of his ember
  glow. The rest are solid as now.
- **A parried rock on its way home** hits the first spur in its path
  (between the plane and him). A cracked one smashes (reuse the surge's spur
  break, `surge_smash.gd` `_spur()`, so it's gone for the plane too) and the
  rock flies on and hits him. A solid one shatters the rock: no hit on him.
  One spur per rock at most. This also fixes "rocks pass through spurs":
  a rock flying toward the plane shatters on a spur in its way too (or is
  planned so none is in its way).
- **Keep dodging needed:** place rocks so a cracked spur sits in the rock's
  path home only some of the time, not every time; most spurs are still
  dodged by flying. The parry's window and whiff lockout stay as they are.
- **Tuning pass** in the same task: rock speed, the 0.5 s commit, tell,
  count, stagger, judged by a driven run. The user had no complaints on
  these; change them only if a run shows a reason.

Stop after this for the user to fly.
