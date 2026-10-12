# Dragon cyclone blast, round 1

An experiment on the `roguelike` branch (`feature/dragon-cyclone`). When
the dragon SPOTS you (docs/design/dragon-vision/round1.md), he roars, then
fires a cyclone at you. There is no damage. It throws you, and the rim does
the rest.

## What was built

- **`scripts/dragon_cyclone.gd`** (Node3D, world space). `SkyDragon` owns it
  as `cyclone` when `cyclone_on` is set before `setup`, and drives it from
  `_cyclone` each frame he flies (both his own flight and `wake_fly`).
  - **Gate:** he must be spotted, his roar must be `AFTER_ROAR` s in (the
    wind-up cuts the roar's close short), and you must be within
    `FIRE_RANGE` of his mouth.
  - **Wind-up (the tell),** `WINDUP` s: his head already tracks you
    (sight). His jaw opens a little and his head draws back. The gale's
    `inhale` streaks are pulled into his mouth from your direction, and a
    sharp inhale sound plays. If you're lost mid wind-up, it cancels.
  - **Shot:** one funnel per shot. It leaves his mouth toward your middle
    (the sight's `target()`) as it was when he fired, at `SPEED`, and goes
    on along that line. It is aimed, not homing. Each frame it ray-checks
    layer 1 (stone) and layer 11 (turf):
    - turf, or a floor within `LAND_NEAR` walker heights of the aim: it
      lands;
    - anything else (a wall, a roof, a pillar): it breaks into a soft burst
      of puffs and is gone;
    - nothing within `RANGE`: it thins away.
  - **On the turf:** it spins for `SPIN_LIFE` s, then fades over `FADE` s.
    It drifts at `DRIFT` m/s, turning every `DRIFT_TURN` s and bouncing off
    walls. Over a rim it spills off and fades. It uses the wind tool's
    slots:
    - `zs_burst_*`: a ground burst when it lands and every `BURST_EVERY` s
      after;
    - `zs_aim_*` in held mode: the existing out-and-round swirl.

    There is no custom flatten effect.
  - **Pilot:** the host calls `pilot_knock(feet, motor)`, then
    `motor.knock(v)`. This is the same knock path as the gale's ground gust
    (`knock_velocity`). The throw goes `KNOCK_OUT` walker heights out and
    peaks `KNOCK_UP` walker heights up, plus a `KNOCK_SPIN` m/s spin along
    the funnel's turn. Each funnel throws you once, and never while you're
    still recovering. X (twirl) breaks the tumble in the air, then Space
    opens the sail.
  - **Plane:** `plane_air(p, nose)` is merged into the study's `plane_air`
    with the downwash (`DragonDownwash.merge`), the same path as
    `plane_gust`. It adds wind out, up and round (`PLANE_OUT/UP/SPIN`) and
    a shove (`PLANE_PITCH`, `PLANE_ROLL`). The plane's catch radius is the
    funnel's radius plus half its span (`WorldScale.span`). The throw
    lingers for `THROW_LINGER` s after the plane leaves the funnel.
  - **Cadence:** `COOLDOWN` s from one shot to the next wind-up while you
    stay spotted. The period is cooldown + wind-up.
  - **Look:** soft tinted streaks orbit the axis, rising, faster near the
    base, with the far side shaded. There are a few soft puffs, and the
    axis sways. Dust puffs kick off the base, and puffs burst out on landing
    and on breaking. It reuses the gale's puff shader and a tinted copy of
    its streak shader.
- **Sound** (`scripts/kit_isle/kit_audio_beasts.gd` `_cyclone`): the
  existing clips: an inhale on the wind-up, an exhale and a wind slam on the
  shot, a heavy slam on landing and a light slam on breaking.
- **Greybox** (`studies/dragon_vision_study.gd`): the cyclone is on by
  default. It applies the pilot knock and merges the plane air. It shows
  toasts for the wind-up and for a break on cover. Flags:
  - `--cyclone-fast`: cooldown `FAST_COOLDOWN` (2 s);
  - `--no-cyclone`: turns the cyclone off;
  - `--cyclone-shot=x,z`: a look check. It fires one shot at once at that
    spot, without needing sight. Use it with `--at` to capture it.

  The aqueduct isle is still unwired (no sight target, no `cyclone_on`).

## Tuning constants (top of scripts/dragon_cyclone.gd)

| What | Constants |
| --- | --- |
| Timing | `WINDUP` 1.3 s, `COOLDOWN` 6 s, `FAST_COOLDOWN` 2 s, `AFTER_ROAR` 2.5 s |
| Shot | `SPEED` 30 m/s, `RANGE` 380 m, `FIRE_RANGE` 220 m, `LAND_NEAR` 3 walker heights |
| Size (shares of his span, 183 m at size 1.5) | `RADIUS` 0.038 (about 7 m base), `TALL` 0.14 (about 26 m), `FLY_TALL` 0.45, `FLARE` 1.9 |
| Turf | `SPIN_LIFE` 4 s, `FADE` 1.2 s, `DRIFT` 2.5 m/s, `DRIFT_TURN` 1.1 s |
| Pilot | `KNOCK_OUT` 12 and `KNOCK_UP` 5 walker heights, `KNOCK_SPIN` 7 m/s (about 17 m/s up, 10 m/s out at the knobs) |
| Plane | `PLANE_OUT` 9, `PLANE_UP` 16, `PLANE_SPIN` 12 m/s; `PLANE_PITCH` 1.2, `PLANE_ROLL` 7 rad/s; `THROW_LINGER` 0.8 s |
| Wind tool | `BURST_*`, `SWIRL_REACH`, `SWIRL` |
| Look | `STREAKS_EACH`, `PUFFS_EACH`, `ROUND`, `RISE`, `DUST_RATE`, tints |

## Run

```
~/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/dragon_vision_study.tscn -- --no-title --cyclone-fast
# look check, a fixed eye on the flat isle:
~/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/dragon_vision_study.tscn -- --no-title --no-sight-overlay --cyclone-shot=20,-100 --at=62,38,-68 --look=20,36,-100 --capture=/tmp/cyclone.png
```

## Tested vs judged by eye

- **Tested headless** (`tests/test_dragon_cyclone.gd`):
  - it travels straight to its aim at `SPEED` and lands there;
  - a wall in the way breaks it at the wall;
  - a pilot inside it is thrown out, up and round, only once per funnel;
    a pilot well outside it is untouched;
  - the plane inside it gets wind up and out, and a roll;
  - the cadence: the first shot comes after the wind-up, then one every
    cooldown + wind-up; losing the pilot stops the wind-up and the shots.
- **Headless game run** (the study, standing at the start): he spots you
  and fires from about 150 m. It lands within 1.5 m of the aim and knocks
  the pilot out and up. A later knock threw him over the rim into the cloud
  sea. No script errors.
- **Windowed, judged by eye** (`--cyclone-shot` captures): a soft, banded,
  swirling column with dust at its base reads as a whirlwind against the
  sky. The first pass was a white fog blob, so the streaks were made
  thinner and shaded and the puffs smaller.
- **Not verified:**
  - the wind-up look (jaw, inhale streaks) and the funnel in flight;
  - the break-on-cover burst on screen;
  - the sounds;
  - the plane being thrown in play;
  - the sail recovery in play;
  - grass, trees and water under the burst and swirl (the greybox has no
    plants).

  Nobody has played it.
- A run quit with `--quit-after` while a one-shot sound is playing reports
  "2 resources still in use at exit": the wind-slam clip and also
  nutcracker.mp3. Quitting at other moments is clean. It looks like
  teardown with live audio. It isn't fixed here.

## Open questions / next steps

- **Pace:** at his 62 m circuit he spots you late in a pass and fires from
  about 150 m (about 5 s of flight). Is that too easy to dodge? Should
  `SPEED` go up, or should he fire earlier?
- **Aim:** he aims at your middle; for a walker that means it lands just
  past you. Should he lead a moving target (still not homing)?
- **Wind slots:** `zs_burst_*`/`zs_aim_*` are shared with the downwash and
  the wind tool. With several users at once, the last writer wins.
- **The sail:** a pilot already sailing gets the same knock. Should the
  funnel be a ride (a thermal) for a sail that enters from above?
- **Look:** a proper painterly pass: the in-flight shape (it is a short
  upright column now), a darker core, and how it reads at 300 m.
- **Wiring:** the aqueduct isle's roost dragon (`sight_target` +
  `cyclone_on`).
