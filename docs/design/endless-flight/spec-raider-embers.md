# Spec: the raider chase with embers (loop `raider-embers`)

Branch `iter/raider-embers` (worktree `zenscape-raider-embers`), made from
`iter/raider` with main (the parry) merged in. Builds on the raider
(`scripts/endless/raider.gd`, `raider_chase.gd`, `lock_on.gd`;
`raider-handoff.md`, `raider-combat-handoff.md`) and the parry
(`scripts/endless/parry.gd`, `parry-handoff.md`). Still an experiment:
everything stays behind `--raider`, smallest playable builds, smoke checks
and throwaway drivers in `scratch/`, no committed tests. Seed 1.

## Done looks like

The fight is a chase, start to finish. No dogfight, no offscreen arrow.

1. **It buzzes you.** A raider comes up from behind and passes close
   overhead or beside you, where you can see it, with a whoosh, then runs
   ahead low and fast (the chase as built: trees, arches, plane rules,
   never a gap the plane can't fit).
2. **You choose.** Lock on (R3 / Y / middle mouse, as now) and chase it, or
   let it fly away. Not locked and far enough off (or out of view long
   enough), it's gone for good; the next one buzzes you a while later.
   Locked on, it keeps running and comes back round ahead if you lose it,
   as now. No offscreen arrow or edge marker for the raider at any time;
   the parry's own tell (rings, pip, whistle) stays.
3. **Embers.** While it runs, it fires embers back at you from its tail:
   glowing orange balls with a short streak, big and slow enough to read
   from behind at chase speed. They fly through the parry (the raider
   joins `parry_source` and answers its contract, `parry.gd` header), so
   the rings, whistle, hit-stop, slow motion and meter all come for free.
   Greybox look: emissive spheres, a trail. A look pass is later.
4. **A parry slows it.** A parried ember goes home onto the raider: a
   burst of sparks and a puff of smoke, and it slows for a few seconds and
   trails smoke while slowed. Hits stack up to a cap (crippled: slow, low,
   smoking hard). The parry's meter pay fills the gauge as it does for the
   ship.
5. **Skimming still closes the gap** (the chase's skim heat, as now). Two
   ways to catch up: fly low, parry well.
6. **A missed ember** knocks you (a shove and a wobble, like the old ram
   hit), no damage; the raider pulls away a little.
7. **The kill.** Caught up with the gauge full, the surge roll that reaches
   it knocks it out of the sky (the kill as now). Then a gap and the next
   one buzzes you.

Flags: `--raider` turns it on. The dogfight and the mix go out of the
default; keep the code reachable behind `--raider-mode=dogfight` only if
that's cheap, otherwise leave it unreached. New knobs get a flag each for
tuning (ember rate, ember speed, slow per hit and its time, the hit cap,
the let-go distance, the gap between raiders).

## Tasks (trunk, in order; no lanes)

1. **Chase only, the buzz, let it go.** Default mode is the chase. The
   raider arrives by buzzing past from behind into view, then runs. Drop
   the raider's offscreen arrow/marker. Not locked and far off or long out
   of view, it leaves; the next comes after a gap. Look at: a still of the
   buzz, the launcher.
2. **Embers through the parry.** It fires embers back from its tail at a
   tunable rate; they reach you, a missed one knocks you, a parried one
   goes home. Check through the real play loop that a roll timed by the
   driver parries one. Look at: stills of an ember closing with the ring,
   the launcher.
3. **The slow and the smoke.** A parried ember's hit slows it, stacks to
   the cap, trails smoke; the gap closes. Check the gap over a run with
   parries vs without. Look at: still of a smoking raider, the launcher.
4. **The kill and pacing.** Kill after catching up on a full gauge, the
   gap to the next raider, ember rate and slow tuned so a decent run
   parries a few, closes and kills in roughly 30 to 60 s. Write the
   handoff's numbers in the Decisions. Look at: the launcher.

Smoke checks every iteration: `python3 tools/smoke.py
studies/endless_flight.tscn -- --raider`, and the same without `--raider`
(the game with no raider must be unchanged).

Cap: the skill's default. Budget per iteration: 150000 tokens (the user's
pick for this loop).
