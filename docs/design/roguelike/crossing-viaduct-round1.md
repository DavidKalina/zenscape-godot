# Crossing round 1: The Broken Viaduct (greybox)

Branch `feature/crossing-viaduct` (cut from `roguelike`, not merged).

A pure-skill crossing between two isles of the spiral, workshopped on its own
in the crossing yard. It uses only the pilot's on-foot moves
(`scripts/pilot_motor.gd`). Every distance is worked out in `lay_out()` from a
motor fitted to the walker's size (`Crossing.walker()`, `WorldScale.wanderer`),
so no copied sizes.

## Run it

    ./run-crossing-yard.command                 # windowed
    ./run-crossing-yard.command --beat=4        # start at a beat (1-5)
    godot --path . res://studies/crossing_yard.tscn -- --no-title [--crossing=viaduct] [--beat=n]

Keys: **R** back to the start rim · **1-5** practice spawn at each beat
(run-up, piers, chimney, launch, far rim) · **N** next crossing (there is only
one so far). Moves: Shift/C at a run slides, + Space long jumps (again on each
landing chains it) · Space on landing pumps · X twirls · into a wall: slide,
Space kicks. When he stands on the far rim, a toast shows the time since he
left the start rim. A fall lands on the soft floor (the "turn below"), and he
walks back: the aqueduct head beside the start rim has treads to climb.

## Files

- `studies/crossing_yard.gd/.tscn`: the yard (extends `studies/kit_isle.gd`:
  the same pilot, camera and input). It has the aqueduct isle's cloud sky and
  no island. `CROSSINGS` maps names to scripts, one line per crossing.
- `studies/crossings/crossing.gd`: the shared base. It holds the contract
  (`lay_out`, `build(paint)`, `entry`, `exit`, `exit_reached`, `beats`,
  `floor_y`, `title`) and greybox helpers (`box`, `column`, `slab`, `piece`,
  headings).
- `studies/crossings/crossing_viaduct.gd`: the Broken Viaduct.
- `tests/test_crossing_viaduct.gd`: the headless test.

## The beats and their numbers (default walker size)

Total gain from start rim to far rim: about **15.6 m** (the slot's rim is
20.1 m up).

1. **Run-up.** Three real aqueduct spans (`RuinKitAqueduct.span`), tilted
   `RUN_DEG` 4.5° (2.6 m rise, flat ground to the slide). Next comes the
   fallen span: the far deck is `FALL_DROP` 4.0 m lower, and the gap is
   `fall_gap` 9.21 m. That is `FALL_SPARE` 0.5 m past the furthest a plain
   running long jump (7.6 m/s) can catch the far lip (8.71 m). The reaches
   at that drop are:
   - plain jump: lands at 7.61 m;
   - chain of two (9.0 m/s): lands at 9.01 m, catches up to 10.23 m;
   - chain of three (10.4 m/s): lands at 10.42 m.

   So a chain of two taken near the lip catches the ledge, and a chain of
   three lands. **A plain jump twirled at its peak also lands**: the twirl is
   that strong (TWIRL_TOP 9 pushes 7.6 up to 9). I left it as "the twirl is
   your one save". If the chain must be the only answer, the twirl needs a
   counter here (an overhang, a headwind) or a motor change.
2. **Piers.** From a turn platform the route bends 55° right over `PIERS` 10
   lip-capped piers. The first is 0.5 m up (under the plain jump). Each
   after is `pier_rise` 0.9 m higher (the pump's 1.5 m less `PUMP_SPARE`
   0.6). They are `pier_gap` 1.03 m apart, so a pump taken anywhere in the
   0.3 s chain window lands on the next top. After the piers comes the
   slot's plinth.
   - **Safe line:** RuinKit `stairs` flights (`safe_flights`, 5 at these
     numbers) with rests between, 4.6 m to the right of the piers. They run
     from the turn platform (stepped down onto) up to the plinth's edge.
3. **Chimney slot**: see below.
4. **Launch.** A `SLAB_DEG` 28° slab runs `SLAB_RUN` 7.5 m off the slot's
   east head, then a flat lip of `LIP_RUN` 2 m on a broken pier. The far
   rim is `FAR_DROP` 0.5 m under the lip and `far_gap` 8.23 m out
   (`LAUNCH_SPARE` 0.3 m past the bare launch's furthest catch, 7.93 m).
   A twirled launch lands at about 8.69 m.

**Fast wall-run line: not built.** A wall run gains at most about a metre,
so it can't skip a 12 m chimney without its own geometry. It needs a design
pass.

## The chimney slot

Constants in `crossing_viaduct.gd`:

| Constant | Value |
|---|---|
| `SLOT_HEIGHT` | 12.0 |
| `SLOT_YAW_DEG` | `-TURN_B` (the +Z door faces back down the piers) |
| `SLOT_PLINTH` | 4.6 (half size of the plinth) |
| position | `slot_at()` / `slot_foot` |

The stand-in copies the real `RuinKitTower.tower_shell` exactly:

- footprint ±2.39 by ±2.70 (`STAND_HALF`);
- shaft ±0.99 by ±1.3 (`STAND_SHAFT`);
- doorway 1.3 wide and 2.6 tall at z +2.7 (`STAND_DOOR`);
- the east and west kick walls run only the shaft's depth (z ±1.3). Their
  heads are the walkable rims at `height`, x from ±0.99 to ±2.39;
- the front and back walls span the full width, `STAND_LOW` 1 m below the
  rims.

The launch slab starts at the east wall's outer edge (local +X, heading
`TURN_B+90`).

**The swap is one line** in `slot_piece()`:

    return RuinKitTower.tower_shell(seed_value,weathered,height)

Also add `const RuinKitTower = preload("res://scripts/ruin_kit_tower.gd")`.

Untested: the real piece's rubble reaches about 3.9 m, inside the plinth's
4.6. Its weathered front and back heads come out ragged and lower than the
stand-in's.

## Verified headless vs not

`tests/test_crossing_viaduct.gd` passes, 0 failures. It drives the pilot
through the yard's own `tick` (the real motor over the built colliders) with
scripted stick and buttons:

- A plain running long jump at the lip falls short, with no catch.
- A chain of three, timed on each touch, lands on the far deck. It lands
  when the last takeoff is within about 1.3 m of the lip, catches the ledge
  from about 1.6-2.0 m, and the test measures both.
- One jump, then a pump on each landing, reaches all 10 piers and the
  plinth.
- Slid down the slab, long-jumped off the lip's edge and twirled at the
  peak, he lands on the far rim. Not twirled, he falls short.

Load check (`--headless ... res://studies/crossing_yard.tscn --quit-after
300`): clean.

**Not verified:**

- The chimney climb itself. The stand-in's shaft matches the real kick gap,
  but no kick-up is tested here; the tower-shell branch tests its own climb.
- Stepping off the slot's rim onto the slab.
- The safe stair walked end to end.
- Climbing back from the floor via the aqueduct head.
- Feel at human timing.

One windowed capture was taken from behind the start rim. The climb reads
from the start, but the far rim's tall column stands in front of the slot
from there, so the slab is not cleanly silhouetted. The column could be
thinned, or the launch heading turned.
