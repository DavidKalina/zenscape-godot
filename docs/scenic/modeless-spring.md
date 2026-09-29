# The land spring

One slice of the modeless scheme (`docs/scenic/hand-world.md`, "Verbs on the diorama"), behind `--modeless`. The land is a spring: press it, pull toward the bottom of the screen and let go, and a mountain springs up; pull the other way and let go, and it springs down into a basin for a lake. How far you pull decides how much.

**Status: built and probed headless only. Nothing here has been seen or felt on screen.** The numbers below are CPU frame gaps and heights; the look of the pucker, the tremble, the ring-down and the hand's pose are unverified.

## What you do

| Gesture | Result |
| --- | --- |
| Press on the land | The hand pinches the spot. Nothing moves yet. |
| Pull down | A pucker rises at the spot, wider and higher with the pull, trembling harder toward the cap. The hand keeps pinching and its hold plays faster. |
| Pull up | A dimple sinks at the spot (the hand switches to Press). |
| Let go, pulled far enough | Mountain (down) or basin (up) springs into place, overshoots, rings down, settles. |
| Let go, pulled very little, or back at the start | The land relaxes with a small wobble, nothing is kept, no undo step. |
| Press the rim, pull down, let go | The same spring from the edge: a ridge rises inward of it ("From the edge" below). |

The pull is the pointer's vertical travel from the press, as a share of `PULL_SCREEN` (0.32) of the viewport's height. Under `DEAD` (0.03) nothing shows; under `MIN_PULL` (0.12) letting go keeps nothing. The shown tension follows the pull with a quick smoothing (`TENSION_FOLLOW`), so the land never jumps.

## How it works (`scripts/land_spring.gd`)

- **Tension** writes only the points within `REACH` (5.2 m) of the press (gathered once at press) and asks for the editor's light refresh (`_refresh_light`), never stacking one on a slow one. Mountain tension is a `(1-t)²` pucker, `BULGE_HEIGHT` 0.1 to 0.85 m over 1.1 to 2.8 m. Basin tension is `DIMPLE` (40%) of the bowl the pull would dig.
- **The final shape is built once, at release.** A mountain uses the alpine form of `scripts/mountain_forms.gd` (`begin`, then `aim` to a spread of 3.4 to 7.2 m; its height follows the spread, so a full pull is about 10 m before weathering). A basin is a bowl: full depth inside 30% of the radius, easing to nothing at the rim, cut from the rim level (the mean ground over the outer ring) so it holds water even on a slope; radius 2.2 to 5 m, depth 0.4 to 1.1 m, never below -1.2 m. Both fade over the plate's last metres.
- **The spring** is a scale `x` on that shape, integrated as `x'' = -w²(x-1) - 2·z·w·x'` with `w` = 12.5 rad/s, `z` = 0.4 (about a 25% overshoot, a period near half a second), in 1/240 s substeps. Release kicks it with `KICK` and `x` starts at 0, so the release snaps. The tension's pucker fades out as `x` goes from 0 to 1, so the land is continuous through release. The spring can dip under 0 on its way down, which raises a small rim round a basin or sinks a mountain's foot.
- **Landing.** A mountain lands through the editor's `_land_mountain`: weathering and rock colour on a worker, emergence told, objects marked as hand work. A basin closes its step and runs the settle refresh. Water is not modelled; the basin is just ground that `pond_fetch`, `pond_surface` and the water brush treat as a hollow (the probe checks the first two).
- **One undo step.** `data.begin_stroke()` opens at press and `end_stroke()` closes at landing, so the tension, the spring and the weathering are one step. A relaxed spring restores the exact heights from press and adds no step. `NativeChunkEditor._history_step` calls `spring.land_now()` first, so an undo mid-spring lands it (a held pull is cancelled).
- **The hand** is driven with `god_hand.reach_gesture` ("pinch" pulling down, "press" pulling up, "" on release, whose Out clip is the follow-through) and `reach_point` (the spot on the land, riding the pucker). No new clips; polish comes later.

## The seam

`press(screen_pos)`, `pull(screen_pos, relative)`, `release(screen_pos)` match the modeless input's `land_pressed`, `land_dragged` and `land_released`. Connect them at merge and delete the block marked TEMPORARY at the end of `land_spring.gd` (`_unhandled_input`, `seam_enabled`, `_seam_pull`). `land_now()` and the `sprung(kind, size)` signal are the other public surface.

