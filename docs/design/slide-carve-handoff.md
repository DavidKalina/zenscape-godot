# Slide carve handoff

Branch `study/slide-carve`, from `study/serpent-ride` (49393ab7). Not merged
and not pushed.

The user played the serpent ride and loved sliding down its back (LT), but
found the slide "really hard to steer". This round adds **carving** to the
on-foot slide, behind a flag, so it can be compared with the slide as it is.

## Launch

    ./run-serpent-ride.command --carve
    ./run-character-study.command --carve
    godot --path . res://studies/serpent_ride.tscn -- --no-title --carve
    godot --path . res://studies/character_study.tscn -- --no-title --carve

- **`--carve`** starts the scene with carving on. The serpent ride (and its
  convoy) carves by default since 2026-10-10; `--no-carve` there gives the
  old slide.
- **F3** turns carving on and off live in both scenes, for an A/B on the
  same slide. The screen says which ("slide: carving" or "slide: as it
  was").
- **F1** shows a `carve` line: off, or ON with its three numbers and the
  turn it is making right now (rad/s).
- **F2** has three new sliders: `carve_turn`, `carve_radius` and
  `carve_scrub`. Print copies them as constants with the rest.

Only these two scenes (and the character study's island packs) can carve.
The main game and every other scene keep the old slide, because the
motor's `carve` defaults to off.

## Why the old slide is hard to steer

`scripts/pilot_motor.gd` `_surf`, as it was (and still is with carve off):

- **On a slope**, the stick across his way pushes him sideways at
  `SLIDE_STEER` (7 m/s²). That turns his way at only 7/pace rad/s: 0.7 rad/s
  at 10 m/s, 0.5 at 13. Meanwhile the slope pulls him down its fall line at
  18 × sin(slope). On the serpent's back the fall line is tipped off the
  spine whenever the body banks or the faceted top tilts. To hold the spine
  against that, the stick has to hold a large push across, which leaves him
  drifting about 2 m off the spine, past its 2 m flat top and onto its 40°
  shoulders. There the shoulder's own pull (11.6 m/s² outward) takes him off.
- **On the flat, crouched,** the slide isn't steered at all. When the serpent
  levels out of its dive, the stick does nothing.

## The rules (the motor's header has them as prose)

With `carve` on, sliding (move "slide": the surf on a slope and the slide on
the flat, crouched or not):

- **The stick across his way turns his way** instead of pushing him across.
  His pace is carried round into the new way, like a snowboard or a belly
  slide.
  - The turn is `CARVE_TURN` rad/s at full stick across, scaled by the
    stick's share across. Half the stick across gives half the turn. The stick
    straight ahead gives no turn.
  - The turn is never tighter than `CARVE_RADIUS`: it's at most pace /
    radius. So a slow slide doesn't spin on the spot.
- **Scrub.** Each radian carved costs `CARVE_SCRUB` of his pace, so a clean
  line is the fast one. Carving never adds pace.
- **The stick held back still brakes** (`SLIDE_BRAKE`), as before. Straight
  back has no share across, so it brakes without turning. Diagonally back,
  it brakes and turns.
- **The slope still pulls** down its fall line, unchanged. Carving across a
  slope gains less; following the fall line gains most.
- **He faces the way he slides,** as before. So the long jump and the slide
  jump out of a carve leave along the carved way.
- **What it doesn't touch:**
  - the slide hop's air weave (`HOP_TURN`/`HOP_STRAFE`, in the air);
  - the chain's timing (`LONG_CHAIN`, `_land_pace`);
  - every other feel number.
- **Off,** it's the same code path with the same numbers. The test checks
  four slides and surfs against the pre-carve motor to 0.0000000, and every
  recording replays exactly as before.

### Starting numbers

| Constant | Value | What it means |
|---|---|---|
| `CARVE_TURN` | 2.8 rad/s | A half turn in about 1.1 s at full stick. `TURN_RUN` on foot is 7; `HOP_TURN` in the air is 2.2. |
| `CARVE_RADIUS` | 2.0 m | The full turn from 5.6 m/s. At 3 m/s, 1.5 rad/s. |
| `CARVE_SCRUB` | 0.08 a radian | A quarter turn costs about 12% of his pace. A full-stick half second at 10 m/s costs about 11%. |

**How they were chosen.** A bot slid the dive (below) at turn rates of 1.6,
2.2, 2.8, 3.4 and 4.0 rad/s and scrubs of 0.05 to 0.1. The faster the turn,
the fewer the falls, levelling off past about 2.8:

| Turn (rad/s) | Scrub | Mean falls a minute over the 7 bots |
|---|---|---|
| 1.6 | 0.1 | 8.8 |
| 2.2 | 0.1 | 4.4 |
| 2.2 | 0.05 | 4.9 |
| 2.8 | 0.06 | 3.2 |
| 2.8 | 0.08 | 2.8 (the final run below) |
| 2.8 | 0.1 | 2.4 |
| 3.4 | 0.08 | 2.6 |
| 4.0 | 0.08 | 2.4 |

The old slide is 8.2. I kept 2.8 rather than more, so a keyboard's
all-or-nothing A/D stays sane. The scrub moved the falls little: a slower
slide is a bit easier, and run-to-run noise is about ±0.4. It mostly moved
the peak pace (each slide's top about 0.3 m/s higher at 0.05 than at 0.1),
so I took the middle.

### The figure's lean

`scripts/pilot_figure.gd` already banks into turns on the ground. Carving,
it leans into the carve instead: `CARVE_LEAN` 0.025 rad per m/s² of the
carve's pull (pace × turn), at most `CARVE_LEAN_MOST` 0.5 rad. That's about
0.2 rad at 4 m/s on a full turn, and the most from about 7 m/s. It reads in
rendered stills on the runway and in the dive. It runs on the existing bank
spring, so it overshoots a touch (0.58 rad seen once).

- It is driven by the motor's new `carving` (the carve's own turn this step,
  rad/s). It doesn't lean for the serpent's turn under him or the slope's
  pull.
- With carve off the figure is unchanged.

## The serpent: bot measurements

`tools/slide_carve_bot.gd` (headless) runs 51 slides per setting:

- **Setup.** The head is set 0 to 160 m on from the dive's mark, through
  the dive and out of its bottom. He starts at 70, 55 or 45 m from the
  snout, crouched.
- **Start.** If its back is still too level to surf, the slide starts when
  it tips (one setup never did, and is left out).
- **End.** A slide ends at the neck (13 m from the snout), at a fall (the
  ride's own: 14 m under where he left), or when he stops.
- **Steering.** The bot steers with a reaction delay and a slow random
  wander of its aim. Off and on use the identical bot. It has three
  styles:
  - **heading:** steers by the way he goes, back toward the spine by how
    far off he is. This is the closest to how people steer.
  - **smooth:** an analog thumb chasing a point on the spine half a second
    ahead.
  - **flick:** a thumb that corrects in 60° pushes.

Results, old slide → carving (2.8 / 2.0 / 0.08):

| Bot | Falls a minute sliding | Held to the neck | Along its back a slide (m) | Fallen ones, before falling (m) | Top pace (m/s) | Each slide's top / mean pace (m/s) |
|---|---|---|---|---|---|---|
| heading, 0.2 s | 7.0 → **0.7** | 25 → 47 of 51 | 34.5 → 43.1 | 25.7 → 43.7 | 13.82 → 13.21 | 12.18 / 7.52 → 11.59 / 7.75 |
| heading, 0.3 s | 9.4 → **1.1** | 18 → 43 | 31.1 → 42.8 | 24.7 → 34.8 | 13.64 → 12.65 | 12.00 / 7.23 → 11.43 / 7.51 |
| heading, 0.3 s, wander 8° | 10.3 → **1.9** | 16 → 40 | 30.6 → 42.0 | 26.4 → 39.9 | 13.70 → 13.18 | 11.91 / 7.20 → 11.43 / 7.59 |
| smooth, 0.2 s | 3.1 → **1.3** | 36 → 44 | 39.5 → 42.6 | 28.7 → 40.8 | 13.80 → 13.55 | 12.36 / 7.90 → 12.05 / 7.88 |
| smooth, 0.3 s, look 0.3 s, wander 8° | 11.4 → **1.7** | 14 → 42 of 50 | 32.2 → 42.2 | 28.7 → 41.2 | 13.70 → 13.15 | 12.11 / 7.41 → 11.60 / 7.73 |
| flick, 0.2 s | 6.3 → **1.4** | 28 → 41 of 50 | 39.0 → 41.9 | 34.4 → 42.2 | 13.84 → 12.80 | 12.39 / 7.90 → 10.47 / 7.10 |
| flick, 0.3 s | 10.0 → **11.3** | 17 → 10 | 31.7 → 30.2 | 24.4 → 28.3 | 14.12 → 12.68 | 11.97 / 7.13 → 10.53 / 6.57 |

The most he can slide is about 43.7 m on average: 57, 42 and 32 m from the
three starts to the neck.

**In short:**

- **Falls.** Over all seven bots, falls a minute go from 8.2 to 2.8.
- **Slides held to the neck.** 43% before, 75% carving.
- **Distance.** Carved slides follow the spine nearly all the way down (42
  to 43 m of about 44). The old slide falls off after about 25 to 34 m.
- **Pace.** Top pace drops a little (each slide's top about 0.5 m/s lower;
  the flick bot about 1.5 to 1.9). The mean pace while sliding is about the
  same. So the scrub costs the peak, not the run.
- **The one loss.** A flick thumb with a 0.3 s reaction does slightly
  worse carving (11.3 against 10.0). Slamming the stick 60° across and
  letting go late overcorrects when the stick really turns him. A real
  thumb would ease off; the bot doesn't.

Run it yourself (both modes, about 2 to 4 minutes each):

    godot --headless --path . --script tools/slide_carve_bot.gd -- --style=heading --delay=0.3
    godot --headless --path . --script tools/slide_carve_bot.gd -- --only-on --carve-turn=3.4 --verbose

## What to try first

1. **The serpent ride with carving:** `./run-serpent-ride.command --carve`.
   - Press R, then 3 at once: you ride near its tail. Its head tips into
     the dive about 12 s later, and the back under you about 16 s later.
   - Hold LT then, and steer down its spine to the neck. Crouch any
     earlier and you surf a little on the tail's own taper.
   - Press F3 and do the same slide the old way.
   - Then ride on through the dive's bottom, where it levels out: the slide
     on the flat now steers.
2. **The character study,** `./run-character-study.command --carve`:
   - **[ the runway:** run, LT to slide, and carve. A full-stick carve on a
     fast slide is about a U-turn. Long-jump out of a carve and it leaves
     along the carved way. Run, long jump, land crouched for a faster slide.
   - **\ the big slope** (35°, 20 m): carve across it and back. Holding
     across is slower; straight down the fall line is fastest. Then long-jump
     out at the foot into the 6 m gap.
   - **0 the slide run** (32° ramp, 4 m gap) and **- the chutes** (50° and
     40°): steer the surf, and jump out of it.
   - **] the long jump chain:** hop chains and weaves should feel exactly as
     before.
   - F3 back and forth on each.
3. **Tune in F2** if it's too twitchy or too lazy:
   - `carve_turn` first: 2.2 is lazier, 3.4 sharper.
   - then `carve_scrub`: 0 is no cost, 0.15 punishes wiggles.
   - Print copies the set.

## Recordings

The character study's recordings keep the motor's whole state at their
start (`scripts/character_recording.gd` `snapshot`), so the new `carve`
var is recorded with no format change.

- **A run made carving** replays carving, even with F3 off. The test shows
  that dropping it from the state sends the run 2.02 m astray, so it does
  need to be there.
- **A run made before carving** has no `carve` in it. The study sets carving
  off before restoring it, so it replays as it was even with F3 on.
- F3 is put back when the replay ends, and does nothing during one.
- The carve numbers are feel (F2), so a replay runs on the feel now, as
  every feel number does.

## Tests

- **`tests/test_slide_carve.gd`** (headless, about 6 s): all 34 checks pass.
  - **Off, as before:**
    - a crouched slide on the flat, an uncrouched slide on the flat, a
      surf down 30° with the stick across, and a surf braked: each matches
      the pre-carve motor (49393ab7) to 0.0000000;
    - the crouched flat slide still runs straight with the stick across.
  - **On, the flat:**
    - full stick across turns the slide at exactly 2.80 rad/s;
    - left mirrors right, and half the stick gives half the turn;
    - at 3.2 m/s the turn is capped at 1.60 rad/s by the radius;
    - pace never gains a step, and keeps 0.893 of a straight slide's (the
      scrub alone predicts 0.894);
    - he faces his way;
    - the stick held back brakes exactly as before.
  - **On, a 30° slope:**
    - no stick runs down the fall line at 9.94 m/s after 1.5 s;
    - the stick across carves him 62° off it at 6.86 m/s, still going down
      it at 3.22 m/s.
  - **Chains:**
    - a long jump out of a slide carved 59° leaves along the carved way, at
      7.60 m/s;
    - ten weaving slide hops (the stick across through each touch) chain
      to 13.00 m/s exactly as before: the same paces, hop by hop.
  - **The studies:** F3, F1, F2, the two recording cases above, `--carve`
    on the ride, and the ride's F1.
  - **The serpent:** the heading bot (0.2 s) carves from 70 m back to the
    neck in 3 of 3 slides, against 2 of 3 the old way.
- **The touched area:** `python3 tools/run_tests.py --tests 'test_character_*.gd' --tests 'test_serpent_ride.gd' --tests 'test_slide_carve.gd'`.
  6 pass and 1 fails:
  - `test_character_recordings.gd` fails exactly as it does on the base.
    `20261010_005619_tech-fun-fluid-movement.json` ends 20.87 m off after
    its twirl at 28.82 s.
  - Every other recording's verdict is byte-identical to the base run
    (0.00 m, with the base's own 0.07 and 0.01 on two).
  - The serpent ride's measures are identical too.
- **Also run:** `test_pilot_*.gd` (9, all pass) and the import check
  (clean).
- **Not run:** the full suite, as the user asked. Nothing was added to
  `tests/known_failures.txt`.

## Known issues

- **Nothing was played by hand.** Whether 2.8 rad/s feels like a carve or a
  twitch, and whether the lean reads in motion, needs the user's thumb. The
  bots are not people:
  - their stick is in the world's frame, not the camera's;
  - they know exactly where the spine is;
  - they never jump.
- **The flick-and-late thumb overcorrects** (see above). If carving feels
  twitchy, lower `carve_turn`. A turn that falls off with speed is the next
  rule to try (see Next ideas).
- **The shoulders still win at low pace.** Once he's well out on its 40°
  shoulder, its pull is 11.6 m/s² outward. Carving turns his way but
  doesn't fight the slope, so a slow slide out there still goes off.
- **The peak pace is a little lower** (about 0.5 m/s per slide on the
  serpent) because of the scrub and the bots' wigglier lines. Set
  `carve_scrub` to 0 to compare.
- **On a keyboard, A/D is full stick,** so it's always the full 2.8 rad/s.
  On a pad it's proportional.
- **F3 has no pad button.** The pad has nothing free that's obvious; the
  keyboard key works alongside a pad.
- **The figure's lean overshoots** its 0.5 rad cap briefly on the bank
  spring.

## What changed

- **`scripts/pilot_motor.gd`:**
  - a header paragraph;
  - `CARVE_TURN`, `CARVE_RADIUS`, `CARVE_SCRUB` with their feel vars;
  - `carve` (off) and `carving` (the turn now, for the figure);
  - `_carve`, called from `_surf` only when `carve` is on;
  - `carving` zeroed each step and on reset.
- **`scripts/pilot_figure.gd`:** `CARVE_LEAN`, `CARVE_LEAN_MOST`, and the
  lean while carving.
- **`studies/character_study.gd`:**
  - `--carve`, F3 (`toggle_carve`), F1's `carve_line`, and the three
    sliders;
  - the replay sets carving as recorded, then puts it back;
  - the hint line.
- **`studies/serpent_ride.gd`:** the carve line in F1, F3 in the hint line,
  and the header.
- **New:** `tools/slide_carve_bot.gd`, `tests/test_slide_carve.gd`.

## Next ideas

1. **A pull toward the spine while sliding on the serpent.** Left out this
   round on purpose, so carving could be tried on its own. If carving alone
   isn't enough, add a gentle pull back to the spine, scaled by how far off
   he is, on the serpent only.
2. **A turn that falls off with speed:** a grip cap, turn ≤ grip / pace.
   It would keep fast carves wide if 2.8 rad/s feels twitchy at 13 m/s,
   while slow carves stay sharp.
3. **The camera into the carve:** a touch of roll, or a quicker swing behind
   the carved way.
4. **The carve's spray and sound:** spray off the outer boot, more the
   harder the carve, and a scrape that rises with it.
5. **A pad button for F3**, if the A/B goes on a while.
6. **Carving as the default.** If the user likes it, turn it on in the main
   game's on-foot pilot and drop the flag. The old steer would then only
   live in recordings.
