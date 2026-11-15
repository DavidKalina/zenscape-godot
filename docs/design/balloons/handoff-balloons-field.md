# Hot air balloons: fields, sizes, colours, take-offs (prototype round, 2026-11-14)

Follows `handoff-balloons.md`. Branch `claude/hot-air-balloon-pricing-1ab577`.

## Try it

```
.\run-endless-flight.cmd --balloon-field-now              # a field near the start, two to four on the ground
.\run-endless-flight.cmd --balloon-field-now --hour=18.6  # the same at dusk
.\run-endless-flight.cmd --balloons-now                   # the old low group of three
.\run-endless-flight.cmd --balloon-field-gap=60           # fields every minute or so while flying on
.\run-endless-flight.cmd --balloons=0                     # none, for an A/B
```

On seed 1 the start faces the Peak, so `--balloon-field-now` turns the field
off the heading until its line is off the massif: look around for it.

## What was built

All in `scripts/endless/endless_balloons.gd` plus one uniform in
`shaders/balloon_canvas.gdshader`. No model change.

- **Pool of 26** (was 3). Groups of one to three still come as before, on
  their own clock; a third member is now sometimes a speck in the sky.
- **Field**: its own clock (`FIELD_GAP` 300 s mean, first after 120 to 240 s),
  appears 1300 to 1500 m ahead. A line of 6 to 8 low balloons along the way
  in, staggered left and right of the line; 4 to 6 middle ones; 2 to 4
  specks 400 to 600 m up; 2 to 4 on the ground on open grass beside the
  line's first stretch. At most 20.
- **On the ground**: the basket sits on the grass, the burner fires in short
  bursts. Once the plane is within 700 m, each lifts after 2 to 24 s (or
  after 150 s regardless): long burns, a climb easing up to 1.4 to 2.4 m/s,
  the drift coming in over the first 35 m, then it joins the usual height
  keeping. The wash only sways it on the ground (0.05 rad, no basket swing).
  Spot rules: no slope over 0.8 m under the basket, under 20 % across the
  envelope, ground colour green (not snow, ice or scree), off the Peak's
  massif, the sea's shore, rivers, and the tree plan's woods, and no tree,
  stone or arch the near world knows. Re-checked when the plane comes within
  380 m (trees are only built near); if blocked then, it lifts at once
  (`blocked` counts it; 0 in every run).
- **Sizes**: each balloon 1.0 to 2.2 times the old size (big ones rarer).
  Wash reach, awake range and visibility hand-over scale with size; graze
  reach scales with its square root; a bigger one rocks less.
- **Colours**: 8 festival palettes (saturated dyes) with a new instance
  uniform `wear` (0.2 to 0.45; the old muted cloth is 1.0) that cuts the
  sun-fade and panel dimming. 85 % of a field's cloth is festival, 60 % of a
  group's.
- **Step**: see Cost.

## Numbers

| | |
|---|---|
| Low line | 6-8 balloons, 90-135 m apart along, 24-42 m either side, floor 11-22 m, size 1.0-1.5 |
| Middle | 4-6 within 300 m of the field's middle, floor 35-120 m |
| Sky | 2-4 within 450 m, floor 400-600 m, size 1.3-2.2; groups' third member 30 % |
| On the ground | 2-4, at least 34 m apart, size 1.0-1.4, found one try a frame (60 tries) |
| Graze reach | 10 m x sqrt(size) past the wing tip |
| Gone | past 2800 m (was 2400), or behind the view past 900 m for 20 s |

New flags: `--balloon-field-now`, `--balloon-field-gap=S`, `--balloon-fields=0`,
`--balloon-pool=N`. Old ones unchanged.

## Cost

Measured with `scratch/balloon_bench.gd` (rendered 720x450 and 1440x900,
camera held over the meadows, balloons fanned out ahead; each config 300 to
600 frames, the list run twice). GPU and render-thread CPU from
`RenderingServer.viewport_get_measured_render_time_*`.

