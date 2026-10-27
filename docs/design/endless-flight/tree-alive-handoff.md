# Endless flight, the woods alive

The ask: the spruces should feel alive. Before this, each tree swayed as one
rigid shape within 200 m, and the sprites past that stood still.

## Launch

- Windows: `.\run-endless-flight.cmd` (on by default)
- Before, to compare: `.\run-endless-flight.cmd --tree-alive=0`
- Windier: `--tree-alive=1.5` (or 2)
- Over woods at cruise on seed 1: `--at=-700,-1900 --heading=0 --alt=45`

## What was built

- `shaders/tree_wind.gdshaderinc` (new). This is the shared part.
  - The `zs_tree_alive` shader global (`project.godot`, default 1). It is
    set from `--tree-alive=X` in `scripts/endless/land_trees.gd` `setup`.
  - **Gust waves** (`zs_tree_wave`). The crests are 90 m apart and roll
    downwind at 2.5 times the air's travel, about 6 m/s. Noise 160 m across
    bends them and breaks them into patches. A tall tree's top lags its foot.
  - **Boughs** (`zs_tree_bough`). Each bough bobs on its own slow beat;
    the phase comes from its turn about the trunk and its height. The
    motion is biggest at the tip and grows larger (not faster) when a wave
    is on the bough. The bob is about 0.2 m at a bough's tip in calm air
    and about 0.5 m at a crest.
  - **Sheen** (`zs_tree_sheen`). Where a wave lifts the boughs, the crown
    turns up to 28 % paler and cooler (the needles' undersides), following
    the wave alone.
- `shaders/conifer_wind.gdshaderinc`: `zs_conifer_offset_alive`. A wave adds
  to the tree's lean (0.22 at a full crest, about a metre at a 15 m top)
  and to the boughs' motion. `zs_conifer_offset` is unchanged for the other
  tree shaders.
- `shaders/reference_surface.gdshader`: the near and far crowns (out to
  200 m) and the trunks call the alive path. The new `tree_sheen` varying
  carries the sheen to the crown's tint.
- `shaders/endless_spruce_sprite.gdshader` (200 m to 1.44 km). The sprites
  now lean and sway in the breeze as the near crowns do, so the hand-over
  at 200 m no longer jumps from a leaning tree to an upright one. They take
  the waves' lean and sheen too. With `--tree-alive=0` they are still, as
  before.
- `shaders/endless_forest_floor.gdshader`: the canopy painted past the
  sprites takes the sheen, so a wave runs on across every hand-over.
- `tools/harness/look_views.gd`: its held views now step the trees.
  Before, the views drew bare trunks within 200 m of the eye: the crowns'
  detail tiles were never stood round a moved camera.

## Fix: jitter (after the first play)

The user found it jittery. There were two causes:

- **The boughs' beat sped up in a wave.** The phase was the clock times a
  pace that changed with the wave, so as a wave came or went the phase
  swept by the clock's whole run. Ten minutes in, that was about 20 Hz of
  flutter.
  - Now the beat is fixed at 2.2 rad/s (about 0.35 Hz), and only the bob
    grows in a wave.
  - The 13 rad/s shiver is gone.
  - The phase changes less along a drooping bough (`vertex.y` 5.3 to 2.5).
- **The sheen flickered.** It followed each bough's bob on the near crowns
  and a 4 rad/s beat on the sprites. Now it follows the wave alone.

## More sway, and the grass's stirring (after the second play)

The user asked for more sway, and for the trees to answer the eddies that
move the grass, as one shared system.

- **What was shared already.** The crowns leaned with the shared breeze
  (`zs_breeze_lean_at`): the gust field, gust bands, gust fronts and the
  8 ribbon heads' wakes.
- **What wasn't.** The map the endless grass bows by, `zs_react_map`
  (`scripts/endless/grass_react.gd`). It carries the eddies' swept
  bands, the gusts landing and the prop's wash.
- **Now.** The crowns and the sprites read that map at their foot
  (`zs_tree_react`, `ZS_TREE_REACT` 0.4 of the grass's push, in lean
  units). A full eddy band bends a 15 m top about 2 m, and the tree springs
  back with the grass. The stir also grows the boughs' bob and lights the
  sheen.
  - The map covers 384 m round the eye, so this reaches the near and far
    crowns and the first sprites.
- **More sway.** With alive on, the breeze's lean is times 1.4
  (`ZS_TREE_SWAY_LEAN`) and the swing round it 0.7 of the lean
  (`ZS_TREE_SWAY_SWING`, was 0.4). The sprites match.
- **Proof.** A gust stamp landed on a meadow spruce
  (`scratch/trees/held.gd --stamp=x,z,strength`) bends its top downwind,
  and the tree springs back.
- **Frame time.** Over woods, alive on against off, two runs: 10.14 and
  9.95 against 9.74 and 9.75 GPU ms, about +0.3 ms.

## Numbers (RTX 4070 Super, 1440x900, 3D at 0.75)

The frame time was taken in real flight over woods
(`--at=-700,-1900 --alt=45`), 300 frames, run twice:

| | GPU ms |
|---|---|
| `--tree-alive=1` | 9.52 |
| `--tree-alive=0` | 9.38 |

That is about +0.15 ms. Held views gave +0.14 ms (cruise over woods) and
no difference down in a wood.

The first run after the change hitched while the shaders compiled.

## Proof

- Smoke passes: `python tools/smoke.py studies/endless_flight.tscn`
  (400 frames, 0 errors).
- In rendered runs the shaders compile with no errors.
- A/B over a wood from 150 m, the luma change across 8 stills over 4 s
  (`scratch/trees/held.gd`): the trees change with alive on and are static
  with it off. Close up, the boughs move between stills a sixth of a second
  apart.
- **Not judged:** whether the waves read as waves while flying. That needs
  play. The knobs are the constants at the top of `tree_wind.gdshaderinc`.

## Not done

- The shadow proxies don't sway (as before).
- The rings (`--spruce-sprites=0` only) don't take the waves.
- No committed test. No existing test touches these shaders.
- The low-res and plastic passes are still to come.

# The far trees, low-res pass

The ask: the far trees looked low-res. Fix it with soft edges, more baked
sides and no grain, behind a flag to compare.

## Launch

- Default: the soft sprites. `--spruce-sprites=old` gives the first look.
- Try `--spruce-far=150`: the sprites from 150 m instead of 200 (see
  below).

## What was built

- **8 baked sides** (`scripts/endless/spruce_sprites.gd`, `SOFT_YAWS`;
  `OLD_YAWS` 4). The cells stay 192 px: a tree at 200 m is about 36 px tall
  at 0.75 scale, so they were never short of pixels.
  - The atlas is 9216 x 576, twice the width, about +28 MB of video memory
    for the two atlases with their mips.
- **No grain between views** (`shaders/endless_spruce_sprite.gdshader`
  `soft`). The nearest two turns and heights are blended (premultiplied),
  each view alone over the middle half of its span. Before, they were
  dithered pixel by pixel.
- **Soft outline.** Alpha to coverage over the screen's MSAA
  (`alpha_to_coverage_and_one`), with the scissor at 0.5 and an
  anti-aliasing edge of 0.3 over the cell's texels. Before, it was a hard
  `discard`.
- **No grain ring at the hand-overs** (`scripts/endless/land_trees.gd`
  `LOD_SPREAD`, `LOD_SOFT_FADE`; `reference_surface` `lod_spread`, the
  sprites' `spread`).
  - Each tree swaps level at its own distance, spread 30 m round 80 m and
    200 m, with the same per-tree hash of the foot on both levels.
  - The dither is 2 m either side. It was 12 m at 80 m and 15 m at 200 m,
    so a whole ring of trees was mid-dither at once.
- **Tried and dropped:** baking the atlas at MSAA 4x. The resolve mixes an
  edge's colour in linear light, and the shader's un-premultiplying (right
  for the byte-averaged mips) reads that back as a pale rim.

## Proof

Held stills from 60 m over a wood at 150 to 600 m
(`scratch/trees/held.gd --eye=720,480,60 --look=680,250,0 --hold=600`),
`scratch/trees/soft/abc.png`, three crops stacked:

- **old:** the grainy, crawling trees;
- **soft:** clean outlines and no grain, except a few 3D far crowns at 100
  to 200 m whose fine needle teeth shimmer at that size;
- **soft with `--spruce-far=150`:** those go too.

The smoke check passes, and there are no shader errors in the rendered runs.

## Frame time (RTX 4070 Super, held view above, GPU ms)

| setup | GPU ms |
|---|---|
| old | 7.57 / 7.54 |
| soft | 7.69 / 7.57 |
| soft, `--spruce-far=150` | 7.53 |

That is about +0.1 ms for the soft sprites (four atlas reads where a view
blends, two before). `--spruce-far=150` is 0.16 ms cheaper than soft at
200 m.

## Not done

- **The 3D far crowns' shimmer at 80 to 200 m.** Moving the sprites in to
  150 m (`--spruce-far=150`) hides most of it. The question is whether the
  sprites read flat that close when you bank past them, which needs play.
- **The sprite and the 3D crown measure distance slightly differently.**
  The sprite measures 3D to the foot; the crown measures across from the
  foot, then up by the pixel's height. This is old; the 2 m dither shows it
  less than 15 m did.
