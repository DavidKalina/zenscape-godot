# The burrower's chase through the tunnel: handoff

Spec: `spec-burrower-chase.md`. Follow him into a sunk tunnel at speed. A glowing
ridge winds round the bore ahead of the plane, the rock blisters and cracks where he
passes, a beat later a spur punches out at that spot, and he leaves the far mouth in a
plume. A crash, a landing, hanging back or not following ends it, and the usual rest
starts. Branch `iter/burrower-cave`, not merged.

## Fly it

```
cd /Users/davidkalina/Documents/Projects/zenscape-burrower-cave && python3 tools/play.py -- --pilot-file=/tmp/chase1.json --at=3400,4384 --heading=90 --alt=60
```

That meets him on the axis of mouth `1_1/a`. The reverse way, out of mouth A's end:

```
cd /Users/davidkalina/Documents/Projects/zenscape-burrower-cave && python3 tools/play.py -- --pilot-file=/tmp/chase2.json --at=7300,5545 --heading=-74 --alt=90 --burrower-near=1400
```

You have `FOLLOW_S`, 5 s, from when he goes in to follow him. A mouth comes up once until
the plane has been 1400 m from it, and a 45-75 s rest follows each chase.

## This round's changes

- **Reach.** The most a spur stands out is now the bigger of `REACH_MOST` (18 m) and the
  way to the bore's middle (`REACH_MIDDLE`, 1.0). Before, 38 of 82 spurs left over 4 m
  past the wingtip for a plane flying the middle; now 20 do. Longest went from 18 m to
  about 39 m. Those long ones read as a beam across a cavern. Root radius capped at
  `GIRTH_MOST` (6 m), so the blister stays in size. `CHAIN` went from 9 to 14 spheres.
- **Pace.** Measured: 57.7 m/s level and straight on Boost, 52-55 weaving. At the old
  `PACE` of 57 a weaving plane sat pinned at `LEAD.y`, median lead 150. `PACE` is now
  54: medians 110-148 in whole runs, minimum 77-117.
- **Spacing.** `SPUR_WANDER` went from 0.3 to 0.2. Closest pair was 40 m (0.69 s), now
  55 m (0.96 s) in `1_1`, at least 1.11 s in the other three, at 57 m/s. That moved every
  spot by up to 8 m.

## The push-ups are gone

Orbs, bells and gongs are out of the game (spec task 5). The last commit with them is
`34788c41`, named in `docs/archive.md`. Gone: `push_ups.gd`, the orb and halo shaders, their
setup, flags (`--burrower-orb-off`, `--burrower-reach`) and `CATCH_PRIZE`, the three moves
in `line_moves.gd`, `line_tune.json` and `near_glyphs.gd`, the `chime` moment path in NearMiss,
the HUD and FlightSound, and what only they used: `want_ahead`, `want_at`, `entering`,
`TreeShudder.shove`, `GrassReact.gust_disc`, `GritMesh.dome`.

- **He runs closer now.** While an orb was due he held about 1.8 s of the plane's flight
  ahead (`want_ahead`, some 80-95 m), and `RUN_AHEAD`, 30-48 m, only after the third orb.
  Now it's `RUN_AHEAD` from the start of the run. In the two catch runs his lead up to the
  catch was 39-70 m, median 56-57, so a catch may come easier. `RUN_AHEAD` in `burrower.gd`
  is the knob.
- **A catch** still fires `caught`, and the burst and dive. No prize.
- **The study** still has things to show (he wakes, leads, dives and roams, with the ridge
  and the wake), so it stays. Keys 1 to 5 and `--bell=2`, `--gong=2` went.
- **Kept:** every file in `assets/audio/burrower/`. `gong-369428.mp3` has no user left; it
  was the study's `--gong=2`.
- **Left alone, not the burrower's:** the orbs in `beat_marks.gd` (flight courses), NearMiss
  `prize` (the pirate ship), the multiplier's and finds' bell sounds, wind horn, ruin kit and
  cloud uses of "bell". Older specs and handoffs keep the words as history.
- **Tests:** none in `tests/` name the burrower, NearMiss, LineMoves, FlightSound or
  GrassReact, so none needs the push-ups. Full suite not run.

Checks on this code: smoke of `studies/endless_flight.tscn` and
`studies/burrower_study.tscn`, PASS, 0 errors each. Whole run `1_1/a`, headless, ended "out",
22 of 22 fired, 0 crashes, lead 65/121/153, one plume. Surge roll by the real input on the
way to the mouth, twice (the driver filled the meter): caught, the `burrower-catch` find
found, no prize, 0 errors. Study through a driver: B called him, he ran 378 m in 8 s,
watched, dived, 0 errors. HUD still `scratch/hud5/f00665.png`: the stone graze's glyph, label
and clearance all show.

## Spot pairs

s 1901/1953 isn't a forced swing. Laid out on a grid, every consecutive pair in all four
tunnels has a place past both with 4 m past each wingtip (the two clear sets come within
1.2 m on a 2 m grid, so they touch). The crash there last round was the scripted pilot
aiming beside a spur it could have ignored. Full stick from level moves the plane 4.6 m
across in 0.5 s, 14 m in 0.75 s and 27 m in 1 s, but that's a turn, about 80 deg off its
way by 1 s, so a side-step that ends straight moves less.

