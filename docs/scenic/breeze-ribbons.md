# Breeze ribbons: the air drawn

Branch `feature/wind-fronts`, 2026-10-03. The user wanted the wind to feel like a living system: always going, varying, and "expressive, continuous, fluid... it's got a swirl, it's got a verticality, it'll come up, come down... more painterly". They disliked seeing the breeze "come in on one individual tree, and then on another".

## What it replaced

`scripts/weather_wind_trails.gd` drew each stroke as the same 6 m sine curve, stamped at a random spot on the plate. The stroke stayed put while a dash slid along it. Nothing joined one mark to the next, so the air seemed to land on one tree and then on another. It is still available with `--old-trails`.

## How a ribbon moves

`scripts/breeze_ribbons.gd`. A ribbon is the trace of a mote carried on an air field, `flow`. Each tick (fixed `STEP` of 1/60 s) the mote moves:

- downwind at its speed;
- across the wind by a slow noise field (`MEANDER` 2.6 m/s, scale 0.07 per metre);
- toward a height `RIDE` (0.9 to 2.4 m) above the ground. It reads the ground `LOOK_AHEAD` (0.6 s of travel) ahead and is pulled toward that height at `CLIMB` (1.6 per second), so it rises before a rise and settles into hollows;
- up and down in a long undulation (`SWELL`, ±0.7 m over 5.5 s).

**Eddies.** `EDDY_RATE` is 0.2 a second. An eddy turns the mote once round over 1.1 to 1.7 s:

- in the upright plane along the wind (a loop, which always rises first);
- flat (a swirl, either way);
- or between the two (a helix).

The pull toward ride height lets go through the loop.

The tail is where the mote has been (`TAIL`, 1.6 to 2.6 s of path, sampled at 30 Hz), so the stroke is continuous and travels with the air.

## Sweeps

A sweep is a second kind of gust event, beside the eddy: a ribbon dives to skim just over the ground, then kicks up off it.

- **Phases** (`SWEEP_DESCEND`, `SWEEP_SKIM`, `SWEEP_LIFT`). It eases down over 0.8 to 1.2 s, skims for 1.0 to 1.8 s at 0.2 to 0.35 m over the ground (`SWEEP_HEIGHT`), travelling 1.35 times faster (`SWEEP_FAST`), then lifts off over 1.5 to 2.5 s. The lift tips its path up through `SWEEP_PITCH` (1.1 rad) in the upright plane along the wind, the same turn an eddy's loop uses, so it climbs several metres, then flattens and settles back to its ride.
- **Following the ground.** The skim reads the ground ahead like any ride, and holds its height at `SWEEP_PULL` both ways, so a rise lifts it clear. It is never allowed below the ground.
- **When.** One ribbon of a front's few, with chance `SWEEP_CHANCE` (0.7), takes a sweep 0.8 to 1.8 s after it joins the plate. A ribbon in the open can also take one of itself, at `SWEEP_RATE` (0.02 a second, well under `EDDY_RATE`). Never under trees (shade on the ground along its way), never while dying, and never with an eddy: one or the other. `--sweeps=` scales the rates; 0 turns them off.
- **What it kicks up.** `kicks()` lists each ribbon that is skimming (or within 0.7 m of the ground, or lifting off), with the ground point under its head, its velocity, `lift` (0 skimming to 1 at the strongest lift-off) and an eased `strength`. `air_at(p)` is the air it adds: within 1.5 m of its track (the head and 2 m behind) and near the ground, a drag along its way (0.8 of its velocity), an updraft in the lift (up to 3.5 m/s) and a gentle swirl round the head (0.8 m/s). The leaf litter (`scripts/wind_leaf_litter.gd`) and grass chaff read it through `atmosphere.wind_trails`: a leaf is dragged, hopped and tumbled, and tops out at about 2.5 m (chaff, lighter, at 3 m).

## When ribbons come

- **With gust fronts** (`carry_front`, `studies/gust_fronts.gd`). A front brings 2 to 4 ribbons. They are spread along its line, join it where it enters the plate (`JOIN`, 0.85 of the radius upwind of the middle) and ride at its speed. The stroke and the plants bowing under it are the same air.
- **Lone ribbons.** Between fronts, one drifts through every 5 to 11 s at the default air, more often in strong air.
- **Limits.** At most `CAPACITY` (8) at once. A ribbon fades out over 0.9 s once it passes the plate's edge.

## How it looks

`shaders/breeze_ribbon.gdshader`. Each ribbon is one brush stroke:

