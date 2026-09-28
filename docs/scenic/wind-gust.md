# The wind tool

Branch `feature/wind-gust`, 2026-09-27. Press `6` while creating (or pick Wind in the palette) to take the wind tool. The user's idea: "Wind should be something that follows the same model, like you can add wind to the world so that the shaders kick in." It follows the handful model (`docs/scenic/handful.md`). You let the air go and the world responds, and before you let it go the ground shows what it will do.

A gust is a passing moment. It does not change the weather (but see "Lasting wind" below).

## The gesture

- **Blow.** Press and drag. The drag's direction sets the gust's heading, and its speed sets how hard it blows. The speed is read over the last `SWIPE_WINDOW` (0.12 s), in ground metres a second. `SWIPE_SPEED` 1.5 m/s blows the weakest gust (`MIN_POWER` 0.15) and 24 m/s blows a full one. Power rises quickly to follow a quickening swipe (`POWER_RISE` 18/s) and eases back slowly (`POWER_FALL` 2.5/s), so a flick that ends with a short pause keeps most of its power.
- **Promise.** While the hand drags, a lane on the ground shows where the air will go (`shaders/wind_gust_ground.gdshader`). It starts at the press, runs along the swipe, is as wide as the air will be, and is as long as the air will run. It ends in an arrow tip.
- **Send.** Release sends the gust as promised. `WindGust.release` sends exactly what `promise()` returned, and the mark draws that same dictionary.
- **Burst.** A press released without moving more than `STILL_DRAG` (0.6 m) is a burst: a ring that runs outward round the press. While the button is held still, the ring's promise grows from `BURST_REACH` 4 m to 12 m over `BURST_GATHER` (1.2 s).
- **Size and strength.** `[ ]` sets the lane's half width (`scripts/wind_brush.gd`, 1.5 to 5 m, default 3). Shift `[ ]` scales how hard a swipe blows (0.5 to 1.5).
- **No land changes.** A gust takes no undo step.

## The run

A lane runs between `REACH` 8 m (weakest) and 30 m (full). A swipe longer than that stretches the run to match. The lane stops `EDGE_MARGIN` (0.5 m) inside the plate, so on the 28 m Genesis plate a full gust is usually cut short by the edge.

- **Anticipation.** For `WIND_UP` (0.14 s) the air draws back, up to `PULL_BACK` (0.6 m) at full power, and builds to a quarter of its strength.
- **Launch and follow-through.** The head leaves at `LAUNCH` (1.3) times its cruising speed. `CRUISE` is 7 m/s for the weakest gust and 15 m/s for a full one; a burst's `BURST_CRUISE` is 8 to 12 m/s. The head then eases to a stop at the lane's end on a quadratic ease-out.
- **Build and fade.** The air reaches full strength over `BUILD` (18 %) of the run and fades over `FADE` (55 % to 100 %).
- **Settle.** For `SETTLE` (1.1 s) after the run, the ribbons thin and the leaves land.
- **Several at once.** Up to `MAX_GUSTS` (4) gusts fly together. A fifth sends the oldest straight to its fade.

## Travelling in the swipe's direction

Every travelling parcel of air used to ride the single global `zs_wind_direction`. A gust now carries its own heading:

- Three new globals, `zs_puff_heading_0..2`, hold a heading for each of the six parcels (parcel 2i in xy, 2i+1 in zw). A zero heading means "ride the global wind", so source parcels, stroke puffs and arrival puffs behave exactly as before.
- `zs_gust_pulse_at` (`shaders/reference_wind.gdshaderinc`) reads the heading. Every shader that already samples the pulse (fog parting, water, the grass and tree gust field, leaves, mist) therefore follows the swipe, and none of them needed editing.
- `zs_gust_push_at` returns the pulse as a direction. Each parcel pushes along its own heading, and the clap ring pushes outward. The water's `zs_water_gust` uses it where it used to push along the global wind.
- On the CPU, `studies/wind_puffs.gd` has matching `push_at`, plus `hold_slot`, `steer` and `let_go` for owned slots. Owned slots are never merged, replaced or retired by the source lifecycle. Leaf litter (`scripts/wind_leaf_litter.gd`) now reads `push_at`.

