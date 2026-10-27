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