- **Drawing is not the cost on this PC.** 20 and 40 near balloons (all
  within 390 m, near model) against none: GPU and render-thread CPU equal
  within the run-to-run noise (about 0.1-0.2 ms). Shadows off, near model
  only within 150 m, gondola hidden, canvas vertex work removed: each also
  within noise. So none of those were cut. The near model already has LODs
  from the import (`generate_lods=true` in `balloon.glb.import`), which is
  why no hand-made middle LOD was built. Not checked on a weaker GPU.
- **The script step was the cost that grew with the pool.** Script ms per
  frame (manager's running mean, rendered, 1/60 s ticks):

| | before | after |
|---|---|---|
| 3 balloons near | 0.05 | 0.05 |
| 20 balloons within 390 m | 0.25 | 0.17-0.19 |
| 20 balloons 90-1300 m | not measured | 0.07-0.10 |
| driven field run, 19 live (headless) | | 0.08-0.11 mean |

  Now every live balloon only glides each frame; its full step runs every
  frame only within 320 m of the eye, near the plane, or while rocking, and
  otherwise 3 balloons a frame by turns. Ground asks: river test dropped
  (LEAST covers it), 1 loose sample (was 2), high ones every 1.5 s, far ones
  every 1 s and one far balloon a frame at most. A sighting is put one
  balloon a frame.
- **Spikes**: one balloon put can take 1-3 ms when its ground asks land in
  cells the world hasn't touched yet (seen once a field, on the second
  put); a 240 s headless run had its worst frame at 1.0-1.2 ms. The meadow
  search costs about 0.1 ms a try.

## Proof

- `python tools/smoke.py studies/endless_flight.tscn -- --balloon-field-now`,
  `-- --balloons-now`, `-- --balloons=0` and no flags: PASS, 0 errors.
- `scratch/balloon_fly.gd` (not committed): `--balloon-field-now
  --weight=medium`, the plane steered through the stick past each low
  balloon's inner side about 5 m off the cloth with a wobble, keeping 12 m
  over the land ahead. Seeds 1-4 without Boost, 1-3 with: every check
  passed. Passes scored 6-9 per run, best chain 3-9; least floor clearance
  of air balloons over land and trees 5.8-9.9 m; ground balloons sank
  0.00 m (basket 0.09 m over the ground: the skids); every run had 2-4 on
  the ground and they lifted 40-112 m.
- `scratch/balloon_long.gd`: 240 s on with `--balloon-field-gap=40`: fields
  and groups come and go, 20 alive at most, no errors.
- Stills in `scratch/shots/` (git-ignored): `field_skim_noon`,
  `field_near_noon`, `field_takeoff_noon`, `field_lift_noon`,
  `field_sky_noon`, `field_wide_noon`, `field_skim_dusk`,
  `field_takeoff_dusk`, `field_near_dusk`; `bench_20.png` (old colours).

## Not verified, known gaps

- Nobody has flown it by hand. The driven pilot's grazes don't prove the
  line feels right to weave.
- The field-flythrough case (20 near) costs ~0.18 ms of script a frame.
- Round the start most land is the Peak's massif, steep, or sea (a probe
  over 300 points: about 8 % pass the ground rules), so the ground balloons'
  search can wander a few hundred metres from the line.
- A field's middle and sky balloons can drift onto the massif; they climb
  over it.
- Fields appear only when the heading arc's chosen point is off the massif,
  tried every 2 s.
- No envelope inflating, no landings (as asked).

## Existing tests

None run (prototype round). No test names balloons. `--balloon-pool` makes
26 balloons' nodes at setup (was 3): a test that counts the study's nodes
would see more.

## Harness

No tool was missing. `tools/harness/look_views.gd`'s `frame_time` lacks
the render thread's CPU time; the bench copied it with `cpu_ms` added.