Two other options were rejected:

- Briefly swinging the global direction would turn every tree, the fog's drift and the clouds for a moment, and would bend parcels already in flight.
- A direction uniform in each consuming shader would have meant touching about 25 shaders.

The heading costs one branch and one vec4 read per parcel, inside one include.

## What it gives the shared air

- **A lane** holds one parcel slot and steers it along the lane every frame. Its weight goes from `PUFF` 0.35 to 0.8 with power, times the build and fade. The parcel is held `PARCEL_AGE` (8 m of air travel) past its birth, so its centre is exactly at the head.
- **A lane also steers one local gust** in the resident's `LocalWindField` (`emit_steered`, `steer`, `let_go`). The local gust rides `LOCAL_LIFT` (1.2 m) above the head, reaches `LOCAL_REACH` (1.6) half widths, and pushes along the true heading at `LOCAL` 8 to 22 m/s. This is what bends foliage, trees, conifers, meadow grass and water in the swipe's direction.
- **A burst** takes the clap ring (`zs_clap`, written through `studies/lightning.gd`'s `clap`) at `BURST_CLAP` 0.5 to 0.9, and four steered local gusts that push outward on the ring.
- **Tie-in.** `WindGust.wind_at(point)` returns the gusts' push at a plate point, in m/s, for anything that drifts on the air. Leaf litter already follows gusts, through `LocalWindField.sample_local` and `puffs.push_at`.

## How it looks

- **The mark** is the water ball's mark adapted to air. It is a pale two-tone lane (0.2 and 0.07 shade, lighter than the ball's) with a rim of air light, lit by sky and sun with a night floor.
  - The lane's back is half a 12-gon. Its tip is an arrow `TIP_FLARE` (1.25) times its width.
  - Chevrons of air light flow along the lane, `CHEVRON_SPACING` 1.6 m apart, faster for a harder gust (`CHEVRON_FLOW` 0.5 to 2.2 spacings a second). The mark breathes ±3.5 % at 0.55 Hz.
  - A burst's promise is a turning 12-gon ring, with rings of light drawing inward while it gathers.
  - The mark paints only near-level ground inside the gust's height range, so trunks and cliffs stay clean.
- **The passing air.** When the gust goes, a band of dappled shade and sheen rides at its head: sharp in front (`PAW_FRONT` 1.8 m), trailing behind (`PAW_TAIL` 4.5 m), with ripples running across it. This is what the bare painted plain shows, since it has no grass blades. The promise behind the head is used up over `USED_UP` (7 m).
- **Ribbons.** A lane has five strands of moving air (`STRANDS`) and a burst has ten spokes (`SPOKES`), in `shaders/wind_gust_trail.gdshader`. They are laid over the ground once, when the gust goes. Only the `TRAIL_LENGTH` (9 m) just behind the head shows, so they ride with it. Each strand lags the head by its own distance, so they overlap, and each lifts and curls where the air is.
- **Leaves and motes.** A press gathers `PRESS_MOTES` (14): 60 % leaves, the rest pale seed fluff, `MOTE_SIZE` 0.16 to 0.3 m so they read from 50 m. They swirl in round the press while the hand blows.
  - When the air reaches them they are carried on an underdamped spring (`CARRY` 38, `CARRY_DAMP` 7.5), so they overshoot and drop back.
  - They tumble, then coast and fall (`MOTE_FALL` 0.9 m/s) once the air has gone, and fade after landing.
  - At most `MOTES` (64) are shown.
- **Sound.** A looped `wind-bed.wav` on the Genesis bus, placed at the head: `VOICE_GAIN` 0.34 while a gust runs and `AIM_GAIN` 0.07 while the hand blows. Its pitch (`VOICE_PITCH` 0.85 to 1.18) follows power and head speed. There are two voices (`VOICES`).
- **Shell.** The Lantern shell recedes while the hand blows. The terrain brush circle hides while the mark shows.

## Lasting wind

This is an open option and is off by default. With `--gust-nudges`, `nudge` (0.25) of a lane's power turns the atmosphere's `direction_angle` toward the gust's heading and adds up to 0.05 to its `strength`. These are the steady breeze's dials, so the change is saved with the place, and living weather may move them on later. In the probe's "nudge" gesture, a 0.93-power gust turned the breeze 12.9° in one run and 37.3° in another; each run seeds a different breeze.

