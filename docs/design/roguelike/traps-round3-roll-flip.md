# Traps, round 3: Rolling Logs and Flip Platforms (2026-10-12)

> Greybox only. Branch `feature/trap-roll-flip` (off `roguelike`). Built to the
> contract in traps-round1.md; no contract change. The user's idea: "platforms
> that are like rolling logs, or platforms that constantly flip over so you
> have to keep jumping over and onto them."

    godot --path . res://studies/trap_yard.tscn -- --no-title --trap=logs
    godot --path . res://studies/trap_yard.tscn -- --no-title --trap=flip

Test: `godot --headless --path . --script tests/test_trap_roll_flip.gd`.

## Rolling Logs (scripts/traps/trap_logs.gd), cost 2 (3 over the void)

Stone drums across a gap, spinning from the start (the first is seen turning
from the entry). The top moves; the pilot is carried with it (`motor.carry`,
a displacement per frame, not a teleport). Standing still he is walked off the
back of the log (or its side); running against it makes headway; hopping log to
log he barely feels it. Alternate logs spin opposite ways. Tell: four dark
stripes per drum (they go orange as the speed-up builds), a `rumble` sound
(placeholder) while he is on one.

| knob | default (wanderer 1.0) | meaning |
|---|---|---|
| count | 6 | logs |
| radius | 0.72 m (walk x 0.3) | drum radius; the flat collision top is 85% of the diameter |
| width | 2.4 m (run x 0.5) | log length across the route ("cross") |
| span | 7.2 m (walk x 3) | log length along the route ("along") |
| gap | 0.71 m (0.3 x a running small hop's reach) | between log tops |
| axis | "cross" | "cross": logs across the route, top moves along it; "along": side by side, top moves sideways |
| spin | 1.68 m/s (walk x 0.7) | surface speed |
| alternate | true | neighbours spin opposite ways |
| speedup | 0.08 /s | spin gain per second spent on the logs |
| max_boost | 1.8 | cap on the gain |
| rumble_gap | 0.5 s | between rumbles |

## Flip Platforms (scripts/traps/trap_flip.gd), cost 3 (4 over the void)

A row of slabs over a drop. Each cycles flat, tell, flip: the tell (`tell` s) is
a shudder, a `click` and the face up warming to orange; the flip (`flip` s) is a
fast 180 degrees about the slab's long axis (across the route). Anything on it
is carried round with it until it is steeper than `knock_angle`, then thrown
(back along the route, up a little, plus the slab's own pace at his point). It
lands upside down: the other face (blue-grey) is up until the next flip. Slab i
runs `stagger` s after slab i-1, so the flips run down the row like a wave and
the next slab is always flat for a hop after the last one flipped: with the
defaults the wave is a hop-per-0.6 s, a pilot hopping at that cadence is never
caught; one who dawdles is thrown.

| knob | default | meaning |
|---|---|---|
| count | 7 | slabs |
| length | 1.2 m (walk x 0.5) | along the route |
| width | 2.4 m (run x 0.5) | across |
| gap | 0.71 m (0.3 x hop reach) | between slabs (and before the first) |
| thick | 0.3 m | |
| period | 2.4 s | one flip per period |
| tell | 0.5 s | shudder + click + colour warm-up |
| flip | 0.22 s | the turn (a `clack` as it starts) |
| stagger | 0.6 s | slab i starts this much after i-1 (period/4: slabs i and i+4 move together) |
| underside | "safe" | "safe", "slick" (carries him back at `slick`), "gone" (no collision while that face is up) |
| slick | 1.44 m/s (walk x 0.6) | the slick face's slide |
| knock | 1.92 m/s (walk x 0.8) | the throw back along the route |
| knock_angle | 1.0 rad | tilt at which a rider is thrown |
| speedup | 0.04 /s | rhythm gain per second on the slabs |
| max_rate | 1.6 | cap on the gain |

`flat_for(i)` is the time slab i stays flat before its tell (for bots and tuning).

## Checks (tests/test_trap_roll_flip.gd)

Standing on a log: carried back at the surface pace, then off it (hangs by a lip
or falls). A scripted run with hops crosses the logs. Standing on a flip slab:
tell sounds first, then he is off it after the flip and the slab lies upside
down, a different colour. A scripted pilot hopping slab to slab at run pace
(waiting at an edge for a flat next slab) crosses all seven.

## Unverified / the user's call

- Feel, windowed: hop cadence vs stagger (the bot needs no waiting at 0.6 s;
  a human may want the wave slower or faster), flip speed, the throw direction
  (back along the route lands him on the previous slab or in the gap).
- The log collision is a flat box top, not a true curve: the feet ride flat
  while the drum visibly turns; the rolled-off feel at the log's edge is the
  box edge.
- "along" axis and the `underside` modes "slick"/"gone" are built but have no
  test; the sounds are placeholders (`rumble`, `click`, `clack`); no art.
- Rendered look and shudder readability not exercised (headless only).
