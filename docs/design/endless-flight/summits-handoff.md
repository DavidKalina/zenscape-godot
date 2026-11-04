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

## Round 3 (look only): snow that frays

Sheets: `scratch/summits/r3/sheet_top{0..3}.png` in the main checkout, four
columns (old, round 1, round 2, round 3), rows low / near / far; 2x crops
`crop2x_top{0,2}_low_r2_vs_r3.png` (left round 2, right round 3).

- **Coverage, not a cut-out.** The cap is a continuous cover `cov` (wide soft
  ramp on the crown field, a wider n.y gate, hollows and lee), then each spot
  has its own threshold from fine noise (0.45 / 1.5 / 4.5 m) with a wide
  smoothstep, so a thin cover breaks into patches and specks and partial
  alpha reads as dusting over the stone. All world-xz noise through zs_fade
  (melts to its mean far off); no new fetch.
- **Edge.** Caps no longer take the Peak's crisp re-threshold: the Peak's
  surface and light are used (psnow_surface called with snowy 1 on caps) and
  the cap keeps its own frayed coverage.
- **Colour.** Cap snow is a cooler, greyer tint, dimmer where thin
  (`summit_dim`), so never pure white on a dark face.
- **Far.** `cov` grows with camera distance (x up to 2.1, gate eased).

Still not right: top 0 low keeps big snow sheets and the bare dark slate
beside them still reads cow-ish (that is the carved rock, left alone); the
bare patches in top 0's crown show a dark ochre stain (stone/old paint under
thin cover); top 2 low snow is soft but still smooth inside; far views show
caps only a little more than round 2 (tops 1 and 2 still faint); there is no
extra grit poking through inside the snow. Not measured on a GPU; about 6 more
noise evaluations inside the cap branch.

Uniforms: `summit_fray` (0.45; 0 hard edges), `summit_lee` (0.30; lee and
windward weight), `summit_dim` (0.24; thin-cover darkening), plus round 1's
`summit_snow`, `summit_proud`, `summit_amount`. `--summits=old` unchanged.

## Round 4 (look only): the snow path rebuilt

Sheets: `scratch/summits/r4/sheet_top{0..3}.png` in the main checkout, three
columns (old `--summits=old`, round 3, round 4), rows low / near / far; 2x
crops `crop2x_top{0,2}_low_r3_vs_r4.png` (left round 3, right round 4).

Why round 3 went wrong (root causes, not tuning):

- **The noise was off-centre.** `zs_fade` returns noise centred on 0, but
  round 3 used it as if it were 0..1 (`fray - 0.5`, `fine_n - 0.2`). So the
  "fray" was a constant -0.5 bias, the per-spot threshold sat on its 0.05 floor
  almost everywhere, and the cap was one soft 0.5-wide smoothstep of the cover:
  the smeared blobs on dark faces.
- **The brown stain was a double fade.** The alpine paint was faded by
  `(1 - snowy)` and the snow then mixed over it by `snowy` again, so under thin
  snow the old tundra grass showed through (a quarter of it at half cover),
  darkened further by `summit_dim`.
- **The Peak lost its edge.** Round 3 passed a copy of `snowy` to
  `psnow_surface` and only wrote it back on caps, so the Peak's snow (and the
  land's own snow line, which takes the Peak's surface off the Peak too) lost
  the surface's bitten edge. Restored: the Peak path is as before the summits.
- **Partial snow took the snow's whole fill.** `psnow_emission` scales all of
  EMISSION by up to 5.2x by the snow's share, which is right for the Peak's
  crisp edge but brightened the ground under a thin cap.
- **Snow sat on the dark faces** because the slope gate was eased by the lee
  and hollows up to about +0.3 on n.y, and nothing kept it off rock.

What it does now (`shaders/endless_ground.gdshader`, the cap block):

- `cov` (0..1): proud x high x lies (n.y 0.80..0.93, lightly eased by lee and
  hollow) x off the rock's own faces (`rock_face`, the rock before the high
  ground's broken rock; not past 700 m, where the faces are a few pixels).
- The cap is `cov` against centred noise at 38 / 12 / 3.5 / 1.1 / 0.45 m,
  scaled by the cover so ground that sheds snow gets none, with a soft edge
  (w 0.09); a thin dust of grit specks just short of the edge; stones (sparse
  tops of a 2.4 m noise and the grit) punched through.
- Far (250..900 m): the cap eases to the cover itself, a soft light crown,
  with the crown's own rough mean on proud high ground.
- Colour: the Peak's surface and light, a shade cooler, the value drifting
  +-30% x `summit_tone` over 12 / 3.5 / 1 m; the snow's extra sky fill only on
  the snow's share, at 0.62 of the Peak's near (shaded caps aren't white
  sheets), the full fill far.
- The alpine ground no longer fades under a cap; it is skipped only where the
  cap is whole.
- Removed: `summit_dim`, `sm_cov`, `sm_dust`, round 3's fray / threshold code.

Uniforms: `summit_fray` (0.5; edge specks and grit, 0 a clean edge),
`summit_lee` (0.30), `summit_stones` (0.5; 0 none), `summit_far` (0.85; 0
only the patches far off), `summit_tone` (0.5; 0 flat), plus `summit_snow`,
`summit_proud`, `summit_amount`. `--summits=old` unchanged (the cap block is
skipped and every new term falls back to the old path).

Still not right: top 1 has no cap in any round (a steep rocky horn; it reads
as bare stone, which is the rule, but it means no crown far off either). Top
0's crown snow is the land's own snow line (about 120 m) through the Peak's
surface, not the cap: crisp-edged, with the ring round the crown's pit, as in
round 2. Stones in top 2's sheet read as pale melt holes more than stones. A
few frayed patches stay on top 0's shaded lower flank. Not measured on a GPU;
about the same noise count as round 3 (eight zs_fade in the cap), no new fetch.
Driver: `scratch/top_shots4.gd` (git-ignored; `--set=uniform=value`,
`--first=N` for the file index). Existing tests: none run; none known to read
these uniforms.
