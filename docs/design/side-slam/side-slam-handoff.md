# Side slam: handoff (prototype round)

Branch `iter/side-slam` (round 1), then `iter/caches-slam` (round 2, with
the kit caches merged in). Prototype only. No committed tests.

## Round 3: costs one segment

- The side slam spends **one segment** (`Updraft.spend_lunge`, the same
  `_take` the burst and updraft use) and arms whenever a segment is there
  (`SideSlam.wanted` asks `can_spend()`), not only at full charge. Three in a
  row from a full gauge work. The HUD gauge reads `charge`, so it drops one
  segment per slam. Unsegmented (off the kit isles) it still needs and spends
  the whole charge.
- Trade-off: with any segment on the ground, Q / RB now waits for its release
  (~0.1 s) before a tap gives the updraft (or the burst in a slide), where
  before only a full gauge waited. With no segment the press is as before.
- Proof: `scratch/dash_slam_cost.gd` (git-ignored), real input on the isle,
  20/20 OK (1 segment leaves 0, 3 leave 2, three in a row 2/1/0 with the
  gauge matching, a tap at 1 segment is the updraft, empty does nothing).
  Smoke `zenscape.tscn --no-title` PASS. `test_slam.gd`: the same two
  updraft checks fail as on main, nothing added or fixed.

## Round 2: from the ground, and no drain

- **The charge doesn't drain.** `scripts/updraft.gd` `DRAIN` (false) turns
  off every drain over time (the old GRACE/DECAY and the segmented
  SEG_GRACE/SEG_DECAY/SEG_HELD_GRACE ones). The charge only goes down when
  spent. How it fills is unchanged. The wind-gauge docs still describe the
  old drain; `DRAIN = true` brings it back.
- **The side slam arms on the ground, not only in a slide.** At full charge,
  standing, walking, running or crouched (motor move `""` or `"crouch"`),
  holding Q / RB past `HOLD` coils and launches him the same way. In a slide
  it works as before. Below full charge, and in the air, nothing changes.
- **The coil from the ground** (`GROUND_COIL`, 0.24 s) plants him: his pace
  bleeds away (`PLANT`, 14/s, he is stopped within a few frames), the host
  keeps the stick, jump and crouch from the motor (`side_slam.holds()`), and
  the figure plays the crouch clip under the coil's wind-back and squash.
  The stick, if held, turns him to aim (`AIM_TURN`), and the lunge goes
  along the stick. If the stick isn't held, it goes the way he faces.
  The lunge is the same as from a slide: 22 m/s, same reach, same hit,
  rebound and miss.
- **The wind-up shows from the press.** Through the `HOLD` wait the coil
  pose already runs to `WAIT_COIL` (0.3) of the full coil, and off a slide
  he dips into the crouch. So the wait reads as the start of the wind-up.
- **What a tap feels like now.** At full charge on the ground, the press
  waits for the release. A tap standing or running gives the updraft on the
  release, about a tap's length (~0.1 s) after the press, with a small dip
  into a crouch first, which reads as the updraft's own anticipation. A tap
  in a slide is the burst, as in round 1. Below full charge, the press
  fires at once, as ever. Jump during the wait and keep holding: at `HOLD`
  he is in the air, so it is the updraft.
- **Feelers.** The lunge also counts a hit when one of five rays from his
  body along his way meets a steep face against it (`FEEL_*`): three heights
  (0.1, 0.45, 0.85 m over the feet) and two at the sides. Without them he
  skimmed over the tomb chest (his body's cylinder starts over the motor's
  step) and glanced off a pier's corner without counting a hit. Slopes
  (|normal.y| > 0.6) are ridden, not hit.
- **Open issues.** After a side slam the charge creeps back up a hair
  (about 0.01) from the rebound's airtime (`SEG_AIR`); harmless but not
  zero. The standing coil is still procedural over the crouch clip; the
  authored clips below would serve it too.
- **Kit caches.** With `--kit-caches` on the isle, a side slam from standing
  into the pier, the buttress and the wall opens each, and the rune comes
  out and is taken. Into the tomb chest it only flares (0.65 against 1.6).

## What was built (round 1; round 2 above widens the trigger)

When the charge is full (all three segments) and he is in a grounded slide,
**holding** Q / pad RB turns the slide into a horizontal slam.

- **Hold vs tap.** At full charge in a slide, the press is held back for up to
  `HOLD` (0.16 s). If you let go before then, it is the ordinary forward burst,
  or the updraft if he has left the slide by then. That burst fires on
  release, a tap's length after the press (about 0.1 s). This is the only
  change to the tap. Below full charge, or outside a slide, the key works
  exactly as before: the burst fires on the press and holding it adds nothing.
- **Coil.** Held past `HOLD`, he coils for `COIL` (0.2 s). He squashes low and
  winds his body back, the slide bleeds pace, the view narrows a little, and
  the cloth sound plays.
