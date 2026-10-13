# Headless body, round 1 (greybox)

The inhaler head's lost stone body. It is a hulking greybox figure with an
empty, raw-cut neck stump, and it walks the isles hunting for its head. It
climbs cliff faces hand over hand, leaps down across gaps, and when it gets
to the head, the head settles onto its neck.

## Play it

    ./run-headless-body.command
    godot --path . res://studies/headless_body_isle.tscn -- --no-title [--body-knob=<knob>=<value>] [--head-knob=<knob>=<value>]

The study is four grey isles in open sky, built on the character study the
way the enemy yard is. Darker isles are the tall ones.

| Isle | Top | What happens there |
|---|---|---|
| A, the low isle | 0 m | The body and you start here |
| B, the mesa | 16 m | Rises off A. The body climbs its south face |
| C, the shelf | 6 m | 8 m gap north of B. The body leaps down onto it |
| D, the crown | 18 m | Rises off C. The head drifts a ring here, and the body climbs to it |

Ramps up the west side of B and of D let you follow on foot. The pocket sail
glides the rest. There is no plane in this study.

- **R** puts you back at the start and resets the body and the head.
- **F1** shows the body's state, its mode (searching, "has it", whole), its
  distance to the head, and its climbs, leaps and listens, plus the head's
  state.

## What it does

The code is in `scripts/enemies/headless_body.gd`. It is built on `enemy.gd`
and spawned through an `EnemyField`. Its sizes come from head heights (the
head's `size` × the walker's height), so everything traces back to
`enemy_field.gd numbers()`. Its neck is about 6.7 m up, its torso 4.4 m
across and its arms 3.7 m long.

1. **Listen.** It stops and sweeps its stump one way and then the other, with
   a hand cupped where its ear was. Then it turns to the bearing it heard.
   Within `hear` (90 m) the bearing is noisy, up to ±`noise`, and gets less
   noisy as it gets closer. Out of hearing range, it picks a way at random.
   It avoids headings that run into a rim with nothing below or a wall it
   won't climb.
2. **Roam.** It walks heavily along that bearing and stops to listen again
   every 7 s or so.
3. **Home.** Once the head is within `sense` (17 m) with a clear line from its
   neck, the body warms in colour, raises its arms and strides straight at
   the head.
4. **Climb.** When it meets a wall too tall to step up, and it hears the head
   above it, it faces the wall's normal and goes up hand over hand.
   - It casts rays at the real geometry every frame. A chest ray holds it
     `standoff` off the face and keeps it square to the face.
   - A downward ray just past the face, cast from above its reach, finds the
     lip. Once the lip is in its hands it hauls up with both hands, more
     slowly, and then mantles over.
   - It refuses walls taller than `climb_max`.
5. **Leap.** At an edge, it searches along its way for a lower floor within
   `leap_max` across and `drop_max` down, with room for its body.
   - **Windup** (1.1 s): it crouches with its arms thrown back.
   - **Leap:** a ballistic arc with its feet ray-cast along the path. A wall
     in the way stops it dead and it drops.
   - **Land:** a squash, a dust ring and a camera quake. A walker within
     `shock_r` is thrown off his feet.
6. **Reunion.** When the head is in arm's reach on the same level, the body
   stops, faces it and lifts its arms. The head arcs onto the neck over
   `settle` (2.2 s), with a puff and a quake. It waits if the head is
   holding you mid-gulp.
7. **Whole (placeholder).** The reunited figure walks off whole and roams any
   way, still climbing (60 % of walls) and leaping. The head rides its
   shoulders with its eyes lit, its jaw shut and its breath stopped.

**You and the body.** It is stone: you can stand on its shoulders and ride it
up a cliff. A leap bucks you off. If it walks, mantles or leaps into you,
you are shoved through `PilotMotor.knock` (about 5.6 m). You can't push it.
There is no damage.

**The head change.** `inhaler_head.gd` gained a `perch` field. When it is
set, the head's `think` only eases its jaw and eyes, and its `_move` copies
the body's neck seat, facing and lean. With `perch` null the head behaves
exactly as before.

## Knobs (`--body-knob=`)

Lengths scale with your height (`unit`, 1.12 m) and speeds with your
walk/run. "Hh" below is head heights.