Wiring: `studies/fidelity.gd` creates it when `--modeless` is on (`land_spring`), and `NativeChunkEditor.spring` points at it. Without `--modeless` nothing exists and the brushes work as before.

## From the edge

The same spring, drawn from the rim: press the lip or the block's wall, pull down, let go (`docs/scenic/modeless.md`, "Edge spring"). `hand_reach` decides it from a downward rim drag and calls `edge_press(screen_pos, edge, hand_point)`, then the usual `pull` and `release`.

| Gesture | Result |
| --- | --- |
| Press the rim, pull down | A trough sags along the grabbed edge, a few metres in, deeper and longer with the pull. The hand pinches at the edge and dips with it. |
| Let go, pulled far enough | A ridge along that edge springs up through the trough, overshoots, rings down, settles and weathers. |
| Let go, pulled very little | The trough relaxes, nothing is kept, no undo step. |

- **The pull** is measured as on the land but clamped to down only (0..1 of the cap). `DEAD` and `MIN_PULL` are the same.
- **Where.** The grabbed rim point's larger coordinate picks the side; the crest line runs along that side `EDGE_INSET` in (5 m at a small pull to 6.5 m at the cap), its middle at the grab along the edge, clamped so the ridge's ends stay within `ALONG_ROOM` (11 m) of the plate's middle line.
- **Tension** is a trough on that crest line: depth `SAG_DEPTH` 0.08 to 0.6 m (with the usual tremble), half-width `SAG_WIDTH` 2.6 m, half-length the ridge's, `(1-u²)²` across and along, faded over the plate's last metres like every shape. Only the strip the trough and the ridge's carry can reach is gathered at the press.
- **The shape** is the `ridge` form of `scripts/mountain_forms.gd`, aimed along the edge: half-length `EDGE_SPREAD` 4 to 9 m, height `EDGE_HEIGHT` 3 to 8.5 m (set directly, not from the spread). It is built once at release; the trough carries into the spring and fades as the ridge takes over, exactly as the pucker does for a mountain.
- **Landing, undo and the hand** are the mountain's: `_land_mountain`, one undo step, `sprung("range", size)`. The hand's point is the grabbed edge (as `hand_reach` shows it, stood out from a wall) lowered by up to `EDGE_HAND_DIP` (0.35 m). Letting go clears only the spring's own poses ("pinch", "press"), so a shake that took the rim keeps its hand.
- Probe: `tools/probe_edge_spring.gd`. In the overview, a 0.67 pull from the near lip sags 0.40 m and raises a ridge 6.6 m high about 6 m in; the mean frame while pulling is about 3.4 ms (headless, CPU).

## Probe

`tools/probe_land_spring.gd`, on the real `studies/cozy_worlds.tscn`, headless (see its header for the command; run with and without `--modeless`). Last run: all checks pass. On the plain at (-2, 1), ground 0.23 m:

- A 0.45 pull raises the spot 5.0 m; a full pull 7.4 m. Peak scale 1.26, so a 7.35 m rest reaches 9.3 m before ringing down (two local peaks) and settling within 0.04 m.
- A 0.85 upward pull digs a basin 1.04 m below the ground and overshoots 0.28 m deeper. `pond_fetch` at -0.15 m finds a bounded hollow of about 3 m in all eight directions.
- Pulls of 0, 0.02 and 0.08, and a pull that returns to the start, leave the heights bit-identical and add no undo step.
- Every spring is one undo step, and one undo restores the heights exactly (small and big mountain, basin, and the seam's).
- Without `--modeless` there is no spring and a plain press still paints.
- CPU frame gaps (headless, dummy renderer): press 1.1 ms; longest frame while pulling 4.2 to 4.5 ms; release call under 1.2 ms; longest frame during the spring 4.7 to 8.8 ms.

## Open

- Which form: alpine always, for now (`MOUNTAIN_FORM`). Biome or the last chosen form could pick it.
- Tune by hand on a real display: the pull span, the tremble, `OMEGA`, `ZETA` and `KICK`, and how tall a full pull should be.
- The hand pulling back (a real reach-back before release) needs new clips; the hand only rides the pucker today.
- Mountains erode on landing but basins are not weathered, and water does not fill on its own: pour with the water ball.
