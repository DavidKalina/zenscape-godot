# Knife-edge drift

Branch `feature/knife-drift`. Greybox mechanics only, no art or sound.

## What it does

- **Knife edge held, no turn:** same as before. The wings go vertical and the
  plane flies straight on its heading, for threading narrow slits.
- **Knife edge held, with turn:** the plane drifts. It turns 1.5x as fast
  as a banked turn and loses about 2 m/s, so the circle is about 40% tighter.
  The nose swings about 16° into the turn, ahead of the plane's actual path.
  This is the Mario Kart drift look: the plane slides round the corner
  nose-in, which reads as carrying its momentum through the turn.
- **Small stick on the edge (|turn| < 0.3):** this counts as a correction,
  so there is no drift. The drift ramps in fully by 0.8 stick. Lining up a
  slit stays steady. The flight bots' knife-edge runs still pass
  (`tests/test_flight_bench.gd`).
- **Turning against the lean** (for example, knife edge right while turning
  left) still drifts, at half strength.
- **Release boost:** if you let go of a drift you held for at least 0.4 s,
  you get up to +2.5 m/s at once. The full amount comes after a 1.2 s hold.
  The engine then eases the speed back to the throttle's speed. The boost
  roughly pays back what the drift bled off, so a drift-then-straight chain
  carries its speed. It is modest by design.
- Pitch is unchanged on the knife edge: it still climbs and dives and does
  not turn the plane (see open questions).

## Controls

Hold Q/E (or LB/RB) for the knife edge. Then steer left or right (A/D or the
left stick) to drift. A double-tap is still a barrel roll, and a roll
cancels the drift.

## Tuning knobs (scripts/sky_plane.gd)

| Knob | Default | Meaning |
|---|---|---|
| `--drift=<x>` / `drift_strength` | 1.0 | Scales the extra turn, the bleed and the boost. 0 turns the drift off. |
| `DRIFT_TURN` | 0.5 | Extra turn rate at full drift, as a share of the normal rate (x strength) |
| `DRIFT_ONSET` / `DRIFT_FULL` | 0.3 / 0.8 | Stick deflection where the drift starts / reaches full |
| `DRIFT_COUNTER` | 0.5 | Drift strength when turning against the lean |
| `DRIFT_BLEED` | 1.6 m/s² | Speed bleed at full drift (x strength). The engine pulls back against it. |
| `DRIFT_SLIP` | 0.12 s | How far the nose leads the path, in seconds of turn |
| `EASE_DRIFT` | 0.15 s | How fast the drift and the slip come and go |
| `DRIFT_BOOST` | 2.5 m/s | Most boost on release (x strength) |
| `DRIFT_MIN` / `DRIFT_CHARGE` | 0.4 s / 1.2 s | Hold needed before any boost / for the full boost |

## Measured (headless, cruise throttle, full stick, steady turn)

| Case | Turn radius | Speed | Nose slip |
|---|---|---|---|
| Normal banked turn | 8.75 m | 14.0 m/s | 0° |
| Straight knife edge | no turn (heading holds to 0.0000 rad, no sideways slide, no speed loss) | 14.0 | 0° |
| Drift, `--drift=1` (default) | **5.10 m** | 12.1 | 16.5° |
| Drift against the lean | 6.56 m | 13.1 | |
| Drift, `--drift=0.5` | 6.56 m | 13.0 | 13.8° |
| Drift, `--drift=1.5` | 4.06 m | 11.1 | 19.3° |
| Drift, `--drift=2` | 3.27 m | 10.2 | 22.0° |
| Normal turn with Boost held | 13.26 m | 21.7 | |
| Drift with Boost held, `--drift=1` | 8.10 m | 19.8 | 16.5° |

The release boost measured 12.7 m/s to 15.2 m/s after a 1.5 s drift, and the
plane settles back to 14.0 m/s.

Tests: `tests/test_knife_drift.gd` (new) and `tests/test_sky_plane.gd` pass.
`tests/test_flight_bench.gd` also passes, which covers the knife-edge bots
and the slits.

## Fly it

The flight study, lines pack:

    ./run-flight-lines.command --drift=1

or directly:

    ~/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/flight_study.tscn -- --no-title --pack=lines --drift=1

The main game:

    ~/Applications/Godot.app/Contents/MacOS/Godot --path . -- --no-title --drift=1

Try `--drift=0` to compare against the old knife edge, and `--drift=1.5` or
`--drift=2` for a stronger drift.

## Open questions

- **Strength:** the default gives a radius about 0.58x the normal turn. The
  user asked for "a little more sharply", so 1.0 may be right, or 1.5 may
  feel better in play.
- **Pitch on the edge:** with the wings vertical, pulling up could also
  drift (the "yank"). For now pitch only climbs and dives. One option: map
  pitch on the knife edge to the drift, toward the lift side.
- **Feedback:** there is no visual or audio cue for a drift or for the
  release boost yet. A whoosh (`flaps += 1`) or a vapour puff would sell the
  boost, but those belong to a polish pass.
- **Camera:** the camera follows the heading, so during a drift it looks
  about 16° inside the path. That may read well (you see where you are
  turning to) or feel off. It needs checking in play.
- **Bots:** the bench results are unchanged, but I didn't instrument whether
  a bot's stick ever crosses DRIFT_ONSET while on the edge. A bot that
  drifts on purpose could later show where drifting saves time.
