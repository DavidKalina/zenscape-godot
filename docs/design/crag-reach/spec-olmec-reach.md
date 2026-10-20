# Spec: the Olmec's reach in the crag reach (loop `olmec-reach`)

Builds on `docs/design/crag-reach/olmec-hunt-handoff.md` (read it first).
Play it: `godot --path . res://studies/crag_reach.tscn -- --no-title --olmec-after=15`.

## What the user saw

Played with `--olmec-after=15`. He ran across the rope bridge and the Olmec
jumped the gap after him, which the user called awesome. Then the user got
away from him, and the Olmec stood stuck on a crown's rim by the rope
bridge's end, the player below on a lower terrace or islet. Standing stuck
broke the immersion.

## Done looks like

- From wherever the player can stand in the crag reach (each mass's crown,
  its terraces and knoll, the islets in walking or jumping reach, the rope
  bridge, the fallen pillar, the aqueduct), the Olmec gets to the player, or
  close enough to threaten (pounce, suck), in most of the places a player
  would expect a huge climbing, leaping stone giant to reach.
- At least one route surprises: a way to the player that the player didn't
  think he had, built from his moveset (a long drop and a wall catch below, a
  climb up the underside of a terrace, a leap onto the bridge, ...).
- He never stands visibly stuck. Where he truly can't reach the player (the
  far west gap, a speck), he does something that reads as intent, within a
  few seconds: he looks for another way along the rim, climbs down and around,
  or throws himself off and comes back up a cliff near the player later.
  Pacing a rim on a loop, or looping seek/chase on a spot, is the failure.
- He breaks things. The crag reach's kit pieces (halls, colonnades, columns,
  the aqueduct, walls, the fallen pillar) break under him through the
  existing break system: the hub `scripts/kit_isle/breakables.gd`, the kit
  breaks `scripts/kit_isle/kit_breaks.gd` with their break kinds
  (`break_kinds.gd`), and his `breach` knob. Most of what's there should be
  breakable: he smashes through a wall or column in his way instead of
  going round, his landings and pounces knock pieces down, and broken
  pieces become rubble his routes read afresh (`changed`). Breaking is part
  of how he reaches you: a route through a ruin, not just round it.
  Breaking doesn't hitch play: no frame stalls the user can feel, when he
  walks up to a piece or when he breaks one, landings included (prepare
  cuts ahead of time, for instance at build or spawn, spread over frames,
  or make them cheaper).
- It stays an experiment: everything behind `--olmec` / `--olmec-after`;
  new body behaviour behind knobs that default off, so `olmec_field` and
  `whole_body_chase` play as before.

## Rules

- Use his moveset (climb, mantle, jump, drop, leap, wall catch, pounce,
  suck). Fix his pathing and choices first; add a new move only when the
  moveset can't reach a place the player expects him to.
- Don't change the crag reach's land, routes or layout names
  (`crag_reach/...`) to make him reach a place. Breaking kit pieces in
  play is fine; the built scene stays the same until he breaks it. If a
  piece he breaks is part of the player's route (the bridge, the
  aqueduct), losing it is fine as long as the player keeps some way on. The landing turf stays clear.
- Sizes from WorldScale / `enemy_field.gd numbers()` (AGENTS.md, Sizes).
- Writes go to /tmp; never touch `layouts/*.json` or other user saves.

## Tasks (the first iteration orders and refines these in its Plan)

1. **Reach table.** A throwaway driver (`scratch/`) that sets the walker at
   each named standing place in turn, with the Olmec hunting from a fixed
   start, and records per place: reached, time, best distance, the state he
   ends in, and whether he's stuck (no progress for N s while looping). Run
   it on the current build and put the table in the commit. Every later task
   reruns it and shows the change. Start with the user's case: the walker on
   the terrace or islet below the rope bridge's end.
2. **Down to you.** The user's case: from a crown rim, he gets down to a
   player on a lower terrace or islet (drop, leap down, climb down a face).
3. **Up from under.** Out from under an overhang or off a lower shelf (the
   east case): he moves along the shelf or face to a spot he can climb.
4. **Bridge, pillar, aqueduct.** He follows over or along them, or leaps
   their gaps, where his size makes that plausible.
5. **Never stuck.** A fallback whenever he makes no progress for a few
   seconds: a readable action (search the rim, climb round, or throw himself
   off and come back up a cliff near the player out of view).
6. **Destruction.** Wire the crag reach's kit pieces into the breakables
   hub, behind `--olmec`, with his `breach` on, so most of them break under
   him (bulk, landing shockwave, pounce, smash through). Read
   `docs/design/kit-breaks/spec-kit-breaks.md` and the existing breakables
   first and reuse them. This can come early, since breaking open a ruin may
   be how he reaches some places. Add the breakables' hit-stop and shake if
   they come free. Prove it with a reach-table run plus a play-view still or
   sheet of a smash.
7. **The surprise.** Pick and tune one route that lands as a surprise.
8. **Look.** Rendered stills (play view) of the fixed cases and the surprise,
   judged by eye.

## Checks per iteration

- Smoke (`tools/smoke.py`): `studies/crag_reach.tscn` with `--olmec`, and
  with no flag; `studies/olmec_field.tscn`; `studies/whole_body_chase.tscn`.
- The reach table, rerun through the real play loop (`tools/drive.py`).
- Rendered stills from the play view for anything the user should look at.
- Cap: the skill's default.
