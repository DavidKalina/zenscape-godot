# Traps, round 1: the contract, the yard, Loose Voussoirs (2026-10-12)

> Greybox only. Branch `feature/trap-contract` (off `roguelike`). Ideas are in
> ideas-traps.md; this is what exists.

## The contract (scripts/traps/trap.gd)

Every trap `extends "res://scripts/traps/trap.gd"` (a Node3D; its own frame has
the way in at the origin and the route along -z, so a generator places it by
setting `transform`).

- `knobs` (Dictionary from `defaults()`): all timings, forces, sizes, built from
  `pilot()` (a PilotMotor at WorldScale's wanderer size: `walk`, `run`, `jumps`,
  `gravity`), never metres. `configure({...})` overrides before adding.
- `cost` 1-5, `under` ("layer" soft fail or "void"), `danger()` = cost, +1 over void.
- Tell: `tell_sight(amount 0..1)` (override to tint) and `tell_sound(kind, at)`
  (records in `heard`, emits `sounded`; the audio hook comes later).
- Route: `length()`, `footprint()` (local x z rect), `entry()`, `exit()`,
  `run_up()`, `verbs`.
- Stepping, same slot as foot_pieces: `before(delta)` ahead of the motor step
  (use `motor.carry` / `motor.toss`), `after(delta, events)` after it,
  `air_at(p)` -> `{wind, thermal}` for wind (the TrapField sums all traps' into
  `motor.air`), `reset()`, `build()` (once in the tree). `motor` is set by the field.
- scripts/traps/trap_field.gd (TrapField) fills the study's `foot_pieces` slot
  and steps all traps.

Draft Vents: `air_at`. Seesaw: `before` carries the pilot with the pivoting body
(`motor.carry`, as foot_pieces does for slabs). Sluice: `before` pushes/`carry`s.

## Adding a trap (the steps)

1. Write `scripts/traps/trap_<name>.gd` extending trap.gd: set `trap_name`,
   `cost`, `under`, `verbs` in `_init` (after `super()`), `defaults()`,
   `length()`, `build()`, and `before`/`after`/`air_at`/`reset` as needed.
   Copy trap_voussoirs.gd as the model. Sizes from `pilot()`/WorldScale only.
2. In studies/trap_yard.gd add a `preload` and ONE line in `TRAPS`:
   `"<name>": TrapScript,`. Lane, decks, floor, station key and `--trap=<name>`
   come free.
3. `tests/test_trap_<name>.gd` modelled on test_trap_voussoirs.gd.

## Run the yard (windowed)

    godot --path . res://studies/trap_yard.tscn -- --no-title --trap=voussoirs

Number keys go to a trap's start, R restarts (traps rebuilt). Headless:
`godot --headless --path . --script tests/test_trap_voussoirs.gd`.

## Loose Voussoirs (scripts/traps/trap_voussoirs.gd)

A row of slabs over a drop (the yard floor is 4 jumps down). Each drops `delay`
after the pilot first lands on it. First slab only tests. Tell: slabs off true
and darker, dust + `grind` sound on touch, orange warm-up before falling.

| knob | default (wanderer 1.0) | meaning |
|---|---|---|
| count | 8 | slabs |
| length | 1.2 m (walk x 0.5) | along the route |
| width | 2.4 m (run x 0.5) | across |
| delay | 0.375 s (0.75 x length/walk) | touch to fall |
| gap_every | 0 | every nth slab missing |
| first_tests | true | slab 0 never falls |
| offset | 0.04 m | untruing |
| fall_time | 2.5 s | fallen slab stays drawn |
| seed | 7 | the untruing |

Run (0.25 s per slab) crosses; walk (0.5 s) doesn't.

## Unverified / the user's call

- Feel: the delay (0.375 s vs the idea doc's 0.5), dust/colour readability,
  the dropping sound (placeholder only), the drop depth.
- Walking onto the next slab as the first falls: the walker usually ledge-grabs
  the next slab's lip (hangs); the test accepts fall or hang.
- Not built: the chain-drop knob, slab-onto-lower-trap arming, combos.
- Windowed run and rendered look not exercised (headless load only).