| Knob | Default | What it sets |
|---|---|---|
| `head_size` | 3.0 | Head height in your heights. Match it to the head's `size` |
| `legs` / `torso` / `breadth` / `depth` / `arm` | 0.75 / 1.2 / 1.3 / 0.72 / 1.1 | Body proportions, in Hh |
| `walk` / `home` | walk × 0.9 / run × 0.7 | Search pace and homing pace |
| `turn` | 0.9 | Turn rate (rad/s) |
| `listen` / `listen_every` | 2.6 s / 7 s | How long a listen lasts and how often it listens |
| `hear` / `noise` | unit × 80 / 0.35 rad | Hearing range and how far off the heard bearing can be |
| `sense` / `lose` | unit × 15 / 2 s | Range at which it "has it", and how long out of sight before it goes back to listening |
| `climb` / `climb_max` | unit × 1.25 m/s / unit × 20 | Climb speed and tallest wall it will climb |
| `mantle` | 1.4 s | How long the haul over the lip takes |
| `leap_max` / `drop_max` / `leap_up` / `leap_gravity` | unit × 11 / unit × 20 / unit × 1.6 / gravity × 0.7 | The leap's reach, drop, arc height and gravity |
| `windup` / `land` | 1.1 s / 1.0 s | Crouch before a leap, and squash after landing |
| `shove_out` / `shove_up` | unit × 5 / unit × 1 | Shove on contact |
| `shock_r` / `shock_out` | unit × 7 / unit × 6 | Landing shock radius and how far it throws you |
| `reunite` / `settle` | unit × 1.6 / 2.2 s | Extra reach for the reunion, and how long the head takes to settle |
| `whole_climb` | 0.6 | Share of walls it climbs once whole |
| `seed` | 1 | Seeds its hearing noise and its whole-mode roaming |

## Verified

- Headless import is clean.
- `studies/headless_body_isle.tscn` ran headless for 600 frames with no
  errors. `studies/inhaler_isle.tscn` also ran clean after the head change.
- A throwaway run through the study's own `tick`, with real physics and rays
  and nothing scripted for the body, went like this:

| t (s) | What happened |
|---|---|
| 0 | Listened on A |
| 15 | Climbed the mesa face, 12 s up |
| 27 | Mantled onto B (16 m) |
| 41 | Wound up at B's north rim |
| 42 | Leapt 12 m across and 10 m down onto C |
| 52 | Climbed D's face |
| 61 | Mantled onto D (18 m) |
| 65 | Sensed the head and homed in |
| 69 | Reached for it |
| 71 | Reunited, then walked off whole |

- A second throwaway check stood the walker in its path. He was shoved
  (2 knocks, about 8 m) through the motor.
- Rendered stills of each beat (listen, climb, mantle, windup, leap, land,
  home, reach, whole, overview) are in `docs/design/roguelike/headless-body/`.
  They are gitignored, so they stay local. They read clearly as greybox.
- `tests/test_world_scale_guard.gd` passes. The full suite was not run.
- **No existing test should break.** The only edit to existing code is the
  head's `perch` hook, which is inactive unless it is set.

## Not verified

- The run was only checked from this one layout and seed. A noisy bearing
  could send it off a rim it can't leap, where it turns, or up a ramp.
- Riding its shoulders up a climb has not been felt in play.
- The camera quake and the sounds have not been heard or felt. The sounds
  are synth placeholders.

## Open questions for you

1. **What should the reunited figure do?** Right now it just walks off whole
   with its head quiet. Some options:
   - The head keeps inhaling from the shoulders, with the body kneeling to
     aim it.
   - The whole figure chases you.
   - It goes back to sleep as a statue.
   - It becomes a set piece you ride.
2. **Should the head know?** Should it drift toward the body, flee from it,
   or not care, as now?
3. **What should the search be like?** It currently hears a noisy bearing
   from anywhere within 90 m. Should it be blind (pure roaming), or should
   it follow something you can see, such as dust or a hum line?
4. **Can you lead it or trick it?** For example, carry or knock the head
   somewhere, or use the body's leap or shoulders as a route ("the plane may
   be the secret-route key" in the same spirit).
5. **Generator.** It is not wired into the run. It would need isles whose
   cliffs it can climb, which the layer shapes already have.

## Rough edges

- It is pure boxes with one pose rig, and the legs stay straight while it
  climbs.
- The arms point straight into the wall when both hands are on the lip.
- It doesn't path round things. It walks its bearing and climbs, leaps or
  turns when it is blocked.
- It ignores kit cover smaller than a wall. The knee and waist rays treat any
  steep face as a wall.
