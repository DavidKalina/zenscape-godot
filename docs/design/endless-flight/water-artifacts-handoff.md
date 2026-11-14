# Water artifacts round (2026-11-13): handoff

The user's photos (2026-11-13 17:18-17:25): "the water looks like it's made
of squares", "poor transitions between river and sea, stark and ugly",
"weird blending between ocean water and river water". Every photo was taken
in photo mode, which holds the tick (the sea sheet, depth map and water time
stay where the flight left them).

Stills are in `scratch/water/` (git-ignored), taken with the throwaway driver
`scratch/water_shots.gd` (held eyes, per-view shader uniforms, a photo-mode
emulation, waits for the depth map after a jump). Spots on seed 1's default
world: river mouths at (-36, 60) (lagoon by the start), (504, 1104),
(1728, -720), (264, 1632), (-504, 1548) (`scratch/find_mouths.gd` lists more).

## What changed (shaders/endless_sea.gdshader, scripts/endless/endless_sea.gd)

1. The depth map is read through a cubic B-spline (four bilinear taps) for
   the depth (`zs_map_depth`), and the calm is `max(bilinear, B-spline)`
   (`zs_river_calm`). `depth_smooth = 0` is the earlier bilinear read.
2. The depth map bake is RGBAF: blue = how far the river's drawn water lies
   under the sea (`SEA_Y - river_drawn`) times alpha = how much of the texel
   is on the river's water. Up a mouth, on the river's water, the sea takes
   its bed depth (for the colour, its fade-in and the light through it) from
   that, smooth, never under the map's own bed, instead of the bed it sees on
   screen. Off the river's water the sea uses the map's depth as on any
   shore, so its colour rule no longer switches on the calm's edge.
   `mouth_smooth = 0` is the earlier rule.
3. Debug views 8-11 (`--sea-set=debug_view:N`): water depth as coloured,
   the calm/map/mouth shares, the bed depth in 0.25 m bands, the map's texel
   middles.

## The four artifacts

**A. Squares in the shallows and up the mouths (17-23-12, 17-24-55, 17-25-37).**
- Up a mouth: proved two sources. (a) The sea in the calm took its depth and
  its 2 m fade-in from the bed seen on screen, which there is the river's
  water drawn by the ground on its chunk grid: turning the sea off in the calm
  (`ALPHA *= 1 - still`) removed most of the squares
  (`scratch/water/mouth/sheet3.png`: real, bed depth, calm, sea off). Fixed by
  change 2. (b) The ground's own mouth tint (endless_ground `r_tint` block,
  the copy of the sea's colour) draws the same squares under it:
  `--river-knob=river_mouth_tint=0.0` removes them entirely
  (`scratch/water/final/sqg.png`). Within that block it is not the level
  weight (`river_mouth_rise=1000` keeps them), not the under-sea wet fade
  (forcing `r_level = 1` keeps them), and not the channel depth formula
  (replacing `real` with the depth map's smooth depth kept them; that change
  was reverted). Setting `river_mouth_deep.y = 0` removes them, but that also
  changes which vertices the ground lifts (`lift_most`), so it does not
  isolate the input. Not fixed; the squares there are still visible
  (`scratch/water/pairs/ab_sq.png`). Next suspects: the per-vertex river
  data the block reads (`river.x/.y` distance and width, the flow in
  CUSTOM0.zw via `depth`'s riffle term) differing between chunks of
  different grids.
- The lagoon by the start: wedges are softer (`scratch/water/pairs/ab_la.png`).
- Open shallows (the 8 m depth map, the first lead): the bilinear read does
  crease on every texel middle (debug view 11 shows the grid), but in the
  views I took I could not show those creases in the final colour
  (`scratch/water/probe/ds_ab.png`, `ds_diff.png`). Change 1 removes them
  anyway; it is not proved to be what the user saw on the beaches.

**B. Squares in the deep sea (17-20-51).** Not proved. In a photo-mode view
from 45 m (`scratch/water/probe/tu_flat_c.png`, contrast-boosted) faint
rectangular panes are in the sea's lit colour. Ruled out by toggling, each
still showing the panes: the vertex heave (`fft_heave=0`, `body_reach=0,1`),
the FFT sea (`sea_fft=0`), the foam buffer (`sea_foam=0`), the whole body
(`sea_body=0`), the cloud shade (`cloud_shade=0`), the depth tint (all four
tints equal), the bed seen through the water (seen forced to 0), the mirror
(it is near black there) and the pixel footprint (it is per-triangle on the
heaved sheet, debug proved, but a smooth footprint changed nothing visible:
reverted). Slopes, chop and wake are smooth (`scratch/water/probe/tv_ab.png`).
Still open.

**C. River to sea transitions (17-23-46, 17-25-30, 17-25-37).** Proved: the
calm (the depth map's green) is near-binary on 8 m texels, so read bilinear
its edge is a staircase of 8 m steps, and across it the sea switched swell on
and its depth from the bed seen to the map's, two very different depths
(`scratch/water/mouth/sheet4.png`: real, calm, sea off, depth). Fixed:
rounded edge and one colour rule across it
(`scratch/water/pairs/ab_tr_calm.png`, `ab_tr.png`). Not gone: the pale
channel still meets the deeper sea's blue on a curved line, and the shore
foam bands show where the calm now fades.

**D1. Dark blue hole where a river reaches the sea (17-18-32).** Proved: the
mouth's channel is deepened (`RIVER_MOUTH_DEEP` 3.6 m) and flared, and where
it ends on a shallow bar the deepened pocket is a closed basin among 0.5 m
flats; with `--river-mouth=0` the hole is gone
(`scratch/water/hole/ab_mouthdeep.png`, `sheet1.png`). The sea colours it
honestly. Not fixed: it is the land (land_field.gd `_river` and the native
kernels' copy), e.g. ease the deepening to the sea floor beyond the mouth.

**D2. Navy sheet over a sand spit (17-25-30).** Not reproduced (tried the
plane parked on a mouth bar and over calm water). One code path paints the
abyss there: in the calm the map was dropped (`known *= 1 - still`), so a
sea pixel whose screen bed was missing or stood above the water fell back to
DEEP. With change 2 the map is kept unless the pixel is on the river's water
and its bed is seen, so that path is gone. Unverified against the photo.

## Costs

- GPU: the depth read is 4 taps instead of 1; the calm 5 instead of 1 (in
  the vertex shader too); the mouth read 4 more taps in calm fragments only.
  The map is 512x512 RGBAF (4 MB, was 2 MB). Frame time not measured.
- CPU: the bake stays on its worker: 4.4-4.5 s against 3.9-4.2 s before
  (`scratch/bake_time.gd`, headless, a square with mouths). The upload when
  a bake lands (main thread, every ~900 m flown) is 4 MB instead of 2 MB.

## Checks

`python tools/smoke.py studies/endless_flight.tscn`: PASS. No committed
tests; the full suite was not run. No existing test reads the depth map's
format (grep of tests/). Not checked on the Mac (Metal) or on the user's
2560x1440 window; my stills are 1440x900 at 3D scale 0.75.
