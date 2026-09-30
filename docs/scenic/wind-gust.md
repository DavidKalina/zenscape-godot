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
- **Settle.** For `SETTLE` (2.0 s) after the run, the ribbons thin, the leaves land and foliage finishes swaying back.
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
- **A lane also steers one local gust** in the resident's `LocalWindField` (`emit_steered`, `steer`, `let_go`). The local gust rides `LOCAL_LIFT` (1.2 m) above the head, reaches `LOCAL_REACH` (1.6) half widths, and pushes along the true heading at `LOCAL` 8 to 22 m/s. Steered gusts stay on the CPU, for leaf litter and the resident's body, and are not published to shaders. Foliage and water take the wind tool's own air instead (see "Foliage" below), so nothing is pushed twice.
- **A burst** takes the clap ring (`zs_clap`, written through `studies/lightning.gd`'s `clap`) at `BURST_CLAP` 0.5 to 0.9, and four steered local gusts that push outward on the ring.
- **Tie-in.** `WindGust.wind_at(point)` returns the gusts' push at a plate point, in m/s, for anything that drifts on the air. Leaf litter already follows gusts, through `LocalWindField.sample_local` and `puffs.push_at`.

## How it looks

**Off by default since 2026-09-29.** The user found the lane, arrow, chevrons and ring too hand-holding, so they are drawn only with `--show-promise` (`WindGust.show_promise`). Without it, the hand's air leaning the foliage while you drag or hold is the only preview. A sent gust shows its passing band of shade at the head, but not the promise being used up behind it. `promise()` and `release()` are unchanged, so the gust still goes exactly where the hidden mark would have promised.

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

## Foliage

The first version bent foliage only through the steered local gust. Each asset's small sway constant scaled that gust, so a broadleaf crown moved about 0.14 m and a conifer's top about 0.2 m. The burst's clap ring only swelled the lean along the global breeze. The user found foliage barely reacted.

Foliage now reads its own globals, `zs_blow_*`, published by `WindGust._publish_blow`: four lanes (`zs_blow_0..3_a/b/c`), the burst (`zs_burst_a/b`) and the blowing hand (`zs_aim_a/b`). `zs_blow_at` in `shaders/reference_wind.gdshaderinc` turns them into a horizontal lean at any point. The lean is 0 when calm and about 1 at a full gust's head, capped at `ZS_BLOW_MAX` 1.4. It comes with a shiver (0 to 1).

- **Along the gust's own way.** A lane leans foliage along its heading, with a little crosswise turbulence (±15 %) riding the front. A burst leans foliage straight out from its centre. So the whole motion follows the swipe.
- **Follow-through.** A shader has no memory, so each point works out when the head passed it. The head's ease-out, start + travel × (1 − (1 − u)²), inverts exactly. From that moment the point plays a damped swing, `zs_blow_swing`: it rises over the 0.3 s before the head arrives and peaks as the head passes. It then swings back past rest by about 30 % at 0.57 s (`ZS_BLOW_RING` 5.5 rad/s, `ZS_BLOW_DAMP` 2.2 /s) and sways out over about 1.5 s. The shiver, a quick flutter across the lean, rises with the front and dies over about 1 s.
- **Anticipation.** During the gust's 0.14 s wind-up, foliage near the lane's start leans back toward the hand, up to 0.25.
- **Strength.** The lean at the head is `BLOW_LEAN` 0.45 to 1.0 with power, and a burst's is `BURST_LEAN` 0.55 to 1.15. Each is scaled by the run's build and fade at the moment the head passed. A settling gust keeps its lean until its sway has died away (`_linger`).
- **The blowing hand.** The air moves before release:
  - **Holding still:** pressure builds round the press, from `HOLD_LEAN` 0.2 to 0.8 over `HOLD_BUILD` 1.6 s. It leans foliage out from the press, swirling round it at about 30°, with a tremble, out to the ring the burst will reach.
  - **Dragging:** the forming lane parts to either side and leans along the drag, most near the hand. The strength is `DRAG_LEAN` 0.35 to 0.75 with the swipe's power, building over the first `DRAG_BUILD` 3 m.
  - **Handover:** after release the hand's air dies away over `HAND_FADE` (0.4 s for a lane, 0.6 s for a burst) while the gust takes over.
- **How plants bend.** `zs_blow_bend` bends a plant above its bend point as a cantilever: tip offset = lean × `zs_blow_give(height)` × height × (h / height)², keeping its length. `zs_blow_give` is 1.0 for plants up to 0.5 m and 0.3 for plants 3 m and taller. Small plants lie over; tall trees lean.
  - Full lean on a 0.35 m tuft moves its tip 0.35 m, about 45°.
  - It moves a broadleaf crown's top (2.4 m, bending from 0.4 m) 0.8 m.
  - It moves a 7 m conifer's top 2.1 m.
- **Where it is wired:**
  - `reference_surface` sway: grass tufts, flowers, shrubs, reeds, bank grass, fern, broadleaf canopies;
  - `conifer_wind.gdshaderinc`: hero spruces, emerged trunk and canopy, birch, willow, juniper, redwood, joshua. It bends trunk and crown together, with a shiver in the rims;
  - `layered_canopy_surface` and `layered_tree_wood`: layered trees;
  - `dense_grass`: laid over in a travelling front;
  - `reference_leaves`: falling leaves drift with the lean;
  - `zs_water_gust`: water ripples, at 9 m/s per unit of lean.
- **Trunks follow crowns.** A trunk that does not sway (`broadleaf:mesh-11`, the layered trunks) would stay put while its crown bent. It now bends with its crown's shape (`blow_enabled`, `blow_shape`), paired in `scripts/garden_view.gd` and `scripts/layered_tree.gd`, so a strong gust never pulls them apart.
- **The steady breeze is unchanged.** Foliage's lean along the global wind now reads `zs_breeze_field`, which is `zs_gust_field` without the wind tool's parcels and without the clap ring while a burst owns it. With no wind-tool air about, the two are identical, and `zs_blow_at` returns 0 with a few comparisons.
- **CPU mirror.** `WindGust.blow_at` is `zs_blow_at` in GDScript, fed from the same published values. The probe reads foliage through it. Keep it in step with the shader.

## Lasting wind

This is an open option and is off by default. With `--gust-nudges`, `nudge` (0.25) of a lane's power turns the atmosphere's `direction_angle` toward the gust's heading and adds up to 0.05 to its `strength`. These are the steady breeze's dials, so the change is saved with the place, and living weather may move them on later. In the probe's "nudge" gesture, a 0.93-power gust turned the breeze 12.9° in one run and 37.3° in another; each run seeds a different breeze.

## What answers on the Genesis plain

- **Bends along the gust's own way (`zs_blow_at`):** every tree, shrub, grass, flower, reed and fern kind listed under "Foliage"; falling leaves; water.
- **Carried on the CPU:** leaf litter, through the steered local gust and `puffs.push_at`.
- **Pulse, along the heading:** fog parting (`reference_air_sample`, `living_fog`) and display mist.
- **Life, as the head reaches it:** gulls, fish, fireflies, deer, a standing heron and, in a hard gust, frogs. `release` raises a `gust` disturbance carrying the front's timing (`_disturb`, `scripts/disturbance.gd`); see `docs/scenic/life.md`, "Noticing".
- **Does not answer:**
  - The painted ground itself is static. The decal's passing band stands in for it.
  - Clouds and peak clouds ignore gusts.
  - The resident's `CreatureWindBody` will be pushed if it is visible, because it samples the same `LocalWindField`.

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
- **Cost.** WindGust's own work, including publishing `zs_blow_*`, was 0.1 to 0.2 ms median per frame for one gust. With five gusts and 64 motes it was 0.34 to 0.59 ms median across four runs, with p95 at most 0.91 ms. A later volley of three ran 0.25 to 0.47 ms median. The first gust of a session can cost one frame about 7 ms while its nodes and materials are made (seen once, in a cold run of the volley alone). A release cost 0.9 to 2.2 ms: 0.7 to 1.4 ms sampling the ground grid, and 0.3 to 1.0 ms building ribbons. Main-loop frames were 8.3 ms median and at most 10 ms throughout. These are CPU numbers only. The dummy renderer does not draw.

### Foliage, before and after

Foliage figures come from the `FOLIAGE` lines: the tip movement of a broadleaf crown, a 7 m conifer and a 0.35 m tuft. "Old" is the first wind tool (the steered local gust through each asset's sway constant). "Lean" is along the way the air goes, so a negative value is the swing back.

| gesture, point | lean peak | swings back | still moving until | crown / conifer / tuft, new | old |
|---|---|---|---|---|---|
| hold 1.5 s, 1.5 m out | 0.76 (18° swirl) | | while held | 0.64 / 1.67 / 0.28 m | 0 |
| hold 1.5 s, 4 m out | 0.80 (30° swirl) | | while held | 0.74 / 1.95 / 0.32 m | 0 |
| burst (power 1), 3 m out | 1.14 at 0.32 s | -0.30 (26 %) | 1.64 s | 0.93 / 2.44 / 0.41 m | 0.09 / 0.14 / 0.06 m |
| burst, 6 m out | 1.09 at 0.57 s | -0.35 (33 %) | 1.9 s | 0.87 / 2.28 / 0.38 m | 0.02 / 0.02 / 0.01 m |
| burst, 14 m out (past the ring) | 0 | | | 0 | 0 |
| swipe (0.92), 10 m along | 0.90 at 0.97 s, 2.7° off heading | -0.29 (33 %) | 2.27 s | 0.73 / 1.90 / 0.32 m | 0.14 / 0.22 / 0.10 m |
| swipe, 16 m along | 0.90 at 1.49 s | -0.29 | 2.8 s | 0.73 / 1.91 / 0.32 m | 0.14 / 0.22 / 0.10 m |
| swipe, 6 m to the side (outside) | 0 | | | 0 | 0 |
| slow drag (0.28), 1.2 m left and right of the line | 0.20 / 0.26 outward | | while dragging | 0.28 / 0.74 / 0.12 m | 0 |

- **Hold build-up.** The pressure grows the longer the hand holds: 1.5 m out, the lean along the outward way is 0.15, 0.37 and 0.47 at 0, 0.5 and 1.0 s. Swirl and tremble make it waver around that.
- **Size of the change.** The new tip movement is 5 to 10 times the old in a lane's path, and 10 to 90 times the old for a burst.

## Unverified

The probe only checks CPU state. Nothing below has been seen rendered:

- how the lane mark, arrow tip, chevrons and ring read on bright and dark ground, by day and at night, and the flat-ground mask on slopes;
- the passing band (dappled shade, sheen, ripples), and whether it reads as air on the painted plain;
- the ribbons' window, width and flow, and the leaves' size, colours and tumble;
- how the new foliage bend reads on screen: its size (a 7 m conifer's top moving 2 m), the swing back, the shiver, the swirl while holding and the parting while dragging;
- whether any crown and trunk still part: the broadleaf and layered trunks now follow their crowns, but the other pairs are conifer-swayed, and no pair has been looked at;
- whether 0.35 m blades lying over by 45° look right, and the dense meadow front;
- water ripples driven by the lean;
- shader cost: `zs_blow_at` loops over four lanes for every foliage vertex. It returns early when a lane is idle, and with no wind-tool air it is a few comparisons, but the GPU cost with five gusts is unmeasured, because headless has no GPU timing;
- the fog parting along the lane, and the clap ring on the fog and water;
- the dense-grass local-wind term (the resident's gusts only, now);
- the wind voice's level against the Genesis beds.

Water answering the clap ring changed on this branch: the ring now pushes water outward, where it used to push along the global wind. Lightning downbursts are affected too.
