# Dragon air blast, round 1

The user's verdict on the cyclone (docs/design/dragon-cyclone/round1.md):
"Pretty good, the attack was too slow though. I kinda want instead a focused
fireball but it's air. Like an air blast projectile that's swift and
punishing." Going from spotted to hit took about 8 s, so you could just walk
out of it.

## What's built

- `scripts/dragon_air_blast.gd` follows the cyclone's structure and
  interfaces: `advance(delta, space, spotted, mouth, aim)`, `pilot_knock(feet,
  motor)`, `plane_air(p, nose)`, the signals `winding_up`/`fired`/`landed`/
  `broke`, the `look`/`publish` flags, and the counters `shots`/`lands`/
  `breaks`/`last_at` that the sound reads.
  - **Tell:** he cuts his spotting roar short 0.8 s in (as the jaw opens).
    For a 0.45 s wind-up his head snaps onto you (a stiff spring in
    `sky_dragon.gd` `_pose`), his jaw draws air, and the gale's inhale runs
    at double rate.
  - **Shot:** a pilot-sized ball (0.55 walker heights in radius) at 110 m/s.
    It leads your velocity, eased from the sight target's motion, all of the
    way to the meeting point. It doesn't home.
  - **Impact:** it bursts on turf or a floor it hits, or on the pilot or
    plane it passes within reach of (tested on a swept segment, so it can't
    tunnel through). The shock reaches 3.2 walker heights (2.5 plane spans
    for the plane). Stone between the burst and you blocks the shock. Stone
    hit side-on pops the ball harmlessly.
    - **Walker:** `knock_velocity` with 42 walker heights out and 3.5 up at
      the burst's heart, falling to 0.45 of that at the rim. That's about
      21 m/s out against the cyclone's 9.
    - **Plane:** wind out along the shot (34 m/s) and down (26 m/s), the nose
      shoved down, yaw, a hard roll (11 rad/s), and a 1.1 s linger. Up-wind
      would only lift the plane, because `sky_plane.gd` adds wind straight to
      its velocity.
    - **Ground:** a `zs_burst_*` ring that flattens grass, trees and water.
  - **Cadence:** 2.3 s cooldown plus the 0.45 s tell gives a shot every
    ~2.75 s while he sees you. Losing you stops it.
  - **Look:** a camera-facing lens quad that bends the screen texture (heat
    shimmer, with a wobbling soft rim and a pale glow), a short streak trail
    (the cyclone's streak mesh), and puffs (the gale's puff mesh). Bursts
    throw a ring of dust and air puffs; pops throw a small puff.
- `sky_dragon.gd`:
  - `blast_on`, `air_blast`, `attack` ("blast" | "cyclone" | "none"),
    `set_attack()` and `attack_node()`.
  - `_cyclone()` advances both attacks; only the active one fires.
  - The mouth pose and the head snap follow the active attack.
  - Other hosts that only set `cyclone_on` are unchanged (`attack` defaults
    to "cyclone").
- `kit_audio_beasts.gd` `_air_blast`: a short high inhale, a hard exhale
  with a crack at the mouth, a heavy slam on a burst, a light slam on a pop.
- `studies/dragon_vision_study.gd`: builds both attacks, applies both knocks
  and both plane airs, and toasts "Blasted!" and "The blast pops on cover".

## Flags and keys (vision greybox)

| | |
|---|---|
| default | air blast |
| `--attack=blast` / `--attack=cyclone` / `--attack=none` | pick the attack |
| `--no-cyclone` | alias for `--attack=none` |
| `--blast-fast` | 1.0 s cooldown (as `--cyclone-fast`, which still works) |
| `--blast-shot=<x>,<z>` | one ball fired at that spot at once, a look check (as `--cyclone-shot=`) |
| K | cycles blast, cyclone, none, with a toast |

```
./run-dragon-vision.command                    # air blast
./run-dragon-vision.command --attack=cyclone   # the old cyclone
./run-dragon-vision.command --fly              # start in the plane
```

## Checked (headless)

- `tests/test_dragon_air_blast.gd` passes:
  - the lead
  - running straight gets hit, while juking at the shot is missed
  - a wall pops the ball harmlessly
  - the burst throws you out and up, more than 1.8 times the cyclone's throw,
    once per burst
  - a pilot outside the shock is untouched
  - the plane is thrown out and down, nose down, rolled
  - the cadence, and he holds fire once he's lost you
- `test_dragon_sight` and `test_dragon_cyclone` still pass.
- Real play path, headless run of the study:
  - **On foot**, standing at the start: spotted at ~6.7 s, fired ~0.5 s
    later, the burst lands on him ~1 s after that (about 1.5 s from spotted
    to hit), and he's knocked ~30 m. The next shot, while he recovers, then
    another knock, threw him off the north edge into the sea.
  - **`--fly`:** spotted, fired leading the plane, it burst 1.3 m from the
    plane, and the plane dropped from 33 m to about -9 m within 2 s.
- `--attack=cyclone` and `--no-cyclone` both load and behave as before.
- The exit-time "ObjectDB instances leaked / resources still in use"
  warnings also show on `roguelike` without this change.

## Unverified (needs the user's play)

- **Looks.** Headless can't render. The lens shader (screen-texture
  distortion) has never been compiled on a GPU, so a shader error is
  possible. The trail length, puff sizes and the shock ring's read in the
  grass are all unverified too.
- **Feel.**
  - Whether 0.45 s is a fair tell.
  - Whether a full lead is too cruel or too soft.
  - Whether a ~40 m throw is right on the bigger isles.
  - Whether the plane's drop is recoverable or always fatal: it fell into
    the cloud-sea floor in the headless run, and what that means for the
    plane here is the plane code's call.
- The K swap is unexercised (no key presses headless). It only calls
  `set_attack`.
- The audio mix of the new sounds.

## Next-round ideas

- A visible charge in the mouth during the tell (a shimmer ball growing), so
  you read it without the sound.
- Tune the lead by distance: full lead close in, less far out. Or lead only
  the flat velocity, so jumping dodges it.
- Let the shock knock loose rubble or treasure, or ripple the cloud sea where
  it bursts over water.
- Remove the cyclone if the blast wins, or keep it as a slower second attack
  for when you hide too long.
- A near-miss camera shake and a whoosh as it passes.

## After play (2026-10-12)

The user loved it. Tuned after: the ball gathers in his jaw through the
wind-up and rides along with his mouth for its first CARRY 0.15 s before
setting back on its aim ("still not quite" from the mouth: fine tuning
later). He sees farther (scripts/dragon_sight.gd RANGE 320 to 450, NEAR
100 to 150) and fires farther (FIRE_RANGE 230 to 330, RANGE 320 to 460);
he's more accurate: LEAD 0.9 to 1.0, LEAD_EASE 8 to 14, and a fuse (FUSE
1.2 walker heights) bursts a near miss on the pilot or the plane.
