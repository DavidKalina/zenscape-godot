# Endless flight, look round 4: the grass tuned toward the isle

The near carpet was coarse and leafy from the plane. Now it is fine and soft, and it reads as one surface with the turf under it. The far look is the same as before.

## Why the isle looked better

The stills are in `scratch/endless-grass-tune/`. For each view, the isle carpet (held `--look=alpine_morning`) and the endless meadow at 1200,950 are compared from the same height and in the same direction. The pixel numbers are the bottom 28% of the 3 m view (`scratch/px.gd`).

| still | mean (sRGB) | light-dark spread |
|---|---|---|
| isle, 9.6 h | 110 144 82 | 40 |
| endless before, default 7.6 h | 89 111 48 | 81 |
| endless before, 9.6 h | 87 111 50 | 54 |
| endless before, 9.6 h, no clouds | 138 165 88 | 42 |

What mattered, most first:

1. **The light.** At 7.6 h the low sun lit one side of each blade and left the other dark. That doubled the contrast (81 against the isle's 40), and every tuft read as its own dark-sided clump. The isle opens on alpine morning's own hour, 9.6.
2. **The cloud's shadow.** The test meadow sits under a low cloud's shadow. Under a cloud, the tuft material halved its whole colour but kept the sun's direct light. The painted ground did the opposite: it lost 85% of its sun and kept the sky's light. So shaded tufts stayed lit like faceted leaves on top of dark turf. In full sun, with no clouds, the endless tufts were as soft as the isle's (spread 42).
3. **The colour under the tufts.** The tuft roots took ground_look's colour, which the endless paint does not draw. The paint between the tufts also had its own grain, dry flecks and velvet. With root and turf apart, each tuft was cut out against the ground.
4. **The tuft itself.** Ten broad blades, made to read from 20–26 m (`grass_tuft_mesh.gd`). From 3–10 m they read as leafy crop clumps even in good light.

Not causes:

- **Density and size.** These match exactly: 6.7 against 6.9 tufts/m², and a mean scale of 1.32 against 1.37 (`scratch/density.gd`).
- **The palette.** Alpine morning's grass ratio is 1 on both.
- **The isle's look-pass globals.** zs_look_fill, rim and ao at five times strength did not change a pixel of the tufts. I tried them and took them out.
- **Framing.** It was not tested on its own. The isle's grass reads well wherever its light is right.

## What changed

- `scripts/endless/endless_look.gd`: the default hour is now `HOUR := 9.6`, the mood's own and the isle's. `--hour=` still overrides it, and L still steps the moods.
- `shaders/reference_surface.gdshader` (shared). Two opt-in uniforms, both 0 by default, so the isle draws as before:
  - `grass_root_paint` (vec4): the tuft's root and the green it leans to become a painted ground's colour (rgb) times the tuft's instance tint. When w is 1, the ground_look call is skipped.
  - `cloud_sun_shade` (float): a cloud volume's shadow takes this share of the sun only, through the light pass, and leaves the sky's light alone, as the endless ground does.
- `shaders/endless_ground.gdshader`: a new `carpet_near` (vec2). Under the near carpet, the paint becomes the tufts' own ground: the patches from 8 m up (`endless_patch.gd grass`, which the roots carry) plus `carpet_near_grain` (0.6) of its fine grain. The dry flecks, velvet, crests and speckle are dropped there.
- `scripts/shared/kit_flora.gd` (shared), opt-in:
  - Site `flower_drift`, a callable from a point to a multiplier on the flowers' keep.
  - A `batch_node(..., mesh)` override. The mesh is set before the buffer; set after, it cost a 24 ms stand.
- `scripts/endless/endless_grass.gd`:
  - The near ring draws a FINE tuft, built here from the same blade code: 12 narrow blades of one bend each plus two 3-blade satellites. That is 54 triangles against 80, at 1.2× the isle's density.
  - The tuft roots and the paint are wired together (`ROOT_PAINT`).
  - `CLOUD_SUN` 0.85 applies to the near tufts, the flowers and the far ring.
  - Wildflower drifts: about 12% of the land, up to 6× the flowers (`DRIFT`, `DRIFT_SCALE`).
  - `LOD` is now 16,30,150,230 (was 20,36,…).
  - The exit leak is fixed. KitFlora's plain Grow made a "Flora" Node3D for every cell and never freed it; the cell's worker now frees it.

## Knobs and flags

All earlier flags and keys work as before: G, --no-grass, --grass=, --grass-range=, --grass-lod=, --no-flowers, the clouds' flags and --mood/--hour.

New flags:

- `--grass-fine=X`: the fine tuft at X of the isle's density (1.2). `0` gives the isle's own tuft at the isle's own density.
- `--grass-patches=X`: how much of the paint's patches the tufts carry (1).
- `--grass-set=name=v`, `--far-set=`, `--ground-set=`: any shader uniform on the near tufts, the far ring or the ground, for tuning by hand. A value with commas is a vector.

Consts in `endless_grass.gd`: `FINE`, `FINE_TUFTS`, `ROOT_PAINT`, `CLOUD_SUN`, `DRIFT`, `DRIFT_SCALE`, `LOD`.

## Perf

Measured on the M5 Pro, Forward+, 1440×900, uncapped, with clouds on, at the 1200,950 meadow (`scratch/endless-grass-tune/perf.sh`, mean of 300 frames). Runs vary by about ±0.5 ms.

| view | grass off | before | after |
|---|---|---|---|
| low, 6 m | 6.8 | 12.8–12.9 | 12.2–12.6 |
| cruise, 45 m | 7.0 | 10.2 | 9.4–10.0 |
| high, 95 m | 7.7 | 9.1 | 8.6–8.9 |

- The gain is small. The near ring, the isle's material, still costs about 4.5 ms low down. Its cost follows the instance count, not the triangles per tuft.
- The far ring costs about 2.2 ms; ending it at 180 m would cut that to about 1.1 ms.
- A boost flight 12 m over the land, 60 s and 1.5 km, through real input: median 16.7 ms (vsync), p99 17.5, worst 18.3 ms. No frame went over 25 ms, and the slowest stand was 1.7 ms. One earlier run had two lone spikes over 33 ms. A `--no-grass` run had none, and two later runs had none either.

## Verified

- Headless import: 0 errors.
- Smoke PASS on `endless_flight` (as is, with `--no-grass`, and with `--grass-fine=0 --mood=golden_meadow`), `aqueduct_isle`, and the motif yard with `bell_spires` and `editor_hill`.
- The isle's 3 m still matches the one taken before the change: mean 110 144 82 in both.
- Rendered runs quit cleanly, and the ObjectDB leak warning is gone, with grass and with `--no-grass`.
- G off and on: `scratch/grass_toggle.gd` gives 3 OK.
- Hand landing on the meadow: a greaser, it rolls to a stop, and grass stands round it.
  - The driver's later "Space rolls it off" and "lifted off" checks fail.
  - They fail the same way on the base commit, so the cause is the driver, not this round.

## Stills (`scratch/endless-grass-tune/`)

- **Isle against endless.** `cmp_l03`, `cmp_l10`, `cmp_l15`, `cmp_l45`, each a contact sheet. Panels: isle, endless before (`base0_*`, 7.6 h), endless after (`fin_*`, in the cloud's shadow), and endless after in sun (`finsun_*`, no clouds; not in the 45 m sheet).
- **Height ladder.** `fin_sheet` (3, 10, 15, 45, 95 m) and `finsun_sheet`.
- **Flying over at 10 m, looking down and forward.** `fin_l10` and `finsun_l10`.
- **Moods and edges.** `fin_moods_edges`: golden meadow and rosewater dusk at 3 and 15 m, the shore at 10 m (`fin_shore`), and a flower drift at 4 m (`fin_drift`).
- **Isle reference.** `isle_sheet` and `isle_l03`.
- **Scripts.** `isle.sh`, `endless.sh` (use `SETTLE=120 --heading=45` so the plane flies out of the shot), `perf.sh`.
- `shot.py`'s camera does not carry the land with it. The land streams round the plane, which flies on, so after a long settle the tufts get buried under coarser land. Keep the settle short.

## Not verified

- Motion: the fine tufts' sway, and the 16–30 m hand-off while moving.
- Moods other than alpine morning, golden meadow and rosewater dusk.
- Whether the 9.6 h default reads the hills as well from cruise height as 7.6 did. The 45 and 95 m stills look lighter and more pastel. If the hills look flatter, `--hour=7.6` brings the old light back.
- Windows and other GPUs.

## Existing tests

- No test covers the endless scripts.
- `test_aqueduct_isle_look.gd` fails with the same 4 FAILs before and after this change, so it already failed on the base commit (triangle budget, catalog multimeshes, a plant on a path, 321 plants off the turf).
- `test_ground_look`, `test_sky_peak_look`, `test_breeze` and `test_kit_time_weather` pass.
- The full suite was not run.

## Next cues

- **Perf.** The near ring's isle material is the lever. A lean endless near-tuft shader, the far shader plus sway, tip glow and root paint, would likely save 3 ms, but it has to be judged against the isle's look.
- **Colour.** In full sun this meadow reads paler and yellower than the isle's lime. That is the paint's warm and dry patch here. If the user wants the isle's lime near the plane, lower `grass_ground_pull` or the paint's warm drift under the carpet.
- **Rock edges.** The wild shag at turf edges (KitFlora `_foot`) shows at the shore as a dark strip. Rock edges were not found near the start, so they were not judged.
