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

# Round 2 (2026-11-13)

Stills in `scratch/w2/` (git-ignored; `pairs/`, `deep/`, `navy/`, `dbg/`), taken
with round 1's `scratch/water_shots.gd` (now also `nosea` and `look:_field=v`
parts). Before = `--river-floor=0` and `waver_exact=0` / `river_waver_exact=0`;
after = defaults. Eyes are in `scratch/w2/views_main.txt` and below.

## Cause found: the sine hash in the depth waver (A and D)

Both shaders tint the water by a depth multiplied by a `waver` (value noise at
33 m and 9 m, `zs_noise`). Its hash, `fract(sin(dot(i, (127.1, 311.7))) *
43758.5453)`, loses precision on the GPU once the lattice coordinates reach the
tens (sin of thousands): a cell's corners no longer match its neighbour's, so
the noise is cut into hard-edged squares on its lattice lines. Proved with sea
debug view 19 (the waver: discontinuous on its cell lines) and 18 (waver = 1:
the squares up the estuary at (1728, -720) are gone). Round 1's squares under
the ground's tint were the same waver (the ground's mouth tint copies it).
Round 1's deep-sea panes at its own eye (pe 0,s12,520>0,s5,600, photo
10,s45,560>0,s0,590, debug_view 3, sea_body 0) come back with `waver_exact=0`
and are gone with 1 (`deep/ab_tu_lit.png`, equalised).

Fix: `zs_noise_exact` in `reference_wind.gdshaderinc` (the same smoothstep
value noise, PCG-style integer hash); the sea's waver and the ground's mouth
tint waver use it. Knobs: sea `waver_exact`, ground `river_waver_exact` (0 the
old). The waver's pattern changes (new random values), its statistics do not.
Cost: the hash is a few integer multiplies instead of a sin; no texture taps.
Other `zs_noise` users are untouched (wind, foam, paws keep the sine hash;
they may break the same way far from the origin, not shown).

Pairs (left before, right after): `pairs/ab_sq.png`, `ab_sq2.png` (estuary at
1728,-720), `ab_m24.png`, `ab_be.png` (beach at 476,508), `deep/ab_tu_lit.png`.

## C: the hole at a mouth (land)

Proved with `scratch/mouth_profile.gd` / `depth_map.gd`: the mouth's bed
(RIVER_BED + RIVER_MOUTH_DEEP = 4.2 m) ends on a rim: where the river ends
because the land under its water is 2.5 m down (`banked` fades the cut), and
where it ends because `inland` fades its strength `k` onto 0-0.5 m flats
(the pool at about (110, 1830), the one in round 1's `hole/ab_mouthdeep.png`).
Fix (`land_field.gd` `_river` and its copy in `native/terrain_kernels/
land_field.h` `river_at`): the bed is never deeper than RIVER_MOUTH_FLOOR
(1.5 m) under the sea's level; at a mouth the cut holds in full out to the
river's end (not faded by `banked`); the mouth's extra depth is scaled by the
river's strength `k`, so it shoals as the river runs out. Up the mouth, where
the river stands over the sea, the channel keeps its depth. Ground shader:
`river_mouth_floor` caps the tint's channel depth the same way.
`--river-floor=0` is the old land and tint.

At 2.5 m the pool still read as a blue hole; at 1.5 m it reads as the
river's water (`pairs/ab_pkn3.png`: old, 2.5 m, 1.5 m, and `ab_pk.png`).
Side effect: every mouth's channel at sea level is shallower and paler (the
estuary in `ab_sq.png` is milkier). What moved: over a 6 km square round the
start (8 m grid, 562,500 samples) 1,002 heights changed, all in mouth
channels, between -4.8 and +0.8 m over the sea, raised up to 1.7 m and
lowered up to 0.84 m (the full cut); 10 of them over the sea's level.
Native kernels rebuilt here (debug and release, `scratch/godot-cpp` copied
from the main checkout's builds/), native matches GDScript on the depth map
round the pool (`scratch/w2/dm_native.txt` = `dm_gd.txt`). The DLLs are
git-ignored: the main checkout and the Mac need their own build.

## B: the line where the channel meets the sea, NOT fixed

Still visible (`pairs/ab_tr2.png`, `ab_tr4.png`). Seen with sea debug 9/12
and ground debug 5 at eye 460,s35,1060>505,s0,1105: the river's drawn water
sinks under the sea over a short reach (RIVER_MOUTH_SINK, the sea's alpha
over 2 m of sunk depth), and the calm stops at the river's water, so calm
pale channel meets the swell within a few metres. Tried a wider calm read
(the map's green through a coarser B-spline): a faint faceted halo, no
better; reverted. Next: a longer hand-over (sink over more of the level, or
the sea's alpha by distance from the river's end), and the calm carried a
few texels out along the flow in the bake.

## E: navy sheet, NOT reproduced

Likely path: the surge raises the sheet over a spit, the "nothing short of
the deep under the swell" rule (`surge_share > 0 && receiver.y > sea_level -
2`) drops the bed, and in the calm round 1's old code also dropped the map
(`known *= 1 - still`), leaving DEEP: navy. Round 1's change 2 keeps the map
there. Four frames at 530,s35,1125>500,s0,1095 with `mouth_smooth=0` (sea
debug 20: red where the bed was dropped, green the map): the rule never fired
(`navy/sheet.png`). Unverified against the photo.

## Debug views added

Sea `debug_view` 12-20 (see the uniform's comment; 20 = bed dropped / map /
depth). Ground `river_mouth_debug` 1-7 (river distance, width, level, flow,
mouth/tint/wet, height over sea, tint depths).

## Checks

`python tools/smoke.py studies/endless_flight.tscn` PASS, also with
`--river-floor=0`. No committed tests, full suite not run. No test reads
RIVER_MOUTH_DEEP or the waver; land hash / ground parity fixtures (if any
pin seed 1's mouths) would change. `tools/ground_parity.py` not run.
