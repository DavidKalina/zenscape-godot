# Raider: handoff (greybox, branch `iter/raider`)

One enemy plane you fight by dodging its rams and ramming it back with the
surge roll. It's an experiment: the smallest playable build, with no
committed tests.

## What was built

- `scripts/endless/raider.gd`: the raider.
  - **States:** away, stalk, tell, ram, over, peel, dead.
  - **Shows up:** after 4 s of flight, about 320 m off and about 22° off the
    view's axis, in view. If it gets more than 950 m away for 3 s, it shows
    up in view again.
  - **Stalk:** when it's ahead of you, it turns back onto your line to meet
    you head-on. When it's behind, it closes on your tail.
  - **Tell:** 0.9 s. Its wings rock, a red-orange glow grows at its nose, the
    marker turns red, pulses and reads "RAM!", and a low whoosh plays.
  - **Ram:** it lunges at where you'll be, at your speed + 45 m/s (at least
    75 m/s). It homes only 0.2 rad/s while more than 50 m out, then flies
    straight. It overshoots for 1.3 s, then comes round again.
  - **Head-on and tail runs alternate without extra code:** a head-on pass
    ends behind you, and a tail run ends ahead of you.
  - **How it flies:** like the traffic planes. The heading turns at a limited
    rate, the wings bank with the turn, and it keeps 22 m over the ground
    ahead (in a ram, at least 4 m over the ground).
  - **Look:** a dark PlaneFigure (livery charcoal and red trim) at 1.3x the
    player's size.
  - **Marker:** its own, a wedge over it with the distance, or an arrow at
    the screen's edge when it's off-screen. I copied the rival race's look
    rather than reusing its HUD, which is wired to the race.
- **A hit:** the ram comes within 6 m and you aren't rolling or surging.
  - `plane.knock`: 0.8 of your speed kept, a 14 m/s shove along its line plus
    a little up, and your nose 0.35 rad off your line.
  - A one-turn tumble over 0.7 s.
  - The unbanked line is lost (`near.lose`) and 0.4 of the meter drains.
  - The view shakes and you hear a crash. Then it peels off for 3 s.
- **A dodge:** the ram passes within 18 m without hitting, or you barrel roll
  through it within 27 m. A roll during the pass makes you immune to the hit
  at any distance.
  - The meter fills 0.2 to 0.38 at once (the closer the pass, the more), plus
    0.08 for a barrel roll.
  - It also counts as a ball's pass on the line (`near.shot_pass`), so it
    shows up as a graze.
- **The kill:** `scripts/endless/surge_smash.gd` calls `raider.try_kill`
  every frame the surge roll is hot, the way it calls the burrower's
  `try_catch`. A plane within 10 m of the raider, counting the closest
  point over the last frame, kills it.
  - It breaks into 16 greybox chips thrown out to the sides and ahead, with
    an orange flash and the flight's wood and dust bursts.
  - Hit-stop and kick as for a plug, then a `smash` moment on the line
    (`LineMoves.smash`, `smashed` "raider"; the stills show it as
    "SMASH +375").
  - `SurgeSmash.raiders` counts kills. A surge roll that misses spends the
    meter as before.
- `studies/endless_flight.gd`: the `raider` var. It's built after
  SurgeSmash when `--raider` is given, and stepped after `coast.after` and
  before the near-miss scoring (FrameLog part `raider`).

## Flags and knobs

| Flag | Constant | Default | What it does |
|---|---|---|---|
| `--raider` | | off | Turns the raider on |
| `--raider-every=S` | `REST` | 20 | Seconds after a kill before the next shows up |
| `--raider-ram=V` | `RAM_OVER` | 45 | Ram speed over yours, m/s (`RAM_LEAST` 75 is the floor) |
| `--raider-tell=S` | `TELL_S` | 0.9 | How long the telegraph lasts, s |
| `--raider-hit=M` | `HIT_R` | 6 | Hit radius, m |
| `--raider-near=M` | `NEAR_R` | 18 | Dodge (near-miss) radius, m |
| `--raider-shove=V` | `SHOVE` | 14 | Knockback, m/s |
| `--raider-fill=F` | `DODGE_FILL.y` | 0.38 | Meter fill for the closest dodge |
| `--raider-turn=R` | `TURN_MAX` | 1.3 | Its turn rate while stalking, rad/s |

