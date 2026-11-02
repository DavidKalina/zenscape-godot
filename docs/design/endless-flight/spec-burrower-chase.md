# The burrower's chase through the tunnel

Step 2 of the burrower at the caves (step 1:
`burrower-cave-step1-handoff.md`). Today he reaches a cave mouth, `plunge`s and
is gone. This spec is the first playable of what happens next, in one chase.
The loop stops there and the user flies it; what comes after is listed at the
end and isn't part of this loop.

Loop: slug `burrower-chase`, branch `iter/burrower-cave`, worktree
`zenscape-burrower-cave`, the skill's default cap. No lanes: every step
stands on the one before.

## What done looks like

The user follows him into a sunk tunnel at speed. He stays unseen. A ridge of
heaving rock runs on ahead of the plane, climbing the wall, crossing the
ceiling and coming down the far side, so he winds around the bore as he goes
forward. Where he passes, the rock cracks, and a beat later a spur of rock
punches out of the bore at that spot. The plane rolls and weaves past them.
Pushing up close to him gives less warning. A rumble says where he is around
the tube when he's out of view. He bursts out of the far mouth in a plume and
the plane follows him into daylight.

## The rules

- **No body.** He is never drawn, in the tunnel or out of it. He is a ridge,
  cracks, grit, dust and sound.
- **Where he is:** a distance along the tunnel and an angle around its
  cross-section. The bore's shape changes along the way, so the ridge sits on
  the real surface of the bore (halls and caverns differ; see
  `scripts/endless/land_tunnels.gd`, `tunnel_sites.gd`).
- **The layout is fixed per tunnel,** drawn from the tunnel's seed: which spurs,
  at what distance and angle. He reveals it as he passes; he doesn't decide
  live. Same seed, same spurs, on every machine. About one spur per 85 m to
  start; keep the spacing in one named constant, because it will be tuned by
  flying.
- **The tell:** the ridge marks the spot, the spot cracks with grit falling,
  and after a hold the spur snaps out fast. Spurs fire off him, not off the
  plane, so a plane close behind him gets less warning. Nothing else needs to
  scale it.
- **How far ahead he runs:** 90-150 m ahead of a plane at speed, about 2 s of
  warning. Keep it in named constants. A scrape costs the plane speed and he
  stretches away by that alone; don't add a rule for it.
- **The crack must read** from 60-85 m in the dark tunnel at about 57 m/s. If
  shape alone doesn't, it may glow or throw light. Judge it in rendered stills
  taken in a real tunnel, and iterate before handing back.
- **The gap:** a spur never closes the way. What's left past it is at least
  `WorldScale.opening(TOY_...)`, with the toy width a named constant in the
  file that owns it (AGENTS.md, Sizes). Check this against the bore at the
  spur's spot, since halls are about 27 x 18 m and caverns are wider.
- **Spurs are stone:** on LAYER 1 like the bore, so `scripts/endless/near_miss.gd`
  and `scripts/endless/flight_contact.gd` treat them as they treat walls. No
  new consequence: a scrape is a scrape and a crash is a crash. No hearts or
  damage. Prove that a graze on a spur scores through the real play loop.
- **Pieces are pooled rock meshes that slide out of the bore.** Don't deform the
  bore's mesh or rebuild its collision during flight. Watch frame cost: the
  chase runs flat out, low, with the land loading around it.
- **Spurs stay out** after he's been through, for as long as that tunnel stays
  built. Nothing goes in the save. A tunnel he hasn't run stays as it is now.
- **A crash, a landing or losing him** ends the chase. He stops being there and
  the usual rest starts. If the plane doesn't follow him in within a few
  seconds of `plunge`, he's gone as he is today.
- **The rumble:** a low positional sound from where he is on the tube, so it
  moves around the plane. A placeholder sound is fine; say so in the handoff.
- **The far mouth:** he leaves in a plume big enough to read from inside the
  bore. Then the chase ends and the rest starts.

## Tasks, in order

The first iteration may split these further. Each ends in something to look at
or fly.

1. **He carries on inside.** `plunge` hands him to the bore: a position by
   distance and angle, a visible ridge on the real surface winding around the
   tube, holding his distance ahead of the plane, ending at the far mouth. No
   spurs.
2. **Spurs and their tell.** The seeded layout, crack, hold, snap, pooled pieces,
   collision on LAYER 1, the gap rule.
3. **The ends and the sound.** The plume at the far mouth, the chase's other
   endings (crash, landing, not following), the rumble.
4. **Read it and pace it.** Fly the whole of at least two tunnels, one with a
   real player's input path through the driver, fix what doesn't read in rendered
   stills, and write the handoff.

## Where it plays

`studies/endless_flight.tscn`, seed 1. Meet him (from step 1):
`--at=3400,4384 --heading=90 --alt=60` (mouth `1_1/a`, on its axis),
`--at=-1486,6874 --heading=56.7 --alt=80` (`-1_1/a`, from the side). Seed 1's
four sunk tunnels are the only ones standing (`tunnel_sites.gd` `SUNK_SITES`).

Keep the new work in its own file(s), such as `scripts/endless/burrower_bore.gd`,
with small edits to `burrower.gd` and `burrower_flight.gd`.

## Checks

Prototype rules (AGENTS.md, Prototyping): the smoke check of
`studies/endless_flight.tscn`, throwaway checks through the real play loop in
`scratch/`, left uncommitted, no new committed tests and no full suite. A
handoff lists any existing test the work breaks. Rendered stills for anything
seen, one window at a time, with `-- --no-title`. macOS has no `timeout`. Use
`python3`, not `python`. Never `git stash` in a worktree: the stash list is
shared and holds the user's work. Anything that writes a save or layout writes
to `/tmp`; open builds with `--pilot-file=/tmp/<file>`.

## Not in this loop

After the user has flown this: the pinch, the ribs and the cave-in; him beside,
under and behind the plane; different tells for different pieces; the line
holding for the length of the chase; caverns as their own beats; what catching
him means; whether unvisited tunnels get dressing of their own.
