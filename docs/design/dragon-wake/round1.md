# Dragon wake, round 1: "oh shoot, he's alive"

Branch `feature/dragon-wake`, made from main at 5d2af458 (the roost on by default). Spectacle only: he wakes, flies a big circuit and settles back. He never grabs the player, deals damage, or grips or tips an isle.

## Try it

```
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path <worktree> -- --no-title --dragon-wake
```

He stirs about 4 s after load. Stand on the aqueduct isle and look south-east toward the roost (about 770 m off), or use the telescope. Once he is in the air, V cycles the dragon camera (chase, orbit, look from here, off). It hands the camera back when he lands.

- `--dragon-wake-at=<s>` wakes him that many seconds after load instead.
- `--no-dragon-wake` keeps him asleep, schedule and all.
- `--day-length=60` makes the schedule come round quickly (a world day a minute).

## The schedule

`scripts/dragon_wake.gd`, the named consts at its top:

| Const | Value | Why |
| --- | --- | --- |
| `WAKE_HOUR` | 15.5 | Once a world day, in late afternoon. The sun is low and gold (daylight about 0.85) when he takes off, so the flight is plainly visible, and he is back on the mountain as the sun sets (about 18:00), so the return reads ominous. A wake at 18:00 or later would put the whole circuit in the dark, where his hide reads pale grey and the flight is hard to follow. |
| `FIRST_AFTER` | 240 s | No wake in the opening minutes. The game opens at about 11:00, so on the default 8-minute day the first 15:30 comes 90 s in. That one is skipped, and the first wake is at the next day's 15:30, about 9.5 minutes into play. On the 24-minute day the first 15:30 comes about 4.5 minutes in and he wakes then. |
| Held day | never | When the clock doesn't run (a look preset, a capture, day length 0), he doesn't wake on his own. Only the flags wake him then. |

