# Raider combat: handoff (loop `raider-combat`, branch `iter/raider`)

This builds on the raider greybox (`raider-handoff.md`). Spec:
`spec-raider-combat.md`. It's still an experiment and everything sits behind
`--raider`. No tests were committed and the full suite wasn't run.

## What's built

- **Lock-on** (`scripts/endless/lock_on.gd`). Press `fly_lock` to lock on to
  the target nearest the middle of the view. It must be within 700 m, on
  screen and not hidden behind the land. Press again to let go.
  - It also lets go past 950 m, after 1.5 s off screen or behind the land, or
    on a kill.
  - The view turns 0.6 of the way toward the target, easing over 0.45 s, and
    keeps the plane within 0.72 of the half view. It also widens 4 degrees.
    The flying isn't touched.
  - Depth of field focuses at the target's distance and the far land
    softens. The near blur stops short of the plane, so the plane stays sharp.
  - A gold reticle with four corners, a dot and "LOCKED" sits on the target.
  - Any node in the group `lock_on` can be a target. The raider's figure is
    the first.
  - While locked, the rival race offers no traffic plane, because R3 is both
    the lock and the challenge.
- **The chase** (`scripts/endless/raider_chase.gd`, the raider's state
  `flee`).
  - **How it flies:** it runs low (4 m) over the land, the tree crowns and
    stone, by plane rules (turn 0.9 rad/s, bank, capped pitch).
  - **Its route:** every 0.35 s it picks a heading from a fan, weighing trees,
    climbs, the sea and turns. It avoids running back at you, is drawn toward
    arches and is pulled home past 5.5 km.
  - **Arches:** it takes a land arch whose opening is at least
    `WorldScale.opening(3.5)` (7 m). It flies to a run-in point and then on
    rails through the middle.
  - **The sea:** it prefers to head for the nearest land.
  - **Pace:** 1.12 x your Boost, easing to 1.0 x between 350 and 650 m off.
  - **Skimming:** flying close to what's under you builds heat (the
    near-miss meter's clearances, within 6 spans). Heat adds up to 40 m/s to
    your plane (`SkyPlane.skim_over`), so a low line closes the gap and a high
    one loses it.
  - **Losing it:** if you're 750 m off, or it's behind the view for 3 s, it
    comes round ahead of you and runs again. It never vanishes.
- **The dogfight** is as in the greybox: stalk, a 0.9 s tell ("RAM!" and a
  nose glow), the ram, a dodge for meter, the hit and knock, and the
  surge-roll kill.
