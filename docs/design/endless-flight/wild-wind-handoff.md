# Handoff: wind across the wilderness (loop `wild-wind`)

Spec: `spec-wild-wind.md` (beside this). Branch `iter/wild-wind`, worktree
`/Users/davidkalina/Documents/Projects/zenscape-wild-wind`. Each step's
commit (`git log --grep='^ITER(wild-wind)'`) has its decisions, checks and
stills.

## What's built

- **The wind field** (`scripts/endless/wind_field.gd`, owned by
  `EndlessLook` as `look.wind`). Strength at a point = the hour's curve x the
  day's temper x (the place's exposure + drifting windy patches) x a slow
  breath, on the old 0..2 `zs_wind_strength` scale.
  - Hour: still at dawn, building through the morning to a peak at
    14:30-15:00, easing through golden hour, near still in the blue hour.
  - Temper: each day rolls calm (30%), breezy (45%) or gusty (25%) from the
    land seed and the day number; it eases in over the blue hour.
  - Exposure: baked once on a worker thread (about 2 s, 177x177 cells of
    125 m) from the land's shape: ridges, tops, high ground and shores
    windy, valley floors and hollows calm, woods shelter themselves and
    their lee. The old wind blows until the bake lands, then the field
    fades in over 4 s.
  - Patches: 5 broad blobs (1.8-3.2 km) drifting downwind at 7 m/s, so a
    place changes over minutes.
  - Deterministic from seed + clock (no `hash` of floats).
  - `wind_at(x, z)` and `direction_at(x, z)` for GDScript (for the plane
    later; the plane doesn't feel the wind yet).
- **Shaders** (`shaders/wind_field.gdshaderinc`): the same field per pixel
  or vertex, from the exposure texture and the 5 blobs as globals.
- **Grass**: where it's windy, the Amberlands' blow-as-one swell (near and
  far tufts combed and leaning, light and dark swells rolling); where it's
  calm, it stands and its sheen stills. The wilderness keeps its colours:
  only a quarter of the swell's straw undersides show
  (`ZS_WIND_SILVER`), and the swells keep reading from flying height
  (`ZS_WIND_UP_SHEEN`; the ground's paint used to mute the sheen to 15%
  above 20-75 m).
- **Trees**: every spruce sways by the wind at its own foot (near crowns,
  sprites to 1.44 km, and the painted canopy's shimmer past that). The old
  far ring and far crowns (only drawn with `--spruce-sprites=0` /
  `--spruce-rings=old`) got a cheap sway.
- **Eddies**: the wind ribbons stay. Their grass motion now rolls smoothly
  (a band of stamps moved every frame, not a stamp dropped every 2 m), and
  they come with the wind: many on windy spots and hours, none in calm
  hollows or at dawn, heading with the local wind.
- **Sound**: the breeze bed swells with the wind at the eye on top of its
  altitude curve.
- **Pollen** drifts on the local wind (all but hangs in calm).
- **Water**: rivers and ponds get dark drifting cat's paws where it's windy;
  still water lies glassy in calm. The sea and the Peak's tarn are
  untouched.
- **The Amberlands**: `--world=amberlands` has no field; in the doors world
  its half is past the field's reach (3 km fade), so it keeps its held hour
  and its own grass, untouched.

## How to play it

```
cd /Users/davidkalina/Documents/Projects/zenscape-wild-wind && python3 tools/play.py --no-pull -- --hour=15 --wind=breezy --wind-map --pilot-file=/tmp/wild_wind_pilot.json
```

Spots on seed 1 at the afternoon peak (add `--at=x,z`):

| Spot | `--at=` | Wind at 15:00 breezy |
|---|---|---|
| Windy coast meadow (the lighthouse isle) | `2125,3225` | 0.94 |
| Calm hollow by the Peak's foot | `-4000,-2025` | 0.14 |
| Windy upland | `750,-3025` | 0.94 |
| Windy wood | `-875,4350` | 0.69 |
| Calm wood | `-4500,-1650` | 0.12 |
| Windy pond (cat's paws) | `4312,-1290` | 0.85 |
| Calm pond (glassy) | `1832,512` | 0.22 |

`]` speeds time to see the day turn.

## Flags

| Flag | What |
|---|---|
| `--wind=calm\|breezy\|gusty` | every day's temper |
| `--wind=X` | a fixed strength X (0..2) everywhere, no hour, no place |
| `--wind=off` | the old single wind (the mood's): the look before this loop |
| `--wind-map` | the field's map, top right (repaints once a second) |
| `--wind-forest=X` | the woods' shelter scaled (0 none, 1 default) |
| `--hour=H` | the hour (already there) |
| `--swell=X,Y,Z` / `--swell=0` | the swell's reach, lean, colour share / today's sheen without it |
| `--sheen-pace=X` | the swells' speed as a share of the air's |
| `--eddy-push=X`, `--eddy-reach=X`, `--eddy-every=S` | the eddies' push on the grass, its reach, a fixed front interval (`endless-eddies-handoff.md` has the rest) |
| `--river-knob=river_paws=Vector4(...)` | the cat's paws (x share, y patch size m, z mirror dulling, w calm glassiness); also `river_paw_wind`, `river_paw_dark`. `Vector4(0,16,0,0)` turns them off |

## Knobs in code

- `scripts/endless/wind_field.gd`: `DAY` (the hour's curve), `TEMPERS`,
  `PEAK`, `SHELTER`, the exposure terms in `bake()` (`RIDGE`, `HOLLOW`,
  `OPEN_WATER`, `FOREST_SHELTER`), `PATCHES`/`PATCH_*`, `breeze_of`,
  `swell_of` (mirrored in `wind_field.gdshaderinc`).
- `shaders/wind_field.gdshaderinc`: `ZS_WIND_SILVER` 0.25, `ZS_WIND_UP_SHEEN` 0.8.
- `scripts/endless/endless_eddies.gd`: `RATE`, `TRAIL_GAIN`, `band()`.
- `scripts/endless/flight_sound.gd`: `WIND_SHARE`, `WIND_SWELL`.

## Stood in

- Inland, the coasts dominate: seed 1's land is low and most of it within
  375 m of water, so most windy ground is shore. Inland ridges and the
  upland do blow (exposure p75 0.72 inland).
- The plane doesn't feel the wind (spec: later).
- No leaf litter in endless flight to blow (the old isles' is archived).

## Open

- Whether the eddies still earn their place beside the new wind (the
  user's call; the spec keeps them).
- The Peak's foot reads as a calm ring (the massif lifts the 2 km blur).
- Calm woods' spruce still bob a little (breeze floor 0.06).
- The eddies' grass bands are subtle from cruise height; they are a near
  flourish.
- The bake takes about 2 s on a worker (1.3 s of it the woods' pass in
  GDScript); the field lands that long after the start.

## Cost

Measured on the Mac (M5 Pro, 1440x900 at 3D scale 0.8, vsync off, 15:00
breezy), held views, median ms per frame. Separate runs drift by a ms or
more (other work on the machine), so the split was measured in one run:
`scratch/cost_ab.gd` (a look_views driver, uncommitted) alternates 40-frame
blocks with the field's shader paths on (`full`) and off (`zs_wind_field.w`
0: the old paths, the same eye wind) and takes each one's median.

| meadow_low (5 m over a meadow) | before | after |
|---|---|---|
| `--wind=off` | 26.3 | 26.3 |
| breezy, field paths off | 27.4 | 26.8 |
| breezy | 28.55 | 27.2 |
| the wind's cost | +2.25 | about +0.9 |

The forest view (14 m by the woods): 48.9 before, 48.0 after, 46.4 with
`--wind=off` (+2.5 to +1.6). From height it costs next to nothing (the
older table: cruise about +0.5, high and wood in the noise).

Where it went, and what was cut (the look kept: stills before and after
match to SSIM 0.9999, PSNR 61 to 65 dB, in scratch/trim_shots/*_pre.png vs *_post2.png):

- It was the GPU, not the eddies. Held views don't run the eddies at all
  and still paid it; with the field's paths off in the same run, 1.1 ms
  went. Of that, the field's texture fetch, five blobs and reach were
  ~0.85 ms (`fixed` field: +0.25).
- Most of it was the far tufts (20 to 230 m, millions of vertices): a
  stand-in field there alone took 1.3 ms off. Each vertex read the field
  twice (its swell share, then the sheen's breeze) and the ground pixel up
  to five times. Now each reads it once (`zs_wind_here` and the `*_here`
  helpers in `wind_field.gdshaderinc`; the ground, far and near tufts):
  -0.9 ms.
- A far tuft reads it only when it shows (its ring keep over 0).
- The far tufts (all within 230 m of the eye) take the patches' sum as its
  second-order form round the eye (`ZS_WIND_NEAR_ONLY`,
  `zs_wind_spots_near`; EndlessLook publishes `zs_wind_near_0/1` from
  `WindField.spots_near` each frame), not five exps: under 0.007 a blob
  off within 400 m. -0.5 ms, repeated (27.77/27.75 vs 27.27/27.13).
- What's left: ~0.4 ms of the field paths (one texture fetch a vertex and
  pixel) and ~0.5 ms that comes with the wilderness's swell paint
  (`grass_swell`, `zs_grass_lean`): it stays even at `--swell=0`, and
  dropping any one of its paint lines took off about half; not pinned down.
- The eddies' CPU (headless, parked at the windy meadow, frame log marks):
  0.9 ms a frame with the field (14 ribbons: the isle ribbons' steps 0.53,
  the bands' trail, lay and set_flows 0.35), 0.7 ms with `--wind=off` (fewer
  ribbons). The ribbons' own steps are the old isle code (four ground reads
  a ribbon a step, 3.2 us each, and their dictionaries); not cut. Held views
  hid this; on the Mac the frame waits on the GPU, so it shows only where
  the CPU is the limit.

Not measured on the PC, and not in a flown flight: a frame log of a low,
fast flight (`python3 tools/play.py -- --frame-log=res://scratch/f1.csv`,
then `python3 tools/frame_report.py scratch/f1.csv`, once with
`--wind=off`) would show it where it's flown.