These are constants only, with no flag: `HIT_DRAIN` 0.4, `YAW` 0.35,
`TUMBLE` (1 turn over 0.7 s), `KILL_R` 10, `RAM_TURN` 0.2, `RAM_STRAIGHT` 50,
`HEAD_M`/`TAIL_M` (the distances a head-on or tail run starts at), `SPAWN_M`
320, `FIRST_S` 4 and `PEEL_S` 3.

## Proof

- **Smoke check:** `python3 tools/smoke.py studies/endless_flight.tscn -- --raider`
  passes, 400 frames with 0 errors, and so does the scene without the flag.
- **Throwaway driver:** `scratch/raider_check.gd`, through the real loop. It
  holds altitude with the stick, presses the roll button with `tap(&"fly_roll")`
  and holds the stick for turns. Run it with
  `python3 tools/drive.py scratch/raider_check.gd -- --timeout=480 --scene-args --raider --raider-every=8 --pilot-file=/tmp/raider_pilot.json`.
  All 17 checks pass:
  - It shows up 151 frames in, in front of the camera.
  - **Hit:** flying straight, the first head-on ram hits. The meter goes
    0.60 to 0.20, the nose is knocked 0.35 rad, it peels off, and the tumble
    is over in 42 frames (0.7 s).
  - **Dodge:** a roll pressed 0.25 s before contact dodges, passing at
    4.1 m. The meter goes 0.00 to 0.49 at once.
  - A hard turn held from the tell on also beats a ram (closest pass 8.9 m,
    counted as a dodge).
  - **Kill:** with a full meter, the roll button 0.3 s before contact is a
    surge roll that kills it. SurgeSmash counts it, and a `smash` moment with
    `smashed` "raider" is on the line. It comes back 8 s later.
  - Over the run, 7 rams were 1 head-on and 6 from the tail. Both kinds
    happen, but the tail runs outnumber the head-on ones once the plane flies
    straight.
- **Rendered stills:** `scratch/raider_shots.gd` with `--rendered`, through
  the player's camera with the HUD.
  - At 300 m the plane is a dot and the marker carries it.
  - The tell reads: a red "RAM!" wedge and an orange glow at its nose, kept
    to a size you can see far off.
  - The ram is an orange ball with the plane inside it, closing on you.
  - The kill is an orange flash, chips flying out ahead and to the sides,
    and "SMASH +375" on the line.
  - The first pass had black boxes in the camera's face. I made the chips
    smaller, lighter and thrown ahead, and hid any within 4 m of the camera.

## Unverified

- **Feel by hand:** whether the timing is beatable without being trivial,
  and whether rolls make you immune for too long, needs the user to play it.
  The driver's dodges are perfectly timed.
- **Per-frame cost:** not measured. It's 5 to 6 height samples, one figure
  update and one marker redraw a frame.
- **The kill test filled the meter by setting it, not by flying.** The
  dodges show the meter does fill by play, about 0.3 to 0.5 per dodge, so a
  full meter takes 2 to 3 dodges.
- **Collision:** none with the land beyond its ground clearance. In a narrow
  valley it can clip the side of a ridge.

## Tests

None added. The full suite wasn't run. I expect no existing test to break:
with the flag off, nothing changes except one FrameLog mark.

## What the harness lacked

GDScript lambdas capture locals by value, so a driver's
`until(func(): x = ...)` doesn't write back to `x`. Use member variables.
`drive.gd`'s notes could say so.