- **The mix** (the default; the `MIX_*` constants in `raider.gd`):
  - It shows up for the dogfight.
  - **Breaking off:** after 2 or 3 passes (rolled each time), it breaks off
    the next time all of these hold:
    - it's 40 to 450 m off;
    - it's ahead of you or beside you;
    - it's flying away from you.
  - **Being tailed:** sat on its tail (within 220 m, your nose within 30
    degrees) for 4 s, it breaks off whatever the count.
  - When it breaks off, it runs from where it is with a whoosh, and its
    marker reads "RUNS" for 1.6 s. A faint orange glow at its tail makes it
    readable past about 80 m.
  - **Losing it:** if you lose it after its first 10 s of running, or it has
    run 30 s (counted only while you're more than 150 m off), it goes back to
    the dogfight with a fresh pass count.
  - A kill ends either one. The next raider comes 20 s later for the
    dogfight.
  - The lock holds across the switches.
- **Kills:** during the chase the surge roll kills it within 14 m
  (`KILL_FLEE`), and height counts 0.6 because you come at it from above.
  Elsewhere the kill radius is 10 m. The surge roll reaches about 25 m ahead,
  so press it at 25 m or closer.
- **Relaunches:** after a crash and relaunch, the raider follows the new plane
  and sweeps no pass across the jump.

## How to play

Each mode with a throwaway save:

```
cd /Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/agent-a2737f8784f0ef9df && python3 tools/play.py --no-pull -- --raider --pilot-file=/tmp/raider_pilot.json
cd /Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/agent-a2737f8784f0ef9df && python3 tools/play.py --no-pull -- --raider --raider-mode=dogfight --pilot-file=/tmp/raider_pilot.json
cd /Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/agent-a2737f8784f0ef9df && python3 tools/play.py --no-pull -- --raider --raider-mode=chase --pilot-file=/tmp/raider_pilot.json
```

The first command is the mix.

In chase mode the seed-1 start faces west. The forest and arches lie east, at
x 1.5 to 3 km, so turn round.

Controls:

| | Keyboard and mouse | Pad |
|---|---|---|
| Lock on or let go | Y, or the middle mouse button | R3 |
| Roll (on a full meter, the surge roll that kills) | Z, or left click | A |
| Surge (the meter's surge) | B | X |
| Boost | Space | RT |

## Knobs

| Flag | Constant | Default | What it does |
|---|---|---|---|
| `--raider-mode=` | | `mix` | `dogfight`, `chase` or `mix` |
| `--raider-pace=X` | `PACE` (chase) | 1.12 | Its speed in the chase, as a multiple of your Boost |
| `--raider-skim=M/S` | `SKIM_GAIN` | 40 | Your speed gain at full skim heat |
| `--raider-low=M` | `LOW` | 4 | How high it flies over what's under it |
| `--raider-dive=RAD` | `PITCH_DIVE` | 0.7 | How steeply it dives after a break |

The greybox flags (`--raider-every`, `-ram`, `-tell`, `-hit`, `-near`,
`-shove`, `-fill`, `-turn`) are unchanged.

Constants with no flag:

- `raider.gd`:
  - the mix: `MIX_PASSES` (2, 3), `MIX_BREAK_M` (40, 450), `MIX_TAIL_M` 220,
    `MIX_TAIL_DEG` 30, `MIX_TAILED_S` 4, `MIX_CHASE_MOST` 30, `MIX_NEAR_M`
    150, `MIX_GRACE` 10, `MIX_AWAY` and `MIX_ABEAM` 0.2, `RUNS_S` 1.6;
  - the kill: `KILL_FLEE` 14 and `FLEE_UP` 0.6;
  - the tail glow: `FLEE_GLOW` 0.3 and `FLEE_GLOW_NEAR` 50.
- `raider_chase.gd`: `EASE_M`, `CLIMB` 0.4, `PITCH_DOWN` 0.3, `SKIM_BAND` 6,
  the fan weights `W_*`, the arch run-in (`APPROACH`, `RUN_IN`, `RAILS`) and
  the sea (`W_SEA`, `W_SEA_HOME`).
- `lock_on.gd`: `REACH`, `LET_GO`, `LOST_S`, `BIAS`, `AIM_EASE`,
  `PLANE_KEEP`, `WIDE` and `DOF_*`.

## What the checks showed

The drivers are throwaway and uncommitted, in `scratch/`. All runs are seed 1,
through the real play loop: R3 and the roll button go in as input events,
Boost is held and the stick steers.

- **Smoke, all four modes, on the final tree:**
  `python3 tools/smoke.py studies/endless_flight.tscn -- --raider`, and the
  same with `--raider-mode=chase`, `dogfight` and `mix`. Each one passed: 400
  frames, 0 errors.
- **Lock-on** (`lockon_check.gd`): 20 of 20 checks passed.
  - R3 locks on and the view turns from 39.8 to 18.3 degrees off the raider.
  - The plane stays in frame and depth of field is on.
  - R3 lets go and the view eases back.
  - A kill lets go, and so does a hard turn away.
- **Chase** (`chase_check.gd`):
  - Flown high and straight, the gap opens, 230 to 343 m.
  - Flown low on its trail, the gap closes, 349 to 231 m, with a skim gain of
    +6 to +9 m/s on average.
  - The meter fills from skimming.
  - A surge roll from behind kills it.
  - It never flew into a solid (0 clips, 0 lifts), and it ran under arch
    `endless/arch/3_-2/0` and low over trees.
- **Mix** (`mix_check.gd`): 17 checks, 0 failures.
  - It breaks off after its passes, in frame and still locked.
  - It's down low within about 6 s.
  - Once lost, it comes back for the dogfight and you lose the skim gain.
  - It comes at you again.
  - The next break, followed low, ends in a surge-roll kill. The driver
    topped the meter up once it passed 0.5; the chase run proves the meter
    can be earned.
  - Nothing is offered while locked.
- **Relaunch** (`relaunch_check.gd`, 12 crashes): the raider kept to the
  plane's height. Its mean height over the land was 103 m and the worst
  204 m, against the 1,300 to 1,800 m before the fix. That earlier height
  came from the drivers steering by the old, crashed plane.
- **Rendered, the last round:**
  - **The mix** (`mix_check.gd --stills_only --shots`): 11 checks, 0
    failures.
    - It broke off after 3 passes (1 hit, 1 dodge, 1 miss), 42 m ahead and
      still locked.
    - It was down low in 133 frames.
  - **The chase**, staged at the arch at `--at=1650,200` (`chase_check.gd
    --stage --lock --shots`):
    - Followed low, the gap closed from 200 to 148 m, with a skim gain of
      +12.3 m/s on average.
    - The first surge roll killed it, passing 14.9 m off.
    - 0 clips, 0 lifts, and it took 1 arch.
    - The one FAIL is the "high and straight" leg, which staging skips. The
      same happened headless.
  - Earlier rounds' rendered runs looked at lock-on with depth of field: the
    raider is sharp, and the far ridges and clouds are soft.

## Unverified

- **Feel by hand:** how often it switches, whether the chase is catchable by a
  player rather than the driver, whether the lock's view turn helps or gets in
  the way, and whether the 14 m chase kill is fair. A player's flight has to
  judge all of these.
- **Frame cost:** not measured. This includes the chase's fan of rays every
  0.35 s, its look-ahead samples every frame, and the depth-of-field blur
  while locked (the global quality setting).
- **No rendered still of a later tell.** Two rendered runs looked for a
  locked tell after the first one, without the start gate in frame. In both,
  the later passes came from behind or out of the locked view before it broke
  off, so the only locked dogfight still is the first tell.
- **No rendered still at an arch.** The chase took its arch before the lock
  was on, so there's none from this round.
- **The kill in the mix rendered.** The rendered mix run here stopped after
  the chase stills. A headless run and an earlier rendered run (2bce1142) did
  reach the kill.

## Open

- **Lifts:** the last-resort lift onto a solid's top is rare but real. It
  happened coming in off the sea at a solid on the coast, and at an arch on
  leg 0 right after a break.
- **Sitting on its tail** alternates 30 s of chase with 4 s of stalk, and it
  never rams.
- **The empty bracket low left** in the first locked tell, right after
  takeoff, is the start gate of the place line `meadow_dash`. That's the
  game's own mark; the raider combat doesn't draw it.
- **The hint line** doesn't name the lock key.
- **Debug counters** in `raider_chase.stats` should be trimmed at lock-in.
- **Lock-in** would bring committed tests, built from the drivers above.

## Stills

All from the plane's camera with the HUD, rendered on the Mac, seed 1, in
`raider-combat-stills/`. Each is scaled to 1200 px and saved as a JPEG.

- `dogfight_first_tell_locked.jpg`: the locked dogfight and the warning. The
  raider's marker reads "RAM!" inside the LOCKED reticle, and the far land is
  soft. The empty bracket low left is the start gate of the place line
  `meadow_dash`, the game's own mark, about 200 m ahead at takeoff.
- `dogfight_ram.jpg`: the ram, 8 m off, the raider inside its red-orange
  glow, closing on the plane.
- `mix_runs_break_off.jpg`: the break-off. "RUNS" over the raider in the
  locked reticle.
- `chase_locked_trees.jpg`: the chase, locked at 87 m, the raider low over
  the spruce ahead and the plane skimming the crowns (a "TREE GRAZE" on the
  line).
- `chase_kill_flash.jpg`: the kill, the surge roll's orange flash where the
  raider was.
- `chase_kill_smash.jpg`: a moment later, the burst and "SMASH +300" on the
  line.

Earlier rounds kept stills of the chase at an arch and of lock-on close and
released in `/tmp` and in their worktrees' `scratch/`. They aren't committed.
