# The land spring

One slice of the modeless scheme (`docs/scenic/hand-world.md`, "Verbs on the diorama"), behind `--modeless`. The land is a spring: press it, pull toward the bottom of the screen and let go, and a mountain springs up; pull the other way and let go, and it springs down into a basin for a lake. How far you pull decides how much.

**Retired from the land (2026-09-28, `feature/modeless-clay`).** In the agreed scheme (`docs/scenic/modeless.md`, second pass) springs belong to the edge and the land is clay: a land press now goes to `scripts/land_clay.gd` (see "Land as clay" there), and nothing on the land drives the spring. The code stays, still created under `--modeless`, because the edge spring (`feature/modeless-edge-spring`) reuses its mountain form, its spring motion and the editor's `_land_mountain`. `tools/probe_land_spring.gd` now drives it directly through `press`, `pull` and `release` and checks the land signals leave it idle. The rest of this page describes the spring as built.

**Status: built and probed headless only. Nothing here has been seen or felt on screen.** The numbers below are CPU frame gaps and heights; the look of the pucker, the tremble, the ring-down and the hand's pose are unverified.

## What you do

| Gesture | Result |
| --- | --- |
| Press on the land | The hand pinches the spot. Nothing moves yet. |
| Pull down | A pucker rises at the spot, wider and higher with the pull, trembling harder toward the cap. The hand keeps pinching and its hold plays faster. |
| Pull up | A dimple sinks at the spot (the hand switches to Press). |
| Let go, pulled far enough | Mountain (down) or basin (up) springs into place, overshoots, rings down, settles. |
| Let go, pulled very little, or back at the start | The land relaxes with a small wobble, nothing is kept, no undo step. |

The pull is the pointer's vertical travel from the press, as a share of `PULL_SCREEN` (0.32) of the viewport's height. Under `DEAD` (0.03) nothing shows; under `MIN_PULL` (0.12) letting go keeps nothing. The shown tension follows the pull with a quick smoothing (`TENSION_FOLLOW`), so the land never jumps.

## How it works (`scripts/land_spring.gd`)

- **Tension** writes only the points within `REACH` (5.2 m) of the press (gathered once at press) and asks for the editor's light refresh (`_refresh_light`), never stacking one on a slow one. Mountain tension is a `(1-t)²` pucker, `BULGE_HEIGHT` 0.1 to 0.85 m over 1.1 to 2.8 m. Basin tension is `DIMPLE` (40%) of the bowl the pull would dig.
- **The final shape is built once, at release.** A mountain uses the alpine form of `scripts/mountain_forms.gd` (`begin`, then `aim` to a spread of 3.4 to 7.2 m; its height follows the spread, so a full pull is about 10 m before weathering). A basin is a bowl: full depth inside 30% of the radius, easing to nothing at the rim, cut from the rim level (the mean ground over the outer ring) so it holds water even on a slope; radius 2.2 to 5 m, depth 0.4 to 1.1 m, never below -1.2 m. Both fade over the plate's last metres.
- **The spring** is a scale `x` on that shape, integrated as `x'' = -w²(x-1) - 2·z·w·x'` with `w` = 12.5 rad/s, `z` = 0.4 (about a 25% overshoot, a period near half a second), in 1/240 s substeps. Release kicks it with `KICK` and `x` starts at 0, so the release snaps. The tension's pucker fades out as `x` goes from 0 to 1, so the land is continuous through release. The spring can dip under 0 on its way down, which raises a small rim round a basin or sinks a mountain's foot.
- **Landing.** A mountain lands through the editor's `_land_mountain`: weathering and rock colour on a worker, emergence told, objects marked as hand work. A basin closes its step and runs the settle refresh. Water is not modelled; the basin is just ground that `pond_fetch`, `pond_surface` and the water brush treat as a hollow (the probe checks the first two).
- **One undo step.** `data.begin_stroke()` opens at press and `end_stroke()` closes at landing, so the tension, the spring and the weathering are one step. A relaxed spring restores the exact heights from press and adds no step. `NativeChunkEditor._history_step` calls `spring.land_now()` first, so an undo mid-spring lands it (a held pull is cancelled).
- **The hand** is driven with `god_hand.reach_gesture` ("pinch" pulling down, "press" pulling up, "" on release, whose Out clip is the follow-through) and `reach_point` (the spot on the land, riding the pucker). No new clips; polish comes later.

## The seam

`press(screen_pos)`, `pull(screen_pos, relative)` and `release(screen_pos)` take a screen press, its drag and its release. They were connected to the modeless input's `land_pressed`, `land_dragged` and `land_released` until land as clay took those; now nothing in the game calls them, and the edge spring will drive them (or the shapes under them) from the rim. `land_now()` and the `sprung(kind, size)` signal are the other public surface.

Wiring: `studies/fidelity.gd` creates it when `--modeless` is on (`land_spring`), and `NativeChunkEditor.spring` points at it, so an undo lands a spring in progress. Without `--modeless` nothing exists and the brushes work as before.

## The edge

