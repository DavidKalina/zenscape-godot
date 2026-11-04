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

# Round 2: the surge stops short of the land (2026-11-03)

Worked on branch `iter/edge-waves-shore` (off `iter/edge-waves`, which was
checked out in another worktree); fast-forward `iter/edge-waves` to it.

## What was wrong

With the belt pulled in to the shore, the big crests ran up beaches and
through cliffs and sea stacks: nothing told the surge where the land was.

## What changed

A shore map scales the surge: `EndlessSea.shore_image`, baked once on a worker
thread when the edge is set (~1.5 s after the sea is made, 582x582 texels of
32 m over the edge square plus 800 m; land read only where the belt can reach).
Per texel, the product of:

- distance off the nearest land (chamfer distance): 0 within `SHORE_NEAR`
  40 m, whole by `SHORE_FULL` 380 m (smoothstep), so a crest dies over two or
  three wavelengths as it comes in, the way a swell dies in the shallows;
- shelter: open water between the spot and land lying toward the open sea
  (along the surge's way out, x and z sweeps weighed by it): sheltered under
  `SHORE_FETCH.x` 150 m, open again by `.y` 1,600 m, softened with a box blur
  (`SHORE_BLUR`, 3 texels, two passes). Inner seas, bays whose mouths face
  sideways and water behind headlands and stacks get little or no surge;
  inlets whose mouths face the open sea get a streak of it.

It multiplies the surge's `share` at the sheet's rest point, so height,
sideways shove, foam, the crests' light and spray all fade together:
`zs_surge_shore` in `shaders/endless_surge.gdshaderinc` (sea and spray), and
`shore_fade` in `endless_sea.gd` for `surge_at` (inside its Newton loop, at the
rest point, as the sheet reads it) and `surge_room` (the fade + 0.12 for the
shove). The CPU reads the same Image bilinearly at texel centres, as the GPU
does. Past the map the fade is 1 (open sea); until the bake is in, the surge is
off on both sides (`shore_ready()`). The spray copies `surge_shore_at` from the
sea each frame (it arrives after the spray's setup).

The previous round's belt, reach and `body_swell` are unchanged.

Flags: `--shore=0` the fade off (the old look, waves onto the land);
`--shore=near,full,fetch_from,fetch_full` other ramps, e.g. `--shore=50,520`
(tried: calmer, the waves sit ~500 m off); `--shore-now` bakes on the main
thread at startup.

## Seen

`captures/edge-waves-shore/` (not committed). `before_*` is `--shore=0`,
`after_*` the final ramp (40/380), `r380_*` the same ramp by flag; the middle
panel of the `tri_*` sheets is the first try, 50/520.

- `pair_E_N.png`, `pair_W_S.png`: crests breaking on the east beach and the
  north stacks before, calm at the shore after.
- `tri_W_cliff.png` (before / 50-520 / 40-380): the big crest along the west
  cliffs, gone at the shore; a modest crest remains 150 m out.
- `tri_N_beach.png`, `tri_E_beach.png`: beaches from 150 m off, 18 m up.
- `pairs2.png`: the SE corner (unchanged, far from land), the south bay, from
  150 m (waves out front, calm band at the shore, a sandbar no longer bared by
  troughs) and the south island.
- `map_after.png` (white: belt x fade; purple: belt with the fade at 0),
  `map_fade.png` (the fade alone: the inner seas dark, mouths streaked).

## Play loop check (scratch/shore_fly.gd, not committed)

Hands-off low flight north along the east shore, 70 to 250 m off the beach,
bobbing 2 to 20 m up, 25 s: the CPU surge under the plane peaked at 0.57 m
within 100 m of land (5.14 m with `--shore=0`), 0.25 m where the map reads
0 (the rest point's shove). Scrapes 3 both ways (dips to 2 m in the body
swell), no crashes. Headless frame time unchanged (7.1 vs 7.9 ms, noise); the
shader adds one texture read per surge call.

## Launch

    python3 /Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/agent-aba3ea510bf92a04f/tools/play.py -- --no-title --pilot-file=/tmp/edge_waves_pilot.json --at=-8950,3025 --heading=0 --alt=18

(along the west cliffs, where a big crest ran along the rock). Add
`--shore=0` for the old. Others: `--at=7550,1100 --heading=270 --alt=25`
(toward the east beach), `--at=-5637,-7550 --heading=90 --alt=18` (along the
north beach and stacks), `--at=7900,1100 --heading=270 --alt=150` (from 150 m).

## Not verified

- That the drawn sea and the CPU match pixel for pixel: they read the same
  map with the same formula; no rendered probe compared them.
- Frame cost on a GPU (one extra texture read per surge call; not measured
  rendered) and the PC.
- The startup pop: the surge appears once the bake is in (~1.5 s, during
  the load in the runs here). A plane started in the belt on a slow PC may
  see it come on.
- Whether the shelter is too strong: water behind stacks and islets gets a
  calm streak 1 to 1.6 km long, softened by the blur. `--shore=40,380,80,900`
  shortens it.
- Lakes and rivers: untouched (inland, not on the sea sheet's belt); not shot.
- Ships: not shot; a ship near a shore now rides less surge.

## Tests

No test names the surge, `surge_room`, `surge_at` or the sea; none expected
to break.