## What answers on the Genesis plain

- **True direction (local gust):**
  - hero trees and emerged trees (`reference_surface` `conifer_sway`, `sway_enabled`);
  - redwoods and layered trees;
  - meadow grass tufts (`grass_blades`);
  - the dense meadow (`shaders/dense_grass.gdshader`), which gained a small local-wind term on this branch. It is off on the plain unless `--beauty-grass` is given;
  - water (`inland_water` normals through `zs_water_gust`);
  - waterfall spray and falls;
  - leaf litter.
- **Pulse, now along the heading:**
  - fog parting (`reference_air_sample`, `living_fog`);
  - display mist;
  - the gust field that makes grass and trees heave and shiver;
  - falling leaves.
- **Does not answer:**
  - The painted ground itself is static. The decal's passing band stands in for it.
  - Clouds and peak clouds ignore gusts.
  - The resident's `CreatureWindBody` will be pushed if it is visible, because it samples the same `LocalWindField`.
- **Direction caveat.** In `reference_surface` and `dense_grass`, the pulse-driven lean still bends along the global breeze. The local gust adds the swipe's direction on top, and at a gust's strength it dominates.

## The probe

`tools/probe_wind_gust.gd`, headless, through the real input path. Numbers from 2026-09-27 on the Genesis plain (28 m plate, dummy renderer):

| gesture | power | reach | run | heading vs swipe | parcel across | parcel along | peak puff / local |
|---|---|---|---|---|---|---|---|
| fast, 6 m in 0.15 s | 0.93 | 20.2 m (edge) | 2.21 s | 0° | 0.0 m | -0.56 to 20.2 m | 0.77 / 21.1 m/s |
| slow, 4 m in 1.2 s | 0.22 | 12.8 m | 2.28 s | 0° | 0.0 m | -0.13 to 12.8 m | 0.45 / 11.1 m/s |
| burst, 0.8 s still | 0.86 | 10.1 m ring | 1.30 s | | | ring ≤ 10.07 m | clap 0.84 / 16.0 m/s |

- The breeze is seeded per run. Across two runs the lanes sat 20° to 175° off it, and the parcels and local gusts followed the swipe (0° error) every time.
- "Parcel across" is 0 because the parcel is placed on the lane's spine. The shaders' parcel shape and the local gust's sphere reach about 3.6 m and 4.8 m to each side, which is a little past a 3 m lane's edge, and fade there.

- Each sent gust equals its promise at release.
- A volley of five swipes 0.12 s apart took parcel slots 0 to 4, with no two gusts sharing a slot. All five were given back within 3 s. A second volley took slots 0 to 2 again. After every gesture: no slots held, no steered local gusts, and a clap weight of 0.
- **Cost.** WindGust's own work was 0.1 to 0.15 ms median per frame for one gust. With five gusts and 64 motes it was 0.3 to 0.4 ms median and 0.58 ms at worst. A release cost 0.9 to 2.2 ms: 0.7 to 1.4 ms sampling the ground grid, and 0.3 to 1.0 ms building ribbons. Main-loop frames were 8.3 ms median and at most 10 ms throughout. These are CPU numbers only. The dummy renderer does not draw.

## Unverified

The probe only checks CPU state. Nothing below has been seen rendered:

- how the lane mark, arrow tip, chevrons and ring read on bright and dark ground, by day and at night, and the flat-ground mask on slopes;
- the passing band (dappled shade, sheen, ripples), and whether it reads as air on the painted plain;
- the ribbons' window, width and flow, and the leaves' size, colours and tumble;
- trees, meadow grass and dense grass bending in the swipe's direction against the breeze's lean, and the water's ripples following the heading;
- the fog parting along the lane, and the clap ring on the fog and water;
- the dense-grass local-wind term, including its effect under the resident's own gusts;
- the wind voice's level against the Genesis beds.

Water answering the clap ring changed on this branch: the ring now pushes water outward, where it used to push along the global wind. Lightning downbursts are affected too.
