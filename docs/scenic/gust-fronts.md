# Gust fronts: the breeze's events

Branch `feature/wind-fronts`, 2026-10-03. The user said the wind "still feels cheap" without being able to say why.

## Why it read cheap

- **Nothing happened.** In 10 s films at the default air (`captures/wind-look/meadow.mp4`, `plain.mp4`), the whole frame's motion stayed within ±8 % of its mean. Local motion rose and fell over several seconds, never hitting or settling.
- **Fizz, not waves.** A one-second difference map of the meadow showed each flower head jiggling on its own, evenly across the field. The meadow waves (`zs_wave_crest_at`) did not read as a band crossing the field.
- **No hit.** The gust field is value noise drifting downwind, so a gust rises as gently as it falls. Plants have no overshoot or recovery. Only the wind tool's gusts (`zs_blow_swing`) had those.
- **The Electron original** had the same smooth field and sine sway. Its events came from writing: every word sent a puff, and thunder sent a downburst ring. The port kept the field but nothing replaced the events.

## What a front is

`studies/gust_fronts.gd`, owned by the atmosphere and aged on its wind clock.

- **When.** The first comes 4 to 10 s after a world opens. After that, one every `GAP` (12 to 30 s) at the default air, sooner in strong air (`gap_for`: about half as long in a gale). At most `SLOTS` (2) run at once. A front is born when it was due, not at the frame's end, so it is the same at any frame rate.
- **Where.** A front is born `LEAD_IN` (6 m) upwind of the plate's edge, travelling with the wind. The plate's middle and radius come from the terrain's world bounds (`Atmosphere.update_ground_bounds`). It runs at `SPEED` 5 to 7.5 m/s, plus 3 m/s per unit of air. Its half width is 0.7 to 1.6 of the plate's radius, off centre by up to half the radius: some fronts cross a side of the plate, some all of it.
- **Its line** wanders `RAGGED` (±4 m) along the wind across its width, so it arrives along a curve.
- **Its strength** is patchy across its width: 0.35 to 1 of its peak, in cells about 8 m wide. Some fronts come even.
- **Peak lean** is power (0.55 to 1) × (0.3 + 0.3 × breeze air). This is in `zs_blow_at`'s units, where 1 lays a small plant over by about 45°. At the default air that is 0.25 to 0.46 on top of the breeze.
- **At a point** (`push`, `zs_front_push`), the front:
  - starts to stir 0.35 s before it arrives and is full 0.25 s after;
  - overshoots by up to `OVERSHOOT` (40 %), ringing at 6 rad/s and dying at 2.4/s;
  - holds `HOLD` (0.5 s);
  - lets go over `RELEASE` (2.2 s, e-folding), so it stays above 30 % for about 3 s.

  A plant's tip reads the front its breeze lag behind its root, so tall plants follow late.
- **The quiet before** (`lull`). Over the `LULL_LEAD` (4 s) before a front reaches the plate's middle, `zs_breeze` eases to `LULL` (0.75; 0.55 at first, softened so the breeze never feels off) of itself, and it is back `RECOVER` (3 s) after. The published breeze fell from 0.50 to 0.24 in the film.

## Where it is wired

- **Shaders.** `zs_front_0_a/b` and `zs_front_1_a/b` are registered in `project.godot` and declared in `reference_globals`. `zs_front_at` (`shaders/reference_wind.gdshaderinc`) is added to the lean in `zs_breeze_lean_wave`. Every plant that takes the breeze takes the fronts with no shader edits: tufts, flowers, shrubs, reeds, ferns, broadleaf crowns and trunks, layered trees, conifers and dense grass. Grass pales (`bow`) and tips flutter (`gust`) with the extra lean.
  - Locals in the front functions are prefixed `fr_`, because user shaders declare `seed` and `rise` uniforms (see the songbirds handoff on name clashes).
- **Creatures.** A front raises a `gust` disturbance with `"steady": true`. Readers (`life_notice.gd`, `songbirds.gd` `_gust_reach`) time a steady head at an even pace (`from + span·u`) and keep its strength the whole way. Strength is power × `NOTICE` (0.25): fish dart, gulls lift, and fireflies scatter. Deer do not alarm, and songbirds do not flush: a sent gust still does both.
- **CPU mirror.** `GustFronts.front_lean` and `lean_at` mirror the shader, for future CPU readers (leaf litter, pollen, songbird leaf drift).

## Checks

- `tests/test_gust_fronts.gd` (headless) checks:
  - the hit-overshoot-release shape;
  - the schedule (default and gale gaps, 18 to 60 fronts in ten minutes, never more than two);
  - travel: upwind first, its own pace, nothing outside its width, patchy in most fronts, ragged lines;
  - the lull;
  - pause holding and 60 / 5 fps agreeing;
  - the shader hooks, globals and `fr_` prefixes.
- `tests/test_breeze.gd` seeds both atmospheres' fronts for its frame-rate check.
- `tools/probe_songbirds.gd` passes 17/17 again. It had failed 2 when fronts flushed the flock before its poke.
- `tools/film_breeze.gd` takes `--front-at=S` (send one S s into the film) and `--no-fronts`.

## Results (2026-10-03)

The films were 16 s at 30 fps with `--front-at=2`, in `captures/wind-look/meadow-fronts.mp4` and `plain-fronts.mp4`. The shaders compiled on Metal with no errors in either run's log.

- **Meadow, daisy patch motion.** The lull went to 1.7 to 1.8, the front to 4.2 to 4.4, then it settled over about 5 s. The breeze alone sat flat at 3.5 to 5.7.
- **Meadow, screen columns.** Motion peaked one after another, at 5.0, 6.0 and 6.5 s: the front crossing.
- **Plain, oak crown.** It spiked to 0.76, then went quiet at 0.13 to 0.17. Before it never dropped below 0.27. The whole wooded plain at 23 m changed little.

## Unverified

- How it looks to the user. The numbers above measure motion, not how it reads.
- Whether trees should take more of a front. Crowns are damped by `zs_blow_give^1.5`, and the plain at diorama distance barely shows the front.
- Water, fog, falling leaves and sound do not answer fronts yet (plan steps 2 and 3). The terrain wind map is step 4.
- GPU cost: two fronts add two noise calls each per foliage vertex while a front runs. Not measured.