The rim pulled down is the edge spring (`scripts/edge_spring.gd`, `docs/scenic/modeless.md`, "Edge rework"): the block dips as a unit while held, and on release a random multi-peak range springs up on this spring, built into the editor's mountain from the alpine form and a rolling dome, and a lifted rim set down slowly sinks this basin at a random spot. It extends this file for the spring, the landing and the basin. The agreed scheme retires the land press's spring (the clay slice); the edge keeps using this code.

## Pull feel (experiment)

Branch `experiment/pull-spring-feel`. The complaint was that you couldn't tell you were pulling the world down: it didn't feel like loading a spring. The old camera lean followed 70 % of the block's drop in the same frame (`LEAN_FOLLOW`), so on screen the block hardly moved, and the void gives no fixed reference. The fix is to move the world first and the camera afterwards, and to show the load on the block. It is chosen with `--pull-cam` (`scripts/modeless_input.gd` `pull_cam`):

| Variant | What it does |
| --- | --- |
| `a` | The camera holds still while the block drops. It follows only late in a deep pull, on a slow spring. At the release it waits a beat, then catches up on its own softer spring. The block squashes and stretches, the plants trail it and the earth strains. |
| `b` (default) | `a`, plus a low, side-on swing at the press (about 13° above the horizon, only from a higher view, never touching the yaw). The swing eases back to your view once the range has settled. |
| `c` | `b`, but the camera stays low after the release: the swing becomes your own view. |
| `old` | The lean from before, exactly: down, in and lower with the block, with no squash, trail or strain. |

The beats:

- **Press.** The swing runs on two chained critically damped springs (`scripts/camera_rig.gd` `PULL_SIDE` 1.34 rad, `PULL_SIDE_W` 28/s, 95 % in about 0.28 s). The yaw stays the player's, and the eye keeps `CLEARANCE` over the ground.
- **Pull.** The camera holds. Past the cap (`PULL_LATE_FROM`, dip 1) it follows `PULL_LATE_SHARE` (45 %) of the further drop on a slow spring (`PULL_LATE_W` 2.6/s). The block's snapshot face squashes about its own floor (`scripts/diorama_flip.gd` `SQUASH_MOST`, `STRETCH_MOST`, `SPREAD`, `SQUASH_LEAD`). This is only a visual transform on the flip's copy; the real terrain never moves. Plants trail the block's vertical speed on a spring (`scripts/pull_feel.gd` `HEAVE_*`), published as the global `zs_heave` and read in `zs_blow_bend` and `zs_conifer_offset`. A strain loop plays louder and higher with the tension (`STRAIN_*`, baked by `tools/generate_nature_audio.py --strain`).
- **Release.** The block shoots up past rest, stretching, and recoils on a critically damped spring (`RECOIL_W` 40/s). It is handed back near rest (`RECOIL_REST`), and the range springs as before (`w` 12.5, `z` 0.4, unchanged). The camera holds `PULL_HOLD` (0.12 s), then catches up on `PULL_CATCH_W` 7/s at `PULL_CATCH_ZETA` 0.5, pushed up over `PULL_CATCH_PUSH` (0.1 s, a sine-squared push, so no acceleration step).
- **Settle.** After `PULL_RETURN_AFTER` (0.9 s) the swing eases back on `PULL_RETURN_W` (95 % in about 1.7 s), or under `c` it is folded into the player's view.

The sky's cloud (`scripts/sky_cloud.gd`) is now left out of the flip's snapshot (`LEAVE_OUT`), in every variant. Before this it was copied onto the snapshot and rode the dip and the flip, although its own header says it floats in the room. The sky and sun were already fixed. Mist and loose leaves are particles, which the snapshot never copies, so they already stay put. They get no lag of their own.

**Headless only (dummy renderer). Nothing here has been seen, heard or felt.** A throwaway probe drove a real pull on `studies/cozy_worlds.tscn` at 60 Hz, from the overview (polar 0.82). With a full pull (288 px) under `b`:

- The swing is 0.52 rad (30°). The camera pivot does not move while held.
- The block's middle goes down 1.80 m (tilt included) and squashes to 0.938.
- At the release it stretches to 1.052 at 83 ms, peaks 0.11 m above rest at 117 ms and is handed back at 183 ms. `old` hands back at 100 ms, so the range starts about 85 ms later.
- The range's scale peaks at 417 ms (333 ms under `old`). The camera rises 0.19 m, peaking at 333 ms, 217 ms after the block's peak.
- The plants stretch to +0.12 while dropping, shrink to -0.09 while rising and whip back to +0.03.
- The worst pivot acceleration is 38 m/s² (290 m/s² under `old`). The worst polar acceleration is 50 rad/s², from the swing.

A deep pull held the camera until the cap, then followed it 0.11 m down, and the block stretched to 1.070. Variant `a` is `b` without the swing. Variant `c` ended at polar 1.34, and the next pull did not swing.

Unverified on screen: whether the 30° swing in 0.28 s reads as a helpful reframe or a lurch; whether the squash, stretch and trail read at 40 m; whether the strain sounds like earth and roots or like noise; whether the extra 85 ms before the range springs feels like a follow-through or like lag; whether the camera's 0.19 m catch reads at all. The trail is a shader edit (a new global uniform, no new varyings), and a headless check misses GPU limits, so compile it windowed once.

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
