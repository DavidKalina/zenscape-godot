# Endless flight, look round 3: the grass carpet

The aqueduct isle's carpet now grows over the streamed land round the
eye. Near the plane it is the isle's own tufts and wildflowers, with the
isle's material. Farther out a plainer far ring takes over, and past that
the painted ground. The painted ground was retuned so the three meet with
no visible ring.

## What changed

- `scripts/endless/endless_grass.gd` (new) holds two layers of 64 m cells.
  Each cell is grown on a WorkerThreadPool task from the land field and
  freed once the eye has moved off it.
  - The grower is KitFlora's `Grow` with the aqueduct isle's carpet
    settings (`AqueductIsleFlora.carpeted`, and `calm`'s numbers). It uses
    the existing opt-ins `plain`, `probe`, `box`, `rim` and `lod`.
  - The probe reads a 1 m height grid of the cell, split into triangles
    the same way as the land's finest mesh. Grass grows only on open turf:
    at least 2.55 m over the sea, with a normal's up of at least 0.905
    (full from 0.95), and thinning out between 36 and 58 m over the sea.
    There is none on rock, sand, snow or seabed.
  - The near layer is the isle carpet at the isle's density (7.8 tufts a
    m²) with the isle's tuft material: sway, light and wind sheen. It
    reaches 20 m, and each tuft shrinks into the ground by 36 m. The
    wildflowers come with it and thin out, one by one, from 22 to 55 m.
  - The far layer is 1.8 a m² of `GrassTuft.build_lite`, grown 2.0×
    wide and 1.8× tall. It is drawn with `shaders/endless_tuft_far.gdshader`
    (new): no sway, a soft "mass" normal, colours matched to the near
    tufts, darker at a glance, and the cloud shade. Its tufts grow in from
    nothing over 20–36 m and thin out over 150–230 m. Its cells have no
    wild grass or tussocks, which makes them cheap (90 ms against 360 ms
    for a near cell).
  - Each tuft's instance colour is the painted ground's patches at its
    root (`scripts/endless/endless_patch.gd`, below). So the carpet carries
    the land's light and dark patches, its lusher meadows and its dry
    ground, rather than sitting on it as a flat disc.
  - The main thread only stands finished batches, at most 1.5 ms a frame,
    as KitFlora's 24 m tiles so each tile culls on its own. The cells
    nearest the start are grown during the load.
- `shaders/endless_patch.gdshaderinc` (new) and `scripts/endless/endless_patch.gd`
  (new) are the same value noise over an integer hash, one for the GPU and
  one for the CPU, so the CPU tint and the paint agree. The ground's patch
  scales from 8 m up (vast, broad, wide, mid, clump) now use it.
- `shaders/endless_ground.gdshader`:
  - The patches use the shared noise.
  - It has new `carpet_*` and `turf_*` uniforms, set by the grass. Past the
    tufts' reach, and anywhere tufts don't grow, the paint takes the
    carpet's tone as it reads from afar: `carpet_tone_top` seen from
    above, `_low` at a glance.
  - It paints a tuft-sized speckle (`carpet_grain`) from about 40 m out,
    and the velvet sheen on the turf is cut by 60%.
  - With the grass off, the whole land takes the tone everywhere.
- `studies/endless_flight.gd` builds the grass with the full look, steps
  it round the camera that draws, has a G key and a HUD line, and lists the
  new flags in its header.
- No shared file was changed: KitFlora, the tuft mesh and
  `reference_surface` are used as they are. The aqueduct isle and the motif
  editor are unchanged, so I did not smoke the isle this round.

## Flags, keys, knobs