The wake reads the clock through `studies/aqueduct_isle.gd` `_world_hours` (the day's 24 plus the hour, or -1 when the day is held). It wakes when that crosses `WAKE_HOUR`.

## The beats

| Beat | Length | What happens |
| --- | --- | --- |
| Stirring | `STIR` 9 s | The coil keeps breathing. At 1 s his eyes open: the eye surface is its own again, glowing, with the night halos back. From 1.2 to 4 s the neck's head end and the head lift off their shelf (`LIFT`, each bone about its own across axis, so up and out from the rock). He looks round, and at 5.2 s he roars (the flight's jaw springs; its call in the kit audio). The kit audio also plays a growl at his mouth. |
| Taking off | `RISE` 8 s | Dust bursts off the ledge and the carrion birds scatter wide and high (`roost_air.gd` `dust`, `scatter`), with a launch beat, a wind slam and rubble in the audio. Every bone is slerped from the coil pose to the flight pose, staggered (`_lag_rise`): head, then the neck from its head end, the chest, the wings (arm, forearm, hand, fingers, as they unfold), the hips and legs, and the tail last, root to tip. The finger shortening (the fold) is lerped out with them. The body's frame moves from the coil's to the climb's. The climb is scripted: slow and steep out over the ledge, away from the summit, speeding up to 26 m/s, flattening out and turning toward the first point. |
| Flying | about 80 s | The sky dragon's own flight (`SkyDragon.wake_fly`: `_ride_air`, `_fly`, `_pose`, `_ease_body`), with wingbeats, glides, banked turns, the tail rope, roars, and the head turning to look at a near camera. He steers along `CIRCUIT` (below). It is not `_step`, so there is no attack timer, gale, treasure, chin collider or clearance. The roost dragon has no gale, treasure or targets anyway. |
| Landing | `SETTLE` 11 s | Once the last approach point is passed, he flies a slowing Bezier curve in over the ledge from out and above. His wings cup and back-beat and his legs reach (the grab's `_flare`). Each bone eases back into the coil (`_lag_land`): the hips, legs and chest first, the wings folding, the tail laid round from its root, the neck wound round the tower, and the head last, down onto its shelf. Dust bursts again as he sets down, the audio plays the weight landing and rubble, and his eyes shut. |

While he is out, the roost is empty, because the same body is the one flying. Through the telescope the ledge shows its worn bed, the bones and the hoard, with no dragon. The roost's nostril haze is off. The breath and crag sounds stop, since the kit audio follows his state.

## The circuit

World x, z, y in m. The motif isles' circles are from `motif_sky.gd` PLACES and REACH. The roost's ledge is at about (695, 469), 135 m up.

1. Takeoff: out from the ledge, away from the summit (north-north-east), to 170 m out and 40 m over the ledge.
2. (600, 230, 120), then (392, 207, 78): westward between the hollow keel and the bell spires, about 150 m from each.
3. (230, 110, 92), then over the aqueduct isle's middle at its turf + `HOME_OVER` (62 m). This is a sweeping pass from the south-east to the north-west, with his shadow across the turf in the afternoon sun.
4. (-120, -205, 105), (-250, -110, 88): past the colonnade spine and westward between it and the Sundered gorge.
5. (-470, 20, 100), (-450, 215, 88): south, round the broken ring's side of the gorge.
6. (-265, 215, 80), (-60, 215, 86): eastward between the gorge and the drowned nave, then south of the aqueduct isle (about 230 m off), north of the cloister tarn.
7. (392, 207, 82), (620, 240, 130): eastward between the keel and the spires again, and on toward the roost.
8. The approach, 150 m out from the ledge and 30 m over it, from the north-east. Then the landing.

The flight steers to each point and takes it as reached within 105 m (`SkyDragon.ARRIVE`). So the line is a smooth loop near these points, not through them exactly. `OUT_MOST` (240 s) brings him home from wherever he is if he is ever out that long.

## What changed

- `scripts/dragon_wake.gd` (new): the schedule, the beats, the circuit and the pose blending.
- `scripts/sky_dragon.gd`:
  - The roost path hands its frame to the wake when there is one.
  - `awake()` and `open_eyes()` are new.
  - `wake_fly` and `wake_pose` are thin wrappers over the existing flight code.
  - V works while he is out, and the watch camera runs then.
  - The `--dragon` path is untouched.
- `scripts/roost_air.gd`: `dust` (a one-shot CPU particle burst of brown-grey puffs) and `scatter` (the birds' circles go 2.2x wider and 60 m higher, beating, easing back over 45 s).
- `scripts/kit_isle/kit_audio_beasts.gd`:
  - A growl in state "waking".
  - The launch beat, wind slam and rubble on "taking off".
  - Heavier beats while taking off and landing.
  - The weight and grit on landing back to "roosting".
  - All of these use the existing streams through `load()`; there are no new preloads.
- `studies/aqueduct_isle.gd`: makes the wake with the roost dragon, provides `_world_hours`, and keeps him shown while he is out even when his mountain isn't standing yet.
- `tests/test_dragon_wake.gd` (new).

## Checks

All headless.

| Check | Result |
| --- | --- |
| Import | Clean |
| `studies/zenscape.tscn --quit-after 300 -- --no-title` | Exit 0. Shows the known "18 ObjectDB instances leaked / 1 resources still in use" from earlier rounds |
| The same with `--dragon` | Exit 0. The leak counts vary from run to run (21/2, then 23/3); the `--dragon` path's code is unchanged |
| The same with `--dragon-wake` | Exit 0. He stirs at 4 s |
| `tests/test_dragon_wake.gd` (new) | PASS (see below) |
| `tests/test_aqueduct_isle_sky.gd` | PASS |
| `tests/test_aqueduct_isle_life.gd` | PASS |
| `tests/test_kit_audio.gd` (builds the sky dragon, runs the beasts' audio) | PASS |
| `tests/test_kit_clouds.gd` (the roost in the clouds' places) | PASS |

`test_dragon_wake.gd` checks the schedule on its own clock, then runs a `--dragon-wake` wake frame by frame:

| Measure | Value |
| --- | --- |
| Order | stirs, takes off, flies, lands, sleeps |
| Whole wake | about 111 s (stir 9, rise 8, circuit about 80, landing 11) |
| Head lift while stirring | 3.4 m |
| Farthest from the roost | 1210 m |
| Nearest the aqueduct isle's middle | 7 m |
| Least height over its ground (any bone) | 47.9 m |
| Least clearance off a motif isle's circle (any bone below its top + 40 m) | 47 m |
| States | never grabbing, clinging or leaving; no grip, no gale |
| Fastest any bone moves in a frame | 168 m/s, a wing or tail tip in flight. Takeoff peaks at 89 m/s and landing at 158 m/s, so nothing snaps |
| Back home | the coil's frame exactly, and its pose; eyes shut |

The flight's dice are seeded for each wake, so a run repeats. The motif clearance was 6 to 8 m on earlier, unseeded runs, before the gorge/nave gap point went up to 80 m.

## What's rough

- **The coil-to-flight blend isn't seen yet.** It is a per-bone slerp, staggered, under a dust burst, and has only been checked headless (no bone jumps between frames: see the test). Mid-blend, the half-unwound neck could swing through the summit tower, or a wing could pass through the ledge, for a second or two. A rendered look at the takeoff and landing is the next step. If it reads badly, the cover could get thicker (more dust, a brief cloud from the wreath) or the camera could cut wide.
- **The head lift** is small rotations on the neck's head end and the head about each bone's across axis. The neck wraps round the tower, so whether that reads as "lifting off the shelf" or clips the rock has only been checked by the head's height (it rises; see the test).
- **The takeoff climb** is scripted (a fixed path out over the ledge), not the flight's own physics, so it may look a little on rails. The landing curve is the same.
- **The circuit** is fixed world points, laid by hand between the motif isles' circles. If the motif layout moves, the points need moving too; the test catches an isle intruded on.
- **Sound** is untested by ear: wiring only, using the existing clips. The crag howl holds its last level while he is out rather than gusting.
- **At night** (a wake late on the 24-minute day, or a flag wake at night), his hide reads pale, as noted in dragon-roost round 3.
- **The wing fold** at rest is still the roost's finger-shortening cheat; the blend lerps it in and out.