That's a line that exists, not proof a person finds it. See Unproven.

## Knobs

`scripts/endless/bore_spurs.gd`: `SPUR_EVERY` 85, `SPUR_WANDER` 0.2, `SPUR_ENDS` 130,
`REACH_SHARE` 0.42-0.72, `REACH_MOST` 18, `REACH_MIDDLE` 1.0, `GIRTH_SHARE`, `GIRTH_MOST` 6,
`TOY_PAST` 4 (gap past a tip), `HOLD_S` 0.8 (warning), `SNAP_S` 0.16.

`scripts/endless/burrower_bore.gd`: `LEAD` 90-150, `PACE` 54, `PACE_MOST` 95, `CROWD_GAIN`,
`WAIT_GAIN`, `LOST_M` 300, `OUT_S` 3, `FOLLOW_S` 5, `RUMBLE_*`, `PLUME_*`.

`scripts/endless/bore_line.gd`: `WIND_M` 340 (one turn round the tube), `WIND_SWAY`.

`scripts/endless/bore_plume.gd`, `scripts/endless/bore_tell.gd`: the plume's and the tell's look.

## Checks on the final code

- Smoke of `studies/endless_flight.tscn`: PASS, 400 frames, 0 errors.
- Gap, all 82 spurs: narrowest clear disc 17.28 m, wanted 8. None dropped.
- Scripted pilot by stick and Boost, knows every spur early, all ended "out", 0 crashes,
  every spur fired:

| Way | Start | Time | Spurs | Lead min/median/max |
|---|---|---|---|---|
| `1_1/a` | met him, rendered | 40.9 s | 22 | 117/148/154 |
| `1_1/b` | met him, rendered, twice | 39.8 s | 22 | 77/121/154 |
| `-1_1/a` | from inside the mouth | 30.9 s | 17 | 96/132/150 |
| `-1_1/b` | from inside the mouth | 30.6 s | 17 | 98/110/150 |
| `1_-1/a` | from inside the mouth | 35.9 s | 20 | 97/127/155 |
| `-2_1/a` | from inside the mouth | 40.3 s | 23 | 99/142/154 |

- The plume fired at every far mouth above, both ends of `1_1` and `-1_1`. Mouth A's end
  read in stills from 128 m and 48 m.
- Graze on a spur through the loop: `"kind":"graze","band":"close","points":185.4,
  "clear":0.70,"surface":"stone"`. Ram: crash, "stone", into 34 m/s, ended "down".
- Rendered frames in the chase (Mac, window, other agents' work running): median 23-25 ms,
  p99 47-57, worst 61-62. One run had a single 514 ms frame in the chase that didn't come
  back on a repeat. Spur and tell work's worst frame 1.1-1.6 ms. After the chase on the
  way out of mouth A: two frames of 107-111 ms, about 2.7 s after the plume, cause unknown.

Earlier rounds' endings (crash, landing, not following, lost) weren't rerun after these
changes, apart from the crash above. They don't touch that code.

## Placeholder

- The rumble: `kit/stone-grind-loop.wav` pitched down. The snap and plume sounds are
  stand-ins too (`crack`, `crash`, `debris`). I couldn't hear any of them.
- The rumble can't say floor from crown: stereo pan is left and right only.
- The plume's colour doesn't change at night.

## Unproven

- **Whether a person makes it.** A second pilot had its stick slowed (0.1 s lag, 7/s
  travel) and knew only spurs lit 0.3 s ago. It finished `1_-1/a` (20 of 20, 0 crashes, 7
  scrapes), and went down after 10 spurs in `1_1/b`, 10 in `-1_1/a` and 2 in `-2_1/a`.
  Its height and steering loops run close to unstable. The crashes I read were the floor,
  or a spur after it had lost its line, but I didn't read them all, so it says little
  either way. Flying it is the test.
- **Mouths other than `1_1`, by the real way in.** The scripted pilot flies into the rock
  at `-1_1/a` and `1_-1/a` a couple of seconds after he goes in, so the table's runs for
  those started inside. That's the script's approach, probably, but a person's way in
  hasn't been seen. `-2_1/b` and `1_-1/b` unflown.
- A first-use shader hitch on a cold cache: the tell and plume are first drawn mid-chase,
  and these runs had warm caches. A PC build isn't tried.
- GPU cost of flying through the plume on a slower machine.
- No test names the bore's scripts or `Tunnels.mouths`, and the full suite wasn't run, so
  none is known broken.

Headless runs now and then print `Parameter "m" is null` and RID errors from the dummy
renderer, at the start of a run or before any spur. They haven't shown up rendered.

## Throwaway drivers

`scratch/spurs.gd` is the pilot: `--under`, `--straight=1_1 --end=1` (start inside),
`--graze`, `--ram`, `--stayout`, `--back`, `--land`, `--tells=DIR`, `--plumeshots=DIR`,
`--thumb --know` (the limited pilot). `scratch/reach.gd --each --pairs --room=5.4` is the
layout survey, `scratch/spurs_gap.gd` the gap, `scratch/stickstep.gd` the plane's numbers.
