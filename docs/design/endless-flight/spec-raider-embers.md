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

## Round 2 (spec change, 2026-11-04, after the user flew round 1)

The user's verdict on round 1: "Pretty fun! But not enough chase. Plane is
hard to see, and feels like parry spam." Parrying was fun, but it came
whatever they did, so they never had to fly well and never felt they could
focus on the chase. What they want: to keep the chase alive *for* the parry
chances. The embers are the raider going "shoot, he's on my tail, I better
lose him."

Done looks like (round 2), on top of round 1:

1. **Panic on its tail.** It fires embers only when you're on its tail:
   close behind it (about 80 m, a knob) with your nose roughly on it. Off
   its tail it just runs its line and fires nothing. On its tail it also
   **jinks**: sharper turns, dives under arches, cuts through tree gaps
   (always gaps the plane fits, `WorldScale.opening`), trying to shake you.
   So the parry stretch is also the hardest stretch to hold on to.
2. **Kept close.** It holds a tighter range (about 40 to 150 m) so it's big
   on screen and you're reading its line. Slightly faster than you on a
   plain line; skimming and following its line keep you in range.
3. **Losing it is the stake.** Behind past about 200 m for a few seconds,
   it gets away for good, locked on or not (no free come-round). The next
   one buzzes after the gap.
4. **A missed ember knocks you back** out of tail range (a real shove plus
   it surging away), so you fight your way in again.
5. **A parry pays.** A parried ember staggers it: its panic breaks for a
   moment and the slow pulls you right onto its tail. Three cripple it
   (as built); the surge roll kills it (as built).
6. **Seeing it.** A coloured ribbon trailing it (reads its line from far
   off, something to follow) and a brighter look on the raider so it
   stands off rock and grass.

Tasks, in order:

1. Panic on its tail (fire only on its tail, the jinks), kept close, the
   getaway, the missed-ember knock-back. Driver: embers fire only while on
   its tail; a run that hangs back gets none and loses it; jinks stay
   flyable (no clipping, gaps the plane fits). Look at: the launcher.
2. The ribbon and the brighter look. Look at: stills at 40, 100 and 150 m
   over land and trees.
3. Tuning: jink strength, fire rate on the tail, skim gain, the parry's
   stagger and slow, the ranges. A decent pilot holds on, parries a few and
   kills in roughly 30 to 60 s; a lazy line loses it. Update
   `raider-embers-handoff.md` with the numbers. Look at: the launcher.