- **Shape.** A fine needle at the head, full just behind it, and a long run to nothing at the tail. Its width swells and eases along its length like a hand's pressure.
- **Paint.** A soft wash across the full width, with a brighter core set slightly to one side, as paint gathers on the brush's heel. Toward the tail the brush dries and its bristles part into streaks.
- **Light.** Lit by the sky and the sun, brighter looking toward the sun, and drawn with the scene's fog.
- **Size on screen.** At least 2 px and at most 22 px wide. Pixel size is measured by projecting a metre across the stroke onto the screen.

**Tuning** works in game and in films:

- `--ribbon-opacity=`
- `--ribbon-width=`
- `--ribbon-glow=` (default 2)
- `--ribbon-debug`: paints width (red), head to tail (green) and drawn pixels over 22 (blue).

For example: `./run-cozy-flow.command --ribbon-width=1.5 --ribbon-opacity=0.7`.

## Wake, livelier trees, defaults (second pass)

The user found single trees with "random gusts" on them, and still could not see the wind moving the plants.

- **The gusts on single trees** were ribbons flying at crown height through or behind a spruce. Only the pieces between its foliage clumps showed. Three changes fix it:
  - Ribbons now ride over woods. The trees' ground shade (`scripts/ground_shade.gd` `shade_at`, through `set_canopy`) lifts their ride by up to `CANOPY` (8 m). They climb fast (`CLIMB` 2.6/s), reading the ground 0 to 1.2 s ahead, and settle slowly beyond a wood (`SETTLE` 0.9/s).
  - Eddies are slow and wide: 2.6 to 3.6 s, 3 to 4 m across, at a rate of 0.07 a second.
  - The tail's grain thins the paint but never breaks it into dashes.
- **The wake.** Each ribbon's head is published as `zs_ribbon_0..7`, with its height above the ground in `zs_ribbon_lift_a/b`. `zs_ribbon_wake` (`shaders/reference_wind.gdshaderinc`) adds to every plant's breeze lean. The wake:
  - bows plants a little ahead of the head and most just behind it;
  - eases back down its trail over about 1.2 s;
  - reaches about 2 m to either side;
  - weakens as the ribbon rises from 3 m to 7 m above the ground.
- **Trees.** The breeze's bend on a tree is `give`, not `give^1.5`, so a 7 m spruce top answers about 1.8 times as far. This applies in `zs_breeze_offset_lean` and `conifer_wind`. `ZS_BREEZE_BASE` went from 0.10 to 0.16.
- **Defaults the user chose** (2026-10-03, "that's pretty sick"). Launch flags override each one:
  - `breeze_gain` 1.6 (`--breeze=`) scales `zs_breeze`;
  - `GustFronts.gain` 2.0 (`--fronts=`) scales each front's peak;
  - `wake_gain` 1.5 (`--wake=`) scales the wake.

## Findings while building

- **Vertex colour arrives sRGB-decoded in the shader.** Width and opacity passed in `COLOR` came out darkened (0.2 became about 0.03), so the strokes were faint and thin. They now ride `UV2`.
- **`2·d / (P[1][1]·viewport height)` underestimated metres per pixel by about 10×** at the diorama camera. This was the same estimate `wind_gust_trail.gdshader` uses for its `MIN_PIXELS` and `MAX_PIXELS`, so the gust streaks may be thinner than intended too (unverified). Projecting a metre to the screen fixed the ribbons.
- **Default brightness.** Lit like the scene, a white stroke matched the sunlit meadow's brightness and disappeared. `glow` 2 lifts it clear.

## Checks

- `tests/test_breeze_ribbons.gd` (headless) checks that a ribbon:
  - travels downwind;
  - rises over a 3 m hill;
  - keeps a continuous path (steps under 0.2 m) with a long tail (over 6 m) that rises and falls;
  - turns back on itself and lifts in an eddy;
  - comes in with a front where it enters the plate;
  - leaves at the edge;
  - sweeps low over flat ground, kicks only while low or lifting, lifts well clear, and stays above a hill;
  - never sweeps under trees, mid-eddy or while dying;
  - moves the same at 60 and 7 fps.
- `tests/test_weather_wind_trails.gd` asks for the old trails (`setup_wind_trails(probe, true)`).
- Films: `captures/wind-look/meadow-ribbons.mp4` and `meadow-ribbons-close.mp4`.

## Unverified

- How it reads to the user: painterly enough, too clean, too many or too few.
- At dusk and night, over water and snow, and on the plain at diorama distance.
- The dry-brush texture at a distance (it barely shows at 20 m).
- GPU cost of rebuilding the ImmediateMesh each frame. It holds at most 8 × ~80 points, and its CPU time is not measured.
