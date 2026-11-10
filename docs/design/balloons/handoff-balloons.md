# Hot air balloons: handoff (prototype round, 2026-11-10)

Balloons drift over the endless land as a rare sighting. Try it:
`.\run-endless-flight.cmd --balloons-now` puts a low group of three 320 to
580 m ahead of the start. `--balloons=0` turns them off for an A/B.

## What was built

- **Model**: `art/blender/balloon/balloon_build.py` writes
  `assets/models/balloon/balloon.glb`: a 16-gore envelope with an open mouth,
  load ropes, a burner frame with two burners, a wicker basket with a leather
  rim, five sandbags and a trailing line, the flame, and a far version (364
  triangles; the near one is 8,400). No textures: the cloth, wicker and flame
  are painted in `shaders/balloon_canvas.gdshader`, `balloon_gear.gdshader`
  and `balloon_flame.gdshader`. One material serves every balloon; the
  pattern (gore stripes, hoops, spiral, zigzag belt, salvaged panels) and its
  three tones are instance uniforms, five patterns by five palettes.
- **Behaviour**: `scripts/endless/endless_balloons.gd`, a pool of three
  balloons. One group of one to three at a time (45/35/20 %), the first
  always low. They drift with the clouds (`look.wind_direction` at the
  clouds' 3.2 m/s), rise and sink gently, climb over the land, trees and
  stone under and ahead of them, and are taken away out of sight. The plane's
  wash rocks the balloon, swings the basket and shudders and dents the cloth.
  The burner fires every 7 to 19 s and whenever the balloon climbs.
- **Sound**: the burner's roar is an `AudioStreamPlayer3D` at each balloon on
  the Ambience bus, heard within 340 m. The clip is made in code at setup
  (two seconds of filtered noise, looped); there is no recorded clip.
- **Near-miss**: a pass within 10 m of the cloth or basket (past the wing
  tip) scores as a graze through `NearMiss.shot_pass`, the hook the pirate
  ship's balls use. It shows on the existing HUD as a stone graze. Flying
  through the cloth scores nothing and only shakes it.
- **Collision**: none. The plane flies through cloth, ropes and basket. The
  game's obstacles crash or scrape the plane, and a drifting collider on
  layer 1 would do that too, so they were left open. No force acts on the
  plane.

## Numbers

| | |
|---|---|
| Size | envelope 17 m across, 24.5 m crown to skids (the model times `SIZE` 1.3) |
| Low band | basket floor 11 to 19 m over the highest ground, tree or stone near it; never under 9 m |
| Middle, high bands | 30 to 75 m, 90 to 220 m |
| Appears | 1300 to 1800 m ahead, within 0.9 rad of the heading, dithered in over 3 s |
| Goes | past 2400 m, or past 900 m and behind the view for 20 s |
| Wait between sightings | `GAP` 110 s mean (55 to 165), first one 25 to 70 s after the start |

Flags: `--balloons=0` or `--no-balloons` (off), `--balloons=N` (most in a
group, 1 to 3), `--balloon-gap=S` (mean wait), `--balloons-now`,
`--balloon-scale=X`. A world profile can turn the `balloons` layer off.

## Proof

- `python tools/smoke.py studies/endless_flight.tscn -- --balloons-now`: PASS, 0 errors.
- Driven check (`scratch/balloon_check.gd`, not committed), medium weight,
  the plane steered through the stick with a wobble: three balloons near the
  start; a pass under the low one and a pass beside the second both score
  and set them rocking; they settle; drift is 3.2 m/s along the clouds' way;
  the burner fires; the group is taken away and a new one appears over
  1300 m off. Seeds 1 to 4 without Boost and seeds 1 to 4 with it: every
  balloon check passed on every seed that reached it, with two exceptions.
  On seed 4 the pass under went through the middle of a gap over 20 m tall
  and was too far from the basket to score. On seed 1 no new group came
  while the driver's plane sat facing the Peak (groups never appear over the
  massif). The driver's own pilot touched down on the land late in several
  runs (it steers crudely near the ground), which fails that run's last
  line and is not a balloon fault; one run (seed 2, no Boost, last sweep)
  died at 45 s without output and was not rerun. Least basket clearance
  over land, trees and stone in the last sweep: 8.2 m near the start group,
  5.6 m for a group that appeared far off. Least plane clearance on the
  passes under: 6.2 m.
- Stills in `scratch/shots/` (git-ignored, on this machine):
  `balloon_noon_far.png`, `balloon_noon_skim.png`, `balloon_low_skim.png`
  (17.3 h), `balloon_noon_close.png`, `balloon_noon_basket.png`,
  `balloon_noon_burn_under.png`, `balloon_dusk_burn.png` (18.6 h),
  `balloon_noon_film_sheet.png` (the shudder and rock).

## Cost

- The manager's step with the group near: 0.03 ms median in a rendered run
  (1440x900, this PC). That run still took all of a balloon's ground samples
  in one frame a second, 0.5 ms; they are now spread, three every 0.25 s, and
  the spread version was not timed in a window.
- A group appearing asks the ground 30 times a balloon in one frame.
- Frame time, rendered, the group in view, in alternating 90-frame blocks
  with the balloons drawn and stepped, then hidden: 7.5/7.2/7.0/6.7 ms with
  against 7.2/6.9/6.8/6.2 ms without, so 0.2 to 0.5 ms a frame for three
  balloons at 80 to 230 m, shadows on. One run; the blocks follow each other
  along the flight, so the views differ a little. Not repeated.

## Shared files touched

`studies/endless_flight.gd` only: a preload, a `balloons` var, six lines of
setup after the birds, and a step with a `FrameLog.mark(&"balloons")` after
the fish. `near_miss.gd` and the sky and cloud shaders are untouched.

## Not verified, and known gaps

- Nobody has flown it by hand. The roar has not been listened to.
- A balloon keeps clear of what `plane_ground` knows (land, trees, arches,
  rocks, halls) and never appears on the Peak's massif, but it can drift
  onto the massif later; it climbs over it as over any land. The Peak's
  towers and the pirate ship are not asked.
- A tree's spire can still slip between ground samples: the driven runs'
  least basket clearance was 5.6 m against the 9 m asked.
- No group appears while the plane's heading arc lies over the Peak.
- At a low sun the side turned from the sun goes very dark.
- A pass scores under the HUD's stone graze label; a label of its own would
  need a change in `near_miss.gd`.
- The headless import rewrote many `.import` files in this worktree (line
  endings); they are not part of the commit.

## Existing tests

None were run (prototype round). No test names balloons; a test that counts
the study's children or its FrameLog marks would see one more of each.
