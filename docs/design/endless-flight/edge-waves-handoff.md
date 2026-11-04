# Edge waves: handoff (ITER(edge-waves), 2026-11-03)

Branch `iter/edge-waves`. Two asks: the big swell (the surge) all round the
map's edge, and the ordinary sea in the middle a bit more pronounced.

## What was wrong

The surge was coded to ring the whole edge, but it was keyed to the edge
line (the rounded square, `coast_` keys), and the land stops well inside that
line. Measured every 250 m round the line (252 spots, scratch driver, not
committed): the last land is a median 1,000 m inside the line (250 to 3,500),
and the old belt started 0 to 650 m past it, whole 600 to 1,300 m past it. So
from a shore the plane met a median 1,350 m of calm sea (up to 3,750) before
the first big wave, and 2,000 m (up to 4,400) before it was whole, with the
fence starting to turn it home at 2,000 m. The waves only came close to a
shore where the coast happens to lie near the line (east side, z about
-4,100: a gap of 850 m). Not a code bug: the numbers just put the belt past
where anyone flies.

## What changed

Land and `coast_` keys untouched. Only the belt and the sea's size:

| | before | after |
|---|---|---|
| `surge_belt` x,y (starts, whole), `endless_sea.gd` `KNOB_DEFAULTS` and `endless_surge.gdshaderinc` | -200, 700 | -2400, -300 |
| `SURGE_REACH` (wander of the start), `endless_sea.gd` and the include | 700 | 450 |
| `surge_spray.gd` `_belt_from` default | -200 | -2400 |
| `body_swell` (long swell, wind sea, peaking) set where the body goes on, `endless_sea.gd` | shader default 0.85, 1.0, 0.9 | 1.7, 1.3, 0.9 |

The CPU copy (`surge_at`, `surge_room`) and the shader read the same belt
knob and the same `SURGE_REACH`, changed in step (formulas unchanged, only
numbers; checked line by line). `body_swell` is a material parameter, so the
CPU swell (`height_at`, native `ZenScapeSwell.configure`) and the shader both
get it. The FFT wind sea is not mirrored on the CPU and was left alone.

Shore to whole-surge distance, 252 perimeter spots: median 2,000 m before,
750 m after; east/south/west/north medians 750/800/450/900 m. The belt now
begins about 800 m before the median shore (small there) and is whole just
past the shoreline; the fence still turns the plane at 2,000 m past the line.
Gulfs whose water is 2,500 to 3,500 m inside the line (the south-middle and
north-middle bays) still get the waves only some way out: 3,000 m worst.

## Seen

`captures/edge-waves/` (not committed):

- `map_before.png`, `map_after.png`: top-down. Green land, dark blue calm
  sea, light blue sea in the surge belt (brighter is bigger), yellow edge
  line, red lines the fence's start (2,000 m) and full turn (3,200 m).
  Tables: `scratch/perimeter_before.txt`, `perimeter_after.txt` (uncommitted).
- Before/after at the same spot: `before_E_shore.png` vs `try1_E_shore.png`
  (the first try, belt -2400/-100, reach 700); final belt: `after_N0.png`
  (north, edge line), `after_NEcorner.png`, `after_SW.png`, `try1_W.png`
  (west), `try1_S.png`, `try2_N.png`.
- Middle sea: `mid_default_{30,150}.png`, `mid_a_*` (1.6,1.2,0.9), `mid_b_*`
  (2.2,1.3,0.9). b reads rough and the plane scraped it at the start's 30 m;
  chosen 1.7/1.3 between default and a-b. From 150 m the change is a finer,
  busier surface; low it is longer, taller swell. `shipview_*` for both ships.

## Launch, old against new

    python3 /Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/agent-ae7f3860efadc5fb1/tools/play.py -- --no-title --pilot-file=/tmp/edge_waves_pilot.json --at=-5387,-7300 --heading=0 --alt=60

(the north shore, flying out over the waves). Other starts: `--at=7000,1100
--heading=90 --alt=40` (east), `--at=-8700,3275 --heading=270 --alt=60` (west),
`--at=-3288,8100 --heading=180 --alt=60` (south), `--at=1800,3600 --heading=60
--alt=30` (middle sea, by the lighthouse isle and the ships).

Old sea: `--sea-set=body_swell:Vector3(0.85,1.0,0.9)`. Old belt:
`--sea-set=surge_belt:Vector4(-200,700,2200,3200)` (the 700 m reach is a
constant, so this is the old belt only roughly).

## Not verified

- The ships up close: the hull sat in the water in the wide stills (their
  sway reads the new swell through `height_at`), but my close framings were
  bad (inside the hull, on the sails), so the prow tunnel and plank clipping
  are unseen. Ship code untouched.
- Lakes and rivers: not shot; they are calmed by `zs_river_calm` (shader)
  and `field.sea_calm`, which this doesn't touch.
- Spray cost: the spray cards now run over the whole ring from 2,400 m
  inside the line; frame cost not measured (about 1.1 ms low in the belt in
  the swell round).
- Near a beach the big crests now break on the shore in some spots (east,
  north stills): to judge in play. The gentler ramp in (belt.x -2400 to
  -300) is the knob if it reads too violent there. The sea sheet's
  heave stays under land (the sea is discarded where land is above it).
- Low flying near shores meets swell now (the "rising wave scrape" rule
  of the swell round applies over a wider area).
- A headless smoke (inland, and at the east shore) passes with no errors.

## Tests

No test names the surge, the belt or `body_swell`; none expected to break.
