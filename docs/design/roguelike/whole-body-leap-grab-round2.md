# Whole body leap and grab, round 2 (greybox)

When the whole body (head on) is after something on a higher isle it can't
walk or climb to, it can now leap up and grab that isle's rim, even when the
rim floats over a gap or hangs out over its head. It crouches and looks up,
leaps, catches the rim with both hands, hangs and swings, then hauls itself
up and over with round 1's climb. Headless it can't; the headless body keeps
its routes. All of this sits behind a new body knob, `leap_grab`. It's off by
default and on only in the new study, so the generator and the headless body
isle are unchanged.

## Run it

```powershell
& "C:\Users\Tenut\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --path C:\Users\Tenut\zenscape-godot --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/whole_body_leap_grab.tscn -- --no-title
```

Knobs go after `--no-title`, for example
`--body-knob=grab_up=5 --body-knob=grab_windup=0.7`.

**Keys:**

- **1:** back to the start.
- **2-5:** put you up on an isle (there are no ways up for you), with the
  chase going on:
  - 2, the far isle;
  - 3, the overhang;
  - 4, the high isle;
  - 5, the top tier.
- **B:** the body back where it started.
- **R:** you and the body back at the start.
- **J:** its sight overlay.
- **F1:** numbers, now with a "grab" line: leaps, grabs, refusals and the
  last rim's reason.
- **Esc:** free the mouse.

Round 1's chase is all here, with its attacks.

## The arena

Heights are in the body's head heights (Hh, 3.36 m) and set in the study
script.

| Isle | Top | What happens there |
|---|---|---|
| Base | 0 | 80 m square. You and the body start here |
| Far isle | 3.6 Hh = 12.1 m | Across a 4 m gap north, its wall hanging over the drop. In reach from the base's rim |
| Overhang | 4.4 Hh = 14.8 m | Over the base's east half, its underside 10.8 m up, so the body fits under it. In reach. From under it, it walks out the nearest way and grabs that lip |
| High isle | 5.1 Hh = 17.1 m | Over the base's west half. Just out of reach (most 15.1 m): it won't try |
| Top tier | 2.7 Hh over the overhang (23.9 m) | North of the overhang. In reach from the overhang's top: the next level |

## The rules

The grab is tried each time it walks after a goal: you, where it last saw
you, or its post on the way back. Before a wall or an edge is dealt with,
and only with `leap_grab` and `chase` on and the body whole:

1. **Is the goal up?** It must be more than 2.5 steps (`step`) over its
   feet.
2. **Find the rim.** It looks along its way to the goal for the first top
   over it, between those 2.5 steps and `grab_up`.
   - If it stands under a place already, it looks out from under it the
     nearest way of four, its way to you first.
   - A rim is found by halving down to about 2 cm.
3. **Decide.** The rim must have room for its body on top.
   - **Face down to its floor:** if the rim's face comes down to its floor,
     it doesn't leap. It walks to the face and climbs it (round 1).
   - **Too high:** a top over `grab_up` is refused ("out of reach") and
     counted.
   - **Too far:** if the hang point is more than `grab_out` off, it walks to
     the hang point first.
4. **Leap.**
   - **Wind-up:** it turns to the rim, crouches (the windup clip) and leans
     back to look up. This lasts `grab_windup`, with a "crouches and looks
     up" toast.
   - **Launch:** an arc whose top is its hang point (its feet its reach
     under the lip). A dust puff and a small wave at take-off.
   - **Catch:** at the top of the arc, the lip must be within `grab_tol`
     of its hands. If it is, it catches: dust, stones knocked off, a
     rumble, a small shake. If not, it falls, and rests `grab_rest` before
     trying again.
5. **Hang:** it swings out and back for `grab_hang`, the swing dying away,
   with its hands slapped onto the lip.
6. **Haul:** round 1's climb with its hands on the lip: the haul, the
   mantle and the mantle's wave. Then on with the chase.

One more rule: if it can see you right over it, out of its reach, for 3 s,
it gives up and looks about. Before this it paced under you for good.

## Knobs

Set these with `--body-knob=`. Hh is a head height (3.36 m); `unit` is your
height (1.12 m).

| Knob | Default | What it sets |
|---|---|---|
| `leap_grab` | 0 (1 in the study) | Turns the grab on (whole, with `chase` on) |
| `grab_up` | 4.5 Hh = 15.1 m | Highest rim over its feet it leaps for |
| `grab_out` | 2.5 Hh = 8.4 m | Furthest its hang point may be, flat, from where it leaps |
| `grab_windup` | 1.0 s | The crouch and look up |
| `grab_tol` | unit × 1.0 = 1.12 m | How far its hands may miss the lip and still catch it |
| `grab_hang` | 0.9 s | Hanging and swinging before it hauls |
| `grab_rest` | 2.0 s | Before it tries again after a grab or a miss |
| `grab_lean` | 0.14 rad | How far it leans back looking up |

The haul's pace is round 1's climb: `climb` and `haul` (`haul` 0.55, about
0.77 m/s with its hands on the lip).

## Verified