- **Lunge.** This is a new motor move, `"lunge"`. He launches along the slide's
  direction at 22 m/s (`LUNGE_PACE`), about 0.45 m (`HOVER`) above the turf,
  for at most 8 m (`REACH`). He climbs slopes, sinks slowly off an edge, and
  can't steer, wall-run, grab a ledge, twirl or open the sail during it. The
  whole charge is spent, and the wake strands come off behind him. Effects:
  speed streaks, the FOV widens, and a swish plays. The slam still works if he
  lunges off an edge and has room under him.
- **Hit.** The lunge counts as a hit when he is stopped short (his step covers
  less than 45 % of what was asked) or when a lock target's aim point comes
  within 1.4 m. Then all of these happen:
  - every breakables hub gets `hit(at, 1.6 m, -1, &"side_slam")`;
  - the slam group gets `slam(at, 1.6, 0.6)`, so ropes, grass, leaves and the
    like answer it;
  - lock targets that have `hit(at, way, strength)` are hit at strength 1.0.
  - Feel: hit-stop (6 frames at 0.04 time scale), the camera jolts along the
    lunge, shakes and punches in, the pad pulses, a shockwave of arcs spreads
    on the wall, dust flies off the wall, and the slam's thump, impact and
    debris play, pitched up.
- **Rebound.** He is thrown off the surface at 7.5 m/s along a mix of the
  surface normal (60 %) and his reflected bounce, and rises 1.8 m. He uses the
  wall-kick move (`"kick"`) but keeps facing the wall, so the follow camera
  doesn't swing round. The stick works at once, so he can follow with the
  sail (Space), the twirl or the downward slam (crouch, with height under
  him). The rebound's kick gives no charge back.
- **Miss.** If the lunge runs out, he keeps 45 % of the pace and drops back to
  the ground. If crouch is still held, that is the slide.

## Play it

```
python3 tools/godot.py --rendered studies/aqueduct_isle.tscn -- --no-title --kit-caches --ledger=/tmp/slam.json
```

(or `run-aqueduct-isle.command`). Build charge from air moves (flips, wall
kicks, long jumps) until the gauge is full; it now keeps. Then, standing,
running or sliding, **hold Q (pad RB)** toward a wall or pier. The caches
(`--kit-caches`) stand west of the aqueduct: the tomb chest by the rubble
slope, and the pier, buttress and wall under the deck.

The aqueduct isle has **no breakables hub**, so nothing breaks there and the
rebound still works. To see a piece break:

```
python3 tools/godot.py --rendered studies/motif_yard.tscn -- --motif=editor_hill
```

Its pier broke in the check. `--no-side-slam` turns the move off;
`--breakers=-side_slam` keeps the move but stops it breaking anything.

## Knobs

- `scripts/side_slam.gd`, top of the file:
  - trigger: `HOLD`, `COIL`, `COIL_BRAKE`; from the ground `GROUND_COIL`,
    `PLANT`, `AIM_TURN`, `WAIT_COIL`, `GROUND_MOVES`
  - feelers: `FEEL_HIGH`, `FEEL_AHEAD`, `FEEL_SIDE`, `FEEL_FACING`, `FEEL_STEEP`
  - lunge: `LUNGE_PACE`, `REACH`, `HOVER`, `CLIMB`, `SINK`, `LIFT`, `MISS_KEEP`
  - hit: `HIT_SHARE`, `ENEMY_REACH`, `HIT_RADIUS`, `PUSH`, `KNOCK`
  - rebound: `REBOUND_OUT`, `REBOUND_RISE`, `BOUNCE`
  - feel: `HITSTOP_*`, `FOV_*`, `KICK*`, `SHAKE*`, `PULSE`
  - look: `STREAK*`, `BURST_*`
  - master switch: `ON`
- `scripts/updraft.gd`: `DRAIN` (false), the charge's drain over time.
- `scripts/pilot_motor.gd`: `LUNGE_GRAVITY` (0.3), the share of gravity he has
  during the lunge.
- `scripts/pilot_figure.gd`: `COIL_*` and `LUNGE_*` for the procedural pose.
- Lengths scale with the motor's `size`, and paces with `size^PACE_POWER`.

## Breaker strength

`&"side_slam"` is on by default, with strength **0.65**
(`scripts/kit_isle/breakables.gd` `BREAKERS`). At that strength posts (0.4),
piers (0.5), walls and arches (0.6) and lintels (0.4) break. Stairs (0.9) and
slabs (1.6) hold.

## Enemies

The hook is the lock targets' `hit(at, way, strength)`, which is the rune
knight's stagger and skid (`scripts/enemies/rune_knight.gd`). It is wired but
**untested**: the knight patrols the deck, and no lane in this round reached
him in a slide. The Olmec and other bodies are not hooked.

## Animation and clips

