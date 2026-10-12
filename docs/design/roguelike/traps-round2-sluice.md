# Traps, round 2: Sluice Flush (2026-10-12)

> Greybox. Branch `feature/trap-sluice` (off `roguelike`). Built to the round-1
> contract (traps-round1.md) with no contract change. `scripts/traps/trap_sluice.gd`,
> test `tests/test_trap_sluice.gd`, one line (plus its preload) in `studies/trap_yard.gd`.

A walled channel (the aqueduct's `CHANNEL` and `PARAPET` at the wanderer's
size) over a drop, a gate over its head. A plate (or a wait) starts a 2 s tell:
the water drops to a trickle, three rising gurgles (`gurgle_low/mid/high`), the
gate header flashes the tell orange. Then a wave (translucent box) runs the
channel at twice the run, and `motor.carry` moves anyone inside it (below the
wave's top) with it each frame. The open end is a gap (cost 3, +1 void = 4).

Counters: the refuge shelf in the channel wall (top = jump height 0.8, over the
0.6 wave): jump up and stand. Or ride it: a jump taken while carried adds the
wave's pace to his velocity, so the leap clears the end gap.

## Knobs (defaults at wanderer 1.0)

| knob | default | meaning |
|---|---|---|
| length | 28.8 m (run x 6) | channel |
| gap | 2.4 m (walk) | drop at the open end |
| end | "open" | "pool": a wall instead, he is swept against it |
| wave_height | 0.6 m (jump 0.8 x 0.75) | carried below this |
| wave_length | 3.6 m (walk x 1.5) | |
| speed | 9.6 m/s (run x 2) | |
| tell_time | 2.0 s | |
| trigger | "plate" | or "timer": `period` s (4) in the channel |
| plate_at | 4.3 m (run x 0.9) | down the channel |
| second_wave / second_gap | false / 1.5 s | |
| refuge | 1 | shelf in the wall (0 none) |
| flow | 0.21 m | idle water depth |

## Run

    godot --path . res://studies/trap_yard.tscn -- --no-title --trap=sluice

Test: `godot --headless --path . --script tests/test_trap_sluice.gd`.

## Unverified

- Windowed run, the look of the water/wave/gate flash, the gurgle (no audio hook yet).
- Feel: a runner who steps on the plate and keeps running just gets caught near
  the end (2 s head start vs 2x speed); the timer trigger, pool end and second
  wave are built but untested; the leap momentum (`motor.velocity` add after a jump
  while carried) is not exercised headless, and may be overwritten by the motor.
- The wave has no collision, only the carry; no wade slowing or swim in the wave.
- Climbing from the channel floor onto the shelf (jump to a 0.8 lip) is not tested; the test sets him on it.
