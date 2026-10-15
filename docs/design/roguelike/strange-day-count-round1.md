# The Day-Count, round 1 (prototype, 2026-10-15)

> Round 4's strange-city card **t1-day-count** (lens4-traps.md, in
> `brainstorm/round4-strange-city/` on the round-4 brainstorm commits),
> built as a playable trap in its own yard. Prototype: proved by a smoke
> check and a throwaway drive; no committed tests.

## Play it

    ./run-strange-day-count.command
    godot --path . res://studies/strange_day_count_yard.tscn -- --no-title [--olmec] [--knob=<k>=<v>] [--body-knob=<k>=<v>]

You start on a basalt plaza facing the court. **1** the plaza, **2** the
hub, **3** the terrace (the way out). **O** brings the Olmec in from the
plaza's far end, hunting you (O again sends him away). **R** puts back
you, the court and the Olmec. Top right is the count: footfalls, clicks,
which rings are lit, and how many clicks until the stair.

## The rule

The court is three nested stone rings round a still hub, over the void.
They turn on **footfalls, not a clock**:

- Every footfall on the court (the rings, the hub, a stone's top) by
  anyone is counted. Every `per_click` (4) footfalls the ratchet clicks
  once. The Olmec's every step is a whole click.
- A click turns the outer ring one notch (22.5°, 16 a turn), every 2nd
  click the middle ring a notch the other way, every 4th the inner ring.
- Stood still, nothing turns. Jumps, hangs, climbs and wall runs make no
  footfalls, so they click nothing. The plaza and the rim don't count.

Why 4 footfalls a click: the drawn body puts a foot down about 6 times a
second at a walk (every 0.38 m) and every 0.72 m at a run. One notch per
footfall turned the outer ring faster than he walks. At 4 a walk clicks
about every 1.5 m, a run every 2.9 m (the card's "a run covers the court
in fewer clicks"). `--knob=per_click=1` plays the card literally.

## The route the rings carry

Each ring has four day-stones, one on each quarter, and two holes to the
void between them. The inner stones are one set-off tall (1.6 m), the
middle two, the outer three. The terrace on the north is four set-offs
up: no catch reaches it from the floor. When **all three rings stand in
line** (a stone of each on every quarter's bearing), the stones make a
stair: hub, inner stone, middle stone, outer stone, terrace, each a
standing jump and a catch apart (0.9 m across, 1.6 m up). That window
comes every 16 clicks, the first at click 11. Every 64 clicks the
**calendar round** puts each ring's paler sun stone at north and opens the
hub's cache (its lid slides aside, a warm light).

The trick is the card's: walking on a stone's top clicks its ring out
from under you. So you count on the hub (stop when all three rings are
lit), then go up by standing jumps without a step on any top.

## The tell

- **Sound** (synth placeholders in the yard): a dry *clack* each click, a
  low *burr* when a second ring grinds round with it, a deep *thrum* when
  the next click completes the stair, a knock and hum when it stands, a
  long hum on the round.
- **Sight**: each notch has a carved day-sign on the ring's top, and each
  stone a band of glyphs on its inner and outer faces (the city kit's
  dead grooves). A ring's glyphs warm to amber when it stands in line, all
  three lit is the stair, and they flare on the round. The hub has a carved
  sight line to the north. The motion itself is the main tell: a notch is
  a 0.45 s heavy lurch (eased in and out), then a hold.
- Weathered city basalt (`CityStone`, the Olmec's stone), no spikes, no red.

## How it's built

- `scripts/traps/trap_day_count.gd` follows the trap contract
  (`scripts/traps/trap.gd`) and is stepped by a `TrapField`. Its knobs are
  sized from `pilot()` and `RuinKit` (hub 0.375 run, ring 0.25 run, rise
  `SET_OFF`, stone two `STAND`s deep).
- Each ring is an `AnimatableBody3D` marked moving ground
  (`PhysicsGround.mark_moving`), posed in `_physics_process`. The motor's
  own `mover` carries him round with it exactly, standing or hanging.
  The stones are a second moving body per ring, **walker-only**
  (`WalkerOnly.mark`). The Olmec barges through them as he does a
  walker's cresset; otherwise the stones stopped him at the court's edge.
- The colliders are grown past the drawn seams and chords, because a 5 cm
  seam swallowed the walker's ground ray.
- **The footfall hook** (local, not the noise bus): the yard overrides
  `_body_events` and hands the drawn body's `footfall` (the event the
  step sound plays on) to `court.footfall(at, "wanderer")`. It does this
  only while he is grounded and not hanging, swimming or wall running.
  The enemy field's `sound_hook` hands each `body_step` to
  `court.olmec_step(at)`. The court counts only what lands on it
  (`on_court`).
- No shared file was edited.

## Proved (headless)

- Import clean. `python tools/smoke.py studies/strange_day_count_yard.tscn`
  passes, with and without `--olmec`.
- Throwaway drive `scratch/day_count_drive.gd` through the real loop and
  input:
  - **Standing still** on the plaza, then on the hub for 4 s: no
    footfalls and no turn. Walking on the plaza counts nothing.
  - **Walking a lap on the court**: 94 drawn footfalls, 94 counted, 23
    clicks. The notches were [23, -11, 5], as the gear says. Every ring
    settled on its notch, and nothing moved in the 3 s stopped after.
  - **Carried**: stood on the outer ring through 12 clicks, he kept his
    place on the ring (0.000 m drift), stayed on his feet and turned
    270° with it.
  - **The stair**: pacing the hub's north edge turned the rings into the
    window at click 11. He stopped, then went up by stick and jump
    hub → 1.6 → 3.2 → 4.8 → terrace 6.4 with no clicks on the way. On a
    fresh court the same climb fails at the second stone.
  - **The Olmec**: called in with the wanderer stood on the hub, he
    hunted him (a suck from the plaza, then a leap onto the hub) and his
    steps on the court were counted and clicked it (2 to 3 steps a run).
    His landing threw the wanderer about and once into a hole; the void
    puts the whole yard back, as R does.
- Related tests: `test_trap_voussoirs`, `_seesaw`, `_sluice`,
  `_sluice_aqueduct`, `_wind`, `_roll_flip`, `test_world_scale_guard`,
  `_fit`, `test_stun_yard` and `test_character_study` pass.
  `test_trap_giants` fails ("thrown at lurch 3") with or without these
  files: it was failing already, not broken here.

## Not verified

- **No rendered look.** This round ran headless, so the stone, the glyph
  glow, the lurch's feel and the camera on a turning ring are unseen.
- Sounds are synth placeholders, unheard.
- The Olmec falling through a hole (the card's Rule 0) didn't come up in
  the runs. He isn't carried by a ring he stands on: the floor moves under
  him and he stays put.
- Whether 4 footfalls a click, the 0.45 s snap, 16 notches and the
  stone-per-quarter stair feel right is your call (all knobs).

## Seams

- No noise: the clacks don't reach the Olmec's hearing yet. When the noise
  bus lands, `tell_sound` (the trap contract's `sounded`) is where to emit
  it.
- The footfall hook lives in this yard. A generator placement needs the
  same two lines in its study: `_body_events` → `footfall`, and
  `sound_hook` → `olmec_step`.
- Not in the generator.
- The calendar round's cache is only a lid and a light. There are no runes
  in it yet.
