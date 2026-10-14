# Whole body chase, round 1 (greybox)

Once the headless body has its head back, it now hunts you. It sees you,
chases you at less than your run, swats you up close, pounces on you from a
little way off, and further off it plants and sucks you in with its head's
breath. It climbs and leaps after you with the head on. All of this sits
behind a new body knob, `chase`. It's off by default and on only in the new
study, so the generator and the headless body isle play as they did.

## Run it

```powershell
& "C:\Users\Tenut\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --path C:\Users\Tenut\zenscape-godot --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/whole_body_chase.tscn -- --no-title
```

Add knobs after `--no-title`, repeating as needed:
`--body-knob=chase_speed=4 --body-knob=suck_max=8 --head-knob=pull=6`.
`--no-sight-overlay` starts with the overlay hidden.

**Keys:** WASD, Space and the rest move you as in every study.

- **J:** show or hide its sight overlay (on at start).
- **B:** put the body back where it started, whole and unaware.
- **R:** put you and the body back at the start.
- **F1:** numbers (its state, awareness, and counts of spots, pounces, sucks, swats and catches).
- **Esc:** free the mouse.

Tip: it's about 10 m tall. Look up with the mouse to see the head.

## The arena

It's one grey arena, 100 m square, in open sky.

- **You start** behind a long wall (32 m long, 12 m tall), out of its sight. It stands about
  30 m north of you.
- **Cover:** the long wall and three 14 m pillars. All are taller than its
  eyes (about 9.6 m).
- **East ledges:**
  - a low ledge at your pump catch height (`RuinKit.CHAIN_TOP`, 2.6 m);
    it pounces up onto it;
  - a mid ledge (6 m) and a tower (12 m), which it climbs;
  - ramps up for you.
- **West isle:** across a level gap of 2.5 walker heights (2.8 m). You jump
  it, and it jumps after you.
- **North shelf:** across the same gap but 2.5 m lower. It leaps down after
  you, and a ramp at the east end brings you back up.

## What it does

Its sight is the dragon's, reused (`scripts/enemies/body_sight.gd` extends
`scripts/dragon_sight.gd`):

- It casts rays to your feet, chest and head.
- It has the same awareness meter and thresholds: **unaware**, then
  **suspicious** at 0.3, then **spotted** at 0.85.
- The cone is flat: 0.9 rad either side of its facing, out to 45 m, at any
  pitch, because it looks down at you.
- The overlay draws the cone as a fan on the ground with a rim at 15.7 m.
  It draws a green, red or grey ray to each of your points, the meter, and
  what it is doing and why, with its attack ranges and their cooldowns.
- Toasts on screen say "It sees you!", "It lost you…", "It gives up…" and
  so on.

It moves between these states:

- **Unaware:** it roams, as a whole body always did.
- **Suspicious:** it stops and turns toward where it glimpsed you.
- **Spotted:** it calls (the head's moan) and chases you at `chase_speed`.
- **Lost:** it walks to where it last saw you and looks about for 5 s. Then
  it gives up, walks back to where it started, and roams again.

### The attack rules

Each frame it chases you and can see you, it picks by your flat distance
from it. Hh is one head height, 3.36 m.

| Your distance | It does |
|---|---|
| ≤ `catch_reach` (1.3 Hh, 4.4 m), within about 4 m of its height | **Swat:** arms up 0.55 s, then fists down. In reach, you're knocked down and away. |
| `pounce_min` to `pounce_max` (5.4 to 15.1 m), you no more than 1 Hh above it or 1.5 Hh below, a clear arc, pounce rested (3 s) | **Pounce:** crouch 0.8 s while it tracks you. It locks your spot 0.3 s before it goes, then flies about 1.2 s. If it lands within 2.2 m of you, you're caught. Its landing wave (power 0.7) throws you if you're on the ground. |
| `suck_min` to `suck_max` (15.1 to 23.5 m), its head's draw reaches you clear, suck rested (7 s) | **Suck:** it plants (1.2 s, the jaw opening), then inhales (5 s). Drawn to its feet, you're swallowed, held 1.2 s, and blasted out. |
| anything else | It walks at you. |

While chasing:

- **A wall in the way:** if you're above it, it climbs, the same climb as
  headless. Otherwise it skirts round, and if there's no way round it
  climbs anyway.
- **An edge:** it jumps a gap to a ledge across, or drops to a lower floor
  if you're below. Otherwise it goes along the rim, or stops and looks.

"Caught" is only a knock (`PilotMotor.knock`, laid down 1.2 s). That's the
same convention as the other enemies. There's no damage.

## Knobs and defaults

Set these with `--body-knob=`. `n.run` is your run (4.8 m/s), `unit` is your
height (1.12 m), and Hh is a head height (3.36 m).

| Knob | Default | What it sets |
|---|---|---|
| `chase` | 0 (1 in the study) | Turns the hunt on (only once it's whole) |
| `chase_speed` | run × 0.9 = 4.32 m/s (was 0.7) | Its chase pace |
| `chase_turn` | 1.8 | Its turn rate while chasing, × `turn` |
| `chase_memory` | 8 s | Unseen this long, it stops at once and looks |
| `sight_range` / `sight_half` / `sight_near` | unit × 40 (45 m) / 0.9 rad / unit × 14 | The cone and the falloff |
| `sight_fill` / `sight_grace` / `sight_drain` | 1.4 / 1.0 s / 0.3 | The awareness meter |
| `search_for` / `search_reach` / `return_for` | 5 s / unit × 2.5 / 30 s | Looking about, how close it gets to the last-seen spot, how long it walks back |
| `catch_reach` | 1.3 Hh | Swat range |
| `swat_windup` / `swat_after` | 0.55 / 0.7 s | The swat's timing |
| `swat_out` / `swat_up` / `swat_down` | unit × 9 / unit × 2.5 / 1.2 s | How hard a catch knocks you (the pounce's too) |
| `pounce_min` / `pounce_max` | 1.6 / 4.5 Hh | Pounce band |
| `pounce_rise` / `pounce_sink` | 1.0 / 1.5 Hh | How far up or down it will pounce |
| `pounce_windup` / `pounce_lock` | 0.8 / 0.3 s | Crouch time, and the blind last bit where it stops tracking |
| `pounce_arc` / `pounce_rest` | 0.3 / 3 s | Arc height share, cooldown |
| `pounce_hit` / `pounce_shock` | unit × 2 / 0.7 | Catch radius on landing, landing wave power |
| `suck_min` / `suck_max` | 4.5 / 7 Hh | Suck band |
| `suck_tell` / `suck_for` / `suck_rest` | 1.2 / 5 / 7 s | Plant time, inhale time, cooldown |
| `suck_turn` / `suck_lose` | 0.6 rad/s / 1 s | Its turn while inhaling; out of sight this long ends it |
| `suck_gulp` | unit × 1.5 | How near its front counts as drawn in |
| `spent` | 1.2 s | Its pause after a suck or a blast |

Worn up on the neck, the head reaches farther than on the ground. Its own
`worn_*` knobs (`--head-knob=`) stand in for `reach`, `pull_d0` and `pull`
only while it's worn by a hunting body. Its knobs on the ground are
unchanged, so the generator's heads get the same worn draw.

| Head knob | Default | Was (tweak 2) |
|---|---|---|
| `worn_reach` | unit × 28 (31.4 m) | the study set `reach` = unit × 26 |
| `worn_pull_d0` | unit × 20 (22.4 m) | the study set `pull_d0` = unit × 18 |
| `worn_pull` | run × 1.3 (6.24 m/s) | `pull` at its default, run × 1.05 (5.04 m/s) |

The trip, the gulp's hold and the blast are the head's own knobs,
unchanged.

## How it's built

- **`scripts/enemies/headless_body.gd`:** additive.
  - The `chase` knobs and their states (alert, chase, seek, return, plant,
    suck, gulp, swat, spent), the `chase_beat` signal, `make_whole(head)`,
    `worn_draw()`, `worn_gulp()`, `chasing_whole()` and `doing()`.
  - The pounce is the existing windup and leap with a new leap kind,
    `"pounce"`.
  - A `_resume()` hook replaces the hard-coded "listen" after a landing or
    a mantle. It returns "listen" unless the chase is on.
  - `_meet_wall`'s climb start became `_start_climb` (same code).
- **`scripts/enemies/inhaler_head.gd`:** additive.
  - `_worn()` runs only on a body whose `chasing_whole()` is true. It
    reuses the tell and inhale look, `_pull`, `_gulp`, `_hold` and
    `_blast`.
  - A gulp at the body's feet goes through `worn_gulp`.
  - `_clear` also skips its body's box when perched.
- **New:**
  - `scripts/enemies/body_sight.gd` and `scripts/enemies/body_sight_overlay.gd`
    (the latter extends the dragon's overlay);
  - `studies/whole_body_chase.gd` and `studies/whole_body_chase.tscn`.

## Verified

- **Headless import:** clean.
- **Smoke runs, headless, no script errors:**
  - `whole_body_chase.tscn`: 400 and 600 frames;
  - `headless_body_isle.tscn`: 600 frames. Its "ObjectDB instances leaked
    at exit" warning is also there on an unchanged copy;
  - `run_layer.tscn -- --shape=sprawl --seed=2`: 400 frames.
- **Throwaway driver, headless at fixed 60 fps.** It drives you through the
  real input path: Input actions, then the study's stick, then the motor.
  It sets the camera's yaw like the mouse does. Teleports only set up each
  bout. All 22 checks pass:
  - **Spot:** it spots you in the open in 1.0 s at 20 m.
  - **Outrun:** it chases at 3.24 m/s while you run at 4.76 m/s. Over 14.5 s
    the gap grows from 20 m to 42 m.
  - **Lose and give up:** keeping a pillar between you, it loses you. It
    reaches your last-seen spot and looks, 8.6 s after spotting. It gives up
    5.0 s later and walks back to within 2.9 m of its start in 11.1 s.
  - **Pounce, standing still:** it winds up at 12 m (0.8 s), flies 1.23 s
    and lands 1.6 m from you: caught.
  - **Pounce, dodged:** a sideways run started at the lock dodges it. It
    lands 6.6 m from you, no catch, but its landing wave still threw you
    once. The driver's jump came too late.
  - **Climb:** you up the 6 m ledge. It climbs 4.7 s after spotting you,
    is up and over 4.5 s later, and swats you up there 3.2 s after that.
  - **Pounce up:** it pounces up onto the low ledge (2.58 m) and catches
    you there.
  - **Gap:** it jumps the 2.8 m west gap after you and lands on the west
    isle.
  - **Suck:** you stand still at 20 m. It plants after 1.0 s, pulls you at
    up to 4.9 m/s (you trip and are yanked in), and swallows you 4.2 s after
    planting. It holds you 1.2 s and blasts you out; you come to rest 24 m
    away. Running off sideways out of its cone escapes.
- **Rendered captures** (short windowed runs quit by a watchdog; stills
  looked at). They show:
  - the spotted overlay (fan, green rays, red meter);
  - the pounce crouch and the body in the air;
  - the inhale: lit eyes, open jaw, streaks drawn in;
  - it up on the 6 m ledge after you.

  Fixes made from them:
  - the overlay text was split into shorter lines and the hint shortened
    (both ran off screen);
  - the fan is no longer filled while it's in the air or on a wall;
  - the tower ramp moved off the mid ledge (it made a tunnel you could
    hide under);
  - the east ledges moved 8 m in from the rim, because a catch near the rim
    threw you off the world;
  - the catch's throw went down from unit × 12 to unit × 9.
- **Full suite:** `tools/run_tests.py`, headless, 8 jobs. On this Windows
  PC it fails a lot without this change. An unchanged copy of the tree
  failed 74 tests (Mac paths, timeouts, load). With this change, 63 failed.
  - Every failure but one also fails on the unchanged copy.
  - The one new failure, `test_threaded_surface_maps.gd`, passes when run
    alone. It's a load flake and doesn't touch the enemies.
  - So no existing test is broken by this change, but the suite isn't
    green. Nothing was added to `known_failures.txt`.

## Not verified (yours to judge by playing)

- How it reads and feels in play. In particular:
  - whether the 0.8 s pounce crouch is readable enough. In the captures it
    is the headless windup clip played fast, and it reads only mildly;
  - whether its landing wave makes a sidestep feel unfair;
  - the camera. At the walker's camera distance its head is often off the
    top of the screen.
- GPU-only behaviour; the suite's gpu tests were not run.

## Clips to author later (Blender)

The new moves are placeholders built from existing clips:

- **Pounce windup and air:** the windup clip played over 0.8 s, then
  jump_air and land. It wants its own coiled crouch, with the head down and
  hands back, and a bigger squash on landing.
- **Swat:** the triumph clip's arms up and fists down, retimed. It wants a
  real overhead smash, with anticipation, a hold and follow-through.
- **Plant and inhale stance:** the windup clip held 45% in. It wants a
  braced stance, leaning back against the draw, with a tremble.
- **Seek:** since tweak 3 it no longer plays the listen clip. It turns to scan, stepping on the spot as it turns (the walk clip, weighted by how fast it turns), or stands (idle). It wants an authored look-about with its head on.
- **Gulp hold and blast recoil:** the body stands idle. It wants a rock back
  with the blast.

No model was made or changed, so the model-budget tricks don't apply this
round.

## Open questions (decide by playing)

1. **Speeds:** is a chase at 0.9 × your run right (tweak 1)? Is 0.8 s of pounce crouch
   too slow or too quick to react to?
2. **Ranges:** swat 4.4 m, pounce 5.4–15.1 m and suck 15.1–23.5 m. Should
   the suck band overlap the pounce band, or should the suck be rarer?
3. **Catching you:** what should it do? Now a catch is a knockdown, and the
   suck is swallow, hold and blast. Should a catch end the run, cost
   something, or reset you?
4. **The pounce's landing wave:** should it throw you when it misses? Now a
   sidestep alone isn't enough; you also have to jump the wave.
5. **Hearing:** should it hear you next (your footsteps, landings), the way
   it hears its head now?
6. **The generator:** should whole bodies there hunt (`chase` on)? It's off
   for now. Its chase goes straight at you and doesn't use the route
   planner (`body_routes.gd`), so on the generator's isles it may need
   routes.

## Tweaks after play (round 1b)

The user played it and asked for three tweaks:

1. **Faster chase:** `chase_speed` went from run × 0.7 to run × 0.9
   (4.32 m/s). You can still outrun it on the flat at a run, just about:
   - the driver measured you at 4.76 m/s and it at 4.11 m/s over 14.5 s
     (it loses a little turning and speeding up);
   - the gap went 20.0 m, then 25.7 m at 7 s, then 29.3 m at 14.5 s, where
     at 0.7 it went 20 m to 42 m;
   - it never caught you.

   Any stop, turn or pounce of yours gives it the ground back.
2. **Stronger suck:** the worn draw went from `pull` run × 1.05, `pull_d0`
   unit × 18 and `reach` unit × 26 to run × 1.3, unit × 20 and unit × 28.
   These are now the head's `worn_*` knobs, so the generator's heads get
   them too.

   | Standing still at 20 m | Before | After |
   |---|---|---|
   | Pull at the start of the inhale | 2.06 m/s | 3.11 m/s (4.42 m/s once fully drawn) |
   | Pull at its peak | 4.91 m/s | 6.10 m/s |
   | Swallowed after planting | 4.23 s | 3.43 s |

   Escapes still work:
   - a committed sprint sideways out of its cone from the moment it plants
     ends 26.5 m off;
   - a sprint straight away round the long wall's end also escapes
     (29.5 m off).
3. **No listen gesture:** the seek no longer plays the listen clip. It turns
   to scan, stepping on the spot as it turns (the walk clip by how fast it
   turns), and stands idle in between.
   - The driver logged the clips over every hunting frame across all its
     bouts: the listen clip played on 0 of 4,180.
   - The seek played stride, walk and idle.
   - Whole, its plain "listen" state already played idle.

## In the generator (round 1c)

The user asked to play the generator (`studies/run_layer.tscn`) against
whole bodies with these attacks:

- **Chase on:** the generator's bodies now have `chase` on
  (`LayerBodies.knobs`, `scripts/roguelike/layer_bodies.gd`).
  `--body-chase=0` turns it off. It's its own flag, not a `--knob=`, so the
  plan doesn't warn about an unknown knob.
- **Suck reach:** the generator's heads get the worn draw from their own
  `worn_*` knobs, used only while worn by a hunting body. Their grounded
  `reach`, `pull_d0` and `pull` are unchanged, and no generator file sets
  them.
- **Way back:** a body that came up a cliff now has the top it came over
  onto as its post. If its post isn't on a floor, giving up sends it
  straight back to roaming (its routes).

Launch:

```powershell
& "C:\Users\Tenut\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --path C:\Users\Tenut\zenscape-godot --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
```

Add `--body-chase=0` to play without the hunt.

**Verified headless** (a throwaway driver, deleted after). A body comes up
its head's cliff, is set whole, and the walker is set 7-18 m in front of
it. Then a minute of hunting:

| Layer | Spotted | Pounces | Sucks (gulps) | Swats | Catches | Gave up | Into the void |
|---|---|---|---|---|---|---|---|
| sprawl 2 | in 1.0 s | 4 | 1 (1) | 0 | 4 | 0 | no |
| sprawl 8 | in 1.0 s | 7 | 3 (1) | 0 | 7 | 1, then walked back | no |
| ring 1 | in 17 s | 1 | 2 (1) | 1 | 1 | 1, then walked back | no |

Over the minute its lowest point was its own isles' ground or a drop onto
a lower isle; it never went into the void. Smoke runs of `run_layer`
(sprawl 2, sprawl 8, ring 1, 400 frames each), `whole_body_chase` and
`headless_body_isle` showed no script errors. `test_run_layer.gd` passes.

Unverified, and worth judging by playing:

- **Thrown off isles:** on the generator's small isles a catch's knock
  (unit × 9) or a landing wave often throws you off an isle. In the
  driver's minute that happened 27 times on sprawl 2, 1 on sprawl 8 and 12
  on ring 1, and the driver set you back by it each time. Each fall would
  cost you the layer.
- **Routes:** the chase still goes straight at you and doesn't use the
  route planner.
