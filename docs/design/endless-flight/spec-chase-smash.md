# Smash through the chase, and a live meter

Step 3 of the burrower at the caves (step 2: `spec-burrower-chase.md`,
`burrower-chase-handoff.md`). The tunnel chase works, but it's one thing over
and over: a spur snaps out and the plane dodges it. This loop gives the surge
roll something to do in the bore, adds a second kind of obstacle, and varies the
spurs. Alongside it, the meter fills while you fly well instead of only after a
line banks.

Loop: slug `chase-smash`, branch `iter/chase-smash`, worktree
`zenscape-chase-smash`, the skill's default cap.

- **Lane `meter`** (branch `lane/meter`, worktree `zenscape-meter`): the live
  meter, below. One agent, its own commit(s). Merged into `iter/chase-smash`
  when it lands.
- **The trunk** (this loop): the chase tasks, in order. They don't need the
  meter lane until the last task, which tunes the two together.

## What done looks like

The user follows him into a sunk tunnel. Spurs no longer come alone, one by one:
there are pairs, gates (two spurs with the gap between them), and runs that
corkscrew around the bore. With a full meter, the plane surges and smashes
straight through a spur in a burst of rock. Now and then he brings the roof down
behind him: a plug of rubble fills the bore with one small hole in it. The
plane threads the hole, or surges and smashes the plug. Throughout, the meter
climbs as the plane grazes and threads, not only after the line goes quiet.

## The rules

### The surge shatters spurs (trunk)

- A plane in a surge (`scripts/endless/surge_smash.gd`, `smash.hot`) that
  meets a snapped spur breaks it, with no crash or scrape. The spur bursts into
  pooled debris, its collision goes, and it stays broken for as long as that
  tunnel is built. Nothing goes in the save.
- The bore itself stays unbreakable. Only spurs (and plugs, below) break.
  `surge_smash.gd`'s header says rock, halls and bores are left out: keep that
  true for the bore, and update the header to say spurs and plugs break.
- A smash should read as a big moment: debris, a thump, a camera kick, sized
  for flying through at speed. Use the break kit (`scripts/breaks/`) if it fits
  pooled rock; otherwise keep the debris pooled in the chase's own files.
- Score it: a smashed spur or plug is a scored moment on the line
  (`near_miss.gd`, `line_moves.gd`, `line_tune.json`). Its value is a named
  tune key.
- A spur that hasn't snapped out yet (still in its tell) isn't there to hit.

### Spur patterns (trunk)

- The seeded layout (`scripts/endless/bore_spurs.gd` `plan()`) draws from a
  few patterns instead of single spurs: **single**, **pair** (two at once,
  across the bore from each other), **gate** (two spurs close together, a
  gap between them that's the line), and **corkscrew** (three to five in a
  run, stepping around the tube). Each pattern's weight and spacing are named
  constants.
- Still fixed per tunnel, from its seed. Same seed, same layout, on every
  machine.
- The gap rule still holds for every pattern: what's left past the spurs at
  any spot is at least `WorldScale.opening(TOY_...)`. A gate's gap counts as
  the way through.
- The tell still fires off him as he passes. A pattern's spurs may share one
  tell or stagger theirs; pick what reads, and judge it in rendered stills.

### Plugs (trunk)

- A **plug** is a wall of rubble across the whole bore, with one hole. He
  brings the roof down behind him: a tell (rumble, dust falling over the
  whole tube, a crack around it), then the rubble drops and seals the bore
  except for the hole.
- **The hole** is threadable: at least `WorldScale.opening(TOY_PLUG_HOLE)`,
  with `TOY_PLUG_HOLE` named in the plug's file. It sits off-centre, at a
  seeded angle, so threading it is a line, not a freebie. A plug never
  seals the bore: the hole is always there.
- **The plug is stone.** Hitting it outside the hole is a crash, as with the
  bore. Threading the hole scores as a thread (the existing thread moment, or
  a new one if the existing one doesn't fit).
- **A surge smashes the whole plug.** The plane flies through debris. Score it
  as a smash.
- About one plug per tunnel to start, never close to a mouth and never on top
  of a spur pattern. The count and spacing are named constants.
- Plugs are pooled meshes, as spurs are. Don't rebuild the bore's mesh or
  collision during flight. Plugs stay down after he's been through, for as
  long as that tunnel stays built.
- Keep the new piece in its own file (e.g. `scripts/endless/bore_plug.gd`),
  with small edits to `burrower_bore.gd`.

### The live meter (lane `meter`)

Today `near.meter` (`scripts/endless/near_miss.gd`) only rises when a line
banks: the chain's points wait until 4.5 s of quiet (`bank_after`), or until
the bank would fill the meter. So a long streak holds the meter back.

- **Each scored moment adds to the meter as it scores**, by its points over
  `meter_full()`. That covers grazes, threads, skims and every other scored
  moment, and prizes still add as they do now.
- **Banking moves points into the score only.** It no longer touches the
  meter. The early-bank rule (`fills`, bank now because it would fill the
  meter) goes.
- **A scrape, crash or knock** (`lose()`) drops the unbanked score, as now.
  The meter keeps what it has.
- **No refill while surging.** Moments scored while the surge is hot (`fly_surge`
  held or `smash.hot`) add to the score, but not the meter.
- The HUD shows the meter climbing live. Read the HUD files
  (`near_miss_hud*.gd`) for anything that assumed the meter only moves on a
  bank (a flash or sound on bank, say), and move it to the right moment.
- Leave `meter_full` at its current value; the trunk's last task tunes it by
  flying.
- Keep edits to `near_miss.gd` small, and end the commit with **Notes for
  merge** naming the lines touched. The trunk's smash scoring adds lines in
  the same file.

## Tasks, in order (trunk)

The first iteration may split these further. Each ends in something to look at
or fly.

1. **The surge shatters spurs.** Break, debris, collision off, the score
   moment. Prove a surge through a snapped spur in the real play loop: no
   crash, the spur gone, the moment scored. Stills of the burst.
2. **Spur patterns.** Pair, gate, corkscrew in `plan()`, the gap rule
   checked per pattern. Stills in a real tunnel of each.
3. **Plugs.** The piece, the tell, the hole, the crash, the thread, the
   smash. Prove threading and smashing through the real play loop. Stills.
4. **Merge the meter lane, then pace it.** Merge `lane/meter` into
   `iter/chase-smash` (the coordinator does this once the lane lands; if it
   hasn't, say so and stop). Fly at least two whole tunnels through the
   driver's real input path. Tune `meter_full`, pattern weights, plug count
   and spacing so the meter fills about once or twice per tunnel when flown
   well. Write the handoff (`chase-smash-handoff.md`).

## Where it plays

`studies/endless_flight.tscn`, seed 1. Meet him (from step 1):
`--at=3400,4384 --heading=90 --alt=60` (mouth `1_1/a`, on its axis),
`--at=-1486,6874 --heading=56.7 --alt=80` (`-1_1/a`, from the side). The
burrower-chase handoff lists launches that start in the air.

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

Projectiles; stalactites; the pinch, the ribs and the cave-in; him beside,
under and behind the plane; what catching him means; braking as a way to
charge.
