# Summits: high-ground paint and summit snow (look only)

Branch `iter/summits`. Paint only: no change to land shape, collision or flora.

## What changed

- `shaders/endless_ground.gdshader`
  - **High-ground paint.** After `albedo = mix(grass, rock, rocky)`: where the
    tufts thin (keyed on `alpine`, so no band where they end) the ground turns
    to a stylised mix: stone patches with ragged edges (the rock's ER_MID /
    ER_LIT colours, greyed a little), fine grit, lichen crusts (yellow-green,
    rust) and patches of short, lighter olive turf. More stone the higher
    (`alpine_stone`) and the steeper. Faded to the mean share far off. Not on
    the Peak, not over rock or snow.
  - **Summit snow.** A crown's prominence is `land_shape.b`: the land's own
    baked 40 m-radius "how proud over the ring round it" (0.5 level). No new
    texture or noise field; the signal was already in the chunks. Crowns
    standing proud and above `summit_snow` whiten in broken patches (three
    scales of ragged noise), on flat ground only (n.y gate 0.62..0.80, steeper
    than the old snow's 0.55..0.72), off the Peak.
- `scripts/endless/rock_shape.gd`: `grid` bakes the shape for a chunk that has
  ground over `HIGH_Y` (30 m world, 70 over the sea) too. Before, only chunks
  with ground steeper than 0.9 got it, so a gentle summit had none (alpha 0,
  the shader reads that as "no signal", no snow).
- `scripts/endless/endless_look.gd`: `--summits=old` sets `summit_mode` 0.

## Uniforms and flags

`summit_mode` (1; 0 = old look), `alpine_from` (0.25, 0.95 on `alpine`),
`alpine_stone` (70, 130 m over the sea), `summit_snow` (70, 100 m over the
sea), `summit_proud` (0.50, 0.58 on land_shape.b), `summit_amount` (1; 0
no caps, 2 more). Flag: `--summits=old` (shader and chunk bake both).

## Stills

`scratch/summits/` in the main checkout: `topN_{low,near,far}_{before,after}.png`
for four tops on seed 1 (N: 0 = 3000,2160; 1 = -720,1740; 2 = 4860,-1320;
3 = -4080,2160), and `sheet_*.png`. Before = `--summits=old`.
Driver: `scratch/top_shots.gd` (git-ignored); finder `scratch/find_tops.gd`.

## Cost

Not measured on a GPU frame time. The paint is ALU only (about 12 noise
evaluations, inside `if (bare > 0.003)` so the low land skips it), no new fetch.
The chunk bake now runs for high chunks that have no steep ground: a one-off per
chunk on the worker.

## Open items

- Snow is the old flat SNOW colour, so near it reads as cream sheets; the
  Peak's own snow surface could be borrowed.
- Existing wood-grain swirls on the carved rock's terraces are unchanged.
- Stone/turf split and cap size want the user's eye in flight; tune with the
  uniforms above.
- Existing tests: none run (prototype round). `tests/` that check chunk
  CUSTOM3 presence (rock shape) may assume gentle chunks get no shape.

## Round 2 (look only)

Sheets: `scratch/summits/r2/sheet_top{0..3}.png` in the main checkout, three
columns (old `--summits=old`, round 1, round 2), rows low / near / far.

- **Snow surface.** Summit caps now take the Peak's snow (`psnow_surface`:
  drifts, wind crust, sastrugi, its light and edge-biting) through `sm_snow`
  gating `ps_on`; it paints from the unsheared point, so no new fetch.
- **Swirl.** Cap and alpine-stone masks read `p.xz` (unsheared), not `gxz`.
  The carved-rock terraces are untouched.
- **Cap placement.** Gate on n.y is steeper (0.74..0.88), eased by hollows
  (`land_shape.r`) and the lee side of the Peak's wind; the cap thins on
  windward and steeper ground.
- **Slate.** The dark slate was the carved-rock shape now baked on gentle
  summit chunks. Chunks baked only for height get alpha 200
  (`RockShape.HIGH_ALPHA`); the shader hands the rock paint alpha 0 for them,
  so the rock is as before. Alpine stone is also warmer (ER_MID..ER_LIT mix,
  less grit and lichen).
- **Far.** Alpine ground and caps grow with camera distance (150..1200 m):
  more bare, a higher stone share, bigger caps (fp, a pixel's footprint, is
  about 1 m even at 900 m, so round 1's fp-keyed far fade never fired).

Not fixed: from the far shots only tops 0 and 3 show the tops clearly
stonier or capped; top 2 (a modest cap) is still near-invisible at 900 m. The
near snow can read as stark white patches on dark shaded faces (top 0 low).
Cost: wall-clock median over 240 frames at tops 0 and 2, low and near,
old vs new, about 1-2 ms more (20 to 21-22 ms, display-bound and noisy; Metal
gives no GPU time). Indicative only.
Fly: `python3 tools/play.py -- --no-title` (old look: add `--summits=old`).