The pose is procedural. Over the `long_jump` clip, the lunge is turned
side-on, rolled and tipped. The coil is a squash plus a wind-back. The rebound
uses `wall_kick`. In the captures it reads as a flat, body-first dive, not a
clear shoulder charge.

To reach the bar in AGENTS.md, it needs these authored Blender clips:

1. `side_slam_coil`: a low crouch-coil on the slide, the leading shoulder
   tucked and the far arm wound back. A hold loop.
2. `side_slam_lunge`: a side-on shoulder charge, the leading arm braced across
   the chest, legs trailing, stretched along the travel.
3. `side_slam_impact`: a 2–3 frame squash against the wall, for the hit-stop.
4. `side_slam_rebound`: a recoil push-off with the arms flung forward, opening
   into the air pose.

## Proof

### Round 2

- **Smoke:** `aqueduct_isle.tscn` and `zenscape.tscn` with `--no-title
  --kit-caches`, and the isle without flags: PASS, 0 errors.
- **`scratch/side_slam_ground.gd`** (git-ignored), real input on the isle,
  18/18 OK:
  - 20 s standing idle keeps the charge at 1.0, 0.8 and 0.5 exactly;
  - standing at full, Q held: wait, coil, planted (pace 0), lunge at
    22 m/s, hits the wall, rebounds 9.2 m/s up and 6.4 m/s off it, the
    whole charge spent;
  - facing away from the wall, the stick toward it: the lunge goes along
    the stick and hits;
  - running at the wall, Q held: he plants, launches and hits;
  - a tap standing at full: the updraft (3.2 m, one segment);
  - below full, a hold standing: the updraft at once, no wait;
  - a tap in a slide: the burst; a hold in a slide: the side slam.
- **`--caches`** (same driver, `--scene-args --kit-caches --ledger=/tmp/x.json`),
  20/20 OK: the pier, buttress and wall each opened by a standing side slam,
  the rune came out and was taken; the tomb chest met, held and flared.
- Round 1's `side_slam_drive.gd` (slide hold, tap, below-full, miss) and
  `side_slam_yard.gd` (editor_hill pier breaks) pass unchanged.
- **Stills** (rendered, `scratch/side_slam_still.gd -- --view=q --off=8`):
  `scratch/shots/coilq_0_stand.png`, `coilq_1_wait.png` (the dip from the
  press), `coilq_3_full.png` (the full coil, low and wound back),
  `coilq_4_lunge.png`. Judged: the coil reads as a plant and a low crouch
  back; the grass hides some of the legs.
- **Tests:** `test_slam.gd` still fails its two updraft checks, as on main.
  `test_wind_*`, `test_dragon_downwash`, `test_sky_tepui` pass. No test
  checks the drain, so none breaks from it. The full suite was not run.

### Round 1

- **Smoke:** headless import. These all pass, 400 frames each with no errors:
  - `aqueduct_isle.tscn`, with and without `--rune-knight`
  - `zenscape.tscn`
  - the motif yard with `editor_hill` and with `bell_spires`
- **`scratch/side_slam_drive.gd` (git-ignored):** runs through real input on
  the aqueduct isle (`hold`/`press` of `walk_crouch` and `walk_wind`). The
  charge is set to full by the driver rather than built from flow.
  - Hold at full charge launches him, he meets the wall, rebounds 9.7 m/s up
    and about 6.4 m/s off it, the whole charge is spent, and the stick steers
    in the air afterwards.
  - A tap at full charge gives one burst and spends one segment.
  - A hold below full charge gives one burst on the press, with no wait.
  - A miss runs out and he lands.
- **`scratch/side_slam_yard.gd`:** in the motif yard (`editor_hill`), the hold
  into a pier breaks it, and the hub logs `side_slam` at strength 0.65.
- **Stills:** `scratch/shots/mine_06.png` (coil), `mine_09.png` (lunge),
  `mine_17.png` (impact), `mine_20.png` (rebound), and the sheet
  `mine_sheet.png`. The play-camera sheet is `scratch/shots/yard_play_sheet.png`.

## Tests

The full suite was not run. Related tests run: `test_slam.gd` and
`test_wind_*`.

- `test_slam.gd` fails 2 checks: "The updraft spends the charge" and the
  updraft-then-slam combo. The test expects `charge == 0.0` after one updraft
  from a standing start on the aqueduct isle. The isle's charge is segmented,
  so one updraft leaves 0.67. The side slam never arms when he is standing.
- The failure looks like it predates this branch, but it was **not checked on
  main**.

## What the harness lacked

- `film()` and `shot_at` with the `side`, `back` and `offset` views put the
  camera in the cloud deck under the yard's isle, so the stills were
  unusable. A throwaway driver camera with `shot()` worked instead.
- There is no helper to find a straight, flat lane to a wall or a breakable
  piece. The drivers search for one with rays.
- There is no helper to build a full charge through real play. The drivers set
  `updraft.charge` directly.