All of this was headless at fixed 60 fps.

- **Smoke runs,** no script errors:
  - the headless import;
  - `whole_body_leap_grab.tscn`, `whole_body_chase.tscn` and
    `headless_body_isle.tscn`, 600 frames each;
  - `run_layer.tscn` for sprawl 2, sprawl 8 and ring 1, 400 frames each.
- **Throwaway driver** (`.claude/tmp/grab_driver.gd`, deleted after). It
  drives you through the real input path: Input actions, then the study's
  stick, then the motor. Teleports only set up each bout. All checks pass:
  - **Far isle (12.1 m, over the gap):**
    - it spots you up there in 1.5 s;
    - it winds up with the rim 12.1 m up and 8.4 m off;
    - wind-up 1.0 s, flight 0.58 s, rising 3.1 m to its hang;
    - it catches the rim, hangs, and is over the top 9.4 s after the
      catch;
    - then it chases you up there and swats you.
  - **High isle (17.1 m):** it spots you at its rim and never leaps. It
    refused 28 times ("rim 17.1 m up (most 15.1 m): out of reach"), then
    looked about and went back.
  - **Overhang (14.8 m), starting under it:**
    - it walks out the nearest way and winds up in 1.3 s;
    - it hangs from the south lip, nearest you, and hauls round onto the
      top.
  - **Two levels:** base, then the overhang (1 grab), then up onto the
    top tier (2 grabs, 14.3 s after you went up).
  - **Listen clip:** no hunting state plays it (0 of 4,180 frames).
- **Rendered captures** (short windowed runs quit by a watchdog; stills
  looked at):
  - from up on the far isle: its head coming over the rim while it hangs
    with its hands on the lip, then the haul (hands and dust on the lip);
  - from the side on the base: the wind-up crouch, it hanging under the
    far isle's rim, and the haul over.

  One fix came from the driver: from under the overhang it first went out
  the far side, away from you. It now takes the nearest way out, your way
  first.
- **Full suite:** not rerun. The change is gated and the round 1 suite
  showed no breaks.

## Not verified (yours to judge by playing)

- How the leap reads in play:
  - the wind-up is the windup clip plus a procedural lean back, and from
    the side it reads as a deep coil more than a look up;
  - the 0.58 s hop up to the hang is quick;
  - the haul, about 9 s from the catch to the top, may be slow.
- Its eyes are about 9.6 m up. On an isle much higher than that you're out
  of its sight unless you stand near the rim. In the study it chases where
  it last saw you, so if it didn't see you go up it won't come. Key-teleports
  can hide you that way.
- Roaming: it only grabs when its goal is up. It does that hunting, and
  going back to its post. Its wander goals (the route planner's) never ask
  for a grab.
- GPU-only behaviour.

## Clips to author (Blender)

- **Grab wind-up:** a deep crouch with the head and chest tipped up at the
  rim and arms swung back. Now it's windup plus a procedural lean.
- **Leap up:** arms reaching overhead. Now it's the first half of jump_air.
- **Catch and hang:** the hands slapping onto the lip, the body swinging
  under it with its legs trailing, and the swing settling. Now it's the haul
  clip, with the hands placed on the lip and a procedural swing.
- **Free-hang haul:** pulling up with no wall under its feet, legs kicking.
  Now it's the haul clip, made for a wall.

No model was made or changed.

## Files

- `scripts/enemies/headless_body.gd`: additive.
  - The `leap_grab` and `grab_*` knobs.
  - The states `grab_windup`, `grab_leap` and `hang`, plus
    `grab_spot()`, `_top_over()`, `_grab_try()` and the lean.
  - In the chase: the under-you give-up, and the grab tried in `_pursue`.
  - The hang shares the climb's hand placement and haul clip.
  - `_move` skips its ground snap in the new states.
- `studies/whole_body_leap_grab.gd` and `.tscn` (new). The study extends
  `studies/whole_body_chase.gd`, which gained `body_at`, `body_face` and
  `_study_body_knobs()` for it.

## Tests broken

None known from this change.

- `test_run_layer.gd` and `test_dragon_sight.gd` pass.
- `test_layer_sprawl.gd` fails in plan-level checks: "spawn faces",
  "exit chain", "into the void", and an out-of-bounds index in the test's
  `_sprawl_plan`. These check the generator's plan and crossings, which
  another session is editing right now, not the enemies. On the earlier
  baseline it timed out.
- The full suite wasn't rerun.

## Open questions

1. **Reach:** is 15.1 m up and 8.4 m out right? Should it reach the high
   isle (17.1 m)?
2. **Timing:** is the wind-up (1.0 s), the swing (0.9 s) and the haul
   (about 9 s) right? Should the free-hang haul be quicker than the haul up
   a wall?
3. **Sight:** should it guess where you went when you vanish up onto an
   isle (look up, or hear you), rather than only chase where it last saw
   you?
4. **Roaming:** should it leap up isles while roaming too, as its own way
   through a layer? That means teaching the route planner (`body_routes.gd`)
   a "grab" leg.
5. **The generator:** should `leap_grab` be on there? It's off now.
