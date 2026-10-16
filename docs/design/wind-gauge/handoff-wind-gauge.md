# Handoff: the wind gauge (loop `wind-gauge`)

Spec: `spec-wind-gauge.md`. Trail: `git log --grep='^ITER(wind-gauge)'`.
Builds on the lock-on loop (`../lock-on/handoff-lock-on.md`).

## Built

- **Gauge** (`scripts/wind_gauge.gd`, made by `studies/kit_isle.gd`, so
  only the kit isle and the main game have it; `WIND_GAUGE_ON`): a brushed
  three-segment arc, lower left, over the updraft charge. Pulses on a
  filled segment, brightens and breathes when full, flicks a spent segment
  out, fades when empty and idle, hides while flying and under the title.
  A shake-and-dim cue on an empty press.
- **Segments** (`scripts/updraft.gd` `segmented`, on only in kit_isle via
  `SEGMENTED_CHARGE`): each unleash spends one full segment at a fixed
  strength; a part-filled segment is kept.
  - Updraft (Q / RB, not sliding): 3.2 m; each further one before landing
    rises 0.6 of the last (three chained: ~6.3 m).
  - Slide boost (Q / RB in any slide, `SLIDE_BOOST`): the forward burst
    along the slide, stick ignored (4.7 -> 13.6 m/s in the check). A
    crouch at a run counts as a slide.
  - Focus blast (X): the gust shot at a fixed 0.7 strength. No segment: X
    twirls.
- **Air charge** (`AIR_CHARGE`): one-off gains on flip 0.14, wall kick
  0.14, long jump 0.12, wall run 0.12, rope 0.12, twirl 0.09, chained jump
  0.06; wall runs +0.10/s and ropes +0.08/s while they last; airtime over
  6 m/s +0.06/s (not while his own updraft carries him). Ground running
  and sliding build nothing. Drain: the part segment after a 3 s lull at
  0.04/s; full segments held 15 s, then 0.015/s.
- character_study and snag_study keep the old all-at-once rule.

## Play it

`studies/zenscape.tscn -- --no-title`. Long jump, twirl, side flip to fill
a segment; Q to rise, crouch at a run then Q to boost, R3 on the stone
then X to blast.

## Open

- Wall-run, wall-kick and rope gains weren't driven (no wall or rope
  found by the driver); airtime-at-speed gains likewise only by code.
- Chained updraft height and all gain numbers are first guesses: tune by
  playing.
- No sound cue on spend or empty.
- Smoke on zenscape, aqueduct_isle and character_study: PASS. No
  committed tests (prototype round).