- `--no-grass` starts with the grass off. G turns it off and on in flight.
- `--grass=X` scales the density (1 is the isle's).
- `--grass-range=M` is where the far ring ends (230). The other rings scale
  with it.
- `--grass-lod=x,y,z,w` sets the four ring distances (20,36,150,230).
- `--no-flowers` leaves out the wildflowers.
- Consts in `endless_grass.gd`: `LOD`, `FAR_TUFTS`, `FAR_GROW`,
  `FAR_ROOT`/`FAR_TIP`, `FLOWER_FADE`, `SLOPE`, `HIGH`, `BEACH_CLEAR`,
  `TONE_TOP`/`TONE_LOW` (the paint's carpet tone), `MAX_TASKS` (6),
  `STAND_BUDGET`.
- Shader uniforms:
  - `endless_tuft_far.gdshader`: `graze_tone`, `mass_normal`.
  - `endless_ground.gdshader`: `carpet_grain`, `carpet_grain_sizes`,
    `carpet_velvet_cut`.

## How it reads from high and far (my judgement)

- Up close (skimming at 3 m, rolling out, stopped on a meadow) it is the
  isle's carpet. It is lovely, with flowers in it, and it keeps going to
  the horizon.
- On a landing approach (15 m) the near tufts and the far ring blend into
  one textured meadow.
- At cruise (45 m) the tufts read as a fine, living grain on the turf.
  There is no disc and no edge.
- High up (95 m, the ceiling over a meadow) the near ring is out of reach.
  The far tufts are 1 to 3 px, and the picture is almost the same as with
  `--no-grass` (compare `f2_l95` with `f2_l95_nograss`).
- So from high above, the read comes from the retuned paint (its tone,
  grain and patches), not from the tufts. That is the honest answer to
  the open question. The tufts earn their cost from about 40 m down.

## Verified (this Mac, M5 Pro, Forward+, 1440x900, Godot 4.7.2)

- Headless import: 0 errors.
- Smoke PASS, 0 errors, for `endless_flight.tscn`, for `-- --no-grass`,
  and for `-- --plain-look`.
- Every rendered run had 0 errors.
- Frame time: the mean of 300 frames, uncapped, with the clouds on, the
  view held still once the grass had grown
  (`scratch/endless-grass/perf.sh` with `scratch/endless_perf.gd`).
  "Before" is `--no-grass`, which is last round's look plus the paint's new
  tone and grain.

  | view (seed 1, meadow at 1200,950) | grass off | grass on |
  |---|---|---|
  | low, 6 m over the meadow | 6.5 ms | 12.9 ms (p95 13.5) |
  | cruise, 45 m | 7.4 ms | 10.2 ms |
  | high, 95 m | 7.6 ms | 9.1 ms |
  | the start (cruise) | ~7 ms | 9.4 ms |

  - At low height the near ring (the isle's tuft shader) costs about
    4–5 ms, the far ring about 2.5 ms, and the flowers about 0.5 ms.
  - The isle's tuft material is what costs. Using it for the whole ring
    out to 230 m cost 20–30 ms, which is why the far ring has its own
    plain shader.
- Boost flight at about 25 m over the ground, 90 s, 2.2 km at 25–27 m/s,
  through the real input (`scratch/endless_grass_boost.gd`):
  - The grass keeps up: 0 queued, 6–8 near cells and about 60 far cells
    the whole way.
  - With vsync: worst frame 18.8 ms, 0 frames over 25 ms, slowest stand
    1.9 ms.
  - Uncapped: median 10.2 ms, p99 14.3 ms, worst 18.6 ms, 0 frames over
    25 ms.
  - The same flight with `--no-grass` had 21 frames over 25 ms (worst 84
    ms), from the land and cloud streaming rather than from the grass. It
    is worth a look some day.
- Hand landing with the grass on (`scratch/endless_grass_land.gd`, real
  input):
  - It flew in with flaps and brake on the meadow at 1200,950 and touched
    down as a "greaser".
  - It rolled to a stop on the turf among the tufts, with grass cells
    standing round it.
  - Boost rolled it off, and it lifted off.
  - The tufts have no collision, so the meadows land as before.
- G turns the grass off (all cells freed) and back on (it regrows):
  `scratch/grass_toggle.gd`.

## Stills (`scratch/endless-grass/`, git-ignored)

- The final set is `f2_*`, taken over the meadow at 1200,950 looking
  south-east into the morning sun:
  - `f2_l03`: skimming at 3 m.
  - `f2_l15`: landing approach.
  - `f2_l45`: cruise.
  - `f2_l95`: high.
  - `f2_far`: across the meadow to the horizon from 12 m.
  - `f2_golden`: golden meadow mood.
  - `f2_dusk`: rosewater dusk.
  - With/without pairs: `f2_l95` and `f2_l95_nograss`, `f2_far` and
    `f2_far_nograss`.
  - Contact sheet: `f2_sheet.png`.
- Without clouds (no shadows, easier to judge the hand-off): the `h3_*`
  ladder, plus `h5_l03` and `h6_l03` (skimming).
- The touch-down and the plane stopped in the grass: `land_touch.png`,
  `land_stopped.png`.
- Scripts: `final.sh` (the set; `DX`/`DZ` give the view direction),
  `ladder.sh`, `perf.sh`.
- A low cloud floats over this meadow, so it is at the top of most
  frames.

## Not verified

- The look in motion: the far ring's grain and the painted speckle could
  shimmer at speed, and the near/far crossover at 20–36 m might show while
  moving. Watch it in play.
- The wind sheen: the near tufts' waves and the paint's crests are
  separate, and I have not judged them together in motion.
- Moods other than alpine morning, golden meadow and rosewater dusk; night
  and the running day.
- How fast the far ring fills at the very start. The load grows the near
  cells and the far cells within 90 m; the rest fill over the first few
  seconds.
- Windows and other GPUs.

## Existing tests this breaks

None known. No test covers the endless scripts or shaders, and no shared
file changed. The full suite was not run.

## Next cues

- If the low view's +6 ms matters, the near ring is the lever. A
  near-ring-only fold of the isle material without the sway parts it
  doesn't need here, or a smaller `LOD.x/y` (16,30 measured about 12.5 ms).
- Trees and scatter on the same layer system; the far shader pattern
  suits card trees too.
- `TONE_TOP/LOW` were matched by eye and by pixel means in alpine
  morning. A per-mood check could tune them per mood.
- A golden hour with the low sun behind the carpet (backlit tips) would
  want a little translucency in the far shader.
